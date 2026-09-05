//! Flutter Rust Bridge API surface.
//!
//! This module defines the public API that Flutter can call via FFI.
//! These are the entry points for all credential operations.
//! Keep bridge-visible signatures and DTOs here; domain implementations live in
//! `operations` so the Flutter contract is independent of internal module layout.

use crate::credential::{
    Credential, CredentialGroup, MDocCredential, PrivacyLevel, SdJwtCredential,
    SelectableCredential, TrustInfo, VerifiableCredential,
};
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
    crate::operations::credentials::parse_verifiable_credential(json)
}

/// Parse CBOR bytes into an MDocCredential.
pub fn parse_mdoc_credential(cbor_bytes: Vec<u8>) -> anyhow::Result<MDocCredential> {
    crate::operations::credentials::parse_mdoc_credential(cbor_bytes)
}

/// Parse SD-JWT string into an SdJwtCredential.
pub fn parse_sd_jwt_credential(sd_jwt: String) -> anyhow::Result<SdJwtCredential> {
    crate::operations::credentials::parse_sd_jwt_credential(sd_jwt)
}

// ============================================================================
// Trust Chain Verification
// ============================================================================

/// Verify mDoc trust chain from X.509 certificate chain.
pub fn verify_mdoc_trust_chain(x5chain: Vec<Vec<u8>>) -> anyhow::Result<TrustInfo> {
    crate::operations::credentials::verify_mdoc_trust_chain(x5chain)
}

/// Verify and attach trust info to an mDoc credential.
pub fn verify_and_attach_trust(
    mdoc: MDocCredential,
    x5chain: Vec<Vec<u8>>,
) -> anyhow::Result<MDocCredential> {
    crate::operations::credentials::verify_and_attach_trust(mdoc, x5chain)
}

// ============================================================================
// Credential Grouping & Selection
// ============================================================================

/// Group credentials by issuer for stacked display.
pub fn group_credentials_by_issuer(credentials: Vec<Credential>) -> Vec<CredentialGroup> {
    crate::operations::credentials::group_credentials_by_issuer(credentials)
}

/// Create a selectable credential for presentation UI.
pub fn create_selectable_credential(
    credential: Credential,
    privacy_level: PrivacyLevel,
) -> SelectableCredential {
    crate::operations::credentials::create_selectable_credential(credential, privacy_level)
}

// ============================================================================
// Credential Validation
// ============================================================================

/// Check if a credential is expired.
pub fn is_credential_expired(credential: &Credential) -> bool {
    crate::operations::credentials::is_credential_expired(credential)
}

/// Get all claim names from a credential.
pub fn get_credential_claims(credential: &Credential) -> Vec<String> {
    crate::operations::credentials::get_credential_claims(credential)
}

// ============================================================================
// Serialization
// ============================================================================

/// Serialize a credential to JSON for storage.
pub fn credential_to_json(credential: &Credential) -> anyhow::Result<String> {
    crate::operations::credentials::credential_to_json(credential)
}

/// Deserialize a credential from JSON.
pub fn credential_from_json(json: String) -> anyhow::Result<Credential> {
    crate::operations::credentials::credential_from_json(json)
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
    crate::operations::policy::sync_policies(license_jwt, endpoint).await
}

/// Evaluate a presentation request against policies and available credentials.
///
/// Returns the minimum disclosure set and any policy violations.
pub fn evaluate_presentation_request(
    request_json: String,
    policies_json: Vec<String>,
    _credentials: Vec<Credential>,
) -> anyhow::Result<PolicyEvaluationResult> {
    crate::operations::policy::evaluate_presentation_request(
        request_json,
        policies_json,
        _credentials,
    )
}

/// Evaluate the complete presentation-policy contract with the canonical Rust
/// service kernel.
///
/// The JSON request contains protocol-verified facts. This adapter performs no
/// trust, signature, freshness, revocation, or policy decision of its own.
pub fn evaluate_service_presentation_policy(request_json: String) -> anyhow::Result<String> {
    crate::operations::policy::evaluate_service_presentation_policy(request_json)
}

/// Get the minimum set of claims to disclose from a credential based on policy.
pub fn get_minimum_disclosure_set(
    policy_json: String,
    credential: Credential,
) -> anyhow::Result<Vec<String>> {
    crate::operations::policy::get_minimum_disclosure_set(policy_json, credential)
}

/// Rank credentials according to policy preferences.
pub fn rank_matching_credentials(
    policy_json: String,
    credentials: Vec<RankableCredentialInput>,
) -> anyhow::Result<Vec<String>> {
    crate::operations::policy::rank_matching_credentials(policy_json, credentials)
}

/// Check issuer constraints against policy.
pub fn check_issuer_constraints(
    policy_json: String,
    issuer_id: String,
    trust_profile_verified: bool,
) -> anyhow::Result<IssuerCheckResultOutput> {
    crate::operations::policy::check_issuer_constraints(
        policy_json,
        issuer_id,
        trust_profile_verified,
    )
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
    pub scope: Option<String>,
}

