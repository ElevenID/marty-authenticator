import 'dart:async';
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
  final String? evaluationError;
  final Map<String, bool>? assertedByUrl;
  final void Function(String)? onEvaluate;

  const _FixtureNativeAdapter({
    required this.asserted,
    this.fail = false,
    this.decisionPurpose,
    this.evaluationError,
    this.assertedByUrl,
    this.onEvaluate,
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
    onEvaluate?.call(statusListCredentialJson);
    if (fail) throw StateError('native evaluator rejected input');
    if (evaluationError != null) throw StateError(evaluationError!);
    final entry = jsonDecode(entryJson) as Map<String, dynamic>;
    return NativeStatusDecision(
      purpose: decisionPurpose ?? entry['statusPurpose'] as String,
      asserted: assertedByUrl?[entry['statusListCredential']] ?? asserted,
    );
  }
}

class _ChunkedStatusClient extends http.BaseClient {
  final Stream<List<int>> stream;

  _ChunkedStatusClient(List<List<int>> chunks)
    : stream = Stream.fromIterable(chunks);

  _ChunkedStatusClient.stream(this.stream);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(stream, 200);
}

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/status_list_behavior.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();

  // These are transport projections of an injected native decision, not proof
  // verification fixtures. Production rejects every raw vector below.
  for (final vector in vectors.where(
    (vector) => vector['unverified_decoded_bit'] is bool,
  )) {
    test('Dart transport projects mocked ${vector['id']} decision', () async {
      var requests = 0;
      var evaluations = 0;
      final statusCredential = vector['status_list_credential'];
      final service = StatusListService(
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(jsonEncode(statusCredential), 200);
        }),
        native: _FixtureNativeAdapter(
          asserted: vector['unverified_decoded_bit'] as bool,
          onEvaluate: (_) => evaluations++,
        ),
      );
      addTearDown(service.dispose);

      final entry = Map<String, dynamic>.from(vector['entry'] as Map);
      final first = await service.checkCredentialStatus(entry);
      final second = await service.checkCredentialStatus(entry);

      expect(first.success, isTrue);
      expect(first.isRevoked, vector['unverified_decoded_bit']);
      expect(second.isRevoked, vector['unverified_decoded_bit']);
      expect(requests, 1, reason: 'status credential should be cached');
      expect(evaluations, 2, reason: 'raw cache hits must be evaluated again');
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

  test('mismatched native purpose fails closed', () async {
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
    expect(result.error, contains('mismatched status purpose'));
  });

  test('authority-unavailable responses never become clear status', () async {
    for (final vector in vectors) {
      final service = StatusListService(
        httpClient: MockClient(
          (_) async =>
              http.Response(jsonEncode(vector['status_list_credential']), 200),
        ),
        native: _FixtureNativeAdapter(
          asserted: false,
          evaluationError: vector['native_error'] as String,
        ),
      );
      final result = await service.checkCredentialStatus(vector['entry']);
      expect(result.success, isFalse);
      expect(result.isRevoked, isNull);
      expect(result.isSuspended, isNull);
      expect(result.error, contains('STATUS_AUTHORITY_UNAVAILABLE'));
      service.dispose();
    }
  });

  test('a later clear entry cannot overwrite an asserted status', () async {
    final asserted = Map<String, dynamic>.from(vectors.first['entry'] as Map);
    final clear = Map<String, dynamic>.from(asserted)
      ..['statusListCredential'] = 'https://issuer.example/status/clear';
    final service = StatusListService(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      native: _FixtureNativeAdapter(
        asserted: false,
        assertedByUrl: {asserted['statusListCredential'] as String: true},
      ),
    );
    addTearDown(service.dispose);
    final result = await service.checkCredentialStatus([asserted, clear]);
    expect(result.success, isTrue);
    expect(result.isRevoked, isTrue);
  });

  test('transport requires HTTPS and does not follow redirects', () async {
    var requests = 0;
    final service = StatusListService(
      httpClient: MockClient((request) async {
        requests++;
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {'location': 'http://issuer.example/status/1'},
        );
      }),
      native: const _FixtureNativeAdapter(asserted: false),
    );
    addTearDown(service.dispose);
    final entry = Map<String, dynamic>.from(vectors.first['entry'] as Map);
    final redirect = await service.checkCredentialStatus(entry);
    expect(redirect.success, isFalse);
    expect(redirect.error, contains('endpoint returned 302'));
    entry['statusListCredential'] = 'http://issuer.example/status/1';
    final insecure = await service.checkCredentialStatus(entry);
    expect(insecure.success, isFalse);
    expect(insecure.error, contains('requires HTTPS'));
    expect(requests, 1);
  });

  test('oversized status responses fail before native evaluation', () async {
    var evaluated = false;
    final service = StatusListService(
      httpClient: MockClient(
        (_) async => http.Response(
          'x' * (StatusListService.maxStatusListBytes + 1),
          200,
        ),
      ),
      native: _FixtureNativeAdapter(
        asserted: false,
        onEvaluate: (_) => evaluated = true,
      ),
    );
    addTearDown(service.dispose);
    final result = await service.checkCredentialStatus(vectors.first['entry']);
    expect(result.success, isFalse);
    expect(result.error, contains('exceeds the byte limit'));
    expect(evaluated, isFalse);
  });

  test(
    'chunked responses are bounded without a Content-Length header',
    () async {
      var evaluated = false;
      final service = StatusListService(
        httpClient: _ChunkedStatusClient([
          List.filled(StatusListService.maxStatusListBytes, 32),
          [32],
        ]),
        native: _FixtureNativeAdapter(
          asserted: false,
          onEvaluate: (_) => evaluated = true,
        ),
      );
      addTearDown(service.dispose);
      final result = await service.checkCredentialStatus(
        vectors.first['entry'],
      );
      expect(result.success, isFalse);
      expect(result.error, contains('exceeds the byte limit'));
      expect(evaluated, isFalse);
    },
  );

  testWidgets('header deadline aborts the in-flight request', (tester) async {
    var aborted = false;
    var evaluated = false;
    final service = StatusListService(
      httpClient: MockClient.streaming((request, _) async {
        await (request as http.Abortable).abortTrigger;
        aborted = true;
        throw http.RequestAbortedException(request.url);
      }),
      native: _FixtureNativeAdapter(
        asserted: false,
        onEvaluate: (_) => evaluated = true,
      ),
    );
    addTearDown(service.dispose);
    StatusCheckResult? result;
    unawaited(
      service.checkCredentialStatus(vectors.first['entry']).then((value) {
        result = value;
      }),
    );
    await tester.pump();
    await tester.pump(StatusListService.requestTimeout);
    expect(result, isNotNull);
    expect(result!.success, isFalse);
    expect(result!.error, contains('TimeoutException'));
    expect(aborted, isTrue);
    expect(evaluated, isFalse);
  });

  testWidgets('slow trickles reach the absolute body deadline', (tester) async {
    var cancelled = false;
    var evaluated = false;
    final body = StreamController<List<int>>(
      onCancel: () async {
        cancelled = true;
      },
    );
    final service = StatusListService(
      httpClient: _ChunkedStatusClient.stream(body.stream),
      native: _FixtureNativeAdapter(
        asserted: false,
        onEvaluate: (_) => evaluated = true,
      ),
    );
    addTearDown(service.dispose);
    addTearDown(body.close);
    StatusCheckResult? result;
    unawaited(
      service.checkCredentialStatus(vectors.first['entry']).then((value) {
        result = value;
      }),
    );
    await tester.pump();
    for (var chunk = 0; chunk < 3; chunk++) {
      body.add([32]);
      await tester.pump(const Duration(seconds: 5));
    }
    await tester.pump();
    expect(result, isNotNull);
    expect(result!.success, isFalse);
    expect(result!.error, contains('TimeoutException'));
    expect(cancelled, isTrue);
    expect(evaluated, isFalse);
  });

  test('transport forwards raw list text without interpreting it', () async {
    const raw = '{ "proof": {"anything": true}, "extra": 1 }';
    String? received;
    final service = StatusListService(
      httpClient: MockClient((_) async => http.Response(raw, 200)),
      native: _FixtureNativeAdapter(
        asserted: false,
        evaluationError: 'STATUS_AUTHORITY_UNAVAILABLE',
        onEvaluate: (value) => received = value,
      ),
    );
    addTearDown(service.dispose);
    final result = await service.checkCredentialStatus(vectors.first['entry']);
    expect(received, raw);
    expect(result.success, isFalse);
    expect(result.isRevoked, isNull);
  });

  test(
    'raw response cache expires at its deadline and on clock rollback',
    () async {
      var now = DateTime.utc(2026, 11, 8);
      var requests = 0;
      final service = StatusListService(
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        native: const _FixtureNativeAdapter(asserted: false),
        now: () => now,
      );
      addTearDown(service.dispose);
      final entry = vectors.first['entry'];
      await service.checkCredentialStatus(entry);
      await service.checkCredentialStatus(entry);
      expect(requests, 1);
      now = now.add(StatusListService.cacheDuration);
      await service.checkCredentialStatus(entry);
      expect(requests, 2);
      now = now.subtract(const Duration(minutes: 1));
      await service.checkCredentialStatus(entry);
      expect(requests, 3);
    },
  );

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
