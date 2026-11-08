//! One-use, verified SD-JWT presentation sessions. Only the exact JWS input
//! crosses to the paired remote signer; issuer and holder keys stay public.

use std::collections::{HashMap, HashSet};
use std::sync::{Mutex, OnceLock};

use anyhow::{bail, ensure, Context};
use chrono::{DateTime, Utc};
use marty_oid4vci::types::SigningAlgorithm;
use marty_oid4vci::{
    jose, ParsedPresentationRequest, PreparedSdJwtPresentation, PresentationRequestQueryType,
    PresentationResponse, ResolvedSdJwtIssuerKey, SdJwtIssuerKeyResolver, TrustedSdJwtIssuerKeys,
    WalletEngine,
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
    let mut canonical = serde_json::to_value(request)?;
    // The resolved serde_json graph enables preserve_order, while PEX formats
    // use HashMap. Independent parses must not bind random map iteration order.
    // Sort every object recursively; array order and parsed values stay bound.
    canonical.sort_all_objects();
    let bytes = serde_json::to_vec(&canonical)?;
    Ok(format!("{:x}", Sha256::digest(bytes)))
}

fn simple_claim_name(claim: &str) -> bool {
    let mut bytes = claim.bytes();
    !claim.is_empty()
        && claim.len() <= 256
        && bytes
            .next()
            .is_some_and(|byte| byte.is_ascii_alphabetic() || byte == b'_')
        && bytes.all(|byte| byte.is_ascii_alphanumeric() || byte == b'_')
}

fn validate_request(
    request: &ParsedPresentationRequest,
    query_id: &str,
) -> anyhow::Result<Vec<String>> {
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
    let claims = match request.query_type {
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
            credential
                .claims
                .iter()
                .map(|claim| claim.path[0].clone())
                .collect::<Vec<_>>()
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
                    formats.keys().any(|format| {
                        matches!(format.as_str(), "dc+sd-jwt" | "vc+sd-jwt" | "sd_jwt_vc")
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
            descriptor
                .constraints
                .fields
                .iter()
                .map(|field| field.path[0][2..].to_string())
                .collect::<Vec<_>>()
        }
    };
    ensure!(
        claims.len() <= 64
            && claims.iter().all(|claim| simple_claim_name(claim))
            && claims.iter().collect::<HashSet<_>>().len() == claims.len(),
        "presentation request claims are unsupported or duplicated"
    );
    Ok(claims)
}

fn validate_disclosures(
    request: &ParsedPresentationRequest,
    query_id: &str,
    selected: &[String],
) -> anyhow::Result<()> {
    let requested = validate_request(request, query_id)?;
    let requested: HashSet<_> = requested.iter().collect();
    let selected_set: HashSet<_> = selected.iter().collect();
    ensure!(
        selected.len() <= 64 && selected_set.len() == selected.len() && selected_set == requested,
        "selected disclosure does not match the approved request"
    );
    Ok(())
}

fn approved_issuer_algorithms(
    request: &ParsedPresentationRequest,
    verified_format: &str,
) -> anyhow::Result<Option<Vec<String>>> {
    // Called only after validate_request and issuer/holder verification. The
    // requested DCQL format must equal the authenticated protected `typ`.
    match request.query_type {
        PresentationRequestQueryType::DcqlQuery => {
            let credential = &request
                .dcql_query
                .as_ref()
                .context("DCQL query is absent")?
                .credentials[0];
            ensure!(
                credential.format == verified_format,
                "verified credential format does not match the approved request"
            );
            Ok(None)
        }
        PresentationRequestQueryType::PresentationDefinition => {
            let descriptor = &request
                .presentation_definition
                .as_ref()
                .context("presentation definition is absent")?
                .input_descriptors[0];
            let Some(formats) = &descriptor.format else {
                return Ok(None);
            };
            // An explicit exact-format rule takes precedence. The legacy
            // sd_jwt_vc alias may accept either supported SD-JWT typ only when
            // no exact-format rule exists; another format's alg list cannot
            // authorize this credential.
            let requirement = formats
                .get(verified_format)
                .or_else(|| formats.get("sd_jwt_vc"))
                .context("verified credential format does not match the approved request")?;
            if let Some(algorithms) = &requirement.alg {
                ensure!(
                    !algorithms.is_empty() && algorithms.len() <= 16,
                    "approved issuer algorithm list is unsupported"
                );
            }
            Ok(requirement.alg.clone())
        }
    }
}

struct PresentationIssuerKeys<'a> {
    trusted: &'a TrustedSdJwtIssuerKeys,
    approved_algorithms: Option<Vec<String>>,
}

