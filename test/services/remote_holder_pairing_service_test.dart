import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marty_authenticator/services/remote_holder_pairing_service.dart';

void main() {
  const code = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  const bearer = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

  Map<String, dynamic> response() => {
    'registration_id': 'registration-1',
    'device_id': 'device-1',
    'device_credential': bearer,
    'credential_expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'holder_binding_public_jwk': {
      'kty': 'OKP',
      'crv': 'Ed25519',
      'x': List.filled(43, 'C').join(),
      'kid': 'remote-binding-1',
    },
    'presentation_signing_public_jwk': {
      'kty': 'EC',
      'crv': 'P-256',
      'x': List.filled(43, 'D').join(),
      'y': List.filled(43, 'E').join(),
      'kid': 'remote-presentation-1',
    },
  };

  test('redeems one remote ticket and securely stores only the expected envelope', () async {
    String? stored;
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://wallet.example/v1/devices/pair');
      expect(request.followRedirects, isFalse);
      expect(jsonDecode(request.body), {'pairing_code': code, 'platform': 'android'});
      return http.Response(jsonEncode(response()), 200);
    });
    final service = RemoteHolderPairingService(
      client: client,
      storeEnrollment: (value) async => stored = value,
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
    expect(enrolled['api_origin'], 'https://wallet.example/');
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
}
