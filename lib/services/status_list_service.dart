/*
 * privacyIDEA Authenticator
 *
 * Copyright (c) 2025 NetKnights GmbH
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

/// Bounded HTTPS transport for untrusted status-list bytes. Rust owns protocol
/// validation and authority decisions; cache hits are evaluated again by Rust.
/// The current raw native API returns STATUS_AUTHORITY_UNAVAILABLE until a
/// governed native status-authority resolver is available.
class StatusListService {
  final http.Client _httpClient;
  final StatusListNativeAdapter _native;
  final DateTime Function() _now;
  final Map<String, _CachedStatusList> _cache = {};

  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration requestTimeout = Duration(seconds: 15);
  static const int maxStatusListBytes = 2 * 1024 * 1024;
  static const int maxCachedStatusLists = 32;

  StatusListService({
    http.Client? httpClient,
    this._native = const RustStatusListNativeAdapter(),
    DateTime Function()? now,
  }) : _httpClient = httpClient ?? http.Client(),
       _now = now ?? DateTime.now;

  Future<StatusCheckResult> checkCredentialStatus(
    Object? credentialStatus,
  ) async {
    if (credentialStatus == null) {
      return StatusCheckResult.noStatusEntry();
    }

    try {
      final entries = await _native.parseEntries(jsonEncode(credentialStatus));
      if (entries.isEmpty) {
        throw StateError('Rust returned no status entries');
      }
      bool? isRevoked;
      bool? isSuspended;

      for (final entry in entries) {
        final credentialJson = await _getStatusListCredential(entry.listUrl);
        final decision = await _native.evaluate(
          entry.entryJson,
          credentialJson,
        );
        if (decision.purpose != entry.purpose) {
          throw StateError('Rust returned a mismatched status purpose');
        }
        if (decision.purpose == 'revocation') {
          isRevoked = (isRevoked ?? false) || decision.asserted;
        } else if (decision.purpose == 'suspension') {
          isSuspended = (isSuspended ?? false) || decision.asserted;
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
    if (cached != null && cached.isUsableAt(_now())) {
      return cached.credentialJson;
    }

    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('Status-list transport requires HTTPS');
    }
    final abort = Completer<void>();
    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers['Accept'] = 'application/vc+ld+json, application/json';
    final response = await _httpClient
        .send(request)
        .timeout(
          requestTimeout,
          onTimeout: () {
            abort.complete();
            throw TimeoutException(
              'Status-list response headers timed out',
              requestTimeout,
            );
          },
        );
    if (response.statusCode != 200) {
      await response.stream.listen(null).cancel();
      throw StateError('Status-list endpoint returned ${response.statusCode}');
    }
    if ((response.contentLength ?? 0) > maxStatusListBytes) {
      await response.stream.listen(null).cancel();
      throw const FormatException(
        'Status-list response exceeds the byte limit',
      );
    }
    final bytes = BytesBuilder(copy: false);
    final chunks = StreamIterator(response.stream);
    try {
      await (() async {
        while (await chunks.moveNext()) {
          final chunk = chunks.current;
          if (bytes.length + chunk.length > maxStatusListBytes) {
            throw const FormatException(
              'Status-list response exceeds the byte limit',
            );
          }
          bytes.add(chunk);
        }
      })().timeout(requestTimeout);
    } finally {
      // The absolute body deadline also stops slow trickles. Cancel the source
      // on timeout or overflow instead of leaving it running in the background.
      await chunks.cancel();
      abort.complete();
    }
    // Preserve the fetched bytes; JSON and proof handling belong to Rust.
    final credentialJson = utf8.decode(bytes.takeBytes());
    final fetchedAt = _now();
    if (!_cache.containsKey(url) && _cache.length >= maxCachedStatusLists) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = _CachedStatusList(
      credentialJson: credentialJson,
      fetchedAt: fetchedAt,
      expiresAt: fetchedAt.add(cacheDuration),
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
  final DateTime fetchedAt;
  final DateTime expiresAt;

  _CachedStatusList({
    required this.credentialJson,
    required this.fetchedAt,
    required this.expiresAt,
  });

  bool isUsableAt(DateTime now) =>
      !now.isBefore(fetchedAt) && now.isBefore(expiresAt);
}

final statusListServiceProvider = Provider<StatusListService>((ref) {
  final service = StatusListService();
  ref.onDispose(service.dispose);
  return service;
});
