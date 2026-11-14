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

// Enhanced QR scanner service with SDK credential handling
//
// This service provides:
// - Advanced QR code processing with SDK integration
// - Credential offer/request parsing and validation
// - Automatic credential matching for presentation requests

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/marty_bridge.dart/api.dart' as rust_api;
import '../utils/logger.dart';
import '../utils/open_badges.dart';
import 'spruce_sdk_services.dart';

/// Enhanced QR scanner service provider
final qrScannerServiceEnhancedProvider = Provider<QRScannerServiceEnhanced>((
  ref,
) {
  return QRScannerServiceEnhanced(
    spruceClientExtended: ref.read(spruceIdClientExtendedProvider),
    walletManagerExtended: ref.read(spruceIdWalletManagerExtendedProvider),
  );
});

/// Enhanced QR scanner service with SDK credential handling
class QRScannerServiceEnhanced {
  final ISpruceIdClientExtended _spruceClient;
  final ISpruceIdWalletManagerExtended _walletManager;

  QRScannerServiceEnhanced({
    required ISpruceIdClientExtended spruceClientExtended,
    required ISpruceIdWalletManagerExtended walletManagerExtended,
  }) : _spruceClient = spruceClientExtended,
       _walletManager = walletManagerExtended;

  /// Process scanned QR code with SDK-enhanced capabilities
  Future<ProcessedQRResult> processQRCode(String rawData) async {
    try {
      Logger.info(
        'Processing QR code with SDK enhancement',
        name: 'QRScannerServiceEnhanced',
      );

      // Step 1: Parse the raw QR data
      final parseResult = await _parseQRData(rawData);

      // Step 2: Validate using SDK capabilities
      final validationResult = await _validateWithSDK(parseResult);
      if (!validationResult.isValid) {
        return ProcessedQRResult.error(
          validationResult.validationErrors.isEmpty
              ? 'QR content validation failed'
              : validationResult.validationErrors.join('; '),
        );
      }

      // Step 3: Enrich with credential matching if applicable
      final enrichedResult = await _enrichWithCredentialData(validationResult);

      return ProcessedQRResult.success(enrichedResult: enrichedResult);
    } catch (e) {
      Logger.error(
        'QR code processing failed',
        error: e,
        name: 'QRScannerServiceEnhanced',
      );
      return ProcessedQRResult.error('Failed to process QR code: $e');
    }
  }

  /// Parse raw QR data into structured format
  Future<ParsedQRData> _parseQRData(String rawData) async {
    try {
      final nativeProtocol = await rust_api.walletValidateQrInput(
        rawData: rawData,
      );
      if (nativeProtocol != null) {
        final parsedContent =
            jsonDecode(nativeProtocol.parsedContentJson)
                as Map<String, dynamic>;
        final type = switch (nativeProtocol.kind) {
          'credential_offer' => QRType.credentialOffer,
          'presentation_request' => QRType.presentationRequest,
          'mdoc_device_engagement' => QRType.mdocDeviceEngagement,
          'push_registration' => QRType.pushRegistration,
          _ => throw StateError(
            'Native wallet parser returned an unsupported kind',
          ),
        };
        return ParsedQRData(
          type: type,
          format: switch (type) {
            QRType.pushRegistration => QRFormat.url,
            QRType.mdocDeviceEngagement => QRFormat.raw,
            _ => QRFormat.openid,
          },
          rawData: nativeProtocol.normalized,
          parsedContent: parsedContent,
          metadata: {
            'native_validated': true,
            'native_backend': 'marty-core',
            'requires_external_provider':
                nativeProtocol.requiresExternalProvider,
          },
        );
      }

      // Unknown input is retained only for the existing error result shape.
      // All supported protocol recognition and parsing happens in Rust.
      return ParsedQRData(
        type: QRType.unknown,
        format: QRFormat.raw,
        rawData: rawData,
        metadata: {'original_format': 'raw_text'},
      );
    } catch (e) {
      throw Exception('Failed to parse QR data: $e');
    }
  }

