/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// OID4VCI / OID4VP wallet service — Rust bridge wrapper.
///
/// All protocol logic lives in the `marty-oid4vci` Rust crate, exposed via
/// flutter_rust_bridge FFI.  This service provides a thin, idiomatic Dart
/// façade over the generated bindings.
///
/// **Usage:**
/// ```dart
/// final svc = OID4VCService();
///
/// // --- Credential issuance (pre-auth flow) ---
/// final offer = await svc.parseCredentialOffer(scannedUri);
/// final meta  = await svc.fetchIssuerMetadata(offer.credentialIssuer);
/// final token = await svc.exchangePreAuthToken(
///   meta.tokenEndpoint, offer.preAuthorizedCode!, txCode: userPin);
/// final nonce = await svc.fetchNonceForIssuer(meta.credentialIssuer);
/// final proofJwt = await svc.createProofJwtAsync(
///   holderKid: holderKid, cNonce: nonce, issuerUrl: meta.credentialIssuer, jwkJson: jwkJson);
/// final cred = await svc.requestCredential(meta.credentialEndpoint,
///   token.accessToken, 'mso_mdoc', proofJwt);
///
/// // --- Credential presentation (OID4VP) ---
/// final req = await svc.parsePresentationRequest(scannedUri);
/// await svc.buildAndSubmitPresentation(
///   responseUri: req.responseUri,
///   presentationDefinitionJson: req.presentationDefinitionJson,
///   dcqlQueryJson: req.dcqlQueryJson,
///   credentialsJson: credentialsJson,
/// );
/// ```
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../rust/marty_bridge.dart/api.dart';
import '../utils/logger.dart';
import '../utils/oid4vci_offer_uri.dart';

// ============================================================================
// Re-exported Dart models (generated types from FRB codegen match these)
// ============================================================================

class CredentialOffer {
  final String credentialIssuer;
  final List<String> credentialConfigurationIds;
  final String? preAuthorizedCode;
  final bool txCodeRequired;
  final String? issuerState;

  const CredentialOffer({
    required this.credentialIssuer,
    required this.credentialConfigurationIds,
    this.preAuthorizedCode,
    this.txCodeRequired = false,
    this.issuerState,
  });

  factory CredentialOffer.fromMap(Map<String, dynamic> m) => CredentialOffer(
    credentialIssuer: m['credential_issuer'] as String,
    credentialConfigurationIds:
        (m['credential_configuration_ids'] as List<dynamic>).cast<String>(),
    preAuthorizedCode: m['pre_authorized_code'] as String?,
    txCodeRequired: (m['tx_code_required'] as bool?) ?? false,
    issuerState: m['issuer_state'] as String?,
  );
}

class IssuerMetadata {
  final String credentialIssuer;
  final String tokenEndpoint;
  final String credentialEndpoint;
  final String? authorizationEndpoint;
  final List<String> grantTypesSupported;
  final String credentialConfigurationsJson;

  const IssuerMetadata({
    required this.credentialIssuer,
    required this.tokenEndpoint,
    required this.credentialEndpoint,
    this.authorizationEndpoint,
    this.grantTypesSupported = const [],
    this.credentialConfigurationsJson = '{}',
  });

  Map<String, dynamic> toMap() => {
    'credential_issuer': credentialIssuer,
    'token_endpoint': tokenEndpoint,
    'credential_endpoint': credentialEndpoint,
    'authorization_endpoint': authorizationEndpoint,
    'grant_types_supported': grantTypesSupported,
    'credential_configurations_json': credentialConfigurationsJson,
  };
}

class Oid4vciTokenResponse {
  final String accessToken;
  final String tokenType;
  final int? expiresIn;
  final String? scope;

  const Oid4vciTokenResponse({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.scope,
  });
}

class AuthorizationSession {
  /// Full URL to open in an in-app browser / custom tab.
  final String authorizationUrl;

  /// Store this securely and pass to [OID4VCService.exchangeAuthCodeToken].
  final String codeVerifier;

  /// CSRF state value.
  final String state;

  /// Redirect URI that was registered with the issuer.
  final String redirectUri;

