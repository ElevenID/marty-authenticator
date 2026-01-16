/*
  Marty Authenticator - Web Test Build

  This is a specialized entry point for E2E testing with Playwright.
  It provides:
  - Test device ID injection via URL params or postMessage
  - Mock Firebase utilities (no actual Firebase)
  - postMessage handler for test coordination
  - Marty push service integration

  Usage:
    flutter build web --target=lib/mains/main_web_test.dart

  URL Parameters:
    - test_mode=true: Enable test mode
    - device_id=<id>: Inject device ID
    - org_id=<id>: Inject organization ID
    - api_url=<url>: Override API URL

  Authors: Adam Burdett
  Copyright (c) 2024-2025 Marty Trust Services
*/

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:flutter/services.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privacyidea_authenticator/utils/logger.dart';
import 'package:privacyidea_authenticator/utils/riverpod/riverpod_providers/generated_providers/localization_notifier.dart';

import '../../../../../../../model/riverpod_states/settings_state.dart';
import 'package:privacyidea_authenticator/l10n/app_localizations.dart';
import '../utils/customization/application_customization.dart';
import '../utils/globals.dart';
import '../utils/riverpod/riverpod_providers/generated_providers/app_constraints_notifier.dart';
import '../views/main_view/main_view.dart';
import '../views/main_view/document_view.dart';
import '../views/splash_screen/splash_screen.dart';
import '../widgets/app_wrapper.dart';

// Import mock services
import '../mocks/mock_spruce_services.dart';
import '../mocks/mock_qr_scanner_service.dart';
import '../utils/riverpod/providers/spruce_providers.dart';
import '../utils/riverpod/providers/credentials_provider.dart';

// Import Marty push service
import '../services/marty_push_service.dart';
import '../models/marty_challenge.dart';

// Import WASM interop for real crypto operations
import '../services/wasm/marty_wasm.dart';
import '../services/qr_scanner_service_enhanced.dart';
import '../services/spruce_client_extended.dart';
import '../utils/riverpod/riverpod_providers/generated_providers/token_notifier.dart';

/// Global test configuration
class TestConfig {
  static String? deviceId;
  static String? organizationId;
  static String? userId;
  static String apiUrl = 'http://localhost:8000';
  static bool testMode = false;

  /// Parse configuration from URL parameters
  static void parseFromUrl() {
    final uri = Uri.parse(html.window.location.href);
    final params = uri.queryParameters;

    testMode = params['test_mode']?.toLowerCase() == 'true';
    deviceId = params['device_id'];
    organizationId = params['org_id'];
    userId = params['user_id'];

    if (params.containsKey('api_url')) {
      apiUrl = params['api_url']!;
    }

    Logger.info(
      'TestConfig: testMode=$testMode, deviceId=$deviceId, orgId=$organizationId',
    );
  }
}

/// PostMessage handler for test coordination
class TestMessageHandler {
  static bool _isReady = false;

  static void init() {
    html.window.addEventListener('message', _handleMessage);
    Logger.info('TestMessageHandler: Listening for postMessage events');
    // Note: WALLET_READY is now sent via notifyWalletReady() after MainView builds
  }

