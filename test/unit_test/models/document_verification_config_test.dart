import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';

void main() {
  test('document presets contain the required verification sequence', () {
    expect(DocumentVerificationConfig.passport.type, DocumentType.passport);
    expect(DocumentVerificationConfig.passport.steps, [
      VerificationStep.scanFront,
      VerificationStep.liveness,
    ]);
    expect(DocumentVerificationConfig.driverLicense.steps, [
      VerificationStep.scanFront,
      VerificationStep.scanBack,
      VerificationStep.liveness,
    ]);
  });

  test('random gestures are unique and bounded', () {
    final gestures = DocumentVerificationConfig.generateRandomGestures();
    expect(gestures, hasLength(3));
    expect(gestures.toSet(), hasLength(3));

    expect(
      DocumentVerificationConfig.generateRandomGestures(count: 99).toSet(),
      hasLength(LivenessGesture.values.length),
    );
    expect(
      DocumentVerificationConfig.generateRandomGestures(count: 0),
      isEmpty,
    );
  });
}
