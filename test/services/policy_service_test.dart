import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:marty_authenticator/services/policy_service.dart';
import 'package:marty_authenticator/rust/src/api.dart' as marty_bridge;

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([FlutterSecureStorage])
void main() {
  group('PolicyService', () {
    late PolicyService policyService;
    late MockFlutterSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      policyService = PolicyService(storage: mockStorage);
    });

    tearDown(() {
      policyService.dispose();
    });

    test('should initialize with empty policies', () {
      expect(policyService.policies, isEmpty);
    });

    test('should load cached policies from storage on init', () async {
      // Arrange
      const cachedJson = '''
      [
        {
          "id": "policy-1",
          "name": "Test Policy",
          "credential_types": ["emrtd"],
          "required_claims": [
            {
              "claim_path": "credentialSubject.firstName",
              "constraints": {},
              "display_name": "First Name"
            }
          ],
          "optional_claims": [],
          "allowed_issuers": [],
          "derived_attribute_preferences": {},
          "require_trust_profile": false,
          "max_credential_age_days": null,
          "credential_ranking_strategy": "FRESHEST_FIRST",
          "credential_ranking_weights": {},
          "version": 1
        }
      ]
      ''';

      when(
        mockStorage.read(key: 'cached_policies'),
      ).thenAnswer((_) async => cachedJson);

      // Act
      await policyService.initialize();

      // Assert
      expect(policyService.policies, hasLength(1));
      expect(policyService.policies.first.id, equals('policy-1'));
      expect(policyService.policies.first.name, equals('Test Policy'));
      verify(mockStorage.read(key: 'cached_policies')).called(1);
    });

    test('should handle missing cache gracefully', () async {
      // Arrange
      when(
        mockStorage.read(key: 'cached_policies'),
      ).thenAnswer((_) async => null);

      // Act
      await policyService.initialize();

      // Assert
      expect(policyService.policies, isEmpty);
    });

    test('should handle invalid JSON in cache', () async {
      // Arrange
      when(
        mockStorage.read(key: 'cached_policies'),
      ).thenAnswer((_) async => 'invalid json');

      // Act
      await policyService.initialize();

      // Assert
      expect(policyService.policies, isEmpty);
    });

    test('should find policy by credential type', () {
      // Arrange
      final policy1 = PresentationPolicy(
        id: 'policy-1',
        name: 'EMRTD Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [],
        optionalClaims: [],
        allowedIssuers: [],
        derivedAttributePreferences: {},
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      final policy2 = PresentationPolicy(
        id: 'policy-2',
        name: 'DTC Policy',
        credentialTypes: ['dtc'],
        requiredClaims: [],
        optionalClaims: [],
        allowedIssuers: [],
        derivedAttributePreferences: {},
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      policyService.updatePolicies([policy1, policy2]);

      // Act
      final found = policyService.findPolicyByCredentialType('emrtd');

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals('policy-1'));
      expect(found.name, equals('EMRTD Policy'));
    });

    test('should return null when policy not found', () {
      // Arrange
      final policy = PresentationPolicy(
        id: 'policy-1',
        name: 'EMRTD Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [],
        optionalClaims: [],
        allowedIssuers: [],
        derivedAttributePreferences: {},
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      policyService.updatePolicies([policy]);

      // Act
      final found = policyService.findPolicyByCredentialType('open-badge');

      // Assert
      expect(found, isNull);
    });

    test('should get minimum disclosure set for policy', () {
      // Arrange
      final requiredClaim1 = RequiredClaim(
        claimPath: 'credentialSubject.firstName',
        constraints: {},
        displayName: 'First Name',
      );

      final requiredClaim2 = RequiredClaim(
        claimPath: 'credentialSubject.lastName',
        constraints: {},
        displayName: 'Last Name',
      );

      final optionalClaim = RequiredClaim(
        claimPath: 'credentialSubject.address',
        constraints: {},
        displayName: 'Address',
      );

      final policy = PresentationPolicy(
        id: 'policy-1',
        name: 'Test Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [requiredClaim1, requiredClaim2],
        optionalClaims: [optionalClaim],
        allowedIssuers: [],
        derivedAttributePreferences: {},
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      // Act
      final minimumSet = policyService.getMinimumDisclosureSet(policy);

      // Assert
      expect(minimumSet, hasLength(2));
      expect(
        minimumSet.map((c) => c.claimPath),
        containsAll([
          'credentialSubject.firstName',
          'credentialSubject.lastName',
        ]),
      );
      expect(
        minimumSet.map((c) => c.claimPath),
        isNot(contains('credentialSubject.address')),
      );
    });

    test('should check if claim is required', () {
      // Arrange
      final requiredClaim = RequiredClaim(
        claimPath: 'credentialSubject.firstName',
        constraints: {},
        displayName: 'First Name',
      );

      final optionalClaim = RequiredClaim(
        claimPath: 'credentialSubject.address',
        constraints: {},
        displayName: 'Address',
      );

      final policy = PresentationPolicy(
        id: 'policy-1',
        name: 'Test Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [requiredClaim],
        optionalClaims: [optionalClaim],
        allowedIssuers: [],
        derivedAttributePreferences: {},
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      // Act & Assert
      expect(
        policyService.isClaimRequired(policy, 'credentialSubject.firstName'),
        isTrue,
      );
      expect(
        policyService.isClaimRequired(policy, 'credentialSubject.address'),
        isFalse,
      );
      expect(
        policyService.isClaimRequired(policy, 'credentialSubject.unknown'),
        isFalse,
      );
    });

    test('should get derived attribute preference', () {
      // Arrange
      final policy = PresentationPolicy(
        id: 'policy-1',
        name: 'Test Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [],
        optionalClaims: [],
        allowedIssuers: [],
        derivedAttributePreferences: {
          'dateOfBirth': 'age_over_18',
          'address': 'country_only',
        },
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      // Act & Assert
      expect(
        policyService.getDerivedAttributePreference(policy, 'dateOfBirth'),
        equals('age_over_18'),
      );
      expect(
        policyService.getDerivedAttributePreference(policy, 'address'),
        equals('country_only'),
      );
      expect(
        policyService.getDerivedAttributePreference(policy, 'unknown'),
        isNull,
      );
    });

    test('should update policies and notify listeners', () async {
      // Arrange
      var notificationCount = 0;
      policyService.addListener(() {
        notificationCount++;
      });

      final policy = PresentationPolicy(
        id: 'policy-1',
        name: 'Test Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [],
        optionalClaims: [],
        allowedIssuers: [],
        derivedAttributePreferences: {},
        requireTrustProfile: false,
        maxCredentialAgeDays: null,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      when(
        mockStorage.write(key: 'cached_policies', value: anyNamed('value')),
      ).thenAnswer((_) async => {});

      // Act
      await policyService.updatePolicies([policy]);

      // Assert
      expect(policyService.policies, hasLength(1));
      expect(notificationCount, equals(1));
      verify(
        mockStorage.write(key: 'cached_policies', value: anyNamed('value')),
      ).called(1);
    });

    test('should parse RequiredClaim from JSON', () {
      // Arrange
      final json = {
        'claim_path': 'credentialSubject.firstName',
        'constraints': {'max_length': 50},
        'display_name': 'First Name',
      };

      // Act
      final claim = RequiredClaim.fromJson(json);

      // Assert
      expect(claim.claimPath, equals('credentialSubject.firstName'));
      expect(claim.displayName, equals('First Name'));
      expect(claim.constraints['max_length'], equals(50));
    });

    test('should serialize RequiredClaim to JSON', () {
      // Arrange
      final claim = RequiredClaim(
        claimPath: 'credentialSubject.lastName',
        constraints: {'required': true},
        displayName: 'Last Name',
      );

      // Act
      final json = claim.toJson();

      // Assert
      expect(json['claim_path'], equals('credentialSubject.lastName'));
      expect(json['display_name'], equals('Last Name'));
      expect(json['constraints'], equals({'required': true}));
    });

    test('should parse PresentationPolicy from JSON', () {
      // Arrange
      final json = {
        'id': 'policy-1',
        'name': 'Test Policy',
        'credential_types': ['emrtd', 'dtc'],
        'required_claims': [
          {
            'claim_path': 'credentialSubject.firstName',
            'constraints': {},
            'display_name': 'First Name',
          },
        ],
        'optional_claims': [],
        'allowed_issuers': ['did:example:issuer-1'],
        'derived_attribute_preferences': {'dateOfBirth': 'age_over_18'},
        'require_trust_profile': true,
        'max_credential_age_days': 90,
        'credential_ranking_strategy': 'HIGHEST_TRUST_FIRST',
        'credential_ranking_weights': {'trust': 0.8},
        'version': 2,
      };

      // Act
      final policy = PresentationPolicy.fromJson(json);

      // Assert
      expect(policy.id, equals('policy-1'));
      expect(policy.name, equals('Test Policy'));
      expect(policy.credentialTypes, hasLength(2));
      expect(policy.requiredClaims, hasLength(1));
      expect(policy.allowedIssuers, contains('did:example:issuer-1'));
      expect(
        policy.derivedAttributePreferences['dateOfBirth'],
        equals('age_over_18'),
      );
      expect(policy.requireTrustProfile, isTrue);
      expect(policy.maxCredentialAgeDays, equals(90));
      expect(policy.credentialRankingStrategy, equals('HIGHEST_TRUST_FIRST'));
      expect(policy.version, equals(2));
    });

    test('should serialize PresentationPolicy to JSON', () {
      // Arrange
      final policy = PresentationPolicy(
        id: 'policy-1',
        name: 'Test Policy',
        credentialTypes: ['emrtd'],
        requiredClaims: [],
        optionalClaims: [],
        allowedIssuers: ['did:example:issuer-1'],
        derivedAttributePreferences: {'dateOfBirth': 'age_over_18'},
        requireTrustProfile: true,
        maxCredentialAgeDays: 90,
        credentialRankingStrategy: 'FRESHEST_FIRST',
        credentialRankingWeights: {},
        version: 1,
      );

      // Act
      final json = policy.toJson();

      // Assert
      expect(json['id'], equals('policy-1'));
      expect(json['name'], equals('Test Policy'));
      expect(json['credential_types'], equals(['emrtd']));
      expect(json['allowed_issuers'], contains('did:example:issuer-1'));
      expect(json['require_trust_profile'], isTrue);
      expect(json['max_credential_age_days'], equals(90));
    });
  });
}
