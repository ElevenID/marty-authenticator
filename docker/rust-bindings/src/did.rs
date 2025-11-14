use pyo3::prelude::*;
use pyo3::exceptions::PyValueError;
use p256::ecdsa::{SigningKey, VerifyingKey};
use ed25519_dalek::{SigningKey as Ed25519SigningKey, VerifyingKey as Ed25519VerifyingKey, Signer};
use rand::rngs::OsRng;
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use sha2::{Sha256, Digest};

/// DID management utilities for generating and resolving Decentralized Identifiers
///
/// This class provides functionality to work with DIDs (Decentralized Identifiers)
/// including generation of new DIDs and resolution of DID documents.
#[pyclass]
pub struct DidManager {}

#[pymethods]
impl DidManager {
    /// Create a new DID manager
    ///
    /// Returns:
    ///     DidManager: A new DID manager instance
    ///
    /// Example:
    ///     >>> manager = DidManager()
    #[new]
    pub fn new() -> Self {
        DidManager {}
    }

    /// Generate a new DID:key with ES256 (P-256) key
    ///
    /// Creates a new Elliptic Curve key pair using the P-256 curve
    /// and generates a corresponding did:key identifier.
    ///
    /// Returns:
    ///     tuple: (did_string, jwk_json_string) where:
    ///         - did_string: The generated DID (e.g., "did:key:z6Mkh...")
    ///         - jwk_json_string: The private key in JWK format as JSON string
    ///
    /// Example:
    ///     >>> manager = DidManager()
    ///     >>> did, private_key = manager.generate_did_key()
    ///     >>> print(did)
    ///     did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK
    #[pyo3(signature = ())]
    pub fn generate_did_key(&self) -> PyResult<(String, String)> {
        // Generate P-256 signing key
        let signing_key = SigningKey::random(&mut OsRng);
        let verifying_key = VerifyingKey::from(&signing_key);

        // Create simplified JWK representation
        let jwk = serde_json::json!({
            "kty": "EC",
            "crv": "P-256",
            "x": URL_SAFE_NO_PAD.encode(verifying_key.to_encoded_point(false).x().unwrap()),
            "y": URL_SAFE_NO_PAD.encode(verifying_key.to_encoded_point(false).y().unwrap()),
            "d": URL_SAFE_NO_PAD.encode(signing_key.to_bytes())
        });

        // Create DID:key (simplified - using thumbprint as identifier)
        let thumbprint = URL_SAFE_NO_PAD.encode(
            Sha256::digest(serde_json::to_string(&jwk).unwrap().as_bytes())
        );
        let did = format!("did:key:z{}", thumbprint);

        let jwk_json = serde_json::to_string(&jwk)
            .map_err(|e| PyValueError::new_err(format!("JWK serialization failed: {}", e)))?;

        Ok((did, jwk_json))
    }

    /// Generate a new DID:key with Ed25519 key
    ///
    /// Creates a new Ed25519 key pair and generates a corresponding
    /// did:key identifier. Ed25519 is preferred for many use cases
    /// due to its performance and security properties.
    ///
    /// Returns:
    ///     tuple: (did_string, jwk_json_string)
    ///
    /// Example:
    ///     >>> manager = DidManager()
    ///     >>> did, private_key = manager.generate_did_key_ed25519()
    #[pyo3(signature = ())]
    pub fn generate_did_key_ed25519(&self) -> PyResult<(String, String)> {
        // Generate Ed25519 key
        let signing_key = Ed25519SigningKey::from_bytes(&rand::random());
        let verifying_key = signing_key.verifying_key();

        // Create simplified JWK representation
        let jwk = serde_json::json!({
            "kty": "OKP",
            "crv": "Ed25519",
            "x": URL_SAFE_NO_PAD.encode(verifying_key.as_bytes()),
            "d": URL_SAFE_NO_PAD.encode(signing_key.as_bytes())
        });

        // Create DID:key (simplified)
        let thumbprint = URL_SAFE_NO_PAD.encode(
            Sha256::digest(serde_json::to_string(&jwk).unwrap().as_bytes())
        );
        let did = format!("did:key:z{}", thumbprint);

        let jwk_json = serde_json::to_string(&jwk)
            .map_err(|e| PyValueError::new_err(format!("JWK serialization failed: {}", e)))?;

        Ok((did, jwk_json))
    }

