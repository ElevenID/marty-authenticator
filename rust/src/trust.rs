//! Trust chain verification using marty-verification.

use crate::credential::TrustInfo;
use marty_verification::{
    verification::mdl::{verify_x5chain, ValidationRuleset, X5Chain},
    IacaRegistry, Jurisdiction, MdlVerificationResult, TrustRegistry,
};

const TRUST_UNAVAILABLE: &str =
    "mDoc issuer trust verification is unavailable: no IACA trust anchors are configured";

/// Trust registry for mDL verification.
#[derive(Default)]
pub struct MdlTrustRegistry {
    iaca_registry: IacaRegistry,
}

impl MdlTrustRegistry {
    /// Create an unconfigured registry.
    ///
    /// No IACA certificates are bundled. Verification reports unavailability
    /// until the caller supplies an authoritative registry with `from_directory`.
    pub fn new() -> anyhow::Result<Self> {
        Ok(Self::default())
    }

    /// Create a trust registry from a directory of IACA certificates.
    ///
    /// Expects PEM files named by jurisdiction code (e.g., `US-CA.pem`).
    pub fn from_directory(path: &std::path::Path) -> anyhow::Result<Self> {
        let iaca_registry = IacaRegistry::from_directory(path)
            .map_err(|e| anyhow::anyhow!("Failed to load IACA certificates: {}", e))?;
        anyhow::ensure!(!iaca_registry.is_empty(), TRUST_UNAVAILABLE);
        Ok(Self { iaca_registry })
    }

    /// Verify an mDoc credential's X5Chain.
    ///
    /// Takes raw DER-encoded certificate bytes and validates the chain.
    pub fn verify_x5chain(&self, cert_chain: &[Vec<u8>]) -> anyhow::Result<MdlVerificationResult> {
        anyhow::ensure!(!self.iaca_registry.is_empty(), TRUST_UNAVAILABLE);

        // Build X5Chain from raw DER bytes using the builder pattern
        let mut builder = X5Chain::builder();
        for cert_der in cert_chain {
            builder = builder.with_der_certificate(cert_der).map_err(|e| {
                anyhow::anyhow!("Certificate error: Failed to parse certificate: {}", e)
            })?;
        }
        let x5chain = builder
            .build()
            .map_err(|e| anyhow::anyhow!("Certificate error: Failed to build X5Chain: {}", e))?;

        // Verify using AAMVA ruleset
        let result = verify_x5chain(&x5chain, &self.iaca_registry, ValidationRuleset::AamvaMdl);
        Ok(result)
    }
}

/// Verify mDoc trust chain and return TrustInfo.
///
/// The Flutter bridge has no configured trust-anchor provider yet. It returns
/// an availability error, not an invalid/untrusted verdict about the credential.
///
/// # Arguments
/// * `cert_chain` - DER-encoded certificate chain (end-entity first)
pub fn verify_mdoc_trust(_cert_chain: &[Vec<u8>]) -> anyhow::Result<TrustInfo> {
    anyhow::bail!(TRUST_UNAVAILABLE)
}

/// Jurisdiction information for display.
#[derive(Debug, Clone)]
pub struct JurisdictionInfo {
    /// State/province code (e.g., "US-CA")
    pub code: String,
    /// Human-readable name
    pub name: String,
}

impl From<&Jurisdiction> for JurisdictionInfo {
    fn from(j: &Jurisdiction) -> Self {
        Self {
            code: j.code().to_string(),
            name: j.code().to_string(), // TODO: Resolve to full name
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::{Path, PathBuf};
    use std::sync::atomic::{AtomicU64, Ordering};

    struct CertificateDirectory(PathBuf);

    impl CertificateDirectory {
        fn new() -> Self {
            static NEXT_ID: AtomicU64 = AtomicU64::new(0);
            let path = std::env::temp_dir().join(format!(
                "marty-authenticator-trust-{}-{}",
                std::process::id(),
                NEXT_ID.fetch_add(1, Ordering::Relaxed)
            ));
            std::fs::create_dir(&path).expect("create isolated certificate directory");
            Self(path)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for CertificateDirectory {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn unconfigured_registry_reports_availability_before_chain_validation() {
        for registry in [
            MdlTrustRegistry::new().unwrap(),
            MdlTrustRegistry::default(),
        ] {
            let error = registry.verify_x5chain(&[vec![0xff]]).unwrap_err();
            assert_eq!(error.to_string(), TRUST_UNAVAILABLE);
        }
    }

    #[test]
    fn unconfigured_bridge_does_not_return_a_credential_trust_verdict() {
        for chain in [vec![], vec![vec![0xff]]] {
            let error = verify_mdoc_trust(&chain).unwrap_err();
            assert_eq!(error.to_string(), TRUST_UNAVAILABLE);
        }
    }

    #[test]
    fn empty_directory_does_not_claim_to_configure_trust() {
        let directory = CertificateDirectory::new();
        assert!(MdlTrustRegistry::from_directory(directory.path()).is_err());
    }

    #[test]
    fn configured_registry_still_validates_the_supplied_chain() {
        let directory = CertificateDirectory::new();
        std::fs::write(
            directory.path().join("US-CA.pem"),
            include_str!("../tests/fixtures/trust/public_ca.pem"),
        )
        .unwrap();
        let registry = MdlTrustRegistry::from_directory(directory.path()).unwrap();
        let error = registry.verify_x5chain(&[vec![0xff]]).unwrap_err();
        assert!(error.to_string().contains("Failed to parse certificate"));
    }
}
