use pyo3::prelude::*;
use pyo3::exceptions::PyValueError;
use serde_json::json;

/// OID4VCI (OpenID for Verifiable Credential Issuance) protocol implementation
///
/// This class provides functionality to implement the OID4VCI protocol,
/// which enables credential issuance flows based on OpenID Connect.
#[pyclass]
pub struct Oid4VciIssuer {
    issuer_url: String,
}

#[pymethods]
impl Oid4VciIssuer {
    /// Create a new OID4VCI issuer
    ///
    /// Args:
    ///     issuer_url (str): Base URL of the credential issuer
    ///                       (e.g., "https://issuer.example.com")
    ///
    /// Returns:
    ///     Oid4VciIssuer: A new OID4VCI issuer instance
    ///
    /// Example:
    ///     >>> issuer = Oid4VciIssuer("https://issuer.example.com")
    #[new]
    pub fn new(issuer_url: String) -> Self {
        Oid4VciIssuer { issuer_url }
    }

    /// Generate a credential offer URL
    ///
    /// Creates an OID4VCI credential offer URL that can be presented
    /// to a wallet application to initiate credential issuance.
    ///
    /// Args:
    ///     credential_type (str): Type of credential to offer
    ///                           (e.g., "org.iso.18013.5.1.mDL")
    ///     pre_authorized_code (str): Pre-authorized code for token exchange
    ///     user_pin_required (bool): Whether user PIN is required
    ///
    /// Returns:
    ///     str: Credential offer URL in the format:
    ///          openid-credential-offer://?credential_offer=<encoded_offer>
    ///
    /// Example:
    ///     >>> offer_url = issuer.generate_credential_offer(
    ///     ...     "org.iso.18013.5.1.mDL",
    ///     ...     "SplxlOBeZQQYbYS6WxSbIA",
    ///     ...     False
    ///     ... )
    ///     >>> print(offer_url)
    ///     openid-credential-offer://?credential_offer=...
    pub fn generate_credential_offer(
        &self,
        credential_type: String,
        pre_authorized_code: String,
        user_pin_required: bool,
    ) -> PyResult<String> {
        let offer = json!({
            "credential_issuer": self.issuer_url,
            "credentials": [credential_type],
            "grants": {
                "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
                    "pre-authorized_code": pre_authorized_code,
                    "user_pin_required": user_pin_required
                }
            }
        });

        let offer_json = serde_json::to_string(&offer)
            .map_err(|e| PyValueError::new_err(format!("JSON encoding failed: {}", e)))?;

        let encoded_offer = urlencoding::encode(&offer_json);

