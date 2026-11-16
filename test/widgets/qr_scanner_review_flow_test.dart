// Widget orchestration with controlled parser/client adapters. Native protocol,
// custody and issuer acceptance are qualified separately by the Rust fixtures.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces_extended.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/services/qr_scanner_service_enhanced.dart';
import 'package:marty_authenticator/services/spruce_client_extended.dart';
import 'package:marty_authenticator/widgets/qr_scanner_enhanced.dart';

class _Client implements ISpruceIdClientExtended {
  final accepted = <String>[];
  bool rejectOffer = false;

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
  }) async {
    accepted.add(credentialOffer);
    if (rejectOffer) throw StateError('Native receipt admission rejected');
    return {'id': 'verified-receipt'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected wallet operation: ${invocation.memberName}');
}

FrbWalletQrInput _parsed(
  String kind, {
  Map<String, dynamic> content = const {},
  bool external = false,
}) => FrbWalletQrInput(
  kind: kind,
  normalized: 'native-normalized-input',
  parsedContentJson: jsonEncode(content),
  requiresExternalProvider: external,
);

FrbWalletQrInput _offer({bool external = false, bool malformed = false}) =>
    _parsed(
      'credential_offer',
      external: external,
      content: {
        'offer_uri': 'frozen-reviewed-offer',
        'credential_issuer': 'https://issuer.example/tenant',
        if (!malformed)
          'credential_configuration_ids': [
            'identity',
            'employee',
            'badge',
            'age',
          ],
      },
    );

Future<GlobalKey<QRScannerEnhancedState>> _mount(
  WidgetTester tester, {
  required NativeQrParser parser,
  required _Client client,
  void Function(ProcessedQRResult)? onResult,
}) async {
  final key = GlobalKey<QRScannerEnhancedState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qrScannerServiceEnhancedProvider.overrideWithValue(
          QRScannerServiceEnhanced(parseNativeQr: parser),
        ),
        spruceIdClientExtendedProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: QRScannerEnhanced(
            key: key,
            scannerOverride: const SizedBox.expand(),
            onScanResult: onResult,
          ),
        ),
      ),
    ),
  );
  return key;
}

Future<void> _scan(
  WidgetTester tester,
  GlobalKey<QRScannerEnhancedState> key, [
  String input = 'untrusted-qr-input',
]) async {
  final processing = key.currentState!.handleScanResult(input);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await processing;
  await tester.pump();
}

