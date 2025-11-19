/// Comprehensive fixtures for SpruceID credentials
/// Provides factory methods for all credential types in various states
library;

import 'dart:convert';

/// Enum for credential states
enum CredentialState {
  valid,
  expiredRecently, // Within 7 days
  expired30Days, // Within 30 days
  nearExpiry, // Expires within 7 days
  revoked,
  missingOptionalFields,
  malformed,
}

/// Base class for state transitions
class CredentialStateTransition {
  final DateTime transitionTime;
  final CredentialState fromState;
  final CredentialState toState;
  final String reason;

  CredentialStateTransition({
    required this.transitionTime,
    required this.fromState,
    required this.toState,
    required this.reason,
  });
}

/// Helper to calculate dates based on credential state
class CredentialDateHelper {
  static DateTime getIssuanceDate(CredentialState state) {
    final now = DateTime.now();
    switch (state) {
      case CredentialState.valid:
        return now.subtract(const Duration(days: 30));
      case CredentialState.expiredRecently:
        return now.subtract(const Duration(days: 370)); // Expired 5 days ago
      case CredentialState.expired30Days:
        return now.subtract(const Duration(days: 395)); // Expired 30 days ago
      case CredentialState.nearExpiry:
        return now.subtract(const Duration(days: 358)); // Expires in 5 days
      case CredentialState.revoked:
        return now.subtract(const Duration(days: 60));
      case CredentialState.missingOptionalFields:
      case CredentialState.malformed:
        return now.subtract(const Duration(days: 30));
    }
  }

  static DateTime? getExpirationDate(CredentialState state) {
    final now = DateTime.now();
    switch (state) {
      case CredentialState.valid:
        return now.add(const Duration(days: 335)); // Valid for ~1 year
      case CredentialState.expiredRecently:
        return now.subtract(const Duration(days: 5));
      case CredentialState.expired30Days:
        return now.subtract(const Duration(days: 30));
      case CredentialState.nearExpiry:
        return now.add(const Duration(days: 5));
      case CredentialState.revoked:
        return now.add(const Duration(days: 275)); // Would be valid but revoked
      case CredentialState.missingOptionalFields:
        return now.add(const Duration(days: 335));
      case CredentialState.malformed:
        return null; // Malformed might have invalid date
    }
  }
}

