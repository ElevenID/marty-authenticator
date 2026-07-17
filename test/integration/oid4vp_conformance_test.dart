/// OID4VP 1.0 Final Conformance Tests — Dart wallet (holder / presenter) side.
///
/// Tests how the wallet correctly parses presentation requests and submits
/// VP tokens for the OID4VP 1.0 Final cross-device and same-device flows.
///
/// Mock layer: HTTP transport level via `MockClient` from `package:http/testing`.
/// Each test injects a `MockClient` into `OID4VCHttpClient` so no Rust bridge
/// (flutter_rust_bridge FFI) is exercised.  Cryptographic proof correctness is
/// tested separately in marty-core/marty-oid4vci/tests/oid4vp_conformance.rs.
///
/// Spec references:
///   OID4VP 1.0 Final: https://openid.net/specs/openid-4-verifiable-presentations-1_0.html
///   PE v2.1: https://identity.foundation/presentation-exchange/spec/v2.1.0/
///   SIOPv2 Draft 13: https://openid.net/specs/openid-connect-self-issued-v2-1_0.html
///
/// §1  Presentation request parsing  — VP_W_X.001 (request by value)
/// §2  Presentation definition       — VP_W_X.002 – VP_W_X.003
/// §3  VP token submission           — VP_W_X.004 (direct_post)
/// §4  client_id_scheme              — VP_W_X.005 (Final §5)
/// §5  Error / rejection             — VP_W_X.006
/// §6  SIOPv2 stubs                  — @Skip pending implementation
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures/oid4vc_conformance_fixtures.dart';
import '../helpers/oid4vc_http_client.dart';

// ── §1  Presentation Request Parsing ─────────────────────────────────────────

