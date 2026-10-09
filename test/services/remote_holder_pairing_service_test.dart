import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marty_authenticator/services/remote_holder_pairing_service.dart';

void main() {
  final code = base64UrlEncode(List<int>.filled(32, 10)).replaceAll('=', '');
  final bearer = base64UrlEncode(List<int>.filled(32, 11)).replaceAll('=', '');
  const pairingId = '11111111-2222-4333-8444-555555555555';

  Map<String, dynamic> response() => {
    'registration_id': 'registration-1',
    'pairing_id': pairingId,
    'device_id': 'device-1',
    'device_credential': bearer,
    'credential_expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'holder_binding_public_jwk': {
      'kty': 'OKP',
      'crv': 'Ed25519',
      'x': base64UrlEncode(List<int>.filled(32, 12)).replaceAll('=', ''),
      'kid': 'remote-binding-1',
    },
    'presentation_signing_public_jwk': {
      'kty': 'EC',
      'crv': 'P-256',
      'x': base64UrlEncode(List<int>.filled(32, 13)).replaceAll('=', ''),
      'y': base64UrlEncode(List<int>.filled(32, 14)).replaceAll('=', ''),
      'kid': 'remote-presentation-1',
    },
  };

  test('redeems one remote ticket and securely stores only the expected envelope', () async {
    String? stored;
    final client = MockClient((request) async {
      expect(request.followRedirects, isFalse);
      if (request.url.path == '/v1/devices/pair') {
        expect(jsonDecode(request.body), {'pairing_code': code, 'platform': 'android'});
        return http.Response(jsonEncode(response()), 200);
      }
      expect(request.url.toString(), 'https://wallet.example/v1/devices/pairing-ack');
      expect(request.headers['authorization'], 'Bearer $bearer');
      expect(jsonDecode(request.body), {'pairing_id': pairingId});
      expect(stored, isNotNull);
      return http.Response('{"confirmed":true}', 200);
    });
    final service = RemoteHolderPairingService(
      client: client,
      storeEnrollment: (value) async => stored = value,
      readEnrollment: () async => stored,
    );
    expect(
      await service.pair(
        apiOrigin: 'https://wallet.example/',
        pairingCode: code,
        platform: 'android',
      ),
      'device-1',
    );
    final enrolled = jsonDecode(stored!) as Map<String, dynamic>;
    expect(enrolled['device_credential'], bearer);
    expect(enrolled['pairing_id'], pairingId);
    expect(enrolled['api_origin'], 'https://wallet.example/');
    expect(enrolled['confirmed'], isTrue);
    expect(enrolled['holder_binding_public_jwk']['kid'], 'remote-binding-1');
    expect(enrolled.toString(), isNot(contains('private_key')));
    service.close();
  });

  test('rejects private key material in the remote response', () async {
    String? stored;
    final malicious = response();
    (malicious['holder_binding_public_jwk'] as Map<String, dynamic>)['d'] = 'private';
    final service = RemoteHolderPairingService(
      client: MockClient((_) async => http.Response(jsonEncode(malicious), 200)),
      storeEnrollment: (value) async => stored = value,
    );
    await expectLater(
      service.pair(
        apiOrigin: 'https://wallet.example/',
        pairingCode: code,
        platform: 'ios',
      ),
      throwsFormatException,
    );
    expect(stored, isNull);
    service.close();
  });

  test('does not follow a cross-origin pairing redirect', () async {
    String? stored;
    final service = RemoteHolderPairingService(
      client: MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          307,
          headers: {'location': 'https://other.example/v1/devices/pair'},
        );
      }),
      storeEnrollment: (value) async => stored = value,
    );
    await expectLater(
      service.pair(
        apiOrigin: 'https://wallet.example/',
        pairingCode: code,
        platform: 'android',
      ),
      throwsStateError,
    );
    expect(stored, isNull);
    service.close();
  });

  test('keeps stored bearer after a failed ack and retries only the ack', () async {
    String? stored;
    var acknowledgments = 0;
    final service = RemoteHolderPairingService(
      client: MockClient((request) async {
        if (request.url.path == '/v1/devices/pair') {
          return http.Response(jsonEncode(response()), 200);
        }
        acknowledgments += 1;
        return http.Response('{"confirmed":true}', acknowledgments == 1 ? 503 : 200);
      }),
      storeEnrollment: (value) async => stored = value,
      readEnrollment: () async => stored,
    );
    await expectLater(
      service.pair(
        apiOrigin: 'https://wallet.example/',
        pairingCode: code,
        platform: 'ios',
      ),
      throwsA(isA<RemotePairingConfirmationPending>()),
    );
    expect(jsonDecode(stored!)['device_credential'], bearer);
    expect(jsonDecode(stored!)['confirmed'], isFalse);
    expect(await service.confirmStored(), 'device-1');
    expect(jsonDecode(stored!)['confirmed'], isTrue);
    expect(acknowledgments, 2);
    service.close();
  });

  test('persists a pending replacement and retries rotation after a lost response', () async {
    final replacement = base64UrlEncode(List<int>.filled(32, 15)).replaceAll('=', '');
    String? stored = jsonEncode({
      ...response(),
      'api_origin': 'https://wallet.example/',
      'confirmed': true,
    });
    var attempts = 0;
    final service = RemoteHolderPairingService(
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://wallet.example/v1/devices/holder-credential-rotations');
        expect(request.followRedirects, isFalse);
        expect(request.headers['authorization'], 'Bearer $bearer');
        expect(jsonDecode(request.body), {'replacement_credential': replacement});
        expect(jsonDecode(stored!)['pending_credential'], replacement);
        attempts += 1;
        return http.Response(
          jsonEncode({
            'registration_id': 'registration-1',
            'credential_expires_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
          }),
          attempts == 1 ? 503 : 200,
        );
      }),
      storeEnrollment: (value) async => stored = value,
      readEnrollment: () async => stored,
      createReplacement: () => replacement,
    );
    await expectLater(service.renewIfDue(force: true), throwsStateError);
    expect(jsonDecode(stored!)['device_credential'], bearer);
    expect(await service.renewIfDue(), 'registration-1');
    expect(jsonDecode(stored!)['device_credential'], replacement);
    expect(jsonDecode(stored!).containsKey('pending_credential'), isFalse);
    expect(attempts, 2);
    service.close();
  });

  test('does not renew an enrollment awaiting pairing acknowledgment', () async {
    final stored = jsonEncode({
      ...response(),
      'api_origin': 'https://wallet.example/',
      'confirmed': false,
    });
    final service = RemoteHolderPairingService(
      client: MockClient((_) async => throw StateError('unexpected network call')),
      readEnrollment: () async => stored,
    );
    await expectLater(service.renewIfDue(), throwsFormatException);
    service.close();
  });

  test('coalesces simultaneous renewal attempts so only one bearer is installed', () async {
    final replacement = base64UrlEncode(List<int>.filled(32, 16)).replaceAll('=', '');
    String? stored = jsonEncode({...response(), 'api_origin': 'https://wallet.example/', 'confirmed': true});
    var calls = 0;
    final service = RemoteHolderPairingService(
      client: MockClient((_) async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(jsonEncode({
          'registration_id': 'registration-1',
          'credential_expires_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
        }), 200);
      }),
      storeEnrollment: (value) async => stored = value,
      readEnrollment: () async => stored,
      createReplacement: () => replacement,
    );
    final results = await Future.wait([
      service.renewIfDue(force: true),
      service.renewIfDue(force: true),
    ]);
    expect(results, ['registration-1', 'registration-1']);
    expect(calls, 1);
    expect(jsonDecode(stored!)['device_credential'], replacement);
    service.close();
  });
}