impl From<marty_oid4vci::types::TokenResponse> for FrbTokenResponse {
    fn from(t: marty_oid4vci::types::TokenResponse) -> Self {
        Self {
            access_token: t.access_token,
            token_type: t.token_type,
            expires_in: Some(t.expires_in),
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

/// A protocol QR/deep-link accepted by the canonical Rust wallet parsers.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbWalletQrInput {
    pub kind: String,
    pub normalized: String,
    pub parsed_content_json: String,
    pub requires_external_provider: bool,
}

/// Presentation holder-binding values validated by the canonical Rust wallet.
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct FrbPresentationBindingContext {
    pub challenge: String,
    pub domain: String,
}

/// Select the native presentation transport without Dart URI-prefix logic.
#[frb]
pub fn wallet_route_presentation_request(input: String) -> anyhow::Result<String> {
    crate::operations::qr::wallet_route_presentation_request(input)
}

/// Validate holder-binding values from a presentation request.
///
/// W3C-style `challenge`/`domain` fields and OID4VP `nonce`/`client_id`
/// aliases are accepted. Missing, malformed, conflicting, or synthetic values
/// fail closed; callers must never invent a fallback binding context.
#[frb]
pub fn wallet_validate_presentation_context(
    request_json: String,
) -> anyhow::Result<FrbPresentationBindingContext> {
    crate::operations::qr::wallet_validate_presentation_context(request_json)
}

/// Normalize a credential-offer handoff through the canonical Rust engine.
#[frb]
pub fn wallet_normalize_credential_offer(input: String) -> anyhow::Result<String> {
    crate::operations::qr::wallet_normalize_credential_offer(input)
}

/// Classify and fully parse a protocol QR/deep-link without a permissive
/// fallback. Unknown non-protocol input returns `None`; malformed supported
/// protocol input returns an error.
#[frb]
pub async fn wallet_validate_qr_input(
    raw_data: String,
) -> anyhow::Result<Option<FrbWalletQrInput>> {
    crate::operations::qr::wallet_validate_qr_input(raw_data).await
}

/// Parse a `openid-credential-offer://` URI or `https://…?credential_offer=…` URL.
#[frb]
pub async fn wallet_parse_credential_offer(
    offer_uri: String,
) -> anyhow::Result<FrbCredentialOffer> {
    crate::operations::issuance::wallet_parse_credential_offer(offer_uri).await
}

/// Fetch `.well-known/openid-credential-issuer` metadata.
#[frb]
pub async fn wallet_fetch_issuer_metadata(issuer_url: String) -> anyhow::Result<FrbIssuerMetadata> {
    crate::operations::issuance::wallet_fetch_issuer_metadata(issuer_url).await
}

/// Exchange a pre-authorized code for an access token.
#[frb]
pub async fn wallet_exchange_pre_auth_token(
    token_endpoint: String,
    pre_auth_code: String,
    tx_code: Option<String>,
) -> anyhow::Result<FrbTokenResponse> {
    crate::operations::issuance::wallet_exchange_pre_auth_token(
        token_endpoint,
        pre_auth_code,
        tx_code,
    )
    .await
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
    crate::operations::issuance::wallet_build_auth_request(
        issuer_metadata_json,
        credential_configuration_id,
        client_id,
        redirect_uri,
        issuer_state,
    )
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
    crate::operations::issuance::wallet_exchange_auth_code_token(
        token_endpoint,
        code,
        code_verifier,
        redirect_uri,
        client_id,
    )
    .await
}

/// Create an `openid4vci-proof+jwt` proof-of-possession JWT.
#[frb]
pub fn wallet_create_proof_jwt(
    holder_kid: String,
    c_nonce: String,
    issuer_url: String,
    jwk_json: String,
) -> anyhow::Result<String> {
    crate::operations::issuance::wallet_create_proof_jwt(holder_kid, c_nonce, issuer_url, jwk_json)
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
    crate::operations::issuance::wallet_request_credential(
        credential_endpoint,
        access_token,
        credential_format,
        credential_configuration_id,
        proof_jwt,
    )
    .await
}

/// Parse an `openid4vp://` or `https://…` presentation request URI.
#[frb]
pub async fn wallet_parse_presentation_request(
    request_uri: String,
) -> anyhow::Result<FrbPresentationRequest> {
    crate::operations::presentation::wallet_parse_presentation_request(request_uri).await
}

/// Build and submit a standard VP presentation.
#[frb]
pub async fn wallet_build_and_submit_presentation(
    response_uri: String,
    presentation_definition_json: Option<String>,
    dcql_query_json: Option<String>,
    credentials_json: String,
) -> anyhow::Result<FrbPresentationResponse> {
    crate::operations::presentation::wallet_build_and_submit_presentation(
        response_uri,
        presentation_definition_json,
        dcql_query_json,
        credentials_json,
    )
    .await
}

/// Build and submit a ZK VP presentation.
#[frb]
pub async fn wallet_build_and_submit_zk_presentation(
    response_uri: String,
    presentation_definition_json: String,
    credentials_json: String,
    zk_proofs: Vec<FrbZkProofEntry>,
) -> anyhow::Result<FrbPresentationResponse> {
    crate::operations::presentation::wallet_build_and_submit_zk_presentation(
        response_uri,
        presentation_definition_json,
        credentials_json,
        zk_proofs,
    )
    .await
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
    crate::operations::proofs::zk_prove_from_presentation_definition(
        presentation_definition_json,
        mdoc_bytes,
        issuer_pkx,
        issuer_pky,
        doc_type,
        secrets_json,
        session_nonce,
    )
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
    crate::operations::proofs::zk_prove(
        predicate_id,
        claim_value,
        mdoc_bytes,
        issuer_pkx,
        issuer_pky,
        doc_type,
        session_nonce,
    )
}

/// Check whether ZK proofs are supported on this device.
#[frb]
pub fn zk_is_supported_on_device() -> bool {
    crate::operations::proofs::zk_is_supported_on_device()
}

#[cfg(test)]
#[path = "api/tests.rs"]
mod tests;
