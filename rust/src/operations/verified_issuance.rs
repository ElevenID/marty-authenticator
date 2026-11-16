//! One-use OID4VCI receipt with an opaque, remote P-256 holder signer.
//! The access token stays inside Rust; only the exact public-key proof input
//! crosses the bridge. A credential is returned only after issuer and holder
//! signatures have been verified against fresh pairing trust.

#[cfg(test)]
#[path = "verified_issuance_native_tests.rs"]
mod native_tests;

#[cfg(test)]
#[path = "joined_device_receipt_native_tests.rs"]
mod joined_device_tests;

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use anyhow::{ensure, Context};
use chrono::{DateTime, Duration, Utc};
use marty_oid4vci::types::{CredentialResponse, SigningAlgorithm};
use marty_oid4vci::wallet::PreparedHolderProof;
use marty_oid4vci::WalletEngine;
use serde_json::Value;

use super::issuer_trust::{
    admit_issuance, preflight_issuance, IssuanceAdmission, IssuanceSelection,
};

const MAX_PENDING: usize = 16;
pub(super) const MAX_OFFER_BYTES: usize = 8192;
const MAX_CREDENTIAL_BYTES: usize = 1024 * 1024;

pub(crate) struct PreparedReceipt {
    pub session_id: String,
    pub signing_input: Vec<u8>,
}

pub(crate) struct VerifiedReceipt {
    pub credential: String,
    pub issuer: String,
    pub credential_type: String,
    pub format: String,
}

struct PendingReceipt {
    slot: ReceiptSlot,
    proof: PreparedHolderProof,
    access_token: String,
    credential_endpoint: String,
    credential_configuration_id: String,
    selection: IssuanceSelection,
    admission: IssuanceAdmission,
    holder_public_jwk_json: String,
    expires_at: DateTime<Utc>,
}

struct PendingResponse {
    _slot: ReceiptSlot,
    received_at: DateTime<Utc>,
    response: CredentialResponse,
    selection: IssuanceSelection,
    admission: IssuanceAdmission,
    holder_public_jwk_json: String,
    expires_at: DateTime<Utc>,
}

static RESPONSES: OnceLock<Mutex<HashMap<String, PendingResponse>>> = OnceLock::new();
fn responses() -> &'static Mutex<HashMap<String, PendingResponse>> {
    RESPONSES.get_or_init(|| Mutex::new(HashMap::new()))
}

static PENDING: OnceLock<Mutex<HashMap<String, PendingReceipt>>> = OnceLock::new();

fn pending() -> &'static Mutex<HashMap<String, PendingReceipt>> {
    PENDING.get_or_init(|| Mutex::new(HashMap::new()))
}

// A reservation follows every receipt through awaited network transitions.
// Dropping a failed/cancelled future releases it without another remote action.
struct ReceiptSlot(String);
static SLOTS: OnceLock<Mutex<std::collections::HashSet<String>>> = OnceLock::new();
impl ReceiptSlot {
    fn reserve() -> anyhow::Result<Self> {
        let now = Utc::now();
        pending()
            .lock()
            .map_err(|_| anyhow::anyhow!("issuance sessions are unavailable"))?
            .retain(|_, session| session.expires_at > now);
        responses()
            .lock()
            .map_err(|_| anyhow::anyhow!("issuance responses are unavailable"))?
            .retain(|_, response| response.expires_at > now);
        let mut slots = SLOTS
            .get_or_init(|| Mutex::new(std::collections::HashSet::new()))
            .lock()
            .map_err(|_| anyhow::anyhow!("issuance capacity is unavailable"))?;
        ensure!(slots.len() < MAX_PENDING, "too many pending issuances");
        let id = uuid::Uuid::new_v4().to_string();
        ensure!(slots.insert(id.clone()), "issuance session collision");
        Ok(Self(id))
    }
}
impl Drop for ReceiptSlot {
    fn drop(&mut self) {
        if let Some(slots) = SLOTS.get() {
            if let Ok(mut slots) = slots.lock() {
                slots.remove(&self.0);
            }
        }
    }
}

