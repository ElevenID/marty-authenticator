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
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Status purpose as defined in W3C Bitstring Status List v1.0
enum StatusPurpose { revocation, suspension }

/// Result of checking a credential's status
class StatusCheckResult {
  /// Whether the status was successfully checked
  final bool success;

  /// Whether the credential is revoked (null if not checked or no revocation entry)
  final bool? isRevoked;

  /// Whether the credential is suspended (null if not checked or no suspension entry)
  final bool? isSuspended;

  /// Error message if the check failed
  final String? error;

  /// Timestamp of when this status was checked
  final DateTime checkedAt;

  const StatusCheckResult({
    required this.success,
    this.isRevoked,
    this.isSuspended,
    this.error,
    required this.checkedAt,
  });

  /// Returns true if the credential status indicates it should not be used
  bool get isInvalid => (isRevoked ?? false) || (isSuspended ?? false);

  factory StatusCheckResult.success({bool? isRevoked, bool? isSuspended}) =>
      StatusCheckResult(
        success: true,
        isRevoked: isRevoked,
        isSuspended: isSuspended,
        checkedAt: DateTime.now(),
      );

  factory StatusCheckResult.failure(String error) => StatusCheckResult(
    success: false,
    error: error,
    checkedAt: DateTime.now(),
  );

  factory StatusCheckResult.noStatusEntry() => StatusCheckResult(
    success: true,
    isRevoked: null,
    isSuspended: null,
    checkedAt: DateTime.now(),
  );
}

/// Parsed BitstringStatusListEntry from a credential
class BitstringStatusListEntry {
  final String id;
  final String type;
  final String statusPurpose;
  final int statusListIndex;
  final String statusListCredential;

  const BitstringStatusListEntry({
    required this.id,
    required this.type,
    required this.statusPurpose,
    required this.statusListIndex,
    required this.statusListCredential,
  });

  factory BitstringStatusListEntry.fromJson(Map<String, dynamic> json) {
    return BitstringStatusListEntry(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'BitstringStatusListEntry',
      statusPurpose: json['statusPurpose'] as String? ?? 'revocation',
      statusListIndex: int.tryParse(json['statusListIndex'].toString()) ?? 0,
      statusListCredential: json['statusListCredential'] as String? ?? '',
    );
  }

  StatusPurpose get purpose => statusPurpose == 'suspension'
      ? StatusPurpose.suspension
      : StatusPurpose.revocation;
}

/// Service for checking credential status via Bitstring Status List
///
/// Implements W3C Bitstring Status List v1.0 verification:
/// 1. Parse credentialStatus from the credential
/// 2. Fetch the status list credential from the URL
/// 3. Decode the GZIP+Base64 encoded bitstring
/// 4. Check the bit at the specified index
class StatusListService {
  final http.Client _httpClient;

  /// Cache of fetched status lists (URL -> encoded list + expiry)
  final Map<String, _CachedStatusList> _cache = {};

  /// Cache duration (matches default server TTL)
  static const Duration cacheDuration = Duration(minutes: 5);

  StatusListService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Check the status of a credential
  ///
  /// Parses the credentialStatus field, fetches the status list(s),
  /// and checks the bits at the specified indices.
  Future<StatusCheckResult> checkCredentialStatus(
    Map<String, dynamic>? credentialStatus,
  ) async {
    if (credentialStatus == null) {
      return StatusCheckResult.noStatusEntry();
    }

    try {
      // Parse credential status entries
      final entries = _parseCredentialStatus(credentialStatus);

      if (entries.isEmpty) {
        return StatusCheckResult.noStatusEntry();
      }

      bool? isRevoked;
      bool? isSuspended;

      for (final entry in entries) {
        final status = await _checkStatusEntry(entry);

        if (entry.purpose == StatusPurpose.revocation) {
          isRevoked = status;
        } else if (entry.purpose == StatusPurpose.suspension) {
          isSuspended = status;
        }
      }

      return StatusCheckResult.success(
        isRevoked: isRevoked,
        isSuspended: isSuspended,
      );
    } catch (e) {
      return StatusCheckResult.failure('Failed to check status: $e');
    }
  }

