import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart';
import 'package:marty_authenticator/utils/logger.dart';

/// Service for managing presentation policies with background sync.
///
/// Handles:
/// - Periodic policy sync from backend
/// - Secure local caching
/// - Policy lookup by verifier ID or credential type
/// - Integration with credential transport for presentation
class PolicyService {
  static const String _policyCacheKey = 'cached_policies';
  static const String _lastSyncKey = 'last_policy_sync';
  static const Duration _syncInterval = Duration(hours: 24);

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Timer? _syncTimer;
  List<PresentationPolicy>? _cachedPolicies;

  /// Initialize the policy service and start background sync.
  ///
  /// [licenseJwt] - License JWT for authentication
  /// [endpoint] - Backend API endpoint
  /// [syncInterval] - Optional custom sync interval (defaults to 24 hours)
  Future<void> initialize({
    required String licenseJwt,
    required String endpoint,
    Duration? syncInterval,
  }) async {
    // Load cached policies
    await _loadCachedPolicies();

    // Initial sync
    await syncPolicies(licenseJwt: licenseJwt, endpoint: endpoint);

    // Start periodic background sync
    _startBackgroundSync(
      licenseJwt: licenseJwt,
      endpoint: endpoint,
      interval: syncInterval ?? _syncInterval,
    );
  }

  /// Manually trigger policy sync.
  Future<void> syncPolicies({
    required String licenseJwt,
    required String endpoint,
  }) async {
    try {
      // Call Rust FFI to fetch policies
      final policies = await RustLib.instance.api.syncPolicies(
        licenseJwt: licenseJwt,
        endpoint: endpoint,
      );

      _cachedPolicies = policies;

      // Cache policies securely
      await _cachePolicies(policies);

      // Update last sync timestamp
      await _secureStorage.write(
        key: _lastSyncKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Log error but don't throw - allow offline operation
      Logger.warning('Policy sync failed: $e');
    }
  }

  /// Get all cached policies.
  Future<List<PresentationPolicy>> getAllPolicies() async {
    if (_cachedPolicies == null) {
      await _loadCachedPolicies();
    }
    return _cachedPolicies ?? [];
  }

  /// Get policy by ID.
  Future<PresentationPolicy?> getPolicyById(String policyId) async {
    final policies = await getAllPolicies();
    try {
      return policies.firstWhere((p) => p.id == policyId);
    } catch (e) {
      return null;
    }
  }

  /// Get policies applicable to a credential type.
  Future<List<PresentationPolicy>> getPoliciesForCredentialType(
    String credentialType,
  ) async {
    final policies = await getAllPolicies();
    return policies
        .where((p) => p.acceptedCredentialTypes.contains(credentialType))
        .toList();
  }

  /// Evaluate a presentation request against cached policies.
  Future<PolicyEvaluationResult> evaluatePresentationRequest({
    required String requestJson,
    required List<dynamic> credentials,
  }) async {
    final policies = await getAllPolicies();
    final policiesJson = policies.map((p) => jsonEncode(p.toJson())).toList();

    return await RustLib.instance.api.evaluatePresentationRequest(
      requestJson: requestJson,
      policiesJson: policiesJson,
      credentials: credentials,
    );
  }

  /// Get minimum disclosure set for a credential based on policy.
  Future<List<String>> getMinimumDisclosureSet({
    required PresentationPolicy policy,
    required dynamic credential,
  }) async {
    return await RustLib.instance.api.getMinimumDisclosureSet(
      policyJson: jsonEncode(policy.toJson()),
      credential: credential,
    );
  }

  /// Rank credentials according to policy preferences.
  Future<List<String>> rankMatchingCredentials({
    required PresentationPolicy policy,
    required List<RankableCredentialInput> credentials,
  }) async {
    return await RustLib.instance.api.rankMatchingCredentials(
      policyJson: jsonEncode(policy.toJson()),
      credentials: credentials,
    );
  }

  /// Check if issuer satisfies policy constraints.
  Future<IssuerCheckResultOutput> checkIssuerConstraints({
    required PresentationPolicy policy,
    required String issuerId,
    required bool trustProfileVerified,
  }) async {
    return await RustLib.instance.api.checkIssuerConstraints(
      policyJson: jsonEncode(policy.toJson()),
      issuerId: issuerId,
      trustProfileVerified: trustProfileVerified,
    );
  }

  /// Check if policies need refresh based on last sync time.
  Future<bool> needsRefresh() async {
    final lastSyncStr = await _secureStorage.read(key: _lastSyncKey);
    if (lastSyncStr == null) return true;

    final lastSync = DateTime.parse(lastSyncStr);
    final now = DateTime.now();
    return now.difference(lastSync) > _syncInterval;
  }

  /// Dispose resources and stop background sync.
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Private helper methods

  void _startBackgroundSync({
    required String licenseJwt,
    required String endpoint,
    required Duration interval,
  }) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) async {
      await syncPolicies(licenseJwt: licenseJwt, endpoint: endpoint);
    });
  }

  Future<void> _loadCachedPolicies() async {
    try {
      final cachedJson = await _secureStorage.read(key: _policyCacheKey);
      if (cachedJson != null) {
        final List<dynamic> policiesList = jsonDecode(cachedJson);
        _cachedPolicies = policiesList
            .map((json) => PresentationPolicy.fromJson(json))
            .toList();
      }
    } catch (e) {
      Logger.warning('Failed to load cached policies: $e');
      _cachedPolicies = [];
    }
  }

  Future<void> _cachePolicies(List<PresentationPolicy> policies) async {
    try {
      final policiesJson = policies.map((p) => p.toJson()).toList();
      await _secureStorage.write(
        key: _policyCacheKey,
        value: jsonEncode(policiesJson),
      );
    } catch (e) {
      Logger.warning('Failed to cache policies: $e');
    }
  }
}

