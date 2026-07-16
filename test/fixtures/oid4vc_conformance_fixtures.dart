/// OID4VCI / OID4VP conformance test fixture constants.
///
/// All strings here are copies of the files in:
///   marty-integration-tests/tests/integration/fixtures/conformance/
///
/// Consumed by:
///   - test/integration/oid4vci_conformance_test.dart
///   - test/integration/oid4vp_conformance_test.dart
///
/// Run `generate_fixtures.py` to regenerate the source files if anything drifts.
library;

// ── Issuer Metadata ───────────────────────────────────────────────────────────

/// OID4VCI 1.0 Final §12.2.2 — minimal conformant issuer metadata.
/// Format: `dc+sd-jwt` (Final spec name).
const String kIssuerMetadataJson = r'''
{
  "credential_issuer": "https://issuer.example.com",
  "credential_endpoint": "https://issuer.example.com/credential",
  "nonce_endpoint": "https://issuer.example.com/nonce",
  "deferred_credential_endpoint": "https://issuer.example.com/deferred",
  "notification_endpoint": "https://issuer.example.com/notification",
  "authorization_servers": ["https://issuer.example.com"],
  "display": [{"name": "Conformance Test Issuer", "locale": "en-US"}],
  "credential_configurations_supported": {
    "UniversityDegree_jwt_vc_json": {
      "format": "jwt_vc_json",
      "scope": "UniversityDegree",
      "cryptographic_binding_methods_supported": ["did:key", "did:web"],
      "credential_signing_alg_values_supported": ["EdDSA", "ES256"],
      "display": [{"name": "University Degree", "locale": "en-US"}],
      "credential_definition": {
        "type": ["VerifiableCredential", "UniversityDegreeCredential"],
        "credentialSubject": {
          "given_name": {"display": [{"name": "Given Name", "locale": "en-US"}]},
          "family_name": {"display": [{"name": "Family Name", "locale": "en-US"}]},
          "degree": {"display": [{"name": "Degree", "locale": "en-US"}]}
        }
      }
    },
    "UniversityDegree_dc_sd_jwt": {
      "format": "dc+sd-jwt",
      "vct": "https://credentials.example.com/university_degree",
      "scope": "UniversityDegree_sd_jwt",
      "cryptographic_binding_methods_supported": ["did:key"],
      "credential_signing_alg_values_supported": ["EdDSA"],
      "display": [{"name": "University Degree (SD-JWT)", "locale": "en-US"}],
      "claims": {
        "given_name": {"display": [{"name": "Given Name", "locale": "en-US"}]},
        "family_name": {"display": [{"name": "Family Name", "locale": "en-US"}]}
      }
    }
  }
}
''';

/// OID4VCI draft-era issuer metadata: uses `vc+sd-jwt` instead of `dc+sd-jwt`.
const String kIssuerMetadataLegacyJson = r'''
{
  "credential_issuer": "https://issuer.example.com",
  "credential_endpoint": "https://issuer.example.com/credential",
  "authorization_servers": ["https://issuer.example.com"],
  "display": [{"name": "Conformance Test Issuer", "locale": "en-US"}],
  "credential_configurations_supported": {
    "UniversityDegree_jwt_vc_json": {
      "format": "jwt_vc_json",
      "scope": "UniversityDegree",
      "cryptographic_binding_methods_supported": ["did:key", "did:web"],
      "credential_signing_alg_values_supported": ["EdDSA", "ES256"],
      "display": [{"name": "University Degree", "locale": "en-US"}],
      "credential_definition": {
        "type": ["VerifiableCredential", "UniversityDegreeCredential"],
        "credentialSubject": {
          "given_name": {"display": [{"name": "Given Name", "locale": "en-US"}]},
          "family_name": {"display": [{"name": "Family Name", "locale": "en-US"}]},
          "degree": {"display": [{"name": "Degree", "locale": "en-US"}]}
        }
      }
    },
    "UniversityDegree_vc_sd_jwt": {
      "format": "vc+sd-jwt",
      "vct": "https://credentials.example.com/university_degree",
      "scope": "UniversityDegree_sd_jwt",
      "cryptographic_binding_methods_supported": ["did:key"],
      "credential_signing_alg_values_supported": ["EdDSA"],
      "display": [{"name": "University Degree (SD-JWT)", "locale": "en-US"}]
    }
  }
}
''';