/// Factory for W3C Verifiable Credentials
class W3CCredentialFixtures {
  /// University Degree Credential
  static Map<String, dynamic> universityDegree({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    final credential = {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
        'https://www.w3.org/2018/credentials/examples/v1',
      ],
      'id': 'urn:uuid:3978344f-8596-4c3a-a978-8fcaba3903c5',
      'type': ['VerifiableCredential', 'UniversityDegreeCredential'],
      'issuer': {
        'id': 'did:web:university.edu',
        'name': 'Example University',
      },
      'issuanceDate': issuanceDate.toIso8601String(),
      if (expirationDate != null)
        'expirationDate': expirationDate.toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        'name': 'Alice Johnson',
        'givenName': 'Alice',
        'familyName': 'Johnson',
        'degree': {
          'type': 'BachelorDegree',
          'name': 'Bachelor of Science in Computer Science',
        },
        'gpa': '3.8',
        'graduationDate': '2023-05-15',
      },
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': issuanceDate.toIso8601String(),
        'verificationMethod': 'did:web:university.edu#key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': 'z58DAdFfa9SkqZMVPxAQpic7ndSayn1PzZs6ZjWp1CktyGesjuTSwRdoWhAfGFCF5bppETSTojQCrfFPP2oumHKtz',
      },
    };

    if (state == CredentialState.revoked) {
      credential['credentialStatus'] = {
        'id': 'https://university.edu/credentials/status/3#94567',
        'type': 'RevocationList2020Status',
        'revocationListIndex': '94567',
        'revocationListCredential': 'https://university.edu/credentials/status/3',
      };
    }

    if (state == CredentialState.missingOptionalFields) {
      (credential['credentialSubject'] as Map).remove('gpa');
      (credential['credentialSubject'] as Map).remove('graduationDate');
    }

    if (state == CredentialState.malformed) {
      credential.remove('proof');
      credential['expirationDate'] = 'invalid-date';
    }

    return credential;
  }

  /// Driver License Credential
  static Map<String, dynamic> driverLicense({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
        'https://w3id.org/citizenship/v1',
      ],
      'id': 'urn:uuid:license-001',
      'type': ['VerifiableCredential', 'DriverLicenseCredential'],
      'issuer': {
        'id': 'did:web:dmv.state.gov',
        'name': 'State Department of Motor Vehicles',
      },
      'issuanceDate': issuanceDate.toIso8601String(),
      if (expirationDate != null)
        'expirationDate': expirationDate.toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        'name': 'Bob Smith',
        'birthDate': '1985-03-21',
        'licenseNumber': 'DL-123456789',
        'class': 'C',
        'restrictions': 'CORRECTIVE LENSES',
        'endorsements': [],
        if (state != CredentialState.missingOptionalFields)
          'portrait': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      },
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': issuanceDate.toIso8601String(),
        'verificationMethod': 'did:web:dmv.state.gov#key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': 'z3hBWwmeoDDW8CvQqEKwPSWJSUXDUqTXHYJVyM3vRjqAK5dLvPxwR8LFdRXBpvqzE4HGC',
      },
    };
  }

  /// Identity Credential
  static Map<String, dynamic> identity({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
      ],
      'id': 'urn:uuid:identity-001',
      'type': ['VerifiableCredential', 'IdentityCredential'],
      'issuer': {
        'id': 'did:web:government.example',
        'name': 'National Identity Authority',
      },
      'issuanceDate': issuanceDate.toIso8601String(),
      if (expirationDate != null)
        'expirationDate': expirationDate.toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        'givenName': 'Carol',
        'familyName': 'Williams',
        'birthDate': '1992-07-14',
        'nationality': 'US',
        'idNumber': 'ID-987654321',
      },
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': issuanceDate.toIso8601String(),
        'verificationMethod': 'did:web:government.example#key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': 'z2F9pqBG4HmeRjZmQvZkC3DqPxwR8LFdRXBpvqzE4HGCK5dLvPxwR8LFdRXBpvqzE4HGC',
      },
    };
  }

  /// Professional Certificate Credential
  static Map<String, dynamic> certificate({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
      ],
      'id': 'urn:uuid:cert-001',
      'type': ['VerifiableCredential', 'CertificateCredential'],
      'issuer': {
        'id': 'did:web:certification-body.org',
        'name': 'Professional Certification Board',
      },
      'issuanceDate': issuanceDate.toIso8601String(),
      if (expirationDate != null)
        'expirationDate': expirationDate.toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        'name': 'David Brown',
        'certification': 'Certified Information Systems Security Professional',
        'certificationNumber': 'CISSP-123456',
        'specialization': 'Cloud Security',
      },
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': issuanceDate.toIso8601String(),
        'verificationMethod': 'did:web:certification-body.org#key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': 'z3mBWwmeoDDW8CvQqEKwPSWJSUXDUqTXHYJVyM3vRjqAK5dLvPxwR8LFdRXBpvqzE4HGC',
      },
    };
  }

  /// Membership Credential
  static Map<String, dynamic> membership({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
      ],
      'id': 'urn:uuid:member-001',
      'type': ['VerifiableCredential', 'MembershipCredential'],
      'issuer': {
        'id': 'did:web:professional-association.org',
        'name': 'Tech Professional Association',
      },
      'issuanceDate': issuanceDate.toIso8601String(),
      if (expirationDate != null)
        'expirationDate': expirationDate.toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        'name': 'Eve Martinez',
        'membershipType': 'Professional',
        'memberNumber': 'TPA-789012',
        'memberSince': '2020-01-15',
      },
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': issuanceDate.toIso8601String(),
        'verificationMethod': 'did:web:professional-association.org#key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': 'z4nCXxnfPEEX9DwRrFLhSXKJTVZMN4IKLMpccOTRskBL6eMwQyS9MWhBgGEDG6cG6brrFUUVpkRDsgUTTqPppKLuz',
      },
    };
  }

  /// Employment Credential
  static Map<String, dynamic> employment({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
      ],
      'id': 'urn:uuid:emp-001',
      'type': ['VerifiableCredential', 'EmploymentCredential'],
      'issuer': {
        'id': 'did:web:techcorp.example',
        'name': 'Tech Corporation Inc.',
      },
      'issuanceDate': issuanceDate.toIso8601String(),
      if (expirationDate != null)
        'expirationDate': expirationDate.toIso8601String(),
      'credentialSubject': {
        'id': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
        'name': 'Frank Anderson',
        'jobTitle': 'Senior Software Engineer',
        'department': 'Engineering',
        'employeeId': 'EMP-456789',
        'startDate': '2021-03-01',
      },
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': issuanceDate.toIso8601String(),
        'verificationMethod': 'did:web:techcorp.example#key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': 'z5oDYyofQFFY0ExSsGMiTYLKUWaNO5JLMNqddPUSltCM7fNxRzT0NXiChHFEH7dH7cssGVVWqlSEthVUUqQrrLMv',
      },
    };
  }

  /// Get all W3C credential types
  static List<Map<String, dynamic>> allTypes({
    CredentialState state = CredentialState.valid,
  }) {
    return [
      universityDegree(state: state),
      driverLicense(state: state),
      identity(state: state),
      certificate(state: state),
      membership(state: state),
      employment(state: state),
    ];
  }
}

