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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/logger.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A serialisable record of a received verifiable credential.
///
/// Holds credential receipts returned by the verified Rust OID4VCI flow.
class StoredCredential {
  final String id;
  final String format; // verified OID4VCI format
  final String issuer; // credential_issuer URL
  final List<String> types;
  final String rawJson; // verified credential payload
  final DateTime issuedAt;

  const StoredCredential({
    required this.id,
    required this.format,
    required this.issuer,
    required this.types,
    required this.rawJson,
    required this.issuedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'format': format,
    'issuer': issuer,
    'types': types,
    'rawJson': rawJson,
    'issuedAt': issuedAt.toIso8601String(),
  };

  factory StoredCredential.fromJson(Map<String, dynamic> json) =>
      StoredCredential(
        id: json['id'] as String,
        format: json['format'] as String,
        issuer: json['issuer'] as String,
        types: (json['types'] as List<dynamic>).cast<String>(),
        rawJson: json['rawJson'] as String,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

/// Persists received OID4VCI credentials to [FlutterSecureStorage].
///
/// Each verified receipt has one secure-storage entry. Enumeration derives
/// from those entries, so a second index write cannot lose a receipt.
///
/// This is the wallet's source of verified credential receipts. It never
/// stores holder private keys or unverified platform-channel imports.
class WalletCredentialStore {
  WalletCredentialStore._();

  static const _prefix = 'marty:wallet:receipt:';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // -------------------------------------------------------------------------
  // Write
  // -------------------------------------------------------------------------

  /// Persist [credential] to secure storage, overwriting any existing entry
  /// with the same [StoredCredential.id].
  static Future<void> store(StoredCredential credential) async {
    await _storage.write(
      key: '$_prefix${credential.id}',
      value: jsonEncode(credential.toJson()),
    );

    Logger.info(
      'Stored credential id=${credential.id} format=${credential.format}',
    );
  }

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  /// Returns all stored credentials, ignoring any with parse errors.
  static Future<List<StoredCredential>> getAll() async {
    final results = <StoredCredential>[];
    for (final entry in (await _storage.readAll()).entries) {
      if (!entry.key.startsWith(_prefix)) continue;
      final id = entry.key.substring(_prefix.length);
      try {
        final credential = StoredCredential.fromJson(
          jsonDecode(entry.value) as Map<String, dynamic>,
        );
        if (credential.id != id) {
          throw const FormatException('Receipt ID does not match storage key');
        }
        results.add(credential);
      } catch (e) {
        Logger.warning(
          'WalletCredentialStore: failed to parse credential $id: $e',
        );
      }
    }
    results.sort((a, b) {
      final byDate = a.issuedAt.compareTo(b.issuedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return results;
  }

  /// Returns a single credential by ID, or null if not found.
  static Future<StoredCredential?> getById(String id) async {
    final raw = await _storage.read(key: '$_prefix$id');
    if (raw == null) return null;
    try {
      final credential = StoredCredential.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (credential.id != id) {
        throw const FormatException('Receipt ID does not match storage key');
      }
      return credential;
    } catch (e) {
      Logger.warning('WalletCredentialStore: parse error for $id: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------------------

  /// Delete a single credential.
  static Future<void> delete(String id) async {
    await _storage.delete(key: '$_prefix$id');
  }

  /// Delete all stored credentials.
  static Future<void> clear() async {
    for (final key in (await _storage.readAll()).keys.toList()) {
      if (key.startsWith(_prefix)) {
        await _storage.delete(key: key);
      }
    }
  }
}
