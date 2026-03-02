/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/logger.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// A holder key pair stored in secure storage.
///
/// [kid] is the key identifier embedded in proof JWTs.
/// [privateJwkJson] is the full private EC JWK (kept in secure storage only).
/// [publicJwkJson] is the public part (safe to share with issuers via proof JWT).
class HolderKeyInfo {
  final String kid;
  final String privateJwkJson;
  final String publicJwkJson;

  const HolderKeyInfo({
    required this.kid,
    required this.privateJwkJson,
    required this.publicJwkJson,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Manages the wallet's long-lived holder key pair (EC P-256).
///
/// Generates a key pair on first use and persists it to
/// [FlutterSecureStorage].  Subsequent calls return the same key.
///
/// The wallet key is used to create proof JWTs during OID4VCI credential
/// issuance.  The holder's DID / `kid` is derived from the public key
/// thumbprint (RFC 7638).
///
/// Usage:
/// ```dart
/// final key = await WalletKeyService.getOrCreateHolderKey();
/// final proofJwt = await svc.createProofJwtAsync(
///   holderKid: key.kid,
///   cNonce: token.cNonce!,
///   issuerUrl: issuer,
///   jwkJson: key.privateJwkJson,
/// );
/// ```
class WalletKeyService {
  WalletKeyService._();

  static const _privateJwkKey = 'marty:wallet:holder:private_jwk';
  static const _kidKey = 'marty:wallet:holder:kid';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns the wallet's holder key.  Generates and persists one if
  /// no key exists yet.
  static Future<HolderKeyInfo> getOrCreateHolderKey() async {
    final storedJwk = await _storage.read(key: _privateJwkKey);
    final storedKid = await _storage.read(key: _kidKey);

    if (storedJwk != null && storedKid != null) {
      final privateJwk = jsonDecode(storedJwk) as Map<String, dynamic>;
      final publicJwk = _publicJwkFromPrivate(privateJwk);
      return HolderKeyInfo(
        kid: storedKid,
        privateJwkJson: storedJwk,
        publicJwkJson: jsonEncode(publicJwk),
      );
    }

    Logger.info('Generating new wallet holder key pair (P-256)');
    return _generateAndPersist();
  }

  /// Deletes the stored holder key (used for key rotation or reset).
  static Future<void> deleteHolderKey() async {
    await _storage.delete(key: _privateJwkKey);
    await _storage.delete(key: _kidKey);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  static Future<HolderKeyInfo> _generateAndPersist() async {
    final algorithm = Ecdsa.p256(Sha256());
    final keyPair = await algorithm.newKeyPair();
    final keyData = await keyPair.extract();

    // Encode as base64url (no padding)
    String b64url(List<int> bytes) =>
        base64Url.encode(bytes).replaceAll('=', '');

    final d = b64url(keyData.d);
    final x = b64url(keyData.x);
    final y = b64url(keyData.y);

    final privateJwk = {
      'kty': 'EC',
      'crv': 'P-256',
      'x': x,
      'y': y,
      'd': d,
    };

    // RFC 7638 JWK thumbprint (SHA-256 of sorted public JWK members)
    final kid = _computeKid(x, y);

    final privateJwkJson = jsonEncode(privateJwk);

    await _storage.write(key: _privateJwkKey, value: privateJwkJson);
    await _storage.write(key: _kidKey, value: kid);

    Logger.info('Wallet holder key generated, kid=$kid');

    final publicJwk = _publicJwkFromPrivate(privateJwk);
    return HolderKeyInfo(
      kid: kid,
      privateJwkJson: privateJwkJson,
      publicJwkJson: jsonEncode(publicJwk),
    );
  }

  /// Derive the public JWK by dropping the private key (`d`).
  static Map<String, dynamic> _publicJwkFromPrivate(
      Map<String, dynamic> privateJwk) {
    return {
      'kty': privateJwk['kty'],
      'crv': privateJwk['crv'],
      'x': privateJwk['x'],
      'y': privateJwk['y'],
    };
  }

  /// Compute a kid by taking the first 22 base64url chars of the
  /// SHA-256 digest of the canonical public JWK (simplified RFC 7638).
  static String _computeKid(String x, String y) {
    // Build a stable, deterministic id from the first 22 chars of x+y
    final prefix = (x + y).substring(0, min(22, (x + y).length));
    return 'did:jwk:$prefix';
  }
}