  /// Call this after MainView has been built to notify tests that wallet UI is ready.
  /// This ensures providers are initialized and wallet menu is visible before
  /// Playwright tests proceed.
  static void notifyWalletReady() {
    if (_isReady) return; // Prevent duplicate signals
    _isReady = true;
    Logger.info('TestMessageHandler: Sending WALLET_READY signal');
    html.window.console.log('TestMessageHandler: WALLET_READY - UI is mounted');
    _sendToParent('WALLET_READY', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> _handleMessage(html.Event event) async {
    if (event is! html.MessageEvent) return;

    final messageEvent = event;

    try {
      final data = _coerceMessageData(messageEvent.data);
      if (data == null) return;

      final type = data['type'] as String?;
      final payload = _coerceMessageData(data['payload']);

      // Debug logging that always outputs
      html.window.console.log(
        'TestMessageHandler: Received message type=$type',
      );

      Logger.info('TestMessageHandler: Received message type=$type');

      switch (type) {
        case 'SCAN_QR_CODE':
          _handleQrCodeInjection(payload);
          break;
        case 'SET_DEVICE_ID':
          _handleSetDeviceId(payload);
          break;
        case 'GET_DEVICE_ID':
          _handleGetDeviceId();
          break;
        case 'GET_CREDENTIALS':
          await _handleGetCredentials();
          break;
        case 'GET_DISPLAY_CREDENTIALS':
          await _handleGetDisplayCredentials();
          break;
        case 'STORE_CREDENTIAL':
          await _handleStoreCredential(payload);
          break;
        case 'CLEAR_DATA':
          await _handleClearData();
          break;
        case 'INJECT_CHALLENGE':
          _handleInjectChallenge(payload);
          break;
        case 'PROCESS_OID4VP_REQUEST':
          _handleProcessOid4vpRequest(payload);
          break;
        case 'APPROVE_PRESENTATION':
          await _handleApprovePresentation(payload);
          break;
        case 'WASM_HEALTH_CHECK':
          _handleWasmHealthCheck();
          break;
        case 'WASM_GENERATE_KEY':
          await _handleWasmGenerateKey(payload);
          break;
        case 'WASM_CREATE_CREDENTIAL':
          await _handleWasmCreateCredential(payload);
          break;
        case 'WASM_CREATE_PRESENTATION':
          await _handleWasmCreatePresentation(payload);
          break;
        case 'REGISTER_PUSH_VIA_QR':
          await _handleRegisterPushViaQR(payload);
          break;
      }
    } catch (e) {
      Logger.error('TestMessageHandler: Error handling message', error: e);
    }
  }

  static Map<String, dynamic>? _coerceMessageData(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data as Map);
    }
    try {
      final converted = js_util.dartify(data);
      if (converted is Map) {
        return Map<String, dynamic>.from(converted as Map);
      }
    } catch (_) {}
    return null;
  }

  static void _handleQrCodeInjection(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final qrData = payload['data'] as String?;
    if (qrData == null) return;

    Logger.info('TestMessageHandler: Injecting QR code data');
    html.window.console.log(
      'TestMessageHandler: Injecting QR code via Enhanced Service',
    );

    try {
      final ref = globalRef;
      if (ref != null) {
        Future.microtask(() async {
          try {
            final service = ref.read(qrScannerServiceEnhancedProvider);
            final result = await service.processQRCode(qrData);

            if (result.isSuccess) {
              final contextKey = await contextedGlobalNavigatorKey;
              final context = contextKey.currentContext;

              if (context != null) {
                // Show dialog to satisfy E2E test requirement
                // ignore: use_build_context_synchronously
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Credential Offer'),
                    content: const Text('Accept this credential?'),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            await ref
                                .read(spruceIdClientExtendedProvider)
                                .handleOID4VCOfferSDK(credentialOffer: qrData);
                            html.window.console.log(
                              'TestMessageHandler: Offer accepted successfully',
                            );
                          } catch (e) {
                            html.window.console.log(
                              'TestMessageHandler: Accept failed: $e',
                            );
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                );
              }
            } else {
              html.window.console.log(
                'TestMessageHandler: processQRCode failed: ${result.errorMessage}',
              );
            }
          } catch (e) {
            html.window.console.log('TestMessageHandler: Service error: $e');
          }
        });
      }
    } catch (e) {
      Logger.error('TestMessageHandler: Failed to dispatch', error: e);
    }

    // Also inject into mock QR scanner as fallback
    final currentConfig = getMockQrScannerConfig();
    if (currentConfig != null) {
      // Add to pending scans - use qrQueue instead of pendingScans
      currentConfig.qrQueue.add(qrData);
      setMockQrScannerConfig(currentConfig);
    } else {
      // Create new config with the QR code
      setMockQrScannerConfig(MockQrScannerConfig.withCode(qrData));
    }

