/// Riverpod providers for SpruceID services
/// Enables dependency injection and easy mocking in tests
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../interfaces/spruce_interfaces.dart';
import '../../../spruce_client.dart';
import '../../../services/spruce_platform_service.dart';

/// Provider for SpruceID platform service (already defined in spruce_platform_service.dart)
/// This is re-exported here for convenience
export '../../../services/spruce_platform_service.dart'
    show spruceIdPlatformServiceProvider;

/// Provider for SpruceIdClient
/// Override this in tests to provide mock implementation
final spruceIdClientProvider = Provider<ISpruceIdClient>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceProvider);
  return SpruceIdClient(platformService);
});

/// Provider for SpruceIdWalletManager
/// Override this in tests to provide mock implementation
final spruceIdWalletManagerProvider = Provider<ISpruceIdWalletManager>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceProvider);
  return SpruceIdWalletManager(platformService);
});

/// Provider for SpruceIdMdocManager
/// Override this in tests to provide mock implementation
final spruceIdMdocManagerProvider = Provider<ISpruceIdMdocManager>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceProvider);
  return SpruceIdMdocManager(platformService);
});

/// Provider for SpruceIdSdJwtManager
/// Override this in tests to provide mock implementation
final spruceIdSdJwtManagerProvider = Provider<ISpruceIdSdJwtManager>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceProvider);
  return SpruceIdSdJwtManager(platformService);
});

/// Convenience provider for initializing SpruceID
/// Watch this in widgets that need SpruceID functionality
final spruceIdInitializedProvider = FutureProvider<bool>((ref) async {
  try {
    final client = ref.watch(spruceIdClientProvider);
    await client.initialize();
    return true;
  } catch (e) {
    // Return false on initialization failure
    return false;
  }
});