  /// Check revocation status only
  Future<bool?> checkRevocationStatus(
    Map<String, dynamic>? credentialStatus,
  ) async {
    final result = await checkCredentialStatus(credentialStatus);
    return result.isRevoked;
  }

  /// Check suspension status only
  Future<bool?> checkSuspensionStatus(
    Map<String, dynamic>? credentialStatus,
  ) async {
    final result = await checkCredentialStatus(credentialStatus);
    return result.isSuspended;
  }

  /// Parse credentialStatus field (can be object or array)
  List<BitstringStatusListEntry> _parseCredentialStatus(
    Map<String, dynamic> credentialStatus,
  ) {
    // Check if it's an array or single object
    if (credentialStatus.containsKey('type') &&
        credentialStatus['type'] == 'BitstringStatusListEntry') {
      // Single entry
      return [BitstringStatusListEntry.fromJson(credentialStatus)];
    }

    // Check for array format
    final entries = <BitstringStatusListEntry>[];

    // Handle array case (credentialStatus could be a list in the JSON)
    // In our model it's Map, but the JSON might have an array
    // This handles the case where it's wrapped differently

    return entries.isEmpty
        ? [BitstringStatusListEntry.fromJson(credentialStatus)]
        : entries;
  }

  /// Check a single status entry
  Future<bool> _checkStatusEntry(BitstringStatusListEntry entry) async {
    // Get the status list (from cache or fetch)
    final encodedList = await _getStatusList(entry.statusListCredential);

    if (encodedList == null) {
      throw Exception('Failed to fetch status list');
    }

    // Decode and check the bit
    return _checkBitInStatusList(encodedList, entry.statusListIndex);
  }

  /// Get status list from cache or fetch from URL
  Future<String?> _getStatusList(String url) async {
    // Check cache
    final cached = _cache[url];
    if (cached != null && !cached.isExpired) {
      return cached.encodedList;
    }

    // Fetch from URL
    try {
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {'Accept': 'application/vc+ld+json, application/json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract encoded list from the status list credential
      final credentialSubject =
          json['credentialSubject'] as Map<String, dynamic>?;
      final encodedList = credentialSubject?['encodedList'] as String?;

      if (encodedList == null) {
        return null;
      }

      // Cache the result
      _cache[url] = _CachedStatusList(
        encodedList: encodedList,
        expiresAt: DateTime.now().add(cacheDuration),
      );

      return encodedList;
    } catch (e) {
      return null;
    }
  }

  /// Check a specific bit in the status list
  ///
  /// The encodedList is GZIP compressed and Base64 encoded.
  /// Bits are stored in MSB (most significant bit) order per W3C spec.
  bool _checkBitInStatusList(String encodedList, int index) {
    // Decode Base64
    final compressed = base64Decode(encodedList);

    // Decompress GZIP
    final decompressed = gzip.decode(compressed);

    // Calculate byte and bit position (MSB ordering per spec)
    final byteIndex = index ~/ 8;
    final bitIndex = 7 - (index % 8); // MSB ordering

    if (byteIndex >= decompressed.length) {
      throw Exception('Index out of range for status list');
    }

    // Check the bit
    return (decompressed[byteIndex] >> bitIndex) & 1 == 1;
  }

  /// Clear the status list cache
  void clearCache() {
    _cache.clear();
  }

  /// Dispose of resources
  void dispose() {
    _cache.clear();
    _httpClient.close();
  }
}

/// Cached status list entry
class _CachedStatusList {
  final String encodedList;
  final DateTime expiresAt;

  _CachedStatusList({required this.encodedList, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Provider for the status list service
final statusListServiceProvider = Provider<StatusListService>((ref) {
  final service = StatusListService();
  ref.onDispose(service.dispose);
  return service;
});