  /// Accept only protocol data already validated by Rust.
  Future<ValidatedQRResult> _validateWithSDK(ParsedQRData parsedData) async {
    if (parsedData.metadata['native_validated'] == true) {
      final requiresExternalProvider =
          parsedData.metadata['requires_external_provider'] == true;
      return ValidatedQRResult(
        parsedData: parsedData,
        isValid: true,
        validationErrors: const [],
        // Parsing a protocol does not authenticate the issuer or verifier.
        securityLevel: SecurityLevel.unknown,
        recommendedActions: requiresExternalProvider
            ? const ['Continue with the required external provider adapter']
            : const [],
        sdkCapabilities: const {'protocol_validation': 'marty-core'},
      );
    }

    return ValidatedQRResult(
      parsedData: parsedData,
      isValid: false,
      validationErrors: const [
        'Unsupported QR content was not validated by the native backend',
      ],
      securityLevel: SecurityLevel.unknown,
      recommendedActions: const [],
      sdkCapabilities: const {},
    );
  }

  /// Enrich validation result with credential data matching
  Future<EnrichedQRResult> _enrichWithCredentialData(
    ValidatedQRResult validatedResult,
  ) async {
    try {
      final parsedData = validatedResult.parsedData;

      if (!validatedResult.isValid) {
        return EnrichedQRResult(
          validatedResult: validatedResult,
          matchingCredentials: const [],
          availableActions: const [],
          privacyAnalysis: null,
        );
      }

      if (parsedData.type == QRType.presentationRequest) {
        return await _enrichPresentationRequest(validatedResult);
      } else if (parsedData.type == QRType.credentialOffer) {
        return await _enrichCredentialOffer(validatedResult);
      } else {
        return EnrichedQRResult(
          validatedResult: validatedResult,
          matchingCredentials: [],
          availableActions: [],
          privacyAnalysis: null,
        );
      }
    } catch (e) {
      Logger.error('Failed to enrich QR result with credential data', error: e);
      return EnrichedQRResult(
        validatedResult: validatedResult,
        matchingCredentials: [],
        availableActions: [],
        privacyAnalysis: null,
      );
    }
  }

  /// Enrich presentation request with matching credentials
  Future<EnrichedQRResult> _enrichPresentationRequest(
    ValidatedQRResult validatedResult,
  ) async {
    final requestContent = validatedResult.parsedData.parsedContent!;
    final requestedAttributes =
        (requestContent['requested_attributes'] as List?)?.cast<String>() ?? [];

    // Get all available credentials
    final allCredentials = await _walletManager.getAllCredentials();

    // Find matching credentials
    final matchingCredentials = <MatchingCredential>[];

    for (final credential in allCredentials) {
      if (isRetiredOpenBadge(credential)) continue;
      final credentialSubject =
          credential['credentialSubject'] as Map<String, dynamic>? ?? {};
      final availableAttributes = credentialSubject.keys.toList();

      final matchingAttributes = requestedAttributes
          .where((attr) => availableAttributes.contains(attr))
          .toList();

      if (matchingAttributes.isNotEmpty) {
        // Get credential capabilities from SDK
        final capabilities = await _spruceClient.getCredentialCapabilitiesSDK(
          credential['id'] as String,
        );

        matchingCredentials.add(
          MatchingCredential(
            credentialId: credential['id'] as String,
            credentialName:
                credential['name'] as String? ?? 'Unknown Credential',
            issuer: credential['issuer'] as String? ?? 'Unknown Issuer',
            matchingAttributes: matchingAttributes,
            totalAttributes: availableAttributes.length,
            matchScore:
                (matchingAttributes.length / requestedAttributes.length * 100)
                    .round(),
            capabilities: capabilities,
            securityLevel: capabilities['hardware_backed'] == true
                ? SecurityLevel.high
                : SecurityLevel.medium,
          ),
        );
      }
    }

    // Sort by match score
    matchingCredentials.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Generate privacy analysis
    final privacyAnalysis = await _generatePrivacyAnalysis(
      requestContent,
      matchingCredentials,
    );

    // Generate available actions
    final availableActions = _generatePresentationActions(
      matchingCredentials,
      requestContent,
    );

    return EnrichedQRResult(
      validatedResult: validatedResult,
      matchingCredentials: matchingCredentials,
      availableActions: availableActions,
      privacyAnalysis: privacyAnalysis,
    );
  }

