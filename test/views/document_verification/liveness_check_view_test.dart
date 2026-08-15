import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_challenge.dart';
import 'package:marty_authenticator/views/document_verification/liveness_check_view.dart';

Future<LivenessChallenge> fakeChallengeFactory({
  required List<LivenessGesture> gestures,
  required Duration ttl,
  required String signingSecret,
}) async {
  final now = DateTime.now().toUtc();
  return LivenessChallenge(
    challengeId: 'lv-test-native',
    nonce: 'nonce-test-native',
    issuedAt: now,
    expiresAt: now.add(ttl),
    gestures: gestures,
    signature: 'a' * 64,
    nativePayload: '{"challenge_id":"lv-test-native"}',
  );
}

void main() {
  testWidgets('walks through every liveness gesture and opens review', (
    tester,
  ) async {
    const gestures = [
      LivenessGesture.smile,
      LivenessGesture.turnHeadLeft,
      LivenessGesture.turnHeadRight,
      LivenessGesture.lookUp,
      LivenessGesture.lookDown,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: LivenessCheckView(
          config: DocumentVerificationConfig.passport,
          gesturesOverride: gestures,
          cameraPreviewOverride: const ColoredBox(color: Colors.black),
          mockGestureDelay: const Duration(milliseconds: 10),
          enableExpiryTicker: false,
          livenessSigningSecret: 'test-secret',
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
          livenessSigningSecret: 'test-secret',
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
          gesturesOverride: const [],
          cameraPreviewOverride: const ColoredBox(color: Colors.black),
          mockGestureDelay: const Duration(minutes: 1),
          challengeTtl: const Duration(milliseconds: 10),
          livenessSigningSecret: 'test-secret',
          challengeFactory: fakeChallengeFactory,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Expires in 0 s'), findsOneWidget);
  });
}
