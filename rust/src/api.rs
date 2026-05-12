//! Flutter Rust Bridge API surface.
//!
//! This module defines the public API that Flutter can call via FFI.
//! These are the entry points for all credential operations.

use crate::credential::{
    Credential, CredentialGroup, MDocCredential, PrivacyLevel, SelectableCredential,
    SdJwtCredential, TrustInfo, VerifiableCredential,
};
use crate::trust;
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
// Required: sync_policies() returns Vec<PresentationPolicy>; frb_generated.rs
// also needs this type in scope for its SseDecode impl.
pub use marty_verification::policy::PresentationPolicy;

// ============================================================================
// Credential Parsing
// ============================================================================

/// Parse a raw JSON string into a VerifiableCredential.
pub fn parse_verifiable_credential(json: String) -> anyhow::Result<VerifiableCredential> {
    use crate::credential::CredentialSubject;

    // First parse as generic JSON to extract claims
    let raw: serde_json::Value = serde_json::from_str(&json)
        .map_err(|e| anyhow::anyhow!("Credential parsing failed: {}", e))?;

    // Parse the basic VC structure
    let mut vc: VerifiableCredential = serde_json::from_str(&json)
        .map_err(|e| anyhow::anyhow!("Credential parsing failed: {}", e))?;

    // Extract and serialize credentialSubject claims
    if let Some(subject) = raw.get("credentialSubject") {
        let subject_id = subject.get("id").and_then(|v| v.as_str()).map(String::from);

        // Get all claims except 'id'
        let claims: std::collections::HashMap<String, serde_json::Value> = if let Some(obj) = subject.as_object() {
            obj.iter()
                .filter(|(k, _)| *k != "id")
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect()
        } else {
            std::collections::HashMap::new()
        };

        vc.subject = CredentialSubject {
            id: subject_id,
            claims_json: serde_json::to_string(&claims).unwrap_or_else(|_| "{}".to_string()),
        };
    }

    vc.raw_json = Some(json);
    Ok(vc)
}

/// Parse CBOR bytes into an MDocCredential.
pub fn parse_mdoc_credential(cbor_bytes: Vec<u8>) -> anyhow::Result<MDocCredential> {
    // Use marty-verification's mDoc parsing
    let parsed = marty_verification::mdoc::parse_device_response(&cbor_bytes)
        .map_err(|e| anyhow::anyhow!("Credential parsing failed: {}", e))?;

    // Convert to our domain model
    let doc = parsed
        .documents
        .first()
        .ok_or_else(|| anyhow::anyhow!("Credential parsing failed: No documents in response"))?;

    let mut namespaces = std::collections::HashMap::new();
    for (ns, items) in &doc.namespaces {
        let mut claim_map = std::collections::HashMap::new();
        for item in items {
            claim_map.insert(
                item.element_identifier.clone(),
                item.element_value.clone(),
            );
        }
        namespaces.insert(ns.clone(), claim_map);
    }

    // Extract claims before moving namespaces into the struct
    let issuing_authority = extract_claim(&namespaces, "org.iso.18013.5.1", "issuing_authority")
        .unwrap_or_else(|| "Unknown".to_string());
    let issuing_country = extract_claim(&namespaces, "org.iso.18013.5.1", "issuing_country")
        .unwrap_or_else(|| "Unknown".to_string());
    let expiry_date = extract_claim(&namespaces, "org.iso.18013.5.1", "expiry_date");
    let portrait = extract_claim(&namespaces, "org.iso.18013.5.1", "portrait");
    let signature = extract_claim(&namespaces, "org.iso.18013.5.1", "signature_usual_mark");

    // Serialize namespaces to JSON string for FFI compatibility
    let namespaces_json = serde_json::to_string(&namespaces)
        .unwrap_or_else(|_| "{}".to_string());

    Ok(MDocCredential {
        id: uuid::Uuid::new_v4().to_string(), // Generate unique ID
        doc_type: doc.doc_type.clone(),
        issuing_authority,
        issuing_country,
        expiry_date,
        namespaces_json,
        trust_info: None,
        portrait,
        signature,
    })
}

