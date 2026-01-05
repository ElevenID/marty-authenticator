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

import 'dart:typed_data';

import '../models/credentials.dart';

/// Repository interface for credential operations.
///
/// This is the main abstraction layer between the app and credential storage.
/// Implementations wrap the Marty Rust layer for parsing/validation and
/// delegate storage to platform-specific services.
abstract class CredentialRepository {
  /// Get all stored credentials.
  Future<List<Credential>> getAllCredentials();

  /// Get all Verifiable Credentials.
  Future<List<VerifiableCredential>> getVerifiableCredentials();

  /// Get all mDoc credentials.
  Future<List<MDocCredential>> getMDocCredentials();

  /// Get a credential by ID.
  Future<Credential?> getCredentialById(String id);

  /// Store a new credential.
  Future<void> storeCredential(Credential credential);

  /// Delete a credential by ID.
  Future<void> deleteCredential(String id);

  /// Parse a raw JSON string into a VerifiableCredential.
  ///
  /// Uses the Marty Rust layer for parsing and validation.
  Future<VerifiableCredential> parseVerifiableCredential(String json);

  /// Parse raw CBOR bytes into an MDocCredential.
  ///
  /// Uses the Marty Rust layer for CBOR parsing and claim extraction.
  Future<MDocCredential> parseMDocCredential(Uint8List cbor);

  /// Verify the trust chain for an mDoc credential.
  ///
  /// Uses the Marty Rust layer (marty-verification) for IACA/CSCA validation.
  Future<TrustInfo> verifyMDocTrustChain(List<Uint8List> x5chain);

  /// Verify and attach trust info to a credential.
  Future<Credential> verifyAndAttachTrust(
    Credential credential,
    List<Uint8List> x5chain,
  );

  /// Group credentials by issuer for display.
  Future<List<CredentialGroup>> groupByIssuer();

  /// Search credentials by type or issuer.
  Future<List<Credential>> searchCredentials({
    String? type,
    String? issuer,
    bool includeExpired = false,
  });

  /// Get credentials matching a presentation request.
  Future<List<SelectableCredential>> getMatchingCredentials({
    required List<String> requestedTypes,
    required List<String> requestedAttributes,
  });
}

/// Result of a credential operation.
class CredentialOperationResult<T> {
  final T? data;
  final CredentialError? error;

  const CredentialOperationResult._({this.data, this.error});

  factory CredentialOperationResult.success(T data) =>
      CredentialOperationResult._(data: data);

  factory CredentialOperationResult.failure(CredentialError error) =>
      CredentialOperationResult._(error: error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  T get dataOrThrow {
    if (error != null) {
      throw error!;
    }
    return data as T;
  }
}

/// Errors that can occur during credential operations.
class CredentialError implements Exception {
  final CredentialErrorType type;
  final String message;
  final dynamic cause;

  const CredentialError({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'CredentialError(${type.name}): $message';
}

/// Types of credential errors.
enum CredentialErrorType {
  /// Failed to parse credential data
  parseError,

  /// Trust chain verification failed
  trustChainError,

  /// Signature verification failed
  signatureError,

  /// Certificate error
  certificateError,

  /// Unsupported credential format
  unsupportedFormat,

  /// Credential has expired
  expired,

  /// Credential has been revoked
  revoked,

  /// Storage operation failed
  storageError,

  /// Network error during verification
  networkError,

  /// Internal/unknown error
  internal,
}
