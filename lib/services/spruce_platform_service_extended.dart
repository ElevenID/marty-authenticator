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

/// Extended SpruceID platform service implementation
/// Leverages SDK integration from refactored Android and iOS handlers
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/spruce_interfaces_extended.dart';
import '../utils/spruce_channels.dart';
import 'spruce_platform_service.dart';

/// Extended platform service implementation with SDK capabilities
/// Uses the refactored Android and iOS handlers with SDK integration
class SpruceIdPlatformServiceExtended extends SpruceIdPlatformService 
    implements ISpruceIdPlatformServiceExtended {
  
  static final _instance = SpruceIdPlatformServiceExtended._internal();
  factory SpruceIdPlatformServiceExtended() => _instance;
  SpruceIdPlatformServiceExtended._internal();

  // Additional SDK-enabled channels
  final MethodChannel _sdkChannel = const MethodChannel('spruce_id_sdk');
  
  // ========================
  // SDK-Enhanced OID4VC Operations
  // ========================

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
    String? keyId,
  }) async {
    try {
      // Use refactored Android/iOS handlers with SDK integration
      final result = await _w3cChannel.invokeMethod('handleOID4VCOfferRefactored', {
        'offer': credentialOffer,
        'pin': pin,
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK OID4VC offer handling failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> handleOID4VPRequestSDK({
    required String presentationRequest,
    required List<Map<String, dynamic>> selectedCredentials,
    required List<String> disclosureOptions,
    String? keyId,
  }) async {
    try {
      // Use refactored Android/iOS handlers with SDK integration
      final result = await _w3cChannel.invokeMethod('handleOID4VPRequestRefactored', {
        'request': presentationRequest,
        'selectedCredentials': selectedCredentials,
        'disclosureOptions': disclosureOptions,
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK OID4VP request handling failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createPresentationSDK({
    required List<Map<String, dynamic>> credentials,
    required String challenge,
    required String domain,
    required Map<String, List<String>> selectiveDisclosure,
    String? keyId,
  }) async {
    try {
      // Use refactored Android/iOS handlers with SDK integration
      final result = await _w3cChannel.invokeMethod('createPresentationRefactored', {
        'credentials': credentials,
        'challenge': challenge,
        'domain': domain,
        'selectiveDisclosure': selectiveDisclosure,
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK presentation creation failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // SDK-Enhanced Holder Operations
  // ========================

  @override
  Future<Map<String, dynamic>> initializeHolderSDK({
    String? keyId,
    Map<String, dynamic>? holderConfig,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('initializeHolderSDK', {
        'keyId': keyId ?? 'default-key',
        'config': holderConfig ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Holder SDK initialization failed: ${e.message}',
        e.details,
      );
    }
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
    try {
      final result = await _sdkChannel.invokeMethod('createVerifiablePresentationSDK', {
        'credentials': credentials,
        'challenge': challenge,
        'domain': domain ?? '',
        'selectiveDisclosure': selectiveDisclosure ?? {},
        'presentationFormat': presentationFormat ?? 'jwt_vp',
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK verifiable presentation creation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> signPresentationSDK({
    required Map<String, dynamic> presentation,
    required String keyId,
    String? verificationMethod,
    String? proofPurpose,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('signPresentationSDK', {
        'presentation': presentation,
        'keyId': keyId,
        'verificationMethod': verificationMethod,
        'proofPurpose': proofPurpose ?? 'authentication',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK presentation signing failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Advanced Credential Operations
  // ========================

  @override
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>> operations,
    String? keyId,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('batchProcessCredentialsSDK', {
        'operations': operations,
        'keyId': keyId ?? 'default-key',
      });
      
      return List<Map<String, dynamic>>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK batch credential processing failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(String credentialId) async {
    try {
      final result = await _sdkChannel.invokeMethod('getCredentialCapabilitiesSDK', {
        'credentialId': credentialId,
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential capabilities retrieval failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> validateCredentialSDK({
    required Map<String, dynamic> credential,
    String? schemaId,
    List<String>? policies,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('validateCredentialSDK', {
        'credential': credential,
        'schemaId': schemaId,
        'policies': policies ?? [],
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential validation failed: ${e.message}',
        e.details,
      );
    }
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
    try {
      final result = await _sdkChannel.invokeMethod('generateSecureKeySDK', {
        'algorithm': algorithm,
        'useHardwareModule': useHardwareModule,
        'keyPolicies': keyPolicies ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK secure key generation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> performCryptoOperationSDK({
    required String operation,
    required String keyId,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? options,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('performCryptoOperationSDK', {
        'operation': operation,
        'keyId': keyId,
        'payload': payload,
        'options': options ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK crypto operation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> establishSecureChannelSDK({
    required String peerDid,
    String? keyId,
    Map<String, dynamic>? channelOptions,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('establishSecureChannelSDK', {
        'peerDid': peerDid,
        'keyId': keyId ?? 'default-key',
        'channelOptions': channelOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK secure channel establishment failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Selective Disclosure Advanced Features
  // ========================

  @override
  Future<Map<String, dynamic>> createAdvancedSdJwtSDK({
    required String issuer,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> disclosureTree,
    List<String>? alwaysDisclose,
    String? keyId,
  }) async {
    try {
      final result = await _jwtChannel.invokeMethod('createAdvancedSdJwtSDK', {
        'issuer': issuer,
        'claims': claims,
        'disclosureTree': disclosureTree,
        'alwaysDisclose': alwaysDisclose ?? [],
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK advanced SD-JWT creation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> presentSdJwtSDK({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
    String? keyId,
  }) async {
    try {
      final result = await _jwtChannel.invokeMethod('presentSdJwtSDK', {
        'sdJwt': sdJwt,
        'disclosureRequest': disclosureRequest,
        'challenge': challenge,
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK SD-JWT presentation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifySdJwtPresentationSDK({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  }) async {
    try {
      final result = await _jwtChannel.invokeMethod('verifySdJwtPresentationSDK', {
        'presentation': presentation,
        'requiredClaims': requiredClaims,
        'policies': policies ?? [],
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK SD-JWT presentation verification failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // mDoc Advanced Operations
  // ========================

  @override
  Future<Map<String, dynamic>> initializeMdocSDK({
    required Map<String, dynamic> mdocData,
    bool enableProximityDetection = true,
    Map<String, dynamic>? deviceConfig,
  }) async {
    try {
      final result = await _mdocChannel.invokeMethod('initializeMdocSDK', {
        'mdocData': mdocData,
        'enableProximityDetection': enableProximityDetection,
        'deviceConfig': deviceConfig ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc initialization failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createMdocPresentationSDK({
    required String docType,
    required List<String> requestedAttributes,
    Map<String, dynamic>? ageVerificationOptions,
    List<String>? hiddenAttributes,
    String? keyId,
  }) async {
    try {
      final result = await _mdocChannel.invokeMethod('createMdocPresentationSDK', {
        'docType': docType,
        'requestedAttributes': requestedAttributes,
        'ageVerificationOptions': ageVerificationOptions ?? {},
        'hiddenAttributes': hiddenAttributes ?? [],
        'keyId': keyId ?? 'default-key',
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc presentation creation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> establishMdocSessionSDK({
    required Map<String, dynamic> sessionRequest,
    String? keyId,
    Map<String, dynamic>? securityOptions,
  }) async {
    try {
      final result = await _mdocChannel.invokeMethod('establishMdocSessionSDK', {
        'sessionRequest': sessionRequest,
        'keyId': keyId ?? 'default-key',
        'securityOptions': securityOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc session establishment failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Credential Lifecycle Management
  // ========================

  @override
  Future<Stream<Map<String, dynamic>>> monitorCredentialStatusSDK(String credentialId) async {
    final StreamController<Map<String, dynamic>> controller = StreamController();
    
    try {
      // Set up platform channel stream for credential monitoring
      const EventChannel eventChannel = EventChannel('spruce_id_credential_monitor');
      
      await _sdkChannel.invokeMethod('startCredentialMonitoring', {
        'credentialId': credentialId,
      });
      
      eventChannel.receiveBroadcastStream(credentialId).listen(
        (data) {
          controller.add(Map<String, dynamic>.from(data));
        },
        onError: (error) {
          controller.addError(SpruceIdException(
            'MONITOR_ERROR',
            'Credential monitoring error: $error',
          ));
        },
        onDone: () {
          controller.close();
        },
      );
      
      return controller.stream;
    } catch (e) {
      controller.addError(SpruceIdException(
        'MONITOR_SETUP_ERROR',
        'Failed to setup credential monitoring: $e',
      ));
      return controller.stream;
    }
  }

  @override
  Future<Map<String, dynamic>> refreshCredentialSDK({
    required String credentialId,
    String? keyId,
    Map<String, dynamic>? refreshOptions,
  }) async {
    try {
      final result = await _walletChannel.invokeMethod('refreshCredentialSDK', {
        'credentialId': credentialId,
        'keyId': keyId ?? 'default-key',
        'refreshOptions': refreshOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential refresh failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> backupCredentialsSDK({
    List<String>? credentialIds,
    required String backupPassphrase,
    Map<String, dynamic>? backupOptions,
  }) async {
    try {
      final result = await _walletChannel.invokeMethod('backupCredentialsSDK', {
        'credentialIds': credentialIds,
        'backupPassphrase': backupPassphrase,
        'backupOptions': backupOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential backup failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> restoreCredentialsSDK({
    required String backupData,
    required String backupPassphrase,
    Map<String, dynamic>? restoreOptions,
  }) async {
    try {
      final result = await _walletChannel.invokeMethod('restoreCredentialsSDK', {
        'backupData': backupData,
        'backupPassphrase': backupPassphrase,
        'restoreOptions': restoreOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential restore failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Cross-Platform Sync and Integration
  // ========================

  @override
  Future<Map<String, dynamic>> syncCredentialsSDK({
    required String syncEndpoint,
    String? syncToken,
    Map<String, dynamic>? syncOptions,
  }) async {
    try {
      final result = await _walletChannel.invokeMethod('syncCredentialsSDK', {
        'syncEndpoint': syncEndpoint,
        'syncToken': syncToken,
        'syncOptions': syncOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential sync failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> exportCredentialsSDK({
    required List<String> credentialIds,
    required String exportFormat,
    Map<String, dynamic>? exportOptions,
  }) async {
    try {
      final result = await _walletChannel.invokeMethod('exportCredentialsSDK', {
        'credentialIds': credentialIds,
        'exportFormat': exportFormat,
        'exportOptions': exportOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential export failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> importCredentialsSDK({
    required String credentialData,
    String? expectedFormat,
    Map<String, dynamic>? importOptions,
  }) async {
    try {
      final result = await _walletChannel.invokeMethod('importCredentialsSDK', {
        'credentialData': credentialData,
        'expectedFormat': expectedFormat,
        'importOptions': importOptions ?? {},
      });
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential import failed: ${e.message}',
        e.details,
      );
    }
  }
}

/// Riverpod provider for extended platform service
final spruceIdPlatformServiceExtendedProvider = 
    Provider<ISpruceIdPlatformServiceExtended>((ref) {
  return SpruceIdPlatformServiceExtended();
});