fn extract_claim(
    namespaces: &std::collections::HashMap<String, std::collections::HashMap<String, serde_json::Value>>,
    namespace: &str,
    claim: &str,
) -> Option<String> {
    namespaces
        .get(namespace)
        .and_then(|ns| ns.get(claim))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

/// Parse SD-JWT string into an SdJwtCredential.
pub fn parse_sd_jwt_credential(sd_jwt: String) -> anyhow::Result<SdJwtCredential> {
    use ssi_sd_jwt::SdJwt;
    use ssi_claims::jwt::{Issuer, Subject, IssuedAt, ExpirationTime};

    // Parse the SD-JWT using ssi-sd-jwt
    let sd_jwt_ref = SdJwt::new(&sd_jwt)
        .map_err(|e| anyhow::anyhow!("Credential parsing failed: Invalid SD-JWT format: {:?}", e.0))?;

    // Decode and reveal claims
    let revealed = sd_jwt_ref.decode_reveal_any()
        .map_err(|e| anyhow::anyhow!("Credential parsing failed: Failed to reveal SD-JWT claims: {}", e))?;

    // Extract JWT claims
    let claims = revealed.claims();

    // Extract issuer from registered claims (Issuer wraps StringOrURI, which wraps the value)
    let issuer = claims.registered.get::<Issuer>()
        .map(|iss| iss.0.as_str().to_string())
        .unwrap_or_else(|| "unknown".to_string());

    // Extract issuance date (iat) from registered claims (IssuedAt wraps NumericDate)
    let issuance_date = claims.registered.get::<IssuedAt>()
        .map(|iat| {
            chrono::DateTime::from_timestamp(iat.0.as_seconds() as i64, 0)
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_else(|| chrono::Utc::now().to_rfc3339())
        })
        .unwrap_or_else(|| chrono::Utc::now().to_rfc3339());

    // Extract expiration date (exp) from registered claims (ExpirationTime wraps NumericDate)
    let expiration_date = claims.registered.get::<ExpirationTime>().map(|exp| {
        chrono::DateTime::from_timestamp(exp.0.as_seconds() as i64, 0)
            .map(|dt| dt.to_rfc3339())
            .unwrap_or_else(|| "invalid".to_string())
    });

    // Extract disclosed claims from the revealed payload (private claims)
    let mut disclosed_claims = std::collections::HashMap::new();
    // Convert the AnyClaims to a JSON value and extract claims
    if let Ok(value) = serde_json::to_value(&claims.private) {
        if let Some(obj) = value.as_object() {
            for (key, val) in obj {
                // Skip SD-JWT specific fields
                if key != "_sd" && key != "_sd_alg" {
                    disclosed_claims.insert(key.clone(), val.clone());
                }
            }
        }
    }

    // Serialize disclosed claims to JSON string for FFI compatibility
    let disclosed_claims_json = serde_json::to_string(&disclosed_claims)
        .unwrap_or_else(|_| "{}".to_string());

    // Get disclosable claims from the disclosure map
    let disclosable_claims: Vec<String> = revealed.disclosures
        .iter()
        .filter_map(|(pointer, _disclosure)| {
            // Extract the claim name from the JSON pointer
            pointer.as_str().split('/').last().map(|s| s.to_string())
        })
        .collect();

    // Check for key binding (via disclosures since parts() doesn't expose it directly)
    let key_binding: Option<String> = None; // Key binding detection requires JWT header inspection

    // Extract subject as ID if present (Subject wraps StringOrURI)
    let id = claims.registered.get::<Subject>()
        .map(|sub| sub.0.as_str().to_string())
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    // Determine types from the VC claims if present
    let types = disclosed_claims
        .get("type")
        .or_else(|| disclosed_claims.get("vct"))
        .and_then(|v| {
            if let Some(arr) = v.as_array() {
                Some(arr.iter().filter_map(|t| t.as_str().map(String::from)).collect())
            } else if let Some(s) = v.as_str() {
                Some(vec![s.to_string()])
            } else {
                None
            }
        })
        .unwrap_or_else(|| vec!["VerifiableCredential".to_string()]);

    Ok(SdJwtCredential {
        id,
        types,
        issuer,
        issuance_date,
        expiration_date,
        disclosed_claims_json,
        disclosable_claims,
        key_binding,
    })
}

// ============================================================================
// Trust Chain Verification
// ============================================================================

/// Verify mDoc trust chain from X.509 certificate chain.
pub fn verify_mdoc_trust_chain(x5chain: Vec<Vec<u8>>) -> anyhow::Result<TrustInfo> {
    trust::verify_mdoc_trust(&x5chain)
}

/// Verify and attach trust info to an mDoc credential.
pub fn verify_and_attach_trust(
    mut mdoc: MDocCredential,
    x5chain: Vec<Vec<u8>>,
) -> anyhow::Result<MDocCredential> {
    let trust_info = trust::verify_mdoc_trust(&x5chain)?;
    mdoc.trust_info = Some(trust_info);
    Ok(mdoc)
}

// ============================================================================
// Credential Grouping & Selection
// ============================================================================

/// Group credentials by issuer for stacked display.
pub fn group_credentials_by_issuer(credentials: Vec<Credential>) -> Vec<CredentialGroup> {
    let mut groups: std::collections::HashMap<String, CredentialGroup> =
        std::collections::HashMap::new();

    for cred in credentials {
        let issuer = cred.issuer().to_string();
        let group = groups.entry(issuer.clone()).or_insert_with(|| CredentialGroup {
            issuer: issuer.clone(),
            issuer_name: issuer.clone(), // TODO: Resolve from metadata
            credentials: vec![],
            logo_url: None,
        });
        group.credentials.push(cred);
    }

    groups.into_values().collect()
}

/// Create a selectable credential for presentation UI.
pub fn create_selectable_credential(
    credential: Credential,
    privacy_level: PrivacyLevel,
) -> SelectableCredential {
    SelectableCredential {
        credential,
        is_selected: false,
        selected_claims: vec![],
        privacy_level,
    }
}

// ============================================================================
// Credential Validation
// ============================================================================

/// Check if a credential is expired.
pub fn is_credential_expired(credential: &Credential) -> bool {
    credential.is_expired()
}

/// Get all claim names from a credential.
pub fn get_credential_claims(credential: &Credential) -> Vec<String> {
    match credential {
        Credential::VerifiableCredential(vc) => {
            // Parse claims from JSON string
            serde_json::from_str::<std::collections::HashMap<String, serde_json::Value>>(&vc.subject.claims_json)
                .map(|m| m.keys().cloned().collect())
                .unwrap_or_default()
        }
        Credential::MDoc(mdoc) => {
            // Parse namespaces from JSON string
            serde_json::from_str::<std::collections::HashMap<String, std::collections::HashMap<String, serde_json::Value>>>(&mdoc.namespaces_json)
                .map(|ns| ns.values().flat_map(|m| m.keys().cloned()).collect())
                .unwrap_or_default()
        }
        Credential::SdJwt(sd) => {
            // Parse disclosed claims from JSON string
            serde_json::from_str::<std::collections::HashMap<String, serde_json::Value>>(&sd.disclosed_claims_json)
                .map(|m| m.keys().cloned().collect())
                .unwrap_or_default()
        }
    }
}

// ============================================================================
// Serialization
// ============================================================================

/// Serialize a credential to JSON for storage.
pub fn credential_to_json(credential: &Credential) -> anyhow::Result<String> {
    serde_json::to_string(credential)
        .map_err(|e| anyhow::anyhow!("Internal error: {}", e))
}

/// Deserialize a credential from JSON.
pub fn credential_from_json(json: String) -> anyhow::Result<Credential> {
    serde_json::from_str(&json)
        .map_err(|e| anyhow::anyhow!("Credential parsing failed: {}", e))
}

// ============================================================================
// Policy Operations
// ============================================================================

/// Sync presentation policies from backend API.
///
/// # Arguments
/// * `license_jwt` - License JWT for authentication
/// * `endpoint` - Backend API endpoint (e.g., "https://api.example.com")
pub async fn sync_policies(
    license_jwt: String,
    endpoint: String,
) -> anyhow::Result<Vec<marty_verification::policy::PresentationPolicy>> {
    use marty_sync::PolicySyncProvider;

    let provider = PolicySyncProvider::new(endpoint, license_jwt);
    let policies = provider.fetch_all().await
        .map_err(|e| anyhow::anyhow!("Policy sync failed: {}", e))?;

    Ok(policies)
}

/// Evaluate a presentation request against policies and available credentials.
///
/// Returns the minimum disclosure set and any policy violations.
pub fn evaluate_presentation_request(
    request_json: String,
    policies_json: Vec<String>,
    credentials: Vec<Credential>,
) -> anyhow::Result<PolicyEvaluationResult> {
    use marty_verification::policy::{PresentationPolicy, MinimumDisclosureResolver};
    use std::collections::HashMap;

    // Parse policies
    let policies: Vec<PresentationPolicy> = policies_json
        .iter()
        .map(|json| serde_json::from_str(json))
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| anyhow::anyhow!("Failed to parse policies: {}", e))?;

    // For now, use first policy (TODO: match by verifier ID)
    let policy = policies.first()
        .ok_or_else(|| anyhow::anyhow!("No policies provided"))?;

    // Get all available claims from credentials
    let mut all_claims = Vec::new();
    for cred in &credentials {
        all_claims.extend(get_credential_claims(cred));
    }

    // Resolve minimum disclosure
    let resolver = MinimumDisclosureResolver::new(policy);
    let disclosure = resolver.resolve(&all_claims);

    Ok(PolicyEvaluationResult {
        is_satisfied: disclosure.is_complete(),
        minimum_disclosure_claims: disclosure.claims,
        missing_required_claims: disclosure.missing_required,
        policy_id: policy.id.clone(),
    })
}

