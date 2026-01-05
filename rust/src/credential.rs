//! Credential domain models owned by Marty.
//!
//! These are the canonical credential types that the Flutter app works with.
//! All parsing and validation happens here in Rust.

use serde::{Deserialize, Serialize};

/// Base credential type that all credentials implement.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum Credential {
    /// W3C Verifiable Credential
    VerifiableCredential(VerifiableCredential),
    /// ISO 18013-5 mDoc (Mobile Driving License)
    MDoc(MDocCredential),
    /// SD-JWT Verifiable Credential
    SdJwt(SdJwtCredential),
}

impl Credential {
    /// Get the unique identifier for this credential.
    pub fn id(&self) -> &str {
        match self {
            Credential::VerifiableCredential(vc) => &vc.id,
            Credential::MDoc(mdoc) => &mdoc.id,
            Credential::SdJwt(sd) => &sd.id,
        }
    }

    /// Get the issuer name/identifier.
    pub fn issuer(&self) -> &str {
        match self {
            Credential::VerifiableCredential(vc) => &vc.issuer,
            Credential::MDoc(mdoc) => &mdoc.issuing_authority,
            Credential::SdJwt(sd) => &sd.issuer,
        }
    }

    /// Check if the credential is expired.
    pub fn is_expired(&self) -> bool {
        match self {
            Credential::VerifiableCredential(vc) => vc
                .expiration_date
                .as_ref()
                .map(|d| is_past(d))
                .unwrap_or(false),
            Credential::MDoc(mdoc) => mdoc
                .expiry_date
                .as_ref()
                .map(|d| is_past(d))
                .unwrap_or(false),
            Credential::SdJwt(sd) => sd
                .expiration_date
                .as_ref()
                .map(|d| is_past(d))
                .unwrap_or(false),
        }
    }

    /// Get the credential type(s) as strings.
    pub fn credential_types(&self) -> Vec<String> {
        match self {
            Credential::VerifiableCredential(vc) => vc.types.clone(),
            Credential::MDoc(mdoc) => vec![mdoc.doc_type.clone()],
            Credential::SdJwt(sd) => sd.types.clone(),
        }
    }
}

fn is_past(date: &str) -> bool {
    // ISO 8601 date comparison
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(date) {
        dt < chrono::Utc::now()
    } else {
        false
    }
}

/// W3C Verifiable Credential model.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifiableCredential {
    /// Unique identifier (e.g., DID URL or UUID)
    pub id: String,

    /// Credential types (e.g., ["VerifiableCredential", "UniversityDegreeCredential"])
    #[serde(default)]
    pub types: Vec<String>,

    /// Issuer DID or URL
    pub issuer: String,

    /// Issuer display name (resolved from metadata)
    #[serde(default)]
    pub issuer_name: Option<String>,

    /// Issuance date (ISO 8601)
    pub issuance_date: String,

    /// Expiration date (ISO 8601), if any
    #[serde(default)]
    pub expiration_date: Option<String>,

    /// Credential subject claims
    pub subject: CredentialSubject,

    /// Proof/signature information
    #[serde(default)]
    pub proof: Option<Proof>,

    /// Credential status for revocation checking
    #[serde(default)]
    pub status: Option<CredentialStatus>,

    /// Raw JSON for pass-through to platform layer
    #[serde(skip)]
    pub raw_json: Option<String>,
}

/// Credential subject containing claims.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CredentialSubject {
    /// Subject DID (holder)
    #[serde(default)]
    pub id: Option<String>,

    /// All claims as JSON string (serialized HashMap<String, Value>)
    /// This avoids opaque type issues with flutter_rust_bridge
    #[serde(skip)]
    pub claims_json: String,
}

/// Proof/signature on a credential.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Proof {
    /// Proof type (e.g., "Ed25519Signature2020", "DataIntegrityProof")
    #[serde(rename = "type")]
    pub proof_type: String,

    /// When the proof was created
    #[serde(default)]
    pub created: Option<String>,

    /// Verification method (key reference)
    #[serde(default)]
    pub verification_method: Option<String>,

    /// Purpose (e.g., "assertionMethod")
    #[serde(default)]
    pub proof_purpose: Option<String>,

    /// The actual signature value
    #[serde(default)]
    pub proof_value: Option<String>,
}

