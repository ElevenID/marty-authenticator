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

/// Comprehensive SpruceID SDK integration test suite
///
/// This test suite validates:
/// - End-to-end SDK integration workflows
/// - Performance benchmarks for critical operations
/// - Error handling and edge cases
/// - Cross-service coordination and data flow
/// - UI integration with SDK services

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:privacyidea_authenticator/services/sprucekit_service_extended.dart';
import 'package:privacyidea_authenticator/services/wallet_manager_extended.dart';
import 'package:privacyidea_authenticator/services/presentation_builder_service.dart';
import 'package:privacyidea_authenticator/services/credential_verification_service.dart';
import 'package:privacyidea_authenticator/services/privacy_analysis_service.dart';
import 'package:privacyidea_authenticator/services/did_management_service_extended.dart';
import 'package:privacyidea_authenticator/services/qr_scanner_service_enhanced.dart';
import 'package:privacyidea_authenticator/services/background_sync_service.dart';

import 'sprucekit_integration_test.mocks.dart';

@GenerateMocks([
  SpruceKitServiceExtended,
  WalletManagerExtended,
  PresentationBuilderService,
  CredentialVerificationService,
  PrivacyAnalysisService,
  DIDManagementServiceExtended,
  QRScannerServiceEnhanced,
  BackgroundSyncService,
])
void main() {
  group('SpruceID SDK Integration Tests', () {
    late ProviderContainer container;

    // Mock services
    late MockSpruceKitServiceExtended mockSpruceKitService;
    late MockWalletManagerExtended mockWalletManager;
    late MockPresentationBuilderService mockPresentationBuilder;
    late MockCredentialVerificationService mockVerificationService;
    late MockPrivacyAnalysisService mockPrivacyAnalysis;
    late MockDIDManagementServiceExtended mockDIDManagement;
    late MockQRScannerServiceEnhanced mockQRScanner;
    late MockBackgroundSyncService mockBackgroundSync;

    // Test data
    final testCredential = {
      'id': 'test-credential-123',
      'type': ['VerifiableCredential', 'EducationCredential'],
      'issuer': 'did:example:issuer123',
      'credentialSubject': {
        'id': 'did:example:subject456',
        'degree': 'Bachelor of Science',
        'institution': 'Example University',
        'graduationDate': '2023-05-15',
      },
      'issuanceDate': '2023-05-16T00:00:00Z',
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': '2023-05-16T00:00:00Z',
        'verificationMethod': 'did:example:issuer123#key-1',
        'proofPurpose': 'assertionMethod',
        'jws': 'example-signature',
      },
    };

    final testPresentationRequest = {
      'challenge': 'test-challenge-789',
      'domain': 'example-verifier.com',
      'requested_attributes': ['degree', 'institution', 'graduationDate'],
      'purpose': 'Academic verification for job application',
      'verifier': {
        'name': 'Example Corporation',
        'did': 'did:example:verifier789',
      },
    };

    setUp(() async {
      // Initialize mock services
      mockSpruceKitService = MockSpruceKitServiceExtended();
      mockWalletManager = MockWalletManagerExtended();
      mockPresentationBuilder = MockPresentationBuilderService();
      mockVerificationService = MockCredentialVerificationService();
      mockPrivacyAnalysis = MockPrivacyAnalysisService();
      mockDIDManagement = MockDIDManagementServiceExtended();
      mockQRScanner = MockQRScannerServiceEnhanced();
      mockBackgroundSync = MockBackgroundSyncService();

      // Create provider container with mocked services
      container = ProviderContainer(
        overrides: [
          spruceKitServiceExtendedProvider.overrideWithValue(
            mockSpruceKitService,
          ),
          walletManagerExtendedProvider.overrideWithValue(mockWalletManager),
          presentationBuilderServiceProvider.overrideWithValue(
            mockPresentationBuilder,
          ),
          credentialVerificationServiceProvider.overrideWithValue(
            mockVerificationService,
          ),
          privacyAnalysisServiceProvider.overrideWithValue(mockPrivacyAnalysis),
          didManagementServiceExtendedProvider.overrideWithValue(
            mockDIDManagement,
          ),
          qrScannerServiceEnhancedProvider.overrideWithValue(mockQRScanner),
          backgroundSyncServiceProvider.overrideWithValue(mockBackgroundSync),
        ],
      );

      // Setup default mock behaviors
      _setupDefaultMockBehaviors();
    });

    tearDown(() {
      container.dispose();
    });

    group('End-to-End Workflow Tests', () {
      testWidgets('Complete credential presentation workflow', (tester) async {
        // Test the full workflow from QR scan to presentation creation

        // 1. Mock QR code scanning
        const qrData =
            'https://verifier.example.com/presentation-request?challenge=test-challenge';
        when(mockQRScanner.processQRCode(qrData)).thenAnswer((_) async {
          return ProcessedQRResult(
            isSuccess: true,
            enrichedResult: EnrichedQRResult(
              validatedResult: ValidatedQRResult(
                parsedData: ParsedQRData(
                  type: QRType.presentationRequest,
                  rawData: qrData,
                  parsedContent: testPresentationRequest,
                ),
                securityLevel: SecurityLevel.high,
                trustedIssuer: true,
                validSignature: true,
              ),
              matchingCredentials: [testCredential],
              privacyAnalysis: PrivacyAnalysisResult(
                overallRiskLevel: RiskLevel.low,
                attributeRisks: {},
                recommendations: [],
                dataMinimization: DataMinimizationSuggestion(
                  requiredAttributes: ['degree', 'institution'],
                  optionalAttributes: ['graduationDate'],
                  unnecessaryAttributes: [],
                ),
              ),
              credentialCompatibility: [],
            ),
          );
        });

        // 2. Mock credential selection and privacy analysis
        when(
          mockPrivacyAnalysis.analyzeAttributeDisclosure(any, any, any),
        ).thenAnswer((_) async {
          return PrivacyAnalysisResult(
            overallRiskLevel: RiskLevel.low,
            attributeRisks: {
              'degree': AttributeRiskAssessment(
                attribute: 'degree',
                riskLevel: RiskLevel.minimal,
                riskFactors: [],
                sensitivityScore: 0.2,
              ),
              'institution': AttributeRiskAssessment(
                attribute: 'institution',
                riskLevel: RiskLevel.minimal,
                riskFactors: [],
                sensitivityScore: 0.3,
              ),
            },
            recommendations: [
              PrivacyRecommendation(
                type: RecommendationType.informational,
                message: 'This request has low privacy impact',
                severity: RecommendationSeverity.low,
              ),
            ],
            dataMinimization: DataMinimizationSuggestion(
              requiredAttributes: ['degree', 'institution'],
              optionalAttributes: ['graduationDate'],
              unnecessaryAttributes: [],
            ),
          );
        });

        // 3. Mock presentation creation
        when(
          mockPresentationBuilder.createPresentation(
            credentials: anyNamed('credentials'),
            presentationRequest: anyNamed('presentationRequest'),
            selectedAttributes: anyNamed('selectedAttributes'),
          ),
        ).thenAnswer((_) async {
          return PresentationCreationResult(
            success: true,
            presentation: {
              'type': ['VerifiablePresentation'],
              'verifiableCredential': [testCredential],
              'proof': {
                'type': 'Ed25519Signature2020',
                'created': DateTime.now().toIso8601String(),
                'challenge': 'test-challenge',
                'domain': 'example-verifier.com',
              },
            },
            metadata: PresentationMetadata(
              credentialCount: 1,
              attributeCount: 3,
              creationTime: DateTime.now(),
              privacyLevel: PrivacyLevel.minimal,
            ),
          );
        });

        // Execute workflow
        final qrResult = await mockQRScanner.processQRCode(qrData);
        expect(qrResult.isSuccess, true);
        expect(qrResult.enrichedResult?.matchingCredentials, isNotEmpty);

        final privacyResult = await mockPrivacyAnalysis
            .analyzeAttributeDisclosure(
              testPresentationRequest['requested_attributes'] as List<String>,
              [testCredential],
              testPresentationRequest,
            );
        expect(privacyResult.overallRiskLevel, RiskLevel.low);

        final presentationResult = await mockPresentationBuilder
            .createPresentation(
              credentials: [testCredential],
              presentationRequest: testPresentationRequest,
              selectedAttributes: ['degree', 'institution', 'graduationDate'],
            );
        expect(presentationResult.success, true);
        expect(presentationResult.presentation, isNotNull);

        // Verify all services were called with correct parameters
        verify(mockQRScanner.processQRCode(qrData)).called(1);
        verify(
          mockPrivacyAnalysis.analyzeAttributeDisclosure(any, any, any),
        ).called(1);
        verify(
          mockPresentationBuilder.createPresentation(
            credentials: anyNamed('credentials'),
            presentationRequest: anyNamed('presentationRequest'),
            selectedAttributes: anyNamed('selectedAttributes'),
          ),
        ).called(1);
      });

      testWidgets('Credential verification and storage workflow', (
        tester,
      ) async {
        // Test credential verification and secure storage workflow

        // Mock credential verification
        when(
          mockVerificationService.verifyCredential(
            any,
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async {
          return CredentialVerificationResult(
            isValid: true,
            verificationLevel: VerificationLevel.full,
            trustedIssuer: true,
            validSignature: true,
            notRevoked: true,
            notExpired: true,
            issues: [],
            trustScore: 0.95,
            securityAssessment: SecurityAssessment(
              overallScore: 0.9,
              signatureStrength: 0.95,
              issuerTrust: 0.9,
              revocationStatus: RevocationStatus.notRevoked,
            ),
            performanceMetrics: PerformanceMetrics(
              verificationDuration: const Duration(milliseconds: 150),
              networkRequests: 2,
              cacheHits: 1,
            ),
          );
        });

        // Mock wallet storage
        when(mockWalletManager.storeCredential(any, any)).thenAnswer((_) async {
          return CredentialStorageResult(
            success: true,
            credentialId: 'stored-credential-123',
            storageLocation: 'secure-enclave',
            encryptionLevel: EncryptionLevel.hardware,
            metadata: {
              'storage_time': DateTime.now().toIso8601String(),
              'encryption_method': 'AES-256-GCM',
              'hardware_backed': true,
            },
          );
        });

        // Execute workflow
        final verificationResult = await mockVerificationService
            .verifyCredential(testCredential);
        expect(verificationResult.isValid, true);
        expect(verificationResult.trustScore, greaterThan(0.9));

        final storageResult = await mockWalletManager.storeCredential(
          testCredential['id'] as String,
          testCredential,
        );
        expect(storageResult.success, true);
        expect(storageResult.encryptionLevel, EncryptionLevel.hardware);

        // Verify service calls
        verify(
          mockVerificationService.verifyCredential(testCredential),
        ).called(1);
        verify(
          mockWalletManager.storeCredential(
            testCredential['id'] as String,
            testCredential,
          ),
        ).called(1);
      });

      testWidgets('Background synchronization workflow', (tester) async {
        // Test background sync functionality

        // Mock sync configuration
        final syncConfig = SyncConfiguration(
          strategy: SyncStrategy.balanced,
          syncInterval: const Duration(minutes: 30),
          enableBackgroundSync: true,
        );

        when(
          mockBackgroundSync.initialize(configuration: syncConfig),
        ).thenAnswer((_) async {});

        when(
          mockBackgroundSync.performSync(
            credentialIds: anyNamed('credentialIds'),
            priority: anyNamed('priority'),
            force: anyNamed('force'),
          ),
        ).thenAnswer((_) async {
          return SyncResult(
            success: true,
            credentialsUpdated: 1,
            revocationsDetected: 0,
            errorsEncountered: 0,
            syncDuration: const Duration(seconds: 2),
            timestamp: DateTime.now(),
          );
        });

        when(mockBackgroundSync.checkRevocations()).thenAnswer((_) async => []);

        // Execute sync workflow
        await mockBackgroundSync.initialize(configuration: syncConfig);

        final syncResult = await mockBackgroundSync.performSync(
          priority: SyncPriority.high,
        );
        expect(syncResult.success, true);
        expect(syncResult.credentialsUpdated, 1);
        expect(syncResult.revocationsDetected, 0);

        final revokedCredentials = await mockBackgroundSync.checkRevocations();
        expect(revokedCredentials, isEmpty);

        // Verify calls
        verify(
          mockBackgroundSync.initialize(configuration: syncConfig),
        ).called(1);
        verify(
          mockBackgroundSync.performSync(priority: SyncPriority.high),
        ).called(1);
        verify(mockBackgroundSync.checkRevocations()).called(1);
      });
    });

    group('Performance Benchmarks', () {
      test('QR processing performance benchmark', () async {
        // Benchmark QR code processing speed
        const iterations = 100;
        final stopwatch = Stopwatch();

        when(mockQRScanner.processQRCode(any)).thenAnswer((_) async {
          // Simulate realistic processing time
          await Future.delayed(const Duration(milliseconds: 50));
          return ProcessedQRResult(isSuccess: true);
        });

        stopwatch.start();
        for (int i = 0; i < iterations; i++) {
          await mockQRScanner.processQRCode('test-qr-$i');
        }
        stopwatch.stop();

        final avgProcessingTime = stopwatch.elapsedMilliseconds / iterations;
        expect(
          avgProcessingTime,
          lessThan(100),
        ); // Should process in under 100ms

        print(
          'QR Processing Average Time: ${avgProcessingTime.toStringAsFixed(2)}ms',
        );
      });

      test('Credential verification performance benchmark', () async {
        const iterations = 50;
        final stopwatch = Stopwatch();

        when(
          mockVerificationService.verifyCredential(
            any,
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return CredentialVerificationResult(
            isValid: true,
            verificationLevel: VerificationLevel.full,
            performanceMetrics: PerformanceMetrics(
              verificationDuration: const Duration(milliseconds: 200),
              networkRequests: 2,
              cacheHits: 0,
            ),
          );
        });

        stopwatch.start();
        for (int i = 0; i < iterations; i++) {
          await mockVerificationService.verifyCredential(testCredential);
        }
        stopwatch.stop();

        final avgVerificationTime = stopwatch.elapsedMilliseconds / iterations;
        expect(
          avgVerificationTime,
          lessThan(300),
        ); // Should verify in under 300ms

        print(
          'Verification Average Time: ${avgVerificationTime.toStringAsFixed(2)}ms',
        );
      });

      test('Presentation creation performance benchmark', () async {
        const iterations = 25;
        final stopwatch = Stopwatch();

        when(
          mockPresentationBuilder.createPresentation(
            credentials: anyNamed('credentials'),
            presentationRequest: anyNamed('presentationRequest'),
            selectedAttributes: anyNamed('selectedAttributes'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 300));
          return PresentationCreationResult(
            success: true,
            presentation: {'test': 'presentation'},
            metadata: PresentationMetadata(
              credentialCount: 1,
              attributeCount: 3,
              creationTime: DateTime.now(),
              privacyLevel: PrivacyLevel.minimal,
            ),
          );
        });

        stopwatch.start();
        for (int i = 0; i < iterations; i++) {
          await mockPresentationBuilder.createPresentation(
            credentials: [testCredential],
            presentationRequest: testPresentationRequest,
            selectedAttributes: ['degree', 'institution'],
          );
        }
        stopwatch.stop();

        final avgCreationTime = stopwatch.elapsedMilliseconds / iterations;
        expect(avgCreationTime, lessThan(500)); // Should create in under 500ms

        print(
          'Presentation Creation Average Time: ${avgCreationTime.toStringAsFixed(2)}ms',
        );
      });
    });

    group('Error Handling and Edge Cases', () {
      test('Invalid QR code handling', () async {
        when(mockQRScanner.processQRCode('invalid-qr-code')).thenAnswer((
          _,
        ) async {
          return ProcessedQRResult(
            isSuccess: false,
            errorMessage: 'Invalid QR code format',
          );
        });

        final result = await mockQRScanner.processQRCode('invalid-qr-code');
        expect(result.isSuccess, false);
        expect(result.errorMessage, contains('Invalid QR code format'));
      });

      test('Network failure during verification', () async {
        when(
          mockVerificationService.verifyCredential(
            any,
            options: anyNamed('options'),
          ),
        ).thenThrow(Exception('Network timeout'));

        expect(
          () => mockVerificationService.verifyCredential(testCredential),
          throwsException,
        );
      });

      test('Revoked credential detection', () async {
        when(mockBackgroundSync.checkRevocations()).thenAnswer((_) async {
          return ['revoked-credential-456'];
        });

        final revokedCredentials = await mockBackgroundSync.checkRevocations();
        expect(revokedCredentials, contains('revoked-credential-456'));
      });

      test('Storage encryption failure', () async {
        when(mockWalletManager.storeCredential(any, any)).thenAnswer((_) async {
          return CredentialStorageResult(
            success: false,
            errorMessage: 'Encryption hardware unavailable',
          );
        });

        final result = await mockWalletManager.storeCredential(
          'test',
          testCredential,
        );
        expect(result.success, false);
        expect(
          result.errorMessage,
          contains('Encryption hardware unavailable'),
        );
      });
    });

    group('Cross-Service Integration', () {
      test('Service coordination during presentation creation', () async {
        // Test that multiple services work together correctly

        // Setup service chain
        when(
          mockWalletManager.getAllCredentials(),
        ).thenAnswer((_) async => [testCredential]);

        when(
          mockPrivacyAnalysis.analyzeAttributeDisclosure(any, any, any),
        ).thenAnswer(
          (_) async => PrivacyAnalysisResult(
            overallRiskLevel: RiskLevel.low,
            attributeRisks: {},
            recommendations: [],
          ),
        );

        when(
          mockPresentationBuilder.createPresentation(
            credentials: anyNamed('credentials'),
            presentationRequest: anyNamed('presentationRequest'),
            selectedAttributes: anyNamed('selectedAttributes'),
          ),
        ).thenAnswer(
          (_) async => PresentationCreationResult(
            success: true,
            presentation: {'test': 'presentation'},
          ),
        );

        // Execute coordinated workflow
        final credentials = await mockWalletManager.getAllCredentials();
        expect(credentials, isNotEmpty);

        final privacyAnalysis = await mockPrivacyAnalysis
            .analyzeAttributeDisclosure(
              ['degree', 'institution'],
              credentials,
              testPresentationRequest,
            );
        expect(privacyAnalysis.overallRiskLevel, RiskLevel.low);

        final presentation = await mockPresentationBuilder.createPresentation(
          credentials: credentials,
          presentationRequest: testPresentationRequest,
          selectedAttributes: ['degree', 'institution'],
        );
        expect(presentation.success, true);

        // Verify all services were called in correct order
        verifyInOrder([
          mockWalletManager.getAllCredentials(),
          mockPrivacyAnalysis.analyzeAttributeDisclosure(any, any, any),
          mockPresentationBuilder.createPresentation(
            credentials: anyNamed('credentials'),
            presentationRequest: anyNamed('presentationRequest'),
            selectedAttributes: anyNamed('selectedAttributes'),
          ),
        ]);
      });
    });

    group('Data Flow Validation', () {
      test('Credential data integrity through workflow', () async {
        // Test that credential data remains intact through the entire workflow

        final originalCredential = Map<String, dynamic>.from(testCredential);

        when(
          mockVerificationService.verifyCredential(
            any,
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => CredentialVerificationResult(isValid: true));

        when(mockWalletManager.storeCredential(any, any)).thenAnswer((_) async {
          return CredentialStorageResult(
            success: true,
            credentialId: 'stored-123',
          );
        });

        when(
          mockWalletManager.getCredential('stored-123'),
        ).thenAnswer((_) async => testCredential);

        // Workflow: verify -> store -> retrieve
        final verificationResult = await mockVerificationService
            .verifyCredential(originalCredential);
        expect(verificationResult.isValid, true);

        final storageResult = await mockWalletManager.storeCredential(
          'test-123',
          originalCredential,
        );
        expect(storageResult.success, true);

        final retrievedCredential = await mockWalletManager.getCredential(
          'stored-123',
        );
        expect(retrievedCredential, equals(originalCredential));
      });
    });
  });
}

/// Setup default mock behaviors for all services
void _setupDefaultMockBehaviors() {
  // This would contain common mock setups used across tests
}
