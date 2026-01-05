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

import 'dart:typed_data';

/// MMF Key Manager Interface.
///
/// Provides cryptographic key management operations. This is an MMF
/// infrastructure interface - credential-agnostic key operations.
/// Marty implements this using platform-specific secure enclaves.
abstract class IKeyManager {
  /// Generate a new key pair.
  ///
  /// Returns the public key. The private key is stored securely in
  /// the platform's secure enclave (Keychain/Keystore).
  Future<Uint8List> generateKeyPair({
    required String keyId,
    required KeyAlgorithm algorithm,
    bool requireBiometric = false,
  });

  /// Get the public key for a stored key pair.
  Future<Uint8List?> getPublicKey(String keyId);

  /// Sign data using a stored private key.
  ///
  /// May trigger biometric authentication if the key was created
  /// with `requireBiometric = true`.
  Future<Uint8List> sign({
    required String keyId,
    required Uint8List data,
    SignatureAlgorithm? algorithm,
  });

  /// Verify a signature using a public key.
  Future<bool> verify({
    required Uint8List publicKey,
    required Uint8List data,
    required Uint8List signature,
    SignatureAlgorithm? algorithm,
  });

  /// Delete a key pair.
  Future<void> deleteKey(String keyId);

  /// Check if a key exists.
  Future<bool> hasKey(String keyId);

  /// List all stored key IDs.
  Future<List<String>> listKeys();

  /// Check if hardware-backed key storage is available.
  Future<bool> isHardwareBackedAvailable();

  /// Get key metadata.
  Future<KeyMetadata?> getKeyMetadata(String keyId);
}

/// Supported key algorithms.
enum KeyAlgorithm {
  /// ECDSA with P-256 curve (secp256r1)
  ecdsaP256,

  /// ECDSA with P-384 curve (secp384r1)
  ecdsaP384,

  /// Ed25519 (EdDSA)
  ed25519,

  /// RSA 2048-bit
  rsa2048,

  /// RSA 4096-bit
  rsa4096,
}

/// Supported signature algorithms.
enum SignatureAlgorithm {
  /// ECDSA with SHA-256
  es256,

  /// ECDSA with SHA-384
  es384,

  /// Ed25519 signature
  eddsa,

  /// RSA PKCS#1 v1.5 with SHA-256
  rs256,

  /// RSA PSS with SHA-256
  ps256,
}

/// Metadata about a stored key.
class KeyMetadata {
  /// Key identifier
  final String keyId;

  /// Key algorithm
  final KeyAlgorithm algorithm;

  /// When the key was created
  final DateTime createdAt;

  /// Whether biometric authentication is required for signing
  final bool requiresBiometric;

  /// Whether the key is hardware-backed
  final bool isHardwareBacked;

  const KeyMetadata({
    required this.keyId,
    required this.algorithm,
    required this.createdAt,
    required this.requiresBiometric,
    required this.isHardwareBacked,
  });
}
