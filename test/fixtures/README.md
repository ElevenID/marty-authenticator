# Wallet protocol vector ownership

`oid4vc_conformance_fixtures.dart` belongs to the OID4VCI/OID4VP wallet tests in
`test/integration`. Keep those behavior tests and their wire vectors together.
The retired Integration Python generator is no longer an update dependency.
Core owns native verification; Verifier owns its offline adapter vectors.

The wallet's final presentation request uses DCQL/entity_id; the legacy request
retains Presentation Exchange/redirect_uri coverage. Both stay. Final/draft
SD-JWT metadata, inline/reference offers, OAuth/token/nonce handling and the
JWT-VC/SD-JWT response cases and the mDoc response fixture also stay. The latter
has no current behavior-test consumer and awaits a wallet behavior gate; retaining
it does not establish mDoc support. Legacy metadata omits optional
claim-display data; its final metadata still covers that shape. The mDoc bytes
and zero-signature credential strings are transport/parser stubs, not valid
credentials or cryptographic issuance evidence. Their differing historical
lengths must not drive verification behavior.

Do not bulk regenerate these vectors from another repository: the representations
have diverged in final request shape and metadata. Add/update the relevant wallet behavior case for a
protocol change. These local suites are owned regression checks, not official
OIDF qualification. Future cryptographically signed vectors belong to the
maintained Rust managed-signing test facilities; retain public material only.
