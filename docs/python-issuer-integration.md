# Python issuer integration: unfinished feature intent

Status: unimplemented integration proposal. The isolated `ssi_python` development
prototype and its build-success report were retired; their code is recoverable
at Authenticator commit `ac446f4`. They had no app, Docker or CI consumers and
were not the wallet's supported Rust bridge. Deleting that unused implementation
does not close or cancel the following feature work.

A future Python/PrivacyIDEA-side issuer integration would need:

| Feature | Missing work and acceptance |
| --- | --- |
| DID and public-key operations | Use canonical DID/JWK owners for P-256 and Ed25519, standard DID encoding/resolution, public-only projections and canonical public JWK thumbprints. Prove independent known vectors and malformed/unknown-method rejection. The prototype hashed serialized private JWKs and returned empty resolver keys. |
| mDoc issuance and MSO | Implement actual ISO 18013-5/COSE signing, claim digests, validity and holder/device binding through canonical owners and approved issuer key custody. Independently verify issued documents and reject tampering, wrong holder and expired material. The prototype returned unsigned simplified CBOR. |
| OID4VCI | Integrate authorization-code/pre-authorized offers, metadata, credential responses and deferred issuance with the current canonical service contract. Validate signature, issuer, expiry, scope, replay and credential binding; nonempty strings are not token validation. |
| Service integration | Select an actual consuming service, authorization/tenant boundary, deployment/package owner and supported API before adding a Python package. Prove public end-to-end issuance and negative isolation cases against the real consumer. |

These requirements are open; no standards, production or release acceptance is
claimed. Reuse canonical Marty protocol/crypto implementations instead of
restoring a second decision implementation. Current wallet features continue
through `rust/`, generated Flutter Rust Bridge, the Marty SDK and native SpruceID
platform handlers; their code, dependencies and tests remain in place.

The unused Woodgrove page-dump script was also retired. Live credential and
presentation QR acquisition and their Make targets remain supported test tools;
future external-wallet interoperability needs asserted results and explicit
source/release binding rather than an HTML dump.

The old development-network notes also proposed a four-service local
PrivacyIDEA/Firebase/web topology and build-time wiring for
`USE_FIREBASE_EMULATOR`, `FIREBASE_AUTH_EMULATOR_HOST`,
`FIRESTORE_EMULATOR_HOST` and `PRIVACYIDEA_URL`, ending in an mDoc offer journey.
That topology is not delivered by current Compose. If revived, it needs a newly
owned emulator/service design, explicit build-time configuration and a real
end-to-end offer/issuance test; the current SSE app and native integrations remain.
