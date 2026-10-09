# Public protocol WASM

These files were generated from `ElevenID/marty-credentials` commit
`fef8da1459ca2494cb6ae71364210ce26cfb5b5d`, crate `rust/marty-rs`
version `0.1.79`, with the hardened Marty Core pin at
`d41d87cc2ef8eeaddbb9d659c2ac5642f7a0ce82`.

Build from that Credentials checkout:

```sh
cargo build --locked --release --target wasm32-unknown-unknown -p marty-rs --no-default-features --features wasm
wasm-bindgen --target web --out-dir ./safe-web target/wasm32-unknown-unknown/release/_marty_rs.wasm
```

Copy the generated JavaScript, WASM, and TypeScript declarations from
`safe-web` into this directory. The generated module exports public protocol
and verification helpers, with no key generation or raw-JWK signing APIs.
`verify_jwt_claims` checks JWT structure and claims only; it does not verify
the signature. Keep cryptographic verification on its qualified native route.

The web loader exposes only the public helper allowlist. Any replacement must
pass an export audit that rejects local key generation and signing before it
is shipped.
