import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const webRoot = resolve(process.argv[2] ?? 'web');
const sourceRoot = resolve('web');
const packageDir = resolve(webRoot, 'marty_rs');
const allowed = new Set([
  'create_authorization_response',
  'create_credential_offer',
  'default',
  'dtc_create',
  'dtc_verify',
  'extract_credentials_from_vp',
  'generate_offer_uri',
  'get_version',
  'health_check',
  'initSync',
  'init_panic_hook',
  'open_badge_ob2_verify',
  'open_badge_ob3_verify',
  'verify_jwt_claims',
]);
const forbidden = new Set([
  'generate_p256_key',
  'generate_ed25519_key',
  'create_verifiable_credential',
  'create_presentation',
]);
const files = [
  '_marty_rs.js',
  '_marty_rs_bg.wasm',
  '_marty_rs.d.ts',
  '_marty_rs_bg.wasm.d.ts',
];

for (const name of files) {
  const source = readFileSync(resolve(sourceRoot, 'marty_rs', name));
  const built = readFileSync(resolve(packageDir, name));
  const digest = (data) => createHash('sha256').update(data).digest('hex');
  if (digest(source) !== digest(built)) {
    throw new Error(`web artifact does not match reviewed source: ${name}`);
  }
}

if (existsSync(resolve(webRoot, 'assets', 'packages', 'marty_rs', '_marty_rs_bg.wasm'))) {
  throw new Error('legacy marty_rs package WASM is still shipped');
}

const wasm = readFileSync(resolve(packageDir, '_marty_rs_bg.wasm'));
const module = await import(pathToFileURL(resolve(packageDir, '_marty_rs.js')));
const unexpected = Object.keys(module).filter((name) => !allowed.has(name));
if (unexpected.length !== 0) {
  throw new Error(`unexpected WASM JavaScript exports: ${unexpected.join(', ')}`);
}
const rawExports = WebAssembly.Module.exports(new WebAssembly.Module(wasm));
for (const name of forbidden) {
  if (name in module || rawExports.some((entry) => entry.name === name)) {
    throw new Error(`private-key operation exported by WASM: ${name}`);
  }
}

module.initSync({ module: wasm });
if (JSON.parse(module.health_check()).status !== 'ok') {
  throw new Error('public WASM health check failed');
}
const offer = JSON.parse(
  module.create_credential_offer(
    'https://issuer.example',
    '["ExampleCredential"]',
    undefined,
    false,
  ),
);
if (offer.credential_issuer !== 'https://issuer.example') {
  throw new Error('public WASM credential-offer contract failed');
}
console.log(`public WASM artifact passed: ${webRoot}`);
