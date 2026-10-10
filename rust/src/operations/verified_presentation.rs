//! One-use, verified SD-JWT presentation sessions. Only the exact JWS input
//! crosses to the paired remote signer; issuer and holder keys stay public.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use anyhow::{bail, ensure, Context};
use chrono::{DateTime, Utc};
use marty_oid4vci::{
    jose, ParsedPresentationRequest, PreparedSdJwtPresentation, PresentationRequestQueryType,
    PresentationResponse, WalletEngine,
};
use sha2::{Digest, Sha256};

use super::issuer_trust::resolver_from_snapshot;

const MAX_CREDENTIAL_BYTES: usize = 1024 * 1024;
const MAX_PENDING_SESSIONS: usize = 16;

pub(crate) struct Selection {
    pub request_uri: String,
    pub approved_request_digest: String,
    pub credential: String,
    pub query_id: String,
    pub claims_to_disclose: Vec<String>,
    pub issuer_snapshot_json: String,
    pub holder_public_jwk_json: String,
}

pub(crate) struct PreparedSelection {
    pub session_id: String,
    pub signing_input: Vec<u8>,
}

struct PendingSelection {
    prepared: PreparedSdJwtPresentation,
    request: ParsedPresentationRequest,
    query_id: String,
    holder_public_jwk_json: String,
    expires_at: DateTime<Utc>,
}

static PENDING: OnceLock<Mutex<HashMap<String, PendingSelection>>> = OnceLock::new();

fn pending() -> &'static Mutex<HashMap<String, PendingSelection>> {
    PENDING.get_or_init(|| Mutex::new(HashMap::new()))
}

pub(crate) fn request_digest(request: &ParsedPresentationRequest) -> anyhow::Result<String> {
    let canonical = serde_json::to_value(request)?;
    let bytes = serde_json::to_vec(&canonical)?;
    Ok(format!("{:x}", Sha256::digest(bytes)))
}

fn validate_request(request: &ParsedPresentationRequest, query_id: &str) -> anyhow::Result<()> {
    ensure!(
        !request.client_id.trim().is_empty() && !request.nonce.trim().is_empty(),
        "presentation challenge is invalid"
    );
    ensure!(
        request
            .response_mode
            .as_deref()
            .is_none_or(|mode| mode == "direct_post"),
        "presentation response mode is unsupported"
    );
    let response_uri = url::Url::parse(&request.response_uri)?;
    ensure!(
        response_uri.scheme() == "https"
            && response_uri.host_str().is_some()
            && response_uri.username().is_empty()
            && response_uri.password().is_none()
            && response_uri.fragment().is_none(),
        "presentation response URI is invalid"
    );
    match request.query_type {
        PresentationRequestQueryType::DcqlQuery => {
            let query = request
                .dcql_query
                .as_ref()
                .context("DCQL query is absent")?;
            ensure!(
                query.credentials.len() == 1,
                "DCQL query shape is unsupported"
            );
            let credential = &query.credentials[0];
            ensure!(
                credential.id == query_id
                    && matches!(credential.format.as_str(), "dc+sd-jwt" | "vc+sd-jwt")
                    && credential.meta.is_none(),
                "selected credential does not match the DCQL query"
            );
            ensure!(
                credential
                    .claims
                    .iter()
                    .all(|claim| claim.path.len() == 1 && !claim.path[0].is_empty()),
                "DCQL claim path is unsupported"
            );
        }
        PresentationRequestQueryType::PresentationDefinition => {
            let definition = request
                .presentation_definition
                .as_ref()
                .context("presentation definition is absent")?;
            ensure!(
                definition.input_descriptors.len() == 1,
                "presentation definition shape is unsupported"
            );
            let descriptor = &definition.input_descriptors[0];
            ensure!(
                descriptor.id == query_id,
                "selected descriptor does not match"
            );
            if let Some(formats) = &descriptor.format {
                ensure!(
                    formats.iter().any(|(format, requirement)| {
                        matches!(format.as_str(), "dc+sd-jwt" | "vc+sd-jwt" | "sd_jwt_vc")
                            && requirement.alg.as_ref().is_none_or(|algorithms| {
                                algorithms.iter().any(|alg| alg == "ES256")
                            })
                    }),
                    "selected descriptor does not accept SD-JWT"
                );
            }
            ensure!(
                descriptor.constraints.fields.iter().all(|field| {
                    field.filter.is_none()
                        && field.zk_predicate.is_none()
                        && field.optional != Some(true)
                        && field.path.len() == 1
                        && field.path[0].starts_with("$.")
                }),
                "presentation field constraint is unsupported"
            );
        }
    }
    Ok(())
}

