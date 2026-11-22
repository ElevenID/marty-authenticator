//! Opaque, bounded consent sessions. Credentials and prepared signing inputs
//! stay native; every transition consumes its old handle, including failures.
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use anyhow::{ensure, Context};
use chrono::{DateTime, Duration, Utc};
use marty_oid4vci::{
    jose, wallet_request_auth::AuthenticatedPresentationRequest, PreparedSdJwtPresentation,
    PresentationResponse, WalletEngine,
};
use serde_json::json;

use super::verifier_governance::{self, FreshGovernance};

const MAX_SESSIONS: usize = 16;

pub(crate) struct PreparedSelection {
    pub session_id: String,
    pub signing_input: Vec<u8>,
}

struct Frozen {
    locator: String,
    governance: FreshGovernance,
    authenticated: AuthenticatedPresentationRequest,
    credential: String,
    issuer_revision: super::issuer_trust::Revision,
    expires_at: DateTime<Utc>,
}

enum Stage {
    Reviewed(Frozen),
    Prepared(Frozen, PreparedSdJwtPresentation),
    // Exercise the actual RAII wrapper without fabricating a Core authority.
    #[cfg(test)]
    ReservationProbe,
}

enum Entry<T> {
    Busy {
        token: uuid::Uuid,
        expires_at: DateTime<Utc>,
    },
    Ready {
        stage: Box<T>,
        expires_at: DateTime<Utc>,
    },
}
impl<T> Entry<T> {
    fn expires_at(&self) -> DateTime<Utc> {
        match self {
            Self::Busy { expires_at, .. } | Self::Ready { expires_at, .. } => *expires_at,
        }
    }
}

struct Store<T>(HashMap<String, Entry<T>>);
impl<T> Default for Store<T> {
    fn default() -> Self {
        Self(HashMap::new())
    }
}
impl<T> Store<T> {
    fn reserve(&mut self, now: DateTime<Utc>) -> anyhow::Result<(String, uuid::Uuid)> {
        self.0.retain(|_, entry| entry.expires_at() > now);
        ensure!(
            self.0.len() < MAX_SESSIONS,
            "too many pending presentations"
        );
        let id = uuid::Uuid::new_v4().to_string();
        let token = uuid::Uuid::new_v4();
        ensure!(!self.0.contains_key(&id), "presentation session collision");
        self.0.insert(
            id.clone(),
            Entry::Busy {
                token,
                expires_at: now + Duration::seconds(60),
            },
        );
        Ok((id, token))
    }
    fn take(&mut self, id: &str, now: DateTime<Utc>) -> anyhow::Result<(Box<T>, uuid::Uuid)> {
        // An overlapping call cannot remove the in-flight reservation.
        ensure!(
            matches!(self.0.get(id), Some(Entry::Ready { .. })),
            "presentation session is missing or consumed"
        );
        let Some(Entry::Ready { stage, expires_at }) = self.0.remove(id) else {
            unreachable!()
        };
        ensure!(expires_at > now, "presentation consent expired");
        let token = uuid::Uuid::new_v4();
        self.0
            .insert(id.to_owned(), Entry::Busy { token, expires_at });
        Ok((stage, token))
    }
    fn active(&self, id: &str, token: uuid::Uuid, now: DateTime<Utc>) -> bool {
        matches!(self.0.get(id), Some(Entry::Busy { token: current, expires_at }) if *current == token && *expires_at > now)
    }
    fn publish(
        &mut self,
        id: &str,
        token: uuid::Uuid,
        stage: T,
        expires_at: DateTime<Utc>,
        now: DateTime<Utc>,
    ) -> anyhow::Result<String> {
        ensure!(
            expires_at > now && self.active(id, token, now),
            "presentation session expired or cancelled"
        );
        let next = uuid::Uuid::new_v4().to_string();
        ensure!(
            !self.0.contains_key(&next),
            "presentation session collision"
        );
        self.0.remove(id);
        self.0.insert(
            next.clone(),
            Entry::Ready {
                stage: Box::new(stage),
                expires_at,
            },
        );
        Ok(next)
    }
    fn release(&mut self, id: &str, token: uuid::Uuid) {
        if matches!(self.0.get(id), Some(Entry::Busy { token: current, .. }) if *current == token) {
            self.0.remove(id);
        }
    }
}

