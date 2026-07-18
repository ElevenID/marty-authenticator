import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_challenge.dart';
import 'package:marty_authenticator/providers/verification_state_provider.dart';
import 'package:marty_authenticator/views/document_verification/review_and_submit_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders challenge and submits verification', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final challenge = LivenessChallenge.create(
      gestures: const [LivenessGesture.smile],
      ttl: const Duration(minutes: 1),
      signingSecret: 'test',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReviewAndSubmitView(livenessChallenge: challenge),
        ),
      ),
    );
    expect(find.textContaining(challenge.challengeId), findsOneWidget);
    expect(find.textContaining(challenge.nonce), findsOneWidget);

    await tester.tap(find.text('Authenticate & Submit'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(
      container.read(verificationStateProvider),
      VerificationStatus.pendingApproval,
    );
  });

  testWidgets('renders without an optional challenge', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReviewAndSubmitView())),
    );
    expect(find.text('Ready to Submit'), findsOneWidget);
    expect(find.textContaining('Liveness Challenge:'), findsNothing);
  });

  testWidgets('reports failed submissions and restores the button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReviewAndSubmitView(
            submitRequest: () async => throw StateError('network failed'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Authenticate & Submit'));
    await tester.pump();
    expect(find.textContaining('network failed'), findsWidgets);
    expect(find.text('Authenticate & Submit'), findsOneWidget);
  });
}