  const AuthorizationSession({
    required this.authorizationUrl,
    required this.codeVerifier,
    required this.state,
    required this.redirectUri,
  });
}

class Oid4vciCredentialResponse {
  final String? format;
  final String? credential;
  final String? transactionId;

  const Oid4vciCredentialResponse({
    this.format,
    this.credential,
    this.transactionId,
  });
}

class PresentationRequest {
  final String clientId;
  final String nonce;
  final String responseUri;
  final String queryType;
  final String? presentationDefinitionJson;
  final String? dcqlQueryJson;

  const PresentationRequest({
    required this.clientId,
    required this.nonce,
    required this.responseUri,
    required this.queryType,
    this.presentationDefinitionJson,
    this.dcqlQueryJson,
  });
}

class ZkProofEntry {
  final String descriptorId;
  final String predicateId;
  final Uint8List proofBytes;

  const ZkProofEntry({
    required this.descriptorId,
    required this.predicateId,
    required this.proofBytes,
  });
}

class PresentationResult {
  final bool ok;
  final String? redirectUri;
  final String? error;
  final String? errorDescription;

  const PresentationResult({
    required this.ok,
    this.redirectUri,
    this.error,
    this.errorDescription,
  });
}

// ============================================================================
// Service
// ============================================================================

/// Wallet service for OID4VCI credential issuance and OID4VP presentation.
///
/// All heavy lifting is delegated to the Rust `marty-oid4vci` crate via the
/// flutter_rust_bridge FFI layer.
class OID4VCService {
  const OID4VCService();

  // --------------------------------------------------------------------------
  // Credential offer
  // --------------------------------------------------------------------------

  /// Parse a `openid-credential-offer://` URI or `https://…?credential_offer=…` URL.
  Future<CredentialOffer> parseCredentialOffer(String offerUri) async {
    Logger.info('Parsing credential offer URI', name: 'OID4VCService');
    final normalizedOfferUri = normalizeOid4vciCredentialOfferUri(offerUri);
    final r = await walletParseCredentialOffer(offerUri: normalizedOfferUri);
    return CredentialOffer(
      credentialIssuer: r.credentialIssuer,
      credentialConfigurationIds: r.credentialConfigurationIds,
      preAuthorizedCode: r.preAuthorizedCode,
      txCodeRequired: r.txCodeRequired,
      issuerState: r.issuerState,
    );
  }

  // --------------------------------------------------------------------------
  // Issuer metadata
  // --------------------------------------------------------------------------

  /// Fetch `.well-known/openid-credential-issuer` for [issuerUrl].
  Future<IssuerMetadata> fetchIssuerMetadata(String issuerUrl) async {
    Logger.info('Fetching issuer metadata', name: 'OID4VCService');
    final r = await walletFetchIssuerMetadata(issuerUrl: issuerUrl);
    return IssuerMetadata(
      credentialIssuer: r.credentialIssuer,
      tokenEndpoint: r.tokenEndpoint,
      credentialEndpoint: r.credentialEndpoint,
      authorizationEndpoint: r.authorizationEndpoint,
      grantTypesSupported: r.grantTypesSupported,
      credentialConfigurationsJson: r.credentialConfigurationsJson,
    );
  }

  // --------------------------------------------------------------------------
  // Token exchange — pre-authorized code flow
  // --------------------------------------------------------------------------

  /// Exchange a pre-authorized code for an access token.
  ///
  /// Pass [txCode] when the credential offer required a transaction PIN.
  Future<Oid4vciTokenResponse> exchangePreAuthToken(
    String tokenEndpoint,
    String preAuthCode, {
    String? txCode,
  }) async {
    Logger.info('Exchanging pre-auth code', name: 'OID4VCService');
    final r = await walletExchangePreAuthToken(
      tokenEndpoint: tokenEndpoint,
      preAuthCode: preAuthCode,
      txCode: txCode,
    );
    return _tokenFromFrb(r);
  }

  // --------------------------------------------------------------------------
  // Authorization-code + PKCE flow
  // --------------------------------------------------------------------------

