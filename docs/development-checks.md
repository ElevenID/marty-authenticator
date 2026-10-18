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