fn https_endpoint(value: &str) -> anyhow::Result<url::Url> {
    let url = url::Url::parse(value)?;
    ensure!(
        url.scheme() == "https"
            && url.host_str().is_some()
            && url.username().is_empty()
            && url.password().is_none()
            && url.fragment().is_none(),
        "issuance endpoint must be an HTTPS URL without credentials or a fragment"
    );
    Ok(url)
}

fn issuer_endpoint(value: &str, issuer: &url::Url) -> anyhow::Result<String> {
    let endpoint = https_endpoint(value)?;
    ensure!(
        endpoint.origin() == issuer.origin(),
        "issuer endpoint has an unexpected origin"
    );
    Ok(endpoint.to_string())
}

pub(crate) async fn prepare(
    offer_uri: &str,
    tx_code: Option<&str>,
    holder_public_jwk_json: &str,
    issuer_snapshot_json: &str,
) -> anyhow::Result<PreparedReceipt> {
    preflight_issuance(issuer_snapshot_json, holder_public_jwk_json)?;
    let slot = ReceiptSlot::reserve()?;
    ensure!(
        !offer_uri.is_empty() && offer_uri.len() <= MAX_OFFER_BYTES,
        "credential offer URI is invalid"
    );
    // Core may fetch a by-reference offer while parsing. Reject non-HTTPS
    // references before that network operation, including wrapped inputs.
    let normalized = marty_oid4vci::normalize_credential_offer_uri(offer_uri)?;
    let envelope = url::Url::parse(&normalized)?;
    for (name, value) in envelope.query_pairs() {
        if name == "credential_offer_uri" {
            https_endpoint(&value)?;
        }
    }
    let engine = WalletEngine::new();
    let offer = engine.parse_credential_offer(&normalized).await?;
    let issuer = https_endpoint(&offer.credential_issuer)?;
    ensure!(
        offer.credential_configuration_ids.len() == 1,
        "credential configuration selection is required"
    );
    let configuration_id = offer.credential_configuration_ids[0].clone();
    ensure!(
        !configuration_id.is_empty() && configuration_id.len() <= 256,
        "credential configuration ID is invalid"
    );
    let grant = offer
        .grants
        .pre_authorized_code
        .context("only pre-authorized issuance is supported")?;
    ensure!(
        grant.tx_code.is_some() == tx_code.is_some(),
        "transaction code requirement does not match the offer"
    );
    if let Some(code) = tx_code {
        ensure!(
            !code.is_empty() && code.len() <= 256,
            "transaction code is invalid"
        );
    }

    let metadata = engine.fetch_issuer_metadata(issuer.as_str()).await?;
    ensure!(
        metadata.credential_issuer == offer.credential_issuer,
        "issuer metadata does not match the offer"
    );
    let credential_endpoint = issuer_endpoint(&metadata.credential_endpoint, &issuer)?;
    let nonce_endpoint = issuer_endpoint(
        metadata
            .nonce_endpoint
            .as_deref()
            .context("issuer nonce endpoint is required")?,
        &issuer,
    )?;
    let configuration = metadata
        .credential_configurations_supported
        .get(&configuration_id)
        .context("offered credential configuration is missing from issuer metadata")?;
    let (format, expected_vct) = supported_configuration(configuration)?;
    ensure!(
        metadata.authorization_servers.len() <= 1,
        "authorization server selection is required"
    );
    let authorization_server = metadata
        .authorization_servers
        .first()
        .unwrap_or(&offer.credential_issuer)
        .clone();
    https_endpoint(&authorization_server)?;
    let token_endpoint = engine.resolve_token_endpoint(&metadata).await?;
    https_endpoint(&token_endpoint)?;
    let selection = IssuanceSelection {
        credential_issuer: offer.credential_issuer.clone(),
        credential_configuration_id: configuration_id.clone(),
        format: format.to_string(),
        vct: expected_vct.to_string(),
        authorization_server,
        token_endpoint: token_endpoint.clone(),
    };
    // Admission precedes releasing the code or preparing any holder signature.
    let admission = admit_issuance(
        issuer_snapshot_json,
        holder_public_jwk_json,
        &selection,
        Utc::now(),
    )?;
    let token = engine
        .exchange_pre_auth_code(&token_endpoint, &grant.pre_authorized_code, tx_code)
        .await
        .map_err(|_| anyhow::anyhow!("issuer token exchange failed"))?;
    ensure!(
        token.token_type.eq_ignore_ascii_case("Bearer") && !token.access_token.is_empty(),
        "issuer token is not a bearer token"
    );
    let lifetime = token.expires_in.min(120);
    ensure!(lifetime > 0, "issuer token is expired");
    let token_expires_at = Utc::now() + Duration::seconds(lifetime as i64);
    let nonce = engine.fetch_nonce(&nonce_endpoint).await?;
    ensure!(!nonce.c_nonce.is_empty(), "issuer proof nonce is empty");

    let public_jwk: Value = serde_json::from_str(holder_public_jwk_json)?;
    let holder_kid = public_jwk
        .get("kid")
        .and_then(Value::as_str)
        .filter(|id| !id.is_empty())
        .context("paired presentation key ID is missing")?;
    let proof = engine.prepare_proof_jwt(
        holder_kid,
        &nonce.c_nonce,
        &offer.credential_issuer,
        holder_public_jwk_json,
    )?;
    ensure!(
        proof.algorithm() == SigningAlgorithm::ES256,
        "paired presentation key is not ES256"
    );
    let signing_input = proof.signing_input().to_vec();
    ensure!(
        !signing_input.is_empty() && signing_input.len() <= 64 * 1024,
        "proof signing input is invalid"
    );
    let session_id = slot.0.clone();
    let now = Utc::now();
    ensure!(
        token_expires_at > now && admission.expires_at > now,
        "issuer token expired before proof preparation"
    );
    let mut sessions = pending()
        .lock()
        .map_err(|_| anyhow::anyhow!("issuance sessions are unavailable"))?;
    sessions.retain(|_, session| session.expires_at > now);
    ensure!(sessions.len() < MAX_PENDING, "too many pending issuances");
    ensure!(
        !sessions.contains_key(&session_id),
        "issuance session collision"
    );
    sessions.insert(
        session_id.clone(),
        PendingReceipt {
            slot,
            proof,
            access_token: token.access_token,
            credential_endpoint,
            credential_configuration_id: configuration_id,
            selection,
            admission,
            holder_public_jwk_json: holder_public_jwk_json.to_string(),
            expires_at: token_expires_at,
        },
    );
    Ok(PreparedReceipt {
        session_id,
        signing_input,
    })
}

