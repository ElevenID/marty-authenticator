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
- Target-owned iOS [W3C handler](../ios/Runner/SpruceID/W3CMethodHandler.swift)
  and [mDoc handler](../ios/Runner/SpruceID/MdocMethodHandler.swift).

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

The standalone iOS `SignerAdapter.swift` and `HttpClientWrapper.swift` files are
unintegrated examples: they are absent from the Runner Sources build phase.
The compiled handlers above own the current implementations. Consolidating those
adapters remains unfinished work and needs explicit Xcode target integration,
SDK compatibility and positive/negative device tests before any ownership claim.
