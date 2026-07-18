import 'document_verification_config.dart';

/// Pure liveness gesture policy, kept independent from camera SDK objects.
class LivenessGestureDetector {
  const LivenessGestureDetector._();

  static bool detects(
    LivenessGesture gesture, {
    double? smilingProbability,
    double? headEulerAngleX,
    double? headEulerAngleY,
  }) {
    return switch (gesture) {
      LivenessGesture.smile => (smilingProbability ?? 0) > 0.8,
      LivenessGesture.turnHeadLeft => (headEulerAngleY ?? 0) > 45,
      LivenessGesture.turnHeadRight => (headEulerAngleY ?? 0) < -45,
      LivenessGesture.lookUp => (headEulerAngleX ?? 0) > 20,
      LivenessGesture.lookDown => (headEulerAngleX ?? 0) < -20,
    };
  }
}