  /// Build the PKCE authorization request.
  ///
  /// Store [AuthorizationSession.codeVerifier] securely and pass to
  /// [exchangeAuthCodeToken] when the redirect arrives.
  AuthorizationSession buildAuthRequest({
    required IssuerMetadata issuerMetadata,
    required String credentialConfigurationId,
    required String clientId,
    required String redirectUri,
    String? issuerState,
  }) {
    // walletBuildAuthRequest is sync in Rust, FRB wraps in Future;
    // use buildAuthRequestAsync() to await the result.
    throw UnimplementedError(
      'Use await buildAuthRequestAsync() — '
      'walletBuildAuthRequest returns a Future in Dart.',
    );
  }

  /// Async version of [buildAuthRequest].
  Future<AuthorizationSession> buildAuthRequestAsync({
    required IssuerMetadata issuerMetadata,
    required String credentialConfigurationId,
    required String clientId,
    required String redirectUri,
    String? issuerState,
  }) async {
    final r = await walletBuildAuthRequest(
      issuerMetadataJson: jsonEncode(issuerMetadata.toMap()),
      credentialConfigurationId: credentialConfigurationId,
      clientId: clientId,
      redirectUri: redirectUri,
      issuerState: issuerState,
    );
    return AuthorizationSession(
      authorizationUrl: r.authorizationUrl,
      codeVerifier: r.codeVerifier,
      state: r.state,
      redirectUri: r.redirectUri,
    );
  }

  /// Exchange an authorization code for an access token.
  Future<Oid4vciTokenResponse> exchangeAuthCodeToken(
    String tokenEndpoint,
    String code,
    String codeVerifier, {
    String? redirectUri,
    String? clientId,
  }) async {
    Logger.info('Exchanging auth code', name: 'OID4VCService');
    final r = await walletExchangeAuthCodeToken(
      tokenEndpoint: tokenEndpoint,
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
      clientId: clientId,
    );
    return _tokenFromFrb(r);
  }

  /// Discover and call the OID4VCI Final Nonce Endpoint.
  Future<String> fetchNonceForIssuer(String issuerUrl) async {
    final issuer = Uri.parse(issuerUrl);
    final metadataUri = issuer.replace(
      path: '/.well-known/openid-credential-issuer${issuer.path}',
      query: null,
      fragment: null,
    );
    final metadataResponse = await http.get(
      metadataUri,
      headers: const {'Accept': 'application/json'},
    );
    if (metadataResponse.statusCode != 200) {
      throw StateError(
        'Issuer metadata returned HTTP ${metadataResponse.statusCode}',
      );
    }
    final metadata = jsonDecode(metadataResponse.body) as Map<String, dynamic>;
    final nonceEndpoint = metadata['nonce_endpoint'] as String?;
    if (nonceEndpoint == null || nonceEndpoint.isEmpty) {
      throw StateError('Issuer metadata does not advertise nonce_endpoint');
    }
    final nonceResponse = await http.post(
      Uri.parse(nonceEndpoint),
      headers: const {'Content-Type': 'application/json'},
      body: '{}',
    );
    if (nonceResponse.statusCode != 200) {
      throw StateError(
        'Nonce endpoint returned HTTP ${nonceResponse.statusCode}',
      );
    }
    final body = jsonDecode(nonceResponse.body) as Map<String, dynamic>;
    final nonce = body['c_nonce'] as String?;
    if (nonce == null || nonce.isEmpty) {
      throw StateError('Nonce endpoint returned no c_nonce');
    }
    return nonce;
  }

  // --------------------------------------------------------------------------
  // Credential request
  // --------------------------------------------------------------------------

  /// Create an `openid4vci-proof+jwt` proof of possession.
  String createProofJwt({
    required String holderKid,
    required String cNonce,
    required String issuerUrl,
    required String jwkJson,
  }) {
    // walletCreateProofJwt is sync in Rust — use createProofJwtAsync for the
    // Future-based FRB wrapper.
    throw UnimplementedError('Use await createProofJwtAsync()');
  }

  Future<String> createProofJwtAsync({
    required String holderKid,
    required String cNonce,
    required String issuerUrl,
    required String jwkJson,
  }) => walletCreateProofJwt(
    holderKid: holderKid,
    cNonce: cNonce,
    issuerUrl: issuerUrl,
    jwkJson: jwkJson,
  );

