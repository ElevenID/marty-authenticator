//! One-use OID4VCI receipt with an opaque, remote P-256 holder signer.
//! The access token stays inside Rust; only the exact public-key proof input
//! crosses the bridge. A credential is returned only after issuer and holder
//! signatures have been verified against fresh pairing trust.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use anyhow::{ensure, Context};
use chrono::{DateTime, Duration, Utc};
use marty_oid4vci::types::SigningAlgorithm;
use marty_oid4vci::wallet::PreparedHolderProof;
use marty_oid4vci::WalletEngine;
use serde_json::Value;

use super::issuer_trust::resolver_from_snapshot;

const MAX_PENDING: usize = 16;
const MAX_OFFER_BYTES: usize = 8192;
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
    proof: PreparedHolderProof,
    access_token: String,
    credential_endpoint: String,
    credential_configuration_id: String,
    expected_format: String,
    expected_vct: String,
    holder_public_jwk_json: String,
    expires_at: DateTime<Utc>,
}

static PENDING: OnceLock<Mutex<HashMap<String, PendingReceipt>>> = OnceLock::new();

fn pending() -> &'static Mutex<HashMap<String, PendingReceipt>> {
    PENDING.get_or_init(|| Mutex::new(HashMap::new()))
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
) -> anyhow::Result<PreparedReceipt> {
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
    let token_endpoint = engine.resolve_token_endpoint(&metadata).await?;
    https_endpoint(&token_endpoint)?;
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
    let session_id = uuid::Uuid::new_v4().to_string();
    let now = Utc::now();
    ensure!(
        token_expires_at > now,
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
            proof,
            access_token: token.access_token,
            credential_endpoint,
            credential_configuration_id: configuration_id,
            expected_format: format.to_string(),
            expected_vct: expected_vct.to_string(),
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
    if let Some(attestation) = proof.get("key_attestations_required") {
        let required = attestation
            .as_object()
            .context("key attestation requirements are invalid")?;
        ensure!(
            required
                .values()
                .all(|value| value.as_array().is_some_and(Vec::is_empty)),
            "issuer requires an unsupported key attestation"
        );
    }
    Ok((format, vct))
}

pub(crate) async fn complete(
    session_id: &str,
    remote_signature: &[u8],
    issuer_snapshot_json: &str,
) -> anyhow::Result<VerifiedReceipt> {
    let session = pending()
        .lock()
        .map_err(|_| anyhow::anyhow!("issuance sessions are unavailable"))?
        .remove(session_id)
        .context("issuance session is missing or already consumed")?;
    ensure!(session.expires_at > Utc::now(), "issuance session expired");
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
    ensure!(
        response.transaction_id.is_none(),
        "deferred issuance is unsupported"
    );
    ensure!(
        response.credentials.is_none(),
        "batch issuance is unsupported"
    );
    let credential = response
        .credential
        .as_ref()
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty() && value.len() <= MAX_CREDENTIAL_BYTES)
        .context("issuer did not return one bounded SD-JWT")?;
    let trusted = resolver_from_snapshot(issuer_snapshot_json, Utc::now())?;
    let verified = engine.verify_received_sd_jwt_credential(
        credential,
        &session.holder_public_jwk_json,
        &trusted.resolver,
    )?;
    ensure!(
        verified.credential_type == session.expected_vct,
        "issued credential type does not match the selected configuration"
    );
    ensure!(
        verified.format == session.expected_format,
        "issued credential format does not match the selected configuration"
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

    #[test]
    fn configuration_must_name_a_sd_jwt_type() {
        assert!(supported_configuration(&json!({"format": "dc+sd-jwt"})).is_err());
        let supported = json!({
            "format": "dc+sd-jwt",
            "vct": "example",
            "cryptographic_binding_methods_supported": ["jwk"],
            "proof_types_supported": {"jwt": {
                "proof_signing_alg_values_supported": ["ES256"],
                "key_attestations_required": {}
            }}
        });
        assert!(supported_configuration(&supported).is_ok());
        let mut unsupported = supported;
        unsupported["proof_types_supported"]["jwt"]["key_attestations_required"] =
            json!({"key_storage": ["iso_18045"]});
        assert!(supported_configuration(&unsupported).is_err());
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
        let session_id = uuid::Uuid::new_v4().to_string();
        pending().lock().unwrap().insert(
            session_id.clone(),
            PendingReceipt {
                proof,
                access_token: "never-sent".into(),
                credential_endpoint: "https://issuer.invalid/credential".into(),
                credential_configuration_id: "fixture".into(),
                expected_format: "dc+sd-jwt".into(),
                expected_vct: "fixture".into(),
                holder_public_jwk_json,
                expires_at: Utc::now() + Duration::minutes(1),
            },
        );
        assert!(complete(&session_id, &[0; 64], "{}").await.is_err());
        let replay = complete(&session_id, &[0; 64], "{}")
            .await
            .err()
            .expect("consumed receipt must fail");
        assert!(replay.to_string().contains("missing or already consumed"));
    }
}
