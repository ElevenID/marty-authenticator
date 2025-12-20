import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spruce_platform_service_extended.dart';

/// Service for building verifiable presentations
class PresentationBuilderService {
  final ISpruceIdPlatformServiceExtended _platformService;

  PresentationBuilderService(this._platformService);

  Future<Map<String, dynamic>> createPresentation({
    required List<Map<String, dynamic>> credentials,
    required String presentationRequest,
    required List<String> selectedAttributes,
    String? challenge,
    String? domain,
  }) async {
    // Parse request to extract challenge and domain if not provided
    // This is a simplified implementation
    final effectiveChallenge = challenge ?? 'default-challenge';
    final effectiveDomain = domain ?? 'default-domain';

    return await _platformService.createPresentationSDK(
      credentials: credentials,
      challenge: effectiveChallenge,
      domain: effectiveDomain,
    );
  }
}

final presentationBuilderServiceProvider = Provider<PresentationBuilderService>(
  (ref) {
    final platformService = ref.watch(spruceIdPlatformServiceExtendedProvider);
    return PresentationBuilderService(platformService);
  },
);
