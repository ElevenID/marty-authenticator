import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const roots = [
  'android/app/src/main/kotlin/it/netknights/piauthenticator/handlers',
  'ios/Runner/SpruceID',
  'macos/Runner',
];
const forbidden = [
  /\b(?:KeyManager|generateSigningKey|signPayload)\b/,
  /\b(?:placeholder|dummy)\b/i,
  /["'](?:valid|verified|isValid|idVerified)["']\s*(?::|to)\s*true\b/,
];

function* sources(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      yield* sources(path);
    } else if (entry.isFile() && /\.(?:kt|swift)$/.test(entry.name)) {
      yield path;
    }
  }
}

for (const root of roots) {
  for (const path of sources(resolve(root))) {
    const source = readFileSync(path, 'utf8');
    if (forbidden.some((pattern) => pattern.test(source))) {
      throw new Error(`local signing or mock success remains in ${path}`);
    }
  }
}

for (const name of ['pubspec.yaml', 'pubspec.lock']) {
  const source = readFileSync(resolve(name), 'utf8');
  if (/pi[_-]authenticator[_-]legacy/.test(source)) {
    throw new Error(`legacy private-key plugin is in the app graph: ${name}`);
  }
}

for (const path of [
  'lib/models/liveness_challenge.dart',
  'lib/views/document_verification/liveness_check_view.dart',
]) {
  const source = readFileSync(resolve(path), 'utf8');
  if (/MARTY_LIVENESS_SIGNING_SECRET|createLivenessChallenge|verifyLivenessChallenge|signingSecret/.test(source)) {
    throw new Error(`local liveness signing remains in active Flutter code: ${path}`);
  }
}

for (const path of [
  'local_plugins/pi-authenticator-legacy',
  'ios/Runner/AppDelegate.swift.original',
  'lib/services/spruce_api_server.py',
  'lib/services/spruce_backend_service.py',
]) {
  if (existsSync(resolve(path))) {
    throw new Error(`retired local-key source remains in the repository: ${path}`);
  }
}

console.log('mobile and desktop custody source guard passed');
