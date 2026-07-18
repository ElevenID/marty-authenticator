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

/// Extended manager implementations with SDK capabilities
/// Provides advanced functionality for mDoc, SD-JWT, and Wallet operations
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/spruce_interfaces_extended.dart';
import 'spruce_platform_service_extended.dart';
import '../spruce_client.dart';
// import 'spruce_mdoc_manager.dart';
// import 'spruce_sdjwt_manager.dart';
// import 'spruce_wallet_manager.dart';

// ========================
// Extended mDoc Manager
// ========================

/// Extended mDoc manager with SDK-enhanced operations
class SpruceIdMdocManagerExtended extends SpruceIdMdocManager
    implements ISpruceIdMdocManagerExtended {
  final ISpruceIdPlatformServiceExtended _platformService;

  SpruceIdMdocManagerExtended(this._platformService) : super(_platformService);

  @override
  Future<Map<String, dynamic>> initializeMdocAdvanced({
    required Map<String, dynamic> mdlData,
    bool enableProximityDetection = true,
    Map<String, dynamic>? deviceConfig,
  }) async {
    return await _platformService.initializeMdocSDK(
      mdocData: mdlData,
      enableProximityDetection: enableProximityDetection,
      deviceConfig: deviceConfig,
    );
  }

  @override
  Future<Map<String, dynamic>> presentWithAdvancedDisclosure({
    required List<String> requestedAttributes,
    Map<String, List<String>>? selectiveDisclosure,
    List<String>? hiddenAttributes,
  }) async {
    return await _platformService.createMdocPresentationSDK(
      docType: 'org.iso.18013.5.1.mDL', // Default doc type
      requestedAttributes: requestedAttributes,
      hiddenAttributes: hiddenAttributes,
    );
  }

  @override
  Future<Map<String, dynamic>> establishSecureSession({
    required Map<String, dynamic> sessionRequest,
    Map<String, dynamic>? securityOptions,
  }) async {
    return await _platformService.establishMdocSessionSDK(
      sessionRequest: sessionRequest,
      securityOptions: securityOptions,
    );
  }

  Future<Map<String, dynamic>> initializeMdocSDK({
    required Map<String, dynamic> mdocData,
    bool enableProximityDetection = true,
    Map<String, dynamic>? deviceConfig,
  }) async {
    return initializeMdocAdvanced(
      mdlData: mdocData,
      enableProximityDetection: enableProximityDetection,
      deviceConfig: deviceConfig,
    );
  }

  Future<Map<String, dynamic>> createMdocPresentationSDK({
    required String docType,
    required List<String> requestedAttributes,
    Map<String, dynamic>? ageVerificationOptions,
    List<String>? hiddenAttributes,
    String? keyId,
  }) async {
    return await _platformService.createMdocPresentationSDK(
      docType: docType,
      requestedAttributes: requestedAttributes,
      ageVerificationOptions: ageVerificationOptions,
      hiddenAttributes: hiddenAttributes,
      keyId: keyId,
    );
  }

  Future<Map<String, dynamic>> establishMdocSessionSDK({
    required Map<String, dynamic> sessionRequest,
    String? keyId,
    Map<String, dynamic>? securityOptions,
  }) async {
    return await _platformService.establishMdocSessionSDK(
      sessionRequest: sessionRequest,
      keyId: keyId,
      securityOptions: securityOptions,
    );
  }

  Future<Map<String, dynamic>> performProximityVerificationSDK({
    required String sessionId,
    required Map<String, dynamic> proximityRequest,
  }) async {
    // Custom logic for proximity verification using SDK
    return await _platformService.performCryptoOperationSDK(
      operation: 'proximity_verification',
      keyId: sessionId,
      payload: proximityRequest,
    );
  }

  Future<Map<String, dynamic>> enableBiometricBindingSDK({
    required String docId,
    required String biometricTemplate,
    Map<String, dynamic>? bindingOptions,
  }) async {
    // Custom logic for biometric binding using SDK
    return await _platformService.performCryptoOperationSDK(
      operation: 'biometric_binding',
      keyId: docId,
      payload: {
        'biometricTemplate': biometricTemplate,
        'options': bindingOptions ?? {},
      },
    );
  }

  @override
  Future<Map<String, dynamic>> handleOid4vpRequest(String requestUrl) async {
    return await _platformService.handleMdocOid4vpRequestSDK(
      requestUrl: requestUrl,
    );
  }
}

// ========================
// Extended SD-JWT Manager
// ========================

