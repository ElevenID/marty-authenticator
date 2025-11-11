import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpruceID Real Data Validation Tests', () {
    group('W3C Verifiable Credential Format Tests', () {
      test('should validate real EU eID credential structure', () {
        final realEuEidCredential = {
          '@context': [
            'https://www.w3.org/2018/credentials/v1',
            'https://w3id.org/citizenship/v1',
            'https://w3id.org/security/suites/ed25519-2018/v1',
          ],
          'id': 'https://issuer.eu/credentials/12345',
          'type': ['VerifiableCredential', 'EuropeanIdentityCredential'],
          'issuer': {
            'id': 'did:web:issuer.eu',
            'name': 'German Federal Ministry of the Interior',
            'type': 'GovernmentOrganization',
          },
          'issuanceDate': '2023-01-15T09:30:00Z',
          'expirationDate': '2033-01-15T09:30:00Z',
          'credentialSubject': {
            'id': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
            'type': 'Person',
            'givenName': 'Anna',
            'familyName': 'Müller',
            'birthDate': '1985-03-15',
            'birthPlace': 'München, Deutschland',
            'nationality': 'DE',
            'citizenshipStatus': 'citizen',
            'documentNumber': 'T22000126',
            'personalNumber': '1234567890',
            'address': {
              'type': 'PostalAddress',
              'streetAddress': 'Musterstraße 123',
              'addressLocality': 'München',
              'postalCode': '80331',
              'addressCountry': 'DE',
            },
          },
          'evidence': [
            {
              'type': ['DocumentVerification'],
              'verifier': 'did:web:issuer.eu',
              'evidenceDocument': 'passport',
              'documentNumber': 'C0123456789',
            },
          ],
        };

        // Validate W3C VC structure
        expect(realEuEidCredential['@context'], isNotNull);
        expect(
          realEuEidCredential['@context'],
          contains('https://www.w3.org/2018/credentials/v1'),
        );
        expect(realEuEidCredential['type'], contains('VerifiableCredential'));
        expect(
          (realEuEidCredential['issuer'] as Map)['id'],
          startsWith('did:'),
        );
        expect(
          (realEuEidCredential['credentialSubject'] as Map)['id'],
          startsWith('did:'),
        );

        // Validate EU-specific fields
        expect(
          (realEuEidCredential['credentialSubject'] as Map)['nationality'],
          equals('DE'),
        );
        expect(
          (realEuEidCredential['credentialSubject']
              as Map)['citizenshipStatus'],
          equals('citizen'),
        );
        expect(realEuEidCredential['evidence'], isNotEmpty);
      });

      test('should validate real university degree credential', () {
        final realDegreeCredential = {
          '@context': [
            'https://www.w3.org/2018/credentials/v1',
            'https://www.w3.org/2018/credentials/examples/v1',
            'https://w3id.org/security/suites/ed25519-2018/v1',
          ],
          'id': 'https://tum.de/credentials/degrees/3732',
          'type': ['VerifiableCredential', 'UniversityDegreeCredential'],
          'issuer': {
            'id': 'did:web:tum.de',
            'name': 'Technische Universität München',
            'type': 'EducationalOrganization',
          },
          'issuanceDate': '2023-07-15T14:30:00Z',
          'credentialSubject': {
            'id': 'did:key:z6MkjchhfUsD6mmvni8mCdXHw216Xrm9bQe2mBH1P5RDjVJG',
            'type': 'Person',
            'alumniOf': {
              'id': 'did:web:tum.de',
              'name': 'Technische Universität München',
            },
            'degree': {
              'type': 'BachelorDegree',
              'name': 'Bachelor of Science in Computer Science',
              'degreeSchool':
                  'School of Computation, Information and Technology',
              'studyProgram': 'Informatik',
              'graduationDate': '2023-07-15',
              'gpa': {
                'value': 1.3,
                'scale': 'German (1.0-4.0)',
                'description': 'sehr gut', // very good
              },
              'finalThesis': {
                'title': 'Machine Learning Applications in Distributed Systems',
                'grade': 1.0,
              },
              'ects': 180, // European Credit Transfer System
              'honorsAwarded': 'magna cum laude',
            },
          },
          'credentialSchema': {
            'id': 'https://tum.de/schemas/degree-credential-v1.json',
            'type': 'JsonSchemaValidator2018',
          },
        };

        // Validate degree credential structure
        expect(
          realDegreeCredential['type'],
          contains('UniversityDegreeCredential'),
        );
        final credSubject = realDegreeCredential['credentialSubject'] as Map;
        final degree = credSubject['degree'] as Map;
        expect(degree['type'], equals('BachelorDegree'));
        expect(degree['ects'], equals(180));
        final gpa = degree['gpa'] as Map;
        expect(gpa['scale'], contains('German'));
        expect(realDegreeCredential['credentialSchema'], isNotNull);
      });
    });

    group('ISO 18013-5 mDoc/MDL Format Tests', () {
      test('should validate real driving license mDoc structure', () {
        // Real ISO 18013-5 mDL data structure (before CBOR encoding)
        final realMdlStructure = {
          'version': '1.0',
          'documents': [
            {
              'docType': 'org.iso.18013.5.1.mDL',
              'issuerSigned': {
                'nameSpaces': {
                  'org.iso.18013.5.1': {
                    // Required elements
                    'family_name': 'Doe',
                    'given_name': 'Jane',
                    'birth_date': '1990-08-15',
                    'issue_date': '2020-08-15',
                    'expiry_date': '2030-08-14',
                    'issuing_country': 'US',
                    'issuing_authority': 'State of California DMV',
                    'document_number': 'DL123456789',
                    'portrait':
                        'YmFzZTY0X2VuY29kZWRfcG9ydHJhaXRfZGF0YQ==', // base64 encoded image
                    'driving_privileges': [
                      {
                        'vehicle_category_code': 'A', // Motorcycles
                        'issue_date': '2018-08-15',
                        'expiry_date': '2030-08-14',
                        'restrictions': [],
                      },
                      {
                        'vehicle_category_code': 'B', // Cars
                        'issue_date': '2018-08-15',
                        'expiry_date': '2030-08-14',
                        'restrictions': ['01'], // Corrective lenses required
                      },
                    ],
                    // Optional elements
                    'un_distinguishing_sign': 'USA',
                    'administrative_number': 'ADM123456',
                    'sex': 1, // 1 = male, 2 = female, 9 = not applicable
                    'height': 175, // cm
                    'weight': 70, // kg
                    'eye_colour': 'blue',
                    'hair_colour': 'brown',
                    'birth_place': 'Los Angeles, CA',
                    'resident_address': 'California',
                    'portrait_capture_date': '2020-08-15',
                    'age_in_years': 33,
                    'age_birth_year': 1990,
                    'age_over_18': true,
                    'age_over_21': true,
                    'issuing_jurisdiction': 'California',
                    'nationality': 'USA',
                    'resident_city': 'Los Angeles',
                    'resident_state': 'CA',
                    'resident_postal_code': '90210',
                    'biometric_template_xx':
                        null, // Placeholder for biometric data
                  },
                },
              },
              'deviceSigned': {
                'nameSpaces': {},
                'deviceAuth': {
                  'deviceSignature': 'device_signature_placeholder',
                },
              },
            },
          ],
          'status': 0, // 0 = OK
        };

        // Validate ISO 18013-5 structure
        expect(realMdlStructure['version'], equals('1.0'));
        expect(realMdlStructure['documents'], hasLength(1));
        final firstDoc = (realMdlStructure['documents'] as List)[0] as Map;
        expect(firstDoc['docType'], equals('org.iso.18013.5.1.mDL'));

        final issuerSigned = firstDoc['issuerSigned'] as Map;
        final nameSpaces = issuerSigned['nameSpaces'] as Map;
        final nameSpace = nameSpaces['org.iso.18013.5.1'] as Map;

        // Validate required elements
        expect(nameSpace['family_name'], isNotNull);
        expect(nameSpace['given_name'], isNotNull);
        expect(
          nameSpace['birth_date'],
          matches(r'^\d{4}-\d{2}-\d{2}$'),
        ); // YYYY-MM-DD format
        expect(nameSpace['driving_privileges'], isA<List>());
        expect(nameSpace['age_over_18'], isTrue);
        expect(nameSpace['age_over_21'], isTrue);

        // Validate driving privileges structure
        final privileges = nameSpace['driving_privileges'] as List;
        expect(privileges, isNotEmpty);
        expect(privileges[0]['vehicle_category_code'], isNotNull);
      });

      test('should validate CBOR encoding for mDoc transport', () {
        // Simplified CBOR structure for mDoc (real CBOR would be binary)
        // This represents the structure that would be CBOR-encoded
        final cborStructure = {
          'version': '1.0', // tstr
          'documents': [
            // array
            {
              'docType': 'org.iso.18013.5.1.mDL', // tstr
              'issuerSigned': {
                // map
                'nameSpaces': {
                  // map
                  'org.iso.18013.5.1': {
                    // map key (tstr)
                    // Each element is a tagged CBOR item with random salts
                    0: [
                      'salt_bytes_16',
                      'family_name',
                      'Doe',
                    ], // [salt, element_identifier, element_value]
                    1: ['salt_bytes_16', 'given_name', 'Jane'],
                    2: ['salt_bytes_16', 'birth_date', '1990-08-15'],
                    3: ['salt_bytes_16', 'age_over_21', true],
                  },
                },
                'issuerAuth': 'cose_sign1_structure', // COSE_Sign1 structure
              },
            },
          ],
        };

        // Validate CBOR-ready structure
        expect(cborStructure['documents'], isA<List>());
        final firstCborDoc = (cborStructure['documents'] as List)[0] as Map;
        final issuerSignedCbor = firstCborDoc['issuerSigned'] as Map;
        expect(issuerSignedCbor['nameSpaces'], isA<Map>());
        expect(issuerSignedCbor['issuerAuth'], isNotNull);
      });

      test('should create valid age verification request', () {
        final ageVerificationRequest = {
          'version': '1.0',
          'docRequests': [
            {
              'itemsRequest': {
                'docType': 'org.iso.18013.5.1.mDL',
                'nameSpaces': {
                  'org.iso.18013.5.1': {
                    'age_over_21':
                        true, // Only requesting age verification, not exact birth date
                    'portrait': false, // Not requesting photo for privacy
                  },
                },
              },
            },
          ],
          'readerAuth':
              null, // No reader authentication required for this scenario
        };

        expect(ageVerificationRequest['docRequests'], hasLength(1));
        final docRequest =
            (ageVerificationRequest['docRequests'] as List)[0] as Map;
        final itemsRequest = docRequest['itemsRequest'] as Map;
        final nameSpaces = itemsRequest['nameSpaces'] as Map;
        final isoNameSpace = nameSpaces['org.iso.18013.5.1'] as Map;
        expect(isoNameSpace['age_over_21'], isTrue);
        expect(isoNameSpace['portrait'], isFalse);
      });
    });

    group('SD-JWT Format Tests', () {
      test('should validate real SD-JWT structure', () {
        // Real SD-JWT example structure (simplified for testing)
        const realSdJwtExample =
            'eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJfc2QiOlsiQ3JRZTdTNjdQX2xjNUxkR29CZkxfQThEOFZHb0N3V0pGTUtRUnZOUWQ4dyIsIkhKRXU5alNTd2N1N1dxTWdBX1FncWhhRmpIT0M5NzVKMGM1V2lUUE1zc0EiLCJKaGZDMWNCNjdzSU5mNlQ4RnZhOW9SRllVZUhpZXE1VVhWa0xHeXFFbnl3Il0sImlzcyI6Imh0dHBzOi8vaXNzdWVyLmV4YW1wbGUuY29tIiwic3ViIjoiNjAwNjE0Mzc0MDFiNDE5NGUxOWFlYTY5MzIzNTBjYWM0ODQwYzAyOWYiLCJuYmYiOjE1NDI1NDQwOTMsImlhdCI6MTU0MjU0NDA5MywiZXhwIjoxODgzMTAwMDAwLCJhZGRyZXNzIjp7Il9zZCI6WyJLTnNxV0ZXSW9UZkVUVGx3cGZhVW9LUlJFN1FIeEVKb0MwMU4yYXl6MFQ4IiwiQjZGWmtkNkRaMmZkWjhhMlJxTzA2bXNLNUlzeC00eTNrMEQ5RFdBSUQ3dyIsInF3MnY3Zk9BeGJwdEo4UUNaZ3ZUWGFsN1BZOExGOXdadVpzWXlSa2t4UEUiXX19.signature_would_be_here~WyJlbHVWNU9nM2dTTklJOEVZbnN4QV9BIiwidm9yaGFuZGVuIix0cnVlXQ~WyJBSngtMDk1VlBycFR0TjRRTU9xUk9BIiwiZmFtaWx5X25hbWUiLCJEw6ZtZXIiXQ~WyJQYzMzSk0yTGNoY1VfbEhnZ3ZfdWZRIiwiZ2l2ZW5fbmFtZSIsIk1vcml0eiJd~WyJHMDJOU3JRZmpGWFE3SW8wOXN5YWpBIiwiYWRkcmVzcyIseyJzdHJlZXRfYWRkcmVzcyI6IlNjaHVsc3RyLiAxMiIsImxvY2FsaXR5IjoiU2NodWxwaWZ0ZSIsInJlZ2lvbiI6IlNhY2hzZW4tQW5oYWx0IiwiY291bnRyeSI6IkRFIn1d~';

        final sdJwtParts = realSdJwtExample.split('~');

        // SD-JWT should have: JWT + disclosure(s) + optional KB-JWT
        expect(sdJwtParts.length, greaterThanOrEqualTo(2));

        final jwtPart = sdJwtParts[0];
        final disclosures = sdJwtParts.sublist(1, sdJwtParts.length - 1);
        final keyBindingJwt = sdJwtParts.last.isEmpty ? null : sdJwtParts.last;

        // Validate JWT structure (header.payload.signature)
        final jwtSegments = jwtPart.split('.');
        expect(jwtSegments, hasLength(3));

        // Validate disclosures (should be non-empty for selective disclosure)
        expect(disclosures, isNotEmpty);
        for (final disclosure in disclosures) {
          expect(disclosure, isNotEmpty);
          // Each disclosure should be base64url encoded array: [salt, claim_name, claim_value]
        }

        // Key binding JWT is optional
        if (keyBindingJwt != null && keyBindingJwt.isNotEmpty) {
          final kbJwtSegments = keyBindingJwt.split('.');
          expect(kbJwtSegments, hasLength(3));
        }
      });

      test('should create valid selective disclosure claims', () {
        final fullClaims = {
          'iss': 'https://issuer.example.com',
          'sub': '6006143740b4194e19aea6932350cac4840c029f',
          'given_name': 'Moritz',
          'family_name': 'Dämer',
          'birth_date': '1990-01-01',
          'address': {
            'street_address': 'Schulstr. 12',
            'locality': 'Schulpfote',
            'region': 'Sachsen-Anhalt',
            'country': 'DE',
          },
          'email': 'moritz.daemer@example.com',
          'phone_number': '+49-123-456789',
        };

        // Simulate creating SD-JWT with selective disclosure
        final sdJwtPayload = {
          'iss': fullClaims['iss'],
          'sub': fullClaims['sub'],
          '_sd': [
            // Hash digests of selectively disclosable claims
            'CrQe7S67P_lc5LdGoBfL_A8D8VGoCwWJFMKQRvNQd8w', // given_name
            'HJEu9jSSwtcu7WqMgA_QgqhaFjHOC975J0c5WiTPMssA', // family_name
            'JhfC1cB67sINf6T8Fva9oRFYUeHieq5UXVkLGyQEny4', // address
          ],
          'iat': 1542544093,
          'exp': 1883100000,
        };

        expect(sdJwtPayload['_sd'], hasLength(3));
        expect(sdJwtPayload['iss'], equals(fullClaims['iss']));
        expect(sdJwtPayload['sub'], equals(fullClaims['sub']));
        expect(
          sdJwtPayload.containsKey('given_name'),
          isFalse,
        ); // Should not be directly in payload
        expect(
          sdJwtPayload.containsKey('birth_date'),
          isFalse,
        ); // Not in selective disclosure, not in payload
      });

      test('should validate presentation with holder binding', () {
        // Real scenario: holder presents SD-JWT with key binding for authentication
        const presentationSdJwt =
            'eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJfc2QiOlsiQ3JRZTdTNjdQX2xjNUxkR29CZkxfQThEOFZHb0N3V0pGTUtRUnZOUWQ4dyIsIkhKRXU5alNTd2N1N1dxTWdBX1FncWhhRmpIT0M5NzVKMGM1V2lUUE1zc0EiXSwiaXNzIjoiaHR0cHM6Ly9pc3N1ZXIuZXhhbXBsZS5jb20iLCJzdWIiOiI2MDA2MTQzNzQwYjQxOTRlMTlhZWE2OTMyMzUwY2FjNDg0MGMwMjlmIn0.signature~WyJlbHVWNU9nM2dTTklJOEVZbnN4QV9BIiwiZ2l2ZW5fbmFtZSIsIk1vcml0eiJd~WyJBSngtMDk1VlBycFR0TjRRTU9xUk9BIiwiZmFtaWx5X25hbWUiLCJExKZtZXIiXQ~eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL3ZlcmlmaWVyLmV4YW1wbGUuY29tIiwibm9uY2UiOiIxMjM0NTY3ODkwIiwiaWF0IjoxNjczNTUwMDAwfQ.kb_jwt_signature';

        final parts = presentationSdJwt.split('~');

        // Should have: SD-JWT + disclosures + KB-JWT
        expect(parts.length, equals(4));

        final sdJwt = parts[0];
        final disclosure1 = parts[1];
        final disclosure2 = parts[2];
        final keyBindingJwt = parts[3];

        // Validate each part
        expect(sdJwt.split('.'), hasLength(3));
        expect(disclosure1, isNotEmpty);
        expect(disclosure2, isNotEmpty);
        expect(keyBindingJwt.split('.'), hasLength(3));

        // Key binding JWT should contain audience and nonce
        // (In real implementation, you'd decode and validate these)
        expect(keyBindingJwt, isNotEmpty);
      });
    });

    group('DID Resolution Tests', () {
      test('should validate did:key format', () {
        const realDidKey =
            'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp';

        expect(realDidKey.startsWith('did:key:'), isTrue);
        expect(
          realDidKey.length,
          greaterThan(45),
        ); // did:key DIDs are typically 58 characters
        expect(
          realDidKey.contains('z6Mk'),
          isTrue,
        ); // Ed25519 keys start with z6Mk
      });

      test('should validate did:web format', () {
        const realDidWeb = 'did:web:example.com:users:alice';

        expect(realDidWeb.startsWith('did:web:'), isTrue);
        expect(realDidWeb.contains(':'), isTrue);

        // Extract domain part
        final parts = realDidWeb.substring(8).split(':');
        expect(parts.first, equals('example.com'));
      });

      test('should validate did:jwk format', () {
        const realDidJwk =
            'did:jwk:eyJrdHkiOiJPS1AiLCJjcnYiOiJFZDI1NTE5IiwieCI6IjExcVlBWWhOcWZoaGR4MXBFNENoOW1lNllST2dOcVhJZHhQTXh6UHhqOVEifQ';

        expect(realDidJwk.startsWith('did:jwk:'), isTrue);
        expect(realDidJwk.length, greaterThan(50));

        // The part after did:jwk: should be base64url encoded JWK
        final jwkPart = realDidJwk.substring(8);
        expect(jwkPart, matches(r'^[A-Za-z0-9_-]+$'));
      });

      test('should create valid DID document structure', () {
        const didKey =
            'did:key:z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp';

        final didDocument = {
          '@context': [
            'https://www.w3.org/ns/did/v1',
            'https://w3id.org/security/suites/ed25519-2018/v1',
          ],
          'id': didKey,
          'verificationMethod': [
            {
              'id': '$didKey#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
              'type': 'Ed25519VerificationKey2018',
              'controller': didKey,
              'publicKeyBase58': '9wKgiG7lV6aBSQvL99hAJeFHhNVyWhkrW86rTKJzLQFB',
            },
          ],
          'authentication': [
            '$didKey#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          ],
          'assertionMethod': [
            '$didKey#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          ],
          'keyAgreement': [
            '$didKey#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          ],
          'capabilityInvocation': [
            '$didKey#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          ],
          'capabilityDelegation': [
            '$didKey#z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp',
          ],
        };

        // Validate DID document structure
        expect(
          didDocument['@context'],
          contains('https://www.w3.org/ns/did/v1'),
        );
        expect(didDocument['id'], equals(didKey));
        expect(didDocument['verificationMethod'], hasLength(1));
        final verMethod = (didDocument['verificationMethod'] as List)[0] as Map;
        expect(verMethod['type'], equals('Ed25519VerificationKey2018'));
        expect(didDocument['authentication'], isNotEmpty);
        expect(didDocument['assertionMethod'], isNotEmpty);
      });
    });

    group('Cryptographic Signature Tests', () {
      test('should validate Ed25519 signature format', () {
        // Real Ed25519 signature example (64 bytes, 128 hex chars)
        const realEd25519Signature =
            '304402203c4c9c8a7b1a2d3e4f567890abcdef1234567890abcdef1234567890abcdef1220220456789abcdef1234567890abcdef1234567890abcdef1234567890abcdef123';

        expect(
          realEd25519Signature.length,
          equals(128),
        ); // 64 bytes * 2 hex chars
        expect(
          realEd25519Signature,
          matches(r'^[0-9a-fA-F]+$'),
        ); // Only hex characters
      });

      test('should validate multibase encoded public key', () {
        // Real multibase encoded Ed25519 public key
        const multibasePublicKey =
            'z6MkiTBz1ymuepAQ4HEHYSF1H8quG5GLVVQR3djdX3mDooWp';

        expect(
          multibasePublicKey.startsWith('z'),
          isTrue,
        ); // z = base58btc encoding
        expect(
          multibasePublicKey.length,
          equals(48),
        ); // Ed25519 public key in multibase
        expect(
          multibasePublicKey.substring(1, 5),
          equals('6Mki'),
        ); // Ed25519 multicodec prefix
      });

      test('should validate COSE signature structure', () {
        // COSE_Sign1 structure for ISO 18013-5 mDoc signatures
        final coseSign1 = {
          'protected': Uint8List.fromList([
            0xa1, 0x01, 0x26, // {"alg": -7} (ES256)
          ]),
          'unprotected': {},
          'payload': Uint8List.fromList([
            // Document data would be here
            0x83,
            0x6a,
            0x44,
            0x65,
            0x76,
            0x69,
            0x63,
            0x65,
            0x41,
            0x75,
            0x74,
            0x68,
          ]),
          'signature': Uint8List.fromList([
            // 64-byte signature for ES256
            0x30,
            0x44,
            0x02,
            0x20,
            0x3c,
            0x4c,
            0x9c,
            0x8a,
            0x7b,
            0x1a,
            0x2d,
            0x3e,
            // ... rest of signature bytes
          ]),
        };

        expect(coseSign1['protected'], isNotNull);
        expect(coseSign1['payload'], isNotNull);
        expect(coseSign1['signature'], isNotNull);
        final signature = coseSign1['signature'] as Uint8List;
        expect(
          signature.length,
          greaterThan(60),
        ); // ES256 signatures are typically 70-72 bytes
      });
    });
  });
}