  /// Enrich credential offer with compatibility analysis
  Future<EnrichedQRResult> _enrichCredentialOffer(
    ValidatedQRResult validatedResult,
  ) async {
    final offerContent = validatedResult.parsedData.parsedContent!;
    final credentials = (offerContent['credentials'] as List?) ?? [];

    // Analyze credential compatibility
    final compatibilityResults = <CredentialCompatibility>[];

    for (final credentialDef in credentials) {
      final compatibility = _describeCredentialCompatibility(
        credentialDef as Map<String, dynamic>,
      );
      compatibilityResults.add(compatibility);
    }

    // Generate available actions
    final availableActions = _generateOfferActions(
      compatibilityResults,
      offerContent,
    );

    return EnrichedQRResult(
      validatedResult: validatedResult,
      matchingCredentials: [], // Not applicable for offers
      availableActions: availableActions,
      privacyAnalysis: null, // Different analysis for offers
      credentialCompatibility: compatibilityResults,
    );
  }

  /// Generate privacy analysis for presentation requests
  Future<PrivacyAnalysis> _generatePrivacyAnalysis(
    Map<String, dynamic> requestContent,
    List<MatchingCredential> matchingCredentials,
  ) async {
    final requestedAttributes =
        (requestContent['requested_attributes'] as List?)?.cast<String>() ?? [];
    final optionalAttributes =
        (requestContent['optional_attributes'] as List?)?.cast<String>() ?? [];

    // Analyze privacy implications of each attribute
    final attributePrivacyScores = <String, double>{};

    for (final attr in requestedAttributes) {
      attributePrivacyScores[attr] = _calculateAttributePrivacyScore(attr);
    }

    // Calculate overall privacy risk
    final overallRiskScore = attributePrivacyScores.values.isNotEmpty
        ? attributePrivacyScores.values.reduce((a, b) => a + b) /
              attributePrivacyScores.length
        : 0.0;

    return PrivacyAnalysis(
      overallRiskLevel: _riskLevelFromScore(overallRiskScore),
      attributeRisks: attributePrivacyScores,
      recommendations: _generatePrivacyRecommendations(
        overallRiskScore,
        requestedAttributes,
      ),
      dataMinimizationOpportunities: _identifyDataMinimizationOpportunities(
        requestedAttributes,
        optionalAttributes,
      ),
    );
  }

  /// Calculate privacy score for individual attributes
  double _calculateAttributePrivacyScore(String attribute) {
    // High privacy risk attributes
    const highRiskAttributes = {
      'ssn',
      'social_security_number',
      'passport_number',
      'driver_license',
      'credit_card',
      'bank_account',
      'biometric_data',
      'medical_records',
    };

    // Medium privacy risk attributes
    const mediumRiskAttributes = {
      'date_of_birth',
      'phone_number',
      'address',
      'email',
      'id_number',
    };

    // Low privacy risk attributes
    const lowRiskAttributes = {
      'name',
      'first_name',
      'last_name',
      'age_over_18',
      'age_over_21',
      'country',
    };

    final lowerAttr = attribute.toLowerCase();

    if (highRiskAttributes.any((risk) => lowerAttr.contains(risk))) {
      return 0.9; // High risk
    } else if (mediumRiskAttributes.any((risk) => lowerAttr.contains(risk))) {
      return 0.6; // Medium risk
    } else if (lowRiskAttributes.any((risk) => lowerAttr.contains(risk))) {
      return 0.3; // Low risk
    } else {
      return 0.5; // Default medium risk for unknown attributes
    }
  }

