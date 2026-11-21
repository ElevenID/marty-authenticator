# Browser wallet storage

Web storage uses upstream `flutter_secure_storage_web` 2.1.1, pinned with its
published package digest. Its WebCrypto AES-GCM storage requires HTTPS or
localhost. It is browser origin storage: application code on that origin can
access the encryption key and data. It does not protect against a compromised
origin or replace native OS storage. Identity signing keys remain exclusively
in the paired remote KMS. No wrapping secret or identity private key is embedded
in the application. Production activation and hosting changes remain separate.

The browser-only startup hook wraps the registered upstream backend. It encodes
both `dbName` and `publicKey` into a versioned destination namespace; upstream
selects storage using `publicKey`, so forwarding `dbName` alone is insufficient.
Session storage is distinct from persistent storage. Native Android/iOS/desktop
plugin registration is unchanged.

## Migration and recovery

Close older wallet tabs before upgrading. The new code serializes operations
with an exclusive browser Web Lock per namespace; old application versions do
not participate in that protocol. Insecure contexts or unavailable locks refuse
storage operations before reading or modifying records. Lock acquisition has a
30-second deadline; an operation already holding the lock is not detached by a
timeout while its data transitions are still in flight.

Before any backend operation, the wrapper inventories the exact encrypted
namespace. Existing ciphertext without its encryption key refuses access before
upstream can initialize a replacement key. Every existing ciphertext entry must
decrypt successfully: upstream's null-on-error/skip-on-readAll behavior is
converted into an explicit recovery error, preserving bytes and preventing an
apparently empty wallet. Invalid ciphertext or keys are never reset automatically.

Only recognized receipt, layout and pairing records from the old exact database
namespace are migrated. The adapter bounds record count and size, requires
canonical base64 and valid UTF-8/JSON, checks receipt ID consistency and layout
shape, and rejects private recovery fields in pairing metadata. Consumers still
perform their own parsing, authentication and verification: migration confers no
trust and imports no retired raw credential/index format as a verified receipt.
Unknown historical records remain in their original location for recovery.

For each supported record, the adapter writes to the encrypted backend, verifies
exact readback, rereads the source to detect an intervening change, and only then
removes that original entry. An interruption after a verified copy is resumable:
an identical destination is checked again. Conflicting copies, corrupt data,
write/readback failures and changed originals fail closed and preserve the
remaining originals. There is no plaintext fallback or destructive reset. The
wallet displays a storage-unavailable message with a retry action instead of
silently presenting an empty wallet. Do not clear browser data to resolve a
conflict; retain it for an authorized recovery decision.

Custom public-key and session options do not consume legacy persistent records,
whose old backend ignored those options. Scoped deletion removes only its new
namespace. Receipt clearing leaves pairing and layout records intact; unrelated
preferences and unknown historical records are preserved.

## Qualification

Adapter failure tests run with controlled stores:

```sh
flutter test --no-pub test/services/browser_storage_migration_test.dart
```

For real browser storage, build the test-only entrypoint separately in JS and
WASM and give each build a fresh loopback origin. The harness contains only
synthetic values and refuses an existing/unmarked origin. It exercises the real
wallet store and card-state provider, upstream WebCrypto and browser locks.

```sh
flutter build web --release --no-pub -t test_support/browser_storage_acceptance.dart --output /tmp/marty-storage-js
flutter build web --release --no-pub --wasm -t test_support/browser_storage_acceptance.dart --output /tmp/marty-storage-wasm
python scripts/serve_browser_storage_acceptance.py --root /tmp/marty-storage-js
```

The server prints its fresh origin and nonce. Navigate sequentially to that
origin with `?phase=<phase>&nonce=<printed-nonce>` for `seed`, `migrate`, `reload`,
`namespaces`, `malformed`, `encrypted-recovery` and `delete`. Each page must report `passed` through
`document.documentElement.getAttribute('data-marty-storage-result')`. Repeat on
a new port for WASM, checking resource evidence for `main.dart.mjs` and
`main.dart.wasm` with no `main.dart.js` fallback. An actual insecure-origin check
uses `127.0.0.1.nip.io` resolving to loopback on the same fixture port with phase
`insecure`; it must report false `isSecureContext` and leave storage empty.

The server binds only 127.0.0.1 and automatically stops after 15 minutes. Retire it
normally by posting an empty body to `/__marty_owned_browser_stop` with its nonce
in `X-Marty-Test-Nonce`; a foreign nonce is refused. Remove only nonce-verified
synthetic browser entries and close test tabs after qualification. These tests
do not qualify native installation, actual credential issuance/signatures,
deployed services, public protocol WASM regeneration or external interoperability.
