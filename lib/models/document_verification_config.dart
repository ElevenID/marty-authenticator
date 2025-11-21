import '../utils/crypto_utils.dart';

enum DocumentType { passport, driverLicense }

enum VerificationStep { scanFront, scanBack, liveness }

enum LivenessGesture { smile, turnHeadLeft, turnHeadRight, lookUp, lookDown }

class DocumentVerificationConfig {
  final DocumentType type;
  final List<VerificationStep> steps;

  const DocumentVerificationConfig({required this.type, required this.steps});

  static DocumentVerificationConfig
  get passport => const DocumentVerificationConfig(
    type: DocumentType.passport,
    steps: [
      VerificationStep.scanFront, // Passport usually only needs the data page
      VerificationStep.liveness,
    ],
  );

  static DocumentVerificationConfig get driverLicense =>
      const DocumentVerificationConfig(
        type: DocumentType.driverLicense,
        steps: [
          VerificationStep.scanFront,
          VerificationStep.scanBack,
          VerificationStep.liveness,
        ],
      );

  static List<LivenessGesture> generateRandomGestures({int count = 3}) {
    final gestures = LivenessGesture.values.toList();
    final random = secureRandom();
    final selectedGestures = <LivenessGesture>[];

    for (var i = 0; i < count; i++) {
      if (gestures.isEmpty) break;
      // Use nextUint8 to get a random byte, then mod by length
      final randomIndex = random.nextUint8() % gestures.length;
      selectedGestures.add(gestures[randomIndex]);
      // Allow repetition? Usually better not to repeat immediately, but for simplicity let's just pick random.
      // If we want unique gestures, we should remove from list.
      // Let's make them unique for better UX.
      gestures.removeAt(randomIndex);
    }
    return selectedGestures;
  }
}