    _sendToParent('QR_CODE_INJECTED', {'success': true});
  }

  static void _handleSetDeviceId(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final deviceId = payload['device_id'] as String?;
    final orgId = payload['org_id'] as String?;

    if (deviceId != null) {
      TestConfig.deviceId = deviceId;
      html.window.localStorage['marty_device_id'] = deviceId;
    }
    if (orgId != null) {
      TestConfig.organizationId = orgId;
      html.window.localStorage['marty_org_id'] = orgId;
    }

    Logger.info('TestMessageHandler: Device ID set to $deviceId');
    _sendToParent('DEVICE_ID_SET', {'device_id': deviceId, 'org_id': orgId});
  }

  static void _handleGetDeviceId() {
    final deviceId =
        TestConfig.deviceId ?? html.window.localStorage['marty_device_id'];
    _sendToParent('DEVICE_ID', {'device_id': deviceId});
  }

  static Future<void> _handleGetCredentials() async {
    final stored = html.window.localStorage['marty_credentials'];
    final List<dynamic> credentials = stored != null ? jsonDecode(stored) : [];

    try {
      final ref = globalRef;
      if (ref != null) {
        final walletManager = ref.read(spruceIdWalletManagerProvider);
        final walletCredentials = await walletManager.getAllCredentials();
        for (final credential in walletCredentials) {
          final credentialId = credential['id']?.toString();
          final alreadyStored = credentials.any((existing) {
            if (existing is Map) {
              return existing['id']?.toString() == credentialId;
            }
            return false;
          });
          if (!alreadyStored) {
            credentials.add(credential);
          }
        }
      }
    } catch (e) {
      Logger.warning(
        'TestMessageHandler: Failed to read wallet credentials: $e',
      );
    }

    _sendToParent('CREDENTIALS', {'credentials': credentials});
  }

  static Future<void> _handleGetDisplayCredentials() async {
    try {
      final ref = globalRef;
      if (ref == null) {
        _sendToParent('DISPLAY_CREDENTIALS', {'credentials': []});
        return;
      }

      final state = ref.read(credentialsProvider);
      final credentials = state.verifiableCredentials.map((credential) {
        return {
          'id': credential.id,
          'type': credential.credentialType,
          'issuer': credential.issuer,
          'credentialSubject': credential.credentialSubject,
          'issuanceDate': credential.issuanceDate,
          'expirationDate': credential.expirationDate,
          'subjectName': credential.displayName,
          'credentialType': credential.credentialType,
        };
      }).toList();

      _sendToParent('DISPLAY_CREDENTIALS', {'credentials': credentials});
    } catch (e) {
      Logger.warning(
        'TestMessageHandler: Failed to read display credentials: $e',
      );
      _sendToParent('DISPLAY_CREDENTIALS', {'credentials': []});
    }
  }

  /// Store a credential to localStorage (for testing)
  static Future<void> _handleStoreCredential(
    Map<String, dynamic>? payload,
  ) async {
    if (payload == null) return;

    final credential = payload['credential'];
    if (credential == null) {
      _sendToParent('CREDENTIAL_STORED', {
        'success': false,
        'error': 'No credential provided',
      });
      return;
    }

    try {
      final Map<String, dynamic> credentialMap =
          credential is Map<String, dynamic>
          ? credential
          : Map<String, dynamic>.from(credential as Map);
      final stored = html.window.localStorage['marty_credentials'];
      final List<dynamic> credentials = stored != null
          ? jsonDecode(stored)
          : [];
      credentials.add(credentialMap);
      html.window.localStorage['marty_credentials'] = jsonEncode(credentials);

      Logger.info(
        'TestMessageHandler: Credential stored, total=${credentials.length}',
      );
      final ref = globalRef;
      if (ref != null) {
        final walletManager = ref.read(spruceIdWalletManagerProvider);
        await walletManager.storeCredential(credentialMap);
        await ref.read(credentialsProvider.notifier).refreshCredentials();
      }

      _sendToParent('CREDENTIAL_STORED', {
        'success': true,
        'count': credentials.length,
      });
    } catch (e) {
      Logger.error('Failed to store credential', error: e);
      _sendToParent('CREDENTIAL_STORED', {
        'success': false,
        'error': e.toString(),
      });
    }
  }

  /// Process an OID4VP presentation request
  /// This simulates wallet receiving a presentation request and finding matching credentials
  static void _handleProcessOid4vpRequest(Map<String, dynamic>? payload) {
    if (payload == null) {
      _sendToParent('OID4VP_PROCESSED', {
        'success': false,
        'error': 'No payload',
      });
      return;
    }

    try {
      final requestUri = payload['request_uri'] as String?;
      final credentialType = payload['credential_type'] as String?;

      Logger.info(
        'TestMessageHandler: Processing OID4VP request for type=$credentialType',
      );

      // Get stored credentials
      final stored = html.window.localStorage['marty_credentials'];
      final List<dynamic> allCredentials = stored != null
          ? jsonDecode(stored)
          : [];

      // Find matching credentials by type
      final List<dynamic> matchingCredentials = allCredentials.where((cred) {
        if (credentialType == null) return true;
        final credType = cred['type'] ?? cred['credential_type'];
        if (credType is List) {
          return credType.contains(credentialType);
        }
        return credType == credentialType;
      }).toList();

      _sendToParent('OID4VP_PROCESSED', {
        'success': true,
        'request_uri': requestUri,
        'credential_type': credentialType,
        'matching_credentials': matchingCredentials,
        'matching_count': matchingCredentials.length,
      });
    } catch (e) {
      Logger.error('Failed to process OID4VP request', error: e);
      _sendToParent('OID4VP_PROCESSED', {
        'success': false,
        'error': e.toString(),
      });
    }
  }

  /// Approve a presentation request and create a VP
  /// Uses WASM if available for real crypto, otherwise returns mock VP
  static Future<void> _handleApprovePresentation(
    Map<String, dynamic>? payload,
  ) async {
    if (payload == null) {
      _sendToParent('PRESENTATION_APPROVED', {
        'success': false,
        'error': 'No payload',
      });
      return;
    }

    try {
      final credentialIndex = payload['credential_index'] as int? ?? 0;
      final audience = payload['audience'] as String? ?? 'demo_verifier';
      final nonce = payload['nonce'] as String?;
      final callbackUrl = payload['callback_url'] as String?;

      // Get selected credential from localStorage
      final stored = html.window.localStorage['marty_credentials'];
      final List<dynamic> credentials = stored != null
          ? jsonDecode(stored)
          : [];

      if (credentials.isEmpty || credentialIndex >= credentials.length) {
        _sendToParent('PRESENTATION_APPROVED', {
          'success': false,
          'error': 'No credential at index $credentialIndex',
        });
        return;
      }

      final credential = credentials[credentialIndex];
      final credentialJwt = credential['jwt'] as String?;

      String vpJwt;

      // Use WASM if available for real VP creation
      final wasm = MartyWasm.instance;
      if (wasm.isAvailable && credentialJwt != null) {
        // Get or generate holder key
        final holderKeyStored = html.window.localStorage['marty_holder_key'];
        Map<String, dynamic> holderKey;
        String holderDid;

        if (holderKeyStored != null) {
          final keyData = jsonDecode(holderKeyStored);
          holderKey = keyData['jwk'] as Map<String, dynamic>;
          holderDid = keyData['did'] as String;
        } else {
          // Generate new holder key
          final keyResult = await wasm.generateP256Key();
          holderKey = keyResult.jwk;
          holderDid = keyResult.did;
          html.window.localStorage['marty_holder_key'] = jsonEncode({
            'did': holderDid,
            'jwk': holderKey,
          });
        }

        vpJwt = await wasm.createPresentation(
          holderDid: holderDid,
          holderJwkJson: jsonEncode(holderKey),
          credentialJwts: [credentialJwt],
          audience: audience,
          nonce: nonce,
        );

        Logger.info('TestMessageHandler: Created VP with WASM');
      } else {
        // Create mock VP for testing without WASM
        vpJwt = 'mock-vp-jwt-${DateTime.now().millisecondsSinceEpoch}';
        Logger.info('TestMessageHandler: Created mock VP (WASM not available)');
      }

      // If callback URL provided, submit the presentation
      if (callbackUrl != null) {
        // Note: In a real implementation, this would make an HTTP POST
        // For testing, we just notify the parent
        Logger.info('TestMessageHandler: Would submit VP to $callbackUrl');
      }

      _sendToParent('PRESENTATION_APPROVED', {
        'success': true,
        'vp_jwt': vpJwt,
        'credential_index': credentialIndex,
        'audience': audience,
        'nonce': nonce,
      });
    } catch (e) {
      Logger.error('Failed to approve presentation', error: e);
      _sendToParent('PRESENTATION_APPROVED', {
        'success': false,
        'error': e.toString(),
      });
    }
  }

  static Future<void> _handleClearData() async {
    html.window.localStorage.remove('marty_device_id');
    html.window.localStorage.remove('marty_org_id');
    html.window.localStorage.remove('marty_credentials');
    html.window.localStorage.remove('marty_push_token');
    TestConfig.deviceId = null;
    TestConfig.organizationId = null;

    try {
      final ref = globalRef;
      if (ref != null) {
        final walletManager = ref.read(spruceIdWalletManagerProvider);
        final credentials = await walletManager.getAllCredentials();
        for (final credential in credentials) {
          final credentialId = credential['id']?.toString();
          if (credentialId != null) {
            await walletManager.deleteCredential(credentialId);
          }
        }
        await ref.read(credentialsProvider.notifier).refreshCredentials();
      }
    } catch (e) {
      Logger.warning(
        'TestMessageHandler: Failed to clear wallet credentials: $e',
      );
    }

    Logger.info('TestMessageHandler: All data cleared');
    _sendToParent('DATA_CLEARED', {});
  }

  static void _handleInjectChallenge(Map<String, dynamic>? payload) {
    if (payload == null) return;

    // Create challenge from payload
    final challenge = MartyChallenge(
      format: martyChallengeFormat,
      challengeId:
          payload['challenge_id'] as String? ??
          'test-${DateTime.now().millisecondsSinceEpoch}',
      deviceId: TestConfig.deviceId ?? 'test-device',
      title: payload['title'] as String? ?? 'Test Challenge',
      question: payload['question'] as String? ?? 'Do you approve this action?',
      nonce: payload['nonce'] as String? ?? 'test-nonce',
      ttlSeconds: payload['ttl_seconds'] as int? ?? 120,
      createdAt: DateTime.now(),
      requireSignature: false,
      options: const [
        ChallengeOption(id: 'accept', label: 'Approve'),
        ChallengeOption(id: 'reject', label: 'Deny'),
      ],
      signature: '',
      credentialId: payload['credential_id'] as String?,
      data: payload['data'] as Map<String, dynamic>? ?? {},
    );

    // Inject into push service
    final pushService = MartyPushService.instance;
    if (pushService is TestMartyPushService) {
      pushService.injectChallenge(challenge);
    }

    _sendToParent('CHALLENGE_INJECTED', {
      'challenge_id': challenge.challengeId,
    });
  }

  static void _sendToParent(String type, Map<String, dynamic> payload) {
    html.window.parent?.postMessage({
      'type': type,
      'payload': payload,
      'source': 'marty-wallet',
    }, '*');
  }

  // =========================================================================
  // WASM Message Handlers - Enable Playwright to use real crypto
  // =========================================================================

  static void _handleWasmHealthCheck() {
    final wasm = MartyWasm.instance;
    if (!wasm.isAvailable) {
      _sendToParent('WASM_STATUS', {
        'available': false,
        'error': 'WASM module not loaded',
      });
      return;
    }

    try {
      final health = wasm.healthCheck();
      final version = wasm.getVersion();
      _sendToParent('WASM_STATUS', {
        'available': true,
        'health': health,
        'version': version,
      });
    } catch (e) {
      _sendToParent('WASM_STATUS', {'available': false, 'error': e.toString()});
    }
  }

  static Future<void> _handleWasmGenerateKey(
    Map<String, dynamic>? payload,
  ) async {
    final wasm = MartyWasm.instance;
    if (!wasm.isAvailable) {
      _sendToParent('WASM_KEY', {
        'success': false,
        'error': 'WASM not available',
      });
      return;
    }

    try {
      final algorithm = payload?['algorithm'] as String? ?? 'P-256';
      final WasmKeyResult key;

      if (algorithm == 'Ed25519') {
        key = await wasm.generateEd25519Key();
      } else {
        key = await wasm.generateP256Key();
      }

      _sendToParent('WASM_KEY', {
        'success': true,
        'did': key.did,
        'keyId': key.keyId,
        'jwk': key.jwk,
      });
    } catch (e) {
      _sendToParent('WASM_KEY', {'success': false, 'error': e.toString()});
    }
  }

  static Future<void> _handleWasmCreateCredential(
    Map<String, dynamic>? payload,
  ) async {
    final wasm = MartyWasm.instance;
    if (!wasm.isAvailable || payload == null) {
      _sendToParent('WASM_CREDENTIAL', {
        'success': false,
        'error': 'WASM not available or no payload',
      });
      return;
    }

    try {
      final result = await wasm.createVerifiableCredential(
        issuerDid: payload['issuer_did'] as String,
        issuerJwkJson: jsonEncode(payload['issuer_jwk']),
        subjectId: payload['subject_id'] as String?,
        credentialType: payload['credential_type'] as String,
        claims: payload['claims'] as Map<String, dynamic>,
        expirationSeconds: payload['expiration_seconds'] as int?,
      );

      _sendToParent('WASM_CREDENTIAL', {
        'success': true,
        'jwt': result.jwt,
        'credentialId': result.credentialId,
      });
    } catch (e) {
      _sendToParent('WASM_CREDENTIAL', {
        'success': false,
        'error': e.toString(),
      });
    }
  }

  static Future<void> _handleWasmCreatePresentation(
    Map<String, dynamic>? payload,
  ) async {
    final wasm = MartyWasm.instance;
    if (!wasm.isAvailable || payload == null) {
      _sendToParent('WASM_PRESENTATION', {
        'success': false,
        'error': 'WASM not available or no payload',
      });
      return;
    }

    try {
      final vpJwt = await wasm.createPresentation(
        holderDid: payload['holder_did'] as String,
        holderJwkJson: jsonEncode(payload['holder_jwk']),
        credentialJwts: (payload['credential_jwts'] as List).cast<String>(),
        audience: payload['audience'] as String,
        nonce: payload['nonce'] as String?,
      );

      _sendToParent('WASM_PRESENTATION', {'success': true, 'vp_jwt': vpJwt});
    } catch (e) {
      _sendToParent('WASM_PRESENTATION', {
        'success': false,
        'error': e.toString(),
      });
    }
  }

  // =========================================================================
  // Push Notification Registration via QR Code
  // =========================================================================

  static Future<void> _handleRegisterPushViaQR(
    Map<String, dynamic>? payload,
  ) async {
    html.window.console.log(
      '_handleRegisterPushViaQR called with payload: $payload',
    );

    if (payload == null) {
      html.window.console.log('_handleRegisterPushViaQR: No payload');
      _sendToParent('PUSH_REGISTERED', {
        'success': false,
        'error': 'No payload provided',
      });
      return;
    }

    try {
      // Handle JavaScript object conversion properly
      final qrDataRaw = payload['qr_data'];
      html.window.console.log('_handleRegisterPushViaQR: qrDataRaw=$qrDataRaw');
      if (qrDataRaw == null) {
        html.window.console.log('_handleRegisterPushViaQR: No QR data');
        _sendToParent('PUSH_REGISTERED', {
          'success': false,
          'error': 'No QR data provided',
        });
        return;
      }

      // Convert from JS object to Dart Map
      Map<String, dynamic> qrData;
      if (qrDataRaw is Map<String, dynamic>) {
        qrData = qrDataRaw;
      } else if (qrDataRaw is Map) {
        qrData = Map<String, dynamic>.from(qrDataRaw);
      } else {
        // Try JSON decode if it's a string
        qrData = jsonDecode(qrDataRaw.toString()) as Map<String, dynamic>;
      }

      html.window.console.log(
        '_handleRegisterPushViaQR: Converted qrData=$qrData',
      );

      Logger.info('TestMessageHandler: Registering push via QR code');
      Logger.info('  Organization: ${qrData['organization_id']}');
      Logger.info('  API URL: ${qrData['api_url']}');

      // Use MartyPushService to register from QR data
      final pushService = MartyPushService.instance;
      html.window.console.log(
        '_handleRegisterPushViaQR: pushService type=${pushService.runtimeType}, apiUrl=${pushService.config.apiBaseUrl}',
      );
      html.window.console.log(
        '_handleRegisterPushViaQR: Calling pushService.registerFromQRCode...',
      );
      final result = await pushService.registerFromQRCode(qrData);
      html.window.console.log('_handleRegisterPushViaQR: Got result=$result');

      if (result['success'] == true) {
        Logger.info(
          'TestMessageHandler: Push registration successful - device_id: ${result['device_id']}',
        );
        _sendToParent('PUSH_REGISTERED', {
          'success': true,
          'device_id': result['device_id'],
          'registration_id': result['registration_id'],
          'organization_id': result['organization_id'],
        });
      } else {
        Logger.error(
          'TestMessageHandler: Push registration failed - ${result['error']}',
        );
        _sendToParent('PUSH_REGISTERED', {
          'success': false,
          'error': result['error'] ?? 'Registration failed',
        });
      }
    } catch (e, stackTrace) {
      html.window.console.log('_handleRegisterPushViaQR: Exception caught: $e');
      html.window.console.log(
        '_handleRegisterPushViaQR: Stack trace: $stackTrace',
      );
      Logger.error('TestMessageHandler: Push registration error', error: e);
      _sendToParent('PUSH_REGISTERED', {
        'success': false,
        'error': e.toString(),
      });
    }
  }
}

