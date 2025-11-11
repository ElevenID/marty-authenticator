import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:privacyidea_authenticator/services/spruce_backend_service.dart';

// Create a simple mock instead of using generated mocks for now
class MockClient extends Mock implements http.Client {}

void main() {
  group('SpruceId Backend Integration Tests', () {
    late SpruceIdBackendService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = SpruceIdBackendService(
        baseUrl: 'http://localhost:5000',
        client: mockClient,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('Health Check', () {
      test('should return healthy status', () async {
        // Arrange
        final responseBody = json.encode({
          'status': 'healthy',
          'service': 'SpruceID Backend API',
          'spruceid_available': true,
        });

        when(
          mockClient.get(
            Uri.parse('http://localhost:5000/health'),
            headers: {'Content-Type': 'application/json'},
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.healthCheck();

        // Assert
        expect(result['status'], equals('healthy'));
        expect(result['service'], equals('SpruceID Backend API'));
        expect(result['spruceid_available'], isTrue);
      });

      test('should throw exception on health check failure', () async {
        // Arrange
        when(
          mockClient.get(
            Uri.parse('http://localhost:5000/health'),
            headers: {'Content-Type': 'application/json'},
          ),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        // Act & Assert
        expect(
          () async => await service.healthCheck(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('DID Operations', () {
      test('should create DID with key method', () async {
        // Arrange
        final responseBody = json.encode({
          'did': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
          'keyJwk': {'kty': 'OKP', 'crv': 'Ed25519', 'x': 'test-key-data'},
          'verificationMethod':
              'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
          'created': '2024-01-01T00:00:00Z',
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/did/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'method': 'key'}),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.createDid(method: 'key');

        // Assert
        expect(result['did'], startsWith('did:key:'));
        expect(result['status'], equals('success'));
        expect(result['keyJwk'], isNotNull);
      });

      test('should create DID with web method', () async {
        // Arrange
        final responseBody = json.encode({
          'did': 'did:web:example.com',
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/did/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'method': 'web',
              'options': {'domain': 'example.com'},
            }),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.createDid(
          method: 'web',
          options: {'domain': 'example.com'},
        );

        // Assert
        expect(result['did'], equals('did:web:example.com'));
        expect(result['status'], equals('success'));
      });
    });

    group('Credential Operations', () {
      test('should sign verifiable credential', () async {
        // Arrange
        final credential = {
          '@context': ['https://www.w3.org/2018/credentials/v1'],
          'type': ['VerifiableCredential'],
          'issuer': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
          'credentialSubject': {
            'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
            'name': 'Test User',
          },
        };

        final keyJwk = {
          'kty': 'OKP',
          'crv': 'Ed25519',
          'x': 'test-key-data',
          'd': 'test-private-key-data',
        };

        final responseBody = json.encode({
          'credential': {
            ...credential,
            'proof': {
              'type': 'Ed25519Signature2018',
              'created': '2024-01-01T00:00:00Z',
              'proofPurpose': 'assertionMethod',
              'verificationMethod':
                  'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
              'proofValue': 'z1234567890abcdef',
            },
          },
          'signed': true,
          'signedAt': '2024-01-01T00:00:00Z',
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/credential/sign'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'credential': credential,
              'keyJwk': keyJwk,
              'verificationMethod':
                  'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
            }),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.signCredential(
          credential: credential,
          keyJwk: keyJwk,
          verificationMethod:
              'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        );

        // Assert
        expect(result['signed'], isTrue);
        expect(result['status'], equals('success'));
        expect(result['credential']['proof'], isNotNull);
      });

      test('should verify verifiable credential', () async {
        // Arrange
        final credential = {
          '@context': ['https://www.w3.org/2018/credentials/v1'],
          'type': ['VerifiableCredential'],
          'issuer': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
          'credentialSubject': {
            'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
            'name': 'Test User',
          },
          'proof': {
            'type': 'Ed25519Signature2018',
            'created': '2024-01-01T00:00:00Z',
            'proofPurpose': 'assertionMethod',
            'verificationMethod':
                'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
            'proofValue': 'z1234567890abcdef',
          },
        };

        final responseBody = json.encode({
          'valid': true,
          'errors': [],
          'verifiedAt': '2024-01-01T00:00:00Z',
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/credential/verify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'credential': credential}),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.verifyCredential(credential: credential);

        // Assert
        expect(result['valid'], isTrue);
        expect(result['errors'], isEmpty);
        expect(result['status'], equals('success'));
      });
    });

    group('mDoc Operations', () {
      test('should create mDoc', () async {
        // Arrange
        final issuerSignedItems = {
          'org.iso.18013.5.1': {
            'given_name': 'John',
            'family_name': 'Doe',
            'birth_date': '1990-01-01',
            'age_over_18': true,
            'age_over_21': true,
          },
        };

        final responseBody = json.encode({
          'mdoc': 'base64-encoded-mdoc-data',
          'docType': 'org.iso.18013.5.1.mDL',
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/mdoc/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'docType': 'org.iso.18013.5.1.mDL',
              'issuerSignedItems': issuerSignedItems,
              'issuerAuth': {},
            }),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.createMDoc(
          issuerSignedItems: issuerSignedItems,
        );

        // Assert
        expect(result['mdoc'], isNotNull);
        expect(result['docType'], equals('org.iso.18013.5.1.mDL'));
        expect(result['status'], equals('success'));
      });

      test('should verify age from mDoc', () async {
        // Arrange
        const mdocBase64 = 'base64-encoded-mdoc-data';
        const minimumAge = 21;

        final responseBody = json.encode({
          'verified': true,
          'minimumAge': minimumAge,
          'method': 'age_over_21',
          'verifiedAt': '2024-01-01T00:00:00Z',
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/age/verify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'mdoc': mdocBase64, 'minimumAge': minimumAge}),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.verifyAge(
          mdocBase64: mdocBase64,
          minimumAge: minimumAge,
        );

        // Assert
        expect(result['verified'], isTrue);
        expect(result['minimumAge'], equals(minimumAge));
        expect(result['method'], equals('age_over_21'));
        expect(result['status'], equals('success'));
      });
    });

    group('SD-JWT Operations', () {
      test('should create SD-JWT', () async {
        // Arrange
        final claims = {
          'iss': 'https://issuer.example.com',
          'sub': 'user123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'age': 30,
        };

        final disclosableClaims = ['name', 'email', 'age'];

        final issuerKey = {
          'kty': 'OKP',
          'crv': 'Ed25519',
          'x': 'test-key-data',
          'd': 'test-private-key-data',
        };

        final responseBody = json.encode({
          'sdJwt':
              'eyJ0eXAiOiJKV1QiLCJhbGciOiJFZERTQSJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXIxMjMifQ.signature~disclosure1~disclosure2~',
          'claims': claims,
          'disclosableClaims': disclosableClaims,
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/sd-jwt/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'claims': claims,
              'disclosableClaims': disclosableClaims,
              'issuerKey': issuerKey,
            }),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.createSdJwt(
          claims: claims,
          disclosableClaims: disclosableClaims,
          issuerKey: issuerKey,
        );

        // Assert
        expect(result['sdJwt'], isNotNull);
        expect(result['sdJwt'], contains('~'));
        expect(result['status'], equals('success'));
      });

      test('should verify SD-JWT', () async {
        // Arrange
        const sdJwt =
            'eyJ0eXAiOiJKV1QiLCJhbGciOiJFZERTQSJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXIxMjMifQ.signature~disclosure1~disclosure2~';

        final issuerPublicKey = {
          'kty': 'OKP',
          'crv': 'Ed25519',
          'x': 'test-key-data',
        };

        final responseBody = json.encode({
          'valid': true,
          'disclosedClaims': {
            'iss': 'https://issuer.example.com',
            'sub': 'user123',
            'name': 'John Doe',
          },
          'verifiedAt': '2024-01-01T00:00:00Z',
          'errors': [],
          'status': 'success',
        });

        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/sd-jwt/verify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'sdJwt': sdJwt,
              'issuerPublicKey': issuerPublicKey,
            }),
          ),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        final result = await service.verifySdJwt(
          sdJwt: sdJwt,
          issuerPublicKey: issuerPublicKey,
        );

        // Assert
        expect(result['valid'], isTrue);
        expect(result['disclosedClaims'], isNotNull);
        expect(result['status'], equals('success'));
      });
    });

    group('Model Classes', () {
      test('SpruceDidResult should parse from JSON correctly', () {
        // Arrange
        final json = {
          'did': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
          'keyJwk': {'kty': 'OKP', 'crv': 'Ed25519', 'x': 'test-key-data'},
          'verificationMethod':
              'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
          'created': '2024-01-01T00:00:00.000Z',
          'status': 'success',
        };

        // Act
        final result = SpruceDidResult.fromJson(json);

        // Assert
        expect(result.did, equals(json['did']));
        expect(result.keyJwk, equals(json['keyJwk']));
        expect(result.verificationMethod, equals(json['verificationMethod']));
        expect(result.status, equals(json['status']));
        expect(result.created, isNotNull);
      });

      test('SpruceVerificationResult should parse from JSON correctly', () {
        // Arrange
        final json = {
          'valid': true,
          'errors': [],
          'verifiedAt': '2024-01-01T00:00:00.000Z',
          'status': 'success',
        };

        // Act
        final result = SpruceVerificationResult.fromJson(json);

        // Assert
        expect(result.valid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.status, equals('success'));
        expect(result.verifiedAt, isNotNull);
      });

      test('SpruceAgeVerificationResult should parse from JSON correctly', () {
        // Arrange
        final json = {
          'verified': true,
          'minimumAge': 21,
          'calculatedAge': 25,
          'method': 'age_over_21',
          'verifiedAt': '2024-01-01T00:00:00.000Z',
          'status': 'success',
        };

        // Act
        final result = SpruceAgeVerificationResult.fromJson(json);

        // Assert
        expect(result.verified, isTrue);
        expect(result.minimumAge, equals(21));
        expect(result.calculatedAge, equals(25));
        expect(result.method, equals('age_over_21'));
        expect(result.status, equals('success'));
        expect(result.verifiedAt, isNotNull);
      });
    });

    group('Error Handling', () {
      test('should handle HTTP errors gracefully', () async {
        // Arrange
        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/did/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'method': 'key'}),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(json.encode({'error': 'Invalid method'}), 400),
        );

        // Act & Assert
        expect(
          () async => await service.createDid(method: 'key'),
          throwsA(predicate((e) => e.toString().contains('Invalid method'))),
        );
      });

      test('should handle network errors gracefully', () async {
        // Arrange
        when(
          mockClient.post(
            Uri.parse('http://localhost:5000/did/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'method': 'key'}),
          ),
        ).thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () async => await service.createDid(method: 'key'),
          throwsA(predicate((e) => e.toString().contains('Network error'))),
        );
      });
    });

    group('Utility Methods', () {
      test('should encode bytes to base64', () {
        // Arrange
        final bytes = [1, 2, 3, 4, 5];
        const expectedBase64 = 'AQIDBAU=';

        // Act
        final result = service.bytesToBase64(Uint8List.fromList(bytes));

        // Assert
        expect(result, equals(expectedBase64));
      });

      test('should decode base64 to bytes', () {
        // Arrange
        const base64String = 'AQIDBAU=';
        final expectedBytes = [1, 2, 3, 4, 5];

        // Act
        final result = service.base64ToBytes(base64String);

        // Assert
        expect(result, equals(expectedBytes));
      });
    });
  });
}
