/// SpruceID Flutter Client Library
/// Real implementation using platform channels with SpruceKit Mobile SDK
library;

import 'dart:async';
import 'services/spruce_platform_service.dart';

/// SpruceID client for Flutter integration with real platform channels
///
/// Provides integration with SpruceID services for:
/// - OID4VC workflows
/// - mDoc/MDL authentication
/// - SD-JWT selective disclosure
/// - Verifiable credential management
class SpruceIdClient {
  final SpruceIdPlatformService _platformService;

  SpruceIdClient() : _platformService = SpruceIdPlatformService();

  /// Initialize SpruceID client
  Future<void> initialize() async {
    await _platformService.initializeW3C();
  }

  /// Create a new DID using SpruceID (W3C VC technology)
  Future<String> createDid({String method = 'key'}) async {
    final result = await _platformService.createDid(method: method);
    return result['did'] as String;
  }

  /// Sign a verifiable credential (W3C VC technology)
  Future<Map<String, dynamic>> signCredential(
    Map<String, dynamic> credential,
  ) async {
    return await _platformService.signVerifiableCredential(credential);
  }

  /// Verify a verifiable credential or presentation (W3C VC technology)
  Future<Map<String, dynamic>> verifyCredential(
    Map<String, dynamic> credential,
  ) async {
    return await _platformService.verifyVerifiableCredential(credential);
  }

  /// Create mDoc response for authentication (PKI/X.509 technology)
  Future<Map<String, dynamic>> createMdocResponse({
    required List<String> requestedAttributes,
    List<String>? hiddenAttributes,
  }) async {
    return await _platformService.createMdocResponse(
      requestedAttributes,
      hiddenAttributes ?? [],
    );
  }

  /// Create SD-JWT presentation (JWT technology)
  Future<Map<String, dynamic>> createSdJwtPresentation({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> discloseKeys,
  }) async {
    return await _platformService.createSdJwt(issuer, claims, discloseKeys);
  }

  /// Get all stored credentials (Wallet technology)
  Future<List<Map<String, dynamic>>> getCredentials() async {
    return await _platformService.getStoredCredentials();
  }

  /// Get credentials by type (Wallet technology)
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return await _platformService.getCredentialsByType(type);
  }
}

/// SpruceID mDoc Manager for Mobile Driver's License
class SpruceIdMdocManager {
  final SpruceIdPlatformService _platformService;

  SpruceIdMdocManager() : _platformService = SpruceIdPlatformService();

  /// Initialize mDoc with driving license data (PKI/X.509 technology)
  Future<Map<String, dynamic>> initializeMdl(
    Map<String, dynamic> mdlData,
  ) async {
    return await _platformService.initializeMdl(mdlData);
  }

  /// Present MDL for age verification (PKI/X.509 technology)
  Future<Map<String, dynamic>> presentForAgeVerification({
    required int minimumAge,
  }) async {
    return await _platformService.presentForAgeVerification(minimumAge);
  }

  /// Present MDL for identity verification (PKI/X.509 technology)
  Future<Map<String, dynamic>> presentForIdVerification({
    required List<String> requestedAttributes,
    List<String>? hiddenAttributes,
  }) async {
    return await _platformService.createMdocResponse(
      requestedAttributes,
      hiddenAttributes ?? [],
    );
  }
}

/// SpruceID SD-JWT Manager for Selective Disclosure
class SpruceIdSdJwtManager {
  final SpruceIdPlatformService _platformService;

  SpruceIdSdJwtManager() : _platformService = SpruceIdPlatformService();

  /// Create SD-JWT with selective disclosure (JWT technology)
  Future<Map<String, dynamic>> createSdJwt({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> selectivelyDisclosableClaims,
  }) async {
    return await _platformService.createSdJwt(
      issuer,
      claims,
      selectivelyDisclosableClaims,
    );
  }

  /// Present SD-JWT with selected disclosures (JWT technology)
  Future<Map<String, dynamic>> present({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> discloseClaims,
  }) async {
    return await _platformService.createSdJwt(issuer, claims, discloseClaims);
  }
}

/// SpruceID Wallet Manager for credential storage
class SpruceIdWalletManager {
  final SpruceIdPlatformService _platformService;

  SpruceIdWalletManager() : _platformService = SpruceIdPlatformService();

  /// Store a verifiable credential (Wallet technology)
  Future<void> storeCredential(Map<String, dynamic> credential) async {
    await _platformService.storeCredential(credential);
  }

  /// Retrieve credentials by type (Wallet technology)
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return await _platformService.getCredentialsByType(type);
  }

  /// Delete a credential (Wallet technology)
  Future<void> deleteCredential(String credentialId) async {
    await _platformService.deleteCredential(credentialId);
  }

  /// Get all credentials (Wallet technology)
  Future<List<Map<String, dynamic>>> getAllCredentials() async {
    return await _platformService.getStoredCredentials();
  }
}