pub(crate) async fn prepare(selection: Selection) -> anyhow::Result<PreparedSelection> {
    ensure!(
        !selection.request_uri.is_empty() && selection.request_uri.len() <= 8192,
        "presentation request URI is invalid"
    );
    ensure!(
        !selection.credential.is_empty() && selection.credential.len() <= MAX_CREDENTIAL_BYTES,
        "selected credential is invalid"
    );
    ensure!(
        !selection.query_id.is_empty() && selection.query_id.len() <= 256,
        "selected query ID is invalid"
    );
    ensure!(
        selection.claims_to_disclose.len() <= 64
            && selection
                .claims_to_disclose
                .iter()
                .all(|claim| !claim.is_empty() && claim.len() <= 256),
        "selected claims are invalid"
    );

    let request = WalletEngine::new()
        .parse_presentation_request(&selection.request_uri)
        .await?;
    prepare_for_request(selection, request)
}

fn prepare_for_request(
    selection: Selection,
    request: ParsedPresentationRequest,
) -> anyhow::Result<PreparedSelection> {
    ensure!(
        selection.approved_request_digest == request_digest(&request)?,
        "presentation request changed after approval"
    );
    validate_request(&request, &selection.query_id)?;
    let trusted = resolver_from_snapshot(&selection.issuer_snapshot_json, Utc::now())?;
    let prepared = WalletEngine::new().prepare_verified_sd_jwt_presentation(
        &selection.credential,
        &selection.claims_to_disclose,
        &request.nonce,
        &request.client_id,
        &selection.holder_public_jwk_json,
        &trusted.resolver,
    )?;
    let signing_input = prepared.signing_input().to_vec();
    ensure!(
        !signing_input.is_empty() && signing_input.len() <= 64 * 1024,
        "presentation signing input is invalid"
    );

    let session_id = uuid::Uuid::new_v4().to_string();
    let mut sessions = pending()
        .lock()
        .map_err(|_| anyhow::anyhow!("presentation sessions are unavailable"))?;
    let now = Utc::now();
    sessions.retain(|_, session| session.expires_at > now);
    ensure!(trusted.expires_at > now, "issuer trust snapshot expired");
    ensure!(
        sessions.len() < MAX_PENDING_SESSIONS,
        "too many pending presentations"
    );
    ensure!(
        !sessions.contains_key(&session_id),
        "presentation session collision"
    );
    sessions.insert(
        session_id.clone(),
        PendingSelection {
            prepared,
            request,
            query_id: selection.query_id,
            holder_public_jwk_json: selection.holder_public_jwk_json,
            expires_at: trusted.expires_at,
        },
    );
    Ok(PreparedSelection {
        session_id,
        signing_input,
    })
}

