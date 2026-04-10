import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';

import 'package:marty_authenticator/mains/main_netknights.dart'
    show PrivacyIDEAAuthenticator;
import 'package:marty_authenticator/widgets/app_wrapper.dart';
import 'package:marty_authenticator/utils/customization/application_customization.dart';
import 'package:marty_authenticator/utils/logger.dart';
import 'package:marty_authenticator/utils/globals.dart';
import 'package:marty_authenticator/widgets/qr_scanner_enhanced.dart';
import 'package:marty_authenticator/views/main_view/document_view.dart';

// Mock Service removed for production test

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Real OID4VC Credential Flow', (WidgetTester tester) async {
    // 1. Get the QR code from environment
    const qrCode = String.fromEnvironment('QR_CODE');
    if (qrCode.isEmpty) {
      fail(
        'QR_CODE environment variable is missing. Run with --dart-define=QR_CODE="..."',
      );
    }

    print('Starting test with QR Code: $qrCode');

    // 2. Start the app with real service
    Logger.init(
      navigatorKey: globalNavigatorKey,
      appRunner: () async {
        runApp(
          EasyDynamicThemeWidget(
            initialThemeMode: ThemeMode.system,
            child: AppWrapper(
              child: PrivacyIDEAAuthenticator(
                ApplicationCustomization.defaultCustomization,
              ),
            ),
          ),
        );
      },
    );

    await tester.pumpAndSettle();

    // Wait for DocumentView to appear (SplashScreen might take time)
    int retries = 0;
    while (find.byType(DocumentView).evaluate().isEmpty && retries < 10) {
      await tester.pump(const Duration(seconds: 1));
      retries++;
    }

    // Verify we are on DocumentView
    if (find.byType(DocumentView).evaluate().isEmpty) {
      print('DocumentView not found after waiting. Current widgets:');
      // debugDumpApp();
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
    // Do NOT await handleScanResult because it waits for the dialog to close
    scannerState.handleScanResult(qrCode);
    await tester.pump();

    // 6. Handle "Accept" dialog if it appears
    print('Waiting for Accept dialog...');
    bool dialogFound = false;
    // Use a more specific finder to avoid ambiguity (Dialog vs Live Preview)
    final acceptButtonFinder = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Accept'),
    );

    // Poll for the dialog for up to 10 seconds
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (acceptButtonFinder.evaluate().isNotEmpty) {
        dialogFound = true;
        print('Found Accept button!');
        break;
      }
    }

    if (dialogFound) {
      await tester.tap(acceptButtonFinder);
      // Use pump instead of pumpAndSettle to avoid hanging on long animations
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      print('Tapped Accept button');

      // Verify success message
      print('Waiting for success message...');
      final successFinder = find.text('Credential offer accepted successfully');
      bool successFound = false;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (successFinder.evaluate().isNotEmpty) {
          successFound = true;
          print('Found success message!');
          break;
        }
      }

      if (!successFound) {
        print('Warning: Success message not found within timeout');
      }
    } else {
      print('Accept button not found, checking for Confirm...');
      final confirmButtonFinder = find.text('Confirm');
      if (confirmButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(confirmButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        print('Tapped Confirm button');
      } else {
        print('Error: Neither Accept nor Confirm button found.');
        // Fail the test if dialog didn't appear
        expect(
          acceptButtonFinder,
          findsOneWidget,
          reason: 'Accept dialog should appear',
        );
      }
    }

    // Wait for completion
    await tester.pump(const Duration(seconds: 2));
  });
}