/// Continuing in next message due to length...

/// Factory for mDoc (ISO 18013-5) credentials
class MDocFixtures {
  /// Mobile Driver License (mDL)
  static Map<String, dynamic> mobileDriverLicense({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      'docType': 'org.iso.18013.5.1.mDL',
      'issuerSigned': {
        'nameSpaces': {
          'org.iso.18013.5.1': {
            'family_name': 'Smith',
            'given_name': 'Robert',
            'birth_date': '1985-03-21',
            'issue_date': issuanceDate.toIso8601String().split('T')[0],
            if (expirationDate != null)
              'expiry_date': expirationDate.toIso8601String().split('T')[0],
            'issuing_country': 'US',
            'issuing_authority': 'State DMV',
            'document_number': 'DL123456789',
            'driving_privileges': [
              {
                'vehicle_category_code': 'C',
                'issue_date': issuanceDate.toIso8601String().split('T')[0],
                if (expirationDate != null)
                  'expiry_date': expirationDate.toIso8601String().split('T')[0],
              }
            ],
            if (state != CredentialState.missingOptionalFields)
              'portrait': base64Encode([0, 0, 0, 1]), // Minimal valid image
            'signature_usual_mark': base64Encode([0, 0, 0, 1]),
          }
        },
        'issuerAuth': {
          'protected': base64Encode(utf8.encode('{"alg":"ES256"}')),
          'payload': base64Encode(utf8.encode('{}')),
          'signature': base64Encode(List.generate(64, (i) => i % 256)),
        }
      },
      'deviceSigned': {
        'nameSpaces': {},
        'deviceAuth': {
          'deviceSignature': {
            'protected': base64Encode(utf8.encode('{"alg":"ES256"}')),
            'payload': base64Encode(utf8.encode('{}')),
            'signature': base64Encode(List.generate(64, (i) => i % 256)),
          }
        }
      }
    };
  }

  /// Mobile ID (mID)
  static Map<String, dynamic> mobileId({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      'docType': 'org.iso.18013.5.1.mID',
      'issuerSigned': {
        'nameSpaces': {
          'org.iso.18013.5.1': {
            'family_name': 'Williams',
            'given_name': 'Carol',
            'birth_date': '1992-07-14',
            'issue_date': issuanceDate.toIso8601String().split('T')[0],
            if (expirationDate != null)
              'expiry_date': expirationDate.toIso8601String().split('T')[0],
            'issuing_country': 'US',
            'issuing_authority': 'National Identity Authority',
            'document_number': 'ID987654321',
            'nationality': 'US',
            if (state != CredentialState.missingOptionalFields)
              'portrait': base64Encode([0, 0, 0, 1]),
            'sex': 'F',
          }
        },
        'issuerAuth': {
          'protected': base64Encode(utf8.encode('{"alg":"ES256"}')),
          'payload': base64Encode(utf8.encode('{}')),
          'signature': base64Encode(List.generate(64, (i) => i % 256)),
        }
      },
      'deviceSigned': {
        'nameSpaces': {},
        'deviceAuth': {
          'deviceSignature': {
            'protected': base64Encode(utf8.encode('{"alg":"ES256"}')),
            'payload': base64Encode(utf8.encode('{}')),
            'signature': base64Encode(List.generate(64, (i) => i % 256)),
          }
        }
      }
    };
  }

