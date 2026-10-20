# Development checks

Install Flutter, Node/npm and pre-commit, then run `make dev-setup`. The setup
restores declared dependencies, validates the single root
`.pre-commit-config.yaml`, and installs hooks. It does not add Dart dependencies
or install a separate Python lint/security toolchain globally.

Use `make check` for Flutter analysis and repository hooks, `make test` for
Flutter tests, and `make security` for the pinned Gitleaks hook. Failures propagate
to the caller. Gitleaks extends its maintained default rules without a generated
baseline. File-format, Markdown links, Dart and local security hooks remain in
the root configuration. Existing live-QR and platform build targets remain.

The Python extension prototype is retired, with its unfinished feature intent in
[Python issuer integration](python-issuer-integration.md). There are no tracked
Python source files to lint; the web test server still uses a small Python
standard-library command. Pre-commit itself may also require Python, but that is
not a Python application dependency.

## Device integration coverage remains unfinished

The retired `scripts/run_driver.sh` invoked `flutter driver` against
`test_driver/run_all.dart`, which is absent. There is no tracked `test_driver/`
or `integration_test/` suite. The existing `test/` suite, including protocol
tests under `test/integration/`, and platform build checks remain; their success
does not establish device integration coverage.

Before claiming that coverage, provide an executable device/emulator suite,
document its Android/iOS setup and exact commands, and exercise real application
flows through the current native wallet adapters. Retain coverage needs for
enrollment, OTP/PUSH, deep links and credential offer/presentation handling,
including permission, lifecycle, network and rejection cases. Use isolated test
accounts and fixtures and preserve any failed-run diagnostics outside Git.

The separate web-test launchers have cross-repository E2E consumers. Their
ownership and missing application entrypoint need separate qualification;
retiring the orphan driver command does not establish or replace that harness.

Both web launchers share `scripts/run-web-test.sh`: the development entry point
uses Flutter Chrome, and `scripts/serve-web-test.sh` builds then serves web output.
They retain `MARTY_API_URL`, `WEB_PORT`, `HEALTH_TIMEOUT` and the serving mode's
`SKIP_BUILD=true` option. Both reject the missing `lib/mains/main_web_test.dart`
before contacting a backend; skipping a build also requires that entrypoint and
`build/web/index.html`. Cached output alone cannot qualify the absent test app.

Restoring web coverage needs an explicit supported browser-wallet implementation
and a test bridge for the retained UI/Integration consumers: readiness, device
registration and QR/deep-link input, push handling, credential storage/selection,
and consented OID4VCI/OID4VP exchanges. Preserve the current Rust and platform
adapter boundaries. Choose and qualify that bridge before changing the E2E
protocol or treating the launch scripts and Docker recipes as working coverage.

The uncalled `docker/Dockerfile.flutter.dev` recipe is retired; it also targeted
the missing entrypoint. Its distinct development requirements remain: an
explicit local API URL, test mode, SSE push instead of a Firebase emulator,
SPA routing, CanvasKit asset serving, and deliberate CORS and security headers.
Qualify those behaviors through the retained `docker/Dockerfile.flutter.web.test`
owner after the browser entrypoint and bridge exist. That recipe is not a
qualified equivalent today. The production `docker/Dockerfile.flutter` remains
separate and unchanged.

## Optional onboarding animation assets

The five unreferenced Lottie JSON files formerly in `res/lottie/` are retired.
The current app has no Lottie renderer dependency or Flutter asset declaration
for them, so they were not packaged or displayed. Secure-onboarding, security
cloud/shield, completion-smile and GitHub-brand animation concepts remain
optional design intent, not implemented flows removed by this cleanup. Any
future animation needs an owned/licensed asset, a declared Flutter asset and
renderer dependency, accessible reduced-motion behavior and a UI test of the
actual consuming screen. Existing onboarding screens and branding are unchanged.

## Browser storage replacement remains open

The local `flutter_secure_storage_web` override is actively consumed by
`WalletCredentialStore` and card state. It stores base64-encoded values in
SharedPreferences; base64 is not encryption. Its original claim that upstream
requires `dart:html` is obsolete: the upstream
[2.x changelog](https://pub.dev/packages/flutter_secure_storage_web/changelog)
records migration to `web` and JS interop, and 2.1.1 is available. Upstream
requires a secure browser context and uses a different WebCrypto storage format.

Removing the override by changing the dependency alone would leave existing
credential bodies/indexes and card state unreadable. The replacement tracked
in [issue 11](https://github.com/ElevenID/marty-authenticator/issues/11) needs
an explicit browser storage/security policy and a qualified, resumable migration:
read the old namespaced records, validate data, verify successful writes and
readback in the new store before removing old entries, and preserve originals
on interruption or failure. Qualify Unicode/malformed values, option/database
namespace isolation, partial failures, repeat runs, logout/delete semantics,
credential/index consistency and secure-context failures. Do not broaden
`deleteAll` to unrelated preferences or silently fall back to plaintext.

Use real browser JS/WASM builds and storage tests through the current app
consumers. Native Android/iOS storage must remain unchanged. This cleanup
retains the open feature and data migration; it does not declare browser
credential storage secure or validate removal of the override. Signing custody
and the other worker's KMS hardening scope are separate from this stored-data
migration.