/// Presentation policy model (matches Rust/Python domain model).
class PresentationPolicy {
  final String id;
  final String name;
  final String? description;
  final String purpose;
  final List<String> acceptedCredentialTypes;
  final List<RequiredClaim> requiredClaims;
  final String holderBinding;
  final String? trustProfileId;
  final List<String> allowedIssuers;
  final Map<String, dynamic> freshnessRequirements;
  final bool preferPredicates;
  final bool singlePresentation;
  final Map<String, String> derivedAttributePreferences;
  final String credentialRankingStrategy;
  final Map<String, double> credentialRankingWeights;
  final int version;

  PresentationPolicy({
    required this.id,
    required this.name,
    this.description,
    required this.purpose,
    required this.acceptedCredentialTypes,
    required this.requiredClaims,
    required this.holderBinding,
    this.trustProfileId,
    required this.allowedIssuers,
    required this.freshnessRequirements,
    required this.preferPredicates,
    required this.singlePresentation,
    required this.derivedAttributePreferences,
    required this.credentialRankingStrategy,
    required this.credentialRankingWeights,
    required this.version,
  });

  factory PresentationPolicy.fromJson(Map<String, dynamic> json) {
    return PresentationPolicy(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      purpose: json['purpose'],
      acceptedCredentialTypes: List<String>.from(
        json['accepted_credential_types'],
      ),
      requiredClaims: (json['required_claims'] as List)
          .map((c) => RequiredClaim.fromJson(c))
          .toList(),
      holderBinding: json['holder_binding'],
      trustProfileId: json['trust_profile_id'],
      allowedIssuers: List<String>.from(json['allowed_issuers'] ?? []),
      freshnessRequirements: json['freshness_requirements'],
      preferPredicates: json['prefer_predicates'],
      singlePresentation: json['single_presentation'],
      derivedAttributePreferences: Map<String, String>.from(
        json['derived_attribute_preferences'] ?? {},
      ),
      credentialRankingStrategy: json['credential_ranking_strategy'],
      credentialRankingWeights: Map<String, double>.from(
        json['credential_ranking_weights'] ?? {},
      ),
      version: json['version'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'purpose': purpose,
      'accepted_credential_types': acceptedCredentialTypes,
      'required_claims': requiredClaims.map((c) => c.toJson()).toList(),
      'holder_binding': holderBinding,
      'trust_profile_id': trustProfileId,
      'allowed_issuers': allowedIssuers,
      'freshness_requirements': freshnessRequirements,
      'prefer_predicates': preferPredicates,
      'single_presentation': singlePresentation,
      'derived_attribute_preferences': derivedAttributePreferences,
      'credential_ranking_strategy': credentialRankingStrategy,
      'credential_ranking_weights': credentialRankingWeights,
      'version': version,
    };
  }
}

/// Required claim specification.
class RequiredClaim {
  final String claimName;
  final String credentialType;
  final bool acceptPredicate;
  final dynamic requiredValue;

  RequiredClaim({
    required this.claimName,
    required this.credentialType,
    required this.acceptPredicate,
    this.requiredValue,
  });

  factory RequiredClaim.fromJson(Map<String, dynamic> json) {
    return RequiredClaim(
      claimName: json['claim_name'],
      credentialType: json['credential_type'],
      acceptPredicate: json['accept_predicate'],
      requiredValue: json['required_value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'claim_name': claimName,
      'credential_type': credentialType,
      'accept_predicate': acceptPredicate,
      'required_value': requiredValue,
    };
  }
}