  /// Mobile Passport (mPassport)
  static Map<String, dynamic> mobilePassport({
    CredentialState state = CredentialState.valid,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    return {
      'docType': 'org.icao.mrtd.passport',
      'issuerSigned': {
        'nameSpaces': {
          'org.icao.mrtd': {
            'family_name': 'JOHNSON',
            'given_name': 'ALICE',
            'birth_date': '1990-05-15',
            'issue_date': issuanceDate.toIso8601String().split('T')[0],
            if (expirationDate != null)
              'expiry_date': expirationDate.toIso8601String().split('T')[0],
            'issuing_country': 'USA',
            'issuing_authority': 'U.S. Department of State',
            'document_number': 'P12345678',
            'nationality': 'USA',
            'sex': 'F',
            if (state != CredentialState.missingOptionalFields)
              'portrait': base64Encode([0, 0, 0, 1]),
            'machine_readable_zone': 'P<USAJOHNSON<<ALICE<<<<<<<<<<<<<<<<<<<<<<<\nP1234567890USA9005155F2512314<<<<<<<<<<<<<<06',
          }
        },
        'issuerAuth': {
          'protected': base64Encode(utf8.encode('{"alg":"ES256"}')),
          'payload': base64Encode(utf8.encode('{}')),
          'signature': base64Encode(List.generate(64, (i) => i % 256)),
        }
      },
      'deviceSigned': {
        'nameSpaces': {},
        'deviceAuth': {
          'deviceSignature': {
            'protected': base64Encode(utf8.encode('{"alg":"ES256"}')),
            'payload': base64Encode(utf8.encode('{}')),
            'signature': base64Encode(List.generate(64, (i) => i % 256)),
          }
        }
      }
    };
  }

  /// Get all mDoc credential types
  static List<Map<String, dynamic>> allTypes({
    CredentialState state = CredentialState.valid,
  }) {
    return [
      mobileDriverLicense(state: state),
      mobileId(state: state),
      mobilePassport(state: state),
    ];
  }
}

/// Factory for SD-JWT (Selective Disclosure JWT) credentials
class SdJwtFixtures {
  /// Generic SD-JWT credential with selective disclosure
  static String credential({
    CredentialState state = CredentialState.valid,
    required String credentialType,
  }) {
    final issuanceDate = CredentialDateHelper.getIssuanceDate(state);
    final expirationDate = CredentialDateHelper.getExpirationDate(state);

    // JWT Header
    final header = {
      'alg': 'ES256',
      'typ': 'vc+sd-jwt',
      'kid': 'issuer-key-1',
    };

    // JWT Payload
    final payload = {
      'iss': 'https://issuer.example.com',
      'sub': 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
      'iat': (issuanceDate.millisecondsSinceEpoch / 1000).floor(),
      if (expirationDate != null)
        'exp': (expirationDate.millisecondsSinceEpoch / 1000).floor(),
      'vct': credentialType,
      '_sd': [
        // Selective disclosure hashes (in real implementation these would be actual hashes)
        'WyJzYWx0MSIsICJnaXZlbl9uYW1lIiwgIkpvaG4iXQ',
        'WyJzYWx0MiIsICJmYW1pbHlfbmFtZSIsICJEb2UiXQ',
        'WyJzYWx0MyIsICJlbWFpbCIsICJqb2huLmRvZUBleGFtcGxlLmNvbSJd',
      ],
      '_sd_alg': 'sha-256',
    };

    // Create JWT (simplified - not cryptographically valid)
    final headerEncoded = base64Encode(utf8.encode(jsonEncode(header)))
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
    final payloadEncoded = base64Encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
    final signature = base64Encode(List.generate(64, (i) => i % 256))
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');

    final jwt = '$headerEncoded.$payloadEncoded.$signature';

    // Disclosures (actual claim values)
    final disclosures = [
      'WyJzYWx0MSIsICJnaXZlbl9uYW1lIiwgIkpvaG4iXQ', // given_name: John
      'WyJzYWx0MiIsICJmYW1pbHlfbmFtZSIsICJEb2UiXQ', // family_name: Doe
      if (state != CredentialState.missingOptionalFields)
        'WyJzYWx0MyIsICJlbWFpbCIsICJqb2huLmRvZUBleGFtcGxlLmNvbSJd', // email
    ];

    // Key Binding JWT (holder binding)
    final kbJwt = 'eyJhbGciOiJFUzI1NiIsInR5cCI6ImtiK2p3dCJ9.eyJub25jZSI6IjEyMzQ1Njc4OTAiLCJhdWQiOiJodHRwczovL3ZlcmlmaWVyLmV4YW1wbGUuY29tIiwiaWF0IjoxNjc4ODg2NDAwfQ.signature';

    // SD-JWT format: <Issuer-signed JWT>~<Disclosure 1>~<Disclosure 2>~...~<KB-JWT>
    return '$jwt~${disclosures.join('~')}~$kbJwt';
  }

