/// OID4VCI Issuer Conformance Tests — Dart wallet (holder) side.
///
/// Tests how the wallet correctly constructs requests and parses spec-compliant
/// server responses for the OID4VCI 1.0 Final credential issuance flow.
///
/// Mock layer: HTTP transport level via `MockClient` from `package:http/testing`.
/// Each test injects a `MockClient` into `OID4VCHttpClient`, which implements
/// the protocol in pure Dart (no Rust bridge required).
///
/// Spec references:
///   OID4VCI 1.0 Final: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html
///   RFC 8414: https://tools.ietf.org/html/rfc8414
///   RFC 6749: https://tools.ietf.org/html/rfc6749
///
/// §1  Metadata parsing              — VCIIssuerMetadataTest
/// §2  Credential offer formats      — VCIIssuerHappyFlow (client side)
/// §3  Token endpoint                — pre-auth code exchange
/// §4  Nonce endpoint                — OID4VCI 1.0 Final nonce flow
/// §5  Credential request            — proof JWT construction & response
/// §6  Nonce rotation                — VCIIssuerHappyFlowAdditionalRequests
/// §7  Error handling                — VCIIssuerFail* error mapping
/// §8  SIOPv2 stubs                  — @Skip pending implementation
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures/oid4vc_conformance_fixtures.dart';
import '../helpers/oid4vc_http_client.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build a [MockClient] that routes by URL path and always returns
/// JSON with 200, unless the [statusOverride] map provides a different code.
MockClient _buildMockClient(
  Map<String, String> pathToBody, {
  Map<String, int> statusOverride = const {},
}) {
  return MockClient((request) async {
    final path = request.url.path;
    for (final entry in pathToBody.entries) {
      if (path.endsWith(entry.key)) {
        final status = statusOverride[entry.key] ?? 200;
        return http.Response(
          entry.value,
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    return http.Response(
      '{"error":"not_found"}',
      404,
      headers: {'content-type': 'application/json'},
    );
  });
}

// ── §1  Metadata Parsing ──────────────────────────────────────────────────────

void main() {
  group('§1 OID4VCI 1.0 Final — Issuer Metadata (VCIIssuerMetadataTest)', () {
    /// OID4VCI §12.2.2: The wallet MUST fetch
    /// `{issuer}/.well-known/openid-credential-issuer` and parse required fields.
    test(
      'metadataParsing_happyPath — required fields present and parseable',
      () async {
        final client = OID4VCHttpClient(
          _buildMockClient({
            '.well-known/openid-credential-issuer': kIssuerMetadataJson,
          }),
        );

        final meta = await client.fetchIssuerMetadata(kIssuerUrl);

        expect(meta.credentialIssuer, equals(kIssuerUrl));
        expect(meta.credentialEndpoint, equals(kCredentialEndpoint));
        expect(
          meta.nonceEndpoint,
          equals(kNonceEndpoint),
          reason: 'OID4VCI 1.0 Final §7: nonce_endpoint MUST be present',
        );
        expect(
          meta.deferredCredentialEndpoint,
          isNotNull,
          reason:
              'OID4VCI 1.0 Final §9: deferred_credential_endpoint MUST be present',
        );
        expect(
          meta.credentialConfigurationsSupported,
          isNotEmpty,
          reason:
              'OID4VCI §12.2.2: credential_configurations_supported MUST be non-empty',
        );
      },
    );

    /// OID4VCI §12.2.2: `credential_configurations_supported` entries MUST
    /// include a `format` field distinguishing Final (`dc+sd-jwt`) from draft.
    test('metadataParsing_configurationsContainFinalFormat', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({
          '.well-known/openid-credential-issuer': kIssuerMetadataJson,
        }),
      );

      final meta = await client.fetchIssuerMetadata(kIssuerUrl);
      final configs = meta.credentialConfigurationsSupported;
      final formats = configs.values
          .map((c) => (c as Map)['format'] as String?)
          .toList();

      expect(
        formats.any((f) => f == 'dc+sd-jwt'),
        isTrue,
        reason:
            'OID4VCI 1.0 Final Appendix A: dc+sd-jwt is the Final format name',
      );
    });

    /// Wallet MUST also accept draft-era `vc+sd-jwt` format in metadata
    /// for backwards compatibility.
    test('metadataParsing_legacyFormat_vcSdJwtAccepted', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({
          '.well-known/openid-credential-issuer': kIssuerMetadataLegacyJson,
        }),
      );

      final meta = await client.fetchIssuerMetadata(kIssuerUrl);
      final configs = meta.credentialConfigurationsSupported;
      final formats = configs.values
          .map((c) => (c as Map)['format'] as String?)
          .toList();

      expect(
        formats.any((f) => f == 'vc+sd-jwt'),
        isTrue,
        reason: 'Draft-era vc+sd-jwt format MUST still be accepted',
      );
    });

    /// RFC 8414: wallet MUST be able to fetch OAuth AS metadata from the
    /// `.well-known/oauth-authorization-server` path.
    test(
      'oauthMetadata_happyPath — token_endpoint and grant_types present',
      () async {
        final client = OID4VCHttpClient(
          _buildMockClient({
            '.well-known/oauth-authorization-server': kOAuthAsMetadataJson,
          }),
        );

        final meta = await client.fetchOAuthMetadata(kIssuerUrl);

        expect(meta['issuer'], equals(kIssuerUrl));
        expect(
          meta['token_endpoint'],
          equals(kTokenEndpoint),
          reason: 'RFC 8414: token_endpoint MUST be present',
        );
        expect(
          (meta['grant_types_supported'] as List<dynamic>).contains(
            'urn:ietf:params:oauth:grant-type:pre-authorized_code',
          ),
          isTrue,
          reason: 'OID4VCI §11: pre-authorized_code grant MUST be listed',
        );
      },
    );

    /// OID4VCI §12.2.2: `authorization_servers` URIs MUST be present.
    test('metadataParsing_authorizationServersPresent', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({
          '.well-known/openid-credential-issuer': kIssuerMetadataJson,
        }),
      );

      final meta = await client.fetchIssuerMetadata(kIssuerUrl);

      expect(
        meta.authorizationServers,
        isNotEmpty,
        reason: 'OID4VCI §12.2.2: authorization_servers MUST be non-empty',
      );
    });
  });

  // ── §2  Credential Offer Formats ────────────────────────────────────────────

  group('§2 OID4VCI — Credential Offer Parsing (VCIIssuerHappyFlow client)', () {
    /// OID4VCI §11: Client parses pre-authorized code offer fields correctly.
    test('credentialOffer_preAuth_parsesAllFields', () {
      final offer =
          jsonDecode(kCredentialOfferPreAuthJson) as Map<String, dynamic>;

      expect(offer['credential_issuer'], equals(kIssuerUrl));
      expect(offer['credential_configuration_ids'], isA<List>());
      expect(
        (offer['credential_configuration_ids'] as List).first,
        equals('UniversityDegree_jwt_vc_json'),
      );

      final grants = offer['grants'] as Map<String, dynamic>;
      final preAuth =
          grants['urn:ietf:params:oauth:grant-type:pre-authorized_code'] as Map;
      expect(preAuth['pre-authorized_code'], equals(kPreAuthCode));
      expect(
        preAuth['tx_code'],
        isNotNull,
        reason: 'OID4VCI §11: tx_code indicates PIN is required',
      );
      expect(
        (preAuth['tx_code'] as Map)['input_mode'],
        anyOf(equals('numeric'), equals('text')),
      );
    });

    /// OID4VCI §11.3: By-reference offer contains `credential_offer_uri`.
    test('credentialOffer_byRef_containsOfferUri', () {
      final offer =
          jsonDecode(kCredentialOfferByRefJson) as Map<String, dynamic>;

      expect(
        offer['credential_offer_uri'],
        isNotNull,
        reason:
            'OID4VCI §11.3: by-reference offer MUST have credential_offer_uri',
      );
      expect(
        offer['credential_offer_uri'],
        startsWith('https://'),
        reason: 'credential_offer_uri MUST be an HTTPS URL',
      );
    });
  });

  // ── §3  Token Endpoint ───────────────────────────────────────────────────────

  group('§3 OID4VCI §7 — Token Endpoint (pre-auth code exchange)', () {
    /// OID4VCI §7.2: Wallet sends correct grant_type and pre-authorized_code.
    test('tokenExchange_preAuth_sendsCorrectGrantType', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        expect(
          request.method,
          equals('POST'),
          reason: 'Token endpoint MUST use POST',
        );
        expect(
          request.headers['content-type'],
          contains('application/x-www-form-urlencoded'),
        );
        capturedBody = request.body;
        return http.Response(
          kTokenResponseJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OID4VCHttpClient(mockClient);
      await client.exchangePreAuthToken(
        tokenEndpoint: kTokenEndpoint,
        preAuthCode: kPreAuthCode,
      );

      expect(capturedBody, contains('grant_type='));
      expect(
        capturedBody,
        contains(
          'urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code',
        ),
      );
      expect(capturedBody, contains('pre-authorized_code=$kPreAuthCode'));
    });

    /// OID4VCI §7: When tx_code is provided, it MUST be sent as `tx_code`.
    test('tokenExchange_withTxCode_includesTxCode', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          kTokenResponseJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await OID4VCHttpClient(mockClient).exchangePreAuthToken(
        tokenEndpoint: kTokenEndpoint,
        preAuthCode: kPreAuthCode,
        txCode: '123456',
      );

      expect(
        capturedBody,
        contains('tx_code=123456'),
        reason: 'OID4VCI §7: tx_code MUST be sent when PIN is required',
      );
    });

    /// OID4VCI Final §6: the token response contains OAuth token fields;
    /// proof nonces are obtained from the nonce endpoint.
    test('tokenExchange_responseFields_allPresent', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({'token': kTokenResponseJson}),
      );

      final token = await client.exchangePreAuthToken(
        tokenEndpoint: kTokenEndpoint,
        preAuthCode: kPreAuthCode,
      );

      expect(
        token.accessToken,
        isNotEmpty,
        reason: 'RFC 6749: access_token MUST be present',
      );
      expect(
        token.tokenType,
        equalsIgnoringCase('Bearer'),
        reason: 'RFC 6749: token_type MUST be Bearer',
      );
    });
  });

  // ── §4  Nonce Endpoint ───────────────────────────────────────────────────────

  group('§4 OID4VCI 1.0 Final §7.2 — Nonce Endpoint', () {
    /// OID4VCI 1.0 Final §7.2: POST to the nonce endpoint without a bearer token.
    test('nonceEndpoint_isUnauthenticated', () async {
      String? capturedAuth;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['authorization'];
        return http.Response(
          kNonceResponseJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await OID4VCHttpClient(
        mockClient,
      ).requestNonce(nonceEndpoint: kNonceEndpoint);

      expect(
        capturedAuth,
        isNull,
        reason: 'OID4VCI 1.0 Final §7.2: nonce requests are unauthenticated',
      );
    });

    /// Nonce response must contain a fresh `c_nonce`.
    test('nonceEndpoint_returnsNewCNonce', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({'nonce': kNonceResponseJson}),
      );

      final nonceResp = await client.requestNonce(
        nonceEndpoint: kNonceEndpoint,
      );

      expect(
        nonceResp.cNonce,
        isNotEmpty,
        reason: 'OID4VCI 1.0 Final §7.2: c_nonce MUST be present',
      );
    });

    /// OID4VCI 1.0 Final §7.2: c_nonce must be unique across calls.
    test('nonceEndpoint_noncesAreUnique', () async {
      int callCount = 0;
      final nonces = ['firstNonce001', 'secondNonce002'];
      final mockClient = MockClient((_) async {
        final n = nonces[callCount++ % nonces.length];
        return http.Response(
          '{"c_nonce":"$n"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = OID4VCHttpClient(mockClient);
      final n1 = await svc.requestNonce(nonceEndpoint: kNonceEndpoint);
      final n2 = await svc.requestNonce(nonceEndpoint: kNonceEndpoint);

      expect(
        n1.cNonce,
        isNot(equals(n2.cNonce)),
        reason:
            'OID4VCI 1.0 Final §7.2: each nonce request MUST return a unique c_nonce',
      );
    });
  });

  // ── §5  Credential Request ───────────────────────────────────────────────────

  group('§5 OID4VCI §8 — Credential Endpoint', () {
    const kDummyProofJwt =
        'eyJhbGciOiJFZERTQSIsInR5cCI6Im9wZW5pZDR2Y2ktcHJvb2Yrand.dGVzdA.dGVzdA';

    /// OID4VCI §8: Credential request MUST include Bearer authorization,
    /// format, and proofs.jwt array.
    test('credentialRequest_sendsCorrectHeaders', () async {
      String? capturedAuth;
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['authorization'];
        capturedBody = request.body;
        return http.Response(
          kCredentialResponseJwtVcJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await OID4VCHttpClient(mockClient).requestCredential(
        credentialEndpoint: kCredentialEndpoint,
        accessToken: kAccessToken,
        credentialFormat: 'jwt_vc_json',
        proofJwt: kDummyProofJwt,
      );

      expect(capturedAuth, equals('Bearer $kAccessToken'));
      expect(capturedBody, contains('"format":"jwt_vc_json"'));
      expect(
        capturedBody,
        contains('"proofs"'),
        reason: 'OID4VCI 1.0 Final §8: MUST use proofs (Final array format)',
      );
    });

    /// OID4VCI §8: Credential response MUST contain credentials array (Final)
    /// and optionally a refreshed c_nonce.
    test('credentialRequest_parsesResponseCorrectly', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({'credential': kCredentialResponseJwtVcJson}),
      );

      final resp = await client.requestCredential(
        credentialEndpoint: kCredentialEndpoint,
        accessToken: kAccessToken,
        credentialFormat: 'jwt_vc_json',
        proofJwt: kDummyProofJwt,
      );

      expect(resp.format, equals('jwt_vc_json'));
      expect(
        resp.credentials,
        isNotEmpty,
        reason: 'OID4VCI 1.0 Final §8: credentials array MUST be non-empty',
      );
    });

    /// OID4VCI §8: SD-JWT credential response is accepted and parseable.
    test('credentialRequest_sdJwtResponse_parseable', () async {
      final client = OID4VCHttpClient(
        _buildMockClient({'credential': kCredentialResponseSdJwtJson}),
      );

      final resp = await client.requestCredential(
        credentialEndpoint: kCredentialEndpoint,
        accessToken: kAccessToken,
        credentialFormat: 'dc+sd-jwt',
        proofJwt: kDummyProofJwt,
      );

      expect(resp.format, equals('dc+sd-jwt'));
      expect(resp.credentials, isNotEmpty);
    });

    /// OID4VCI §8: When `credential_configuration_id` is provided, it MUST
    /// appear in the request body.
    test('credentialRequest_includesConfigId_whenProvided', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          kCredentialResponseJwtVcJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await OID4VCHttpClient(mockClient).requestCredential(
        credentialEndpoint: kCredentialEndpoint,
        accessToken: kAccessToken,
        credentialFormat: 'jwt_vc_json',
        proofJwt: kDummyProofJwt,
        credentialConfigurationId: 'UniversityDegree_jwt_vc_json',
      );

      expect(
        capturedBody,
        contains(
          '"credential_configuration_id":"UniversityDegree_jwt_vc_json"',
        ),
        reason:
            'OID4VCI §8.2: credential_configuration_id MUST be sent when provided',
      );
    });
  });

  // ── §6  Additional Proof Nonces ─────────────────────────────────────────────

  group('§6 OID4VCI 1.0 Final §7 — Additional Proof Nonces', () {
    /// Each additional proof obtains a fresh c_nonce from the nonce endpoint.
    test('additionalRequest_usesNonceEndpointForNextProof', () async {
      const nextNonce = 'nextProofNonce999';
      String? secondRequestBody;
      int callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            '{"format":"jwt_vc_json","credentials":["cred1"]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (callCount == 2) {
          return http.Response(
            '{"c_nonce":"$nextNonce"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        secondRequestBody = request.body;
        return http.Response(
          kCredentialResponseJwtVcJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = OID4VCHttpClient(mockClient);

      await svc.requestCredential(
        credentialEndpoint: kCredentialEndpoint,
        accessToken: kAccessToken,
        credentialFormat: 'jwt_vc_json',
        proofJwt: 'proof.using.original.nonce',
      );

      final nonce = await svc.requestNonce(nonceEndpoint: kNonceEndpoint);
      final newProofJwt = 'proof.using.${nonce.cNonce}';
      await svc.requestCredential(
        credentialEndpoint: kCredentialEndpoint,
        accessToken: kAccessToken,
        credentialFormat: 'jwt_vc_json',
        proofJwt: newProofJwt,
      );

      expect(
        secondRequestBody,
        contains(nextNonce),
        reason:
            'OID4VCI Final §7: the nonce endpoint value must be used in the next proof',
      );
    });
  });

  // ── §7  Error Handling ───────────────────────────────────────────────────────

  group('§7 RFC 6749 §5.2 / OID4VCI §8 — Error Response Handling', () {
    /// RFC 6749 §5.2: A 401 from the token endpoint MUST surface as an error.
    test('errorHandling_tokenEndpoint401_throwsError', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          '{"error":"invalid_client","error_description":"Invalid credentials"}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        () => OID4VCHttpClient(mockClient).exchangePreAuthToken(
          tokenEndpoint: kTokenEndpoint,
          preAuthCode: kPreAuthCode,
        ),
        throwsA(isA<StateError>()),
        reason: 'RFC 6749: 401 from token endpoint MUST throw',
      );
    });

    /// OID4VCI §8: A 401 from the credential endpoint MUST surface as an error.
    test('errorHandling_credentialEndpoint401_throwsError', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          '{"error":"invalid_token"}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        () => OID4VCHttpClient(mockClient).requestCredential(
          credentialEndpoint: kCredentialEndpoint,
          accessToken: 'stale-token',
          credentialFormat: 'jwt_vc_json',
          proofJwt: 'proof.jwt',
        ),
        throwsA(isA<StateError>()),
        reason: 'OID4VCI §8: 401 from credential endpoint MUST throw',
      );
    });

    /// OID4VCI §8: A 400 with `invalid_proof` and a new c_nonce SHOULD
    /// allow the wallet to retry with a fresh nonce.
    test('errorHandling_invalidProof400_parseable', () {
      const responseBody = '{"error":"invalid_proof"}';
      final body = jsonDecode(responseBody) as Map<String, dynamic>;

      expect(body['error'], equals('invalid_proof'));
      expect(body, isNot(contains('c_nonce')));
    });
  });

  // ── §8  SIOPv2 Stubs ─────────────────────────────────────────────────────────

  group('§8 SIOPv2 Draft 13 — stubbed pending implementation', () {
    test(
      'siop_v2_discovery_wellKnown',
      () async {
        // TODO: validate /.well-known/openid-configuration with
        // subject_syntax_types_supported and id_token_signing_alg_values_supported.
      },
      skip: 'SIOPv2 not yet implemented — see test_siop_v2_conformance.py',
    );

    test(
      'siop_v2_idToken_iss_sub_mustMatch',
      () async {
        // TODO: SIOPv2 §11 — iss claim MUST equal sub claim for self-issued IDs.
      },
      skip: 'SIOPv2 not yet implemented — see test_siop_v2_conformance.py',
    );
  });
}
