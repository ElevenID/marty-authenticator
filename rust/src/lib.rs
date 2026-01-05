// Marty Authenticator Rust Bridge
//
// This crate provides FFI bindings via flutter_rust_bridge to expose
// marty-verification functionality to the Flutter app.
//
// All credential-related logic lives here in Rust, hiding SpruceID
// implementation details and providing a clean Marty-owned API.

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

pub mod api;
pub mod credential;
pub mod error;
pub mod trust;

// Re-export types for flutter_rust_bridge
pub use credential::{Credential, MDocCredential, SdJwtCredential, TrustInfo, VerifiableCredential};
pub use error::{MartyError, MartyResult};
