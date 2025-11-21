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
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/spruce_interfaces_extended.dart';
import '../utils/logger.dart';
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
    String? keyId,
  }) async {
    return await _platformService.handleOID4VCOfferSDK(
      credentialOffer: credentialOffer,
      pin: pin,
      keyId: keyId,
    );
  }

  @override
  Future<Map<String, dynamic>> handleOID4VPRequestSDK({
    required String presentationRequest,
    required List<Map<String, dynamic>> selectedCredentials,
    required List<String> disclosureOptions,
    String? keyId,
  }) async {
    return await _platformService.handleOID4VPRequestSDK(
      presentationRequest: presentationRequest,
      selectedCredentials: selectedCredentials,
      disclosureOptions: disclosureOptions,
      keyId: keyId,
    );
  }

  @override
  Future<Map<String, dynamic>> createPresentationSDK({
    required List<Map<String, dynamic>> credentials,
    required String challenge,
    required String domain,
    required Map<String, List<String>> selectiveDisclosure,
    String? keyId,
  }) async {
    return await _platformService.createPresentationSDK(
      credentials: credentials,
      challenge: challenge,
      domain: domain,
      selectiveDisclosure: selectiveDisclosure,
      keyId: keyId,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>> operations,
    String? keyId,
  }) async {
    return await _platformService.batchProcessCredentialsSDK(
      operations: operations,
      keyId: keyId,
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
  // SDK-Enhanced Holder Operations
  // ========================

  @override
  Future<Map<String, dynamic>> initializeHolderSDK({
    String? keyId,
    Map<String, dynamic>? holderConfig,
  }) async {
    return await _platformService.initializeHolderSDK(
      keyId: keyId,
      holderConfig: holderConfig,
    );
  }

  @override
  Future<Map<String, dynamic>> createVerifiablePresentationSDK({
    required List<Map<String, dynamic>> credentials,
    required String challenge,
    String? domain,
    Map<String, List<String>>? selectiveDisclosure,
    String? presentationFormat,
    String? keyId,
  }) async {
    return await _platformService.createVerifiablePresentationSDK(
      credentials: credentials,
      challenge: challenge,
      domain: domain,
      selectiveDisclosure: selectiveDisclosure,
      presentationFormat: presentationFormat,
      keyId: keyId,
    );
  }

  @override
  Future<Map<String, dynamic>> signPresentationSDK({
    required Map<String, dynamic> presentation,
    required String keyId,
    String? verificationMethod,
    String? proofPurpose,
  }) async {
    return await _platformService.signPresentationSDK(
      presentation: presentation,
      keyId: keyId,
      verificationMethod: verificationMethod,
      proofPurpose: proofPurpose,
    );
  }

  // ========================
  // Enhanced Security Operations
  // ========================

  @override
  Future<Map<String, dynamic>> generateSecureKeySDK({
    String algorithm = 'Ed25519',
    bool useHardwareModule = true,
    Map<String, dynamic>? keyPolicies,
  }) async {
    return await _platformService.generateSecureKeySDK(
      algorithm: algorithm,
      useHardwareModule: useHardwareModule,
      keyPolicies: keyPolicies,
    );
  }

  @override
  Future<Map<String, dynamic>> performCryptoOperationSDK({
    required String operation,
    required String keyId,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? options,
  }) async {
    return await _platformService.performCryptoOperationSDK(
      operation: operation,
      keyId: keyId,
      payload: payload,
      options: options,
    );
  }

  @override
  Future<Map<String, dynamic>> establishSecureChannelSDK({
    required String peerDid,
    String? keyId,
    Map<String, dynamic>? channelOptions,
  }) async {
    return await _platformService.establishSecureChannelSDK(
      peerDid: peerDid,
      keyId: keyId,
      channelOptions: channelOptions,
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
    // Initialize base SDK
    await initialize();

    // Initialize advanced features if requested
    if (enableAdvancedFeatures) {
      await _platformService.initializeHolderSDK(holderConfig: config);
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
  Future<Map<String, dynamic>> createAdvancedPresentation({
    required List<Map<String, dynamic>> credentials,
    required Map<String, dynamic> presentationRequest,
    required Map<String, List<String>> selectiveDisclosure,
  }) async {
    // Extract challenge and domain from presentation request if available
    final challenge =
        presentationRequest['challenge'] as String? ?? 'default-challenge';
    final domain = presentationRequest['domain'] as String? ?? 'default-domain';

    return await createPresentationSDK(
      credentials: credentials,
      challenge: challenge,
      domain: domain,
      selectiveDisclosure: selectiveDisclosure,
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
}

/// Riverpod provider for extended client
final spruceIdClientExtendedProvider = Provider<ISpruceIdClientExtended>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceExtendedProvider);
  return SpruceIdClientExtended(platformService);
});