/// Get the minimum set of claims to disclose from a credential based on policy.
pub fn get_minimum_disclosure_set(
    policy_json: String,
    credential: Credential,
) -> anyhow::Result<Vec<String>> {
    use marty_verification::policy::{PresentationPolicy, MinimumDisclosureResolver};

    let policy: PresentationPolicy = serde_json::from_str(&policy_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse policy: {}", e))?;

    let available_claims = get_credential_claims(&credential);
    let resolver = MinimumDisclosureResolver::new(&policy);
    let disclosure = resolver.resolve(&available_claims);

    Ok(disclosure.claims)
}

/// Rank credentials according to policy preferences.
pub fn rank_matching_credentials(
    policy_json: String,
    credentials: Vec<RankableCredentialInput>,
) -> anyhow::Result<Vec<String>> {
    use marty_verification::policy::{PresentationPolicy, CredentialRanker};
    use marty_verification::policy::ranking::RankableCredential;
    use std::time::{SystemTime, UNIX_EPOCH};

    let policy: PresentationPolicy = serde_json::from_str(&policy_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse policy: {}", e))?;

    let ranker = CredentialRanker::new(&policy);

    let mut rankable: Vec<RankableCredential> = credentials
        .into_iter()
        .map(|c| {
            let issued_at = SystemTime::UNIX_EPOCH + std::time::Duration::from_secs(c.issued_at_unix as u64);
            RankableCredential {
                credential_id: c.credential_id,
                issuer_id: c.issuer_id,
                issued_at,
                trust_level: c.trust_level,
                claim_count: c.claim_count,
            }
        })
        .collect();

    ranker.rank(&mut rankable);

    Ok(rankable.into_iter().map(|r| r.credential_id).collect())
}

/// Check issuer constraints against policy.
pub fn check_issuer_constraints(
    policy_json: String,
    issuer_id: String,
    trust_profile_verified: bool,
) -> anyhow::Result<IssuerCheckResultOutput> {
    use marty_verification::policy::{PresentationPolicy, IssuerConstraintChecker};
    use marty_verification::policy::issuer::IssuerCheckResult;

    let policy: PresentationPolicy = serde_json::from_str(&policy_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse policy: {}", e))?;

    let checker = IssuerConstraintChecker::new(
        policy.trust_profile_id.as_ref(),
        &policy.allowed_issuers,
    );

    let result = checker.check_issuer(&issuer_id, trust_profile_verified);

    Ok(IssuerCheckResultOutput {
        is_trusted: result.is_trusted(),
        violation_message: result.violation_message().map(String::from),
    })
}

// ============================================================================
// Policy Support Types
// ============================================================================

/// Result of policy evaluation for FFI.
#[derive(Debug, Clone)]
pub struct PolicyEvaluationResult {
    pub is_satisfied: bool,
    pub minimum_disclosure_claims: Vec<String>,
    pub missing_required_claims: Vec<String>,
    pub policy_id: String,
}

/// Input for credential ranking.
#[derive(Debug, Clone)]
pub struct RankableCredentialInput {
    pub credential_id: String,
    pub issuer_id: String,
    pub issued_at_unix: i64,
    pub trust_level: f64,
    pub claim_count: usize,
}

/// Result of issuer constraint check.
#[derive(Debug, Clone)]
pub struct IssuerCheckResultOutput {
    pub is_trusted: bool,
    pub violation_message: Option<String>,
}
// ============================================================================
// OID4VCI / OID4VP — FFI-safe DTOs
// ============================================================================

/// Parsed credential offer returned to Flutter.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbCredentialOffer {
    pub credential_issuer: String,
    pub credential_configuration_ids: Vec<String>,
    pub pre_authorized_code: Option<String>,
    pub tx_code_required: bool,
    pub issuer_state: Option<String>,
}

/// Wallet-relevant issuer metadata.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbIssuerMetadata {
    pub credential_issuer: String,
    pub token_endpoint: String,
    pub credential_endpoint: String,
    pub authorization_endpoint: Option<String>,
    pub grant_types_supported: Vec<String>,
    pub credential_configurations_json: String,
}

impl From<marty_oid4vci::IssuerMetadata> for FrbIssuerMetadata {
    fn from(m: marty_oid4vci::IssuerMetadata) -> Self {
        let token_endpoint = m.token_endpoint();
        let credential_configurations_json =
            serde_json::to_string(&m.credential_configurations_supported)
                .unwrap_or_else(|_| "{}".to_string());
        Self {
            credential_issuer: m.credential_issuer,
            token_endpoint,
            credential_endpoint: m.credential_endpoint,
            authorization_endpoint: m.authorization_endpoint,
            grant_types_supported: m.grant_types_supported,
            credential_configurations_json,
        }
    }
}

/// OAuth 2.0 / OID4VCI token response.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbTokenResponse {
    pub access_token: String,
    pub token_type: String,
    pub expires_in: Option<u64>,
    pub c_nonce: Option<String>,
    pub c_nonce_expires_in: Option<u64>,
    pub scope: Option<String>,
}

