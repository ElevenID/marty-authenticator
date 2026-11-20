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
[Python issuer integration](python-issuer-integration.md). Python standard-library
utilities now support build qualification, artifact validation and isolated test
fixtures. They are separate from the application's runtime. Pre-commit may also
require Python.

## Android native compilation and APK qualification

The dedicated Android workflow source-builds the bridge independently for
`armeabi-v7a`, `arm64-v8a` and `x86_64`. Each matrix job invokes the existing
Cargokit Gradle task with one validated Flutter target. It retains Rust 1.97.1,
Flutter 3.44.6, NDK 28.2.13676358, the locked/offline Cargo graph, current feature
selection and `CARGO_PROFILE_DEV_DEBUG=0`. Each job keeps its 15-minute bound.
The application's ordinary builds still compile the bridge from source.

Each successful producer exports only its bridge, the reviewed ONNX runtime and
a bounded manifest. The manifest binds the actual clean checkout commit/tree,
repository, workflow run and attempt, native input hashes, target and build
configuration. It records original library hashes and the expected packaged
bridge hash after the pinned NDK's `llvm-strip --strip-unneeded` transformation.
ONNX runtime bytes remain unchanged through packaging. No Cargo target directory
or third-party precompiled bridge is transferred.

The existing `(Android)` check runs after the complete matrix, including when a
producer fails or is skipped, and requires every producer to succeed. It downloads
only artifacts from the current run and attempt through the pinned artifact
action, with checksum mismatches treated as errors. The CI-only Gradle init
adapter validates exactly three producers before staging their verified files at
the existing native task boundary. It rejects stale/mixed source or run identities,
missing/duplicate/extra artifacts, symlinks, changed native bytes and changed NDK
strip tools. Normal application builds do not load that adapter.

The final 15-minute job assembles both original debug flavors in one Gradle graph.
The adapter checks each real Flutter task's flavor, `lib/main_document.dart`
entrypoint, debug mode, all three target platforms and unchanged Dart defines.
The existing APK validation still checks every native library's ELF/ABI structure
and 64-bit 16-KiB load alignment. It additionally requires the packaged bridge and
ONNX runtime bytes to match the current source producers for all three ABIs.
Both complete APKs and their provenance report are retained only after validation,
under a run/attempt/commit-specific name that preserves earlier evidence on retry.

Because artifact identity includes the workflow attempt, rerun **all jobs** after
a partial failed-job retry; successful producers from an older attempt are not
silently reused. Local structural and provenance checks use Python 3.12:

```sh
python -m unittest discover -s scripts -p 'test_android_native_artifacts.py'
python -m unittest discover -s scripts -p 'test_verify_android_native_bridge.py'
python scripts/qualify_android_native_adapter.py --gradle "$PWD/android/gradlew"
```

The adapter fixture executes the actual Cargokit task and CI init script in
Gradle 8.11.1 with controlled Android interfaces. It checks both flavor tasks,
the original entrypoint/defines, all three transfers, changed-run rejection and
failure when a source task is skipped despite stale outputs. It uses an owned
Git checkout, temporary outputs and Gradle daemon, and also runs in the final
Android job. The Cargokit helper is tracked as executable so the real task's
Unix setup does not change the source tree before provenance is recorded.

`android/gradle.properties` also records `android.builtInKotlin=false` and
`android.newDsl=false`, the values that pinned Flutter 3.44.6 otherwise appends
while preparing the Android configuration. Flutter's
[built-in Kotlin migrator](https://github.com/flutter/flutter/blob/3.44.6/packages/flutter_tools/lib/src/android/migrations/disable_built_in_kotlin_migration.dart)
and [DSL migrator](https://github.com/flutter/flutter/blob/3.44.6/packages/flutter_tools/lib/src/android/migrations/disable_new_dsl_migration.dart)
leave existing properties unchanged. Both source and assembly jobs reject any
tracked change immediately after Flutter configuration, and artifact export
and validation retain their complete clean-tree check. The properties file is
included in the explicit native input hashes.

In run [44800287738](https://github.com/ElevenID/marty-authenticator/actions/runs/44800287738),
all three native source tasks compiled, but export rejected tracked changes
after Flutter reported both properties-file upgrades. No artifacts from that
failed run qualified. Committing the migration values preserves the existing
build configuration; the repaired candidate still needs its own successful
hosted compilation and APK qualification.

These tests use synthetic ELF fixtures to exercise rejection and transfer logic.
They do not replace actual Android compilation, APK payload validation, native
loading, installed-wallet flows or independent interoperability qualification.
Exact executed candidates and remaining device acceptance stay in PR57.

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

## Browser storage replacement

The base64 SharedPreferences override is replaced by pinned upstream
`flutter_secure_storage_web` 2.1.1 plus the application's bounded, resumable
migration adapter. The [browser storage policy and qualification commands](browser-storage.md)
describe namespace isolation, exact readback before retiring an original,
preservation on failure, recovery behavior and real JS/WASM acceptance.
Migration does not authenticate a credential or pairing. Native storage and
non-exportable remote signing custody are unchanged. Exact execution checkpoints
and remaining release acceptance stay in PR57 and the existing demo audit;
[issue 11](https://github.com/ElevenID/marty-authenticator/issues/11) is not closed
by source changes alone.
