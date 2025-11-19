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

/// Abstract interfaces for SpruceID services to enable mocking and dependency injection
library;

import 'dart:async';

/// Platform service interface for SpruceID operations
/// Abstracts platform channel communication for testability
abstract class ISpruceIdPlatformService {
  bool get isInitialized;

  // W3C VC Methods
  Future<void> initializeW3C();
  Future<Map<String, dynamic>> createDid({String method = 'key'});
  Future<Map<String, dynamic>> resolveDid(String did);
  Future<Map<String, dynamic>> signVerifiableCredential(
    Map<String, dynamic> credential, {
    String? keyId,
  });
  Future<Map<String, dynamic>> verifyVerifiableCredential(
    Map<String, dynamic> credential,
  );

  // PKI/X.509 Methods
  Future<Map<String, dynamic>> generateKeyPair({
    String keyType = 'RSA',
    int keySize = 2048,
  });
  Future<Map<String, dynamic>> createCSR(String subject, {String? keyId});
  Future<Map<String, dynamic>> signWithCertificate(
    Map<String, dynamic> document,
    String certificateId,
  );
  Future<Map<String, dynamic>> verifyCertificateChain(
    List<String> certificateChain,
  );

  // JWT Methods
  Future<Map<String, dynamic>> createJWT(
    String issuer,
    Map<String, dynamic> claims,
  );
  Future<Map<String, dynamic>> verifyJWT(String jwt, String issuer);
  Future<Map<String, dynamic>> createSdJwt(
    String issuer,
    Map<String, dynamic> claims,
    List<String> selectivelyDisclosableClaims,
  );
  Future<Map<String, dynamic>> verifySdJwt(
    String sdJwt,
    List<String> requiredClaims,
  );

  // mDoc Methods
  Future<Map<String, dynamic>> initializeMdl(Map<String, dynamic> mdlData);
  Future<Map<String, dynamic>> presentForAgeVerification(int minimumAge);
  Future<Map<String, dynamic>> createMdocResponse(
    List<String> requestedAttributes,
    List<String> hiddenAttributes,
  );

  // Wallet Methods
  Future<void> storeCredential(Map<String, dynamic> credential);
  Future<List<Map<String, dynamic>>> getStoredCredentials();
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type);
  Future<void> deleteCredential(String id);
}

/// Main SpruceID client interface
/// Provides high-level API for SpruceID operations
abstract class ISpruceIdClient {
  Future<void> initialize();
  Future<String> createDid({String method = 'key'});
  Future<Map<String, dynamic>> signCredential(
    Map<String, dynamic> credential,
  );
  Future<Map<String, dynamic>> verifyCredential(
    Map<String, dynamic> credential,
  );
  Future<Map<String, dynamic>> createMdocResponse({
    required List<String> requestedAttributes,
    List<String>? hiddenAttributes,
  });
  Future<Map<String, dynamic>> createSdJwtPresentation({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> discloseKeys,
  });
  Future<List<Map<String, dynamic>>> getCredentials();
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type);
}

/// mDoc manager interface for mobile documents
/// Handles MDL and other mobile document operations
abstract class ISpruceIdMdocManager {
  Future<Map<String, dynamic>> initializeMdl(Map<String, dynamic> mdlData);
  Future<Map<String, dynamic>> presentForAgeVerification({
    required int minimumAge,
  });
  Future<Map<String, dynamic>> presentForIdVerification({
    required List<String> requestedAttributes,
    List<String>? hiddenAttributes,
  });
}

/// SD-JWT manager interface for selective disclosure
/// Handles SD-JWT creation and presentation
abstract class ISpruceIdSdJwtManager {
  Future<Map<String, dynamic>> createSdJwt({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> selectivelyDisclosableClaims,
  });
  Future<Map<String, dynamic>> present({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> discloseClaims,
  });
}

/// Wallet manager interface for credential storage
/// Handles credential persistence and retrieval
abstract class ISpruceIdWalletManager {
  Future<void> storeCredential(Map<String, dynamic> credential);
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type);
  Future<void> deleteCredential(String credentialId);
  Future<List<Map<String, dynamic>>> getAllCredentials();
}