// ── OAuth AS Metadata ─────────────────────────────────────────────────────────

/// RFC 8414 OAuth Authorization Server metadata.
const String kOAuthAsMetadataJson = r'''
{
  "issuer": "https://issuer.example.com",
  "token_endpoint": "https://issuer.example.com/token",
  "grant_types_supported": [
    "urn:ietf:params:oauth:grant-type:pre-authorized_code",
    "authorization_code"
  ],
  "token_endpoint_auth_methods_supported": ["none"],
  "code_challenge_methods_supported": ["S256"],
  "pre-authorized_grant_anonymous_access_supported": true
}
''';

// ── Credential Offers ─────────────────────────────────────────────────────────

/// OID4VCI §11 — pre-authorized code offer with tx_code requirement.
const String kCredentialOfferPreAuthJson = r'''
{
  "credential_issuer": "https://issuer.example.com",
  "credential_configuration_ids": ["UniversityDegree_jwt_vc_json"],
  "grants": {
    "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
      "pre-authorized_code": "SplxlOBeZQQYbYS6WxSbIA",
      "tx_code": {
        "length": 6,
        "input_mode": "numeric",
        "description": "Please enter the PIN sent to your email."
      }
    }
  }
}
''';

/// OID4VCI §11.3 — offer by reference: contains a URI to fetch the actual offer.
const String kCredentialOfferByRefJson = r'''
{
  "credential_offer_uri": "https://issuer.example.com/offers/abc123"
}
''';

// ── Token & Nonce Responses ───────────────────────────────────────────────────

/// OID4VCI Final token endpoint response. Proof nonces are separate.
const String kTokenResponseJson = r'''
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.dGVzdA.dGVzdA",
  "token_type": "Bearer",
  "expires_in": 86400
}
''';

/// OID4VCI 1.0 Final §7.2 — nonce endpoint response.
const String kNonceResponseJson = r'''
{
  "c_nonce": "fGFF7UkhLa"
}
''';

// ── Credential Responses ──────────────────────────────────────────────────────

/// OID4VCI §8 — JWT-VC credential response (Final: `credentials` array).
const String kCredentialResponseJwtVcJson = r'''
{
  "format": "jwt_vc_json",
  "credentials": [
    "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkaWQ6a2V5Ono2TWtpc3N1ZXIiLCJzdWIiOiJkaWQ6a2V5Ono2TWtob2xkZXIiLCJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiVW5pdmVyc2l0eURlZ3JlZUNyZWRlbnRpYWwiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiZ2l2ZW5fbmFtZSI6IkNvbmZvcm1hbmNlIiwiZmFtaWx5X25hbWUiOiJUZXN0IiwiZGVncmVlIjoiQlNjIENvbXB1dGVyIFNjaWVuY2UifX19.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  ]
}
''';

/// OID4VCI §8 — SD-JWT VC credential response.
const String kCredentialResponseSdJwtJson = r'''
{
  "format": "dc+sd-jwt",
  "credentials": [
    "eyJhbGciOiJFZERTQSIsInR5cCI6InZjK3NkLWp3dCJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInZjdCI6Imh0dHBzOi8vY3JlZGVudGlhbHMuZXhhbXBsZS5jb20vdW5pdmVyc2l0eV9kZWdyZWUiLCJfc2RfYWxnIjoic2hhLTI1NiIsIl9zZCI6WyJBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQSJdfQ.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  ]
}
''';

/// OID4VCI §8 — mDoc credential response (base64url-encoded CBOR).
const String kCredentialResponseMdocJson = r'''
{
  "format": "mso_mdoc",
  "credentials": ["oQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
}
''';

// ── OID4VP — Presentation Flow ────────────────────────────────────────────────