  /// Request a credential from the issuer's credential endpoint.
  Future<Oid4vciCredentialResponse> requestCredential({
    required String credentialEndpoint,
    required String accessToken,
    required String credentialFormat,
    String? credentialConfigurationId,
    required String proofJwt,
  }) async {
    Logger.info('Requesting credential', name: 'OID4VCService');
    final r = await walletRequestCredential(
      credentialEndpoint: credentialEndpoint,
      accessToken: accessToken,
      credentialFormat: credentialFormat,
      credentialConfigurationId: credentialConfigurationId,
      proofJwt: proofJwt,
    );
    return Oid4vciCredentialResponse(
      format: r.format,
      credential: r.credential,
      transactionId: r.transactionId,
    );
  }

  // --------------------------------------------------------------------------
  // OID4VP — Presentation
  // --------------------------------------------------------------------------

  /// Parse an `openid4vp://` or `https://…` presentation request URI.
  Future<PresentationRequest> parsePresentationRequest(
    String requestUri,
  ) async {
    Logger.info('Parsing presentation request', name: 'OID4VCService');
    final r = await walletParsePresentationRequest(requestUri: requestUri);
    return PresentationRequest(
      clientId: r.clientId,
      nonce: r.nonce,
      responseUri: r.responseUri,
      queryType: r.queryType,
      presentationDefinitionJson: r.presentationDefinitionJson,
      dcqlQueryJson: r.dcqlQueryJson,
    );
  }

  /// Build and submit a standard (non-ZK) VP presentation.
  ///
  /// [credentialsJson] — JSON object mapping descriptor ID → credential string.
  Future<PresentationResult> buildAndSubmitPresentation({
    required String responseUri,
    String? presentationDefinitionJson,
    String? dcqlQueryJson,
    required String credentialsJson,
  }) async {
    Logger.info('Submitting VP presentation', name: 'OID4VCService');
    if (presentationDefinitionJson == null && dcqlQueryJson == null) {
      throw ArgumentError(
        'Either presentationDefinitionJson or dcqlQueryJson is required.',
      );
    }
    final r = await walletBuildAndSubmitPresentation(
      responseUri: responseUri,
      presentationDefinitionJson: presentationDefinitionJson,
      dcqlQueryJson: dcqlQueryJson,
      credentialsJson: credentialsJson,
    );
    return _presentationResultFromFrb(r);
  }

  /// Build and submit a ZK VP presentation.
  ///
  /// Generate [zkProofs] with [zk_prove] before calling this method.
  Future<PresentationResult> buildAndSubmitZkPresentation({
    required String responseUri,
    required String presentationDefinitionJson,
    required String credentialsJson,
    required List<ZkProofEntry> zkProofs,
  }) async {
    Logger.info('Submitting ZK VP presentation', name: 'OID4VCService');
    final frbProofs = zkProofs
        .map(
          (p) => FrbZkProofEntry(
            descriptorId: p.descriptorId,
            predicateId: p.predicateId,
            proofBytes: p.proofBytes,
          ),
        )
        .toList();
    final r = await walletBuildAndSubmitZkPresentation(
      responseUri: responseUri,
      presentationDefinitionJson: presentationDefinitionJson,
      credentialsJson: credentialsJson,
      zkProofs: frbProofs,
    );
    return _presentationResultFromFrb(r);
  }

  // --------------------------------------------------------------------------
  // Private helpers
  // --------------------------------------------------------------------------

  Oid4vciTokenResponse _tokenFromFrb(FrbTokenResponse t) =>
      Oid4vciTokenResponse(
        accessToken: t.accessToken,
        tokenType: t.tokenType,
        expiresIn: t.expiresIn?.toInt(),
        scope: t.scope,
      );

  PresentationResult _presentationResultFromFrb(FrbPresentationResponse r) =>
      PresentationResult(
        ok: r.ok,
        redirectUri: r.redirectUri,
        error: r.error,
        errorDescription: r.errorDescription,
      );
}