fn supported_configuration(configuration: &Value) -> anyhow::Result<(&str, &str)> {
    let object = configuration
        .as_object()
        .context("credential configuration is not an object")?;
    let format = object
        .get("format")
        .and_then(Value::as_str)
        .context("credential configuration format is missing")?;
    let vct = object
        .get("vct")
        .and_then(Value::as_str)
        .filter(|vct| !vct.is_empty())
        .context("SD-JWT credential type is missing")?;
    ensure!(
        matches!(format, "dc+sd-jwt" | "vc+sd-jwt"),
        "credential format is unsupported"
    );
    let binding = object
        .get("cryptographic_binding_methods_supported")
        .and_then(Value::as_array)
        .context("credential binding methods are missing")?;
    ensure!(
        binding.iter().any(|method| method.as_str() == Some("jwk")),
        "issuer does not advertise JWK holder binding"
    );
    let proof = object
        .get("proof_types_supported")
        .and_then(|types| types.get("jwt"))
        .context("issuer does not advertise JWT holder proofs")?;
    let algorithms = proof
        .get("proof_signing_alg_values_supported")
        .and_then(Value::as_array)
        .context("JWT proof algorithms are missing")?;
    ensure!(
        algorithms.iter().any(|alg| alg.as_str() == Some("ES256")),
        "issuer does not advertise ES256 holder proofs"
    );
    // Presence requires an attestation even when the object is empty. This
    // wallet can prove possession of its paired key, but cannot attest it.
    ensure!(
        proof.get("key_attestations_required").is_none(),
        "issuer requires an unsupported key attestation"
    );
    Ok((format, vct))
}

