# Verified wallet integration — W14

This is the continuation of the fork and protocol implementation plan's W14,
using the existing Authenticator PR 57. The November 7 integration reconciles
the earlier remote KMS wallet work with main's reviewed dependency foundation
and Open Badges 3 retirement changes. It does not release a wallet artifact.

## Dependency and API boundary

The current development pins in `rust/Cargo.toml` and `rust/Cargo.lock` are
Core `dbb7cfa9ef92dd26e836e64cbfe2b3022e8687f0` and Verifier
`dc24be7118cee57863a89f5c0c78617a22e74085`, with the reviewed private SSI,
SD-JWT, isomdl and independent linked-data sources. The wallet graph retains
its holder role without enabling the issuer feature; wallet dependencies also
enable verifier support. The integration adds the existing SHA-256 dependency used
for request digests without changing the reviewed dependency families.

These provisional published prerequisites are Core #440 and Verifier #196;
they must be replaced with their verified accepted main commits and the exact
graph requalified before merge eligibility. The prior merged foundation was
Core `11655e38` / Verifier `ab126eda`. Upgrading only the direct Core pins failed
resolution because the old transitive sync graph required Cedar4.12 while the
new Core requires4.14. The canonical sync prerequisite aligns its Core graph
and exact SQLCipher fork with Core; it retains encryption and existing
`kms-only`/verification roles. No issuer capability is added to the wallet.

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
digest recursively sorts object keys so independently parsed HashMaps do not
cause spurious approval mismatches; array order and values remain bound. The
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

## Historical qualification record

The full validation record is maintained in PR 57. The integration has passed
the private dependency reader tests (11), custody source guard, native Rust tests
(58), Flutter analysis, complete Flutter tests (276 passed, four existing SIOPv2
skips), wallet acceptance tests (3), and a standard JavaScript release web build.
After the independent review fixes, the two affected Flutter suites also pass
(18 tests) and analysis remains clean. Regression tests cover the frozen QR
snapshot, exact format/algorithm agreement, key-attestation requirements, Final
response verification, optional disclosures and retired raw presentation
endpoints. Native tests use the locked dependency graph and the matching genuine
ONNX Runtime 1.24.2 CPU library through ort-sys's supported dynamic-link settings.

The pinned FRB 2.13.0 generator completed successfully. `rust/src/api.rs` and
generated FRB Rust/Dart/C files remain unchanged from the original PR 57 head.
The public web artifact hash/export/health/offer audit passes
against the checked-in artifacts; those artifacts still identify Credentials
`fef8da1` and Core `d41d87c`. That result does not establish regeneration against
the new fork graph. The successful JavaScript web build does not qualify the
optional Flutter WASM build, which reports an FRB JS-interop incompatibility.

Two independent source reviews passed for this draft continuation. Their findings
resulted in the attestation, offer snapshot, format/algorithm, retired ZK endpoint,
and deterministic request-digest corrections. The PR records the review
dispositions; the remaining activation gates are explicit below.

## External acceptance gates

PR 57 must remain draft until the following are addressed and qualified:

- **Authenticated verifier and destination.** The wallet's currently used legacy
  request-object path decodes a JWT payload without authenticating its signature.
  Core #439 supplies an accepted registered-client API and #440 adds governed DID
  semantics, but the wallet still needs their actual native session integration.
  Consent currently displays the
  raw `client_id` and the actual HTTPS `response_uri` separately; those identifiers can differ. W04 must
  implement the supported request/client authentication profile and bind the authenticated recipient. A digest of parsed fields is not that authentication.
- **Complete request semantics.** Fields such as `client_id_scheme` and
  `transaction_data` are not retained in the parsed request. Unsupported security
  semantics must be rejected or implemented before external conformance claims.
- **Disclosure consent qualification.** The native review now verifies the exact
  stored credential with fresh governed issuer keys and the paired holder key
  before returning all always-shared issuer payload members and protected-header
  signing metadata. The consent view displays these beside optional disclosures.
  Values cross the bridge as exact JSON text, retaining large numeric identifiers,
  nested values and types without web-number rounding. This projection grants no
  signing authority or verifier authentication. Final bridge and installed-wallet
  execution remain required.
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

### Consent projection source verification

The candidate loop excludes individual credentials that fail native verification
without deleting them or hiding other verified candidates. Trust/key acquisition
failures and malformed successful bridge projections abort review. Submission
keeps the exact token reviewed even if storage changes, and the existing native
preparation still checks the request and fresh issuer trust before signing.
The signing header is displayed as metadata; URLs and certificate fields are not
resolved from the consent view, and neither raw signature nor compact token is
returned in the projection.