/// Credential status for revocation checking.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CredentialStatus {
    /// Status type (e.g., "StatusList2021Entry")
    #[serde(rename = "type")]
    pub status_type: String,

    /// Status list credential ID
    #[serde(default)]
    pub status_list_credential: Option<String>,

    /// Index in the status list
    #[serde(default)]
    pub status_list_index: Option<String>,
}

/// ISO 18013-5 mDoc credential (Mobile Driving License, mID, etc.).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MDocCredential {
    /// Internal identifier
    pub id: String,

    /// Document type (e.g., "org.iso.18013.5.1.mDL")
    pub doc_type: String,

    /// Issuing authority name
    pub issuing_authority: String,

    /// Issuing country (ISO 3166-1 alpha-2)
    pub issuing_country: String,

    /// Expiry date (ISO 8601)
    #[serde(default)]
    pub expiry_date: Option<String>,

    /// Namespaced claims as JSON string (serialized HashMap<String, HashMap<String, Value>>)
    /// This avoids opaque type issues with flutter_rust_bridge
    #[serde(skip)]
    pub namespaces_json: String,

    /// Trust chain verification result
    #[serde(default)]
    pub trust_info: Option<TrustInfo>,

    /// Portrait image (base64 encoded)
    #[serde(default)]
    pub portrait: Option<String>,

    /// Signature image (base64 encoded)
    #[serde(default)]
    pub signature: Option<String>,
}

/// SD-JWT Verifiable Credential.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SdJwtCredential {
    /// Unique identifier
    pub id: String,

    /// Credential types
    #[serde(default)]
    pub types: Vec<String>,

    /// Issuer identifier
    pub issuer: String,

    /// Issuance date
    pub issuance_date: String,

    /// Expiration date
    #[serde(default)]
    pub expiration_date: Option<String>,

    /// Disclosed claims as JSON string (serialized HashMap<String, Value>)
    /// This avoids opaque type issues with flutter_rust_bridge
    #[serde(skip)]
    pub disclosed_claims_json: String,

    /// Selectively disclosable claim names
    #[serde(default)]
    pub disclosable_claims: Vec<String>,

    /// Key binding JWT, if present
    #[serde(default)]
    pub key_binding: Option<String>,
}

/// Trust chain verification information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustInfo {
    /// Whether the trust chain is valid
    pub is_valid: bool,

    /// Trust anchor used (e.g., IACA jurisdiction)
    #[serde(default)]
    pub trust_anchor: Option<String>,

    /// Chain validation status message
    #[serde(default)]
    pub status_message: Option<String>,

    /// Certificate chain (PEM encoded)
    #[serde(default)]
    pub certificate_chain: Vec<String>,
}

/// Grouping of credentials by issuer for stacked display.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CredentialGroup {
    /// Issuer identifier
    pub issuer: String,

    /// Display name for the issuer
    pub issuer_name: String,

    /// Credentials from this issuer
    pub credentials: Vec<Credential>,

    /// Issuer logo URL
    #[serde(default)]
    pub logo_url: Option<String>,
}

/// Credential with selection state for presentation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SelectableCredential {
    /// The underlying credential
    pub credential: Credential,

    /// Whether this credential is selected for presentation
    pub is_selected: bool,

    /// Claims selected for disclosure
    pub selected_claims: Vec<String>,

    /// Privacy level for this presentation
    pub privacy_level: PrivacyLevel,
}

/// Privacy level for credential presentation.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum PrivacyLevel {
    /// Disclose all claims
    Full,
    /// Disclose only required claims
    Minimal,
    /// Custom claim selection
    Custom,
}

impl Default for PrivacyLevel {
    fn default() -> Self {
        PrivacyLevel::Minimal
    }
}
