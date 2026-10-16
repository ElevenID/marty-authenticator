# SpruceID integration

Flutter reaches the native wallet implementation through the SpruceID platform
channels. Keep platform and channel adaptation local; use SDK operations for
credential exchange, presentations, and credential storage.

## Implementation owners

- [Flutter platform service](../lib/services/spruce_platform_service.dart) and
  [channel definitions](../lib/utils/spruce_channels.dart).
- [Android handler](../android/app/src/main/kotlin/it/netknights/piauthenticator/handlers/SpruceIdHandlerRefactored.kt).
- [Android presentation signer](../android/app/src/main/kotlin/it/netknights/piauthenticator/handlers/PresentationSignerAdapter.kt).
- [iOS channel handler](../ios/Runner/SpruceID/SpruceIdChannelHandler.swift).
- [iOS signer](../ios/Runner/SpruceID/SignerAdapter.swift) and
  [HTTP adapter](../ios/Runner/SpruceID/HttpClientWrapper.swift).

## Integration guidance

Use `Oid4vci` for credential offers, `Holder` for presentations,
`Oid4vp180137` for mDoc presentation flows, and `CredentialPack` for storage.
The SDK requires its own HTTP and presentation-signer interfaces; a platform
HTTP client or key manager needs an adapter rather than direct substitution.
Keep consent and credential selection in the application flow.

Consult the dependency declarations and source owners above for the installed
SDK APIs. Historical progress reports and their SDK-version-specific examples
are available in Git history; their compilation claims do not qualify the
current Android or iOS build.