  /// Convert numeric risk score to risk level
  RiskLevel _riskLevelFromScore(double score) {
    if (score >= 0.8) return RiskLevel.high;
    if (score >= 0.6) return RiskLevel.medium;
    if (score >= 0.3) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  /// Generate privacy recommendations
  List<String> _generatePrivacyRecommendations(
    double overallRisk,
    List<String> requestedAttributes,
  ) {
    final recommendations = <String>[];

    if (overallRisk >= 0.8) {
      recommendations.add(
        'High privacy risk detected - consider declining this request',
      );
      recommendations.add(
        'If you must share, verify the verifier\'s identity thoroughly',
      );
    } else if (overallRisk >= 0.6) {
      recommendations.add(
        'Medium privacy risk - review what information you\'re sharing',
      );
      recommendations.add(
        'Consider using selective disclosure to share only necessary attributes',
      );
    } else if (overallRisk >= 0.3) {
      recommendations.add('Low privacy risk - standard precautions apply');
    }

    // Specific attribute recommendations
    final sensitiveAttrs = requestedAttributes
        .where((attr) => _calculateAttributePrivacyScore(attr) >= 0.8)
        .toList();

    if (sensitiveAttrs.isNotEmpty) {
      recommendations.add(
        'Highly sensitive attributes requested: ${sensitiveAttrs.join(', ')}',
      );
    }

    return recommendations;
  }

  /// Identify data minimization opportunities
  List<String> _identifyDataMinimizationOpportunities(
    List<String> required,
    List<String> optional,
  ) {
    final opportunities = <String>[];

    if (optional.isNotEmpty) {
      opportunities.add(
        '${optional.length} optional attributes can be excluded',
      );
    }

    // Suggest alternatives for high-risk attributes
    for (final attr in required) {
      if (attr.toLowerCase().contains('date_of_birth')) {
        opportunities.add(
          'Consider sharing age verification instead of full date of birth',
        );
      } else if (attr.toLowerCase().contains('address')) {
        opportunities.add(
          'Consider sharing only city/state instead of full address',
        );
      }
    }

    return opportunities;
  }

  /// Describe an offered credential without claiming unsupported analysis.
  /// Native acceptance still validates the user's explicitly reviewed offer.
  CredentialCompatibility _describeCredentialCompatibility(
    Map<String, dynamic> credentialDef,
  ) {
    final type = credentialDef['type'];
    final format = credentialDef['format'];
    return CredentialCompatibility(
      credentialType: type is String ? type : 'Unknown',
      format: format is String ? format : 'Unknown',
      isSupported: false,
      supportLevel: CompatibilityLevel.unknown,
      requiredCapabilities: const [],
      availableCapabilities: const [],
      missingCapabilities: const ['Credential compatibility evaluation'],
    );
  }

  /// Generate available actions for presentation requests
  List<QRAction> _generatePresentationActions(
    List<MatchingCredential> matchingCredentials,
    Map<String, dynamic> requestContent,
  ) {
    final actions = <QRAction>[];

    if (matchingCredentials.isNotEmpty) {
      actions.add(
        QRAction(
          id: 'create_presentation',
          title: 'Share Credentials',
          description: 'Create presentation with selected credentials',
          type: ActionType.presentation,
          priority: ActionPriority.high,
          requiresUserConsent: true,
          metadata: {
            'matching_credentials_count': matchingCredentials.length,
            'best_match_score': matchingCredentials.first.matchScore,
          },
        ),
      );

      actions.add(
        QRAction(
          id: 'selective_disclosure',
          title: 'Advanced Privacy Controls',
          description: 'Fine-tune what information to share',
          type: ActionType.selectiveDisclosure,
          priority: ActionPriority.medium,
          requiresUserConsent: true,
          metadata: {
            'total_attributes': matchingCredentials.first.totalAttributes,
          },
        ),
      );
    } else {
      actions.add(
        QRAction(
          id: 'no_matching_credentials',
          title: 'No Matching Credentials',
          description: 'You don\'t have credentials that match this request',
          type: ActionType.information,
          priority: ActionPriority.low,
          requiresUserConsent: false,
          metadata: {'can_fulfill': false},
        ),
      );
    }

    actions.add(
      QRAction(
        id: 'decline_request',
        title: 'Decline Request',
        description: 'Refuse to share any information',
        type: ActionType.decline,
        priority: ActionPriority.medium,
        requiresUserConsent: false,
        metadata: {},
      ),
    );

    return actions;
  }

  /// Generate available actions for credential offers
  List<QRAction> _generateOfferActions(
    List<CredentialCompatibility> compatibilityResults,
    Map<String, dynamic> offerContent,
  ) {
    final actions = <QRAction>[];

    final supportedCredentials = compatibilityResults
        .where(
          (credential) =>
              credential.isSupported &&
              credential.supportLevel != CompatibilityLevel.unknown &&
              credential.supportLevel != CompatibilityLevel.unsupported,
        )
        .length;
    final unknownCredentials = compatibilityResults
        .where(
          (credential) => credential.supportLevel == CompatibilityLevel.unknown,
        )
        .length;
    final totalCredentials = compatibilityResults.length;
    final unsupportedCredentials =
        totalCredentials - supportedCredentials - unknownCredentials;

    if (supportedCredentials > 0) {
      actions.add(
        QRAction(
          id: 'accept_credentials',
          title: 'Accept Credentials',
          description:
              'Add $supportedCredentials credential${supportedCredentials == 1 ? '' : 's'} to wallet',
          type: ActionType.credentialAcceptance,
          priority: ActionPriority.high,
          requiresUserConsent: true,
          metadata: {
            'supported_count': supportedCredentials,
            'total_count': totalCredentials,
          },
        ),
      );
    }

    if (unknownCredentials > 0) {
      actions.add(
        QRAction(
          id: 'review_compatibility',
          title: 'Review Credential Offer',
          description: 'Credential compatibility has not been evaluated',
          type: ActionType.information,
          priority: ActionPriority.medium,
          requiresUserConsent: true,
          metadata: {
            'unknown_count': unknownCredentials,
            'total_count': totalCredentials,
          },
        ),
      );
    }

    if (unsupportedCredentials > 0) {
      actions.add(
        QRAction(
          id: 'partial_support_warning',
          title: 'Unsupported Credentials',
          description:
              '$unsupportedCredentials credential${unsupportedCredentials == 1 ? '' : 's'} not supported',
          type: ActionType.warning,
          priority: ActionPriority.medium,
          requiresUserConsent: false,
          metadata: {'unsupported_count': unsupportedCredentials},
        ),
      );
    }

    actions.add(
      QRAction(
        id: 'decline_offer',
        title: 'Decline Offer',
        description: 'Don\'t add any credentials',
        type: ActionType.decline,
        priority: ActionPriority.low,
        requiresUserConsent: false,
        metadata: {},
      ),
    );

    return actions;
  }
}

// Data classes for QR processing results

/// Types of QR codes that can be processed
enum QRType {
  presentationRequest,
  credentialOffer,
  mdocDeviceEngagement,
  pushRegistration, // marty://push-register QR for enabling push notifications
  unknown,
}

/// QR code data formats
enum QRFormat { url, openid, raw }

/// Security levels for QR content
enum SecurityLevel {
  unknown,
  low,
  medium,
  high;