/// OID4VP 1.0 Final §5/§6 — default authorization request with embedded DCQL.
const String kPresentationRequestJson = r'''
{
  "response_type": "vp_token",
  "client_id": "https://verifier.example.com",
  "client_id_scheme": "entity_id",
  "nonce": "n-0S6_WzA2Mj",
  "response_mode": "direct_post",
  "response_uri": "https://verifier.example.com/callback",
  "state": "test-state-abc",
  "dcql_query": {
    "credentials": [
      {
        "id": "university_degree",
        "format": "jwt_vc_json",
        "meta": {
          "type_values": [["VerifiableCredential", "UniversityDegreeCredential"]]
        },
        "claims": [
          {
            "id": "claim_degree",
            "path": ["degree"]
          }
        ]
      }
    ]
  }
}
''';

/// Legacy PE-shaped authorization request retained for compatibility coverage.
const String kLegacyPresentationRequestJson = r'''
{
  "response_type": "vp_token",
  "client_id": "https://verifier.example.com",
  "client_id_scheme": "entity_id",
  "nonce": "n-0S6_WzA2Mj",
  "response_mode": "direct_post",
  "response_uri": "https://verifier.example.com/callback",
  "state": "test-state-abc",
  "presentation_definition": {
    "id": "pd-conformance-test",
    "name": "OID4VP Conformance Test",
    "purpose": "Verify University Degree for conformance testing",
    "input_descriptors": [
      {
        "id": "university_degree",
        "name": "University Degree Credential",
        "purpose": "We need your degree credential",
        "constraints": {
          "fields": [
            {
              "path": ["$.vc.type", "$.type"],
              "filter": {
                "type": "array",
                "contains": {"const": "UniversityDegreeCredential"}
              }
            }
          ]
        }
      }
    ]
  }
}
''';

/// DIF Presentation Exchange v2 presentation definition (standalone).
const String kPresentationDefinitionJson = r'''
{
  "id": "pd-conformance-test",
  "name": "OID4VP Conformance Test",
  "purpose": "Verify University Degree for conformance testing",
  "input_descriptors": [
    {
      "id": "university_degree",
      "name": "University Degree Credential",
      "purpose": "We need your degree credential",
      "constraints": {
        "fields": [
          {
            "path": ["$.vc.type", "$.type"],
            "filter": {
              "type": "array",
              "contains": {"const": "UniversityDegreeCredential"}
            }
          }
        ]
      }
    }
  ]
}
''';

/// DIF PE v2 presentation submission matching kPresentationDefinitionJson.
const String kPresentationSubmissionJson = r'''
{
  "id": "ps-conformance-test",
  "definition_id": "pd-conformance-test",
  "descriptor_map": [
    {
      "id": "university_degree",
      "format": "jwt_vp",
      "path": "$",
      "path_nested": {
        "id": "university_degree",
        "format": "jwt_vc",
        "path": "$.vp.verifiableCredential[0]"
      }
    }
  ]
}
''';

// ── Shared test constants ─────────────────────────────────────────────────────

/// Verifier identifier — matches `VERIFIER_ID` in generate_fixtures.py and
/// the Rust test constant.
const String kVerifierId = 'https://verifier.example.com';

/// Nonce embedded in kPresentationRequestJson and the vp_token_jwt.txt fixture.
const String kNonce = 'n-0S6_WzA2Mj';

/// Holder DID derived from HOLDER_KEY_SEED (bytes 0x01..0x20).
const String kHolderDid =
    'did:key:z6MkneMkZqwqRiU5mJzSG3kDwzt9P8C59N4NGTfBLfSGE7c7';

/// Issuer base URL.
const String kIssuerUrl = 'https://issuer.example.com';

/// Token endpoint URL.
const String kTokenEndpoint = 'https://issuer.example.com/token';

/// Credential endpoint URL.
const String kCredentialEndpoint = 'https://issuer.example.com/credential';

/// Nonce endpoint URL (OID4VCI 1.0 Final §7).
const String kNonceEndpoint = 'https://issuer.example.com/nonce';

/// Verifier response / callback URI.
const String kResponseUri = 'https://verifier.example.com/callback';

/// Pre-authorized code used in kCredentialOfferPreAuthJson.
const String kPreAuthCode = 'SplxlOBeZQQYbYS6WxSbIA';

/// Access token from kTokenResponseJson.
const String kAccessToken =
    'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.dGVzdA.dGVzdA';

/// c_nonce from kTokenResponseJson.
const String kCNonce = 'tZignsnFbp';