pub(crate) async fn complete(
    session_id: &str,
    remote_signature: &[u8],
) -> anyhow::Result<PresentationResponse> {
    let pending = pending()
        .lock()
        .map_err(|_| anyhow::anyhow!("presentation sessions are unavailable"))?
        .remove(session_id)
        .context("presentation session is missing or already consumed")?;
    ensure!(
        pending.expires_at > Utc::now(),
        "issuer trust snapshot expired"
    );
    ensure!(
        remote_signature.len() == 64,
        "remote ES256 signature is invalid"
    );
    let signing_input = pending.prepared.signing_input();
    if !jose::verify_detached_signature_with_public_jwk(
        signing_input,
        remote_signature,
        &pending.holder_public_jwk_json,
        "ES256",
    )? {
        bail!("remote signature does not match the paired public key");
    }
    let presentation = pending.prepared.complete(remote_signature)?;
    let engine = WalletEngine::new();
    let (vp_token, submission) = engine.build_presentation_for_request(
        &pending.request,
        HashMap::from([(pending.query_id, presentation)]),
    )?;
    engine
        .submit_presentation_for_request(&pending.request, &vp_token, submission.as_ref())
        .await
        .map_err(Into::into)
}

#[cfg(test)]
mod tests {
    use super::*;
    use marty_oid4vci::{DcqlCredentialQuery, DcqlQuery};
    use serde_json::json;

    fn dcql_request() -> ParsedPresentationRequest {
        ParsedPresentationRequest {
            client_id: "https://verifier.example".into(),
            nonce: "nonce-1".into(),
            response_uri: "https://verifier.example/response".into(),
            response_mode: Some("direct_post".into()),
            state: Some("state-1".into()),
            query_type: PresentationRequestQueryType::DcqlQuery,
            presentation_definition: None,
            dcql_query: Some(DcqlQuery {
                credentials: vec![DcqlCredentialQuery {
                    id: "member".into(),
                    format: "dc+sd-jwt".into(),
                    meta: None,
                    claims: vec![],
                }],
            }),
        }
    }

    #[test]
    fn request_binding_rejects_changed_query_id_and_insecure_response() {
        let mut request = dcql_request();
        let approved = request_digest(&request).unwrap();
        assert!(validate_request(&request, "member").is_ok());
        assert!(validate_request(&request, "other").is_err());
        request.dcql_query.as_mut().unwrap().credentials[0].meta = Some(json!({
            "vct_values": ["https://example.invalid/other"]
        }));
        assert!(validate_request(&request, "member").is_err());
        request.dcql_query.as_mut().unwrap().credentials[0].meta = None;
        request.state = Some("changed-state".into());
        assert_ne!(approved, request_digest(&request).unwrap());
        request.response_uri = "http://verifier.example/response".into();
        assert!(validate_request(&request, "member").is_err());
    }

    #[test]
    fn signed_public_vector_prepares_exact_input_and_bad_signature_consumes_session() {
        let vector: serde_json::Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        let now = Utc::now();
        let mut issuer_jwk = vector["issuer_public_jwk"].clone();
        issuer_jwk["kid"] = vector["issuer_key_id"].clone();
        issuer_jwk["alg"] = json!("ES256");
        let snapshot = json!({
            "organization_id": "org-1",
            "trust_profile_id": "11111111-2222-4333-8444-555555555555",
            "generated_at": now,
            "expires_at": now + chrono::Duration::seconds(30),
            "issuer_keys": [{
                "issuer": vector["issuer"],
                "key_id": vector["issuer_key_id"],
                "algorithm": "ES256",
                "public_jwk": issuer_jwk
            }]
        });
        let selected = Selection {
            request_uri: "openid4vp://unused".into(),
            approved_request_digest: request_digest(&dcql_request()).unwrap(),
            credential: vector["credential"].as_str().unwrap().into(),
            query_id: "member".into(),
            claims_to_disclose: vec!["email".into()],
            issuer_snapshot_json: snapshot.to_string(),
            holder_public_jwk_json: vector["holder_public_jwk"].to_string(),
        };
        let prepared = prepare_for_request(selected, dcql_request()).unwrap();
        assert!(!prepared.signing_input.is_empty());
        let runtime = tokio::runtime::Builder::new_current_thread()
            .build()
            .unwrap();
        assert!(runtime
            .block_on(complete(&prepared.session_id, &[0; 64]))
            .is_err());
        assert!(runtime
            .block_on(complete(&prepared.session_id, &[0; 64]))
            .is_err());
    }
}