  /// University degree as SD-JWT
  static String universityDegree({
    CredentialState state = CredentialState.valid,
  }) {
    return credential(
      state: state,
      credentialType: 'https://credentials.example.com/university-degree',
    );
  }

  /// Identity credential as SD-JWT
  static String identity({
    CredentialState state = CredentialState.valid,
  }) {
    return credential(
      state: state,
      credentialType: 'https://credentials.example.com/identity',
    );
  }

  /// Professional certificate as SD-JWT
  static String certificate({
    CredentialState state = CredentialState.valid,
  }) {
    return credential(
      state: state,
      credentialType: 'https://credentials.example.com/professional-certificate',
    );
  }

  /// Get all SD-JWT credential types
  static List<String> allTypes({
    CredentialState state = CredentialState.valid,
  }) {
    return [
      universityDegree(state: state),
      identity(state: state),
      certificate(state: state),
    ];
  }
}

/// Master fixture class combining all credential types
class SpruceCredentialFixtures {
  /// Get all credentials across all formats in a specific state
  static Map<String, dynamic> allCredentials({
    CredentialState state = CredentialState.valid,
  }) {
    return {
      'w3c': W3CCredentialFixtures.allTypes(state: state),
      'mdoc': MDocFixtures.allTypes(state: state),
      'sdJwt': SdJwtFixtures.allTypes(state: state),
    };
  }

  /// Get a diverse set of credentials for UI testing (mix of types and states)
  static Map<String, dynamic> diverseSet() {
    return {
      'valid': {
        'w3c': [
          W3CCredentialFixtures.universityDegree(state: CredentialState.valid),
          W3CCredentialFixtures.driverLicense(state: CredentialState.valid),
        ],
        'mdoc': [
          MDocFixtures.mobileId(state: CredentialState.valid),
        ],
        'sdJwt': [
          SdJwtFixtures.identity(state: CredentialState.valid),
        ],
      },
      'nearExpiry': {
        'w3c': [
          W3CCredentialFixtures.certificate(state: CredentialState.nearExpiry),
        ],
        'mdoc': [
          MDocFixtures.mobileDriverLicense(state: CredentialState.nearExpiry),
        ],
      },
      'expired': {
        'w3c': [
          W3CCredentialFixtures.membership(state: CredentialState.expiredRecently),
        ],
      },
      'revoked': {
        'w3c': [
          W3CCredentialFixtures.employment(state: CredentialState.revoked),
        ],
      },
    };
  }

  /// Create a credential state transition scenario
  static CredentialStateTransition createTransition({
    required CredentialState fromState,
    required CredentialState toState,
    String? reason,
  }) {
    return CredentialStateTransition(
      transitionTime: DateTime.now(),
      fromState: fromState,
      toState: toState,
      reason: reason ?? 'Simulated state transition for testing',
    );
  }
}
