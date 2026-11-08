# Reviewed fork foundation in the wallet bridge

The Rust bridge adopts the reviewed Core and private-fork foundation as one
dependency graph. Its seven direct Core dependencies and the Core dependencies
of `marty-sync` resolve to the same immutable revision. SSI, its DID methods and
the verification-only ECDSA compatibility patch resolve from the whole reviewed
SSI fork; the dedicated linked-data revision remains separate. The former
registry SSI graph and standalone SSI-JWT patch are removed from the lockfile.

The exact revisions are recorded in `rust/Cargo.toml` and `rust/Cargo.lock`.
They coordinate with Core PR 414, SD-JWT PR 44, isomdl PR 38, and Verifier PR 180.
Existing wallet, native biometrics and ZK prover feature selections are retained.

The retired standalone SSI-JWT patch removed an unused `serde_with` 2.x
dependency; that security maintenance change remains present in the monorepo
JWT crate. Its separate dependency-only major bumps for `hashbrown`,
`ordered-float` and `thiserror` are consolidated to the shared SSI graph's
upstream-compatible requirements. This is a deliberate dependency-maintenance
choice rather than byte-identical parity. The retained implementation differences
are the custody-safe removal of local signing and upstream's validated
`StringOrURI` wrapper; the bridge uses its compatible `as_str` interface.

## What the bridge gains

- The reviewed SSI implementation and one compatible verification backend.
- Core's provider-backed SD-JWT verification and JSON parsing that preserves
  fractional numbers and literal object types under consumer feature unification.
- Core's isomdl 0.4 adaptation, including the authenticated-MSO passive mdoc
  verification boundary and retained product algorithm policy.
- Signed USB trust-package JSON preservation through parsing, typed schema
  conversion and storage readback in the shared synchronization stack.

The foundation adoption in PR 83 did not change the Flutter bridge API or
generate new Dart bindings. Credential-display parsing continues to decode
claims; that operation does not authenticate issuer authority. PR 57 now
integrates that graph into the verified holder preparation and remote-key
custody path; see [verified wallet integration](verified-wallet-integration.md)
for its current scope and remaining qualification gates. No new protocol
profile, holder-key fallback, cryptosuite or transport was enabled by the
dependency adoption alone.

## Qualification

The reviewed foundation candidate passes a native Linux bridge check and all
37 existing Rust bridge tests against the committed graph, using the real native
ZK and ONNX runtime dependencies. Those tests do not qualify biometric model
accuracy or device behavior. All 11 existing private-fork reader tests pass.
Independent metadata review confirms one Core revision across all 11 selected
Core packages and unchanged resolved feature selections after graph convergence.

The existing Rust Bridge Codegen workflow checks generated bindings and runs
native bridge behavior tests against the committed lockfile. The private-fork
reader boundary remains enforced by its existing tests. Actual Cargo metadata
must contain one Core source shared with `marty-sync` and no registry or old
standalone SSI-JWT replacement graph.

Native bridge checks and platform/Flutter checks are separate qualifications.
Android/iOS execution, generated Dart analysis, device integration and release
artifacts retain their existing gates. This foundation change does not release
or deploy the wallet.
