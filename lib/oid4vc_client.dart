/// Flutter OID4VC Integration Library
/// Provides client-side support for OpenID for Verifiable Credentials
///
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'utils/logger.dart';

class OID4VCClient {
  final String baseUrl;
  final String? clientId;
  final Duration timeout;

  OID4VCClient({
    required this.baseUrl,
    this.clientId,
    this.timeout = const Duration(seconds: 30),
  });

  /// Parse a credential offer from URL or QR code
  Future<CredentialOffer?> parseCredentialOffer(String offerUri) async {
    try {
      final uri = Uri.parse(offerUri);

      if (uri.scheme == 'openid-credential-offer') {
        // Parse credential offer from query parameters
        final offerParam = uri.queryParameters['credential_offer'];
        if (offerParam != null) {
          final decoded = base64Decode(offerParam);
          final offerData = jsonDecode(utf8.decode(decoded));
          return CredentialOffer.fromJson(offerData);
        }
      } else if (uri.scheme.startsWith('http')) {
        // Fetch credential offer from HTTP URL
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final offerData = jsonDecode(response.body);
          return CredentialOffer.fromJson(offerData);
        }
      }

      return null;
    } catch (e) {
      Logger.error('Error parsing credential offer', error: e);
      return null;
    }
  }

  /// Request credentials using pre-authorized code flow
  Future<CredentialResponse?> requestCredentialWithPreAuthCode({
    required CredentialOffer offer,
    required String preAuthCode,
    String? userPin,
  }) async {
    try {
      // Get issuer metadata
      final issuerMetadata = await _getIssuerMetadata(offer.credentialIssuer);
      if (issuerMetadata == null) return null;

      // Exchange pre-authorized code for access token
      final tokenResponse = await _exchangePreAuthCode(
        issuerMetadata.tokenEndpoint,
        preAuthCode,
        userPin,
      );

      if (tokenResponse == null) return null;

      // Request credential with access token
      return await _requestCredential(
        issuerMetadata.credentialEndpoint,
        tokenResponse.accessToken,
        offer.credentials.first,
      );
    } catch (e) {
      Logger.error('Error requesting credential', error: e);
      return null;
    }
  }

  /// Create a verifiable presentation for authentication
  Future<String?> createPresentation({
    required List<String> credentials,
    required String challenge,
    required String domain,
    List<String>? requiredCredentialTypes,
  }) async {
    try {
      // Create presentation wrapper
      final presentation = {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiablePresentation'],
        'id': 'urn:uuid:${const Uuid().v4()}',
        'holder': await _getHolderDid(),
        'verifiableCredential': credentials.map((c) => jsonDecode(c)).toList(),
        'proof': await _createPresentationProof(challenge, domain),
      };

      return jsonEncode(presentation);
    } catch (e) {
      Logger.error('Error creating presentation', error: e);
      return null;
    }
  }

  /// Authenticate with privacyIDEA using verifiable presentation
  Future<AuthenticationResult?> authenticateWithPresentation({
    required String username,
    required String pin,
    required String presentation,
    String? realm,
  }) async {
    try {
      final authData = {
        'user': realm != null ? '$username@$realm' : username,
        'pass': '$pin$presentation',
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/validate/check'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: authData,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return AuthenticationResult.fromJson(result);
      }

      return null;
    } catch (e) {
      Logger.error('Error authenticating', error: e);
      return null;
    }
  }

  /// Get issuer metadata from well-known endpoint
  Future<IssuerMetadata?> _getIssuerMetadata(String issuerUrl) async {
    try {
      final metadataUrl = '$issuerUrl/.well-known/openid_credential_issuer';
      final response = await http.get(Uri.parse(metadataUrl)).timeout(timeout);

      if (response.statusCode == 200) {
        final metadata = jsonDecode(response.body);
        return IssuerMetadata.fromJson(metadata);
      }

      return null;
    } catch (e) {
      Logger.error('Error getting issuer metadata', error: e);
      return null;
    }
  }

  /// Exchange pre-authorized code for access token
  Future<TokenResponse?> _exchangePreAuthCode(
    String tokenEndpoint,
    String preAuthCode,
    String? userPin,
  ) async {
    try {
      final body = {
        'grant_type': 'urn:ietf:params:oauth:grant-type:pre-authorized_code',
        'pre-authorized_code': preAuthCode,
      };

      if (userPin != null) {
        body['user_pin'] = userPin;
      }

      final response = await http
          .post(
            Uri.parse(tokenEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        return TokenResponse.fromJson(tokenData);
      }

      return null;
    } catch (e) {
      Logger.error('Error exchanging pre-auth code', error: e);
      return null;
    }
  }

  /// Request credential from issuer
  Future<CredentialResponse?> _requestCredential(
    String credentialEndpoint,
    String accessToken,
    Map<String, dynamic> credentialDefinition,
  ) async {
    try {
      final requestBody = {
        'format': credentialDefinition['format'] ?? 'jwt_vc_json',
        'credential_definition': {
          'type': credentialDefinition['types'] ?? ['VerifiableCredential'],
        },
        'proof': await _createCredentialProof(accessToken),
      };

      final response = await http
          .post(
            Uri.parse(credentialEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final credentialData = jsonDecode(response.body);
        return CredentialResponse.fromJson(credentialData);
      }

      return null;
    } catch (e) {
      Logger.error('Error requesting credential', error: e);
      return null;
    }
  }

  /// Create proof for credential request
  Future<Map<String, dynamic>> _createCredentialProof(
    String accessToken,
  ) async {
    // In practice, create proper cryptographic proof
    // This is simplified for demonstration
    return {
      'proof_type': 'jwt',
      'jwt': 'dummy_jwt_proof', // Replace with actual JWT proof
    };
  }

  /// Create proof for verifiable presentation
  Future<Map<String, dynamic>> _createPresentationProof(
    String challenge,
    String domain,
  ) async {
    // In practice, create proper cryptographic proof
    // This is simplified for demonstration
    return {
      'type': 'Ed25519Signature2020',
      'created': DateTime.now().toIso8601String(),
      'verificationMethod': await _getVerificationMethod(),
      'proofPurpose': 'authentication',
      'challenge': challenge,
      'domain': domain,
      'proofValue': 'dummy_signature', // Replace with actual signature
    };
  }

  /// Get holder DID
  Future<String> _getHolderDid() async {
    // In practice, derive from wallet's key material
    return 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
  }

  /// Get verification method for proofs
  Future<String> _getVerificationMethod() async {
    final holderDid = await _getHolderDid();
    return '$holderDid#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
  }
}

/// Data classes for OID4VC workflow

class CredentialOffer {
  final String credentialIssuer;
  final List<Map<String, dynamic>> credentials;
  final Map<String, dynamic>? grants;

  CredentialOffer({
    required this.credentialIssuer,
    required this.credentials,
    this.grants,
  });

  factory CredentialOffer.fromJson(Map<String, dynamic> json) {
    return CredentialOffer(
      credentialIssuer: json['credential_issuer'],
      credentials: List<Map<String, dynamic>>.from(json['credentials']),
      grants: json['grants'],
    );
  }
}

class IssuerMetadata {
  final String credentialIssuer;
  final String credentialEndpoint;
  final String tokenEndpoint;
  final List<String> credentialConfigurationsSupported;

  IssuerMetadata({
    required this.credentialIssuer,
    required this.credentialEndpoint,
    required this.tokenEndpoint,
    required this.credentialConfigurationsSupported,
  });

  factory IssuerMetadata.fromJson(Map<String, dynamic> json) {
    return IssuerMetadata(
      credentialIssuer: json['credential_issuer'],
      credentialEndpoint: json['credential_endpoint'],
      tokenEndpoint: json['token_endpoint'],
      credentialConfigurationsSupported: List<String>.from(
        json['credential_configurations_supported'] ?? [],
      ),
    );
  }
}

class TokenResponse {
  final String accessToken;
  final String tokenType;
  final int? expiresIn;

  TokenResponse({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
    );
  }
}

class CredentialResponse {
  final String? credential;
  final String? acceptanceToken;
  final String? cNonce;
  final int? cNonceExpiresIn;

  CredentialResponse({
    this.credential,
    this.acceptanceToken,
    this.cNonce,
    this.cNonceExpiresIn,
  });

  factory CredentialResponse.fromJson(Map<String, dynamic> json) {
    return CredentialResponse(
      credential: json['credential'],
      acceptanceToken: json['acceptance_token'],
      cNonce: json['c_nonce'],
      cNonceExpiresIn: json['c_nonce_expires_in'],
    );
  }
}

class AuthenticationResult {
  final bool result;
  final String? detail;
  final String? message;

  AuthenticationResult({required this.result, this.detail, this.message});

  factory AuthenticationResult.fromJson(Map<String, dynamic> json) {
    return AuthenticationResult(
      result: json['result']['value'] ?? false,
      detail: json['detail']?.toString(),
      message: json['detail']?['message'],
    );
  }
}
