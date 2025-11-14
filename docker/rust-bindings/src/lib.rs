use pyo3::prelude::*;

mod mdoc;
mod did;
mod oid4vci;

use mdoc::MdocIssuer;
use did::DidManager;
use oid4vci::Oid4VciIssuer;

/// Python bindings for SpruceID SSI crate
///
/// This module provides Python bindings for issuing mDoc credentials,
/// managing DIDs, and implementing OID4VCI credential issuance flows.
///
/// Classes:
///     MdocIssuer: Issue ISO 18013-5 mobile document credentials
///     DidManager: Generate and resolve Decentralized Identifiers
///     Oid4VciIssuer: Handle OpenID for Verifiable Credential Issuance protocol
#[pymodule]
fn ssi_python(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<MdocIssuer>()?;
    m.add_class::<DidManager>()?;
    m.add_class::<Oid4VciIssuer>()?;
    Ok(())
}
