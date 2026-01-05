//! Flutter Rust Bridge API surface.
//!
//! This module defines the public API that Flutter can call via FFI.
//! These are the entry points for all credential operations.

use crate::credential::{
    Credential, CredentialGroup, MDocCredential, PrivacyLevel, SelectableCredential,
    SdJwtCredential, TrustInfo, VerifiableCredential,
};
use crate::trust;

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