static SESSIONS: OnceLock<Mutex<Store<Stage>>> = OnceLock::new();
fn sessions() -> &'static Mutex<Store<Stage>> {
    SESSIONS.get_or_init(|| Mutex::new(Store::default()))
}
fn lock() -> anyhow::Result<std::sync::MutexGuard<'static, Store<Stage>>> {
    sessions()
        .lock()
        .map_err(|_| anyhow::anyhow!("presentation sessions are unavailable"))
}

// A dropped future releases its slot. Cancellation removes the marker, so an
// eventual callback cannot publish a session after cancellation or expiration.
struct Reservation {
    id: String,
    token: uuid::Uuid,
}
impl Reservation {
    fn new() -> anyhow::Result<Self> {
        let (id, token) = lock()?.reserve(Utc::now())?;
        Ok(Self { id, token })
    }
    fn take(id: &str) -> anyhow::Result<(Self, Box<Stage>)> {
        let (stage, token) = lock()?.take(id, Utc::now())?;
        Ok((
            Self {
                id: id.to_owned(),
                token,
            },
            stage,
        ))
    }
    fn publish(self, stage: Stage, expires_at: DateTime<Utc>) -> anyhow::Result<String> {
        // Edition2021 tail-expression temporaries can outlive consumed self.
        // Drop the guard explicitly before Reservation::drop reacquires it.
        let mut store = lock()?;
        let result = store.publish(&self.id, self.token, stage, expires_at, Utc::now());
        drop(store);
        result
    }
    fn consume(self) -> anyhow::Result<()> {
        let mut store = lock()?;
        ensure!(
            store.active(&self.id, self.token, Utc::now()),
            "presentation session expired or cancelled"
        );
        store.release(&self.id, self.token);
        Ok(())
    }
}
impl Drop for Reservation {
    fn drop(&mut self) {
        if let Ok(mut store) = sessions().lock() {
            store.release(&self.id, self.token);
        }
    }
}

pub(crate) fn cancel(session_id: &str) -> anyhow::Result<()> {
    lock()?.0.remove(session_id);
    Ok(())
}

fn same_authority(old: &FreshGovernance, fresh: &FreshGovernance) -> bool {
    let a = &old.authority;
    let b = &fresh.authority;
    old.scope == fresh.scope
        && old.request_input == fresh.request_input
        && a.authority_id == b.authority_id
        && a.revision == b.revision
        && a.client_id == b.client_id
        && a.request_key_id == b.request_key_id
        && a.public_jwk_json == b.public_jwk_json
        && a.response_uris == b.response_uris
        && a.valid_from == b.valid_from
        && a.valid_until == b.valid_until
}

impl Frozen {
    async fn refresh(
        &self,
        governance: &str,
        holder: &str,
    ) -> anyhow::Result<(FreshGovernance, AuthenticatedPresentationRequest)> {
        ensure!(self.expires_at > Utc::now(), "presentation consent expired");
        let fresh = verifier_governance::parse(governance, &self.locator, holder, Utc::now())?;
        ensure!(
            same_authority(&self.governance, &fresh),
            "confirmed pairing or verifier authority changed"
        );
        // Equality above requires byte-for-byte original JWS identity. Core
        // authenticates those bytes again, using current DID and authority.
        let authenticated = fresh
            .authenticate_retained(self.authenticated.compact_jws())
            .await?;
        ensure!(
            self.expires_at > Utc::now()
                && authenticated.consent_binding_digest()
                    == self.authenticated.consent_binding_digest(),
            "authenticated consent changed"
        );
        Ok((fresh, authenticated))
    }
}

fn query_id(request: &marty_oid4vci::ParsedPresentationRequest) -> anyhow::Result<&str> {
    let query = request
        .dcql_query
        .as_ref()
        .context("authenticated DCQL request is absent")?;
    ensure!(
        query.credentials.len() == 1,
        "authenticated query is unsupported"
    );
    Ok(&query.credentials[0].id)
}

