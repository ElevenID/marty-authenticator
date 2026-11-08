# Wallet status authority

The raw `evaluate_bitstring_status(entry_json, status_list_credential_json)`
bridge is retained for ABI compatibility, but it cannot establish an authorized
status-list issuer or key. It returns `STATUS_AUTHORITY_UNAVAILABLE` instead of
promoting a decoded bit or nonempty proof object into a successful decision.
This is an explicit capability gate: production status checks through this raw
API remain unknown.

Activation requires a native governed resolver and Core verification that binds
the credential's status entry to the authorized issuer and assertion key, signed
list ID and purpose, proof, validity period, and freshness deadline. Caller JSON,
an HTTPS connection, and key material embedded in a list do not establish that
authority. Core already verifies authenticated status evidence in its Open Badges
path; the wallet must use an appropriate public verification contract rather than
copying its proof or authorization logic into Dart.

Dart performs bounded HTTPS retrieval without redirects and caches untrusted
bytes for at most five minutes. Each use still crosses the native evaluation
boundary. Failed, stale, future-dated, or incomplete checks display as unknown;
successful asserted suspension displays as suspended. An asserted entry cannot
be overwritten by a later clear entry for the same purpose.

The regression fixtures intentionally contain untrusted and invalid proofs.
They must never produce a successful native status decision. Dart test doubles
exercise transport and display projection only, not signature verification.
The staged holder-key and presentation-session work in PR #57 is independent
of this gate; this change retains the existing status bridge signatures.