pub(crate) async fn complete(
    session_id: &str,
    remote_signature: &[u8],
    issuer_snapshot_json: &str,
) -> anyhow::Result<String> {
    let session = pending()
        .lock()
        .map_err(|_| anyhow::anyhow!("issuance sessions are unavailable"))?
        .remove(session_id)
        .context("issuance session is missing or already consumed")?;
    ensure!(session.expires_at > Utc::now(), "issuance session expired");
    session.admission.revalidate(
        issuer_snapshot_json,
        &session.holder_public_jwk_json,
        &session.selection,
        Utc::now(),
    )?;
    let proof_jwt = session.proof.complete(remote_signature)?;
    let engine = WalletEngine::new();
    let response = engine
        .request_credential(
            &session.credential_endpoint,
            &session.access_token,
            &session.credential_configuration_id,
            &proof_jwt,
        )
        .await
        .map_err(|_| anyhow::anyhow!("issuer credential request failed"))?;
    single_credential(&response)?;
    let now = Utc::now();
    ensure!(
        session.expires_at > now,
        "issuance session expired during credential request"
    );
    let handle = uuid::Uuid::new_v4().to_string();
    let mut received = responses()
        .lock()
        .map_err(|_| anyhow::anyhow!("issuance responses are unavailable"))?;
    received.retain(|_, response| response.expires_at > now);
    ensure!(
        !received.contains_key(&handle),
        "issuance response collision"
    );
    received.insert(
        handle.clone(),
        PendingResponse {
            _slot: session.slot,
            received_at: now,
            response,
            selection: session.selection,
            admission: session.admission,
            holder_public_jwk_json: session.holder_public_jwk_json,
            expires_at: session.expires_at,
        },
    );
    // Never expose an unverified credential. Dart must fetch authority after
    // the network response, then consume this opaque finalization handle.
    Ok(handle)
}

pub(crate) fn finalize(
    response_id: &str,
    issuer_snapshot_json: &str,
) -> anyhow::Result<VerifiedReceipt> {
    let received = responses()
        .lock()
        .map_err(|_| anyhow::anyhow!("issuance responses are unavailable"))?
        .remove(response_id)
        .context("issuance response is missing or already consumed")?;
    ensure!(
        received.expires_at > Utc::now(),
        "issuance response expired"
    );
    received.admission.observed_after(
        issuer_snapshot_json,
        &received.holder_public_jwk_json,
        received.received_at,
    )?;
    verify_receipt(
        &received.response,
        &received.selection,
        &received.admission,
        &received.holder_public_jwk_json,
        issuer_snapshot_json,
    )
}

// OID4VCI 1.0 uses an array of credential objects even for one issued
// credential. Retain the older singular response only when it is unambiguous.
// Neither a batch nor deferred issuance is part of this wallet path.
fn single_credential(response: &CredentialResponse) -> anyhow::Result<&str> {
    ensure!(
        response.transaction_id.is_none(),
        "deferred issuance is unsupported"
    );
    let value = match (&response.credential, &response.credentials) {
        (Some(credential), None) => credential,
        (None, Some(credentials)) if credentials.len() == 1 => credentials[0]
            .as_object()
            .and_then(|entry| entry.get("credential"))
            .context("issuer did not return one credential object")?,
        _ => anyhow::bail!("issuer did not return exactly one unambiguous credential"),
    };
    value
        .as_str()
        .filter(|value| !value.is_empty() && value.len() <= MAX_CREDENTIAL_BYTES)
        .context("issuer did not return one bounded SD-JWT")
}

