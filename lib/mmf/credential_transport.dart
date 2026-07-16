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

import 'dart:typed_data';

/// MMF Credential Transport Interface.
///
/// Provides credential exchange protocol operations. This is an MMF
/// infrastructure interface - handles the transport layer for credential
/// issuance (OID4VCI) and presentation (OID4VP) flows.
///
/// The transport layer is credential-agnostic - it handles protocol messages
/// but doesn't interpret credential contents. Marty parses and validates
/// credentials using its Rust layer.
abstract class ICredentialTransport {
  // ============================================================================
  // OID4VCI - Credential Issuance
  // ============================================================================

  /// Initiate credential issuance from a credential offer.
  ///
  /// Returns the authorization URL for the user to complete authentication.
  Future<IssuanceSession> initiateIssuance(String credentialOfferUri);

  /// Complete the authorization step with the auth code.
  Future<TokenResponse> completeAuthorization({
    required IssuanceSession session,
    required String authorizationCode,
  });

  /// Request credential issuance.
  ///
  /// Returns raw credential data that Marty's Rust layer will parse.
  Future<CredentialResponse> requestCredential({
    required IssuanceSession session,
    required TokenResponse tokens,
    required String credentialType,
    Uint8List? proofJwt,
  });

  /// Request batch credential issuance.
  Future<List<CredentialResponse>> requestBatchCredentials({
    required IssuanceSession session,
    required TokenResponse tokens,
    required List<String> credentialTypes,
    Uint8List? proofJwt,
  });

  // ============================================================================
  // OID4VP - Credential Presentation
  // ============================================================================

  /// Parse a presentation request.
  Future<PresentationRequest> parsePresentationRequest(String requestUri);

  /// Create and submit a verifiable presentation.
  ///
  /// Takes raw credential data (as JSON or CBOR) and creates the presentation.
  Future<PresentationResponse> submitPresentation({
    required PresentationRequest request,
    required List<CredentialSubmission> credentials,
    Uint8List? holderKeyProof,
  });

  // ============================================================================
  // BLE/NFC Transport (ISO 18013-5)
  // ============================================================================

  /// Start BLE peripheral mode for mDoc presentation.
  Future<void> startBlePresentation({
    required Uint8List deviceEngagement,
    required Function(PresentationRequest) onRequest,
    required Function(String) onError,
  });

  /// Stop BLE peripheral mode.
  Future<void> stopBlePresentation();

  /// Check if NFC is available.
  Future<bool> isNfcAvailable();

  /// Start NFC reader mode for mDoc verification.
  Future<void> startNfcReader({
    required Function(Uint8List) onDeviceEngagement,
    required Function(String) onError,
  });

  /// Stop NFC reader mode.
  Future<void> stopNfcReader();
}

/// Session state for credential issuance.
class IssuanceSession {
  /// Unique session identifier
  final String sessionId;

  /// Credential issuer URL
  final String issuerUrl;

  /// Authorization endpoint
  final String authorizationEndpoint;

  /// Token endpoint
  final String tokenEndpoint;

  /// Credential endpoint
  final String credentialEndpoint;

  /// Available credential types
  final List<String> credentialTypes;

  /// Code verifier for PKCE
  final String codeVerifier;

  /// State parameter
  final String state;

  const IssuanceSession({
    required this.sessionId,
    required this.issuerUrl,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.credentialEndpoint,
    required this.credentialTypes,
    required this.codeVerifier,
    required this.state,
  });
}

/// OAuth token response.
class TokenResponse {
  /// Access token
  final String accessToken;

  /// Token type (usually "Bearer")
  final String tokenType;

  /// Expiration time in seconds
  final int? expiresIn;

  /// Refresh token, if provided
  final String? refreshToken;

  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.refreshToken,
  });
}

/// Raw credential response from issuer.
class CredentialResponse {
  /// Credential format (jwt_vc_json, ldp_vc, mso_mdoc, etc.)
  final String format;

  /// Raw credential data (to be parsed by Marty Rust layer)
  final dynamic credential;

  /// Transaction ID for deferred issuance
  final String? transactionId;

  const CredentialResponse({
    required this.format,
    required this.credential,
    this.transactionId,
  });
}

/// Parsed presentation request.
class PresentationRequest {
  /// Request ID
  final String id;

  /// Verifier/relying party info
  final String verifierId;

  /// Verifier display name
  final String? verifierName;

  /// Requested credential types
  final List<RequestedCredential> requestedCredentials;

  /// Response URI for submission
  final String responseUri;

  /// Nonce/challenge
  final String nonce;

  /// Presentation definition (raw)
  final Map<String, dynamic>? presentationDefinition;

  /// DCQL query (raw)
  final Map<String, dynamic>? dcqlQuery;

  /// The original credential query shape (`presentation_definition` or `dcql_query`).
  final String? queryType;

  const PresentationRequest({
    required this.id,
    required this.verifierId,
    this.verifierName,
    required this.requestedCredentials,
    required this.responseUri,
    required this.nonce,
    this.presentationDefinition,
    this.dcqlQuery,
    this.queryType,
  });
}

/// A single requested credential in a presentation request.
class RequestedCredential {
  /// Credential type
  final String type;

  /// Required attributes
  final List<String> requiredAttributes;

  /// Optional attributes
  final List<String> optionalAttributes;

  /// Credential format constraints
  final List<String>? formats;

  const RequestedCredential({
    required this.type,
    required this.requiredAttributes,
    this.optionalAttributes = const [],
    this.formats,
  });
}

/// Credential submission for presentation.
class CredentialSubmission {
  /// Credential format
  final String format;

  /// Raw credential data (JSON or CBOR bytes)
  final dynamic credentialData;

  /// Attributes to disclose (for selective disclosure)
  final List<String>? disclosedAttributes;

  const CredentialSubmission({
    required this.format,
    required this.credentialData,
    this.disclosedAttributes,
  });
}

/// Response from presentation submission.
class PresentationResponse {
  /// Whether the presentation was accepted
  final bool accepted;

  /// Redirect URL, if any
  final String? redirectUrl;

  /// Error message, if rejected
  final String? error;

  const PresentationResponse({
    required this.accepted,
    this.redirectUrl,
    this.error,
  });
}
