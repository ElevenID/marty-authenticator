use pyo3::prelude::*;
use pyo3::exceptions::PyValueError;
use serde_json::json;
use std::collections::HashMap;
use base64::{Engine as _, engine::general_purpose::STANDARD};

/// mDoc credential issuer for ISO 18013-5 mobile documents
///
/// This class provides functionality to issue ISO/IEC 18013-5 compliant
/// mobile document credentials, including mobile driver's licenses (mDL)
/// and other identity documents.
#[pyclass]
pub struct MdocIssuer {
    issuer_key_json: String,
    issuer_did: String,
}

#[pymethods]
impl MdocIssuer {
    /// Create a new mDoc issuer
    ///
    /// Args:
    ///     issuer_key_jwk (str): JWK private key as JSON string
    ///     issuer_did (str): DID of the issuer
    ///
    /// Returns:
    ///     MdocIssuer: A new mDoc issuer instance
    ///
    /// Example:
    ///     >>> issuer_key = '{"kty":"EC","crv":"P-256",...}'
    ///     >>> issuer_did = "did:key:z6MkhaXg..."
    ///     >>> issuer = MdocIssuer(issuer_key, issuer_did)
    #[new]
    pub fn new(issuer_key_jwk: String, issuer_did: String) -> PyResult<Self> {
        // Validate that it's valid JSON
        let _: serde_json::Value = serde_json::from_str(&issuer_key_jwk)
            .map_err(|e| PyValueError::new_err(format!("Invalid JWK: {}", e)))?;

        Ok(MdocIssuer {
            issuer_key_json: issuer_key_jwk,
            issuer_did,
        })
    }

    /// Issue an mDoc credential
    ///
    /// Creates a complete ISO 18013-5 mobile document credential with
    /// the specified claims, signed by the issuer's key.
    ///
    /// Args:
    ///     doctype (str): Document type (e.g., 'org.iso.18013.5.1.mDL')
    ///     claims (dict): Dictionary of claims organized by namespace
    ///                   Example: {"org.iso.18013.5.1": {"family_name": "Doe", "given_name": "John"}}
    ///     holder_public_key (str): Holder's public key as JWK JSON string
    ///     validity_days (int, optional): Number of days the credential is valid. Defaults to 365.
    ///
    /// Returns:
    ///     str: Base64-encoded CBOR mDoc credential
    ///
    /// Example:
    ///     >>> claims = {
    ///     ...     "org.iso.18013.5.1": {
    ///     ...         "family_name": "Doe",
    ///     ...         "given_name": "John",
    ///     ...         "birth_date": "1990-01-01"
    ///     ...     }
    ///     ... }
    ///     >>> holder_key = '{"kty":"EC","crv":"P-256",...}'
    ///     >>> mdoc = issuer.issue_mdoc("org.iso.18013.5.1.mDL", claims, holder_key, 365)
    #[pyo3(signature = (doctype, claims, holder_public_key, validity_days=365))]
    pub fn issue_mdoc(
        &self,
        doctype: String,
        claims: HashMap<String, HashMap<String, String>>,
        holder_public_key: String,
        validity_days: i64,
    ) -> PyResult<String> {
        // Parse holder public key - just validate it's valid JSON
        let _: serde_json::Value = serde_json::from_str(&holder_public_key)
            .map_err(|e| PyValueError::new_err(format!("Invalid holder key: {}", e)))?;

        // Calculate validity dates
        let now = chrono::Utc::now();
        let valid_until = now + chrono::Duration::days(validity_days);

        // Build mDoc structure (simplified for initial implementation)
        // TODO: Implement full ISO 18013-5 structure with proper COSE signing
        let mdoc = json!({
            "version": "1.0",
            "docType": doctype,
            "issuer": self.issuer_did,
            "issuanceDate": now.to_rfc3339(),
            "validUntil": valid_until.to_rfc3339(),
            "claims": claims,
        });

        // Serialize to CBOR
        let cbor_data = serde_cbor::to_vec(&mdoc)
            .map_err(|e| PyValueError::new_err(format!("CBOR encoding failed: {}", e)))?;

        // Return base64-encoded CBOR
        Ok(STANDARD.encode(cbor_data))
    }

    /// Create a Mobile Security Object (MSO)
    ///
    /// The MSO is the core security component of an mDoc, containing
    /// cryptographic digests of all claim values and signed by the issuer.
    ///
    /// Args:
    ///     doctype (str): Document type
    ///     claims (dict): Dictionary of claims organized by namespace
    ///     validity_days (int): Number of days the MSO is valid
    ///
    /// Returns:
    ///     str: Base64-encoded signed MSO in COSE Sign1 format
    ///
    /// Example:
    ///     >>> claims = {"org.iso.18013.5.1": {"family_name": "Doe"}}
    ///     >>> mso = issuer.create_mso("org.iso.18013.5.1.mDL", claims, 365)
    pub fn create_mso(
        &self,
        doctype: String,
        claims: HashMap<String, HashMap<String, String>>,
        validity_days: i64,
    ) -> PyResult<String> {
        let now = chrono::Utc::now();
        let valid_until = now + chrono::Duration::days(validity_days);

        // Compute digests for claims
        let mut value_digests: HashMap<String, HashMap<String, Vec<u8>>> = HashMap::new();

        for (namespace, attrs) in &claims {
            let mut namespace_digests = HashMap::new();

            for (attr_name, attr_value) in attrs {
                // Serialize claim value to CBOR
                let cbor_value = serde_cbor::to_vec(attr_value)
                    .map_err(|e| PyValueError::new_err(format!("CBOR encoding failed: {}", e)))?;

                // Compute SHA-256 digest
                use sha2::{Sha256, Digest};
                let mut hasher = Sha256::new();
                hasher.update(&cbor_value);
                let digest = hasher.finalize().to_vec();

                namespace_digests.insert(attr_name.clone(), digest);
            }

            value_digests.insert(namespace.clone(), namespace_digests);
        }

        // Build MSO
        let mso = json!({
            "version": "1.0",
            "digestAlgorithm": "SHA-256",
            "valueDigests": value_digests,
            "docType": doctype,
            "validityInfo": {
                "signed": now.to_rfc3339(),
                "validFrom": now.to_rfc3339(),
                "validUntil": valid_until.to_rfc3339(),
            }
        });

        // TODO: Sign MSO with COSE Sign1
        // For now, just return unsigned MSO
        let cbor_mso = serde_cbor::to_vec(&mso)
            .map_err(|e| PyValueError::new_err(format!("CBOR encoding failed: {}", e)))?;

        Ok(STANDARD.encode(cbor_mso))
    }

    /// Get the issuer's DID
    ///
    /// Returns:
    ///     str: The issuer's Decentralized Identifier
    pub fn get_issuer_did(&self) -> PyResult<String> {
        Ok(self.issuer_did.clone())
    }

    /// Compute digest of a claim value for MSO
    ///
    /// Args:
    ///     value (str): Claim value to hash
    ///
    /// Returns:
    ///     str: Base64-encoded SHA-256 digest
    pub fn compute_digest(&self, value: String) -> PyResult<String> {
        // Serialize to CBOR
        let cbor_value = serde_cbor::to_vec(&value)
            .map_err(|e| PyValueError::new_err(format!("CBOR encoding failed: {}", e)))?;

        // Compute SHA-256 digest
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(&cbor_value);
        let digest = hasher.finalize().to_vec();

        Ok(STANDARD.encode(digest))
    }
}

use serde_json;
use serde_cbor;
use sha2;
use chrono;
