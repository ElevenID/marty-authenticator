import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces_extended.dart';
import 'package:marty_authenticator/services/spruce_client_extended.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/widgets/presentation_request_view.dart';
import 'package:marty_authenticator/widgets/qr_scanner_enhanced.dart';

class _Client implements ISpruceIdClientExtended {
  final ready = Completer<void>();
  final cancelled = <String>[];
  final selection = UserSelectionRequiredException(
    sessionId: 'owned-consent',
    matches: const [
      {
        'id': 'credential',
        'type': 'Identity',
        'issuer': 'https://issuer.example',
        'requestedFields': {
          'credential': ['email'],
        },
        'alwaysSharedClaims': {'sub': '"identifier"'},
        'alwaysSharedHeader': {'alg': '"ES256"'},
      },
    ],
    requestDetails: const {
      'verifier': 'governed-verifier',
      'recipient': 'https://verifier.example/submit',
    },
  );
  @override
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  }) async {
    await ready.future;
    throw selection;
  }

  @override
  Future<void> cancelOID4VPRequestSDK({required String sessionId}) async {
    cancelled.add(sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected wallet operation');
}

void main() {
  Future<GlobalKey<QRScannerEnhancedState>> mount(
    WidgetTester tester,
    _Client client,
  ) async {
    final key = GlobalKey<QRScannerEnhancedState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [spruceIdClientExtendedProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(
            body: QRScannerEnhanced(
              key: key,
              showLivePreview: false,
              scannerOverride: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    return key;
  }

  testWidgets(
    'a review arriving after scanner disposal is cancelled without opening consent',
    (tester) async {
      final client = _Client();
      final key = await mount(tester, client);
      final processing = key.currentState!.handlePresentationRequest(
        'untrusted-input',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      client.ready.complete();
      await processing;
      expect(client.cancelled, ['owned-consent']);
      expect(find.byType(PresentationRequestView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back from consent retires the owned session', (tester) async {
    final client = _Client()..ready.complete();
    final key = await mount(tester, client);
    final processing = key.currentState!.handlePresentationRequest(
      'untrusted-input',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PresentationRequestView), findsOneWidget);
    Navigator.of(key.currentContext!).pop();
    await tester.pump();
    await processing;
    expect(client.cancelled, ['owned-consent']);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing an open consent retires its native session', (
    tester,
  ) async {
    final client = _Client()..ready.complete();
    final key = await mount(tester, client);
    final processing = key.currentState!.handlePresentationRequest(
      'untrusted-input',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PresentationRequestView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await processing;
    expect(client.cancelled, contains('owned-consent'));
    expect(tester.takeException(), isNull);
  });
}
