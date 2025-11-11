import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
  group('SpruceID End-to-End Integration Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      // Reset all mock handlers
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

    group('Complete University Degree Credential Workflow', () {
      test(
        'should handle full credential issuance and verification workflow',
        () async {
          // Step 1: Initialize SpruceID
          // Step 2: Create issuer DID
          // Step 3: Create holder DID
          // Step 4: Issue university degree credential
          // Step 5: Store credential in wallet
          // Step 6: Present credential for verification
          // Step 7: Verify presented credential

          var callSequence = <String>[];
          String? issuerDid;
          String? holderDid;
          Map<String, dynamic>? issuedCredential;
          String? storedCredentialId;

          // Mock all channel handlers
          const MethodChannel(
            'com.netknights.authenticator/spruce_id',
          ).setMockMethodCallHandler((MethodCall methodCall) async {
            callSequence.add('spruce_id:${methodCall.method}');

            switch (methodCall.method) {
              case 'initialize':
                return null;
              case 'createDid':
                final method = methodCall.arguments['method'] as String;
                if (method == 'key') {
                  final newDid =
                      'did:key:z6Mk${DateTime.now().millisecondsSinceEpoch}';
                  if (issuerDid == null) {
                    issuerDid = newDid;
                  } else {
                    holderDid = newDid;
                  }
                  return newDid;
                }
                return null;
              case 'signCredential':
                final credential = methodCall.arguments['credential'] as Map;
                issuedCredential = {
                  ...credential,
                  'proof': {
                    'type': 'Ed25519Signature2018',
                    'created': '2023-06-15T10:30:00Z',
                    'proofPurpose': 'assertionMethod',
                    'verificationMethod': '$issuerDid#key-1',
                    'proofValue':
                        'z58DAdFfa9CwHp${DateTime.now().millisecondsSinceEpoch}',
                  },
                };
                return {'signed': true, 'credential': issuedCredential};
              case 'verifyCredential':
                return {'valid': true, 'status': 'verified', 'errors': []};
              default:
                return null;
            }
          });

          const MethodChannel(
            'com.netknights.authenticator/spruce_wallet',
          ).setMockMethodCallHandler((MethodCall methodCall) async {
            callSequence.add('spruce_wallet:${methodCall.method}');

            switch (methodCall.method) {
              case 'initializeWallet':
                return null;
              case 'storeCredential':
                storedCredentialId =
                    'cred_${DateTime.now().millisecondsSinceEpoch}';
                return storedCredentialId;
              case 'getCredentials':
                return issuedCredential != null ? [issuedCredential] : [];
              case 'getCredentialsByType':
                final type = methodCall.arguments['type'] as String;
                return type == 'UniversityDegreeCredential' &&
                        issuedCredential != null
                    ? [issuedCredential]
                    : [];
              default:
                return null;
            }
          });

          // Execute the complete workflow

          // 1. Initialize SpruceID
          const spruceChannel = MethodChannel(
            'com.netknights.authenticator/spruce_id',
          );
          await spruceChannel.invokeMethod('initialize');

          // 2. Create issuer DID (university)
          final issuerDidResult = await spruceChannel.invokeMethod(
            'createDid',
            {'method': 'key'},
          );
          expect(issuerDidResult, equals(issuerDid));
          expect(issuerDid, isNotNull);
          expect(issuerDid!.startsWith('did:key:'), isTrue);

          // 3. Create holder DID (student)
          final holderDidResult = await spruceChannel.invokeMethod(
            'createDid',
            {'method': 'key'},
          );
          expect(holderDidResult, equals(holderDid));
          expect(holderDid, isNotNull);
          expect(holderDid!.startsWith('did:key:'), isTrue);

          // 4. Create university degree credential
          final universityCredential = {
            '@context': [
              'https://www.w3.org/2018/credentials/v1',
              'https://www.w3.org/2018/credentials/examples/v1',
            ],
            'type': ['VerifiableCredential', 'UniversityDegreeCredential'],
            'issuer': issuerDid,
            'issuanceDate': '2023-06-15T10:30:00Z',
            'credentialSubject': {
              'id': holderDid,
              'degree': {
                'type': 'BachelorDegree',
                'name': 'Bachelor of Science in Computer Science',
                'degreeSchool': 'Technical University of Munich',
              },
              'graduationDate': '2023-06-15',
              'gpa': 1.3,
            },
          };

          // 5. Sign credential (university issues it)
          final signResult = await spruceChannel.invokeMethod(
            'signCredential',
            {'credential': universityCredential},
          );

          expect(signResult['signed'], isTrue);
          expect(issuedCredential, isNotNull);
          expect(issuedCredential!['proof'], isNotNull);
          expect(
            issuedCredential!['proof']['verificationMethod'],
            contains(issuerDid!),
          );

          // 6. Initialize wallet
          const walletChannel = MethodChannel(
            'com.netknights.authenticator/spruce_wallet',
          );
          await walletChannel.invokeMethod('initializeWallet');

          // 7. Store credential in wallet
          final storeResult = await walletChannel.invokeMethod(
            'storeCredential',
            {'credential': issuedCredential},
          );
          expect(storeResult, equals(storedCredentialId));
          expect(storedCredentialId, isNotNull);

          // 8. Retrieve credentials from wallet
          final retrievedCredentials = await walletChannel.invokeMethod(
            'getCredentials',
          );
          expect(retrievedCredentials, hasLength(1));
          expect(
            retrievedCredentials[0]['type'],
            contains('UniversityDegreeCredential'),
          );

          // 9. Get credentials by specific type
          final degreeCredentials = await walletChannel.invokeMethod(
            'getCredentialsByType',
            {'type': 'UniversityDegreeCredential'},
          );
          expect(degreeCredentials, hasLength(1));
          expect(degreeCredentials[0], equals(issuedCredential));

          // 10. Verify the stored credential
          final verifyResult = await spruceChannel.invokeMethod(
            'verifyCredential',
            {'credential': jsonEncode(issuedCredential)},
          );
          expect(verifyResult['valid'], isTrue);
          expect(verifyResult['status'], equals('verified'));
          expect(verifyResult['errors'], isEmpty);

          // Verify the complete call sequence
          expect(
            callSequence,
            equals([
              'spruce_id:initialize',
              'spruce_id:createDid', // issuer DID
              'spruce_id:createDid', // holder DID
              'spruce_id:signCredential',
              'spruce_wallet:initializeWallet',
              'spruce_wallet:storeCredential',
              'spruce_wallet:getCredentials',
              'spruce_wallet:getCredentialsByType',
              'spruce_id:verifyCredential',
            ]),
          );
        },
      );
    });

    group('Complete Driving License mDoc Workflow', () {
      test(
        'should handle full mDoc issuance and age verification workflow',
        () async {
          var callSequence = <String>[];
          Map<String, dynamic>? mdlData;
          Uint8List? mdocResponse;

          const MethodChannel(
            'com.netknights.authenticator/spruce_mdoc',
          ).setMockMethodCallHandler((MethodCall methodCall) async {
            callSequence.add('spruce_mdoc:${methodCall.method}');

            switch (methodCall.method) {
              case 'initializeMdl':
                mdlData = Map<String, dynamic>.from(
                  methodCall.arguments['mdlData'] as Map,
                );
                return null;
              case 'presentForAgeVerification':
                final minimumAge = methodCall.arguments['minimumAge'] as int;
                final birthDate = DateTime.parse(
                  '1990-08-15',
                ); // From test data
                final age = DateTime.now().difference(birthDate).inDays ~/ 365;
                return {
                  'verified': age >= minimumAge,
                  'minimumAge': minimumAge,
                  'proximityRequired': false,
                  'status': age >= minimumAge
                      ? 'verified'
                      : 'age_verification_failed',
                };
              case 'createMdocResponse':
                mdocResponse = Uint8List.fromList([
                  0x83, 0x01, 0x02, 0x03, // Simplified CBOR response
                  ...List.generate(
                    50,
                    (i) => i % 256,
                  ), // Simulated mDoc CBOR data
                ]);
                return mdocResponse;
              default:
                return null;
            }
          });

          // Execute driving license workflow

          // 1. Create driving license data
          final drivingLicenseData = {
            'docType': 'org.iso.18013.5.1.mDL',
            'nameSpaces': {
              'org.iso.18013.5.1': {
                'family_name': 'Smith',
                'given_name': 'Alice',
                'birth_date': '1990-08-15',
                'age_in_years': 33,
                'issue_date': '2020-08-15',
                'expiry_date': '2030-08-14',
                'issuing_country': 'US',
                'issuing_authority': 'California DMV',
                'document_number': 'DL987654321',
                'driving_privileges': [
                  {
                    'vehicle_category_code': 'B',
                    'issue_date': '2020-08-15',
                    'expiry_date': '2030-08-14',
                  },
                ],
                'age_over_18': true,
                'age_over_21': true,
              },
            },
          };

          // 2. Initialize mDL
          const mdocChannel = MethodChannel(
            'com.netknights.authenticator/spruce_mdoc',
          );
          await mdocChannel.invokeMethod('initializeMdl', {
            'mdlData': drivingLicenseData,
          });

          expect(mdlData, isNotNull);
          expect(mdlData!['docType'], equals('org.iso.18013.5.1.mDL'));

          final nameSpace = mdlData!['nameSpaces']['org.iso.18013.5.1'] as Map;
          expect(nameSpace['family_name'], equals('Smith'));
          expect(nameSpace['given_name'], equals('Alice'));

          // 3. Perform age verification (21+)
          final ageVerifyResult = await mdocChannel.invokeMethod(
            'presentForAgeVerification',
            {'minimumAge': 21},
          );

          expect(ageVerifyResult['verified'], isTrue);
          expect(ageVerifyResult['minimumAge'], equals(21));
          expect(ageVerifyResult['status'], equals('verified'));

          // 4. Create selective disclosure response (only age verification, not full data)
          final mdocResponseResult = await mdocChannel.invokeMethod(
            'createMdocResponse',
            {
              'docType': 'org.iso.18013.5.1.mDL',
              'attributes': nameSpace,
              'requestedAttributes': [
                'age_over_21',
              ], // Only disclose age verification
            },
          );

          expect(mdocResponseResult, equals(mdocResponse));
          expect(mdocResponse, isNotNull);
          expect(mdocResponse!.length, greaterThan(50));

          // Verify call sequence
          expect(
            callSequence,
            equals([
              'spruce_mdoc:initializeMdl',
              'spruce_mdoc:presentForAgeVerification',
              'spruce_mdoc:createMdocResponse',
            ]),
          );
        },
      );
    });

    group('Complete SD-JWT Workflow', () {
      test(
        'should handle full SD-JWT issuance and selective presentation',
        () async {
          var callSequence = <String>[];
          String? fullSdJwt;
          String? selectivePresentation;

          const MethodChannel(
            'com.netknights.authenticator/spruce_oid4vc',
          ).setMockMethodCallHandler((MethodCall methodCall) async {
            callSequence.add('spruce_oid4vc:${methodCall.method}');

            switch (methodCall.method) {
              case 'initializeOid4vc':
                return null;
              case 'createSdJwt':
                final disclosableClaims =
                    methodCall.arguments['selectivelyDisclosableClaims']
                        as List?;

                if (disclosableClaims?.length == 4) {
                  // Full SD-JWT creation
                  fullSdJwt =
                      'eyJhbGciOiJFZERTQSJ9.eyJpc3MiOiJkaWQ6a2V5OnRlc3QiLCJfc2QiOlsiY2xhaW0xIiwiY2xhaW0yIiwiY2xhaW0zIiwiY2xhaW00Il19.sig~WyJzYWx0MSIsImdpdmVuX25hbWUiLCJKb2huIl0~WyJzYWx0MiIsImZhbWlseV9uYW1lIiwiRG9lIl0~WyJzYWx0MyIsImVtYWlsIiwiam9obkBleGFtcGxlLmNvbSJd~WyJzYWx0NCIsInBob25lX251bWJlciIsIisxMjM0NTY3ODkwIl0~';
                  return fullSdJwt;
                } else {
                  // Selective presentation
                  selectivePresentation =
                      'eyJhbGciOiJFZERTQSJ9.eyJpc3MiOiJkaWQ6a2V5OnRlc3QiLCJfc2QiOlsiY2xhaW0xIiwiY2xhaW0yIl19.sig~WyJzYWx0MSIsImdpdmVuX25hbWUiLCJKb2huIl0~WyJzYWx0MiIsImZhbWlseV9uYW1lIiwiRG9lIl0~';
                  return selectivePresentation;
                }
              case 'verifyPresentation':
                return {'valid': true, 'status': 'verified'};
              default:
                return null;
            }
          });

          // Execute SD-JWT workflow

          // 1. Initialize OID4VC
          const oid4vcChannel = MethodChannel(
            'com.netknights.authenticator/spruce_oid4vc',
          );
          await oid4vcChannel.invokeMethod('initializeOid4vc');

          // 2. Create full SD-JWT with multiple selectively disclosable claims
          final fullClaims = {
            'iss': 'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
            'sub': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
            'given_name': 'John',
            'family_name': 'Doe',
            'email': 'john@example.com',
            'phone_number': '+1234567890',
            'birth_date': '1990-01-01',
            'nationality': 'US',
          };

          final allSelectiveFields = [
            'given_name',
            'family_name',
            'email',
            'phone_number',
          ];

          final fullSdJwtResult = await oid4vcChannel
              .invokeMethod('createSdJwt', {
                'claims': fullClaims,
                'selectivelyDisclosableClaims': allSelectiveFields,
              });

          expect(fullSdJwtResult, equals(fullSdJwt));
          expect(fullSdJwt, isNotNull);
          expect(fullSdJwt!.contains('~'), isTrue);
          expect(
            fullSdJwt!.split('~').length,
            equals(6),
          ); // JWT + 4 disclosures + empty KB-JWT

          // 3. Create selective presentation (only name, not email/phone)
          final limitedSelectiveFields = ['given_name', 'family_name'];

          final presentationResult = await oid4vcChannel
              .invokeMethod('createSdJwt', {
                'claims': fullClaims,
                'selectivelyDisclosableClaims': limitedSelectiveFields,
              });

          expect(presentationResult, equals(selectivePresentation));
          expect(selectivePresentation, isNotNull);
          expect(
            selectivePresentation!.split('~').length,
            equals(4),
          ); // JWT + 2 disclosures + empty KB-JWT

          // 4. Verify the selective presentation
          final verifyResult = await oid4vcChannel.invokeMethod(
            'verifyPresentation',
            {'presentation': selectivePresentation},
          );

          expect(verifyResult['valid'], isTrue);
          expect(verifyResult['status'], equals('verified'));

          // Verify call sequence
          expect(
            callSequence,
            equals([
              'spruce_oid4vc:initializeOid4vc',
              'spruce_oid4vc:createSdJwt', // Full SD-JWT
              'spruce_oid4vc:createSdJwt', // Selective presentation
              'spruce_oid4vc:verifyPresentation',
            ]),
          );
        },
      );
    });

    group('Cross-Platform Integration Tests', () {
      test('should coordinate between all SpruceID subsystems', () async {
        // This test simulates a real-world scenario where:
        // 1. User has a government-issued digital ID (mDoc)
        // 2. User gets a university degree credential (W3C VC)
        // 3. User creates selective disclosure for job application (SD-JWT)
        // 4. All credentials are stored in wallet

        var allChannelCalls = <String>[];

        // Setup all channel mocks
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          allChannelCalls.add('main:${methodCall.method}');
          return {'success': true, 'did': 'did:key:test123'};
        });

        const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          allChannelCalls.add('mdoc:${methodCall.method}');
          return {'verified': true};
        });

        const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          allChannelCalls.add('oid4vc:${methodCall.method}');
          return {'sdJwt': 'jwt.payload.signature~disclosure~'};
        });

        const MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          allChannelCalls.add('wallet:${methodCall.method}');
          return {'stored': true};
        });

        // Execute cross-platform workflow
        await const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).invokeMethod('initialize');
        await const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).invokeMethod('initializeMdl');
        await const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).invokeMethod('initializeOid4vc');
        await const MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        ).invokeMethod('initializeWallet');

        await const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).invokeMethod('createDid');
        await const MethodChannel(
          'com.netknights.authenticator/spruce_mdoc',
        ).invokeMethod('presentForAgeVerification');
        await const MethodChannel(
          'com.netknights.authenticator/spruce_oid4vc',
        ).invokeMethod('createSdJwt');
        await const MethodChannel(
          'com.netknights.authenticator/spruce_wallet',
        ).invokeMethod('storeCredential');

        // Verify all subsystems were called
        expect(allChannelCalls, contains('main:initialize'));
        expect(allChannelCalls, contains('mdoc:initializeMdl'));
        expect(allChannelCalls, contains('oid4vc:initializeOid4vc'));
        expect(allChannelCalls, contains('wallet:initializeWallet'));
        expect(allChannelCalls, contains('main:createDid'));
        expect(allChannelCalls, contains('mdoc:presentForAgeVerification'));
        expect(allChannelCalls, contains('oid4vc:createSdJwt'));
        expect(allChannelCalls, contains('wallet:storeCredential'));
      });
    });

    group('Error Handling and Recovery Tests', () {
      test('should handle network failures gracefully', () async {
        var attemptCount = 0;

        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          attemptCount++;
          if (attemptCount <= 2) {
            throw PlatformException(
              code: 'NETWORK_ERROR',
              message: 'Failed to connect to DID resolver',
            );
          }
          return 'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp';
        });

        // First two attempts should fail
        await expectLater(
          () => const MethodChannel(
            'com.netknights.authenticator/spruce_id',
          ).invokeMethod('createDid'),
          throwsA(isA<PlatformException>()),
        );

        await expectLater(
          () => const MethodChannel(
            'com.netknights.authenticator/spruce_id',
          ).invokeMethod('createDid'),
          throwsA(isA<PlatformException>()),
        );

        // Third attempt should succeed
        final result = await const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).invokeMethod('createDid');
        expect(result, startsWith('did:key:'));
        expect(attemptCount, equals(3));
      });

      test('should handle invalid credential data', () async {
        const MethodChannel(
          'com.netknights.authenticator/spruce_id',
        ).setMockMethodCallHandler((MethodCall methodCall) async {
          final credential = methodCall.arguments['credential'];
          if (credential == null ||
              credential is! Map ||
              credential['@context'] == null) {
            throw PlatformException(
              code: 'INVALID_CREDENTIAL',
              message: 'Credential missing required @context field',
            );
          }
          return {'valid': true};
        });

        // Test with invalid credential
        await expectLater(
          () => const MethodChannel('com.netknights.authenticator/spruce_id')
              .invokeMethod('verifyCredential', {
                'credential': {'invalid': 'data'},
              }),
          throwsA(isA<PlatformException>()),
        );

        // Test with valid credential
        final result =
            await const MethodChannel(
              'com.netknights.authenticator/spruce_id',
            ).invokeMethod('verifyCredential', {
              'credential': {
                '@context': ['https://www.w3.org/2018/credentials/v1'],
                'type': ['VerifiableCredential'],
              },
            });
        expect(result['valid'], isTrue);
      });
    });
  });
}
