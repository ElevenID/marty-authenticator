import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spruce_platform_service_extended.dart';

/// Result of a credential verification
class VerificationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> details;

  const VerificationResult({
    required this.isValid,
    this.errors = const [],
    this.details = const {},
  });
}

/// Service for verifying credentials
class CredentialVerificationService {
  final ISpruceIdPlatformServiceExtended _platformService;

  CredentialVerificationService(this._platformService);

  Future<VerificationResult> verifyCredential(
    Map<String, dynamic> credential,
  ) async {
    try {
      // In a real implementation, this would call the platform service to verify the credential
      // For now, we'll assume it's valid if it has an issuer and type

      // Example call to platform service (if method existed)
      // final result = await _platformService.verifyCredentialSDK(credential);

      final isValid =
          credential.containsKey('issuer') && credential.containsKey('type');

      return VerificationResult(
        isValid: isValid,
        errors: isValid ? [] : ['Missing issuer or type'],
        details: {'checkedAt': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      return VerificationResult(isValid: false, errors: [e.toString()]);
    }
  }
}

final credentialVerificationServiceProvider =
    Provider<CredentialVerificationService>((ref) {
      final platformService = ref.watch(
        spruceIdPlatformServiceExtendedProvider,
      );
      return CredentialVerificationService(platformService);
    });
