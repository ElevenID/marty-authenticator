//! Error types for the Marty Authenticator bridge.

use thiserror::Error;

/// Errors that can occur during credential operations.
#[derive(Error, Debug)]
pub enum MartyError {
    #[error("Credential parsing failed: {0}")]
    ParseError(String),

    #[error("Trust chain verification failed: {0}")]
    TrustChainError(String),

    #[error("Signature verification failed: {0}")]
    SignatureError(String),

    #[error("Certificate error: {0}")]
    CertificateError(String),

    #[error("Unsupported credential format: {0}")]
    UnsupportedFormat(String),

    #[error("Expired credential")]
    Expired,

    #[error("Revoked credential")]
    Revoked,

    #[error("Internal error: {0}")]
    Internal(String),
}

impl From<marty_verification::VerificationError> for MartyError {
    fn from(err: marty_verification::VerificationError) -> Self {
        MartyError::TrustChainError(err.to_string())
    }
}

/// Result type for Marty operations - uses anyhow for flutter_rust_bridge compatibility.
pub type MartyResult<T> = anyhow::Result<T>;