fn verify_receipt(
    response: &CredentialResponse,
    selection: &IssuanceSelection,
    admission: &IssuanceAdmission,
    holder_public_jwk_json: &str,
    issuer_snapshot_json: &str,
) -> anyhow::Result<VerifiedReceipt> {
    let credential = single_credential(response)?;
    let trusted = admission.verify(
        issuer_snapshot_json,
        holder_public_jwk_json,
        selection,
        credential,
        Utc::now(),
    )?;
    let verified = WalletEngine::new().verify_received_sd_jwt_credential(
        credential,
        holder_public_jwk_json,
        &trusted.resolver,
    )?;
    ensure!(
        verified.credential_type == selection.vct,
        "issued credential type does not match the selected configuration"
    );
    ensure!(
        verified.format == selection.format,
        "issued credential format does not match the selected configuration"
    );
    ensure!(
        trusted.expires_at > Utc::now(),
        "issuer authority expired during credential verification"
    );
    Ok(VerifiedReceipt {
        credential: credential.to_string(),
        issuer: verified.issuer,
        credential_type: verified.credential_type,
        format: verified.format,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn fixture_selection() -> IssuanceSelection {
        IssuanceSelection {
            credential_issuer: "https://issuer.example".into(),
            credential_configuration_id: "fixture".into(),
            format: "vc+sd-jwt".into(),
            vct: "urn:elevenid:credential:verified-wallet".into(),
            authorization_server: "https://issuer.example".into(),
            token_endpoint: "https://issuer.example/token".into(),
        }
    }
    fn fixture_authority(fixture: &Value) -> String {
        let now = Utc::now();
        let selection = fixture_selection();
        let mut jwk = fixture["issuer_public_jwk"].clone();
        jwk["kid"] = fixture["issuer_key_id"].clone();
        let mut envelope = super::super::issuer_trust::fixture_envelope(
            json!({
            "organization_id":"org-1","trust_profile_id":"11111111-2222-4333-8444-555555555555",
            "generated_at":now,"expires_at":now+Duration::seconds(30),
            "issuer_keys":[{"issuer":fixture["issuer"],"key_id":fixture["issuer_key_id"],
                "algorithm":"ES256","public_jwk":jwk}]}),
            fixture["holder_public_jwk"].clone(),
            &selection.vct,
        );
        envelope["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([{
            "credential_issuer":selection.credential_issuer,"credential_configuration_id":selection.credential_configuration_id,
            "format":selection.format,"vct":selection.vct,"authorization_server":null,"token_endpoint":null}]);
        envelope.to_string()
    }

    fn stage_response(fixture: &Value, snapshot: &str, received_at: DateTime<Utc>) -> String {
        let holder = fixture["holder_public_jwk"].to_string();
        let selection = fixture_selection();
        let admission = admit_issuance(snapshot, &holder, &selection, Utc::now()).unwrap();
        let slot = ReceiptSlot::reserve().unwrap();
        let id = slot.0.clone();
        responses().lock().unwrap().insert(
            id.clone(),
            PendingResponse {
                _slot: slot,
                received_at,
                response: serde_json::from_value(
                    json!({"credentials":[{"credential":fixture["credential"]}]}),
                )
                .unwrap(),
                selection,
                admission,
                holder_public_jwk_json: holder,
                expires_at: Utc::now() + Duration::seconds(30),
            },
        );
        id
    }

    fn refresh_authority(raw: &str) -> String {
        let now = Utc::now();
        let mut value: Value = serde_json::from_str(raw).unwrap();
        value["observed_at"] = json!(now);
        value["expires_at"] = json!(now + Duration::seconds(30));
        value["issuer"]["generated_at"] = json!(now);
        value["issuer"]["expires_at"] = value["expires_at"].clone();
        value.to_string()
    }

    #[test]
    fn finalization_requires_post_response_authority_and_consumes_every_attempt() {
        let fixture: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        let before = fixture_authority(&fixture);
        let received_at = Utc::now();
        let id = stage_response(&fixture, &before, received_at);
        let error = finalize(&id, &before).err().unwrap();
        assert!(error.to_string().contains("predates"));
        assert!(finalize(&id, &refresh_authority(&before)).is_err());
        assert!(!SLOTS.get().unwrap().lock().unwrap().contains(&id));

        let id = stage_response(&fixture, &before, Utc::now());
        let fresh = refresh_authority(&before);
        let verified = finalize(&id, &fresh).unwrap();
        assert_eq!(verified.credential, fixture["credential"].as_str().unwrap());
        assert!(finalize(&id, &fresh).is_err());
        assert!(!SLOTS.get().unwrap().lock().unwrap().contains(&id));

        for pointer in ["/issuer/revision/version", "/scope/device_id"] {
            let id = stage_response(&fixture, &before, Utc::now());
            let mut changed: Value = serde_json::from_str(&refresh_authority(&before)).unwrap();
            *changed.pointer_mut(pointer).unwrap() = if pointer.ends_with("version") {
                json!(2)
            } else {
                json!("other-device")
            };
            assert!(finalize(&id, &changed.to_string()).is_err());
            assert!(finalize(&id, &refresh_authority(&before)).is_err());
            assert!(!SLOTS.get().unwrap().lock().unwrap().contains(&id));
        }
    }

    #[test]
    fn dropped_receipt_reservation_releases_its_inflight_slot() {
        let slot = ReceiptSlot::reserve().unwrap();
        let id = slot.0.clone();
        assert!(SLOTS.get().unwrap().lock().unwrap().contains(&id));
        drop(slot);
        assert!(!SLOTS.get().unwrap().lock().unwrap().contains(&id));
    }

    #[test]
    fn accepts_one_final_credential_object_or_one_legacy_credential() {
        for value in [
            json!({"credentials": [{"credential": "issued~token~"}]}),
            json!({"credential": "issued~token~"}),
        ] {
            let response = serde_json::from_value(value).unwrap();
            assert_eq!(single_credential(&response).unwrap(), "issued~token~");
        }
    }

    #[test]
    fn rejects_ambiguous_batch_deferred_and_malformed_credential_responses() {
        for value in [
            json!({}),
            json!({"credentials": []}),
            json!({"credentials": [{"credential": "one"}, {"credential": "two"}]}),
            json!({"credential": "one", "credentials": [{"credential": "one"}]}),
            json!({"transaction_id": "deferred", "credentials": [{"credential": "one"}]}),
            json!({"credentials": ["unwrapped-token"]}),
            json!({"credentials": [{}]}),
            json!({"credentials": [{"credential": 42}]}),
            json!({"credentials": [{"credential": ""}]}),
            json!({"credential": {"unverified": true}}),
            json!({"credential": "x".repeat(MAX_CREDENTIAL_BYTES + 1)}),
        ] {
            let response = serde_json::from_value(value).unwrap();
            assert!(single_credential(&response).is_err());
        }
    }

    #[test]
    fn final_response_is_verified_against_governed_trust_and_selected_configuration() {
        let fixture: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        let now = Utc::now();
        let mut issuer_jwk = fixture["issuer_public_jwk"].clone();
        issuer_jwk["kid"] = fixture["issuer_key_id"].clone();
        issuer_jwk["alg"] = json!("ES256");
        let snapshot = json!({
            "organization_id": "org-1",
            "trust_profile_id": "11111111-2222-4333-8444-555555555555",
            "generated_at": now,
            "expires_at": now + Duration::seconds(30),
            "issuer_keys": [{
                "issuer": fixture["issuer"],
                "key_id": fixture["issuer_key_id"],
                "algorithm": "ES256",
                "public_jwk": issuer_jwk
            }]
        })
        .to_string();
        let mut snapshot = super::super::issuer_trust::fixture_envelope(
            serde_json::from_str(&snapshot).unwrap(),
            fixture["holder_public_jwk"].clone(),
            "urn:elevenid:credential:verified-wallet",
        );
        let selection = fixture_selection();
        snapshot["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([{
            "credential_issuer":selection.credential_issuer,
            "credential_configuration_id":selection.credential_configuration_id,
            "format":selection.format,"vct":selection.vct,
            "authorization_server":null,"token_endpoint":null}]);
        let snapshot = snapshot.to_string();
        let holder = fixture["holder_public_jwk"].to_string();
        let response: CredentialResponse = serde_json::from_value(json!({
            "credentials": [{"credential": fixture["credential"]}]
        }))
        .unwrap();
        let admission = admit_issuance(&snapshot, &holder, &selection, now).unwrap();
        let verify = |vct: &str, format: &str| {
            let mut selected = selection.clone();
            selected.vct = vct.into();
            selected.format = format.into();
            verify_receipt(&response, &selected, &admission, &holder, &snapshot)
        };
        let issuer = fixture["issuer"].as_str().unwrap();
        let verified = verify("urn:elevenid:credential:verified-wallet", "vc+sd-jwt").unwrap();
        assert_eq!(verified.credential, fixture["credential"].as_str().unwrap());
        assert_eq!(verified.issuer, issuer);
        // Issuer identity is authenticated through the governed resolver.
        // The OID4VCI service URL need not equal a credential's DID issuer
        // (OID4VCI 1.0 section 14.4); do not invent that equality here.
        for (vct, format, expected_error) in [
            ("OtherCredential", "vc+sd-jwt", "type"),
            (
                "urn:elevenid:credential:verified-wallet",
                "dc+sd-jwt",
                "format",
            ),
        ] {
            let error = verify(vct, format).err().unwrap();
            assert!(
                error.to_string().contains(expected_error)
                    || error.to_string().contains("not authorized")
            );
        }
        let mut other_issuer: Value = serde_json::from_str(&snapshot).unwrap();
        other_issuer["issuer"]["issuer_keys"][0]["issuer"] = json!("did:web:other.example");
        assert!(verify_receipt(
            &response,
            &selection,
            &admission,
            &holder,
            &other_issuer.to_string(),
        )
        .is_err());
    }

    #[test]
    fn configuration_must_name_a_sd_jwt_type() {
        assert!(supported_configuration(&json!({"format": "dc+sd-jwt"})).is_err());
        let supported = json!({
            "format": "dc+sd-jwt",
            "vct": "example",
            "cryptographic_binding_methods_supported": ["jwk"],
            "proof_types_supported": {"jwt": {
                "proof_signing_alg_values_supported": ["ES256"]
            }}
        });
        assert!(supported_configuration(&supported).is_ok());
        for requirement in [
            json!({}),
            json!({"key_storage": []}),
            json!({"key_storage": ["iso_18045"]}),
            json!([]),
            json!(false),
            Value::Null,
        ] {
            let mut unsupported = supported.clone();
            unsupported["proof_types_supported"]["jwt"]["key_attestations_required"] = requirement;
            let error = supported_configuration(&unsupported).unwrap_err();
            assert!(error.to_string().contains("unsupported key attestation"));
        }
    }

    #[test]
    fn issuer_endpoints_cannot_escape_origin() {
        let issuer = https_endpoint("https://issuer.example/tenant").unwrap();
        assert!(issuer_endpoint("https://issuer.example/nonce", &issuer).is_ok());
        assert!(issuer_endpoint("https://other.example/nonce", &issuer).is_err());
        assert!(issuer_endpoint("http://issuer.example/nonce", &issuer).is_err());
    }

    #[tokio::test]
    async fn missing_session_fails_before_network_or_trust_use() {
        let error = complete("missing", &[0; 64], "{}")
            .await
            .err()
            .expect("missing receipt must fail");
        assert!(error.to_string().contains("missing or already consumed"));
    }

    #[tokio::test]
    async fn invalid_remote_signature_consumes_receipt_before_network() {
        let fixture: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        let holder_public_jwk_json = fixture["holder_public_jwk"].to_string();
        let proof = WalletEngine::new()
            .prepare_proof_jwt(
                "fixture-holder",
                "fixture-nonce",
                "https://issuer.example",
                &holder_public_jwk_json,
            )
            .unwrap();
        let slot = ReceiptSlot::reserve().unwrap();
        let session_id = slot.0.clone();
        let snapshot = fixture_authority(&fixture);
        pending().lock().unwrap().insert(
            session_id.clone(),
            PendingReceipt {
                slot,
                proof,
                access_token: "never-sent".into(),
                credential_endpoint: "https://issuer.invalid/credential".into(),
                credential_configuration_id: "fixture".into(),
                selection: fixture_selection(),
                admission: admit_issuance(
                    &snapshot,
                    &holder_public_jwk_json,
                    &fixture_selection(),
                    Utc::now(),
                )
                .unwrap(),
                holder_public_jwk_json,
                expires_at: Utc::now() + Duration::minutes(1),
            },
        );
        assert!(complete(&session_id, &[0; 64], &snapshot).await.is_err());
        let replay = complete(&session_id, &[0; 64], "{}")
            .await
            .err()
            .expect("consumed receipt must fail");
        assert!(replay.to_string().contains("missing or already consumed"));
    }
}
