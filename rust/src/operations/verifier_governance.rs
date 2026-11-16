//! Native admission of fresh confirmed-device managed verifier evidence.
//! Transport-provided keys do not replace Core DID/signature authentication.
use anyhow::{ensure, Context};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{DateTime, Duration, Utc};
use marty_oid4vci::{
    wallet_request_auth::{AuthenticatedPresentationRequest, GovernedDidVerifierAuthority},
    WalletEngine,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

#[derive(Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub(crate) struct DeviceScope {
    credential_id: String,
    registration_id: String,
    pairing_id: String,
    device_id: String,
    user_id: String,
    pub(crate) organization_id: String,
    pub(crate) issuer_trust_profile_id: String,
    verifier_trust_profile_id: Option<String>,
    pub(crate) credential_expires_at: DateTime<Utc>,
    holder_binding_key: HolderKey,
    presentation_signing_key: HolderKey,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn fixture(now: DateTime<Utc>) -> (Value, String, String) {
        let ec = json!({"kty":"EC","crv":"P-256","x":"axfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpY","y":"T-NC4v4af5uO5-tKfA-eFivOM1drMV7Oy7ZAaDe_UfU"});
        let ed =
            json!({"kty":"OKP","crv":"Ed25519","x":"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo"});
        let id = "11111111-2222-4333-8444-555555555555";
        let profile = "21111111-2222-4333-8444-555555555555";
        let locator = format!("https://verifier.example/v1/flows/instances/{id}/request");
        let recipient = locator.replace("/request", "/submit");
        let key = |jwk: Value, algorithm: &str| json!({"key_id":uuid::Uuid::new_v4().to_string(),"algorithm":algorithm,"version":1,"jwk_thumbprint":thumbprint(&jwk).unwrap(),"public_jwk":jwk});
        let whole = DateTime::from_timestamp(now.timestamp(), 0).unwrap();
        let value = json!({"contract":"marty.wallet/device-verifier-governance/v2","observed_at":now,"expires_at":now+Duration::seconds(30),
            "scope":{"credential_id":id,"registration_id":uuid::Uuid::new_v4().to_string(),"pairing_id":uuid::Uuid::new_v4().to_string(),"device_id":"device-1","user_id":"user-1","organization_id":"org-1",
                "issuer_trust_profile_id":id,"verifier_trust_profile_id":profile,"credential_expires_at":now+Duration::hours(1),
                "holder_binding_key":key(ed,"EdDSA"),"presentation_signing_key":key(ec.clone(),"ES256")},
            "verifier":{"contract":"marty.wallet/verifier-authority/v2","organization_id":"org-1","trust_profile_id":profile,"observed_at":now,"expires_at":now+Duration::seconds(30),
                "authority":{"authority_id":format!("{profile}/{id}"),"revision":"revision-1","key_purpose":"oid4vp_request_signing","algorithm":"ES256","request_clock_skew_seconds":30,"max_request_lifetime_seconds":900,
                    "registration":{"client_id":"decentralized_identifier:did:web:verifier.example","request_key_id":"did:web:verifier.example#key-1","public_jwk":ec,"response_uris":[recipient],"valid_from":whole-Duration::seconds(60),"valid_until":whole+Duration::hours(1)}},
                "request":{"producer_id":"flow-primary","instance_id":id,"request_uri":locator,"response_uri":recipient,"nonce":"nonce-1","compact_request_jws":"synthetic.not.authenticated","request_jws_sha256":format!("{:x}",Sha256::digest(b"synthetic.not.authenticated")),"request_issued_at":whole,"request_expires_at":whole+Duration::seconds(120)}}});
        (value, locator, ec.to_string())
    }
    #[test]
    fn rejects_scope_holder_recipient_digest_and_clock_substitution() {
        let now = Utc::now();
        let (value, locator, holder) = fixture(now);
        assert!(parse(&value.to_string(), &locator, &holder, now).is_ok());
        let mut enrolled: Value = serde_json::from_str(&holder).unwrap();
        enrolled["kid"] = json!("cred-presenter-public-enrollment-reference");
        assert!(parse(&value.to_string(), &locator, &enrolled.to_string(), now).is_ok());
        enrolled["jku"] = json!("https://attacker.example/keys");
        assert!(parse(&value.to_string(), &locator, &enrolled.to_string(), now).is_err());
        for (pointer, replacement) in [
            ("/scope/organization_id", json!("other-org")),
            (
                "/scope/verifier_trust_profile_id",
                json!(uuid::Uuid::new_v4().to_string()),
            ),
            (
                "/scope/presentation_signing_key/jwk_thumbprint",
                json!("forged"),
            ),
            ("/scope/presentation_signing_key/version", json!(0)),
            (
                "/verifier/request/response_uri",
                json!("https://attacker.example"),
            ),
            (
                "/verifier/request/compact_request_jws",
                json!("changed.bytes"),
            ),
            ("/expires_at", json!(now - Duration::seconds(1))),
            (
                "/verifier/authority/key_purpose",
                json!("credential_issuer"),
            ),
        ] {
            let mut changed = value.clone();
            *changed.pointer_mut(pointer).unwrap() = replacement;
            assert!(
                parse(&changed.to_string(), &locator, &holder, now).is_err(),
                "{pointer}"
            );
        }
        let mut private = value.clone();
        private["scope"]["presentation_signing_key"]["public_jwk"]["d"] = json!("forbidden");
        assert!(parse(&private.to_string(), &locator, &holder, now).is_err());
        let duplicate = value.to_string().replacen(
            "\"credential_id\":",
            "\"credential_id\":\"first\",\"credent\\u0069al_id\":",
            1,
        );
        assert!(parse(&duplicate, &locator, &holder, now).is_err());
        assert!(parse(
            &value.to_string(),
            &format!("{locator}?extra"),
            &holder,
            now
        )
        .is_err());
    }
    #[tokio::test]
    async fn well_scoped_transport_evidence_cannot_authenticate_a_forged_request() {
        let now = Utc::now();
        let (value, locator, holder) = fixture(now);
        let checked = parse(&value.to_string(), &locator, &holder, now).unwrap();
        assert!(checked.authenticate().await.is_err());
    }
}
#[derive(Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct HolderKey {
    key_id: String,
    algorithm: String,
    version: i64,
    public_jwk: Value,
    jwk_thumbprint: String,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Envelope {
    contract: String,
    scope: DeviceScope,
    observed_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    verifier: Verifier,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Verifier {
    contract: String,
    organization_id: String,
    trust_profile_id: String,
    observed_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    authority: Authority,
    request: Request,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Authority {
    authority_id: String,
    revision: String,
    key_purpose: String,
    algorithm: String,
    request_clock_skew_seconds: u32,
    max_request_lifetime_seconds: u32,
    registration: Registration,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Registration {
    client_id: String,
    request_key_id: String,
    public_jwk: Value,
    response_uris: Vec<String>,
    valid_from: DateTime<Utc>,
    valid_until: DateTime<Utc>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    producer_id: String,
    instance_id: String,
    request_uri: String,
    response_uri: String,
    nonce: String,
    compact_request_jws: String,
    request_jws_sha256: String,
    request_issued_at: DateTime<Utc>,
    request_expires_at: DateTime<Utc>,
}

pub(crate) struct FreshGovernance {
    pub scope: DeviceScope,
    pub authority: GovernedDidVerifierAuthority,
    pub original_jws: String,
    pub holder_jwk_json: String,
    pub expires_at: DateTime<Utc>,
    request: Request,
}
fn text(v: &str) -> bool {
    !v.is_empty() && v.len() <= 2048 && v.trim() == v && !v.chars().any(char::is_control)
}
fn uuid(v: &str) -> bool {
    uuid::Uuid::parse_str(v).is_ok_and(|id| !id.is_nil() && id.to_string() == v)
}
fn fresh(observed: DateTime<Utc>, expires: DateTime<Utc>, now: DateTime<Utc>) -> bool {
    observed <= now
        && expires > now
        && expires > observed
        && observed
            .checked_add_signed(Duration::seconds(60))
            .is_some_and(|end| expires <= end)
}
pub(crate) fn thumbprint(key: &Value) -> anyhow::Result<String> {
    let object = key.as_object().context("holder key is invalid")?;
    let names = match (key["kty"].as_str(), key["crv"].as_str()) {
        (Some("EC"), Some("P-256")) => vec!["crv", "kty", "x", "y"],
        (Some("OKP"), Some("Ed25519")) => vec!["crv", "kty", "x"],
        _ => anyhow::bail!("holder key is invalid"),
    };
    ensure!(
        object.len() == names.len() && object.keys().all(|name| names.contains(&name.as_str())),
        "holder key is invalid"
    );
    let mut members = std::collections::BTreeMap::new();
    for name in names {
        let value = key[name].as_str().context("holder key is invalid")?;
        if name == "x" || name == "y" {
            let bytes = URL_SAFE_NO_PAD.decode(value)?;
            ensure!(
                bytes.len() == 32 && URL_SAFE_NO_PAD.encode(bytes) == value,
                "holder key is invalid"
            );
        }
        members.insert(name, value);
    }
    Ok(URL_SAFE_NO_PAD.encode(Sha256::digest(serde_json::to_vec(&members)?)))
}

impl DeviceScope {
    pub(crate) fn validate_holder(
        &self,
        current_holder: &str,
        now: DateTime<Utc>,
    ) -> anyhow::Result<String> {
        let scope = self;
        ensure!(
            scope.credential_expires_at > now
                && [
                    scope.credential_id.as_str(),
                    &scope.registration_id,
                    &scope.pairing_id,
                    &scope.issuer_trust_profile_id
                ]
                .iter()
                .all(|v| uuid(v))
                && scope.verifier_trust_profile_id.as_deref().is_none_or(uuid)
                && scope.verifier_trust_profile_id.as_deref()
                    != Some(scope.issuer_trust_profile_id.as_str())
                && text(&scope.device_id)
                && text(&scope.user_id)
                && text(&scope.organization_id),
            "device governance scope is invalid"
        );
        for (key, algorithm) in [
            (&scope.holder_binding_key, "EdDSA"),
            (&scope.presentation_signing_key, "ES256"),
        ] {
            ensure!(
                uuid(&key.key_id)
                    && key.algorithm == algorithm
                    && key.version > 0
                    && key.jwk_thumbprint == thumbprint(&key.public_jwk)?,
                "holder governance is invalid"
            );
            ensure!(
                (algorithm == "ES256" && key.public_jwk["kty"] == "EC")
                    || (algorithm == "EdDSA" && key.public_jwk["kty"] == "OKP"),
                "holder governance algorithm is invalid"
            );
        }
        let holder = marty_crypto::strict_json::parse_unique_json(current_holder.as_bytes())?;
        // Enrollment includes the public provider key ID. It is metadata rather
        // than an RFC7638 member; admit only that one extra, never arbitrary fields.
        let mut canonical_holder = holder.clone();
        if let Some(kid) = canonical_holder
            .as_object_mut()
            .context("holder key is invalid")?
            .remove("kid")
        {
            ensure!(kid.as_str().is_some_and(text), "holder key ID is invalid");
        }
        ensure!(
            thumbprint(&canonical_holder)? == scope.presentation_signing_key.jwk_thumbprint,
            "paired holder key changed"
        );
        Ok(holder.to_string())
    }
}

pub(crate) fn parse(
    raw: &str,
    locator: &str,
    current_holder: &str,
    now: DateTime<Utc>,
) -> anyhow::Result<FreshGovernance> {
    ensure!(
        raw.len() <= 65536 && text(locator),
        "verifier governance is invalid"
    );
    let value = marty_crypto::strict_json::parse_unique_json(raw.as_bytes())?;
    ensure!(
        !super::issuer_trust::contains_private_material(&value),
        "verifier governance is invalid"
    );
    let envelope: Envelope = serde_json::from_value(value)?;
    let scope = &envelope.scope;
    let verifier = &envelope.verifier;
    let verifier_profile = scope
        .verifier_trust_profile_id
        .as_deref()
        .context("verifier profile is absent")?;
    let registration = &verifier.authority.registration;
    let request = &verifier.request;
    ensure!(
        envelope.contract == "marty.wallet/device-verifier-governance/v2"
            && verifier.contract == "marty.wallet/verifier-authority/v2"
            && fresh(envelope.observed_at, envelope.expires_at, now)
            && fresh(verifier.observed_at, verifier.expires_at, now)
            && envelope.expires_at <= verifier.expires_at
            && envelope.expires_at <= scope.credential_expires_at
            && scope.organization_id == verifier.organization_id
            && verifier_profile == verifier.trust_profile_id
            && [
                scope.credential_id.as_str(),
                &scope.registration_id,
                &scope.pairing_id,
                &scope.issuer_trust_profile_id,
                verifier_profile
            ]
            .iter()
            .all(|v| uuid(v))
            && text(&scope.device_id)
            && text(&scope.user_id)
            && text(&scope.organization_id),
        "verifier governance scope is invalid"
    );
    let holder_json = scope.validate_holder(current_holder, now)?;
    let source = verifier
        .authority
        .authority_id
        .strip_prefix(&format!("{verifier_profile}/"))
        .context("verifier authority is invalid")?;
    let did = registration
        .client_id
        .strip_prefix("decentralized_identifier:")
        .context("verifier client is invalid")?;
    let uri = url::Url::parse(locator)?;
    let suffix = format!("/v1/flows/instances/{}/request", request.instance_id);
    let base = locator
        .strip_suffix(&suffix)
        .context("verifier locator is invalid")?;
    let response = format!("{base}/v1/flows/instances/{}/submit", request.instance_id);
    ensure!(
        uuid(source)
            && text(&verifier.authority.revision)
            && verifier.authority.key_purpose == "oid4vp_request_signing"
            && verifier.authority.algorithm == "ES256"
            && verifier.authority.request_clock_skew_seconds == 30
            && verifier.authority.max_request_lifetime_seconds == 900
            && ["did:web:", "did:key:", "did:jwk:"]
                .iter()
                .any(|prefix| did.strip_prefix(prefix).is_some_and(|s| !s.is_empty()))
            && registration
                .request_key_id
                .strip_prefix(&format!("{did}#"))
                .is_some_and(|s| !s.is_empty())
            && uri.scheme() == "https"
            && uri.host_str().is_some()
            && uri.username().is_empty()
            && uri.password().is_none()
            && uri.query().is_none()
            && uri.fragment().is_none()
            && uuid(&request.instance_id)
            && request.request_uri == locator
            && request.response_uri == response
            && registration.response_uris == [response]
            && text(&request.producer_id)
            && text(&request.nonce)
            && !request.compact_request_jws.is_empty()
            && request.request_jws_sha256
                == format!(
                    "{:x}",
                    Sha256::digest(request.compact_request_jws.as_bytes())
                )
            && registration.valid_from <= now
            && registration.valid_until > now
            && registration.valid_from.timestamp_subsec_nanos() == 0
            && registration.valid_until.timestamp_subsec_nanos() == 0
            && verifier.expires_at <= registration.valid_until
            && request.request_issued_at >= registration.valid_from
            && request.request_expires_at <= registration.valid_until
            && request.request_issued_at <= now + Duration::seconds(30)
            && request.request_expires_at > now
            && request.request_expires_at > request.request_issued_at
            && request
                .request_issued_at
                .checked_add_signed(Duration::seconds(900))
                .is_some_and(|end| request.request_expires_at <= end)
            && request.request_expires_at >= verifier.expires_at
            && request.request_issued_at.timestamp_subsec_nanos() == 0
            && request.request_expires_at.timestamp_subsec_nanos() == 0,
        "verifier request evidence is invalid"
    );
    let expires_at = envelope
        .expires_at
        .min(verifier.expires_at)
        .min(request.request_expires_at);
    let authority = GovernedDidVerifierAuthority {
        authority_id: verifier.authority.authority_id.clone(),
        revision: verifier.authority.revision.clone(),
        client_id: registration.client_id.clone(),
        request_key_id: registration.request_key_id.clone(),
        public_jwk_json: registration.public_jwk.to_string(),
        response_uris: registration.response_uris.clone(),
        valid_from: registration.valid_from.timestamp(),
        valid_until: registration.valid_until.timestamp(),
        observed_at: envelope
            .observed_at
            .timestamp()
            .max(verifier.observed_at.timestamp()),
        expires_at: expires_at.timestamp(),
    };
    Ok(FreshGovernance {
        scope: envelope.scope,
        authority,
        original_jws: request.compact_request_jws.clone(),
        holder_jwk_json: holder_json,
        expires_at,
        request: envelope.verifier.request,
    })
}

impl FreshGovernance {
    pub async fn authenticate(&self) -> anyhow::Result<AuthenticatedPresentationRequest> {
        let authenticated = WalletEngine::new()
            .reauthenticate_governed_did_signed_request(&self.original_jws, &self.authority)
            .await?;
        ensure!(
            self.expires_at > Utc::now()
                && authenticated.request().nonce == self.request.nonce
                && authenticated.request().state.as_deref()
                    == Some(self.request.instance_id.as_str())
                && authenticated.request().response_uri == self.request.response_uri,
            "verifier evidence changed"
        );
        ensure!(
            authenticated.expires_at() == self.request.request_expires_at.timestamp(),
            "verifier expiry evidence changed"
        );
        Ok(authenticated)
    }

    pub fn issuer_trust(
        &self,
        raw: &str,
        credential: &str,
    ) -> anyhow::Result<super::issuer_trust::FreshIssuerTrust> {
        let trusted = super::issuer_trust::resolver_from_snapshot(
            raw,
            credential,
            &self.holder_jwk_json,
            Utc::now(),
        )?;
        ensure!(trusted.scope == self.scope, "issuer trust scope changed");
        Ok(trusted)
    }
}