impl From<marty_oid4vci::types::TokenResponse> for FrbTokenResponse {
    fn from(t: marty_oid4vci::types::TokenResponse) -> Self {
        Self {
            access_token: t.access_token,
            token_type: t.token_type,
            expires_in: Some(t.expires_in),
            c_nonce: t.nonce,
            c_nonce_expires_in: t.nonce_expires_in,
            scope: t.scope,
        }
    }
}

/// Everything Flutter needs to open the authorization redirect URL.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbAuthorizationRequest {
    pub authorization_url: String,
    pub code_verifier: String,
    pub state: String,
    pub redirect_uri: String,
}

/// Credential response from the issuer.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbCredentialResponse {
    pub format: Option<String>,
    pub credential: Option<String>,
    pub transaction_id: Option<String>,
    pub c_nonce: Option<String>,
    pub c_nonce_expires_in: Option<u64>,
}

impl From<marty_oid4vci::types::CredentialResponse> for FrbCredentialResponse {
    fn from(r: marty_oid4vci::types::CredentialResponse) -> Self {
        let credential = r.credential.as_ref().map(|v| {
            if v.is_string() {
                v.as_str().unwrap_or("").to_string()
            } else {
                v.to_string()
            }
        });
        Self {
            format: None,
            credential,
            transaction_id: r.transaction_id,
            c_nonce: r.nonce,
            c_nonce_expires_in: r.nonce_expires_in,
        }
    }
}

