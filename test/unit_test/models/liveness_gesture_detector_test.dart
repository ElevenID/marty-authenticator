import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/models/liveness_gesture_detector.dart';

void main() {
  test('applies strict thresholds for every liveness gesture', () {
    expect(
      LivenessGestureDetector.detects(
        LivenessGesture.smile,
        smilingProbability: 0.81,
      ),
      isTrue,
    );
    expect(
      LivenessGestureDetector.detects(
        LivenessGesture.turnHeadLeft,
        headEulerAngleY: 46,
      ),
      isTrue,
    );
    expect(
      LivenessGestureDetector.detects(
        LivenessGesture.turnHeadRight,
        headEulerAngleY: -46,
      ),
      isTrue,
    );
    expect(
      LivenessGestureDetector.detects(
        LivenessGesture.lookUp,
        headEulerAngleX: 21,
      ),
      isTrue,
    );
    expect(
      LivenessGestureDetector.detects(
        LivenessGesture.lookDown,
        headEulerAngleX: -21,
      ),
      isTrue,
    );

    for (final gesture in LivenessGesture.values) {
      expect(LivenessGestureDetector.detects(gesture), isFalse);
    }
  });
}
