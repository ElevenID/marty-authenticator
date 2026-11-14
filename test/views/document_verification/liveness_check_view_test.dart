import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_challenge.dart';
import 'package:marty_authenticator/views/document_verification/liveness_check_view.dart';

Future<LivenessChallenge> fakeChallengeFactory() async {
  final now = DateTime.now().toUtc();
  return LivenessChallenge(
    challengeId: 'lv-test-native',
    nonce: 'nonce-test-native',
    issuedAt: now,
    expiresAt: now.add(const Duration(minutes: 1)),
    gestures: const [
      LivenessGesture.smile,
      LivenessGesture.turnHeadLeft,
      LivenessGesture.turnHeadRight,
      LivenessGesture.lookUp,
      LivenessGesture.lookDown,
    ],
    signature: 'a' * 64,
    nativePayload: '{"challenge_id":"lv-test-native"}',
  );
}

void main() {
  testWidgets('production route fails closed without a remote challenge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LivenessCheckView(config: DocumentVerificationConfig.passport),
      ),
    );
    await tester.pump();
    expect(
      find.text('Remote liveness challenge is unavailable'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('walks through every liveness gesture and opens review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LivenessCheckView(
          config: DocumentVerificationConfig.passport,
          cameraPreviewOverride: const ColoredBox(color: Colors.black),
          mockGestureDelay: const Duration(milliseconds: 10),
          enableExpiryTicker: false,
          challengeFactory: fakeChallengeFactory,
          reviewBuilder: (challenge) =>
              Scaffold(body: Text('Review ${challenge?.challengeId}')),
        ),
      ),
    );
    await tester.pump();

    for (final instruction in [
      'Smile!',
      'Turn head Left',
      'Turn head Right',
      'Look Up',
      'Look Down',
    ]) {
      expect(find.text(instruction), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Review lv-'), findsOneWidget);
  });

  testWidgets('shows camera progress while hardware initializes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LivenessCheckView(
          config: DocumentVerificationConfig.passport,
          enableExpiryTicker: false,
          challengeFactory: fakeChallengeFactory,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('expires a short-lived challenge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LivenessCheckView(
          config: DocumentVerificationConfig.passport,
          cameraPreviewOverride: const ColoredBox(color: Colors.black),
          mockGestureDelay: const Duration(minutes: 1),
          challengeFactory: () async {
            final now = DateTime.now().toUtc();
            return LivenessChallenge(
              challengeId: 'lv-short',
              nonce: 'nonce-short',
              issuedAt: now,
              expiresAt: now.add(const Duration(seconds: 2)),
              gestures: const [LivenessGesture.smile],
              signature: 'signed-payload',
              nativePayload: 'opaque-payload',
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2200)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('Expires in 0 s'), findsOneWidget);
  });

  testWidgets('rejects a malformed remote gesture set before camera starts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LivenessCheckView(
          config: DocumentVerificationConfig.passport,
          cameraPreviewOverride: const ColoredBox(color: Colors.black),
          challengeFactory: () async {
            final now = DateTime.now().toUtc();
            return LivenessChallenge(
              challengeId: 'lv-invalid',
              nonce: 'nonce-invalid',
              issuedAt: now,
              expiresAt: now.add(const Duration(minutes: 1)),
              gestures: const [],
              signature: 'signed-payload',
              nativePayload: 'opaque-payload',
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Remote liveness challenge is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Smile!'), findsNothing);
  });
}
