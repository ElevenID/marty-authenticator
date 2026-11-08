# Verified wallet integration — W14

This is the continuation of the fork and protocol implementation plan's W14,
using the existing Authenticator PR 57. The November 7 integration reconciles
the earlier remote KMS wallet work with main's reviewed dependency foundation
and Open Badges 3 retirement changes. It does not release a wallet artifact.

## Dependency and API boundary

The merged foundation pins remain authoritative in `rust/Cargo.toml` and
`rust/Cargo.lock`: Core `11655e38c2dbf69bfa5bc3c873f80c5fad628723` and Verifier
`ab126edaa4ed381d86d9ee89c4b72ca70b40490d`, with the reviewed private SSI,
SD-JWT, isomdl and independent linked-data sources. The wallet graph retains
its holder role without enabling the issuer feature; wallet dependencies also
enable verifier support. The integration adds the existing SHA-256 dependency used
for request digests without changing the reviewed dependency families.

The existing PR 57 Flutter/Rust bridge API is retained. The native implementation
receives public keys and exact remote signatures; issuer and holder private
keys do not enter the bridge. Display parsing is not credential verification.

## Receipt behavior

The native QR preview freezes a fetched offer into a bounded inline offer. The
approval dialog and acceptance operation use that same snapshot, preserving
the issuer, configuration IDs, grant and transaction-code requirements even if
the original referenced resource changes. No second reference fetch is needed.

The verified receipt path now accepts the OID4VCI 1.0 response containing one
credential object in `credentials`. A singular legacy `credential` remains
accepted only when the response is unambiguous. Empty, malformed, oversized,
multiple-credential, mixed singular/plural and deferred responses are rejected.

Both accepted encodings use the same Core verification path before a receipt
is returned: a fresh governed issuer-key snapshot, exact authenticated issuer
identity and key resolution, the paired holder key, and the selected credential
type and format. A correctly shaped response alone does not admit a credential.
The issuance service URL is not assumed to equal a credential's DID issuer;
OID4VCI 1.0 section 14.4 permits those identifiers to differ. Any additional
relationship policy needs an explicit governed mapping.

The supported proof profile has no key-attestation capability. Any presence of
`proof_types_supported.jwt.key_attestations_required`, including an empty object,
is therefore rejected before token exchange or signing. Omission is required;
an empty requirement object does not make attestation optional.

## Presentation approval behavior

Rust checks the exact selected optional-disclosure set before producing a holder signing
input. The supported request subset is one credential with unique, bounded,
simple claim names. Missing or additional selections, duplicate selections,
duplicate requested names, and unsupported nested/wildcard paths are rejected.
The same boundary applies to the retained legacy Presentation Exchange adapter.
An empty claim request selects no optional disclosures.

The authenticated SD-JWT format must exactly match the selected DCQL format.
For the legacy Presentation Exchange adapter, an exact format entry takes
precedence over the `sd_jwt_vc` alias; the alias accepts either supported SD-JWT
format when no exact entry is present. The matching entry's issuer-algorithm
restriction is enforced during issuer-key resolution and signature verification.
An algorithm accepted for another format cannot authorize the selected one.

The digest binds the fields retained in Core's parsed request, including the
nonce, audience, response destination, state and supported query. It does not
authenticate the request sender or preserve fields the parser omits. The
session retains that parsed request and is consumed before remote signature
verification and submission, including failure paths. The exact remote signature
must verify under the paired public holder key.

Both legacy raw presentation submission endpoints, including the ZK endpoint,
now reject before parsing or network access. Their generated ABI remains for
compatibility, but it lacks the approval and trust context required to submit.

## Main reconciliation

Main's Final issuance metadata lookup and plural proof request tests remain.
The retired raw-JWK signing ABI and unverified credential provider remain
removed. Tests that arrived on main against those retired interfaces now cover
verified receipts or explicit unsupported outcomes. Supported native method
channel verification and presentation-selection forwarding retain positive
tests. OB2 rejection and OB3 selection remain covered.

## Qualification record

The full validation record is maintained in PR 57. The integration has passed
the private dependency reader tests (11), custody source guard, native Rust tests
(57), Flutter analysis, complete Flutter tests (276 passed, four existing SIOPv2
skips), wallet acceptance tests (3), and a standard JavaScript release web build.
After the independent review fixes, the two affected Flutter suites also pass
(18 tests) and analysis remains clean. Regression tests cover the frozen QR
snapshot, exact format/algorithm agreement, key-attestation requirements, Final
response verification, optional disclosures and retired raw presentation
endpoints. Native tests use the locked dependency graph and the matching genuine
ONNX Runtime 1.24.2 CPU library through ort-sys's supported dynamic-link settings.

`rust/src/api.rs` and generated FRB Rust/Dart files remain unchanged from the
original PR 57 head. The public web artifact hash/export/health/offer audit passes
against the checked-in artifacts; those artifacts still identify Credentials
`fef8da1` and Core `d41d87c`. That result does not establish regeneration against
the new fork graph. The successful JavaScript web build does not qualify the
optional Flutter WASM build, which reports an FRB JS-interop incompatibility.

Two independent source reviews are required before publishing this continuation.
Review findings are fixed in source or tracked below as explicit activation gates;
the PR records the completed review dispositions.

## External acceptance gates

PR 57 must remain draft until the following are addressed and qualified:

- **Authenticated verifier and destination.** Core's request-object path decodes
  a JWT payload without verifying its signature. Consent currently displays the
  raw `client_id`, while the actual HTTPS `response_uri` can differ. W04 must
  implement the supported request/client authentication profile and show and
  bind the actual recipient. A digest of parsed fields is not that authentication.
- **Complete request semantics.** Fields such as `client_id_scheme` and
  `transaction_data` are not retained in the parsed request. Unsupported security
  semantics must be rejected or implemented before external conformance claims.
- **Complete disclosure consent.** The exactness checks cover optional
  disclosures. Cleartext signed claims and identifiers remain in the issuer JWT
  and are not yet listed in the consent view. Display verified always-shared
  claims alongside the optional set, or constrain the profile before acceptance.
- **Issuance-service relationship.** The signed issuer is authenticated against
  the governed key snapshot, but that snapshot does not map the selected service
  and configuration to allowed credential issuers. Define that relationship
  explicitly; equating a service URL with a credential DID is not a valid fix.
- **Deployment evidence.** Real remote KMS signing, installed Android/iOS behavior,
  browser storage migration, regenerated public artifacts and external
  interoperability still require qualification.

Successful source tests do not establish real remote KMS acceptance, installed
Android/iOS behavior, browser storage migration or external interoperability.
Those gates remain open, and PR 57 remains draft until its required acceptance
is complete. Broader Final/HAIP request semantics and authenticated request-object
handling belong to W04; this change does not advertise full Final conformance.

References: [OpenID4VCI 1.0 sections 8.3, 12.2.4 and 14.4](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
and [OpenID4VP 1.0](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html).
