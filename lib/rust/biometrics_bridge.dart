/*
 * Marty Biometrics Bridge
 *
 * Dart helpers wrapping the FRB-generated biometric FFI functions.
 * Call [RustLib.init()] before using these functions.
 *
 * Usage:
 * ```dart
 * final result = await BiometricsBridge.verifyFaceMatch(
 *   referenceImage: referenceB64,
 *   probeImage: probeB64,
 * );
 * if (result.verified) { ... }
 * ```
 */

import 'package:path_provider/path_provider.dart';
import 'marty_bridge.dart/biometrics.dart' as ffi;

/// High-level Dart wrapper around the Rust biometric FFI.
class BiometricsBridge {
  BiometricsBridge._();

  /// Resolve the platform-specific models directory.
  ///
  /// On mobile this is `<appSupportDir>/models/`.
  static Future<String> _modelsDir() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/models';
  }

  /// Compare a reference face against a live probe.
  ///
  /// Returns [FrbFaceMatchResult] with similarity score.
  static Future<ffi.FrbFaceMatchResult> verifyFaceMatch({
    required String referenceImage,
    required String probeImage,
    double? threshold,
  }) async {
    final modelsDir = await _modelsDir();
    return ffi.verifyFaceMatch(
      referenceImage: referenceImage,
      probeImage: probeImage,
      threshold: threshold?.toDouble(),
      modelsDir: modelsDir,
    );
  }

  /// Assess the quality of a face image before capture is accepted.
  static Future<ffi.FrbFaceQuality> assessQuality(String imageBase64) async {
    final modelsDir = await _modelsDir();
    return ffi.assessFaceQuality(image: imageBase64, modelsDir: modelsDir);
  }

  /// Estimate the subject's age from a face image.
  static Future<ffi.FrbAgeEstimate> estimateAge(String imageBase64) async {
    final modelsDir = await _modelsDir();
    return ffi.estimateFaceAge(image: imageBase64, modelsDir: modelsDir);
  }
}
