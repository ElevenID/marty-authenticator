/// SpruceID Flutter Client Library
/// Real implementation using platform channels with SpruceKit Mobile SDK
library;

import 'dart:async';
import 'interfaces/spruce_interfaces.dart';
import 'services/spruce_platform_service.dart';

/// SpruceID client for Flutter integration with real platform channels
///
/// Provides integration with SpruceID services for:
/// - OID4VC workflows
/// - mDoc/MDL authentication
/// - SD-JWT selective disclosure
/// - Verifiable credential management
class SpruceIdClient implements ISpruceIdClient {
  final ISpruceIdPlatformService _platformService;

  SpruceIdClient([ISpruceIdPlatformService? platformService])
    : _platformService = platformService ?? SpruceIdPlatformService();

  @override
  Future<void> initialize() async {
    await _platformService.initializeW3C();
  }

  @override
  Future<Map<String, dynamic>> verifyCredential(
    Map<String, dynamic> credential,
  ) async {
    return await _platformService.verifyVerifiableCredential(credential);
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentials() async {
    return await _platformService.getStoredCredentials();
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return await _platformService.getCredentialsByType(type);
  }
}

/// SpruceID mDoc Manager for Mobile Driver's License
class SpruceIdMdocManager implements ISpruceIdMdocManager {
  final ISpruceIdPlatformService _platformService;

  SpruceIdMdocManager([ISpruceIdPlatformService? platformService])
    : _platformService = platformService ?? SpruceIdPlatformService();

  @override
  Future<Map<String, dynamic>> initializeMdl(
    Map<String, dynamic> mdlData,
  ) async {
    return await _platformService.initializeMdl(mdlData);
  }

  @override
  Future<Map<String, dynamic>> presentForAgeVerification({
    required int minimumAge,
  }) async {
    return await _platformService.presentForAgeVerification(minimumAge);
  }
}

/// SpruceID Wallet Manager for credential storage
class SpruceIdWalletManager implements ISpruceIdWalletManager {
  final ISpruceIdPlatformService _platformService;

  SpruceIdWalletManager([ISpruceIdPlatformService? platformService])
    : _platformService = platformService ?? SpruceIdPlatformService();

  @override
  Future<void> storeCredential(Map<String, dynamic> credential) async {
    await _platformService.storeCredential(credential);
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return await _platformService.getCredentialsByType(type);
  }

  @override
  Future<void> deleteCredential(String credentialId) async {
    await _platformService.deleteCredential(credentialId);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCredentials() async {
    return await _platformService.getStoredCredentials();
  }
}
