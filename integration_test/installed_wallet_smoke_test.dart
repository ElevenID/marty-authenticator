// Installed Android/iOS smoke coverage with the real application, Rust bridge
// and secure-storage plugin. The synthetic inline offer is never issued.
// Camera capture, permissions, deployed services and successful credential
// exchange remain separate qualification gates.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marty_authenticator/main_document.dart' as app;
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/frb_generated.dart';
import 'package:marty_authenticator/services/qr_scanner_service_enhanced.dart';
import 'package:marty_authenticator/services/spruce_client_extended.dart';
import 'package:marty_authenticator/services/verified_wallet_bridge.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';
import 'package:marty_authenticator/views/main_view/document_view.dart';
import 'package:marty_authenticator/widgets/presentation_request_view.dart';
import 'package:marty_authenticator/widgets/qr_scanner_enhanced.dart';

const _ioTimeout = Duration(seconds: 10);
const _storage = FlutterSecureStorage();
const _probeKey = 'marty:integration-test:installed-smoke-probe';
const _probeValue = 'installed-wallet-storage-probe-v1';
final _offerJson = jsonEncode({
  'credential_issuer': 'https://issuer.invalid',
  'credential_configuration_ids': ['InstalledSmokeIdentity'],
  'grants': {
    'authorization_code': {'issuer_state': 'installed-smoke-fixture'},
  },
});
final _offerUri = Uri(
  scheme: 'openid-credential-offer',
  host: '',
  queryParameters: {'credential_offer': _offerJson},
).toString();

Future<void> _requireIsolatedDevice() async {
  const enabled = bool.fromEnvironment('WALLET_DEVICE_SMOKE');
  const qrCode = String.fromEnvironment('QR_CODE');
  if (!enabled || qrCode != 'WALLET_DEVICE_SMOKE_CAMERA_DISABLED') {
    throw StateError('Run the explicit test-device-smoke target.');
  }
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw StateError('This suite requires an installed Android or iOS app.');
  }
  if ((await _storage.readAll().timeout(_ioTimeout)).isNotEmpty) {
    // Preserve existing enrollment, receipts and layout without logging them.
    throw StateError(
      'Existing secure storage was preserved. Use a fresh isolated test app.',
    );
  }
}

Future<void> _checkStoragePlugin() async {
  try {
    await _storage
        .write(key: _probeKey, value: _probeValue)
        .timeout(_ioTimeout);
    expect(
      await _storage.read(key: _probeKey).timeout(_ioTimeout),
      _probeValue,
    );
  } finally {
    // The initial empty-store check establishes ownership of this one key.
    // Preserve an unexpected replacement instead of deleting it.
    final value = await _storage.read(key: _probeKey).timeout(_ioTimeout);
    if (value == _probeValue) {
      await _storage.delete(key: _probeKey).timeout(_ioTimeout);
    } else if (value != null) {
      throw StateError('The storage probe changed; its value was preserved.');
    }
  }
  expect(await _storage.read(key: _probeKey).timeout(_ioTimeout), isNull);
}

Matcher _nativeRejection(String message) => throwsA(
  isA<AnyhowException>().having(
    (error) => error.toString(),
    'native error',
    contains(message),
  ),
);

Future<void> _checkNativeAdapters() async {
  final parser = QRScannerServiceEnhanced();
  final parsed = await parser.processQRCode(_offerUri).timeout(_ioTimeout);
  expect(parsed.isSuccess, isTrue);
  final input = parsed.enrichedResult!.validatedResult.parsedData;
  final preview = CredentialOfferPreview.fromParsed(input);
  expect(preview.issuer, 'https://issuer.invalid');
  expect(preview.credentialConfigurationIds, ['InstalledSmokeIdentity']);
  expect(input.rawData, preview.offerUri);
  final envelope = Uri.parse(preview.offerUri);
  expect(envelope.queryParameters.keys, ['credential_offer']);
  final frozen = jsonDecode(envelope.queryParameters['credential_offer']!);
  expect(frozen['credential_issuer'], 'https://issuer.invalid');
  expect(frozen['credential_configuration_ids'], ['InstalledSmokeIdentity']);
  expect(
    frozen['grants']['authorization_code']['issuer_state'],
    'installed-smoke-fixture',
  );

  final unsupported = await parser
      .processQRCode('not-a-wallet-qr')
      .timeout(_ioTimeout);
  expect(unsupported.isSuccess, isFalse);
  expect(unsupported.enrichedResult, isNull);
  await expectLater(
    credentialFromJson(json: '{}').timeout(_ioTimeout),
    throwsA(isA<AnyhowException>()),
  );

  const bridge = RustVerifiedWalletBridge();
  await expectLater(
    bridge.routePresentation(input: _offerUri).timeout(_ioTimeout),
    _nativeRejection(
      'Credential offers cannot be routed as presentation requests',
    ),
  );
  await expectLater(
    bridge
        .prepareReceipt(
          offerUri: _offerUri,
          holderPublicJwkJson: '{}',
          issuerSnapshotJson: '{"private_key":null}',
        )
        .timeout(_ioTimeout),
    _nativeRejection('issuer trust snapshot contains private key material'),
  );
}

