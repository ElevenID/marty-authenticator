import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_challenge.dart';
import 'package:marty_authenticator/providers/verification_state_provider.dart';
import 'package:marty_authenticator/views/document_verification/review_and_submit_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

LivenessChallenge testChallenge() {
  final now = DateTime.now().toUtc();
  return LivenessChallenge(
    challengeId: 'lv-review-fixture',
    nonce: 'nonce-review-fixture',
    issuedAt: now,
    expiresAt: now.add(const Duration(minutes: 1)),
    gestures: const [LivenessGesture.smile],
    signature: 'a' * 64,
    nativePayload: '{"challenge_id":"lv-review-fixture"}',
  );
}

void main() {
  testWidgets('marks pending only after supplied handlers succeed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final challenge = testChallenge();
    var authenticated = false;
    var submitted = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReviewAndSubmitView(
            livenessChallenge: challenge,
            authenticate: () async {
              authenticated = true;
              return true;
            },
            submitRequest: (sentChallenge) async {
              expect(authenticated, isTrue);
              expect(sentChallenge, same(challenge));
              submitted = true;
            },
          ),
        ),
      ),
    );
    expect(find.textContaining(challenge.challengeId), findsOneWidget);
    expect(find.textContaining(challenge.nonce), findsOneWidget);

    await tester.tap(find.text('Authenticate & Submit'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
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
    expect(find.text('Submission Unavailable'), findsOneWidget);
    expect(find.textContaining('Liveness Challenge:'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('expired challenge cannot submit through supplied handlers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now().toUtc();
    final expired = LivenessChallenge(
      challengeId: 'expired',
      nonce: 'nonce',
      issuedAt: now.subtract(const Duration(minutes: 2)),
      expiresAt: now.subtract(const Duration(minutes: 1)),
      gestures: const [LivenessGesture.smile],
      signature: 'a' * 64,
      nativePayload: '{"challenge_id":"expired"}',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReviewAndSubmitView(
            livenessChallenge: expired,
            authenticate: () async => true,
            submitRequest: (_) async => fail('Expired challenge was submitted'),
          ),
        ),
      ),
    );
    expect(find.text('Submission Unavailable'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('malformed challenge cannot reach supplied handlers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final valid = testChallenge();
    final malformed = LivenessChallenge(
      challengeId: valid.challengeId,
      nonce: valid.nonce,
      issuedAt: valid.issuedAt,
      expiresAt: valid.expiresAt,
      gestures: const [LivenessGesture.smile, LivenessGesture.smile],
      signature: valid.signature,
      nativePayload: valid.nativePayload,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReviewAndSubmitView(
            livenessChallenge: malformed,
            authenticate: () async => fail('Malformed challenge authenticated'),
            submitRequest: (_) async => fail('Malformed challenge submitted'),
          ),
        ),
      ),
    );
    expect(find.text('Submission Unavailable'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('reports failed submissions and restores the button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReviewAndSubmitView(
            livenessChallenge: testChallenge(),
            authenticate: () async => true,
            submitRequest: (_) async => throw StateError('network failed'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Authenticate & Submit'));
    await tester.pump();
    expect(find.textContaining('network failed'), findsWidgets);
    expect(find.text('Authenticate & Submit'), findsOneWidget);
  });

  testWidgets('declined authentication never calls the submission handler', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var submitted = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReviewAndSubmitView(
            livenessChallenge: testChallenge(),
            authenticate: () async => false,
            submitRequest: (_) async => submitted = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Authenticate & Submit'));
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    expect(container.read(verificationStateProvider), VerificationStatus.none);
  });
}
