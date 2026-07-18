import init, * as martyRs from '/assets/packages/marty_rs/_marty_rs.js';

try {
  await init('/assets/packages/marty_rs/_marty_rs_bg.wasm');
  globalThis.marty_rs = {
    ...martyRs,
    create_verifiable_credential: (
      issuerDid,
      issuerJwk,
      subjectId,
      credentialType,
      claims,
      expirationSeconds,
    ) => martyRs.create_verifiable_credential(
      issuerDid,
      issuerJwk,
      subjectId,
      credentialType,
      claims,
      expirationSeconds == null ? null : BigInt(expirationSeconds),
    ),
  };
} catch (error) {
  console.error('Failed to initialize marty-rs WebAssembly', error);
}
