/// Pure-Dart OID4VCI / OID4VP HTTP client for conformance testing.
///
/// Implements the OID4VCI and OID4VP protocol HTTP calls using `package:http`,
/// bypassing the Rust bridge (flutter_rust_bridge / marty-oid4vci FFI).
///
/// By accepting an injectable `http.Client`, tests can substitute a
/// `MockClient` from `package:http/testing.dart` to exercise the Dart-side
/// request construction and response parsing without a live server.
///
/// This is **test-only infrastructure** and must not be imported by production
/// code.  The production wallet service is `lib/services/oid4vc_service.dart`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

// ── Data models ───────────────────────────────────────────────────────────────

class Oid4vciIssuerMetadata {
  final String credentialIssuer;
  final String credentialEndpoint;
  final String? nonceEndpoint;
  final String? deferredCredentialEndpoint;
  final String? notificationEndpoint;
  final List<String> authorizationServers;
  final Map<String, dynamic> credentialConfigurationsSupported;

  const Oid4vciIssuerMetadata({
    required this.credentialIssuer,
    required this.credentialEndpoint,
    this.nonceEndpoint,
    this.deferredCredentialEndpoint,
    this.notificationEndpoint,
    this.authorizationServers = const [],
    this.credentialConfigurationsSupported = const {},
  });

  factory Oid4vciIssuerMetadata.fromJson(
    Map<String, dynamic> j,
  ) => Oid4vciIssuerMetadata(
    credentialIssuer: j['credential_issuer'] as String,
    credentialEndpoint: j['credential_endpoint'] as String,
    nonceEndpoint: j['nonce_endpoint'] as String?,
    deferredCredentialEndpoint: j['deferred_credential_endpoint'] as String?,
    notificationEndpoint: j['notification_endpoint'] as String?,
    authorizationServers:
        (j['authorization_servers'] as List<dynamic>?)?.cast<String>() ?? [],
    credentialConfigurationsSupported:
        (j['credential_configurations_supported'] as Map<String, dynamic>?) ??
        {},
  );
}

class Oid4vciTokenResponse {
  final String accessToken;
  final String tokenType;
  final int? expiresIn;
  final String? cNonce;
  final int? cNonceExpiresIn;

  const Oid4vciTokenResponse({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.cNonce,
    this.cNonceExpiresIn,
  });

  factory Oid4vciTokenResponse.fromJson(Map<String, dynamic> j) =>
      Oid4vciTokenResponse(
        accessToken: j['access_token'] as String,
        tokenType: j['token_type'] as String,
        expiresIn: j['expires_in'] as int?,
        cNonce: j['c_nonce'] as String?,
        cNonceExpiresIn: j['c_nonce_expires_in'] as int?,
      );
}

class Oid4vciNonceResponse {
  final String cNonce;
  final int? cNonceExpiresIn;

  const Oid4vciNonceResponse({required this.cNonce, this.cNonceExpiresIn});

  factory Oid4vciNonceResponse.fromJson(Map<String, dynamic> j) =>
      Oid4vciNonceResponse(
        cNonce: j['c_nonce'] as String,
        cNonceExpiresIn: j['c_nonce_expires_in'] as int?,
      );
}

class Oid4vciCredentialResponse {
  final String? format;
  final List<String> credentials;
  final String? credential; // draft-era single credential
  final String? transactionId;
  final String? cNonce;
  final int? cNonceExpiresIn;

  const Oid4vciCredentialResponse({
    this.format,
    this.credentials = const [],
    this.credential,
    this.transactionId,
    this.cNonce,
    this.cNonceExpiresIn,
  });

  factory Oid4vciCredentialResponse.fromJson(Map<String, dynamic> j) =>
      Oid4vciCredentialResponse(
        format: j['format'] as String?,
        credentials: (j['credentials'] as List<dynamic>?)?.cast<String>() ?? [],
        credential: j['credential'] as String?,
        transactionId: j['transaction_id'] as String?,
        cNonce: j['c_nonce'] as String?,
        cNonceExpiresIn: j['c_nonce_expires_in'] as int?,
      );
}

class Oid4vpPresentationRequest {
  final String responseType;
  final String clientId;
  final String? clientIdScheme;
  final String nonce;
  final String? responseMode;
  final String? responseUri;
  final String? state;
  final Map<String, dynamic>? presentationDefinition;
  final Map<String, dynamic>? dcqlQuery;

  const Oid4vpPresentationRequest({
    required this.responseType,
    required this.clientId,
    this.clientIdScheme,
    required this.nonce,
    this.responseMode,
    this.responseUri,
    this.state,
    this.presentationDefinition,
    this.dcqlQuery,
  });

  factory Oid4vpPresentationRequest.fromJson(Map<String, dynamic> j) =>
      Oid4vpPresentationRequest(
        responseType: j['response_type'] as String,
        clientId: j['client_id'] as String,
        clientIdScheme: j['client_id_scheme'] as String?,
        nonce: j['nonce'] as String,
        responseMode: j['response_mode'] as String?,
        responseUri: j['response_uri'] as String?,
        state: j['state'] as String?,
        presentationDefinition:
            j['presentation_definition'] as Map<String, dynamic>?,
        dcqlQuery: j['dcql_query'] as Map<String, dynamic>?,
      );
}

// ── Client ────────────────────────────────────────────────────────────────────

/// HTTP-transport-level OID4VCI / OID4VP client for use in conformance tests.
///
/// Inject a `MockClient` from `package:http/testing.dart` in tests to intercept
/// each request and return spec-compliant fixture responses.
class OID4VCHttpClient {
  final http.Client _http;