Collected local evidence for this slice: five tests pass in a standalone Linux
Cargo subgraph importing the exact production review/trust modules and the pinned
Core revision. These include the existing public remote-signature vector,
forgery/wrong-holder/untrusted-issuer refusal, exact numeric/nested/escaped value
rendering and duplicate-member rejection. Two Linux consent widget tests pass,
covering immutable always-shared fields and switching credentials. These are
module/crypto-fixture and widget tests, not a whole native bridge, current remote
KMS execution, browser artifact regeneration or installed-wallet qualification.
The new String-returning bridge method has been regenerated with FRB2.13.0 and
the pinned Flutter3.44.6 SDK on Linux. The actual whole native bridge library
reports 67 passes with no skips; the three new review regressions are included
in that total. Focused Flutter orchestration/consent suites report 61 passes.
The exact committed candidate `9ef7e67a2b961dae13d876d214b8daa89e26a181` passed
full Flutter analysis and all 347 tests, with four existing SIOPv2 skips, in an
isolated detached checkout. The original working tree's unrelated changes were
preserved outside that candidate. The mobile/desktop custody source guard and
12 private-dependency reader tests also passed. No public WASM binary or installed
device was qualified; the request-authentication and live acceptance gates remain.

References: [OpenID4VCI 1.0 sections 8.3, 12.2.4 and 14.4](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
and [OpenID4VP 1.0](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html).

## November 15 current-main reconciliation

Reconciles main `1a396a0641ad3996c543fc782de97ca2d7546e93` without rewriting retained feature history. Main's dependency updates, native status boundary, retired proximity placeholder and dependency-reader guards remain. QR merge conflicts preserve native classification, explicit offer review and the separation between parsed content and verified receipt selection; scanned compatibility fields cannot trigger automatic acceptance or establish trust. Main's advisory QR test cases are ported to these current APIs. Sensitive-field warnings now appear in the actual presentation consent view, which also displays the exact response URI. That URI remains request-supplied until W04 authenticates it.

Historical validation on that combined source: locked Flutter dependencies restored with Flutter 3.44.6 / Dart 3.12.2; analysis reports no issues; 84 affected Flutter tests pass; full Flutter suite reports 334 passes and four existing SIOPv2 skips. These exercise mocked bridge/platform contracts and widgets. They do not execute the native Rust/KMS bridge, regenerate artifacts, install a device wallet or establish interoperable protocol acceptance. The then-observed lack of an incoming-authentication API is superseded by Core #439/#440; a pin change alone still cannot qualify the consumer.

Authentication/raw security semantics, issuance service/configuration-to-issuer governance, native issuer/KMS integration and all installed/artifact/external acceptance gates above remain open. Always-shared projection source work and its separately scoped checks are recorded above. No production behavior is activated by this draft source checkpoint.

## November 16 original authority evidence and dependency qualification

The paired transports now retain original strict UTF-8 JSON, use the confirmed
pairing's fixed HTTPS origin/bearer without redirects, enforce status/media and
byte bounds, and invalidate responses when that pairing changes. A single body
deadline cannot be extended by continuous chunks or a stalled cancellation
future. Verifier transport alone grants no authority. Issuance completion,
consent review and presentation preparation pass original issuer evidence to
native unique-member parsing and recursive private-material rejection before
typed conversion. This preserves the earlier Dart custody check while moving
validation to the native boundary.

At `f440223`, actual native tests reported69 passed0 ignored, and focused
mocked Flutter transport/orchestration tests reported36 passes with clean
analysis. After the provisional coherent Core/sync upgrade, actual native
execution reports70 passed0 ignored. The old policy fixture's bare verified
boolean correctly stopped authorizing a named profile under current Core; the
synthetic fixture now supplies its actual profile identity and missing/wrong
identity regression cases deny. No runtime policy check was weakened.

Independent source reviews identified the body-deadline and recursive private
material regressions; both were corrected and re-reviewed without remaining
findings. Reviewers executed no tests. Standard FRB2.13 generation passed on
this provisional graph: all13 generated Rust/Dart/C sources match their
preserved pre-generation bytes and the content hash remains175211210. The
initial local tool invocation exposed Clang headers to GCC while rebuilding
SQLCipher, then a scoped retry lacked ffigen's standard headers. Both failed
runs were rejected. Supplying Clang headers only to bindgen/ffigen fixed the
development tooling; no dependency or validation rule was relaxed. Final
accepted-graph qualification is recorded below. Actual authentication,
issuer governance, installed-device, artifact and interoperability execution
remain required.

## Accepted graph and PNG QR tooling repair

Core #440 merged at `8e06ee93b44aca4cb956cef5c2b74642620c736e` and
Verifier #196 merged at `117289db9b19bb21acbe992c4a58d4877a004ae9`.
Wallet commit `766c0ae90c061f1820e7543b2ad15264d7416765` uses those accepted
revisions for all seven direct Core dependencies and the sync dependency.
The eleven locked Core packages share that same revision. Package versions,
wallet/verifier/prover roles, `kms-only` enforcement and the pinned SQLCipher
closure remain unchanged. Actual native execution reports 70 passes and zero
ignores; Rust formatting and bridge Clippy with warnings denied pass.
Independent source review found no issue and executed no tests. This dependency
qualification does not establish native authenticated sessions or installed
wallet acceptance; FRB generation was not rerun for this pin-only change.

GitHub advisory [GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5)
affects Zod versions below 4.6.6. The Node QR tools inherited Zod 3 through Jimp's
editing plugins. Both callers produce PNG through Playwright screenshot/canvas
APIs, so they now use Jimp's existing `pngjs` 7.0.0 decoder directly. This removes
the Jimp/Zod closure without forcing an incompatible schema major version.
Retained package versions do not change. The decoder bounds encoded bytes and
dimensions and chunk structure before parsing, permits only the non-interlaced
8-bit RGB/RGBA profile produced by these browser APIs, preserves RGBA bytes and
transparency, and checks PNG CRCs. Duplicate headers and trailing data are
refused before decoding. Existing debug PNG output is ignored by Git.

Four synthetic Node tests pass with zero skips, both live-fetch scripts pass
syntax checks, and `npm audit` reports zero vulnerabilities in the resulting
tooling graph. The live external QR services were not contacted. The existing
Flutter test job installs the locked Node dependencies without lifecycle scripts
and runs these checks; no runner was added. This is local tooling evidence,
not hosted CI or external interoperability execution. The default-branch
Dependabot alert remains open until an accepted main change resolves it.

## Native managed-governance boundary under construction

An internal native module now admits the original strict, duplicate-free device
v2 envelope, rejects private/unknown material, checks the complete confirmed
scope and current presentation-holder thumbprint, and binds exact locator,
instance, callback, original-JWS digest and freshness. Enrolled public `kid`
metadata is admitted separately from the closed RFC 7638 hash members. Fresh
issuer evidence must match the same organization and confirmed issuer profile.
The authentication method delegates DID/key binding and original signed-request
verification to accepted Core and compares signed nonce/state/recipient/expiry
with owner evidence.

Actual native execution reports 72 passes with zero ignores, including scope,
holder, recipient, digest, clock and escaped-duplicate negatives and rejection
of forged JWS despite a well-scoped synthetic envelope. Formatting and bridge
Clippy with warnings denied pass. Independent review caught the enrolled-key
metadata mismatch; it was fixed and re-reviewed without remaining findings.
Reviewers executed no tests.

At `a82c0d28e6e9f56da31129cc78191cde32df92b4`, this module was internal,
deliberately unwired groundwork. Its temporary local dead-code allowance did
not relax runtime validation or qualify a product entry point. The following
checkpoint supplies native sessions and regenerated APIs; Dart product wiring
and installed acceptance remain required. The standalone presentation parser
is not authenticated by the existence of this module.

## Opaque native presentation API checkpoint

Four governed bridge operations now review, prepare, complete and cancel native
sessions. Review authenticates the original owner JWS through Core before
verifying the candidate against its signed type/VCT/algorithm policy. Only an
opaque handle and bounded authenticated request/always-shared consent projection
leave native storage; the exact credential remains frozen. Preparation consumes
that handle and accepts disclosures, rather than a replacement credential or
request. Completion verifies the remote signature against the original retained
signing input. Both transitions require fresh device scope, holder, verifier
authority and issuer evidence and reauthenticate the original signed bytes.

Storage bounds all ready and in-flight work to16 slots and a maximum60-second
consent lifetime. Transitions rotate handles, failures consume old handles, and
cancelled/expired callbacks cannot republish sessions. Locks never span network
awaits. Explicit guard destruction precedes the consumed reservation's destructor
to avoid a Rust2021 temporary-drop mutex deadlock caught by independent review.
The actual reservation wrapper now has publication/consumption/cancellation/
expiration regressions, separately from generic store tests.

The old preparation and completion bridge signatures always reject calls; their
historical implementation is compiled only for tests. The untrusted parser and
standalone issuer projection grant no signing or submission authority. The
temporary native dead-code allowance was removed. FRB2.13 generation succeeds,
changing seven generated outputs (content hash `-948931303`); the other six
generated files match their preserved bytes. Native tests report78 passes and
zero ignores; formatting, bridge Clippy with warnings denied and focused Dart
analysis pass. Reviewers executed no tests, and the corrected publication path
was re-reviewed without remaining findings.

At `b5b4793e2e14f9ec6c8c9ea17256471c32cc8eb9`, this was a native API checkpoint:
Dart still called the retired path. The next checkpoint supplies product wiring
as described below. Successful authenticated native lifecycle, paused device-HTTP
scope changes, installed wallet acceptance and official interoperability remain
separate execution gates.

## Governed Dart consent and remote-signing coordinator

The product bridge now calls the governed native operations. A QR supplies only
the client/locator selectors sent to the fixed authenticated paired-device
endpoint; duplicate, inline, alternate-transport and extra authority parameters
are refused. Original verifier/issuer JSON reaches native unchanged. Dart no
longer parses an unsigned request for consent or retains replacement credential
tokens for preparation. It displays the native-authenticated request and exact
always-shared lexemes, retains opaque native review handles and passes the
explicit approved disclosure set. The supported native DID/DCQL profile admits
signed VCT metadata; historical mocked Presentation Exchange success cases do
not establish support in this profile.

Preparation reads fresh governance, issuer trust and holder metadata. After the
remote signature arrives, completion reads all three again. Native remains
responsible for current scope, original JWS and credential policy, recipient
and stored signing-input verification. Reject/back/dispose, failed transitions,
expired choices, unused candidates and stale callbacks retire native handles;
rotated handles are registered before checking cancellation. A disposal signal
also settles navigation awaits, since disposing a Navigator does not guarantee
that its pushed-route future completes.

Actual mocked execution:41 orchestration/client tests and3 widget lifecycle
tests pass; focused analysis of8 source/test items is clean. Paused preparation,
paused signing, stale initiation, failed post-signing governance, cleanup order,
malformed native display shapes and disposed scanner results are exercised.
Independent source review found no remaining issue and ran no tests. The full
Flutter command ran356 passes/4skips but failed to load `version_test.dart`
because this assigned checkout has a pre-existing user deletion of tracked
`lib/model/version.g.dart`; that deletion is preserved. The subsequently added
QR rejection test is covered by the41-test focused run. Full exact-candidate
qualification must use an isolated checkout with the committed file present.
These mocked tests do not execute the real native signing/submission lifecycle,
installed wallet, managed owner/PDP deployment or official suites.

## Native remote-KMS and HTTPS qualification

The native application boundary now has two explicitly executed guarded cases.
The shared accepted Core test-support dependency creates only marked disposable
OpenBao sign-only keys; request, credential-issuer, presentation-holder and
binding keys remain non-exportable. Governance envelopes are synthetic fixture
inputs, not observations from deployed Device Registration/Trust Profile/PDP.

One process proves that an untrusted receiver CA cannot receive a presentation.
A separate process, with the fixture CA scoped to that child process, exercises
real Core DID/key/JWS authentication, exact signed VCT/algorithm policy, native
consent, preparation of the stored signing input, remote ES256 and one HTTPS
submission. The receiver captures the exact state and destination; native checks
the submitted issuer JWT, one approved disclosure, holder signature, full client
audience, nonce and disclosure hash. Replay, cancelled approval, changed user,
authority revision, holder version, a newly signed replacement request, removed
issuer keys, unsupported transaction semantics and policy mismatches fail closed.

Actual execution reports two cases passed with zero ignores and exactly one
HTTPS submission. The default native run separately reports78 passes and two
fixture-only ignores; collection is not execution. Four driver cleanup regressions
and12 private-fork boundary tests pass. Formatting and bridge Clippy with warnings
denied pass. FRB2.13 regeneration succeeds with all13 generated outputs byte
identical and content hash `-948931303`. No retained package identity/version was
removed or upgraded: five new test-only packages support the accepted remote
signers. Locked metadata retains `kms-only`, the wallet/verifier roles and no
OID4VCI issuer capability. All12 Core packages, including the dev-only fixture,
use accepted `8e06ee93b44aca4cb956cef5c2b74642620c736e`.

The existing bridge CI job now executes both guarded cases from the actual
compiler-recorded test executable; driver changes trigger the job. Its fresh
bounded local container and private TLS/capture directory are removed on success
or failure with exact ownership/nonce checks. An independent review caught a
cleanup ordering gap and missing workflow filters; both were fixed and the
cleanup regressions plus final native cases pass. Reviewers ran no tests. The
first self-signed receiver attempt failed during TLS submission; Core's error
did not expose the underlying TLS alert. The fixture now uses a separate root
and an issued serverAuth CA:false IP certificate, and both cases pass. TLS chain
and hostname checks are retained; no global trust store was changed.

This native application/provider qualification is stronger than mocks but does
not establish deployed governance, paused DeviceHTTP races, governed issuer-owner
admission, installed Android/iOS/Web wallet, rootless installer or official-suite
acceptance. Existing installations, services, production flags and cloud resources
were not changed.