void main() {
  group('§1 OID4VP 1.0 Final — Presentation Request (VP_W_X.001)', () {
    /// OID4VP §6.1: wallet fetches URI, parses required top-level fields.
    test('parsePresentationRequest_byValue_happyPath', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          kPresentationRequestJson,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final req = await OID4VCHttpClient(
        mockClient,
      ).fetchPresentationRequest('https://verifier.example.com/request/abc123');

      expect(
        req.responseType,
        equals('vp_token'),
        reason: 'OID4VP §5: response_type MUST be "vp_token" for VP requests',
      );
      expect(
        req.clientId,
        equals(kVerifierId),
        reason: 'OID4VP §5: client_id MUST match the verifier URI',
      );
      expect(
        req.nonce,
        equals(kNonce),
        reason: 'OID4VP §5: nonce MUST be present for replay protection',
      );
      expect(
        req.responseMode,
        equals('direct_post'),
        reason:
            'OID4VP §6: response_mode MUST be "direct_post" for wallet-initiated',
      );
      expect(
        req.responseUri,
        equals(kResponseUri),
        reason: 'OID4VP §6: response_uri MUST be present for direct_post',
      );
      expect(
        req.dcqlQuery,
        isNotNull,
        reason:
            'OID4VP §6: the default verifier request should carry dcql_query',
      );
      expect(
        req.presentationDefinition,
        isNull,
        reason:
            'PE is legacy compat only; the default verifier request should omit presentation_definition',
      );
    });

    /// OID4VP §5: All three REQUIRED fields from §5 must be non-null.
    test('presentationRequest_requiredFields_allPresent', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          kPresentationRequestJson,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final req = await OID4VCHttpClient(
        mockClient,
      ).fetchPresentationRequest('https://verifier.example.com/request/abc123');

      expect(req.nonce, isNotEmpty, reason: 'OID4VP §5: nonce is REQUIRED');
      expect(
        req.clientId,
        isNotEmpty,
        reason: 'OID4VP §5: client_id is REQUIRED',
      );
      expect(
        req.responseType,
        isNotEmpty,
        reason: 'OID4VP §5: response_type is REQUIRED',
      );
      expect(
        req.dcqlQuery,
        isNotNull,
        reason: 'Default OID4VP requests should expose dcql_query',
      );
      expect(
        req.presentationDefinition,
        isNull,
        reason:
            'Default OID4VP requests should not expose presentation_definition',
      );
    });

    /// OID4VP §6: When response_mode is direct_post, response_uri MUST be present.
    test('presentationRequest_directPost_responseUriRequired', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          kPresentationRequestJson,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final req = await OID4VCHttpClient(
        mockClient,
      ).fetchPresentationRequest('https://verifier.example.com/request/abc123');

      expect(req.responseMode, equals('direct_post'));
      expect(
        req.responseUri,
        isNotNull,
        reason:
            'OID4VP §6: response_uri MUST be present when response_mode is direct_post',
      );
      expect(
        req.responseUri,
        startsWith('https://'),
        reason: 'OID4VP §6: response_uri MUST be an HTTPS URI',
      );
    });

    /// OID4VP §5: When the request arrives as a signed JWT, the wallet MUST
    /// decode the payload (content-type: application/oauth-authz-req+jwt).
    test('parsePresentationRequest_jwtContentType_payloadDecoded', () async {
      // Minimal unsigned JWT with JSON payload (header.payload.sig)
      // The 'payload' part is the base64url of kPresentationRequestJson.
      final payloadB64 = base64Url
          .encode(utf8.encode(kPresentationRequestJson))
          .replaceAll('=', '');
      final fakeJwt = 'eyJhbGciOiJFZERTQSJ9.$payloadB64.fakeSig';

      final mockClient = MockClient(
        (_) async => http.Response(
          fakeJwt,
          200,
          headers: {'content-type': 'application/oauth-authz-req+jwt'},
        ),
      );

      final req = await OID4VCHttpClient(
        mockClient,
      ).fetchPresentationRequest('https://verifier.example.com/request/jwt123');

      expect(
        req.nonce,
        equals(kNonce),
        reason:
            'JWT-encoded request MUST be decoded and nonce MUST match fixture',
      );
      expect(req.clientId, equals(kVerifierId));
      expect(req.dcqlQuery, isNotNull);
      expect(req.presentationDefinition, isNull);
    });

    /// Legacy PE requests must still parse so compat flows (e.g. lissi) survive.
    test('parsePresentationRequest_legacyPeRequest_stillSupported', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          kLegacyPresentationRequestJson,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final req = await OID4VCHttpClient(mockClient).fetchPresentationRequest(
        'https://verifier.example.com/request/legacy-pe',
      );

      expect(req.presentationDefinition, isNotNull);
      expect(req.dcqlQuery, isNull);
    });
  });

  // ── §2  Credential Query / Legacy Presentation Definition ────────────────

  group('§2 OID4VP / PE v2 — Presentation Definition (VP_W_X.002–003)', () {
    /// PE v2.1 §5: PD in fixture has required `id` and `input_descriptors`.
    test('presentationDefinition_fixtureHasRequiredFields', () {
      final pd =
          jsonDecode(kPresentationDefinitionJson) as Map<String, dynamic>;

      expect(
        pd['id'],
        isNotNull,
        reason: 'PE v2.1 §5: id is REQUIRED in a Presentation Definition',
      );
      expect(
        pd['input_descriptors'],
        isA<List>(),
        reason: 'PE v2.1 §5: input_descriptors MUST be a list',
      );
      expect(
        (pd['input_descriptors'] as List).isNotEmpty,
        isTrue,
        reason: 'PE v2.1 §5: input_descriptors MUST be non-empty',
      );
    });

    /// PE v2.1 §5.1: Each input descriptor MUST have `id` and `constraints`.
    test('presentationDefinition_inputDescriptor_hasIdAndConstraints', () {
      final pd =
          jsonDecode(kPresentationDefinitionJson) as Map<String, dynamic>;
      final descriptors = pd['input_descriptors'] as List<dynamic>;

      for (final desc in descriptors) {
        final d = desc as Map<String, dynamic>;
        expect(
          d['id'],
          isNotNull,
          reason: 'PE v2.1 §5.1: input_descriptor.id MUST be present',
        );
        expect(
          d['constraints'],
          isNotNull,
          reason: 'PE v2.1 §5.1: input_descriptor.constraints MUST be present',
        );
      }
    });

    /// PE v2.1 §8.1: Presentation Submission in fixture references the
    /// correct definition_id and descriptor_map.
    test('presentationSubmission_linksToDefinition', () {
      final ps =
          jsonDecode(kPresentationSubmissionJson) as Map<String, dynamic>;
      final pd =
          jsonDecode(kPresentationDefinitionJson) as Map<String, dynamic>;

      expect(
        ps['definition_id'],
        equals(pd['id']),
        reason:
            'PE v2.1 §8.1: presentation_submission.definition_id MUST equal the PD id',
      );
      expect(
        ps['descriptor_map'],
        isA<List>(),
        reason: 'PE v2.1 §8.1: descriptor_map MUST be a list',
      );
    });

    /// The PD embedded in the presentation request matches the standalone PD fixture.
    test('presentationRequest_embeddedPD_matchesFixture', () {
      final req =
          jsonDecode(kLegacyPresentationRequestJson) as Map<String, dynamic>;
      final pd =
          jsonDecode(kPresentationDefinitionJson) as Map<String, dynamic>;

      final embedded = req['presentation_definition'] as Map<String, dynamic>;
      expect(
        embedded['id'],
        equals(pd['id']),
        reason:
            'Embedded PD id MUST match the standalone PD fixture — shared corpus consistency',
      );
    });
  });

  // ── §3  VP Token Submission ───────────────────────────────────────────────

  group('§3 OID4VP §7 — VP Token Submission (VP_W_X.004)', () {
    const kFakeVpToken =
        'eyJhbGciOiJFZERTQSJ9.dGVzdA.dGVzdA'; // minimal fake JWT for HTTP tests

    /// OID4VP §7: submitVpToken MUST POST to response_uri with form encoding.
    test('submitVpToken_usesPostWithFormEncoding', () async {
      String? capturedMethod;
      String? capturedBody;
      Uri? capturedUrl;
      String? capturedContentType;

      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedUrl = request.url;
        capturedBody = request.body;
        capturedContentType = request.headers['content-type'];
        return http.Response('', 200);
      });

      await OID4VCHttpClient(
        mockClient,
      ).submitVpToken(responseUri: kResponseUri, vpToken: kFakeVpToken);

      expect(
        capturedMethod,
        equals('POST'),
        reason: 'OID4VP §7: VP response MUST use POST',
      );
      expect(capturedUrl.toString(), equals(kResponseUri));
      expect(
        capturedContentType,
        contains('application/x-www-form-urlencoded'),
        reason: 'OID4VP §7: direct_post MUST use form encoding',
      );
      expect(capturedBody, contains('vp_token='));
    });

    /// DCQL-originated submissions should not require PE metadata.
    test('submitVpToken_dcqlDefault_omitsPresentationSubmission', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('', 200);
      });

      await OID4VCHttpClient(
        mockClient,
      ).submitVpToken(responseUri: kResponseUri, vpToken: kFakeVpToken);

      expect(
        capturedBody,
        contains('vp_token='),
        reason: 'OID4VP §7: vp_token MUST be in form body',
      );
      expect(
        capturedBody,
        isNot(contains('presentation_submission=')),
        reason:
            'DCQL-originated submissions should omit PE presentation_submission metadata',
      );
    });

    /// Legacy PE requests still include presentation_submission when provided.
    test('submitVpToken_legacyPe_includesPresentationSubmission', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('', 200);
      });

      final ps =
          jsonDecode(kPresentationSubmissionJson) as Map<String, dynamic>;

      await OID4VCHttpClient(mockClient).submitVpToken(
        responseUri: kResponseUri,
        vpToken: kFakeVpToken,
        presentationSubmission: ps,
      );

      expect(
        capturedBody,
        contains('presentation_submission='),
        reason:
            'Legacy PE requests should still forward presentation_submission',
      );
    });

    /// OID4VP §7: state MUST be included when provided.
    test('submitVpToken_withState_includesState', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('', 200);
      });

      await OID4VCHttpClient(mockClient).submitVpToken(
        responseUri: kResponseUri,
        vpToken: kFakeVpToken,
        state: 'abc-state-xyz',
      );

      expect(
        capturedBody,
        contains('state=abc-state-xyz'),
        reason: 'OID4VP §7: state MUST be forwarded when provided',
      );
    });

    /// OID4VP §7: a 200 response means accepted; the raw response is returned.
    test('submitVpToken_200_isReturnedDirectly', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          '{"redirect_uri":"https://verifier.example.com/done"}',
          200,
        ),
      );

      final resp = await OID4VCHttpClient(
        mockClient,
      ).submitVpToken(responseUri: kResponseUri, vpToken: kFakeVpToken);

      expect(resp.statusCode, equals(200));
    });

    /// OID4VP §7: a 400 signals an error from the verifier; status is surfaced.
    test('submitVpToken_400_statusExposedToCaller', () async {
      final mockClient = MockClient(
        (_) async => http.Response('{"error":"vp_token_invalid"}', 400),
      );

      final resp = await OID4VCHttpClient(
        mockClient,
      ).submitVpToken(responseUri: kResponseUri, vpToken: 'tampered.jwt.token');

      expect(
        resp.statusCode,
        equals(400),
        reason:
            'OID4VP §7: 400 from verifier MUST be surfaced as statusCode 400 '
            'so the wallet can surface an appropriate error to the user',
      );
    });
  });

  // ── §4  client_id_scheme ──────────────────────────────────────────────────

  group('§4 OID4VP 1.0 Final §5 — client_id_scheme (VP_W_X.005)', () {
    /// OID4VP 1.0 Final §5: client_id_scheme MUST be present at the transport level.
    test('presentationRequest_clientIdScheme_recognized', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          kPresentationRequestJson,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final req = await OID4VCHttpClient(
        mockClient,
      ).fetchPresentationRequest('https://verifier.example.com/req/1');

      expect(
        req.clientIdScheme,
        isNotNull,
        reason:
            'OID4VP 1.0 Final §5: client_id_scheme MUST be present (x509_san_dns or did)',
      );
    });

    /// client_id_scheme must be one of the defined Final values.
    test('presentationRequest_clientIdScheme_knownValue', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          kPresentationRequestJson,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final req = await OID4VCHttpClient(
        mockClient,
      ).fetchPresentationRequest('https://verifier.example.com/req/1');

      const knownSchemes = {
        'pre-registered',
        'redirect_uri',
        'entity_id',
        'did',
        'x509_san_dns',
        'x509_san_uri',
        'verifier_attestation',
      };

      expect(
        knownSchemes.contains(req.clientIdScheme),
        isTrue,
        reason:
            'OID4VP 1.0 Final §5: client_id_scheme must be a registered value',
      );
    });
  });

  // ── §5  Error / Rejection ─────────────────────────────────────────────────

  group('§5 OID4VP — Error Handling (VP_W_X.006)', () {
    /// If fetching the presentation request fails, an error MUST be surfaced.
    test('fetchPresentationRequest_networkError_throws', () async {
      final mockClient = MockClient(
        (_) async => http.Response('{"error":"not_found"}', 404),
      );

      expect(
        () => OID4VCHttpClient(
          mockClient,
        ).fetchPresentationRequest('https://verifier.example.com/req/missing'),
        throwsA(isA<StateError>()),
        reason: 'Non-200 from request_uri endpoint MUST throw',
      );
    });

    /// A missing nonce in the request SHOULD be detected.
    test('presentationRequest_missingNonce_detectable', () {
      final requestWithoutNonce =
          jsonDecode(kPresentationRequestJson) as Map<String, dynamic>;
      requestWithoutNonce.remove('nonce');

      expect(
        requestWithoutNonce.containsKey('nonce'),
        isFalse,
        reason: 'Regression: nonce was not removed from test fixture copy',
      );

      // The wallet must detect the missing nonce before building a VP.
      // This test asserts the fixture shape, not the client (no suitable method yet).
      // When OID4VCHttpClient gains a validatePresentationRequest() method, add:
      //   expect(() => client.validatePresentationRequest(req), throwsStateError);
    });
  });

  // ── §6  SIOPv2 Stubs ──────────────────────────────────────────────────────

  group('§6 SIOPv2 Draft 13 — stubbed pending implementation', () {
    test(
      'siop_v2_selfIssuedIdTokenFlow',
      () async {
        // TODO: SIOPv2 §11 — wallet presents self-issued ID token where iss == sub.
      },
      skip: 'SIOPv2 not yet implemented — see test_siop_v2_conformance.py',
    );

    test(
      'siop_v2_wellKnownDiscovery',
      () async {
        // TODO: GET /.well-known/openid-configuration to discover SIOPv2 params.
      },
      skip: 'SIOPv2 not yet implemented — see test_siop_v2_conformance.py',
    );
  });
}
