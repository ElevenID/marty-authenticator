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

## Unfinished iOS adapter consolidation

The standalone `W3CMethodHandlerRefactored.swift`, `SignerAdapter.swift` and
`HttpClientWrapper.swift` examples were never in the Runner Sources build phase
and are now retired (recoverable at Authenticator checkpoint `19bef442`). The
compiled handlers above continue to own the app's behavior.

The alternate design intended SDK-backed DID creation, holder VC signing and
presentation, OID4VCI offers, OID4VP 18013-7 requests, a key-manager signer adapter
and a bounded async HTTP client. Those remain feature/design requirements;
removing uncompiled examples does not declare them delivered. The prototypes
fabricated a DID from a UUID, left SDK calls as placeholders and returned an
unchanged credential with detached hex instead of proving signed output.

Consolidation needs explicit Xcode target integration and SDK compatibility;
canonical DID/JWK and signed credential/presentation outputs; token/request
validation and holder binding; bounded HTTP errors/timeouts and cancellation;
and positive/negative end-to-end device tests through the compiled channel.
Do not infer feature parity from an example compiling outside the app target.

The uncompiled `AppDelegate.swift.original` backup is also retired. Its inline
placeholder PKI, mdoc, JWT, wallet and fabricated DID handlers are not an
alternative startup owner. Keep SDK qualification and positive/negative device
tests with the compiled `AppDelegate.swift` and its separate method handlers;
removing the backup does not establish that unfinished SDK operations work.
