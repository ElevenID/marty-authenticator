import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/spruce_interfaces.dart';
import 'wasm/marty_wasm.dart';
import '../utils/logger.dart';

/// Web implementation of SpruceID platform service
/// Uses WASM bindings for real cryptographic operations
class SpruceIdPlatformServiceWeb implements ISpruceIdPlatformService {
  final MartyWasm _wasm = MartyWasm.instance;
  bool _initialized = false;

  // Simple in-memory storage for web session
  final List<Map<String, dynamic>> _storedCredentials = [];

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initializeW3C() async {
    if (!_initialized) {
      try {
        await _wasm.initialize();
        _initialized = true;
        Logger.info('SpruceIdPlatformServiceWeb: WASM initialized');
      } catch (e) {
        Logger.error(
          'SpruceIdPlatformServiceWeb: WASM initialization failed',
          error: e,
        );
        rethrow;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> createDid({String method = 'key'}) async {
    await initializeW3C();

    if (method == 'key') {
      // Ed25519 -> did:key
      final result = await _wasm.generateEd25519Key();
      return {
        'did': result.did,
        'keyId': result.keyId,
        'keys': [result.jwk], // Return as list of keys
        'verificationMethod': result.did, // Simplified
      };
    } else if (method == 'jwk') {
      // P-256 -> did:jwk
      final result = await _wasm.generateP256Key();
      return {
        'did': result.did,
        'keyId': result.keyId,
        'keys': [result.jwk],
        'verificationMethod': result.did,
      };
    }

    throw UnimplementedError('DID method "$method" not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> resolveDid(String did) async {
    throw UnimplementedError('resolveDid not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> signVerifiableCredential(
    Map<String, dynamic> credential, {
    String? keyId,
  }) async {
    // This requires issuer DID and key, which should be managed.
    // For now, on web we often just issue using the WASM createVerifiableCredential directly
    // but that API requires passing issuerDid and jwk.
    // The interface here assumes the service manages the keys (implied by just passing credential).
    throw UnimplementedError(
      'signVerifiableCredential with managed keys not supported on Web',
    );
  }

  @override
  Future<Map<String, dynamic>> verifyVerifiableCredential(
    Map<String, dynamic> credential,
  ) async {
    // WASM verifyJwtClaims?
    throw UnimplementedError('verifyVerifiableCredential not supported on Web');
  }

  // PKI/X.509 Methods
  @override
  Future<Map<String, dynamic>> generateKeyPair({
    String keyType = 'RSA',
    int keySize = 2048,
  }) async {
    await initializeW3C();
    if (keyType == 'EC' || keyType == 'P-256') {
      final res = await _wasm.generateP256Key();
      return {
        'publicKey': res.jwk,
        'privateKey': res.jwk,
        'keyId': res.keyId,
        'type': 'EC',
      };
    }
    // RSA not supported in WASM subset
    throw UnimplementedError('Key type "$keyType" not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> createCSR(
    String subject, {
    String? keyId,
  }) async {
    throw UnimplementedError('createCSR not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> signWithCertificate(
    Map<String, dynamic> document,
    String certificateId,
  ) async {
    throw UnimplementedError('signWithCertificate not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> verifyCertificateChain(
    List<String> certificateChain,
  ) async {
    throw UnimplementedError('verifyCertificateChain not supported on Web');
  }

  // JWT Methods
  @override
  Future<Map<String, dynamic>> createJWT(
    String issuer,
    Map<String, dynamic> claims,
  ) async {
    throw UnimplementedError('createJWT not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> verifyJWT(String jwt, String issuer) async {
    await initializeW3C();
    final res = await _wasm.verifyJwtClaims(
      jwt: jwt,
      expectedIssuer: issuer.isNotEmpty ? issuer : null,
    );

    if (!res.valid) {
      throw Exception('JWT verification failed: ${res.error}');
    }

    return res.payload ?? {};
  }

  @override
  Future<Map<String, dynamic>> createSdJwt(
    String issuer,
    Map<String, dynamic> claims,
    List<String> selectivelyDisclosableClaims,
  ) async {
    throw UnimplementedError('createSdJwt not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> verifySdJwt(
    String sdJwt,
    List<String> requiredClaims,
  ) async {
    // Basic verification of the JWT part for now
    final jwt = sdJwt.split('~')[0];
    return verifyJWT(jwt, '');
  }

  // mDoc Methods
  @override
  Future<Map<String, dynamic>> initializeMdl(
    Map<String, dynamic> mdlData,
  ) async {
    throw UnimplementedError('initializeMdl not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> presentForAgeVerification(int minimumAge) async {
    throw UnimplementedError('presentForAgeVerification not supported on Web');
  }

  @override
  Future<Map<String, dynamic>> createMdocResponse(
    List<String> requestedAttributes,
    List<String> hiddenAttributes,
  ) async {
    throw UnimplementedError('createMdocResponse not supported on Web');
  }

  // Wallet Methods
  @override
  Future<void> storeCredential(Map<String, dynamic> credential) async {
    _storedCredentials.add(credential);
  }

  @override
  Future<List<Map<String, dynamic>>> getStoredCredentials() async {
    return List.from(_storedCredentials);
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return _storedCredentials
        .where(
          (c) =>
              c['type'] == type ||
              (c['type'] is List && (c['type'] as List).contains(type)),
        )
        .toList();
  }

  @override
  Future<void> deleteCredential(String id) async {
    _storedCredentials.removeWhere((c) => c['id'] == id);
  }
}
