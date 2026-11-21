# Public protocol WASM

These files were generated from `ElevenID/marty-credentials` commit
`76ab864203ff794d28309a220d87aa292d93c9d2`, crate `rust/marty-rs`
version `0.1.79`, with the hardened Marty Core pin at
`11152cfb83ec47174a21ad76fd4c9e811c93602f`.
The locked build used Rust 1.97.1 and wasm-bindgen 0.2.127.

Build from that Credentials checkout:

```sh
cargo +1.97.1 build --locked --release --target wasm32-unknown-unknown -p marty-rs --no-default-features --features wasm
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
