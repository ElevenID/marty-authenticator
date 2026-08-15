import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marty_authenticator/services/status_list_service.dart';

class _FixtureNativeAdapter implements StatusListNativeAdapter {
  final bool asserted;
  final bool fail;
  final String? decisionPurpose;

  const _FixtureNativeAdapter({
    required this.asserted,
    this.fail = false,
    this.decisionPurpose,
  });

  @override
  Future<List<NativeStatusEntry>> parseEntries(
    String credentialStatusJson,
  ) async {
    if (fail) throw StateError('native parser rejected input');
    final decoded = jsonDecode(credentialStatusJson);
    final entries = decoded is List ? decoded : [decoded];
    return entries
        .map((value) {
          final entry = Map<String, dynamic>.from(value as Map);
          return NativeStatusEntry(
            purpose: entry['statusPurpose'] as String,
            listUrl: entry['statusListCredential'] as String,
            entryJson: jsonEncode(entry),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<NativeStatusDecision> evaluate(
    String entryJson,
    String statusListCredentialJson,
  ) async {
    if (fail) throw StateError('native evaluator rejected input');
    final entry = jsonDecode(entryJson) as Map<String, dynamic>;
    return NativeStatusDecision(
      purpose: decisionPurpose ?? entry['statusPurpose'] as String,
      asserted: asserted,
    );
  }
}

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/status_list_behavior.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();

  for (final vector in vectors.where((vector) => vector['asserted'] is bool)) {
    test('Dart transport preserves ${vector['id']} native decision', () async {
      var requests = 0;
      final statusCredential = vector['status_list_credential'];
      final service = StatusListService(
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(jsonEncode(statusCredential), 200);
        }),
        native: _FixtureNativeAdapter(asserted: vector['asserted'] as bool),
      );
      addTearDown(service.dispose);

      final entry = Map<String, dynamic>.from(vector['entry'] as Map);
      final first = await service.checkCredentialStatus(entry);
      final second = await service.checkCredentialStatus(entry);

      expect(first.success, isTrue);
      expect(first.isRevoked, vector['asserted']);
      expect(second.isRevoked, vector['asserted']);
      expect(requests, 1, reason: 'status credential should be cached');
    });
  }

  test(
    'native rejection fails closed without a Python or Dart fallback',
    () async {
      final service = StatusListService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        native: const _FixtureNativeAdapter(asserted: false, fail: true),
      );
      addTearDown(service.dispose);

      final result = await service.checkCredentialStatus(
        Map<String, dynamic>.from(vectors.first['entry'] as Map),
      );

      expect(result.success, isFalse);
      expect(result.isRevoked, isNull);
      expect(result.error, contains('native parser rejected input'));
    },
  );

  test('object-or-array status input preserves both W3C purposes', () async {
    final service = StatusListService(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      native: const _FixtureNativeAdapter(asserted: true),
    );
    addTearDown(service.dispose);
    final revocation = Map<String, dynamic>.from(vectors.first['entry'] as Map);
    final suspension = Map<String, dynamic>.from(revocation)
      ..['id'] = 'https://issuer.example/status/suspension#5'
      ..['statusPurpose'] = 'suspension'
      ..['statusListCredential'] = 'https://issuer.example/status/suspension';

    final result = await service.checkCredentialStatus([
      revocation,
      suspension,
    ]);

    expect(result.success, isTrue);
    expect(result.isRevoked, isTrue);
    expect(result.isSuspended, isTrue);
  });

  test('credential without status remains a successful no-op', () async {
    final service = StatusListService(
      httpClient: MockClient((_) async => http.Response('{}', 500)),
      native: const _FixtureNativeAdapter(asserted: false, fail: true),
    );
    addTearDown(service.dispose);

    final result = await service.checkCredentialStatus(null);
    expect(result.success, isTrue);
    expect(result.isRevoked, isNull);
    expect(result.isSuspended, isNull);
  });

  test(
    'compatibility helpers preserve status semantics and cache control',
    () async {
      var requests = 0;
      final service = StatusListService(
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        native: const _FixtureNativeAdapter(asserted: true),
      );
      addTearDown(service.dispose);
      final entry = Map<String, dynamic>.from(vectors.first['entry'] as Map);

      expect(await service.checkRevocationStatus(entry), isTrue);
      expect(await service.checkSuspensionStatus(entry), isNull);
      expect(StatusCheckResult.success(isSuspended: true).isInvalid, isTrue);
      expect(StatusCheckResult.success(isRevoked: false).isInvalid, isFalse);
      expect(requests, 1);

      service.clearCache();
      expect(await service.checkRevocationStatus(entry), isTrue);
      expect(requests, 2);
    },
  );

  test('unsupported native purpose fails closed', () async {
    final service = StatusListService(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      native: const _FixtureNativeAdapter(
        asserted: false,
        decisionPurpose: 'message',
      ),
    );
    addTearDown(service.dispose);

    final result = await service.checkCredentialStatus(
      Map<String, dynamic>.from(vectors.first['entry'] as Map),
    );

    expect(result.success, isFalse);
    expect(result.error, contains('unsupported status purpose'));
  });

  test('status endpoint failures remain invalid native operations', () async {
    final service = StatusListService(
      httpClient: MockClient((_) async => http.Response('unavailable', 503)),
      native: const _FixtureNativeAdapter(asserted: false),
    );
    addTearDown(service.dispose);

    final result = await service.checkCredentialStatus(
      Map<String, dynamic>.from(vectors.first['entry'] as Map),
    );

    expect(result.success, isFalse);
    expect(result.error, contains('endpoint returned 503'));
  });
}