/// Admit one exact candidate before consent. The signed request is authenticated
/// before any candidate's signed contents are returned to Flutter.
pub(crate) async fn review(
    locator: String,
    governance: String,
    credential: String,
    issuer: String,
    holder: String,
) -> anyhow::Result<String> {
    ensure!(
        !credential.is_empty() && credential.len() <= 1024 * 1024,
        "credential is invalid"
    );
    let reservation = Reservation::new()?;
    let checked = verifier_governance::parse(&governance, &locator, &holder, Utc::now())?;
    let authenticated = checked.authenticate().await?;
    let trusted = checked.issuer_trust(&issuer, &credential)?;
    let verified = authenticated.verify_sd_jwt_for_consent(
        &credential,
        &checked.holder_jwk_json,
        &trusted.resolver,
    )?;
    let projection = super::disclosure_review::projection(&credential, &verified)?;
    let request = super::presentation::request_projection(
        authenticated.request(),
        authenticated.consent_binding_digest(),
    )?;
    query_id(authenticated.request())?;
    let expires_at = checked
        .expires_at
        .min(trusted.expires_at)
        .min(
            DateTime::from_timestamp(authenticated.expires_at(), 0)
                .context("invalid request expiry")?,
        )
        .min(Utc::now() + Duration::seconds(60));
    let frozen = Frozen {
        locator,
        governance: checked,
        authenticated,
        credential,
        issuer_revision: trusted.revision,
        expires_at,
    };
    let session_id = reservation.publish(Stage::Reviewed(frozen), expires_at)?;
    Ok(serde_json::to_string(
        &json!({"session_id":session_id, "expires_at":expires_at, "request":request, "credential":serde_json::from_str::<serde_json::Value>(&projection)?}),
    )?)
}

pub(crate) async fn prepare(
    session_id: &str,
    claims: &[String],
    governance: &str,
    issuer: &str,
    holder: &str,
) -> anyhow::Result<PreparedSelection> {
    let (reservation, stage) = Reservation::take(session_id)?;
    let Stage::Reviewed(mut frozen) = *stage else {
        anyhow::bail!("presentation session is not awaiting approval")
    };
    let (fresh, authenticated) = frozen.refresh(governance, holder).await?;
    let trusted = fresh.issuer_trust(issuer, &frozen.credential)?;
    ensure!(
        trusted.revision == frozen.issuer_revision,
        "issuer authority revision changed"
    );
    let prepared = authenticated.prepare_sd_jwt_presentation(
        &frozen.credential,
        claims,
        &fresh.holder_jwk_json,
        &trusted.resolver,
    )?;
    let signing_input = prepared.signing_input().to_vec();
    ensure!(
        !signing_input.is_empty() && signing_input.len() <= 65536,
        "presentation signing input is invalid"
    );
    frozen.expires_at = frozen
        .expires_at
        .min(fresh.expires_at)
        .min(trusted.expires_at);
    let expires_at = frozen.expires_at;
    let session_id = reservation.publish(Stage::Prepared(frozen, prepared), expires_at)?;
    Ok(PreparedSelection {
        session_id,
        signing_input,
    })
}