  static SecurityLevel fromString(String value) {
    return SecurityLevel.values.firstWhere(
      (level) => level.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SecurityLevel.unknown,
    );
  }
}

/// Risk levels for privacy analysis
enum RiskLevel { minimal, low, medium, high }

/// Action types available for QR processing results
enum ActionType {
  presentation,
  selectiveDisclosure,
  credentialAcceptance,
  information,
  warning,
  decline,
}

/// Priority levels for actions
enum ActionPriority { low, medium, high }

/// Compatibility levels for credentials
enum CompatibilityLevel {
  unknown,
  unsupported,
  basic,
  full,
  enhanced;

  static CompatibilityLevel fromString(String value) {
    return CompatibilityLevel.values.firstWhere(
      (level) => level.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CompatibilityLevel.unknown,
    );
  }
}

/// Parsed QR data structure
class ParsedQRData {
  final QRType type;
  final QRFormat format;
  final String rawData;
  final Map<String, dynamic>? parsedContent;
  final Map<String, dynamic> metadata;

  const ParsedQRData({
    required this.type,
    required this.format,
    required this.rawData,
    this.parsedContent,
    required this.metadata,
  });
}

/// Validated QR result with SDK verification
class ValidatedQRResult {
  final ParsedQRData parsedData;
  final bool isValid;
  final List<String> validationErrors;
  final SecurityLevel securityLevel;
  final List<String> recommendedActions;
  final Map<String, dynamic> sdkCapabilities;

