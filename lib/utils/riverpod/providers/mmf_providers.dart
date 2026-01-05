/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mmf/mmf.dart';
import '../../../services/mmf/mmf_services.dart';
import 'spruce_providers.dart';

// Note: Key management is handled directly by native SpruceID SDK KeyManager.
// The Dart layer does not need a keyManagerProvider - all crypto operations
// go through native platform channels. See IAuthKeyManager for the interface.

/// Provider for ISecureStorage implementation.
///
/// Uses FlutterSecureStorageAdapter backed by flutter_secure_storage.
final secureStorageProvider = Provider<ISecureStorage>((ref) {
  return FlutterSecureStorageAdapter();
});

/// Provider for ICredentialTransport implementation.
///
/// Uses SpruceCredentialTransport backed by SpruceID wallet/mDoc channels.
/// Requires a SpruceIdPlatformService instance.
final credentialTransportProvider = Provider<ICredentialTransport>((ref) {
  final platformService = ref.watch(spruceIdPlatformServiceProvider);
  return SpruceCredentialTransport(platformService: platformService);
});