/// Parsed OID4VP presentation request.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbPresentationRequest {
    pub client_id: String,
    pub nonce: String,
    pub response_uri: String,
    pub query_type: String,
    pub presentation_definition_json: Option<String>,
    pub dcql_query_json: Option<String>,
}

/// One ZK proof to include in a presentation.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbZkProofEntry {
    pub descriptor_id: String,
    pub predicate_id: String,
    pub proof_bytes: Vec<u8>,
}

impl From<FrbZkProofEntry> for marty_oid4vci::ZkProofEntry {
    fn from(e: FrbZkProofEntry) -> Self {
        marty_oid4vci::ZkProofEntry {
            descriptor_id: e.descriptor_id,
            predicate_id: e.predicate_id,
            proof_bytes: e.proof_bytes,
        }
    }
}

/// The verifier's response after receiving a VP token.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbPresentationResponse {
    pub ok: bool,
    pub redirect_uri: Option<String>,
    pub error: Option<String>,
    pub error_description: Option<String>,
}

impl From<marty_oid4vci::PresentationResponse> for FrbPresentationResponse {
    fn from(r: marty_oid4vci::PresentationResponse) -> Self {
        Self {
            ok: r.ok,
            redirect_uri: r.redirect_uri,
            error: r.error,
            error_description: r.error_description,
        }
    }
}

// ============================================================================
// OID4VCI / OID4VP wallet entry points
// ============================================================================

/// Parse a `openid-credential-offer://` URI or `https://…?credential_offer=…` URL.
#[frb]
pub async fn wallet_parse_credential_offer(offer_uri: String) -> anyhow::Result<FrbCredentialOffer> {
    let engine = marty_oid4vci::WalletEngine::new();
    let offer = engine
        .parse_credential_offer(&offer_uri)
        .await
        .map_err(|e| anyhow::anyhow!("Credential offer parse error: {}", e))?;

    let pre_authorized_code = offer.grants.pre_authorized_code.as_ref()
        .map(|pa| pa.pre_authorized_code.clone());
    let tx_code_required = offer.grants.pre_authorized_code.as_ref()
        .and_then(|pa| pa.tx_code.as_ref()).is_some();
    let issuer_state = offer.grants.authorization_code.as_ref()
        .and_then(|ac| ac.issuer_state.clone());

    Ok(FrbCredentialOffer {
        credential_issuer: offer.credential_issuer,
        credential_configuration_ids: offer.credential_configuration_ids,
        pre_authorized_code,
        tx_code_required,
        issuer_state,
    })
}

/// Fetch `.well-known/openid-credential-issuer` metadata.
#[frb]
pub async fn wallet_fetch_issuer_metadata(issuer_url: String) -> anyhow::Result<FrbIssuerMetadata> {
    let engine = marty_oid4vci::WalletEngine::new();
    let meta = engine
        .fetch_issuer_metadata(&issuer_url)
        .await
        .map_err(|e| anyhow::anyhow!("Issuer metadata fetch error: {}", e))?;
    Ok(FrbIssuerMetadata::from(meta))
}

/// Exchange a pre-authorized code for an access token.
#[frb]
pub async fn wallet_exchange_pre_auth_token(
    token_endpoint: String,
    pre_auth_code: String,
    tx_code: Option<String>,
) -> anyhow::Result<FrbTokenResponse> {
    let engine = marty_oid4vci::WalletEngine::new();
    let token = engine
        .exchange_pre_auth_code(&token_endpoint, &pre_auth_code, tx_code.as_deref())
        .await
        .map_err(|e| anyhow::anyhow!("Token exchange error: {}", e))?;
    Ok(FrbTokenResponse::from(token))
}