        Ok(format!("openid-credential-offer://?credential_offer={}", encoded_offer))
    }

    /// Generate a credential offer URL with authorization code flow
    ///
    /// Creates an OID4VCI credential offer using the authorization code
    /// grant type instead of pre-authorized code.
    ///
    /// Args:
    ///     credential_type (str): Type of credential to offer
    ///     issuer_state (str): State parameter for the authorization flow
    ///     authorization_server (str, optional): Authorization server URL if different from issuer
    ///
    /// Returns:
    ///     str: Credential offer URL
    ///
    /// Example:
    ///     >>> offer_url = issuer.generate_credential_offer_with_auth_code(
    ///     ...     "org.iso.18013.5.1.mDL",
    ///     ...     "state-12345"
    ///     ... )
    #[pyo3(signature = (credential_type, issuer_state, authorization_server=None))]
    pub fn generate_credential_offer_with_auth_code(
        &self,
        credential_type: String,
        issuer_state: String,
        authorization_server: Option<String>,
    ) -> PyResult<String> {
        let mut grants = json!({
            "authorization_code": {
                "issuer_state": issuer_state
            }
        });

        if let Some(auth_server) = authorization_server {
            grants["authorization_code"]["authorization_server"] = json!(auth_server);
        }

        let offer = json!({
            "credential_issuer": self.issuer_url,
            "credentials": [credential_type],
            "grants": grants
        });

        let offer_json = serde_json::to_string(&offer)
            .map_err(|e| PyValueError::new_err(format!("JSON encoding failed: {}", e)))?;

        let encoded_offer = urlencoding::encode(&offer_json);

        Ok(format!("openid-credential-offer://?credential_offer={}", encoded_offer))
    }

    /// Generate credential response for OID4VCI
    ///
    /// Creates the final credential response that is sent back to the
    /// wallet after successful token exchange.
    ///
    /// Args:
    ///     credential_data (str): Base64-encoded credential
    ///     format (str): Credential format (e.g., "mso_mdoc", "vc+sd-jwt", "jwt_vc_json")
    ///
    /// Returns:
    ///     str: Credential response as JSON string
    ///
    /// Example:
    ///     >>> response = issuer.generate_credential_response(
    ///     ...     base64_mdoc,
    ///     ...     "mso_mdoc"
    ///     ... )
    pub fn generate_credential_response(
        &self,
        credential_data: String,
        format: String,
    ) -> PyResult<String> {
        let response = json!({
            "format": format,
            "credential": credential_data,
        });

        serde_json::to_string(&response)
            .map_err(|e| PyValueError::new_err(format!("JSON encoding failed: {}", e)))
    }

    /// Generate credential response with deferred issuance
    ///
    /// Creates a deferred credential response that includes an
    /// acceptance token for later credential retrieval.
    ///
    /// Args:
    ///     acceptance_token (str): Token for deferred credential retrieval
    ///
    /// Returns:
    ///     str: Deferred credential response as JSON string
    ///
    /// Example:
    ///     >>> response = issuer.generate_deferred_credential_response(
    ///     ...     "deferred-token-xyz"
    ///     ... )
    pub fn generate_deferred_credential_response(
        &self,
        acceptance_token: String,
    ) -> PyResult<String> {
        let response = json!({
            "acceptance_token": acceptance_token,
        });

        serde_json::to_string(&response)
            .map_err(|e| PyValueError::new_err(format!("JSON encoding failed: {}", e)))
    }

    /// Validate an access token for credential issuance
    ///
    /// Validates that an access token is valid and has the correct
    /// scope for the requested credential type.
    ///
    /// Args:
    ///     access_token (str): Bearer token from client
    ///     expected_scope (str): Expected scope for credential type
    ///
    /// Returns:
    ///     bool: True if valid, False otherwise
    ///
    /// Note:
    ///     This is a placeholder implementation. In production, this should
    ///     validate the token signature, expiration, and scope properly.
    pub fn validate_access_token(
        &self,
        access_token: String,
        expected_scope: String,
    ) -> PyResult<bool> {
        // TODO: Implement proper token validation
        // This should:
        // 1. Verify token signature
        // 2. Check expiration
        // 3. Validate scope
        // 4. Verify issuer
        Ok(!access_token.is_empty() && !expected_scope.is_empty())
    }

    /// Generate issuer metadata for OID4VCI
    ///
    /// Creates the credential issuer metadata that describes the
    /// issuer's capabilities and endpoints.
    ///
    /// Args:
    ///     supported_credentials (list): List of supported credential types
    ///     token_endpoint (str, optional): Token endpoint URL
    ///     credential_endpoint (str, optional): Credential endpoint URL
    ///
    /// Returns:
    ///     str: Issuer metadata as JSON string
    ///
    /// Example:
    ///     >>> metadata = issuer.generate_issuer_metadata(
    ///     ...     ["org.iso.18013.5.1.mDL", "UniversityDegree"]
    ///     ... )
    #[pyo3(signature = (supported_credentials, token_endpoint=None, credential_endpoint=None))]
    pub fn generate_issuer_metadata(
        &self,
        supported_credentials: Vec<String>,
        token_endpoint: Option<String>,
        credential_endpoint: Option<String>,
    ) -> PyResult<String> {
        let token_ep = token_endpoint.unwrap_or_else(||
            format!("{}/token", self.issuer_url)
        );
        let credential_ep = credential_endpoint.unwrap_or_else(||
            format!("{}/credential", self.issuer_url)
        );

        let metadata = json!({
            "credential_issuer": self.issuer_url,
            "credential_endpoint": credential_ep,
            "token_endpoint": token_ep,
            "credentials_supported": supported_credentials,
            "grant_types_supported": [
                "authorization_code",
                "urn:ietf:params:oauth:grant-type:pre-authorized_code"
            ]
        });

        serde_json::to_string_pretty(&metadata)
            .map_err(|e| PyValueError::new_err(format!("JSON encoding failed: {}", e)))
    }

    /// Get the issuer URL
    ///
    /// Returns:
    ///     str: The credential issuer URL
    pub fn get_issuer_url(&self) -> PyResult<String> {
        Ok(self.issuer_url.clone())
    }
}

use urlencoding;
use serde_json;
