import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';

import 'package:privacyidea_authenticator/mains/main_netknights.dart'
    show PrivacyIDEAAuthenticator;
import 'package:privacyidea_authenticator/widgets/app_wrapper.dart';
import 'package:privacyidea_authenticator/utils/customization/application_customization.dart';
import 'package:privacyidea_authenticator/utils/logger.dart';
import 'package:privacyidea_authenticator/utils/globals.dart';
import 'package:privacyidea_authenticator/widgets/qr_scanner_enhanced.dart';
import 'package:privacyidea_authenticator/widgets/presentation_request_view.dart';
import 'package:privacyidea_authenticator/views/main_view/document_view.dart';
import 'package:privacyidea_authenticator/services/spruce_platform_service_extended.dart';
import 'package:privacyidea_authenticator/interfaces/spruce_interfaces_extended.dart';
import 'package:privacyidea_authenticator/services/spruce_managers_extended.dart';

// Mock Service
class MockSpruceIdPlatformServiceExtended extends Fake
    implements ISpruceIdPlatformServiceExtended {
  @override
  Future<Map<String, dynamic>> handleOID4VPRequestSDK({
    required String presentationRequest,
    required List<Map<String, dynamic>> selectedCredentials,
    required List<String> disclosureOptions,
    String? keyId,
  }) async {
    print('MockSpruceIdPlatformServiceExtended: handleOID4VPRequestSDK called');
    return {
      'type': 'presentation_request',
      'client_id': 'Woodgrove Demo',
      'nonce': '123456',
      'presentation_definition': {},
    };
  }

  @override
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  }) async {
    print(
      'MockSpruceIdPlatformServiceExtended: initiateOID4VPRequestSDK called',
    );
    // Simulate user selection required
    throw UserSelectionRequiredException(
      sessionId: 'mock_session_123',
      matches: [
        {
          'id': 'mock_cred_1',
          'type': 'VerifiableCredential',
          'issuer': 'did:example:issuer',
          'requestedFields': {
            'all': ['credentialSubject'],
          },
        },
      ],
      requestDetails: {'verifier': 'Mock Verifier', 'purpose': 'Testing'},
    );
  }

  @override
  Future<Map<String, dynamic>> completeOID4VPRequestSDK({
    required String sessionId,
    required String selectedCredentialId,
    List<String>? selectedFields,
  }) async {
    print(
      'MockSpruceIdPlatformServiceExtended: completeOID4VPRequestSDK called',
    );
    return {'status': 'success'};
  }

  @override
  Future<List<Map<String, dynamic>>> getStoredCredentials() async {
    return [
      {
        'id': 'mock_cred_1',
        'type': 'VerifiableCredential',
        'issuer': 'did:example:issuer',
        'credentialSubject': {'given_name': 'John'},
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> initializeHolderSDK({
    String? keyId,
    Map<String, dynamic>? holderConfig,
  }) async {
    return {};
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Real OID4VP Presentation Flow', (WidgetTester tester) async {
    // 1. Get the QR code from environment
    const qrCode = String.fromEnvironment('QR_CODE');
    if (qrCode.isEmpty) {
      fail(
        'QR_CODE environment variable is missing. Run with --dart-define=QR_CODE="..."',
      );
    }

    print('Starting presentation test with QR Code: $qrCode');

    // 2. Start the app with MOCKED service
    Logger.init(
      navigatorKey: globalNavigatorKey,
      appRunner: () async {
        runApp(
          EasyDynamicThemeWidget(
            initialThemeMode: ThemeMode.system,
            child: AppWrapper(
              overrides: [
                spruceIdPlatformServiceExtendedProvider.overrideWithValue(
                  MockSpruceIdPlatformServiceExtended(),
                ),
                spruceIdWalletManagerExtendedProvider.overrideWithValue(
                  SpruceIdWalletManagerExtended(
                    MockSpruceIdPlatformServiceExtended(),
                  ),
                ),
              ],
              child: PrivacyIDEAAuthenticator(
                ApplicationCustomization.defaultCustomization,
              ),
            ),
          ),
        );
      },
    );

    await tester.pumpAndSettle();

    // Wait for DocumentView
    int retries = 0;
    while (find.byType(DocumentView).evaluate().isEmpty && retries < 10) {
      await tester.pump(const Duration(seconds: 1));
      retries++;
    }

    if (find.byType(DocumentView).evaluate().isEmpty) {
      print('DocumentView not found');
      // Try to dump app to see where we are
      // debugDumpApp();
      return;
    } else {
      print('DocumentView found');
    }

    // 3. Navigate to QR Scanner
    final qrIconFinder = find.byIcon(Icons.qr_code_scanner);
    if (qrIconFinder.evaluate().isNotEmpty) {
      print('Found QR icon, tapping...');
      await tester.tap(qrIconFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    } else {
      final qrIconOutlinedFinder = find.byIcon(Icons.qr_code_scanner_outlined);
      if (qrIconOutlinedFinder.evaluate().isNotEmpty) {
        await tester.tap(qrIconOutlinedFinder);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      } else {
        print('Warning: Could not find QR icon to open scanner.');
      }
    }

    // 4. Verify Scanner is visible
    await tester.pump(const Duration(seconds: 2));
    final scannerFinder = find.byType(QRScannerEnhanced);
    expect(
      scannerFinder,
      findsOneWidget,
      reason: 'QRScannerEnhanced widget should be visible',
    );

    // 5. Inject the QR code
    final QRScannerEnhancedState scannerState =
        tester.state(scannerFinder) as QRScannerEnhancedState;
    print('Injecting QR code into scanner...');
    scannerState.handleScanResult(qrCode);
    await tester.pump();

    // 6. Wait for PresentationRequestView
    await tester.pumpAndSettle();
    final presentationViewFinder = find.byType(PresentationRequestView);
    expect(
      presentationViewFinder,
      findsOneWidget,
      reason: 'PresentationRequestView should be visible',
    );

    // 7. Tap Share
    print('Tapping Share button...');
    await tester.tap(find.text('Share'));

    // 8. Verify success snackbar
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Wait for animation
    expect(find.text('Presentation submitted successfully'), findsOneWidget);

    // Allow some time for async operations
    await tester.pump(const Duration(seconds: 2));
  });
}