/// Build PKCE authorization request URL + code verifier.
#[frb]
pub fn wallet_build_auth_request(
    issuer_metadata_json: String,
    credential_configuration_id: String,
    client_id: String,
    redirect_uri: String,
    issuer_state: Option<String>,
) -> anyhow::Result<FrbAuthorizationRequest> {
    let frb_meta: FrbIssuerMetadata = serde_json::from_str(&issuer_metadata_json)
        .map_err(|e| anyhow::anyhow!("Invalid issuer_metadata_json: {}", e))?;
    let meta = marty_oid4vci::IssuerMetadata {
        credential_issuer: frb_meta.credential_issuer.clone(),
        token_endpoint: Some(frb_meta.token_endpoint.clone()),
        credential_endpoint: frb_meta.credential_endpoint.clone(),
        authorization_endpoint: frb_meta.authorization_endpoint.clone(),
        grant_types_supported: frb_meta.grant_types_supported.clone(),
        credential_configurations_supported: serde_json::from_str(
            &frb_meta.credential_configurations_json,
        ).unwrap_or_default(),
        extra: Default::default(),
    };
    let engine = marty_oid4vci::WalletEngine::new();
    let (auth_req, code_verifier) = engine
        .build_authorization_request(
            &meta,
            &credential_configuration_id,
            &client_id,
            &redirect_uri,
            issuer_state,
        )
        .map_err(|e| anyhow::anyhow!("Authorization request build error: {}", e))?;
    let auth_endpoint_fallback = format!("{}/authorize", frb_meta.credential_issuer);
    let auth_endpoint = meta.authorization_endpoint.as_deref()
        .unwrap_or(&auth_endpoint_fallback);
    let authorization_url = engine
        .authorization_redirect_url(auth_endpoint, &auth_req)
        .map_err(|e| anyhow::anyhow!("Authorization URL build error: {}", e))?;
    let state = auth_req.state.clone().unwrap_or_default();
    let redir = auth_req.redirect_uri.clone().unwrap_or(redirect_uri);
    Ok(FrbAuthorizationRequest { authorization_url, code_verifier, state, redirect_uri: redir })
}

/// Exchange authorization code + PKCE verifier for access token.
#[frb]
pub async fn wallet_exchange_auth_code_token(
    token_endpoint: String,
    code: String,
    code_verifier: String,
    redirect_uri: Option<String>,
    client_id: Option<String>,
) -> anyhow::Result<FrbTokenResponse> {
    let engine = marty_oid4vci::WalletEngine::new();
    let token = engine
        .exchange_auth_code(
            &token_endpoint,
            &code,
            &code_verifier,
            redirect_uri.as_deref(),
            client_id.as_deref(),
        )
        .await
        .map_err(|e| anyhow::anyhow!("Auth code token exchange error: {}", e))?;
    Ok(FrbTokenResponse::from(token))
}

/// Create an `openid4vci-proof+jwt` proof-of-possession JWT.
#[frb]
pub fn wallet_create_proof_jwt(
    holder_kid: String,
    c_nonce: String,
    issuer_url: String,
    jwk_json: String,
) -> anyhow::Result<String> {
    let engine = marty_oid4vci::WalletEngine::new();
    engine
        .create_proof_jwt(&holder_kid, &c_nonce, &issuer_url, &jwk_json)
        .map_err(|e| anyhow::anyhow!("Proof JWT creation error: {}", e))
}

/// Request a credential from the issuer.
#[frb]
pub async fn wallet_request_credential(
    credential_endpoint: String,
    access_token: String,
    credential_format: String,
    credential_configuration_id: Option<String>,
    proof_jwt: String,
) -> anyhow::Result<FrbCredentialResponse> {
    use marty_oid4vci::types::CredentialFormat;
    let format = CredentialFormat::from_str_loose(&credential_format)
        .ok_or_else(|| anyhow::anyhow!("Unknown credential format: {}", credential_format))?;
    let engine = marty_oid4vci::WalletEngine::new();
    let resp = engine
        .request_credential(
            &credential_endpoint,
            &access_token,
            &format,
            credential_configuration_id.as_deref(),
            &proof_jwt,
        )
        .await
        .map_err(|e| anyhow::anyhow!("Credential request error: {}", e))?;
    Ok(FrbCredentialResponse::from(resp))
}

