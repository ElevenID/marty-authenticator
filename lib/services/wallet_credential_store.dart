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
/// Credentials received via OID4VCI are stored here before being
/// promoted to the richer [MDocCredential] / [VerifiableCredential]
/// model when the UI reads them.
class StoredCredential {
  final String id;
  final String format; // e.g. "mso_mdoc", "vc+sd-jwt", "ldp_vc"
  final String issuer; // credential_issuer URL
  final List<String> types;
  final String rawJson; // full credential response body (JSON)
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
/// Credentials are keyed as `cred:{id}` with a JSON index stored at
/// `cred:index` (a JSON array of IDs).
///
/// This store acts as a staging area — the main credential repository
/// reads from here and constructs typed domain objects.
class WalletCredentialStore {
  WalletCredentialStore._();

  static const _indexKey = 'marty:cred:index';
  static const _prefix = 'marty:cred:';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // -------------------------------------------------------------------------
  // Write
  // -------------------------------------------------------------------------

  /// Persist [credential] to secure storage, overwriting any existing entry
  /// with the same [StoredCredential.id].
  static Future<void> store(StoredCredential credential) async {
    // Write credential body
    await _storage.write(
      key: '$_prefix${credential.id}',
      value: jsonEncode(credential.toJson()),
    );

    // Update index
    final index = await _readIndex();
    if (!index.contains(credential.id)) {
      index.add(credential.id);
      await _writeIndex(index);
    }

    Logger.info(
      'Stored credential id=${credential.id} format=${credential.format}',
    );
  }

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  /// Returns all stored credentials, ignoring any with parse errors.
  static Future<List<StoredCredential>> getAll() async {
    final index = await _readIndex();
    final results = <StoredCredential>[];

    for (final id in index) {
      final raw = await _storage.read(key: '$_prefix$id');
      if (raw == null) continue;
      try {
        results.add(
          StoredCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (e) {
        Logger.warning(
          'WalletCredentialStore: failed to parse credential $id: $e',
        );
      }
    }

    return results;
  }

  /// Returns a single credential by ID, or null if not found.
  static Future<StoredCredential?> getById(String id) async {
    final raw = await _storage.read(key: '$_prefix$id');
    if (raw == null) return null;
    try {
      return StoredCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    final index = await _readIndex();
    index.remove(id);
    await _writeIndex(index);
  }

  /// Delete all stored credentials.
  static Future<void> clear() async {
    final index = await _readIndex();
    for (final id in index) {
      await _storage.delete(key: '$_prefix$id');
    }
    await _storage.delete(key: _indexKey);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static Future<List<String>> _readIndex() async {
    final raw = await _storage.read(key: _indexKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeIndex(List<String> index) =>
      _storage.write(key: _indexKey, value: jsonEncode(index));
}
