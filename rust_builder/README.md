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
