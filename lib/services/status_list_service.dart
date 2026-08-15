/*
 * privacyIDEA Authenticator
 *
 * Copyright (c) 2025 NetKnights GmbH
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../rust/marty_bridge.dart/status.dart' as rust_status;

/// Result of checking a credential's W3C Bitstring Status List entries.
class StatusCheckResult {
  final bool success;
  final bool? isRevoked;
  final bool? isSuspended;
  final String? error;
  final DateTime checkedAt;

  const StatusCheckResult({
    required this.success,
    this.isRevoked,
    this.isSuspended,
    this.error,
    required this.checkedAt,
  });

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

/// Transport-neutral status entry returned by the Rust parser.
class NativeStatusEntry {
  final String purpose;
  final String listUrl;
  final String entryJson;

  const NativeStatusEntry({
    required this.purpose,
    required this.listUrl,
    required this.entryJson,
  });
}

/// Transport-neutral result returned by the Rust status evaluator.
class NativeStatusDecision {
  final String purpose;
  final bool asserted;

  const NativeStatusDecision({required this.purpose, required this.asserted});
}

/// Injectable boundary used by Dart tests; production always delegates to Rust.
abstract interface class StatusListNativeAdapter {
  Future<List<NativeStatusEntry>> parseEntries(String credentialStatusJson);

  Future<NativeStatusDecision> evaluate(
    String entryJson,
    String statusListCredentialJson,
  );
}

class RustStatusListNativeAdapter implements StatusListNativeAdapter {
  const RustStatusListNativeAdapter();

  @override
  Future<List<NativeStatusEntry>> parseEntries(
    String credentialStatusJson,
  ) async {
    final entries = await rust_status.parseStatusEntries(
      credentialStatusJson: credentialStatusJson,
    );
    return entries
        .map(
          (entry) => NativeStatusEntry(
            purpose: entry.purpose,
            listUrl: entry.listUrl,
            entryJson: entry.entryJson,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<NativeStatusDecision> evaluate(
    String entryJson,
    String statusListCredentialJson,
  ) async {
    final decision = await rust_status.evaluateBitstringStatus(
      entryJson: entryJson,
      statusListCredentialJson: statusListCredentialJson,
    );
    return NativeStatusDecision(
      purpose: decision.purpose,
      asserted: decision.asserted,
    );
  }
}

/// Fetches and caches status-list credentials while Rust owns all protocol
/// parsing, bounded decoding, validation, and status decisions.
class StatusListService {
  final http.Client _httpClient;
  final StatusListNativeAdapter _native;
  final Map<String, _CachedStatusList> _cache = {};

  static const Duration cacheDuration = Duration(minutes: 5);

  StatusListService({
    http.Client? httpClient,
    this._native = const RustStatusListNativeAdapter(),
  }) : _httpClient = httpClient ?? http.Client();

  Future<StatusCheckResult> checkCredentialStatus(
    Object? credentialStatus,
  ) async {
    if (credentialStatus == null) {
      return StatusCheckResult.noStatusEntry();
    }

    try {
      final entries = await _native.parseEntries(jsonEncode(credentialStatus));
      bool? isRevoked;
      bool? isSuspended;

      for (final entry in entries) {
        final credentialJson = await _getStatusListCredential(entry.listUrl);
        final decision = await _native.evaluate(
          entry.entryJson,
          credentialJson,
        );
        if (decision.purpose == 'revocation') {
          isRevoked = decision.asserted;
        } else if (decision.purpose == 'suspension') {
          isSuspended = decision.asserted;
        } else {
          throw StateError('Rust returned an unsupported status purpose');
        }
      }

      return StatusCheckResult.success(
        isRevoked: isRevoked,
        isSuspended: isSuspended,
      );
    } catch (error) {
      return StatusCheckResult.failure('Failed to check status: $error');
    }
  }

  Future<bool?> checkRevocationStatus(Object? credentialStatus) async =>
      (await checkCredentialStatus(credentialStatus)).isRevoked;

  Future<bool?> checkSuspensionStatus(Object? credentialStatus) async =>
      (await checkCredentialStatus(credentialStatus)).isSuspended;

  Future<String> _getStatusListCredential(String url) async {
    final cached = _cache[url];
    if (cached != null && !cached.isExpired) {
      return cached.credentialJson;
    }

    final response = await _httpClient.get(
      Uri.parse(url),
      headers: {'Accept': 'application/vc+ld+json, application/json'},
    );
    if (response.statusCode != 200) {
      throw StateError('Status-list endpoint returned ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Status-list credential must be a JSON object',
      );
    }
    final credentialJson = jsonEncode(decoded);
    _cache[url] = _CachedStatusList(
      credentialJson: credentialJson,
      expiresAt: DateTime.now().add(cacheDuration),
    );
    return credentialJson;
  }

  void clearCache() => _cache.clear();

  void dispose() {
    _cache.clear();
    _httpClient.close();
  }
}

class _CachedStatusList {
  final String credentialJson;
  final DateTime expiresAt;

  _CachedStatusList({required this.credentialJson, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

final statusListServiceProvider = Provider<StatusListService>((ref) {
  final service = StatusListService();
  ref.onDispose(service.dispose);
  return service;
});