void main() async {
  Logger.init(
    navigatorKey: globalNavigatorKey,
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      WidgetsBinding.instance.ensureSemantics();

      // Parse test configuration from URL
      TestConfig.parseFromUrl();

      // Initialize test message handler for postMessage coordination
      TestMessageHandler.init();

      Logger.warning('🧪 RUNNING IN WEB TEST MODE 🧪');
      Logger.warning('API URL: ${TestConfig.apiUrl}');

      // Initialize WASM module for real crypto operations
      try {
        await MartyWasm.instance.initialize();
        if (MartyWasm.instance.isAvailable) {
          Logger.info('✅ Marty WASM module initialized');
          Logger.info('   Version: ${MartyWasm.instance.getVersion()}');
        } else {
          Logger.warning('⚠️ WASM not available - using mock crypto');
        }
      } catch (e) {
        Logger.warning('⚠️ WASM initialization failed: $e - using mock crypto');
      }

      // Create mock SpruceID services
      final mockServices = MockSpruceIdServices.createDefault(
        config: MockSpruceIdConfig.realistic(),
      );
      mockServices.platformService.preloadFixtures();
      Logger.info('✅ Mock SpruceID services initialized');

      // Setup mock QR scanner
      final mockQrConfig = MockQrScannerConfig.withAllFixtures();
      setMockQrScannerConfig(mockQrConfig);
      Logger.info('✅ Mock QR scanner configured');

      // Initialize Marty push service with test configuration
      final pushConfig = MartyPushConfig(
        apiBaseUrl: TestConfig.apiUrl,
        pollInterval: const Duration(seconds: 2),
      );

      // Create test push service and set as singleton
      // This must be done before any code accesses MartyPushService.instance
      final testPushService = TestMartyPushService(config: pushConfig);
      MartyPushService.setInstance(testPushService);
      html.window.console.log(
        'TestMartyPushService: setInstance called with config apiBaseUrl=${pushConfig.apiBaseUrl}',
      );

      // Setup mock MethodChannel handler for OID4VC calls (WASM shim)
      // Since we are in a web test build without native plugins, we must intercept calls manually.
      // We cannot use setMockMethodCallHandler because it requires flutter_test.
      ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(
        'com.netknights.authenticator/spruce_w3c',
        (ByteData? message) async {
          if (message == null) return null;
          try {
            final MethodCall call = const StandardMethodCodec()
                .decodeMethodCall(message);

            if (call.method == 'handleOID4VCOfferRefactored') {
              Logger.info(
                '✅ MockChannel: Intercepted handleOID4VCOfferRefactored',
              );
              html.window.console.log(
                'MockChannel: Intercepted handleOID4VCOfferRefactored - returning success',
              );

              final result = <String, dynamic>{
                'status': 'success',
                'credential_id':
                    'mock-credential-${DateTime.now().millisecondsSinceEpoch}',
              };
              return const StandardMethodCodec().encodeSuccessEnvelope(result);
            }
          } catch (e) {
            html.window.console.log('MockChannel: Error decoding message: $e');
          }
          return null;
        },
      );

      if (TestConfig.deviceId != null) {
        testPushService.setTestDeviceId(TestConfig.deviceId!);
        Logger.info(
          '✅ Test push service initialized with device: ${TestConfig.deviceId}',
        );
      } else {
        Logger.info('✅ Test push service initialized (no device ID yet)');
      }

      runApp(
        EasyDynamicThemeWidget(
          initialThemeMode: ThemeMode.system,
          child: AppWrapper(overrides: [], child: const MartyWebTestApp()),
        ),
      );
    },
  );
}