/// Parse an `openid4vp://` or `https://…` presentation request URI.
#[frb]
pub async fn wallet_parse_presentation_request(
    request_uri: String,
) -> anyhow::Result<FrbPresentationRequest> {
    let engine = marty_oid4vci::WalletEngine::new();
    let request = engine
        .parse_presentation_request(&request_uri)
        .await
        .map_err(|e| anyhow::anyhow!("Presentation request parse error: {}", e))?;
    let presentation_definition_json = request
        .presentation_definition
        .as_ref()
        .map(|definition| serde_json::to_string(definition))
        .transpose()
        .map_err(|e| anyhow::anyhow!("PresentationDefinition serialization error: {}", e))?;
    let dcql_query_json = request
        .dcql_query
        .as_ref()
        .map(|query| serde_json::to_string(query))
        .transpose()
        .map_err(|e| anyhow::anyhow!("DCQL query serialization error: {}", e))?;
    let query_type = match request.query_type {
        marty_oid4vci::PresentationRequestQueryType::PresentationDefinition => "presentation_definition",
        marty_oid4vci::PresentationRequestQueryType::DcqlQuery => "dcql_query",
    }
    .to_string();
    Ok(FrbPresentationRequest {
        client_id: request.client_id,
        nonce: request.nonce,
        response_uri: request.response_uri,
        query_type,
        presentation_definition_json,
        dcql_query_json,
    })
}

/// Build and submit a standard VP presentation.
#[frb]
pub async fn wallet_build_and_submit_presentation(
    response_uri: String,
    presentation_definition_json: Option<String>,
    dcql_query_json: Option<String>,
    credentials_json: String,
) -> anyhow::Result<FrbPresentationResponse> {
    let credentials: std::collections::HashMap<String, String> =
        serde_json::from_str(&credentials_json)
            .map_err(|e| anyhow::anyhow!("Invalid credentials_json: {}", e))?;
    let query_type = if dcql_query_json.is_some() {
        marty_oid4vci::PresentationRequestQueryType::DcqlQuery
    } else if presentation_definition_json.is_some() {
        marty_oid4vci::PresentationRequestQueryType::PresentationDefinition
    } else {
        return Err(anyhow::anyhow!(
            "Either presentation_definition_json or dcql_query_json is required"
        ));
    };
    let presentation_definition = presentation_definition_json
        .as_ref()
        .map(|json| serde_json::from_str(json))
        .transpose()
        .map_err(|e| anyhow::anyhow!("Invalid presentation_definition_json: {}", e))?;
    let dcql_query = dcql_query_json
        .as_ref()
        .map(|json| serde_json::from_str(json))
        .transpose()
        .map_err(|e| anyhow::anyhow!("Invalid dcql_query_json: {}", e))?;
    let engine = marty_oid4vci::WalletEngine::new();
    let request = marty_oid4vci::ParsedPresentationRequest {
        client_id: String::new(),
        nonce: String::new(),
        response_uri: response_uri.clone(),
        response_mode: None,
        state: None,
        query_type,
        presentation_definition,
        dcql_query,
    };
    let (vp_token, submission) = engine
        .build_presentation_for_request(&request, credentials)
        .map_err(|e| anyhow::anyhow!("Presentation build error: {}", e))?;
    let resp = engine
        .submit_presentation_optional(&response_uri, &vp_token, submission.as_ref())
        .await
        .map_err(|e| anyhow::anyhow!("Presentation submission error: {}", e))?;
    Ok(FrbPresentationResponse::from(resp))
}

/// Build and submit a ZK VP presentation.
#[frb]
pub async fn wallet_build_and_submit_zk_presentation(
    response_uri: String,
    presentation_definition_json: String,
    credentials_json: String,
    zk_proofs: Vec<FrbZkProofEntry>,
) -> anyhow::Result<FrbPresentationResponse> {
    use marty_oid4vci::verifier::PresentationDefinition;
    let definition: PresentationDefinition = serde_json::from_str(&presentation_definition_json)
        .map_err(|e| anyhow::anyhow!("Invalid presentation_definition_json: {}", e))?;
    let credentials: std::collections::HashMap<String, String> =
        serde_json::from_str(&credentials_json)
            .map_err(|e| anyhow::anyhow!("Invalid credentials_json: {}", e))?;
    let proofs: Vec<marty_oid4vci::ZkProofEntry> =
        zk_proofs.into_iter().map(Into::into).collect();
    let engine = marty_oid4vci::WalletEngine::new();
    let (vp_token, submission) = engine
        .build_zk_presentation(&definition, credentials, proofs)
        .map_err(|e| anyhow::anyhow!("ZK presentation build error: {}", e))?;
    let resp = engine
        .submit_presentation(&response_uri, &vp_token, &submission)
        .await
        .map_err(|e| anyhow::anyhow!("ZK presentation submission error: {}", e))?;
    Ok(FrbPresentationResponse::from(resp))
}

// ============================================================================
// ZK entry points
// ============================================================================

