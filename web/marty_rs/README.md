# Public protocol WASM

These files were generated from `ElevenID/marty-credentials` commit
`f77b37292b61f1490ccec6539b04391ddc124eb0`, crate `rust/marty-rs`
version `0.1.79`, with the hardened Marty Core pin at
`b30866a81284d97b65a3e4cdd85e917df17e10d4`.
The locked build used Rust 1.95.0 and wasm-bindgen 0.2.127.

Build from that Credentials checkout:

```sh
cargo +1.95.0 build --locked --release --target wasm32-unknown-unknown -p marty-rs --no-default-features --features wasm
wasm-bindgen --target web --out-dir ./safe-web target/wasm32-unknown-unknown/release/_marty_rs.wasm
```

Copy the generated JavaScript, WASM, and TypeScript declarations from
`safe-web` into this directory. The generated module exports public protocol
and verification helpers, with no key generation or raw-JWK signing APIs.
Removed local-key APIs, unverified JWT-claims extraction and obsolete OB2
verification are not exported. Keep wallet identity signing and credential
verification on their governed, qualified native routes.

The web loader exposes only the public helper allowlist. Any replacement must
pass an export audit that rejects local key generation and signing before it
is shipped.