pub(crate) async fn complete(
    session_id: &str,
    signature: &[u8],
    governance: &str,
    issuer: &str,
    holder: &str,
) -> anyhow::Result<PresentationResponse> {
    let (reservation, stage) = Reservation::take(session_id)?;
    let Stage::Prepared(frozen, prepared) = *stage else {
        anyhow::bail!("presentation session is not awaiting a signature")
    };
    ensure!(signature.len() == 64, "remote ES256 signature is invalid");
    let (fresh, authenticated) = frozen.refresh(governance, holder).await?;
    let trusted = fresh.issuer_trust(issuer, &frozen.credential)?;
    ensure!(
        trusted.revision == frozen.issuer_revision,
        "issuer authority revision changed"
    );
    authenticated.verify_sd_jwt_for_consent(
        &frozen.credential,
        &fresh.holder_jwk_json,
        &trusted.resolver,
    )?;
    ensure!(
        jose::verify_detached_signature_with_public_jwk(
            prepared.signing_input(),
            signature,
            &fresh.holder_jwk_json,
            "ES256"
        )?,
        "remote signature does not match the confirmed public key"
    );
    let presentation = prepared.complete(signature)?;
    let request = authenticated.request();
    let engine = WalletEngine::new();
    let (vp_token, submission) = engine.build_presentation_for_request(
        request,
        HashMap::from([(query_id(request)?.to_owned(), presentation)]),
    )?;
    ensure!(
        frozen.expires_at > Utc::now()
            && fresh.expires_at > Utc::now()
            && trusted.expires_at > Utc::now(),
        "presentation authority expired"
    );
    // Last cancellation check and irreversible one-use transition occur before
    // submission, with no mutex held while awaiting external I/O.
    reservation.consume()?;
    engine
        .submit_presentation_for_request(request, &vp_token, submission.as_ref())
        .await
        .map_err(Into::into)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn reservations_bound_inflight_work_and_cancelled_callbacks_cannot_publish() {
        let now = Utc::now();
        let mut store = Store::<u8>::default();
        let (id, token) = store.reserve(now).unwrap();
        assert!(store.active(&id, token, now));
        assert!(!store.active(&id, uuid::Uuid::new_v4(), now));
        store.release(&id, uuid::Uuid::new_v4());
        assert!(store.active(&id, token, now));
        assert!(
            store.take(&id, now).is_err(),
            "overlapping call must not consume reservation"
        );
        store.0.remove(&id); // Explicit cancellation during an await.
        assert!(!store.active(&id, token, now));
        for _ in 0..MAX_SESSIONS {
            store.reserve(now).unwrap();
        }
        assert!(store.reserve(now).is_err());
        assert!(store.reserve(now + Duration::seconds(61)).is_ok());
        assert_eq!(store.0.len(), 1);
    }
    #[test]
    fn dropped_future_releases_its_reservation() {
        let reservation = Reservation::new().unwrap();
        let id = reservation.id.clone();
        assert!(lock().unwrap().0.contains_key(&id));
        drop(reservation);
        assert!(!lock().unwrap().0.contains_key(&id));
    }

    #[test]
    fn reservation_wrapper_publishes_consumes_and_releases_failures_without_nested_locking() {
        let reservation = Reservation::new().unwrap();
        let old = reservation.id.clone();
        let published = reservation
            .publish(Stage::ReservationProbe, Utc::now() + Duration::seconds(30))
            .unwrap();
        assert!(!lock().unwrap().0.contains_key(&old));
        let (completing, stage) = Reservation::take(&published).unwrap();
        assert!(matches!(*stage, Stage::ReservationProbe));
        completing.consume().unwrap();
        assert!(Reservation::take(&published).is_err());

        let cancelled = Reservation::new().unwrap();
        let id = cancelled.id.clone();
        cancel(&id).unwrap();
        assert!(cancelled
            .publish(Stage::ReservationProbe, Utc::now() + Duration::seconds(30))
            .is_err());
        assert!(!lock().unwrap().0.contains_key(&id));

        let expired = Reservation::new().unwrap();
        let id = expired.id.clone();
        assert!(expired
            .publish(Stage::ReservationProbe, Utc::now())
            .is_err());
        assert!(!lock().unwrap().0.contains_key(&id));
    }

    #[test]
    fn transitions_rotate_handles_and_replays_cannot_remove_inflight_work() {
        let now = Utc::now();
        let until = now + Duration::seconds(30);
        let mut store = Store::<String>::default();
        let (id, token) = store.reserve(now).unwrap();
        let reviewed = store
            .publish(&id, token, "exact reviewed candidate".into(), until, now)
            .unwrap();
        assert_ne!(id, reviewed);
        assert!(store.take(&id, now).is_err());
        assert!(store
            .publish(&id, token, "late callback".into(), until, now)
            .is_err());
        let (frozen, transition) = store.take(&reviewed, now).unwrap();
        assert_eq!(*frozen, "exact reviewed candidate");
        assert!(store.take(&reviewed, now).is_err());
        assert!(store.active(&reviewed, transition, now));
        let prepared = store
            .publish(
                &reviewed,
                transition,
                "exact prepared input".into(),
                until,
                now,
            )
            .unwrap();
        assert_ne!(reviewed, prepared);
        assert!(store.take(&reviewed, now).is_err());
        let (input, completing) = store.take(&prepared, now).unwrap();
        assert_eq!(*input, "exact prepared input");
        store.release(&prepared, completing);
        assert!(store.take(&prepared, now).is_err());
        assert!(store.0.is_empty());
    }

    #[test]
    fn cancellation_or_expiration_during_refresh_never_resurrects_a_session() {
        let now = Utc::now();
        let until = now + Duration::seconds(10);
        for cancelled in [false, true] {
            let mut store = Store::<u8>::default();
            let (id, token) = store.reserve(now).unwrap();
            let reviewed = store.publish(&id, token, 1, until, now).unwrap();
            let (_, refreshing) = store.take(&reviewed, now).unwrap();
            if cancelled {
                store.0.remove(&reviewed);
            }
            let resumed_at = if cancelled { now } else { until };
            assert!(store
                .publish(&reviewed, refreshing, 2, until, resumed_at)
                .is_err());
            store.release(&reviewed, refreshing);
            assert!(store.0.is_empty());
        }
    }
}

#[cfg(test)]
#[path = "governed_presentation_native_tests.rs"]
mod native_tests;
