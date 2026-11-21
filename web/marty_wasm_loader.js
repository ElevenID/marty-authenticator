import init, * as martyRs from './marty_rs/_marty_rs.js';

try {
  await init(new URL('./marty_rs/_marty_rs_bg.wasm', import.meta.url));
  globalThis.marty_rs = {
    create_credential_offer: martyRs.create_credential_offer,
    generate_offer_uri: martyRs.generate_offer_uri,
    create_authorization_response: martyRs.create_authorization_response,
    get_version: martyRs.get_version,
    health_check: martyRs.health_check,
  };
} catch (error) {
  console.error('Failed to initialize marty-rs WebAssembly', error);
}
