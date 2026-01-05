//! Trust chain verification using marty-verification.

use crate::credential::TrustInfo;
use marty_verification::{
    IacaRegistry, Jurisdiction, MdlVerificationResult,
    verification::mdl::{verify_x5chain, ValidationRuleset, X5Chain},
};

/// Trust registry for mDL verification.
pub struct MdlTrustRegistry {
    iaca_registry: IacaRegistry,
}

impl MdlTrustRegistry {
    /// Create a new trust registry from bundled IACA certificates.
    ///
    /// # Production Note
    /// In production, this should load real IACA certificates from:
    /// - AAMVA VICAL (Vehicle Identification CA Listing)
    /// - State/provincial DMV certificate repositories
    /// - Bundle certificates from `assets/iaca/` directory
    ///
    /// For demo mode, we use an empty registry which effectively
    /// skips issuer trust validation while still validating the
    /// certificate chain structure.
    pub fn new() -> anyhow::Result<Self> {
        // TODO: In production, load bundled IACA certificates:
        // 1. Create assets/iaca/ directory with jurisdiction PEM files
        // 2. Use include_bytes! macro to embed at compile time
        // 3. Parse and add to registry via add_jurisdiction_iaca()
        //
        // Example production loading:
        // ```ignore
        // let mut registry = IacaRegistry::new();
        // registry.add_jurisdiction_iaca(
        //     Jurisdiction::us_state("CA"),
        //     Certificate::from_pem(include_bytes!("../../assets/iaca/US-CA.pem"))?,
        // )?;
        // ```

        Ok(Self {
            iaca_registry: IacaRegistry::new(),
        })
    }

    /// Create a trust registry from a directory of IACA certificates.
    ///
    /// Expects PEM files named by jurisdiction code (e.g., `US-CA.pem`).
    #[allow(dead_code)]
    pub fn from_directory(path: &std::path::Path) -> anyhow::Result<Self> {
        let iaca_registry = IacaRegistry::from_directory(path)
            .map_err(|e| anyhow::anyhow!("Failed to load IACA certificates: {}", e))?;
        Ok(Self { iaca_registry })
    }

    /// Verify an mDoc credential's X5Chain.
    ///
    /// Takes raw DER-encoded certificate bytes and validates the chain.
    pub fn verify_x5chain(&self, cert_chain: &[Vec<u8>]) -> anyhow::Result<MdlVerificationResult> {
        // Build X5Chain from raw DER bytes using the builder pattern
        let mut builder = X5Chain::builder();
        for cert_der in cert_chain {
            builder = builder.with_der_certificate(cert_der)
                .map_err(|e| anyhow::anyhow!("Certificate error: Failed to parse certificate: {}", e))?;
        }
        let x5chain = builder.build()
            .map_err(|e| anyhow::anyhow!("Certificate error: Failed to build X5Chain: {}", e))?;

        // Verify using AAMVA ruleset
        let result = verify_x5chain(&x5chain, &self.iaca_registry, ValidationRuleset::AamvaMdl);
        Ok(result)
    }
}

impl Default for MdlTrustRegistry {
    fn default() -> Self {
        Self::new().expect("Failed to create default trust registry")
    }
}

/// Verify mDoc trust chain and return TrustInfo.
///
/// # Arguments
/// * `cert_chain` - DER-encoded certificate chain (end-entity first)
pub fn verify_mdoc_trust(cert_chain: &[Vec<u8>]) -> anyhow::Result<TrustInfo> {
    let registry = MdlTrustRegistry::new()?;
    let result = registry.verify_x5chain(cert_chain)?;

    let status = if result.verified {
        "Valid"
    } else if result.errors.is_empty() {
        "Unknown"
    } else {
        "Invalid"
    };

    Ok(TrustInfo {
        is_valid: result.verified,
        trust_anchor: result.jurisdiction,
        status_message: Some(status.to_string()),
        certificate_chain: vec![], // Optionally encode chain as PEM
    })
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
