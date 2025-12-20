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
import '../views/splash_screen/splash_screen.dart';
import '../widgets/app_wrapper.dart';

// Import mock services
import '../mocks/mock_spruce_services.dart';
import '../mocks/mock_qr_scanner_service.dart';
import '../utils/riverpod/providers/spruce_providers.dart';

// Import Marty push service
import '../services/marty_push_service.dart';

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
  static void init() {
    html.window.addEventListener('message', _handleMessage);
    Logger.info('TestMessageHandler: Listening for postMessage events');

    // Notify parent that wallet is ready
    _sendToParent('WALLET_READY', {});
  }

  static void _handleMessage(html.Event event) {
    if (event is! html.MessageEvent) return;

    final messageEvent = event;

    try {
      final data = messageEvent.data;
      if (data is! Map) return;

      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

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
          _handleGetCredentials();
          break;
        case 'CLEAR_DATA':
          _handleClearData();
          break;
        case 'INJECT_CHALLENGE':
          _handleInjectChallenge(payload);
          break;
      }
    } catch (e) {
      Logger.error('TestMessageHandler: Error handling message', error: e);
    }
  }

  static void _handleQrCodeInjection(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final qrData = payload['data'] as String?;
    if (qrData == null) return;

    Logger.info('TestMessageHandler: Injecting QR code data');

    // Inject into mock QR scanner
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

  static void _handleGetCredentials() {
    final stored = html.window.localStorage['marty_credentials'];
    final credentials = stored != null ? jsonDecode(stored) : [];
    _sendToParent('CREDENTIALS', {'credentials': credentials});
  }

  static void _handleClearData() {
    html.window.localStorage.remove('marty_device_id');
    html.window.localStorage.remove('marty_org_id');
    html.window.localStorage.remove('marty_credentials');
    html.window.localStorage.remove('marty_push_token');
    TestConfig.deviceId = null;
    TestConfig.organizationId = null;

    Logger.info('TestMessageHandler: All data cleared');
    _sendToParent('DATA_CLEARED', {});
  }

  static void _handleInjectChallenge(Map<String, dynamic>? payload) {
    if (payload == null) return;

    // Create challenge from payload
    final challenge = MartyPushChallenge(
      challengeId:
          payload['challenge_id'] as String? ??
          'test-${DateTime.now().millisecondsSinceEpoch}',
      title: payload['title'] as String? ?? 'Test Challenge',
      question: payload['question'] as String? ?? 'Do you approve this action?',
      nonce: payload['nonce'] as String? ?? 'test-nonce',
      credentialId: payload['credential_id'] as String?,
      data: payload['data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.now(),
      ttlSeconds: payload['ttl_seconds'] as int? ?? 120,
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
}

void main() async {
  Logger.init(
    navigatorKey: globalNavigatorKey,
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Parse test configuration from URL
      TestConfig.parseFromUrl();

      // Initialize test message handler for postMessage coordination
      TestMessageHandler.init();

      Logger.warning('🧪 RUNNING IN WEB TEST MODE 🧪');
      Logger.warning('API URL: ${TestConfig.apiUrl}');

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

      // Create test push service if device ID is provided
      if (TestConfig.deviceId != null) {
        final testPushService = TestMartyPushService(config: pushConfig);
        testPushService.setTestDeviceId(TestConfig.deviceId!);
        Logger.info(
          '✅ Test push service initialized with device: ${TestConfig.deviceId}',
        );
      }

      runApp(
        EasyDynamicThemeWidget(
          initialThemeMode: ThemeMode.system,
          child: AppWrapper(
            overrides: [
              spruceIdPlatformServiceProvider.overrideWithValue(
                mockServices.platformService,
              ),
              spruceIdClientProvider.overrideWithValue(mockServices.client),
              spruceIdWalletManagerProvider.overrideWithValue(
                mockServices.walletManager,
              ),
              spruceIdMdocManagerProvider.overrideWithValue(
                mockServices.mdocManager,
              ),
              spruceIdSdJwtManagerProvider.overrideWithValue(
                mockServices.sdJwtManager,
              ),
            ],
            child: const MartyWebTestApp(),
          ),
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
          home: SplashScreen(
            customization: ApplicationCustomization.defaultCustomization,
          ),
          routes: {
            '/main': (context) => MainView(
              backgroundImage: ApplicationCustomization
                  .defaultCustomization
                  .backgroundImage
                  ?.getWidget,
              appbarIcon: ApplicationCustomization
                  .defaultCustomization
                  .appbarIcon
                  .getWidget,
              appName: ApplicationCustomization.defaultCustomization.appName,
              disablePatchNotes: true,
            ),
          },
        );
      },
    );
  }
}
