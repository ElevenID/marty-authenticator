# Verified paired-wallet integration

The retained implementation is PR 57. This document describes the supported
source boundaries. Exact candidates, executed tests, failures and remaining
acceptance are recorded in that PR and the existing demo audit. Source
integration does not activate or release a production wallet.

## Dependency and bridge boundary

The manifests pin accepted Core `8b553b472890cebbf4972cd0fdcb440141085d35`
(Core #441) and Verifier `8b417a9bd3618fe2bb690727dfee1fd7c6de12eb`
(Verifier #198). Core dependencies of `marty-sync` share that revision. The
wallet uses only the portable policy/profile client of marty-sync, without
native trust-list acquisition, database or USB-import capabilities. The
reviewed SSI, SD-JWT, isomdl, linked-data and SQLCipher closures remain
coordinated. The application retains its wallet, verification and prover roles;
it does not enable an issuer capability or local private-key fallback.

Core #441 supplies Android target-owned OpenSSL/zstd includes and NDK static
C++ link metadata for the real prover. This packaging support is separate from
APK loading and installed-device acceptance; it does not change holder custody.

FRB 2.13 connects Dart orchestration to native operations. Public holder keys
and exact remote signatures cross that boundary; identity-signing private keys
remain non-exportable. Display parsing is not credential verification. Raw
signing, unverified storage and raw submission entry points remain retired or
explicitly unsupported.

## Issuance authority and receipts

The native QR parser freezes a reviewed referenced offer into a bounded inline
offer, and the approval UI forwards that exact snapshot. Parsed QR content
establishes neither trust nor receipt acceptance. The verified path supports one
offered configuration until explicit configuration selection exists.

`issuer_trust.rs` admits original, duplicate-free
`marty.wallet/device-issuer-governance/v2` transport and canonical
`marty.wallet/issuer-authority/v2` evidence. It checks full confirmed pairing
scope, holder key/thumbprint/version, authority revision, bounded freshness,
public keys and per-key credential/issuance grants, without a legacy fallback.
Issuer-only pairings do not require or acquire verifier authority.

Before token exchange or proof input, `verified_issuance.rs` requires an exact
owner-granted service/configuration/wire-format/VCT mapping to permitted signed
issuers. Delegated authorization-server/token endpoints must match explicit
grants. Service URLs are not inferred from DIDs, and a key trusted for a VCT does
not authorize every service or issuer.

The receipt freezes selected endpoints, configuration, format/type, holder,
scope and revision. Fresh authority is checked before the credential request.
The response stays native behind a one-use opaque handle. Finalization requires
authority observed after that response, unchanged scope/revision/grants, and
verification of the exact credential's issuer signature, holder binding, type,
format and times. Only then can Dart store it. One capacity reservation follows
awaited transitions and releases on failure/drop.

One unambiguous singular credential or final credential object is accepted.
Empty, malformed, oversized, batch, mixed singular/plural and deferred responses
are rejected. Any key-attestation requirement is rejected before exchange/signing.

## Authenticated presentation and consent

`verifier_governance.rs` and Core authenticate the original signed request using
the supported governed DID verifier profile. Device evidence supplies bounded
authority; it does not replace signature/DID authentication. The exact request,
recipient and supported query semantics are bound before consent. Unsupported
security-relevant semantics are rejected rather than silently omitted.

`governed_presentation.rs` owns bounded review/preparation handles. The exact
credential is authenticated with fresh issuer evidence and the paired holder
before returning consent data. Issuer evidence must match the verifier's entire
pairing scope. Its revision is frozen and rechecked at preparation/completion;
failed transitions consume their handles.

Consent shows the authenticated recipient, always-shared signed payload members
and protected-header metadata alongside optional disclosures. Exact JSON text
preserves identifiers, nested values and types. Metadata URLs/certificates are
not resolved by the view. Rust enforces the approved disclosure set and verifies
the remote signature before submission. Decoding or matching a digest alone does
not authenticate a request.

## Qualification boundaries

The ordinary native suite ignores provider-only cases. The owned-fixture driver
`scripts/qualify_native_wallet_governance.py --artifacts <compiler-jsonl>`
discovers compiled cases before allocation and explicitly executes real
non-exportable TLS/Transit issuance/presentation with synthetic governance and a
controlled issuer. Test collection is not provider execution.

The UI holder driver supports `--holder-test-binary <ui-artifact>` and optional
`--native-wallet-test-binary <auth-artifact>`. The latter joins real PostgreSQL
Trust Profile/router, keyless HTTPS, typed Device authority, confirmed issuer-only
pairing and remote holder signing to native receipt operations. A persisted
service grant changes after a response and fresh finalization must reject it.
Both artifacts are discovered before allocation. The OID4VCI issuer and PDP are
controlled fixtures, so this does not qualify deployed Issuance or gateway routing.

Flutter widget tests, native/provider execution, generated-binding parity,
Android builds and unsigned iOS configuration are separate evidence. A mocked
client's success is not native acceptance. A JavaScript build is not public WASM
regeneration or browser storage/migration acceptance.

PR 57 remains draft while applicable artifact/storage migration, deployed issuer,
installed Android/iOS and independent interoperability gates are unfinished.
Status stays unknown without authenticated authority, verified proofs and
freshness. Server-verifiable liveness remains explicitly unsupported; challenge
parsing alone is not liveness verification. No full Final/HAIP conformance or
production readiness is implied. Earlier snapshot counts remain historical in
Git/PR/audit records and do not qualify a later combined candidate.
