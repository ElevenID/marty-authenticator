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

/// Extended interfaces for SpruceID SDK integration capabilities
/// These extend the base interfaces with advanced SDK features
library;

import 'dart:async';
import 'spruce_interfaces.dart';

/// Extended platform service interface with SDK capabilities
/// Adds advanced features unlocked by SpruceID SDK integration
abstract class ISpruceIdPlatformServiceExtended
    extends ISpruceIdPlatformService {
  // ========================
  // SDK-Enhanced OID4VC Operations
  // ========================

  /// Handle OID4VC credential offer using SDK
  /// Replaces manual HTTP handling with SDK-integrated approach
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
  });

  /// Initiate OID4VP request processing
  /// Returns session ID and matches if user selection is required
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  });

  /// Complete OID4VP request with user selection
  Future<Map<String, dynamic>> completeOID4VPRequestSDK({
    required String sessionId,
    required String selectedCredentialId,
    List<String>? selectedFields,
  });

  // ========================
  // Advanced Credential Operations
  // ========================

  /// Batch process multiple credentials with SDK optimization
  /// Enables efficient processing of multiple credential operations
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>>
    operations, // operation_type, credential, params
    String? keyId,
  });

  /// Get credential metadata and capabilities
  /// Provides detailed information about credential formats and supported operations
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(
    String credentialId,
  );

  /// Validate credential against schema and policies
  /// Advanced validation using SDK schema verification
  Future<Map<String, dynamic>> validateCredentialSDK({
    required Map<String, dynamic> credential,
    String? schemaId,
    List<String>? policies,
  });

  // ========================
  // Selective Disclosure Advanced Features
  // ========================

  /// Create SD-JWT with advanced selective disclosure patterns
  /// Sophisticated selective disclosure with complex claim structures
  Future<Map<String, dynamic>> createAdvancedSdJwtSDK({
    required String issuer,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> disclosureTree, // nested disclosure patterns
    List<String>? alwaysDisclose,
    String? keyId,
  });

  /// Present SD-JWT with privacy-preserving disclosure
  /// Advanced presentation with zero-knowledge proofs and privacy features
  Future<Map<String, dynamic>> presentSdJwtSDK({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
    String? keyId,
  });

  /// Verify SD-JWT presentation with policy enforcement
  /// Advanced verification with policy-based validation
  Future<Map<String, dynamic>> verifySdJwtPresentationSDK({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  });

  // ========================
  // mDoc Advanced Operations
  // ========================

  /// Initialize mDoc with advanced device engagement
  /// Enhanced mDoc operations with proximity detection and security features
  Future<Map<String, dynamic>> initializeMdocSDK({
    required Map<String, dynamic> mdocData,
    bool enableProximityDetection = true,
    Map<String, dynamic>? deviceConfig,
  });

  /// Handle mDoc OID4VP request using SDK
  /// Processes an OID4VP request URL and generates a response
  Future<Map<String, dynamic>> handleMdocOid4vpRequestSDK({
    required String requestUrl,
  });

  /// Create mDoc presentation with advanced selective disclosure
  /// Sophisticated mDoc presentations with privacy-preserving features
  Future<Map<String, dynamic>> createMdocPresentationSDK({
    required String docType,
    required List<String> requestedAttributes,
    Map<String, dynamic>? ageVerificationOptions,
    List<String>? hiddenAttributes,
    String? keyId,
  });

  /// Establish mDoc session with enhanced security
  /// Advanced mDoc session management with security protocols
  Future<Map<String, dynamic>> establishMdocSessionSDK({
    required Map<String, dynamic> sessionRequest,
    String? keyId,
    Map<String, dynamic>? securityOptions,
  });

  // ========================
  // Credential Lifecycle Management
  // ========================

  /// Monitor credential status and updates
  /// SDK-enabled credential monitoring with automatic updates
  Future<Stream<Map<String, dynamic>>> monitorCredentialStatusSDK(
    String credentialId,
  );

  /// Refresh credential automatically
  /// Advanced credential refresh with issuer coordination
  Future<Map<String, dynamic>> refreshCredentialSDK({
    required String credentialId,
    String? keyId,
    Map<String, dynamic>? refreshOptions,
  });

  /// Backup and restore credentials securely
  /// SDK-enabled secure backup with encryption and integrity protection
  Future<Map<String, dynamic>> backupCredentialsSDK({
    List<String>? credentialIds,
    required String backupPassphrase,
    Map<String, dynamic>? backupOptions,
  });

  Future<Map<String, dynamic>> restoreCredentialsSDK({
    required String backupData,
    required String backupPassphrase,
    Map<String, dynamic>? restoreOptions,
  });

  // ========================
  // Cross-Platform Sync and Integration
  // ========================

  /// Synchronize credentials across devices
  /// Advanced sync with conflict resolution and security
  Future<Map<String, dynamic>> syncCredentialsSDK({
    required String syncEndpoint,
    String? syncToken,
    Map<String, dynamic>? syncOptions,
  });

  /// Export credentials for interoperability
  /// SDK-enabled export with format conversion and compatibility
  Future<Map<String, dynamic>> exportCredentialsSDK({
    required List<String> credentialIds,
    required String exportFormat, // 'w3c_vc', 'mdoc', 'sd_jwt', 'universal'
    Map<String, dynamic>? exportOptions,
  });

  /// Import credentials from external sources
  /// Advanced import with validation and format detection
  Future<Map<String, dynamic>> importCredentialsSDK({
    required String credentialData,
    String? expectedFormat,
    Map<String, dynamic>? importOptions,
  });
}

