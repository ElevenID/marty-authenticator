import 'document_verification_config.dart';
import '../rust/marty_bridge.dart/biometrics.dart' as rust_biometrics;

/// Pure liveness gesture policy, kept independent from camera SDK objects.
class LivenessGestureDetector {
  const LivenessGestureDetector._();

  static bool detects(
    LivenessGesture gesture, {
    double? smilingProbability,
    double? headEulerAngleX,
    double? headEulerAngleY,
  }) {
    return rust_biometrics.evaluateLivenessGesture(
      gesture: gesture.name,
      smilingProbability: smilingProbability,
      headEulerAngleX: headEulerAngleX,
      headEulerAngleY: headEulerAngleY,
    );
  }
}
