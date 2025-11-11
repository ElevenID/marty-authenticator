import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for integrating with SpruceID backend APIs
/// This provides server-side SSI operations for the authenticator app
class SpruceIdBackendService {
  final String baseUrl;
  final http.Client _client;

  SpruceIdBackendService({
    this.baseUrl = 'http://localhost:5000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Health check for the backend service
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Health check error: $e');
    }
  }

  /// Create a new DID using the backend service
  Future<Map<String, dynamic>> createDid({
    String method = 'key',
    Map<String, dynamic>? options,
  }) async {
    try {
      final requestBody = {
        'method': method,
        if (options != null) 'options': options,
      };

      final response = await _client.post(
        Uri.parse('$baseUrl/did/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('DID creation failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('DID creation error: $e');
    }
  }

  /// Sign a verifiable credential
  Future<Map<String, dynamic>> signCredential({
    required Map<String, dynamic> credential,
    required dynamic keyJwk,
    required String verificationMethod,
  }) async {
    try {
      final requestBody = {
        'credential': credential,
        'keyJwk': keyJwk,
        'verificationMethod': verificationMethod,
      };

      final response = await _client.post(
        Uri.parse('$baseUrl/credential/sign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('Credential signing failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('Credential signing error: $e');
    }
  }

  /// Verify a verifiable credential
  Future<Map<String, dynamic>> verifyCredential({
    required Map<String, dynamic> credential,
  }) async {
    try {
      final requestBody = {'credential': credential};

      final response = await _client.post(
        Uri.parse('$baseUrl/credential/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('Credential verification failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('Credential verification error: $e');
    }
  }

  /// Create an mDoc (Mobile Document)
  Future<Map<String, dynamic>> createMDoc({
    String docType = 'org.iso.18013.5.1.mDL',
    required Map<String, dynamic> issuerSignedItems,
    Map<String, dynamic>? issuerAuth,
  }) async {
    try {
      final requestBody = {
        'docType': docType,
        'issuerSignedItems': issuerSignedItems,
        'issuerAuth': issuerAuth ?? {},
      };

      final response = await _client.post(
        Uri.parse('$baseUrl/mdoc/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('mDoc creation failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('mDoc creation error: $e');
    }
  }

  /// Verify age from an mDoc
  Future<Map<String, dynamic>> verifyAge({
    required String mdocBase64,
    int minimumAge = 18,
  }) async {
    try {
      final requestBody = {'mdoc': mdocBase64, 'minimumAge': minimumAge};

      final response = await _client.post(
        Uri.parse('$baseUrl/age/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('Age verification failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('Age verification error: $e');
    }
  }

  /// Create an SD-JWT (Selective Disclosure JWT)
  Future<Map<String, dynamic>> createSdJwt({
    required Map<String, dynamic> claims,
    required List<String> disclosableClaims,
    required dynamic issuerKey,
  }) async {
    try {
      final requestBody = {
        'claims': claims,
        'disclosableClaims': disclosableClaims,
        'issuerKey': issuerKey,
      };

      final response = await _client.post(
        Uri.parse('$baseUrl/sd-jwt/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('SD-JWT creation failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('SD-JWT creation error: $e');
    }
  }

  /// Verify an SD-JWT
  Future<Map<String, dynamic>> verifySdJwt({
    required String sdJwt,
    required dynamic issuerPublicKey,
  }) async {
    try {
      final requestBody = {'sdJwt': sdJwt, 'issuerPublicKey': issuerPublicKey};

      final response = await _client.post(
        Uri.parse('$baseUrl/sd-jwt/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception('SD-JWT verification failed: ${error['error']}');
      }
    } catch (e) {
      throw Exception('SD-JWT verification error: $e');
    }
  }

  /// Helper method to encode bytes as base64 for API calls
  String bytesToBase64(Uint8List bytes) {
    return base64.encode(bytes);
  }

  /// Helper method to decode base64 to bytes from API responses
  Uint8List base64ToBytes(String base64String) {
    return base64.decode(base64String);
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}

/// SpruceID backend integration models for type safety
class SpruceDidResult {
  final String did;
  final Map<String, dynamic>? keyJwk;
  final String? verificationMethod;
  final String? keyId;
  final DateTime? created;
  final String status;
  final String? warning;

  const SpruceDidResult({
    required this.did,
    this.keyJwk,
    this.verificationMethod,
    this.keyId,
    this.created,
    required this.status,
    this.warning,
  });

  factory SpruceDidResult.fromJson(Map<String, dynamic> json) {
    return SpruceDidResult(
      did: json['did'] as String,
      keyJwk: json['keyJwk'] as Map<String, dynamic>?,
      verificationMethod: json['verificationMethod'] as String?,
      keyId: json['keyId'] as String?,
      created: json['created'] != null ? DateTime.parse(json['created']) : null,
      status: json['status'] as String,
      warning: json['warning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'did': did,
      if (keyJwk != null) 'keyJwk': keyJwk,
      if (verificationMethod != null) 'verificationMethod': verificationMethod,
      if (keyId != null) 'keyId': keyId,
      if (created != null) 'created': created!.toIso8601String(),
      'status': status,
      if (warning != null) 'warning': warning,
    };
  }
}

class SpruceCredentialResult {
  final Map<String, dynamic> credential;
  final bool signed;
  final DateTime? signedAt;
  final String status;
  final String? warning;

  const SpruceCredentialResult({
    required this.credential,
    required this.signed,
    this.signedAt,
    required this.status,
    this.warning,
  });

  factory SpruceCredentialResult.fromJson(Map<String, dynamic> json) {
    return SpruceCredentialResult(
      credential: json['credential'] as Map<String, dynamic>,
      signed: json['signed'] as bool,
      signedAt: json['signedAt'] != null
          ? DateTime.parse(json['signedAt'])
          : null,
      status: json['status'] as String,
      warning: json['warning'] as String?,
    );
  }
}

class SpruceVerificationResult {
  final bool valid;
  final List<String> errors;
  final DateTime? verifiedAt;
  final String status;
  final String? warning;

  const SpruceVerificationResult({
    required this.valid,
    this.errors = const [],
    this.verifiedAt,
    required this.status,
    this.warning,
  });

  factory SpruceVerificationResult.fromJson(Map<String, dynamic> json) {
    return SpruceVerificationResult(
      valid: json['valid'] as bool,
      errors: List<String>.from(json['errors'] ?? []),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
      status: json['status'] as String,
      warning: json['warning'] as String?,
    );
  }
}

class SpruceAgeVerificationResult {
  final bool verified;
  final int minimumAge;
  final int? calculatedAge;
  final String? method;
  final DateTime? verifiedAt;
  final String status;
  final String? error;

  const SpruceAgeVerificationResult({
    required this.verified,
    required this.minimumAge,
    this.calculatedAge,
    this.method,
    this.verifiedAt,
    required this.status,
    this.error,
  });

  factory SpruceAgeVerificationResult.fromJson(Map<String, dynamic> json) {
    return SpruceAgeVerificationResult(
      verified: json['verified'] as bool,
      minimumAge: json['minimumAge'] as int,
      calculatedAge: json['calculatedAge'] as int?,
      method: json['method'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
      status: json['status'] as String,
      error: json['error'] as String?,
    );
  }
}

/// Global instance for easy access throughout the app
final spruceBackendService = SpruceIdBackendService();