/// Extended client interface with SDK capabilities
/// High-level API for advanced SpruceID SDK features
abstract class ISpruceIdClientExtended extends ISpruceIdClient {
  /// Initialize SDK with advanced configuration
  Future<void> initializeSDK({
    Map<String, dynamic>? config,
    bool enableAdvancedFeatures = true,
  });

  /// Handle complete OID4VC flow with SDK
  Future<Map<String, dynamic>> handleOID4VCFlow({
    required String credentialOffer,
    String? pin,
    Map<String, dynamic>? presentationOptions,
  });

  /// Handle OID4VC credential offer using SDK directly
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
  });

  /// Enable background credential monitoring
  Future<void> enableCredentialMonitoring();

  /// Get enhanced credential metadata
  Future<Map<String, dynamic>> getCredentialMetadata(String credentialId);

  /// Batch process credentials
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>> operations,
    String? keyId,
  });

  /// Get credential capabilities
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(
    String credentialId,
  );

  /// Validate credential
  Future<Map<String, dynamic>> validateCredentialSDK({
    required Map<String, dynamic> credential,
    String? schemaId,
    List<String>? policies,
  });

  /// Sync Credentials SDK
  Future<Map<String, dynamic>> syncCredentialsSDK({
    required String syncEndpoint,
    String? syncToken,
    Map<String, dynamic>? syncOptions,
  });

  /// Export Credentials SDK
  Future<Map<String, dynamic>> exportCredentialsSDK({
    required List<String> credentialIds,
    required String exportFormat,
    Map<String, dynamic>? exportOptions,
  });

  /// Import Credentials SDK
  Future<Map<String, dynamic>> importCredentialsSDK({
    required String credentialData,
    String? expectedFormat,
    Map<String, dynamic>? importOptions,
  });

  /// Initiate OID4VP request processing
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  });

  /// Complete OID4VP request with user selection
  Future<Map<String, dynamic>> completeOID4VPRequestSDK({
    required String sessionId,
    required String selectedCredentialId,
    List<String>? selectedFields,
  });
}

/// Extended mDoc manager with SDK capabilities
abstract class ISpruceIdMdocManagerExtended extends ISpruceIdMdocManager {
  /// Initialize mDoc with advanced features
  Future<Map<String, dynamic>> initializeMdocAdvanced({
    required Map<String, dynamic> mdlData,
    bool enableProximityDetection = true,
    Map<String, dynamic>? deviceConfig,
  });

  /// Present with advanced selective disclosure
  Future<Map<String, dynamic>> presentWithAdvancedDisclosure({
    required List<String> requestedAttributes,
    Map<String, List<String>>? selectiveDisclosure,
    List<String>? hiddenAttributes,
  });

  /// Establish secure mDoc session
  Future<Map<String, dynamic>> establishSecureSession({
    required Map<String, dynamic> sessionRequest,
    Map<String, dynamic>? securityOptions,
  });

  /// Handle mDoc OID4VP request
  Future<Map<String, dynamic>> handleOid4vpRequest(String requestUrl);
}

/// Extended SD-JWT manager with SDK capabilities
abstract class ISpruceIdSdJwtManagerExtended {
  /// Create SD-JWT with advanced disclosure patterns
  Future<Map<String, dynamic>> createAdvancedSdJwt({
    required String issuer,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> disclosureTree,
    List<String>? alwaysDisclose,
  });

  /// Present with privacy-preserving features
  Future<Map<String, dynamic>> presentWithPrivacy({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
  });

  /// Verify presentation with policy enforcement
  Future<Map<String, dynamic>> verifyWithPolicies({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  });
}

/// Extended wallet manager with SDK capabilities
abstract class ISpruceIdWalletManagerExtended extends ISpruceIdWalletManager {
  /// Get credentials with metadata
  Future<List<Map<String, dynamic>>> getCredentialsWithMetadata();

  /// Backup credentials securely
  Future<Map<String, dynamic>> backupCredentials({
    List<String>? credentialIds,
    required String passphrase,
  });

  /// Restore credentials from backup
  Future<Map<String, dynamic>> restoreCredentials({
    required String backupData,
    required String passphrase,
  });

  /// Sync credentials across devices
  Future<Map<String, dynamic>> syncCredentials({
    required String syncEndpoint,
    String? syncToken,
  });
}
