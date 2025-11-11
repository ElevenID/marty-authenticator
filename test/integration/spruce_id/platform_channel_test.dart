import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  group('SpruceID Platform Channel Integration Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      // Reset method call handlers after each test
      const MethodChannel(
        'com.netknights.authenticator/spruce_id',
      ).setMockMethodCallHandler(null);
      const MethodChannel(
        'com.netknights.authenticator/spruce_mdoc',
      ).setMockMethodCallHandler(null);
      const MethodChannel(
        'com.netknights.authenticator/spruce_oid4vc',
      ).setMockMethodCallHandler(null);
      const MethodChannel(
        'com.netknights.authenticator/spruce_wallet',
      ).setMockMethodCallHandler(null);
    });

    group('Platform Channel Communication', () {
      test('should handle main spruce_id channel methods', () async {
        var receivedCalls = <String>[];

        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          receivedCalls.add(methodCall.method);

          switch (methodCall.method) {
            case 'initialize':
              return null;
            case 'createDid':
              return {
                'did':
                    'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
                'keyId': 'z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
              };
            case 'signCredential':
              return {
                'signed': true,
                'credential': {
                  ...methodCall.arguments['credential'],
                  'proof': {
                    'type': 'Ed25519Signature2018',
                    'proofValue': 'test_signature',
                  },
                },
              };
            case 'verifyCredential':
              return {'valid': true, 'errors': []};
            default:
              return null;
          }
        });

        // Test channel calls
        const channel = MethodChannel('com.netknights.authenticator/spruce_id');

        await channel.invokeMethod('initialize');
        await channel.invokeMethod('createDid', {'method': 'key'});
        await channel.invokeMethod('signCredential', {
          'credential': {'type': 'TestCredential'},
        });
        await channel.invokeMethod('verifyCredential', {
          'credential': 'test.jwt.token',
        });

        expect(
          receivedCalls,
          containsAll([
            'initialize',
            'createDid',
            'signCredential',
            'verifyCredential',
          ]),
        );
      });

      test('should handle mDoc channel methods', () async {
        var receivedCalls = <String>[];

        const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          receivedCalls.add(methodCall.method);

          switch (methodCall.method) {
            case 'initializeMdl':
              return null;
            case 'presentForAgeVerification':
              return {
                'verified': true,
                'minimumAge': methodCall.arguments['minimumAge'],
              };
            case 'createMdocResponse':
              return Uint8List.fromList([0x83, 0x01, 0x02, 0x03]);
            default:
              return null;
          }
        });

        const channel = MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        );

        await channel.invokeMethod('initializeMdl', {
          'mdlData': {'docType': 'org.iso.18013.5.1.mDL'},
        });
        await channel.invokeMethod('presentForAgeVerification', {
          'minimumAge': 21,
        });
        await channel.invokeMethod('createMdocResponse', {
          'docType': 'org.iso.18013.5.1.mDL',
          'attributes': {'name': 'John'},
          'requestedAttributes': ['name'],
        });

        expect(
          receivedCalls,
          containsAll([
            'initializeMdl',
            'presentForAgeVerification',
            'createMdocResponse',
          ]),
        );
      });

      test('should handle OID4VC/SD-JWT channel methods', () async {
        var receivedCalls = <String>[];

        const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          receivedCalls.add(methodCall.method);

          switch (methodCall.method) {
            case 'initializeOid4vc':
              return null;
            case 'createSdJwt':
              return 'jwt_header.jwt_payload.signature~disclosure1~disclosure2~';
            case 'presentSdJwt':
              return 'jwt_header.jwt_payload.signature~selective_disclosure~';
            case 'verifyPresentation':
              return {'valid': true};
            default:
              return null;
          }
        });

        const channel = MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        );

        await channel.invokeMethod('initializeOid4vc');
        await channel.invokeMethod('createSdJwt', {
          'claims': {'name': 'John'},
          'selectivelyDisclosableClaims': ['name'],
        });
        await channel.invokeMethod('presentSdJwt', {
          'sdJwt': 'full_sd_jwt',
          'discloseClaims': ['name'],
        });
        await channel.invokeMethod('verifyPresentation', {
          'presentation': 'presentation_data',
        });

        expect(
          receivedCalls,
          containsAll([
            'initializeOid4vc',
            'createSdJwt',
            'presentSdJwt',
            'verifyPresentation',
          ]),
        );
      });

      test('should handle wallet channel methods', () async {
        var receivedCalls = <String>[];

        const MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          receivedCalls.add(methodCall.method);

          switch (methodCall.method) {
            case 'initializeWallet':
              return null;
            case 'storeCredential':
              return null;
            case 'getCredentials':
              return [
                methodCall.arguments?['credential'] ?? {'type': 'test'},
              ];
            case 'getCredentialsByType':
              return [
                {'type': methodCall.arguments['type']},
              ];
            case 'deleteCredential':
              return null;
            default:
              return null;
          }
        });

        const channel = MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        );

        await channel.invokeMethod('initializeWallet');
        await channel.invokeMethod('storeCredential', {
          'credential': {'type': 'TestCredential'},
        });
        await channel.invokeMethod('getCredentials');
        await channel.invokeMethod('getCredentialsByType', {
          'type': 'TestCredential',
        });
        await channel.invokeMethod('deleteCredential', {'id': 'credential_id'});

        expect(
          receivedCalls,
          containsAll([
            'initializeWallet',
            'storeCredential',
            'getCredentials',
            'getCredentialsByType',
            'deleteCredential',
          ]),
        );
      });
    });

    group('Platform Error Handling', () {
      test('should handle platform exceptions correctly', () async {
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          throw PlatformException(
            code: 'TEST_ERROR',
            message: 'Test error message',
            details: {'additional': 'error details'},
          );
        });

        const channel = MethodChannel('com.netknights.authenticator/spruce_id');

        await expectLater(
          () => channel.invokeMethod('createDid'),
          throwsA(isA<PlatformException>()),
        );
      });

      test('should handle missing method exceptions', () async {
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          throw MissingPluginException('Method not implemented');
        });

        const channel = MethodChannel('com.netknights.authenticator/spruce_id');

        await expectLater(
          () => channel.invokeMethod('nonExistentMethod'),
          throwsA(isA<MissingPluginException>()),
        );
      });
    });

    group('Real Data Scenarios', () {
      test('should handle real EU driving license mDoc data', () async {
        final realEuMdlData = {
          'docType': 'org.iso.18013.5.1.mDL',
          'nameSpaces': {
            'org.iso.18013.5.1': {
              'family_name': 'Müller',
              'given_name': 'Anna',
              'birth_date': '1985-03-15',
              'age_in_years': 38,
              'issue_date': '2020-03-15',
              'expiry_date': '2030-03-14',
              'issuing_country': 'DE',
              'issuing_authority': 'Stadt München',
              'document_number': 'D1234567890',
              'driving_privileges': [
                {
                  'vehicle_category_code': 'B',
                  'issue_date': '2020-03-15',
                  'expiry_date': '2030-03-14',
                },
              ],
            },
          },
        };

        const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'initializeMdl') {
            final data = methodCall.arguments['mdlData'] as Map;
            expect(data['docType'], equals('org.iso.18013.5.1.mDL'));
            expect(
              data['nameSpaces']['org.iso.18013.5.1']['issuing_country'],
              equals('DE'),
            );
            return null;
          }
          return null;
        });

        const channel = MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        );
        await expectLater(
          () =>
              channel.invokeMethod('initializeMdl', {'mdlData': realEuMdlData}),
          returnsNormally,
        );
      });

      test('should handle real university credential data', () async {
        final realUniversityCredential = {
          '@context': [
            'https://www.w3.org/2018/credentials/v1',
            'https://www.w3.org/2018/credentials/examples/v1',
          ],
          'id': 'http://university.edu/credentials/3732',
          'type': ['VerifiableCredential', 'UniversityDegreeCredential'],
          'issuer': {
            'id': 'did:web:university.edu',
            'name': 'Technical University of Munich',
          },
          'issuanceDate': '2023-06-15T10:30:00Z',
          'expirationDate': '2033-06-15T10:30:00Z',
          'credentialSubject': {
            'id': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
            'degree': {
              'type': 'BachelorDegree',
              'name': 'Bachelor of Science in Computer Science',
              'degreeSchool':
                  'School of Computation, Information and Technology',
            },
            'graduationDate': '2023-06-15',
            'gpa': 1.5, // German grading system (1.0 = best, 4.0 = worst)
            'honorsAwarded': 'magna cum laude',
          },
        };

        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'signCredential') {
            final credential = methodCall.arguments['credential'] as Map;
            expect(credential['type'], contains('UniversityDegreeCredential'));
            expect(
              credential['credentialSubject']['degree']['type'],
              equals('BachelorDegree'),
            );
            return {
              'signed': true,
              'credential': {
                ...credential,
                'proof': {
                  'type': 'Ed25519Signature2018',
                  'created': '2023-06-15T10:30:00Z',
                  'proofPurpose': 'assertionMethod',
                  'verificationMethod': 'did:web:university.edu#key-1',
                  'proofValue': 'z4Qy9ZkJ...real_signature_would_be_here',
                },
              },
            };
          }
          return null;
        });

        const channel = MethodChannel('com.netknights.authenticator/spruce_id');
        final result = await channel.invokeMethod('signCredential', {
          'credential': realUniversityCredential,
        });

        expect(result['signed'], isTrue);
        expect(
          result['credential']['proof']['verificationMethod'],
          contains('university.edu'),
        );
      });

      test('should handle real selective disclosure scenario', () async {
        // Real scenario: sharing only name and age verification, not exact birth date
        final fullClaims = {
          'iss': 'did:web:government.eu',
          'sub': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
          'given_name': 'Anna',
          'family_name': 'Müller',
          'birth_date': '1985-03-15',
          'nationality': 'DE',
          'passport_number': 'C0123456789',
          'age_over_18': true,
          'age_over_21': true,
          'issuing_authority': 'German Federal Ministry of the Interior',
        };

        final selectiveDisclosure = [
          'given_name',
          'family_name',
          'age_over_18',
          'nationality',
        ];

        const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createSdJwt') {
            final claims = methodCall.arguments['claims'] as Map;
            final disclosableClaims =
                methodCall.arguments['selectivelyDisclosableClaims'] as List;

            expect(claims['given_name'], equals('Anna'));
            expect(disclosableClaims, contains('age_over_18'));
            expect(
              disclosableClaims,
              isNot(contains('birth_date')),
            ); // Birth date should not be disclosed
            expect(
              disclosableClaims,
              isNot(contains('passport_number')),
            ); // Passport number should be private

            // Return SD-JWT with selective disclosures
            return 'eyJhbGciOiJFZERTQSJ9.eyJpc3MiOiJkaWQ6d2ViOmdvdmVybm1lbnQuZXUiLCJfc2QiOlsiY2xhaW0xIiwiY2xhaW0yIiwiY2xhaW0zIiwiY2xhaW00Il19.signature~WyJzYWx0MSIsImdpdmVuX25hbWUiLCJBbm5hIl0~WyJzYWx0MiIsImZhbWlseV9uYW1lIiwiTcO8bGxlciJd~WyJzYWx0MyIsImFnZV9vdmVyXzE4Iix0cnVlXQ~WyJzYWx0NCIsIm5hdGlvbmFsaXR5IiwiREUiXQ~';
          }
          return null;
        });

        const channel = MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        );
        final result = await channel.invokeMethod('createSdJwt', {
          'claims': fullClaims,
          'selectivelyDisclosableClaims': selectiveDisclosure,
        });

        expect(
          result.split('~').length,
          equals(6),
        ); // JWT + 4 disclosures + empty KB-JWT
        expect(result, contains('eyJ')); // Should contain JWT header
      });
    });
  });
}
