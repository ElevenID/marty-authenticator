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

/// Riverpod providers for credential repository
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/credential_repository.dart';
import '../../../repositories/marty_credential_repository.dart';
import '../../../models/credentials.dart';
import 'spruce_providers.dart';

/// Provider for the credential repository.
///
/// This is the main entry point for all credential operations.
/// Uses MartyCredentialRepository which wraps the Marty Rust layer
/// for parsing/validation and SpruceID for storage transport.
final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  final walletManager = ref.watch(spruceIdWalletManagerProvider);
  return MartyCredentialRepository(walletManager: walletManager);
});

/// Provider for all credentials.
final allCredentialsProvider = FutureProvider<List<Credential>>((ref) async {
  final repository = ref.watch(credentialRepositoryProvider);
  return repository.getAllCredentials();
});

/// Provider for verifiable credentials only.
final verifiableCredentialsProvider =
    FutureProvider<List<VerifiableCredential>>((ref) async {
      final repository = ref.watch(credentialRepositoryProvider);
      return repository.getVerifiableCredentials();
    });

/// Provider for mDoc credentials only.
final mDocCredentialsProvider = FutureProvider<List<MDocCredential>>((
  ref,
) async {
  final repository = ref.watch(credentialRepositoryProvider);
  return repository.getMDocCredentials();
});

/// Provider for credentials grouped by issuer.
final groupedCredentialsProvider = FutureProvider<List<CredentialGroup>>((
  ref,
) async {
  final repository = ref.watch(credentialRepositoryProvider);
  return repository.groupByIssuer();
});

/// Provider for a specific credential by ID.
final credentialByIdProvider = FutureProvider.family<Credential?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(credentialRepositoryProvider);
  return repository.getCredentialById(id);
});

/// Provider for matching credentials in a presentation request.
final matchingCredentialsProvider =
    FutureProvider.family<
      List<SelectableCredential>,
      ({List<String> types, List<String> attributes})
    >((ref, request) async {
      final repository = ref.watch(credentialRepositoryProvider);
      return repository.getMatchingCredentials(
        requestedTypes: request.types,
        requestedAttributes: request.attributes,
      );
    });

/// State notifier for credential mutations (add, delete).
class CredentialNotifier extends StateNotifier<AsyncValue<void>> {
  final CredentialRepository _repository;
  final Ref _ref;

  CredentialNotifier(this._repository, this._ref)
    : super(const AsyncValue.data(null));

  /// Store a new credential.
  Future<void> storeCredential(Credential credential) async {
    state = const AsyncValue.loading();
    try {
      await _repository.storeCredential(credential);
      // Invalidate cached providers
      _ref.invalidate(allCredentialsProvider);
      _ref.invalidate(verifiableCredentialsProvider);
      _ref.invalidate(mDocCredentialsProvider);
      _ref.invalidate(groupedCredentialsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete a credential by ID.
  Future<void> deleteCredential(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteCredential(id);
      // Invalidate cached providers
      _ref.invalidate(allCredentialsProvider);
      _ref.invalidate(verifiableCredentialsProvider);
      _ref.invalidate(mDocCredentialsProvider);
      _ref.invalidate(groupedCredentialsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider for credential mutations.
final credentialNotifierProvider =
    StateNotifierProvider<CredentialNotifier, AsyncValue<void>>((ref) {
      final repository = ref.watch(credentialRepositoryProvider);
      return CredentialNotifier(repository, ref);
    });
