import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_challenge.dart';

void main() {
  test('native challenge data remains serializable', () {
    final now = DateTime.now().toUtc();
    final challenge = LivenessChallenge(
      challengeId: 'lv-native',
      nonce: 'nonce-native',
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
      gestures: const [LivenessGesture.smile, LivenessGesture.lookUp],
      signature: 'a' * 64,
      nativePayload: '{"challenge_id":"lv-native"}',
    );
    expect(challenge.challengeId, startsWith('lv-'));
    expect(challenge.nonce, startsWith('nonce-'));
    expect(challenge.signature, hasLength(64));

    final restored = LivenessChallenge.fromJson(challenge.toJson());
    expect(restored.challengeId, challenge.challengeId);
    expect(restored.gestures, challenge.gestures);
    expect(restored.issuedAt, challenge.issuedAt);
    expect(restored.expiresAt, challenge.expiresAt);
    expect(restored.signature, challenge.signature);
    expect(restored.nativePayload, challenge.nativePayload);
  });

  test('malformed or expired remote challenge data fails closed', () {
    final now = DateTime.now().toUtc();
    final valid = <String, dynamic>{
      'challenge_id': 'lv-test',
      'nonce': 'nonce-test',
      'issued_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(minutes: 1)).toIso8601String(),
      'gestures': ['lookDown'],
      'signature': 'signed-payload',
      'native_payload': 'opaque-payload',
    };
    expect(LivenessChallenge.fromJson(valid).gestures, [
      LivenessGesture.lookDown,
    ]);

    final invalid = [
      <String, dynamic>{},
      {
        ...valid,
        'gestures': ['lookDown', 'unknown'],
      },
      {
        ...valid,
        'gestures': ['lookDown', 'lookDown'],
      },
      {...valid, 'gestures': <String>[]},
      {...valid, 'issued_at': 'not-a-date'},
      {
        ...valid,
        'expires_at': now
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      },
      {...valid, 'signature': ''},
      {...valid, 'native_payload': null},
    ];
    for (final json in invalid) {
      expect(() => LivenessChallenge.fromJson(json), throwsFormatException);
    }
  });
}