  const ValidatedQRResult({
    required this.parsedData,
    required this.isValid,
    required this.validationErrors,
    required this.securityLevel,
    required this.recommendedActions,
    required this.sdkCapabilities,
  });
}

/// Matching credential information
class MatchingCredential {
  final String credentialId;
  final String credentialName;
  final String issuer;
  final List<String> matchingAttributes;
  final int totalAttributes;
  final int matchScore;
  final Map<String, dynamic> capabilities;
  final SecurityLevel securityLevel;

  const MatchingCredential({
    required this.credentialId,
    required this.credentialName,
    required this.issuer,
    required this.matchingAttributes,
    required this.totalAttributes,
    required this.matchScore,
    required this.capabilities,
    required this.securityLevel,
  });
}

/// Privacy analysis for presentation requests
class PrivacyAnalysis {
  final RiskLevel overallRiskLevel;
  final Map<String, double> attributeRisks;
  final List<String> recommendations;
  final List<String> dataMinimizationOpportunities;

  const PrivacyAnalysis({
    required this.overallRiskLevel,
    required this.attributeRisks,
    required this.recommendations,
    required this.dataMinimizationOpportunities,
  });
}

/// Credential compatibility analysis
class CredentialCompatibility {
  final String credentialType;
  final String format;
  final bool isSupported;
  final CompatibilityLevel supportLevel;
  final List<String> requiredCapabilities;
  final List<String> availableCapabilities;
  final List<String> missingCapabilities;

  const CredentialCompatibility({
    required this.credentialType,
    required this.format,
    required this.isSupported,
    required this.supportLevel,
    required this.requiredCapabilities,
    required this.availableCapabilities,
    required this.missingCapabilities,
  });
}

/// Available action for QR result
class QRAction {
  final String id;
  final String title;
  final String description;
  final ActionType type;
  final ActionPriority priority;
  final bool requiresUserConsent;
  final Map<String, dynamic> metadata;

  const QRAction({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.requiresUserConsent,
    required this.metadata,
  });
}

/// Enriched QR result with credential matching
class EnrichedQRResult {
  final ValidatedQRResult validatedResult;
  final List<MatchingCredential> matchingCredentials;
  final List<QRAction> availableActions;
  final PrivacyAnalysis? privacyAnalysis;
  final List<CredentialCompatibility>? credentialCompatibility;

  const EnrichedQRResult({
    required this.validatedResult,
    required this.matchingCredentials,
    required this.availableActions,
    this.privacyAnalysis,
    this.credentialCompatibility,
  });

  /// Automatic handling requires positive, nonempty compatibility evidence.
  /// Unknown offers remain available through the explicit review action.
  bool get canAutoHandleOffer {
    final compatibility = credentialCompatibility;
    return validatedResult.isValid &&
        validatedResult.parsedData.type == QRType.credentialOffer &&
        compatibility != null &&
        compatibility.isNotEmpty &&
        compatibility.every(
          (credential) =>
              credential.isSupported &&
              credential.supportLevel != CompatibilityLevel.unknown &&
              credential.supportLevel != CompatibilityLevel.unsupported,
        );
  }
}

/// Final processed QR result
class ProcessedQRResult {
  final bool isSuccess;
  final String? errorMessage;
  final EnrichedQRResult? enrichedResult;

  const ProcessedQRResult._({
    required this.isSuccess,
    this.errorMessage,
    this.enrichedResult,
  });

  factory ProcessedQRResult.success({
    required EnrichedQRResult enrichedResult,
  }) {
    return ProcessedQRResult._(isSuccess: true, enrichedResult: enrichedResult);
  }

  factory ProcessedQRResult.error(String errorMessage) {
    return ProcessedQRResult._(isSuccess: false, errorMessage: errorMessage);
  }
}
