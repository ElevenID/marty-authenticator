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

## Installed-device smoke suite and remaining acceptance

`integration_test/installed_wallet_smoke_test.dart` is an executable Android/iOS
smoke and rejection suite. It boots `lib/main_document.dart`, loads the packaged
Rust bridge through the real application initializer, and uses the real
secure-storage plugin and default wallet providers. It does not replace native
adapters or HTTP clients with mocks.

The bounded checks cover:

- Secure-storage write/read/delete for one owned non-credential probe key.
- Native inline-offer parsing and preservation of the reviewed offer, unsupported
  QR input, malformed credential rejection, offer/presentation route separation,
  and issuer-authority rejection before any credential exchange.
- The document view's scanner route, native offer review and decline, rejection
  when an unpaired wallet accepts an offer, and malformed presentation rejection
  without a consent screen or success message.
- Return to the document view and confirmation that rejection stored no receipt
  or enrollment and that the wallet can still read its empty storage.

Use a disposable device, emulator or simulator profile with a fresh
`netknights_debug` app and empty secure storage. The suite refuses existing data
without printing it or clearing it. Its cleanup deletes only the exact probe
value it wrote. In particular, it never calls `deleteAll`, removes receipts or
resets enrollment. An iOS reinstall may retain Keychain data, so use an isolated
simulator/profile rather than relying on uninstalling a personal wallet.

Restore the declared dependencies with Flutter **3.44.6** (`flutter pub get
--enforce-lockfile`). For Android, use the repository's Java/SDK/NDK and Rust
target setup from the packaging section above and an already running isolated
Android device/emulator. For iOS, use a macOS host with the repository's Xcode,
CocoaPods and native Rust build prerequisites, plus an already running isolated
iOS simulator or a development-signed test device. The existing
`netknights_debug` scheme is used on both platforms. Private native dependencies
must be available through the repository's existing authenticated setup.

For this iOS debug scheme, the Runner configuration inherits `FLUTTER_TARGET`
from the project's `Flutter/Generated.xcconfig`. Its former hardcoded application
entrypoint is removed so Flutter can select the generated integration-test
listener. Do not set `FLUTTER_TARGET` to the test file manually; the listener
wrapper is required. Ordinary explicit `-t lib/main_document.dart` builds still
select the application entrypoint. The other flavor/release overrides are
unchanged. This is source wiring only: the existing hosted iOS job uses
`netknights --config-only` and does not build or execute this changed debug
scheme. Its effective listener target, native build and installed run still need
verification on a macOS device host.

Select the exact identifier from `flutter devices`, then run either platform
with the same command:

```sh
make test-device-smoke DEVICE_ID='<exact Android or iOS device identifier>'
```

The equivalent direct command is:

```sh
flutter test integration_test/installed_wallet_smoke_test.dart \
  --flavor netknights_debug -d '<exact device identifier>' \
  --dart-define=WALLET_DEVICE_SMOKE=true \
  --dart-define=QR_CODE=WALLET_DEVICE_SMOKE_CAMERA_DISABLED
```

These defines explicitly select a smoke run and the existing camera-disabled
test seam. The test feeds deterministic inline input at the scanner callback;
it does not exercise camera capture or the OS permission prompt. The fixture
uses an `.invalid` issuer and needs no demo service, test account or pairing
credential. Parsing never authenticates that issuer. Normal `flutter test`
discovery continues to run `test/`; this device suite runs only when explicitly
selected. Global formatting and analysis include its source.

Run from a clean checkout of the candidate being qualified. Preserve diagnostics
outside the checkout, including the source commit, Flutter
version, device identifier/OS/ABI, command and full failed-run output. For
example, in Bash on the device host:

```sh
run_dir=$(mktemp -d "${TMPDIR:-/tmp}/wallet-device-smoke.XXXXXX")
git rev-parse HEAD > "$run_dir/source-commit.txt"
flutter --version > "$run_dir/flutter-version.txt"
flutter devices --machine > "$run_dir/devices.json"
set -o pipefail
make test-device-smoke DEVICE_ID='<exact device identifier>' 2>&1 \
  | tee "$run_dir/test.log"
```

The tracked suite and a passing source/build check do not establish an installed
run. Record each actual device execution and exact candidate in PR57 before
claiming that bounded coverage. Neither this suite nor a successful run closes
W14: enrollment/renewal and remote signing, OTP/PUSH, OS deep links, camera and
permission behavior, process/lifecycle and network failures, successful governed
issuance/presentation, deployed issuer services and independent interoperability
still need their applicable fixtures and runtime qualification. Synthetic
native provider fixtures and the mocked tests in `test/integration/` and
`acceptance_test/` remain distinct evidence.

The retired `scripts/run_driver.sh` targeted absent
`test_driver/run_all.dart`. The separate `test-live-credential` and
`test-live-presentation` Make targets also reference absent `real_*_flow_test.dart`
suites; they now fail before fetching a QR from a demo service. Restoring those
flows requires their own supported, governed exchange suite. The installed smoke
suite is not a replacement for live credential acceptance.

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