void main() {
  testWidgets(
    'parsing and duplicate suppression never imply trust or acceptance',
    (tester) async {
      final parsed = Completer<FrbWalletQrInput?>();
      final client = _Client();
      final results = <ProcessedQRResult>[];
      var parses = 0;
      final key = await _mount(
        tester,
        client: client,
        parser: ({required rawData}) {
          parses++;
          return parsed.future;
        },
        onResult: results.add,
      );
      final processing = key.currentState!.handleScanResult('same-offer');
      await tester.pump();
      expect(find.text('Parsing QR code...'), findsOneWidget);
      await key.currentState!.handleScanResult('same-offer');
      expect(parses, 1);
      parsed.complete(_offer());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await processing;
      expect(find.text('QR PARSED'), findsOneWidget);
      expect(find.text('Review Offer'), findsOneWidget);
      expect(
        find.text('Review this offer; Rust verifies it before wallet storage.'),
        findsOneWidget,
      );
      expect(
        results.single.enrichedResult!.validatedResult.parsedData.rawData,
        'native-normalized-input',
      );
      expect(client.accepted, isEmpty);
      await key.currentState!.handleScanResult('same-offer');
      expect(parses, 1);
      await tester.tap(find.text('Dismiss'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('QR PARSED'), findsNothing);
      await _scan(tester, key, 'same-offer');
      expect(parses, 2);
      expect(client.accepted, isEmpty);
    },
  );

  for (final accept in [false, true]) {
    testWidgets(
      'offer review ${accept ? 'accepts only its frozen offer' : 'declines without issuance'}',
      (tester) async {
        final client = _Client();
        final key = await _mount(
          tester,
          client: client,
          parser: ({required rawData}) async => _offer(),
        );
        await _scan(tester, key);
        expect(client.accepted, isEmpty);
        await tester.tap(find.text('Review Offer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('https://issuer.example/tenant is offering:'),
          findsOneWidget,
        );
        expect(find.text('identity'), findsOneWidget);
        expect(find.text('employee'), findsOneWidget);
        expect(find.text('badge'), findsOneWidget);
        expect(find.text('... and 1 more'), findsOneWidget);
        expect(client.accepted, isEmpty);
        await tester.tap(find.text(accept ? 'Accept' : 'Decline'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(client.accepted, accept ? ['frozen-reviewed-offer'] : isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        if (accept)
          expect(
            find.text('Credential offer accepted successfully'),
            findsOneWidget,
          );
      },
    );
  }

  testWidgets(
    'failed native receipt admission shows failure without a success',
    (tester) async {
      final client = _Client()..rejectOffer = true;
      final key = await _mount(
        tester,
        client: client,
        parser: ({required rawData}) async => _offer(),
      );
      await _scan(tester, key);
      await tester.tap(find.text('Review Offer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(client.accepted, ['frozen-reviewed-offer']);
      expect(find.text('Failed to accept credential offer'), findsOneWidget);
      expect(find.text('Credential offer accepted successfully'), findsNothing);
    },
  );

  for (final external in [false, true]) {
    testWidgets(
      'unreviewable ${external ? 'external' : 'malformed'} offer cannot reach issuance',
      (tester) async {
        final client = _Client();
        final key = await _mount(
          tester,
          client: client,
          parser: ({required rawData}) async =>
              _offer(external: external, malformed: !external),
        );
        await _scan(tester, key);
        await tester.tap(find.text('Review Offer'));
        await tester.pump();
        expect(
          find.textContaining('This offer cannot be reviewed:'),
          findsOneWidget,
        );
        expect(find.text('Accept'), findsNothing);
        expect(client.accepted, isEmpty);
      },
    );
  }

  for (final kind in ['mdoc_device_engagement', 'push_registration']) {
    testWidgets(
      '$kind remains unavailable rather than inventing a wallet result',
      (tester) async {
        final client = _Client();
        final key = await _mount(
          tester,
          client: client,
          parser: ({required rawData}) async => _parsed(kind),
        );
        await _scan(tester, key);
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Unavailable'),
        );
        expect(button.onPressed, isNull);
        expect(find.text('QR PARSED'), findsOneWidget);
        expect(client.accepted, isEmpty);
      },
    );
  }

  testWidgets('desktop pairing never falls back to local custody', (
    tester,
  ) async {
    final client = _Client();
    final key = await _mount(
      tester,
      client: client,
      parser: ({required rawData}) async => _parsed(
        'remote_pairing',
        content: {
          'api_origin': 'https://wallet.example',
          'pairing_code': 'opaque-fixture-code',
        },
      ),
    );
    await _scan(tester, key);
    expect(find.text('Remote Wallet Pairing'), findsOneWidget);
    await tester.tap(find.text('Pair'));
    await tester.pump();
    expect(
      find.text('Remote wallet pairing requires an Android or iOS app'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(client.accepted, isEmpty);
  });

  testWidgets(
    'parser failures do not expose untrusted input or start a wallet operation',
    (tester) async {
      final client = _Client();
      final key = await _mount(
        tester,
        client: client,
        parser: ({required rawData}) async =>
            throw StateError('private-input-marker'),
      );
      await _scan(tester, key, 'private-input-marker');
      expect(find.text('Unable to parse QR content'), findsOneWidget);
      expect(find.textContaining('private-input-marker'), findsNothing);
      expect(find.text('QR PARSED'), findsNothing);
      expect(client.accepted, isEmpty);
    },
  );
}
