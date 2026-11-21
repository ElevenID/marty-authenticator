//! Application operations behind the stable Flutter API.

pub(crate) mod credentials;
pub(crate) mod disclosure_review;
pub(crate) mod governed_presentation;
pub(crate) mod issuance;
pub(crate) mod issuer_trust;
pub(crate) mod policy;
pub(crate) mod presentation;
pub(crate) mod proofs;
pub(crate) mod qr;
pub(crate) mod verified_issuance;
// Historical protocol fixtures only. Product submission uses governed sessions.
#[cfg(test)]
pub(crate) mod verified_presentation;
pub(crate) mod verifier_governance;