/// Prove all ZK predicates in a `PresentationDefinition`.
#[frb]
pub fn zk_prove_from_presentation_definition(
    presentation_definition_json: String,
    mdoc_bytes: Vec<u8>,
    issuer_pkx: String,
    issuer_pky: String,
    doc_type: String,
    secrets_json: String,
    session_nonce: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    #[derive(serde::Deserialize)]
    struct PD { input_descriptors: Vec<ID> }
    #[derive(serde::Deserialize)]
    struct ID { id: String }

    let pd: PD = serde_json::from_str(&presentation_definition_json)
        .map_err(|e| anyhow::anyhow!("Invalid Presentation Definition JSON: {}", e))?;
    let secrets: std::collections::HashMap<String, String> = serde_json::from_str(&secrets_json)
        .map_err(|e| anyhow::anyhow!("Invalid Secrets JSON: {}", e))?;

    for descriptor in pd.input_descriptors {
        let predicate = marty_zkp::ZkPredicate::from_id(&descriptor.id);
        let claim_name = predicate.required_claim();
        let claim_value = secrets.get(claim_name)
            .ok_or_else(|| anyhow::anyhow!("Missing '{}' in secrets for predicate '{}'", claim_name, descriptor.id))?;
        let attr = marty_zkp::AttributeRequest::new("org.iso.18013.5.1", claim_name, claim_value.as_bytes().to_vec());
        let input = marty_zkp::MdocProveInput {
            mdoc: mdoc_bytes.clone(),
            issuer_pkx: issuer_pkx.clone(),
            issuer_pky: issuer_pky.clone(),
            transcript: session_nonce.clone(),
            attributes: vec![attr],
            now: chrono::Utc::now().to_rfc3339(),
            doc_type: doc_type.clone(),
        };
        let circuit = marty_zkp::Circuit::generate(input.attributes.len())
            .map_err(|e| anyhow::anyhow!("Circuit generation failed: {}", e))?;
        return marty_zkp::Prover::prove(&circuit, &input)
            .map_err(|e| anyhow::anyhow!("ZK proof generation failed: {}", e));
    }
    Err(anyhow::anyhow!("No input descriptors found in Presentation Definition"))
}

/// Generate a ZK proof for a single named predicate.
#[frb]
pub fn zk_prove(
    predicate_id: String,
    claim_value: String,
    mdoc_bytes: Vec<u8>,
    issuer_pkx: String,
    issuer_pky: String,
    doc_type: String,
    session_nonce: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    let predicate = marty_zkp::ZkPredicate::from_id(&predicate_id);
    let claim_name = predicate.required_claim();
    let attr = marty_zkp::AttributeRequest::new("org.iso.18013.5.1", claim_name, claim_value.as_bytes().to_vec());
    let input = marty_zkp::MdocProveInput {
        mdoc: mdoc_bytes,
        issuer_pkx,
        issuer_pky,
        transcript: session_nonce,
        attributes: vec![attr],
        now: chrono::Utc::now().to_rfc3339(),
        doc_type,
    };
    let circuit = marty_zkp::Circuit::generate(input.attributes.len())
        .map_err(|e| anyhow::anyhow!("Circuit generation failed: {}", e))?;
    marty_zkp::Prover::prove(&circuit, &input)
        .map_err(|e| anyhow::anyhow!("ZK proof generation failed: {}", e))
}

/// Check whether ZK proofs are supported on this device.
#[frb]
pub fn zk_is_supported_on_device() -> bool {
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    fn encode_query_json(value: &str) -> String {
        url::form_urlencoded::byte_serialize(value.as_bytes()).collect()
    }

    #[tokio::test]
    async fn wallet_parse_presentation_request_reports_dcql_shape() {
        let dcql_query = r#"{"credentials":[{"id":"member_credential","format":"dc+sd-jwt"}]}"#;
        let request_uri = format!(
            "openid4vp://authorize?client_id={}&nonce=nonce-123&response_uri={}&dcql_query={}",
            encode_query_json("https://verifier.example"),
            encode_query_json("https://verifier.example/submit"),
            encode_query_json(dcql_query),
        );

        let parsed = wallet_parse_presentation_request(request_uri).await.unwrap();

        assert_eq!(parsed.query_type, "dcql_query");
        assert!(parsed.presentation_definition_json.is_none());
        assert!(parsed.dcql_query_json.is_some());
        assert_eq!(parsed.response_uri, "https://verifier.example/submit");
    }

    #[tokio::test]
    async fn wallet_parse_presentation_request_preserves_legacy_pe_shape() {
        let presentation_definition = r#"{"id":"pd-1","input_descriptors":[{"id":"member_credential","constraints":{"fields":[]}}]}"#;
        let request_uri = format!(
            "openid4vp://authorize?client_id={}&nonce=nonce-123&response_uri={}&presentation_definition={}",
            encode_query_json("https://verifier.example"),
            encode_query_json("https://verifier.example/submit"),
            encode_query_json(presentation_definition),
        );

        let parsed = wallet_parse_presentation_request(request_uri).await.unwrap();

        assert_eq!(parsed.query_type, "presentation_definition");
        assert!(parsed.presentation_definition_json.is_some());
        assert!(parsed.dcql_query_json.is_none());
    }
}