/// Extended SD-JWT manager with SDK-enhanced selective disclosure
class SpruceIdSdJwtManagerExtended extends SpruceIdSdJwtManager
    implements ISpruceIdSdJwtManagerExtended {
  final ISpruceIdPlatformServiceExtended _platformService;

  SpruceIdSdJwtManagerExtended(this._platformService) : super(_platformService);

  @override
  Future<Map<String, dynamic>> createAdvancedSdJwt({
    required String issuer,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> disclosureTree,
    List<String>? alwaysDisclose,
  }) async {
    return await _platformService.createAdvancedSdJwtSDK(
      issuer: issuer,
      claims: claims,
      disclosureTree: disclosureTree,
      alwaysDisclose: alwaysDisclose,
    );
  }

  @override
  Future<Map<String, dynamic>> presentWithPrivacy({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
  }) async {
    return await _platformService.presentSdJwtSDK(
      sdJwt: sdJwt,
      disclosureRequest: disclosureRequest,
      challenge: challenge,
    );
  }

  @override
  Future<Map<String, dynamic>> verifyWithPolicies({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  }) async {
    return await _platformService.verifySdJwtPresentationSDK(
      presentation: presentation,
      requiredClaims: requiredClaims,
      policies: policies,
    );
  }

  Future<Map<String, dynamic>> createAdvancedSdJwtSDK({
    required String issuer,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> disclosureTree,
    List<String>? alwaysDisclose,
    String? keyId,
  }) async {
    return createAdvancedSdJwt(
      issuer: issuer,
      claims: claims,
      disclosureTree: disclosureTree,
      alwaysDisclose: alwaysDisclose,
    );
  }

  Future<Map<String, dynamic>> presentSdJwtSDK({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
    String? keyId,
  }) async {
    return await _platformService.presentSdJwtSDK(
      sdJwt: sdJwt,
      disclosureRequest: disclosureRequest,
      challenge: challenge,
      keyId: keyId,
    );
  }

  Future<Map<String, dynamic>> verifySdJwtPresentationSDK({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  }) async {
    return await _platformService.verifySdJwtPresentationSDK(
      presentation: presentation,
      requiredClaims: requiredClaims,
      policies: policies,
    );
  }

  Future<Map<String, dynamic>> createSelectiveDisclosureSchemaSDK({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> disclosureRules,
    String? schemaId,
  }) async {
    // Custom logic for creating selective disclosure schema
    return await _platformService.performCryptoOperationSDK(
      operation: 'create_disclosure_schema',
      keyId: schemaId ?? 'default-schema',
      payload: {'schema': schema, 'disclosureRules': disclosureRules},
    );
  }

  Future<Map<String, dynamic>> validateDisclosureComplianceSDK({
    required String presentation,
    required String schemaId,
    List<String>? additionalPolicies,
  }) async {
    // Custom logic for validating disclosure compliance
    return await _platformService.validateCredentialSDK(
      credential: {'presentation': presentation},
      schemaId: schemaId,
      policies: additionalPolicies,
    );
  }
}

// ========================
// Extended Wallet Manager
// ========================

