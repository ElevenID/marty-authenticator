# Native bridge build integration

This private Flutter FFI plugin compiles and bundles the existing `../rust`
crate. It adds no wallet API or alternate signing implementation.

The scaffold and Cargokit sources come from the published
`flutter_rust_bridge_codegen` 2.13.0 crate, upstream commit
`8631db91a90c699439c9ce2a1fb4164ae8661da9`. The downloaded crate SHA-256 was
verified against the Cargo registry index:
`701a8e577f9f5f59f651e1e932add36ee5dfb82d0fa20215225ea177d4dbbe4b`.
The Cargokit license is retained in `cargokit/LICENSE`.

Local changes support the exact Rust release pin, distinguish Cargo package
names from explicit/normalized library names, and reject builds that produce
none of the expected libraries. The Android minimum SDK and NDK match the
application (26 and 28.2.13676358). The standalone build-tool test dependency
closure is updated for Dart 3.12; collection, path and YAML stay exactly pinned.
The plugin and standalone tool share the application SDK floors so formatting
is consistent before and after the standalone package resolves dependencies.
Android builds also pass the versioned NDK target, sysroot and target header
directory to bindgen, and select the same NDK clang executable used for C builds.
The ARMv7 LLVM target and sysroot-directory mapping follow
[cargo-ndk](https://github.com/bbqsrc/cargo-ndk/blob/main/src/cargo.rs); host
libc headers are not an Android binding input.

Android also stages the official full ONNX Runtime 1.24.2 Android AAR for the
existing `ort-sys` 2.0.0-rc.12 native backend. Microsoft documents this
[native-library distribution](https://onnxruntime.ai/docs/install/#cc-1).
`android/onnxruntime-android.lock.json` pins its primary Maven HTTPS URL, archive
SHA-256 and each ABI library's size and SHA-256. The archive digest was
bootstrapped from that HTTPS download; no independent signed checksum was
available. Gradle verifies cached/downloaded bytes before extracting only the
four official runtime libraries. Cargokit selects the libraries for Flutter's
validated requested targets. No AAR
Java dependency or precompiled Rust bridge is substituted.

Both `ORT_LIB_PATH` and `ORT_LIB_LOCATION` select the verified target library;
dynamic linking and no-download settings prevent the crate's missing ARMv7
prebuilt fallback. Cargokit copies that same library beside the source-built
bridge. The app retains its bytes through packaging and the APK validator
requires its pinned digest for all three configured Flutter ABIs. The old
scaffold's debug-only x86 addition is removed to match Flutter 3.44, whose
supported/default platforms and embedding dependencies are ARMv7, ARM64 and
x86_64. Both debug and release builds use Flutter's validated requested target
set; all three required APK ABIs remain. The runtime supports ORT API 24 and Android API 24; the
unchanged Rust feature selection uses ORT API 17 and the app minimum remains 26.
No inference backend, operator set, prover or wallet feature is disabled.

The dedicated Android APK job uses `CARGO_PROFILE_DEV_DEBUG=0` to omit native
debug information for each ABI. Rust backtraces in those qualification APKs lose
source-line detail. Debug assertions, overflow checks, features and target
selection retain their defaults; the runner and 15-minute Android job limit are
unchanged. Reproduce that job's profile by setting the same environment variable
when invoking `flutter build apk --debug`. The organization Flutter-quality
caller's approved build command and default debug profile remain unchanged.

That job uses Flutter's supported `apk --config-only` preparation, followed by
one Gradle invocation for `assembleNetknightsDebug` and
`assembleNetknights_debugDebug`. Both tasks use `lib/main_document.dart` and all
three configured Flutter platforms; shared native tasks execute in the same
Gradle graph. Both APKs must pass the existing native payload validator before
the artifact is retained. A successful configuration step alone is not a build.

Android Cargokit invokes `cargo rustc --lib --crate-type cdylib` with the same
toolchain, locked/offline flags, manifest, package, target and environment. JNI
packaging uses only that shared library, so Android no longer assembles the
unused static archive as well. Other platforms keep the existing Cargo build
and static/dynamic artifact behavior. This changes build output selection,
not native features, exported bridge APIs or the inference/prover backend.

`../rust/cargokit.yaml` selects Rust 1.97.1 and locked, offline Cargo builds.
Fetch the reviewed lockfile dependencies before building. The root
`cargokit_options.yaml` rejects downloaded precompiled library substitution.

Use the supported [Cargokit integration](https://cjycode.com/flutter_rust_bridge/manual/integrate/cargokit).
The Native Assets backend was evaluated but its current Rust builder dependency
conflicts with this application's Flutter SDK `meta` pin. No SDK override is
introduced.

Source integration and successful APK compilation do not qualify installed
Android/iOS startup or paired wallet flows. Exact execution and remaining
acceptance stay in PR57 and the existing demo audit.