    /// Resolve a DID to its DID Document
    ///
    /// Resolves a DID identifier to its corresponding DID Document,
    /// which contains verification methods, service endpoints, and
    /// other metadata.
    ///
    /// Args:
    ///     did (str): DID string to resolve (e.g., "did:key:z6Mkh...")
    ///
    /// Returns:
    ///     str: DID Document as JSON string
    ///
    /// Example:
    ///     >>> manager = DidManager()
    ///     >>> did_doc = manager.resolve_did("did:key:z6MkhaXg...")
    ///     >>> print(did_doc)
    ///     {"id": "did:key:...", "@context": "...", ...}
    pub fn resolve_did(&self, did: String) -> PyResult<String> {
        // TODO: Implement proper DID resolution using ssi-dids
        // For now, return a basic DID Document structure
        let doc = serde_json::json!({
            "@context": [
                "https://www.w3.org/ns/did/v1",
                "https://w3id.org/security/suites/jws-2020/v1"
            ],
            "id": did,
            "verificationMethod": [{
                "id": format!("{}#key-1", did),
                "type": "JsonWebKey2020",
                "controller": did,
                "publicKeyJwk": {}
            }],
            "authentication": [format!("{}#key-1", did)],
            "assertionMethod": [format!("{}#key-1", did)],
        });

        Ok(doc.to_string())
    }

    /// Extract public key from a JWK private key
    ///
    /// Args:
    ///     jwk_json (str): Private JWK as JSON string
    ///
    /// Returns:
    ///     str: Public JWK as JSON string
    ///
    /// Example:
    ///     >>> private_key = '{"kty":"EC","crv":"P-256","d":"...",...}'
    ///     >>> public_key = manager.get_public_key(private_key)
    pub fn get_public_key(&self, jwk_json: String) -> PyResult<String> {
        let jwk: serde_json::Value = serde_json::from_str(&jwk_json)
            .map_err(|e| PyValueError::new_err(format!("Invalid JWK: {}", e)))?;

        // Remove private key component
        let mut public_jwk = jwk.clone();
        if let Some(obj) = public_jwk.as_object_mut() {
            obj.remove("d");
        }

        serde_json::to_string(&public_jwk)
            .map_err(|e| PyValueError::new_err(format!("JWK serialization failed: {}", e)))
    }

    /// Get JWK thumbprint (hash of the public key)
    ///
    /// Args:
    ///     jwk_json (str): JWK as JSON string
    ///
    /// Returns:
    ///     str: Base64url-encoded thumbprint
    ///
    /// Example:
    ///     >>> thumbprint = manager.get_jwk_thumbprint(jwk_json)
    pub fn get_jwk_thumbprint(&self, jwk_json: String) -> PyResult<String> {
        // Compute SHA-256 hash of the JWK
        let mut hasher = Sha256::new();
        hasher.update(jwk_json.as_bytes());
        let thumbprint = hasher.finalize();

        Ok(URL_SAFE_NO_PAD.encode(thumbprint))
    }

    /// Convert DID to verification method ID
    ///
    /// Args:
    ///     did (str): DID string
    ///     key_id (str, optional): Key identifier. Defaults to "key-1"
    ///
    /// Returns:
    ///     str: Verification method ID (DID URL)
    ///
    /// Example:
    ///     >>> vm_id = manager.did_to_verification_method("did:key:z6Mkh...")
    ///     >>> print(vm_id)
    ///     did:key:z6Mkh...#key-1
    #[pyo3(signature = (did, key_id="key-1"))]
    pub fn did_to_verification_method(&self, did: String, key_id: &str) -> PyResult<String> {
        Ok(format!("{}#{}", did, key_id))
    }
}

use serde_json;