/// Extended wallet manager with SDK-enhanced credential lifecycle
class SpruceIdWalletManagerExtended extends SpruceIdWalletManager
    implements ISpruceIdWalletManagerExtended {
  final ISpruceIdPlatformServiceExtended _platformService;

  SpruceIdWalletManagerExtended(this._platformService)
    : super(_platformService);

  @override
  Future<void> storeCredentialSecure({
    required Map<String, dynamic> credential,
    String? encryptionKey,
    Map<String, dynamic>? securityOptions,
  }) async {
    await _platformService.performCryptoOperationSDK(
      operation: 'store_credential',
      keyId: encryptionKey ?? 'default-storage-key',
      payload: {'credential': credential, 'options': securityOptions ?? {}},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsWithMetadata() async {
    final result = await _platformService.batchProcessCredentialsSDK(
      operations: [
        {'operation': 'get_all_credentials'},
      ],
    );
    return result;
  }

  @override
  Future<Map<String, dynamic>> backupCredentials({
    List<String>? credentialIds,
    required String passphrase,
  }) async {
    return await _platformService.backupCredentialsSDK(
      credentialIds: credentialIds,
      backupPassphrase: passphrase,
    );
  }

  @override
  Future<Map<String, dynamic>> restoreCredentials({
    required String backupData,
    required String passphrase,
  }) async {
    return await _platformService.restoreCredentialsSDK(
      backupData: backupData,
      backupPassphrase: passphrase,
    );
  }

  @override
  Future<Map<String, dynamic>> syncCredentials({
    required String syncEndpoint,
    String? syncToken,
  }) async {
    return await _platformService.syncCredentialsSDK(
      syncEndpoint: syncEndpoint,
      syncToken: syncToken,
    );
  }

  Future<Stream<Map<String, dynamic>>> monitorCredentialStatusSDK(
    String credentialId,
  ) async {
    return await _platformService.monitorCredentialStatusSDK(credentialId);
  }

  Future<Map<String, dynamic>> refreshCredentialSDK({
    required String credentialId,
    String? keyId,
    Map<String, dynamic>? refreshOptions,
  }) async {
    return await _platformService.refreshCredentialSDK(
      credentialId: credentialId,
      keyId: keyId,
      refreshOptions: refreshOptions,
    );
  }

  Future<Map<String, dynamic>> backupCredentialsSDK({
    List<String>? credentialIds,
    required String backupPassphrase,
    Map<String, dynamic>? backupOptions,
  }) async {
    return backupCredentials(
      credentialIds: credentialIds,
      passphrase: backupPassphrase,
    );
  }

  Future<Map<String, dynamic>> restoreCredentialsSDK({
    required String backupData,
    required String backupPassphrase,
    Map<String, dynamic>? restoreOptions,
  }) async {
    return restoreCredentials(
      backupData: backupData,
      passphrase: backupPassphrase,
    );
  }

  Future<Map<String, dynamic>> syncCredentialsSDK({
    required String syncEndpoint,
    String? syncToken,
    Map<String, dynamic>? syncOptions,
  }) async {
    return syncCredentials(syncEndpoint: syncEndpoint, syncToken: syncToken);
  }

  Future<Map<String, dynamic>> exportCredentialsSDK({
    required List<String> credentialIds,
    required String exportFormat,
    Map<String, dynamic>? exportOptions,
  }) async {
    return await _platformService.exportCredentialsSDK(
      credentialIds: credentialIds,
      exportFormat: exportFormat,
      exportOptions: exportOptions,
    );
  }

  Future<Map<String, dynamic>> importCredentialsSDK({
    required String credentialData,
    String? expectedFormat,
    Map<String, dynamic>? importOptions,
  }) async {
    return await _platformService.importCredentialsSDK(
      credentialData: credentialData,
      expectedFormat: expectedFormat,
      importOptions: importOptions,
    );
  }

  Future<Map<String, dynamic>> setupAutomaticRenewalSDK({
    required List<String> credentialIds,
    required Map<String, dynamic> renewalPolicy,
    String? keyId,
  }) async {
    // Custom logic for automatic renewal setup
    return await _platformService.performCryptoOperationSDK(
      operation: 'setup_automatic_renewal',
      keyId: keyId ?? 'renewal-key',
      payload: {'credentialIds': credentialIds, 'renewalPolicy': renewalPolicy},
    );
  }

  Future<Map<String, dynamic>> analyzeWalletHealthSDK({
    Map<String, dynamic>? healthCheckOptions,
  }) async {
    // Custom logic for wallet health analysis
    final results = await _platformService.batchProcessCredentialsSDK(
      operations: [
        {'operation': 'health_check', 'options': healthCheckOptions ?? {}},
      ],
    );
    return results.isNotEmpty ? results.first : {};
  }

  Future<Map<String, dynamic>> optimizeWalletStorageSDK({
    Map<String, dynamic>? optimizationOptions,
  }) async {
    // Custom logic for wallet storage optimization
    return await _platformService.performCryptoOperationSDK(
      operation: 'optimize_storage',
      keyId: 'storage-optimization',
      payload: optimizationOptions ?? {},
    );
  }
}

// ========================
// Riverpod Providers
// ========================

/// Provider for extended mDoc manager
final spruceIdMdocManagerExtendedProvider =
    Provider<ISpruceIdMdocManagerExtended>((ref) {
      final platformService = ref.watch(
        spruceIdPlatformServiceExtendedProvider,
      );
      return SpruceIdMdocManagerExtended(platformService);
    });

/// Provider for extended SD-JWT manager
final spruceIdSdJwtManagerExtendedProvider =
    Provider<ISpruceIdSdJwtManagerExtended>((ref) {
      final platformService = ref.watch(
        spruceIdPlatformServiceExtendedProvider,
      );
      return SpruceIdSdJwtManagerExtended(platformService);
    });

/// Provider for extended wallet manager
final spruceIdWalletManagerExtendedProvider =
    Provider<ISpruceIdWalletManagerExtended>((ref) {
      final platformService = ref.watch(
        spruceIdPlatformServiceExtendedProvider,
      );
      return SpruceIdWalletManagerExtended(platformService);
    });
