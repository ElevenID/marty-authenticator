import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/services/qr_scanner_service_enhanced.dart';
import 'package:marty_authenticator/widgets/qr_scanner_enhanced.dart';

void main() {
  testWidgets('parsed offer waits for explicit review and shows Rust details', (
    tester,
  ) async {
    const offerUri = 'openid-credential-offer://approved';
    final container = ProviderContainer(
      overrides: [
        qrScannerServiceEnhancedProvider.overrideWithValue(
          QRScannerServiceEnhanced(
            parseNativeQr: ({required rawData}) async => const FrbWalletQrInput(
              kind: 'credential_offer',
              normalized: offerUri,
              parsedContentJson:
                  '{"offer_uri":"openid-credential-offer://approved","credential_issuer":"https://issuer.example","credential_configuration_ids":["ExampleIdentity"]}',
              requiresExternalProvider: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: QRScannerEnhanced(enableHapticFeedback: false)),
        ),
      ),
    );
    final state = tester.state<QRScannerEnhancedState>(
      find.byType(QRScannerEnhanced),
    );
    // ignore: invalid_use_of_visible_for_testing_member
    final processing = state.handleScanResult(offerUri);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await processing;

    expect(find.text('QR PARSED'), findsOneWidget);
    expect(find.text('Review Offer'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Review Offer'), findsOneWidget);

    await tester.tap(find.text('Review Offer'));
    await tester.pump();
    expect(find.text('https://issuer.example is offering:'), findsOneWidget);
    expect(find.text('ExampleIdentity'), findsOneWidget);
    await tester.tap(find.text('Decline'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