  const OID4VCHttpClient(this._http);

  // ── OID4VCI — Issuer metadata ──────────────────────────────────────────────

  /// OID4VCI §12.2.2: GET `{issuerUrl}/.well-known/openid-credential-issuer`.
  Future<Oid4vciIssuerMetadata> fetchIssuerMetadata(String issuerUrl) async {
    final uri = Uri.parse('$issuerUrl/.well-known/openid-credential-issuer');
    final response = await _http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    _assertStatus(response, 200, 'fetchIssuerMetadata');
    return Oid4vciIssuerMetadata.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// RFC 8414: GET `{issuerUrl}/.well-known/oauth-authorization-server`.
  Future<Map<String, dynamic>> fetchOAuthMetadata(String issuerUrl) async {
    final uri = Uri.parse('$issuerUrl/.well-known/oauth-authorization-server');
    final response = await _http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    _assertStatus(response, 200, 'fetchOAuthMetadata');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── OID4VCI — Token exchange ───────────────────────────────────────────────

  /// OID4VCI §7.2: Exchange a pre-authorized code for an access token.
  ///
  /// POST to [tokenEndpoint] with:
  ///   `grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code`
  ///   `pre-authorized_code=<code>`
  ///   `tx_code=<pin>` (if [txCode] is not null)
  Future<Oid4vciTokenResponse> exchangePreAuthToken({
    required String tokenEndpoint,
    required String preAuthCode,
    String? txCode,
  }) async {
    final body = <String, String>{
      'grant_type': 'urn:ietf:params:oauth:grant-type:pre-authorized_code',
      'pre-authorized_code': preAuthCode,
    };
    if (txCode != null) body['tx_code'] = txCode;

    final response = await _http.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    _assertStatus(response, 200, 'exchangePreAuthToken');
    return Oid4vciTokenResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── OID4VCI — Nonce endpoint ───────────────────────────────────────────────

  /// OID4VCI 1.0 Final §7.2: POST to nonce endpoint; returns a fresh c_nonce.
  Future<Oid4vciNonceResponse> requestNonce({
    required String nonceEndpoint,
    required String accessToken,
  }) async {
    final response = await _http.post(
      Uri.parse(nonceEndpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    _assertStatus(response, 200, 'requestNonce');
    return Oid4vciNonceResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── OID4VCI — Credential request ──────────────────────────────────────────

  /// OID4VCI §8: Request a credential using a proof JWT.
  ///
  /// Uses the Final-spec `proofs` array format.  Pass
  /// [credentialConfigurationId] to select a specific configuration.
  Future<Oid4vciCredentialResponse> requestCredential({
    required String credentialEndpoint,
    required String accessToken,
    required String credentialFormat,
    required String proofJwt,
    String? credentialConfigurationId,
  }) async {
    final body = <String, dynamic>{
      'format': credentialFormat,
      'proofs': {
        'jwt': <String>[proofJwt],
      },
    };
    if (credentialConfigurationId != null) {
      body['credential_configuration_id'] = credentialConfigurationId;
    }

    final response = await _http.post(
      Uri.parse(credentialEndpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    _assertStatus(response, 200, 'requestCredential');
    return Oid4vciCredentialResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── OID4VP — Presentation flow ─────────────────────────────────────────────

  /// OID4VP §5.2: Fetch the authorization request object.
  ///
  /// Handles both:
  ///   - Inline JSON response (`application/json`)
  ///   - Signed JWT response (`application/oauth-authz-req+jwt`)
  Future<Oid4vpPresentationRequest> fetchPresentationRequest(
    String requestUri,
  ) async {
    final response = await _http.get(
      Uri.parse(requestUri),
      headers: {'Accept': 'application/oauth-authz-req+jwt, application/json'},
    );
    _assertStatus(response, 200, 'fetchPresentationRequest');

    final ct = response.headers['content-type'] ?? '';
    if (ct.contains('jwt')) {
      // Decode the JWT payload (no signature verification at this layer)
      final payload = _decodeJwtPayload(response.body.trim());
      return Oid4vpPresentationRequest.fromJson(payload);
    }
    return Oid4vpPresentationRequest.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// OID4VP §7.5: Submit a VP token to the verifier via `direct_post`.
  ///
  /// POST `application/x-www-form-urlencoded` with:
  ///   `vp_token=<token>`
  ///   `presentation_submission=<json>`
  ///   `state=<state>` (if provided)
  Future<http.Response> submitVpToken({
    required String responseUri,
    required String vpToken,
    required Map<String, dynamic> presentationSubmission,
    String? state,
  }) async {
    final body = <String, String>{
      'vp_token': vpToken,
      'presentation_submission': jsonEncode(presentationSubmission),
    };
    if (state != null) body['state'] = state;

    return _http.post(
      Uri.parse(responseUri),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertStatus(http.Response r, int expected, String operation) {
    if (r.statusCode != expected) {
      throw StateError(
        '$operation returned ${r.statusCode}, expected $expected: ${r.body}',
      );
    }
  }

  /// Decode the JWT payload (second segment) without verifying the signature.
  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) throw ArgumentError('Not a valid JWT: $jwt');
    var b64 = parts[1];
    // Add padding
    while (b64.length % 4 != 0) {
      b64 += '=';
    }
    final decoded = base64Url.decode(b64);
    return jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
  }
}