class MartyWebTestApp extends ConsumerWidget {
  const MartyWebTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    globalRef = ref;

    // Create mock QR scanner navigator observer
    final mockQrObserver = MockQrScannerNavigatorObserver();

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final localizations = AppLocalizations.of(context);
          if (localizations != null) {
            ref
                .read(localizationNotifierProvider.notifier)
                .update(localizations);
          }
          ref.read(appConstraintsNotifierProvider.notifier).update(constraints);
        });

        return MaterialApp(
          title: 'Marty Wallet (Test)',
          navigatorKey: globalNavigatorKey,
          navigatorObservers: [mockQrObserver],
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          // In test mode, skip splash and go directly to MainView
          home: TestConfig.testMode
              ? _TestReadyWrapper(child: const DocumentView())
              : SplashScreen(
                  customization: ApplicationCustomization.defaultCustomization,
                ),
          routes: {'/main': (context) => const DocumentView()},
        );
      },
    );
  }
}

/// Wrapper widget that notifies Playwright tests when the wallet UI is ready.
/// This ensures WALLET_READY is sent after the MainView has actually rendered,
/// not just when the message handler is initialized.
class _TestReadyWrapper extends StatefulWidget {
  final Widget child;

  const _TestReadyWrapper({required this.child});

  @override
  State<_TestReadyWrapper> createState() => _TestReadyWrapperState();
}

class _TestReadyWrapperState extends State<_TestReadyWrapper> {
  @override
  void initState() {
    super.initState();
    // Schedule WALLET_READY notification for after this frame completes,
    // ensuring the MainView widget tree has been built and is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TestMessageHandler.notifyWalletReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
