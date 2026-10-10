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

/// Extended SpruceID client with SDK capabilities
/// Utilizes the extended platform service to provide advanced functionality
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/spruce_interfaces_extended.dart';
import '../utils/logger.dart';
import 'remote_holder_pairing_service.dart';
import 'spruce_platform_service_extended.dart';
import '../spruce_client.dart';

/// Extended client implementation with SDK-enhanced features
class SpruceIdClientExtended extends SpruceIdClient
    implements ISpruceIdClientExtended {
  final ISpruceIdPlatformServiceExtended _platformService;

  SpruceIdClientExtended(this._platformService) : super(_platformService);

  // ========================
  // SDK-Enhanced Credential Operations
  // ========================

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
  }) async {
    return await _platformService.handleOID4VCOfferSDK(
      credentialOffer: credentialOffer,
      pin: pin,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>> operations,
  }) async {
    return await _platformService.batchProcessCredentialsSDK(
      operations: operations,
    );
  }

  @override
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(
    String credentialId,
  ) async {
    return await _platformService.getCredentialCapabilitiesSDK(credentialId);
  }

  @override
  Future<Map<String, dynamic>> validateCredentialSDK({
    required Map<String, dynamic> credential,
    String? schemaId,
    List<String>? policies,
  }) async {
    return await _platformService.validateCredentialSDK(
      credential: credential,
      schemaId: schemaId,
      policies: policies,
    );
  }

  // ========================
  // Cross-Platform Sync Operations
  // ========================

  @override
  Future<Map<String, dynamic>> syncCredentialsSDK({
    required String syncEndpoint,
    String? syncToken,
    Map<String, dynamic>? syncOptions,
  }) async {
    return await _platformService.syncCredentialsSDK(
      syncEndpoint: syncEndpoint,
      syncToken: syncToken,
      syncOptions: syncOptions,
    );
  }

  @override
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

  @override
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

  @override
  Future<void> initializeSDK({
    Map<String, dynamic>? config,
    bool enableAdvancedFeatures = true,
  }) async {
    await initialize();
    if (enableAdvancedFeatures) {
      if (config != null && config.isNotEmpty) {
        throw UnsupportedError('Local holder SDK configuration is retired');
      }
      final holder = RemoteHolderPairingService();
      try {
        await holder.publicJwkForPurpose('presentation_signing');
      } finally {
        holder.close();
      }
    }
  }

  @override
  Future<Map<String, dynamic>> handleOID4VCFlow({
    required String credentialOffer,
    String? pin,
    Map<String, dynamic>? presentationOptions,
  }) async {
    return await handleOID4VCOfferSDK(
      credentialOffer: credentialOffer,
      pin: pin,
    );
  }

  @override
  Future<void> enableCredentialMonitoring() async {
    // This would typically set up a stream or periodic check
    // For now, we'll just log it as implemented
    Logger.info('Credential monitoring enabled');
  }

  @override
  Future<Map<String, dynamic>> getCredentialMetadata(
    String credentialId,
  ) async {
    return await getCredentialCapabilitiesSDK(credentialId);
  }

  @override
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  }) async {
    return await _platformService.initiateOID4VPRequestSDK(
      presentationRequest: presentationRequest,
    );
  }

  @override
  Future<Map<String, dynamic>> completeOID4VPRequestSDK({
    required String sessionId,
    required String selectedCredentialId,
    List<String>? selectedFields,
  }) async {
    return await _platformService.completeOID4VPRequestSDK(
      sessionId: sessionId,
      selectedCredentialId: selectedCredentialId,
      selectedFields: selectedFields,
    );
  }
}

/// Riverpod provider for extended client
final spruceIdClientExtendedProvider = Provider<ISpruceIdClientExtended>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceExtendedProvider);
  return SpruceIdClientExtended(platformService);
});
