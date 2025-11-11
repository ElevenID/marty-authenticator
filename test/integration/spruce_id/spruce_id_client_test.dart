import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:privacyidea_authenticator/spruce_client.dart';
import 'package:privacyidea_authenticator/services/spruce_platform_service.dart';

void main() {
  group('SpruceID Client Integration Tests', () {
    late SpruceIdClient client;

    setUpAll(() {
      // Setup mock platform channels for testing
      TestWidgetsFlutterBinding.ensureInitialized();
      client = SpruceIdClient();
    });

    group('DID Operations', () {
      test('should initialize SpruceID client successfully', () async {
        // Mock successful initialization
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'initialize') {
            return null; // Success
          }
          return null;
        });

        await expectLater(() => client.initialize(), returnsNormally);
      });

      test('should create DID with did:key method', () async {
        const realDidKeyExample =
            'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp';
        const realKeyId = 'z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp';

        // Mock DID creation with real-like data
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createDid') {
            expect(methodCall.arguments['method'], equals('key'));
            return {
              'did': realDidKeyExample,
              'keyId': realKeyId,
              'status': 'created',
            };
          }
          return null;
        });

        final result = await client.createDid(method: 'key');

        expect(result, equals(realDidKeyExample));
        expect(result.startsWith('did:key:'), isTrue);
        expect(result.length, greaterThan(50)); // DID:key DIDs are quite long
      });

      test('should create DID with did:web method', () async {
        const realDidWebExample = 'did:web:example.com:users:alice';
        const realKeyId = 'key-1';

        // Mock DID creation with real web DID format
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createDid') {
            expect(methodCall.arguments['method'], equals('web'));
            return {
              'did': realDidWebExample,
              'keyId': realKeyId,
              'status': 'created',
            };
          }
          return null;
        });

        final result = await client.createDid(method: 'web');

        expect(result, equals(realDidWebExample));
        expect(result.startsWith('did:web:'), isTrue);
      });

      test('should handle DID creation errors gracefully', () async {
        // Mock DID creation error
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createDid') {
            throw PlatformException(
              code: 'DID_CREATION_ERROR',
              message: 'Failed to create DID: Invalid key material',
            );
          }
          return null;
        });

        await expectLater(
          () => client.createDid(method: 'key'),
          throwsA(isA<SpruceIdException>()),
        );
      });
    });

    group('Credential Operations', () {
      test('should sign verifiable credential with real structure', () async {
        final realCredential = {
          '@context': [
            'https://www.w3.org/2018/credentials/v1',
            'https://www.w3.org/2018/credentials/examples/v1',
          ],
          'type': ['VerifiableCredential', 'UniversityDegreeCredential'],
          'issuer': 'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          'issuanceDate': '2023-01-01T00:00:00Z',
          'credentialSubject': {
            'id': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
            'degree': {
              'type': 'BachelorDegree',
              'name': 'Bachelor of Science and Arts',
            },
          },
        };

        final signedCredentialExample = {
          ...realCredential,
          'proof': {
            'type': 'Ed25519Signature2018',
            'created': '2023-01-01T00:00:00Z',
            'proofPurpose': 'assertionMethod',
            'verificationMethod':
                'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
            'proofValue': 'zAN1rKvtG...truncated_for_example...3G7QnKyXa',
          },
        };

        // Mock credential signing
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'signCredential') {
            expect(methodCall.arguments['credential'], equals(realCredential));
            return {
              'signed': true,
              'credential': signedCredentialExample,
              'status': 'signed',
            };
          }
          return null;
        });

        final result = await client.signCredential(realCredential);

        expect(result['signed'], isTrue);
        expect(result['credential']['proof'], isNotNull);
        expect(
          result['credential']['proof']['type'],
          equals('Ed25519Signature2018'),
        );
        expect(
          result['credential']['proof']['verificationMethod'],
          contains('did:key:'),
        );
      });

      test('should verify valid credential', () async {
        const validCredentialJwt =
            'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6a2V5Ono2TWtpVEJ6MXltdWVwQVE0SEVIWVNGMUg4cXVHNUdMVlZRUjNkamRYM21Eb29XcCIsInN1YiI6ImRpZDprZXk6ejZNa2pjaGhmVXNENm1tdm5pOG1DZFhIdzIxNlhybTliUWUybUJIMVA1UkRqVkpHIiwidmMiOnsiQGNvbnRleHQiOlsiaHR0cHM6Ly93d3cudzMub3JnLzIwMTgvY3JlZGVudGlhbHMvdjEiLCJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy9leGFtcGxlcy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiVW5pdmVyc2l0eURlZ3JlZUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiaWQiOiJkaWQ6a2V5Ono2TWtqY2hoZlVzRDZtbXZuaThiQ2RYSHcyMTZYcm05YlFlMm1CSDFQNVJEalZKRyIsImRlZ3JlZSI6eyJ0eXBlIjoiQmFjaGVsb3JEZWdyZWUiLCJuYW1lIjoiQmFjaGVsb3Igb2YgU2NpZW5jZSBhbmQgQXJ0cyJ9fX0sImlhdCI6MTY3MjUzMTIwMCwiZXhwIjoxNzA0MDY3MjAwfQ.signature_would_be_here';

        // Mock credential verification
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'verifyCredential') {
            expect(
              methodCall.arguments['credential'],
              equals(validCredentialJwt),
            );
            return {'valid': true, 'status': 'verified', 'errors': []};
          }
          return null;
        });

        final result = await client.verifyCredential(validCredentialJwt);

        expect(result['valid'], isTrue);
        expect(result['status'], equals('verified'));
        expect(result['errors'], isEmpty);
      });

      test('should detect invalid credential', () async {
        const invalidCredentialJwt = 'invalid.jwt.token';

        // Mock credential verification failure
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'verifyCredential') {
            return {
              'valid': false,
              'status': 'invalid',
              'errors': ['Invalid JWT format', 'Signature verification failed'],
            };
          }
          return null;
        });

        final result = await client.verifyCredential(invalidCredentialJwt);

        expect(result['valid'], isFalse);
        expect(result['status'], equals('invalid'));
        expect(result['errors'], isNotEmpty);
      });
    });

    group('mDoc/MDL Operations', () {
      test('should initialize MDL with real driving license data', () async {
        final realMdlData = {
          'docType': 'org.iso.18013.5.1.mDL',
          'nameSpaces': {
            'org.iso.18013.5.1': {
              'family_name': 'Doe',
              'given_name': 'John',
              'birth_date': '1990-01-01',
              'age_in_years': 33,
              'age_birth_year': 1990,
              'document_number': 'DL123456789',
              'driving_privileges': [
                {
                  'vehicle_category_code': 'A',
                  'issue_date': '2018-01-01',
                  'expiry_date': '2028-01-01',
                },
              ],
              'portrait': 'base64_encoded_portrait_image_data',
            },
          },
        };

        final mdocManager = SpruceIdMdocManager();

        // Mock MDL initialization
        const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'initializeMdl') {
            expect(methodCall.arguments['mdlData'], equals(realMdlData));
            return null; // Success
          }
          return null;
        });

        await expectLater(
          () => mdocManager.initializeMdl(realMdlData),
          returnsNormally,
        );
      });

      test('should perform age verification with 21+ requirement', () async {
        final mdocManager = SpruceIdMdocManager();

        // Mock age verification for 21+ requirement (common for alcohol/tobacco)
        const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'presentForAgeVerification') {
            expect(methodCall.arguments['minimumAge'], equals(21));
            expect(methodCall.arguments['proximityRequired'], isFalse);
            return {
              'verified': true,
              'minimumAge': 21,
              'proximityRequired': false,
              'status': 'verified',
            };
          }
          return null;
        });

        final result = await mdocManager.presentForAgeVerification(
          minimumAge: 21,
        );

        expect(result['verified'], isTrue);
        expect(result['minimumAge'], equals(21));
      });

      test('should handle age verification failure for underage', () async {
        final mdocManager = SpruceIdMdocManager();

        // Mock age verification failure (person under 18)
        const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'presentForAgeVerification') {
            expect(methodCall.arguments['minimumAge'], equals(18));
            return {
              'verified': false,
              'minimumAge': 18,
              'proximityRequired': false,
              'status': 'age_verification_failed',
            };
          }
          return null;
        });

        final result = await mdocManager.presentForAgeVerification(
          minimumAge: 18,
        );

        expect(result['verified'], isFalse);
        expect(result['status'], equals('age_verification_failed'));
      });

      test('should create mDoc response with selective disclosure', () async {
        final requestedAttributes = [
          'given_name',
          'family_name',
          'age_over_18',
        ];
        final mdlAttributes = {
          'given_name': 'John',
          'family_name': 'Doe',
          'birth_date': '1990-01-01',
          'age_over_18': true,
          'age_over_21': false,
          'document_number': 'DL123456789',
        };

        // Mock selective disclosure response (should only include requested attributes)
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createMdocResponse') {
            expect(
              methodCall.arguments['docType'],
              equals('org.iso.18013.5.1.mDL'),
            );
            expect(methodCall.arguments['attributes'], equals(mdlAttributes));
            expect(
              methodCall.arguments['requestedAttributes'],
              equals(requestedAttributes),
            );

            // Return CBOR-encoded mDoc response (simplified as bytes)
            return Uint8List.fromList([
              0x83, 0x01, 0x02, 0x03, // Simplified CBOR structure
              0x58, 0x20, // Map with selective disclosure
              // ... would contain real CBOR encoded mDoc data
            ]);
          }
          return null;
        });

        final result = await client.createMdocResponse(
          docType: 'org.iso.18013.5.1.mDL',
          attributes: mdlAttributes,
          requestedAttributes: requestedAttributes,
        );

        expect(result, isNotEmpty);
        expect(result.length, greaterThan(4)); // Should have real CBOR data
      });
    });

    group('SD-JWT Operations', () {
      test('should create SD-JWT with selective disclosure', () async {
        final claims = {
          'iss': 'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          'sub': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
          'given_name': 'John',
          'family_name': 'Doe',
          'email': 'john.doe@example.com',
          'phone_number': '+1-202-555-0101',
          'birth_date': '1990-01-01',
          'nationality': 'US',
        };

        final selectivelyDisclosableClaims = [
          'email',
          'phone_number',
          'birth_date',
        ];

        // Example SD-JWT structure: JWT~disclosure1~disclosure2~KB-JWT
        const realSdJwtExample =
            'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6a2V5Ono2TWtpVEJ6MXltdWVwQVE0SEVIWVNGMUg4cXVHNUdMVlZRUjNkamRYM21Eb29XcCIsInN1YiI6ImRpZDprZXk6ejZNa2pjaGhmVXNENm1tdm5pOG1DZFhIdzIxNlhybTliUWUybUJIMVA1UkRqVkpHIiwiZ2l2ZW5fbmFtZSI6IkpvaG4iLCJmYW1pbHlfbmFtZSI6IkRvZSIsIm5hdGlvbmFsaXR5IjoiVVMiLCJfc2QiOlsiY2xhaW1faGFzaF9mb3JfZW1haWwiLCJjbGFpbV9oYXNoX2Zvcl9waG9uZSIsImNsYWltX2hhc2hfZm9yX2JpcnRoX2RhdGUiXX0.signature~WyJzYWx0IiwiZW1haWwiLCJqb2huLmRvZUBleGFtcGxlLmNvbSJd~WyJzYWx0MiIsInBob25lX251bWJlciIsIisxLTIwMi01NTUtMDEwMSJd~WyJzYWx0MyIsImJpcnRoX2RhdGUiLCIxOTkwLTAxLTAxIl0~';

        final sdJwtManager = SpruceIdSdJwtManager();

        // Mock SD-JWT creation
        const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createSdJwt') {
            expect(methodCall.arguments['claims'], equals(claims));
            expect(
              methodCall.arguments['selectivelyDisclosableClaims'],
              equals(selectivelyDisclosableClaims),
            );
            return realSdJwtExample;
          }
          return null;
        });

        final result = await sdJwtManager.createSdJwt(
          claims: claims,
          selectivelyDisclosableClaims: selectivelyDisclosableClaims,
        );

        expect(result, equals(realSdJwtExample));
        expect(
          result.contains('~'),
          isTrue,
        ); // SD-JWT contains tildes as separators
        expect(
          result.split('~').length,
          equals(5),
        ); // JWT + 3 disclosures + KB-JWT
      });

      test('should present SD-JWT with selective disclosure', () async {
        const fullSdJwt =
            'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.base_claims.signature~WyJzYWx0IiwiZW1haWwiLCJqb2huLmRvZUBleGFtcGxlLmNvbSJd~WyJzYWx0MiIsInBob25lX251bWJlciIsIisxLTIwMi01NTUtMDEwMSJd~WyJzYWx0MyIsImJpcnRoX2RhdGUiLCIxOTkwLTAxLTAxIl0~';
        final discloseClaims = [
          'email',
        ]; // Only disclose email, keep phone and birth_date private

        const selectivePresentationExample =
            'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.base_claims.signature~WyJzYWx0IiwiZW1haWwiLCJqb2huLmRvZUBleGFtcGxlLmNvbSJd~';

        final sdJwtManager = SpruceIdSdJwtManager();

        // Mock SD-JWT presentation creation
        const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'createSdJwt') {
            // For presentation, we create a new SD-JWT with only selected claims
            return selectivePresentationExample;
          }
          return null;
        });

        final result = await sdJwtManager.present(
          sdJwt: fullSdJwt,
          discloseClaims: discloseClaims,
        );

        expect(result, equals(selectivePresentationExample));
        expect(
          result.split('~').length,
          equals(2),
        ); // JWT + 1 disclosure (only email)
      });
    });

    group('Wallet Operations', () {
      test('should store and retrieve credentials', () async {
        final testCredential = {
          'type': 'UniversityDegreeCredential',
          'issuer': 'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          'credentialSubject': {
            'degree': {
              'type': 'BachelorDegree',
              'name': 'Bachelor of Computer Science',
            },
          },
          'issuanceDate': '2023-05-15T10:30:00Z',
        };

        final walletManager = SpruceIdWalletManager();

        // Mock credential storage and retrieval
        const MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'storeCredential') {
            expect(methodCall.arguments['credential'], equals(testCredential));
            return null; // Success
          } else if (methodCall.method == 'getCredentials') {
            return [testCredential]; // Return stored credential
          }
          return null;
        });

        // Store credential
        await expectLater(
          () => walletManager.storeCredential(testCredential),
          returnsNormally,
        );

        // Retrieve credentials
        final retrievedCredentials = await walletManager.getAllCredentials();

        expect(retrievedCredentials, hasLength(1));
        expect(retrievedCredentials.first, equals(testCredential));
      });

      test('should retrieve credentials by type', () async {
        final degreeCredentials = [
          {
            'type': 'UniversityDegreeCredential',
            'issuer': 'did:web:university.edu',
            'credentialSubject': {
              'degree': {'type': 'BachelorDegree'},
            },
          },
          {
            'type': 'UniversityDegreeCredential',
            'issuer': 'did:web:college.edu',
            'credentialSubject': {
              'degree': {'type': 'MasterDegree'},
            },
          },
        ];

        final walletManager = SpruceIdWalletManager();

        // Mock type-specific credential retrieval
        const MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'getCredentialsByType') {
            expect(
              methodCall.arguments['type'],
              equals('UniversityDegreeCredential'),
            );
            return degreeCredentials;
          }
          return null;
        });

        final result = await walletManager.getCredentialsByType(
          'UniversityDegreeCredential',
        );

        expect(result, hasLength(2));
        expect(
          result.every((cred) => cred['type'] == 'UniversityDegreeCredential'),
          isTrue,
        );
      });
    });

    group('Error Handling', () {
      test('should handle platform channel errors gracefully', () async {
        // Mock platform error
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          throw PlatformException(
            code: 'NETWORK_ERROR',
            message: 'Failed to connect to DID resolver',
            details: {'endpoint': 'https://uniresolver.io/1.0/identifiers/'},
          );
        });

        await expectLater(
          () => client.createDid(method: 'web'),
          throwsA(isA<SpruceIdException>()),
        );
      });

      test('should validate credential format before processing', () async {
        final invalidCredential = {
          'invalid': 'structure',
          'missing': 'required_fields',
        };

        await expectLater(
          () => client.signCredential(invalidCredential),
          throwsA(isA<SpruceIdException>()),
        );
      });
    });
  });
}