impl SdJwtIssuerKeyResolver for PresentationIssuerKeys<'_> {
    fn resolve(
        &self,
        issuer: &str,
        key_id: Option<&str>,
        algorithm: SigningAlgorithm,
    ) -> marty_oid4vci::Oid4vciResult<ResolvedSdJwtIssuerKey> {
        if self.approved_algorithms.as_ref().is_some_and(|algorithms| {
            !algorithms
                .iter()
                .any(|allowed| allowed == algorithm.as_str())
        }) {
            return Err(marty_oid4vci::Oid4vciError::InvalidRequest(
                "credential issuer algorithm does not match the approved request".into(),
            ));
        }
        self.trusted.resolve(issuer, key_id, algorithm)
    }
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
    validate_disclosures(&request, &selection.query_id, &selection.claims_to_disclose)?;
    let trusted = resolver_from_snapshot(&selection.issuer_snapshot_json, Utc::now())?;
    let engine = WalletEngine::new();
    let verified = engine.verify_received_sd_jwt_credential(
        &selection.credential,
        &selection.holder_public_jwk_json,
        &trusted.resolver,
    )?;
    let request_keys = PresentationIssuerKeys {
        trusted: &trusted.resolver,
        approved_algorithms: approved_issuer_algorithms(&request, &verified.format)?,
    };
    let prepared = engine.prepare_verified_sd_jwt_presentation(
        &selection.credential,
        &selection.claims_to_disclose,
        &request.nonce,
        &request.client_id,
        &selection.holder_public_jwk_json,
        &request_keys,
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
    use marty_oid4vci::{DcqlClaimQuery, DcqlCredentialQuery, DcqlQuery};
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
                    format: "vc+sd-jwt".into(),
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
    fn approved_digest_is_stable_across_reparsed_and_reordered_objects() {
        let mut request = dcql_request();
        request.query_type = PresentationRequestQueryType::PresentationDefinition;
        request.dcql_query = None;
        request.presentation_definition = Some(
            serde_json::from_value(json!({
                "id": "legacy-definition",
                "input_descriptors": [{
                    "id": "member",
                    "format": {
                        "vc+sd-jwt": {"alg": ["ES256", "ES384"]},
                        "sd_jwt_vc": {"alg": ["EdDSA"]}
                    },
                    "constraints": {"fields": [{"path": ["$.email"]}]}
                }]
            }))
            .unwrap(),
        );
        let approved = request_digest(&request).unwrap();
        let serialized = serde_json::to_string(&request).unwrap();
        // Each independent deserialization creates a newly seeded PEX HashMap.
        for _ in 0..128 {
            let reparsed = serde_json::from_str(&serialized).unwrap();
            assert_eq!(approved, request_digest(&reparsed).unwrap());
        }
        let mut reordered = serde_json::to_value(&request).unwrap();
        reordered["presentation_definition"]["input_descriptors"][0]["format"] = json!({
            "sd_jwt_vc": {"alg": ["EdDSA"]},
            "vc+sd-jwt": {"alg": ["ES256", "ES384"]}
        });
        let reordered = serde_json::from_value(reordered).unwrap();
        assert_eq!(approved, request_digest(&reordered).unwrap());

        let mut changed = request.clone();
        changed.nonce = "different-nonce".into();
        assert_ne!(approved, request_digest(&changed).unwrap());
        changed = request.clone();
        changed.state = Some("different-state".into());
        assert_ne!(approved, request_digest(&changed).unwrap());
        changed = request;
        changed
            .presentation_definition
            .as_mut()
            .unwrap()
            .input_descriptors[0]
            .format
            .as_mut()
            .unwrap()
            .get_mut("vc+sd-jwt")
            .unwrap()
            .alg = Some(vec!["ES384".into(), "ES256".into()]);
        assert_ne!(
            approved,
            request_digest(&changed).unwrap(),
            "array order stays bound"
        );
    }

    fn request_for_claims(names: &[&str]) -> ParsedPresentationRequest {
        let mut request = dcql_request();
        request.dcql_query.as_mut().unwrap().credentials[0].claims = names
            .iter()
            .enumerate()
            .map(|(index, name)| DcqlClaimQuery {
                id: format!("claim_{index}"),
                path: vec![(*name).into()],
            })
            .collect();
        request
    }

    #[test]
    fn rust_enforces_exact_requested_disclosures() {
        let request = request_for_claims(&["email", "role"]);
        assert!(validate_disclosures(&request, "member", &["role".into(), "email".into()]).is_ok());
        for selected in [
            vec![],
            vec!["email".into()],
            vec!["email".into(), "role".into(), "address".into()],
            vec!["email".into(), "email".into(), "role".into()],
        ] {
            assert!(validate_disclosures(&request, "member", &selected).is_err());
        }
        assert!(validate_disclosures(&dcql_request(), "member", &[]).is_ok());
        assert!(validate_disclosures(&dcql_request(), "member", &["email".into()]).is_err());
    }

    #[test]
    fn rejects_duplicate_or_unsupported_requested_claims() {
        for names in [
            vec!["email", "email"],
            vec!["address.street"],
            vec!["*"],
            vec![""],
            vec!["0email"],
        ] {
            assert!(validate_request(&request_for_claims(&names), "member").is_err());
        }
        let names = (0..65)
            .map(|index| format!("claim_{index}"))
            .collect::<Vec<_>>();
        let names = names.iter().map(String::as_str).collect::<Vec<_>>();
        assert!(validate_request(&request_for_claims(&names), "member").is_err());
    }

    #[test]
    fn disclosure_bypass_fails_before_issuer_trust_or_signing_input() {
        let request = request_for_claims(&["email"]);
        for claims_to_disclose in [vec![], vec!["email".into(), "address".into()]] {
            let selection = Selection {
                request_uri: "openid4vp://unused".into(),
                approved_request_digest: request_digest(&request).unwrap(),
                credential: "not-inspected".into(),
                query_id: "member".into(),
                claims_to_disclose,
                issuer_snapshot_json: "not-inspected".into(),
                holder_public_jwk_json: "not-inspected".into(),
            };
            let error = prepare_for_request(selection, request.clone())
                .err()
                .unwrap();
            assert!(error.to_string().contains("selected disclosure"));
        }
    }

    #[test]
    fn legacy_presentation_exchange_paths_have_the_same_rust_approval_checks() {
        let mut request = dcql_request();
        request.query_type = PresentationRequestQueryType::PresentationDefinition;
        request.dcql_query = None;
        request.presentation_definition = Some(
            serde_json::from_value(json!({
                "id": "legacy-definition",
                "input_descriptors": [{
                    "id": "member",
                    "constraints": {"fields": [{"path": ["$.email"]}]}
                }]
            }))
            .unwrap(),
        );
        assert!(validate_disclosures(&request, "member", &["email".into()]).is_ok());
        assert!(validate_disclosures(&request, "member", &["address".into()]).is_err());
        for path in ["$.", "$.address.street", "$.email[0]", "$.*", "$..email"] {
            request
                .presentation_definition
                .as_mut()
                .unwrap()
                .input_descriptors[0]
                .constraints
                .fields[0]
                .path = vec![path.into()];
            assert!(validate_request(&request, "member").is_err());
        }
    }

    fn signed_selection(request: &ParsedPresentationRequest) -> Selection {
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
        Selection {
            request_uri: "openid4vp://unused".into(),
            approved_request_digest: request_digest(request).unwrap(),
            credential: vector["credential"].as_str().unwrap().into(),
            query_id: "member".into(),
            claims_to_disclose: vec!["email".into()],
            issuer_snapshot_json: snapshot.to_string(),
            holder_public_jwk_json: vector["holder_public_jwk"].to_string(),
        }
    }

    #[test]
    fn signed_public_vector_prepares_exact_input_and_bad_signature_consumes_session() {
        let request = request_for_claims(&["email"]);
        let prepared = prepare_for_request(signed_selection(&request), request).unwrap();
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

    #[test]
    fn authenticated_sd_jwt_type_must_equal_the_approved_dcql_format() {
        let mut request = request_for_claims(&["email"]);
        // The signed fixture's protected typ is vc+sd-jwt. A valid signature
        // and holder binding cannot satisfy an approved dc+sd-jwt request.
        request.dcql_query.as_mut().unwrap().credentials[0].format = "dc+sd-jwt".into();
        let error = prepare_for_request(signed_selection(&request), request)
            .err()
            .unwrap();
        assert!(error.to_string().contains("verified credential format"));
    }

    #[test]
    fn presentation_exchange_binds_the_matching_format_and_issuer_algorithm() {
        for (formats, accepted) in [
            (json!({"vc+sd-jwt": {"alg": ["ES256"]}}), true),
            (json!({"sd_jwt_vc": {"alg": ["ES256"]}}), true),
            (json!({"dc+sd-jwt": {"alg": ["ES256"]}}), false),
            (json!({"vc+sd-jwt": {"alg": ["EdDSA"]}}), false),
            (json!({"vc+sd-jwt": {"alg": []}}), false),
            (
                json!({
                    "vc+sd-jwt": {"alg": ["EdDSA"]},
                    "dc+sd-jwt": {"alg": ["ES256"]},
                    "sd_jwt_vc": {"alg": ["ES256"]}
                }),
                false,
            ),
        ] {
            let mut request = request_for_claims(&["email"]);
            request.query_type = PresentationRequestQueryType::PresentationDefinition;
            request.dcql_query = None;
            request.presentation_definition = Some(
                serde_json::from_value(json!({
                    "id": "legacy-definition",
                    "input_descriptors": [{
                        "id": "member", "format": formats,
                        "constraints": {"fields": [{"path": ["$.email"]}]}
                    }]
                }))
                .unwrap(),
            );
            let result = prepare_for_request(signed_selection(&request), request);
            if accepted {
                let session = result.expect("matching signed format and issuer algorithm");
                pending().lock().unwrap().remove(&session.session_id);
            } else {
                assert!(
                    result.is_err(),
                    "incompatible format or algorithm must be rejected"
                );
            }
        }
    }
}
