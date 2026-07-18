import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_challenge.dart';

void main() {
  test('created challenge has signed, unique, serializable data', () {
    final challenge = LivenessChallenge.create(
      gestures: const [LivenessGesture.smile, LivenessGesture.lookUp],
      ttl: const Duration(minutes: 1),
      signingSecret: 'test-secret',
    );
    final second = LivenessChallenge.create(
      gestures: const [LivenessGesture.smile],
      ttl: const Duration(minutes: 1),
      signingSecret: 'test-secret',
    );

    expect(challenge.challengeId, startsWith('lv-'));
    expect(challenge.nonce, startsWith('nonce-'));
    expect(challenge.signature, hasLength(64));
    expect(challenge.challengeId, isNot(second.challengeId));
    expect(challenge.isExpired, isFalse);

    final restored = LivenessChallenge.fromJson(challenge.toJson());
    expect(restored.challengeId, challenge.challengeId);
    expect(restored.gestures, challenge.gestures);
    expect(restored.issuedAt, challenge.issuedAt);
    expect(restored.expiresAt, challenge.expiresAt);
    expect(restored.signature, challenge.signature);
  });

  test('parsing uses safe defaults for invalid external data', () {
    final challenge = LivenessChallenge.fromJson({
      'gestures': ['lookDown', 'unknown'],
      'issued_at': DateTime.utc(2025),
      'expires_at': 'not-a-date',
    });

    expect(challenge.challengeId, isEmpty);
    expect(challenge.nonce, isEmpty);
    expect(challenge.signature, isEmpty);
    expect(challenge.gestures, [
      LivenessGesture.lookDown,
      LivenessGesture.smile,
    ]);
    expect(challenge.issuedAt, DateTime.utc(2025));
    expect(
      challenge.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    expect(challenge.isExpired, isTrue);

    final defaults = LivenessChallenge.fromJson(const {});
    expect(defaults.gestures, isEmpty);
    expect(
      defaults.issuedAt,
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  });
}