Future<void> _checkApplicationRejections(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DocumentView)),
  );
  final client = container.read(spruceIdClientExtendedProvider);
  await expectLater(
    client.handleOID4VCOfferSDK(credentialOffer: _offerUri).timeout(_ioTimeout),
    throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'unpaired rejection',
        'Remote wallet is not paired',
      ),
    ),
  );
  await expectLater(
    client
        .initiateOID4VPRequestSDK(
          presentationRequest: 'not-a-presentation-request',
        )
        .timeout(_ioTimeout),
    _nativeRejection('Unsupported presentation request'),
  );
  expect((await _storage.readAll().timeout(_ioTimeout)).isEmpty, isTrue);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int count = 1,
}) async {
  // The scanner owns a repeating animation; pumpAndSettle cannot finish there.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().length == count) return;
  }
  expect(finder, findsNWidgets(count));
}

Future<void> _openScanner(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.qr_code_scanner));
  await _waitFor(tester, find.byType(QRScannerEnhanced));
  expect(find.text('Test Mode: Camera Disabled'), findsOneWidget);
}

Future<void> _reviewOffer(WidgetTester tester) async {
  final state = tester.state<QRScannerEnhancedState>(
    find.byType(QRScannerEnhanced),
  );
  // Only camera delivery is replaced. Parsing, providers and clients are real.
  final processing = state.handleScanResult(_offerUri);
  await _waitFor(tester, find.text('Review Offer'));
  await tester.pump(const Duration(milliseconds: 400));
  await processing.timeout(_ioTimeout);
  expect(find.text('QR PARSED'), findsOneWidget);
  expect((await WalletCredentialStore.getAll()).isEmpty, isTrue);
  await tester.tap(find.text('Review Offer'));
  await _waitFor(tester, find.byType(AlertDialog));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('https://issuer.invalid is offering:'), findsOneWidget);
  expect(find.text('InstalledSmokeIdentity'), findsOneWidget);
}

Future<void> _returnToDocuments(WidgetTester tester) async {
  await tester.pageBack();
  await _waitFor(
    tester,
    find.byType(QRScannerEnhanced, skipOffstage: false),
    count: 0,
  );
  await _waitFor(tester, find.byType(DocumentView));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DocumentView)),
  );
  await container
      .read(cardStateProvider.notifier)
      .refreshCards()
      .timeout(_ioTimeout);
  await tester.pump();
  expect(container.read(walletStorageUnavailableProvider), isFalse);
  expect(container.read(cardStateProvider), isEmpty);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'installed wallet loads native adapters and rejects unpaired exchange',
    (tester) async {
      await _requireIsolatedDevice();
      await _checkStoragePlugin();
      await app.main().timeout(const Duration(seconds: 30));
      try {
        await _waitFor(tester, find.byType(DocumentView));
        await _checkNativeAdapters();
        await _checkApplicationRejections(tester);

        await _openScanner(tester);
        await _reviewOffer(tester);
        await tester.tap(find.text('Decline'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AlertDialog), findsNothing);
        expect((await WalletCredentialStore.getAll()).isEmpty, isTrue);
        expect((await _storage.readAll().timeout(_ioTimeout)).isEmpty, isTrue);
        expect(
          find.text('Credential offer accepted successfully'),
          findsNothing,
        );

        // Reopening creates a new scan session after duplicate suppression.
        await _returnToDocuments(tester);
        await _openScanner(tester);
        await _reviewOffer(tester);
        await tester.tap(find.text('Accept'));
        await _waitFor(tester, find.text('Failed to accept credential offer'));
        expect(
          find.text('Credential offer accepted successfully'),
          findsNothing,
        );
        expect((await WalletCredentialStore.getAll()).isEmpty, isTrue);
        expect((await _storage.readAll().timeout(_ioTimeout)).isEmpty, isTrue);

        final scanner = tester.state<QRScannerEnhancedState>(
          find.byType(QRScannerEnhanced),
        );
        await scanner
            .handlePresentationRequest('not-a-presentation-request')
            .timeout(_ioTimeout);
        await _waitFor(
          tester,
          find.text('Failed to process presentation request'),
        );
        expect(find.byType(PresentationRequestView), findsNothing);
        expect(find.text('Presentation submitted successfully'), findsNothing);
        await _returnToDocuments(tester);
        expect((await _storage.readAll().timeout(_ioTimeout)).isEmpty, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        RustLib.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
