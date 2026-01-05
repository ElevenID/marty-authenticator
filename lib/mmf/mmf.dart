/*
 * privacyIDEA Authenticator - MMF Infrastructure Interfaces
 *
 * This barrel file exports all MMF infrastructure interfaces.
 * These are credential-agnostic abstractions that Marty implements
 * using platform-specific services (SpruceID, platform channels, etc.).
 *
 * MMF provides:
 * - Key management (IKeyManager) - low-level crypto operations
 * - Auth key management (IAuthKeyManager) - device identity, sessions
 * - Secure storage (ISecureStorage)
 * - Credential transport (ICredentialTransport)
 *
 * Marty owns:
 * - Credential domain models
 * - Credential key management (cred:* namespace)
 * - Credential parsing (via Rust layer)
 * - Trust chain verification (via marty-verification)
 * - Business logic
 *
 * Key ID Namespacing:
 * - auth:device:*, auth:session:* - MMF authentication keys
 * - cred:issuer:*, cred:holder:* - Marty credential keys
 */

export 'key_manager.dart';
export 'auth_key_manager.dart';
export 'secure_storage.dart';
export 'credential_transport.dart';
