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

/// Extended SpruceID platform service implementation
/// Leverages SDK integration from refactored Android and iOS handlers
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../interfaces/spruce_interfaces_extended.dart';
import '../rust/marty_bridge.dart/api.dart' as rust_api;
import 'remote_holder_pairing_service.dart';
import 'wallet_credential_store.dart';
import 'spruce_platform_service.dart';

/// Exception thrown when user selection is required for a presentation request
class UserSelectionRequiredException implements Exception {
  final String sessionId;
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic> requestDetails;

  UserSelectionRequiredException({
    required this.sessionId,
    required this.matches,
    required this.requestDetails,
  });

  @override
  String toString() => 'UserSelectionRequiredException(sessionId: $sessionId)';
}

class _PendingVerifiedPresentation {
  final String requestUri;
  final String requestDigest;
  final String queryId;
  final List<String> requiredClaims;
  final Map<String, String> credentials;
  final DateTime createdAt;

  const _PendingVerifiedPresentation({
    required this.requestUri,
    required this.requestDigest,
    required this.queryId,
    required this.requiredClaims,
    required this.credentials,
    required this.createdAt,
  });
}

/// Extended platform service implementation with SDK capabilities
/// Uses the refactored Android and iOS handlers with SDK integration
class SpruceIdPlatformServiceExtended extends SpruceIdPlatformService
    implements ISpruceIdPlatformServiceExtended {
  static final _instance = SpruceIdPlatformServiceExtended._internal();
  factory SpruceIdPlatformServiceExtended() => _instance;
  SpruceIdPlatformServiceExtended._internal() : super.protected();

  // Additional SDK-enabled channels
  final MethodChannel _sdkChannel = const MethodChannel('spruce_id_sdk');
  final Map<String, String> _presentationSessionRoutes = {};
  final Map<String, _PendingVerifiedPresentation>
  _pendingVerifiedPresentations = {};

  // ========================
  // SDK-Enhanced OID4VC Operations
  // ========================

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
    String? keyId,
  }) async {
    if (keyId != null) {
      throw UnsupportedError('Local holder key selection is retired');
    }
    final holder = RemoteHolderPairingService();
    try {
      final publicJwk = await holder.publicJwkForPurpose(
        'presentation_signing',
      );
      final prepared = await rust_api.walletPrepareVerifiedSdJwtReceipt(
        offerUri: credentialOffer,
        txCode: pin,
        holderPublicJwkJson: jsonEncode(publicJwk),
      );
      final signature = await holder.signInput(
        purpose: 'presentation_signing',
        signingInput: prepared.signingInput,
      );
      final snapshot = await holder.fetchIssuerKeys();
      final receipt = await rust_api.walletCompleteVerifiedSdJwtReceipt(
        sessionId: prepared.sessionId,
        remoteSignature: signature,
        issuerSnapshotJson: jsonEncode(snapshot),
      );
      final id = const Uuid().v4();
      await WalletCredentialStore.store(
        StoredCredential(
          id: id,
          format: receipt.format,
          issuer: receipt.issuer,
          types: [receipt.credentialType],
          rawJson: receipt.credential,
          issuedAt: DateTime.now().toUtc(),
        ),
      );
      return {'id': id, 'format': receipt.format, 'issuer': receipt.issuer};
    } finally {
      holder.close();
    }
  }

  @override
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  }) async {
    final holder = RemoteHolderPairingService();
    try {
      MethodChannel channel = w3cChannel;
      String method = 'handleVpRequest';

      final route = await rust_api.walletRoutePresentationRequest(
        input: presentationRequest,
      );
      if (route == 'mdoc') {
        channel = mdocChannel;
        method = 'createMdocResponse';
      } else if (route != 'oid4vp') {
        throw StateError(
          'Native wallet returned an unsupported presentation route',
        );
      }
      await holder.renewIfDue();

      if (route == 'oid4vp') {
        return await _initiateVerifiedPresentation(presentationRequest);
      }

      final result = await channel.invokeMethod(method, {
        'request': presentationRequest,
        'requestUrl': presentationRequest,
      });

      final resultMap = Map<String, dynamic>.from(result);

      if (resultMap['status'] == 'user_selection_required') {
        final sessionId = resultMap['sessionId'];
        if (sessionId is! String || sessionId.isEmpty) {
          throw StateError('Presentation selection session is invalid');
        }
        if (_presentationSessionRoutes.containsKey(sessionId)) {
          throw StateError('Presentation selection session was reused');
        }
        if (_presentationSessionRoutes.length >= 16) {
          _presentationSessionRoutes.remove(
            _presentationSessionRoutes.keys.first,
          );
        }
        _presentationSessionRoutes[sessionId] = route;
        throw UserSelectionRequiredException(
          sessionId: sessionId,
          matches: List<Map<String, dynamic>>.from(resultMap['matches'] ?? []),
          requestDetails: {
            'verifier': resultMap['verifier'],
            'purpose': resultMap['purpose'],
          },
        );
      }

      return resultMap;
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK OID4VP initiation failed: ${e.message}',
        e.details,
      );
    } finally {
      holder.close();
    }
  }

  @override
  Future<Map<String, dynamic>> completeOID4VPRequestSDK({
    required String sessionId,
    required String selectedCredentialId,
    List<String>? selectedFields,
  }) async {
    try {
      final route = _presentationSessionRoutes[sessionId];
      if (route == null) {
        throw StateError('Presentation selection session is unknown');
      }
      if (route == 'oid4vp') {
        _presentationSessionRoutes.remove(sessionId);
        return await _completeVerifiedPresentation(
          sessionId,
          selectedCredentialId,
          selectedFields,
        );
      }
      final channel = route == 'mdoc' ? mdocChannel : w3cChannel;
      final method = route == 'mdoc' ? 'createMdocResponse' : 'handleVpRequest';
      final result = await channel.invokeMethod(method, {
        'sessionId': sessionId,
        'selectedCredentialId': selectedCredentialId,
        'selectedFields': selectedFields,
      });
      _presentationSessionRoutes.remove(sessionId);
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK OID4VP completion failed: ${e.message}',
        e.details,
      );
    }
  }

  Future<Map<String, dynamic>> _initiateVerifiedPresentation(
    String requestUri,
  ) async {
    final request = await rust_api.walletParsePresentationRequest(
      requestUri: requestUri,
    );
    if (request.clientId.isEmpty ||
        request.nonce.isEmpty ||
        request.requestDigest.isEmpty) {
      throw StateError('Presentation request is invalid');
    }
    late final String queryId;
    final requestedClaims = <String>[];
    String? purpose;
    if (request.queryType == 'dcql_query') {
      final query = jsonDecode(request.dcqlQueryJson ?? 'null');
      if (query is! Map<String, dynamic> ||
          query['credentials'] is! List ||
          (query['credentials'] as List).length != 1) {
        throw StateError('Presentation query is unsupported');
      }
      final credential = (query['credentials'] as List).single;
      if (credential is! Map<String, dynamic> ||
          credential['id'] is! String ||
          credential['meta'] != null ||
          !{'dc+sd-jwt', 'vc+sd-jwt'}.contains(credential['format'])) {
        throw StateError('Presentation credential format is unsupported');
      }
      queryId = credential['id'] as String;
      final claims = credential['claims'] ?? [];
      if (claims is! List) throw StateError('Presentation claims are invalid');
      for (final claim in claims) {
        if (claim is! Map<String, dynamic> ||
            claim['path'] is! List ||
            (claim['path'] as List).length != 1 ||
            (claim['path'] as List).single is! String) {
          throw StateError('Presentation claim path is unsupported');
        }
        requestedClaims.add((claim['path'] as List).single as String);
      }
    } else if (request.queryType == 'presentation_definition') {
      final definition = jsonDecode(
        request.presentationDefinitionJson ?? 'null',
      );
      if (definition is! Map<String, dynamic> ||
          definition['input_descriptors'] is! List ||
          (definition['input_descriptors'] as List).length != 1) {
        throw StateError('Presentation definition is unsupported');
      }
      final descriptor = (definition['input_descriptors'] as List).single;
      if (descriptor is! Map<String, dynamic> || descriptor['id'] is! String) {
        throw StateError('Presentation descriptor is invalid');
      }
      final formats = descriptor['format'];
      if (formats != null &&
          (formats is! Map<String, dynamic> ||
              !formats.entries.any((entry) {
                if (!{
                  'dc+sd-jwt',
                  'vc+sd-jwt',
                  'sd_jwt_vc',
                }.contains(entry.key)) {
                  return false;
                }
                final requirement = entry.value;
                if (requirement is! Map<String, dynamic>) {
                  return false;
                }
                final algorithms = requirement['alg'];
                return algorithms == null ||
                    (algorithms is List && algorithms.contains('ES256'));
              }))) {
        throw StateError('Presentation descriptor format is unsupported');
      }
      queryId = descriptor['id'] as String;
      purpose = definition['purpose'] is String
          ? definition['purpose'] as String
          : null;
      final constraints = descriptor['constraints'];
      final fields = constraints is Map<String, dynamic>
          ? constraints['fields'] ?? []
          : [];
      if (fields is! List) throw StateError('Presentation fields are invalid');
      for (final field in fields) {
        if (field is! Map<String, dynamic> ||
            field['filter'] != null ||
            field['zk_predicate'] != null ||
            field['optional'] == true ||
            field['path'] is! List ||
            (field['path'] as List).length != 1) {
          throw StateError('Presentation field constraint is unsupported');
        }
        final path = (field['path'] as List).single;
        if (path is! String ||
            !RegExp(r'^\$\.[A-Za-z_][A-Za-z0-9_]*$').hasMatch(path)) {
          throw StateError('Presentation field path is unsupported');
        }
        requestedClaims.add(path.substring(2));
      }
    } else {
      throw StateError('Presentation query type is unsupported');
    }
    if (queryId.isEmpty ||
        requestedClaims.length > 64 ||
        requestedClaims.any(
          (claim) =>
              claim.length > 256 ||
              !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(claim),
        ) ||
        requestedClaims.toSet().length != requestedClaims.length) {
      throw StateError('Presentation request claims are invalid');
    }

    final tokens = <String, String>{};
    final matches = <Map<String, dynamic>>[];
    for (final credential in await WalletCredentialStore.getAll()) {
      if (!{
        'dc+sd-jwt',
        'vc+sd-jwt',
        'sd_jwt_vc',
      }.contains(credential.format)) {
        continue;
      }
      final token = _storedSdJwt(credential.rawJson);
      if (token == null) continue;
      tokens[credential.id] = token;
      matches.add({
        'id': credential.id,
        'type': credential.types.join(', '),
        'issuer': credential.issuer,
        'requestedFields': {'credential': requestedClaims},
      });
    }
    if (matches.isEmpty) {
      throw StateError('No stored SD-JWT credential is available');
    }
    final random = Random.secure();
    final sessionId = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    if (_presentationSessionRoutes.containsKey(sessionId)) {
      throw StateError('Presentation session collision');
    }
    if (_presentationSessionRoutes.length >= 16) {
      final evicted = _presentationSessionRoutes.keys.first;
      _presentationSessionRoutes.remove(evicted);
      _pendingVerifiedPresentations.remove(evicted);
    }
    _presentationSessionRoutes[sessionId] = 'oid4vp';
    _pendingVerifiedPresentations[sessionId] = _PendingVerifiedPresentation(
      requestUri: requestUri,
      requestDigest: request.requestDigest,
      queryId: queryId,
      requiredClaims: requestedClaims,
      credentials: tokens,
      createdAt: DateTime.now().toUtc(),
    );
    throw UserSelectionRequiredException(
      sessionId: sessionId,
      matches: matches,
      requestDetails: {'verifier': request.clientId, 'purpose': purpose},
    );
  }

  static String? _storedSdJwt(String raw) {
    Object? value;
    try {
      value = jsonDecode(raw);
    } catch (_) {
      value = raw;
    }
    if (value is Map<String, dynamic>) value = value['credential'];
    if (value is! String ||
        value.isEmpty ||
        value.length > 1024 * 1024 ||
        !value.contains('~')) {
      return null;
    }
    return value;
  }

  Future<Map<String, dynamic>> _completeVerifiedPresentation(
    String sessionId,
    String selectedCredentialId,
    List<String>? selectedFields,
  ) async {
    final pending = _pendingVerifiedPresentations.remove(sessionId);
    if (pending == null ||
        DateTime.now().toUtc().difference(pending.createdAt) >
            const Duration(minutes: 2)) {
      throw StateError('Presentation approval expired');
    }
    final credential = pending.credentials[selectedCredentialId];
    if (credential == null) {
      throw StateError('Selected credential is unavailable');
    }
    if (selectedFields == null) {
      throw StateError('Presentation disclosures require explicit approval');
    }
    final selected = selectedFields.map((field) {
      if (!field.startsWith('credential/')) {
        throw StateError('Selected disclosure field is invalid');
      }
      return field.substring('credential/'.length);
    }).toSet();
    if (!selected.containsAll(pending.requiredClaims) ||
        selected.difference(pending.requiredClaims.toSet()).isNotEmpty) {
      throw StateError(
        'Selected disclosure does not match the approved request',
      );
    }

    final holder = RemoteHolderPairingService();
    try {
      final snapshot = await holder.fetchIssuerKeys();
      final publicJwk = await holder.publicJwkForPurpose(
        'presentation_signing',
      );
      final prepared = await rust_api.walletPrepareVerifiedSdJwtPresentation(
        requestUri: pending.requestUri,
        approvedRequestDigest: pending.requestDigest,
        credential: credential,
        queryId: pending.queryId,
        claimsToDisclose: pending.requiredClaims,
        issuerSnapshotJson: jsonEncode(snapshot),
        holderPublicJwkJson: jsonEncode(publicJwk),
      );
      final signature = await holder.signInput(
        purpose: 'presentation_signing',
        signingInput: prepared.signingInput,
      );
      final response = await rust_api.walletCompleteVerifiedSdJwtPresentation(
        sessionId: prepared.sessionId,
        remoteSignature: signature,
      );
      if (!response.ok) {
        throw StateError(
          response.errorDescription ?? 'Verifier rejected presentation',
        );
      }
      return {'ok': true, 'redirect_uri': response.redirectUri};
    } finally {
      holder.close();
    }
  }

  @override
  Future<Map<String, dynamic>> handleOID4VPRequestSDK({
    required String presentationRequest,
    required List<Map<String, dynamic>> selectedCredentials,
    required List<String> disclosureOptions,
    String? keyId,
  }) async {
    throw UnsupportedError(
      'Presentations require the verified remote-KMS selection flow',
    );
  }

  @override
  Future<Map<String, dynamic>> createPresentationSDK({
    required List<Map<String, dynamic>> credentials,
    required String challenge,
    required String domain,
    required Map<String, List<String>> selectiveDisclosure,
    String? keyId,
  }) async {
    throw UnsupportedError(
      'Presentation creation requires a verified remote-KMS request',
    );
  }

  // ========================
  // SDK-Enhanced Holder Operations
  // ========================

  @override
  Future<Map<String, dynamic>> initializeHolderSDK({
    String? keyId,
    Map<String, dynamic>? holderConfig,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('initializeHolderSDK', {
        'keyId': keyId ?? 'default-key',
        'config': holderConfig ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Holder SDK initialization failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createVerifiablePresentationSDK({
    required List<Map<String, dynamic>> credentials,
    required String challenge,
    String? domain,
    Map<String, List<String>>? selectiveDisclosure,
    String? presentationFormat,
    String? keyId,
  }) async {
    try {
      final result = await _sdkChannel
          .invokeMethod('createVerifiablePresentationSDK', {
            'credentials': credentials,
            'challenge': challenge,
            'domain': domain ?? '',
            'selectiveDisclosure': selectiveDisclosure ?? {},
            'presentationFormat': presentationFormat ?? 'jwt_vp',
            'keyId': keyId ?? 'default-key',
          });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK verifiable presentation creation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> signPresentationSDK({
    required Map<String, dynamic> presentation,
    required String keyId,
    String? verificationMethod,
    String? proofPurpose,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('signPresentationSDK', {
        'presentation': presentation,
        'keyId': keyId,
        'verificationMethod': verificationMethod,
        'proofPurpose': proofPurpose ?? 'authentication',
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK presentation signing failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Advanced Credential Operations
  // ========================

  @override
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>> operations,
    String? keyId,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod(
        'batchProcessCredentialsSDK',
        {'operations': operations, 'keyId': keyId ?? 'default-key'},
      );

      return List<Map<String, dynamic>>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK batch credential processing failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(
    String credentialId,
  ) async {
    try {
      final result = await _sdkChannel.invokeMethod(
        'getCredentialCapabilitiesSDK',
        {'credentialId': credentialId},
      );

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential capabilities retrieval failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> validateCredentialSDK({
    required Map<String, dynamic> credential,
    String? schemaId,
    List<String>? policies,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('validateCredentialSDK', {
        'credential': credential,
        'schemaId': schemaId,
        'policies': policies ?? [],
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential validation failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Enhanced Security Operations
  // ========================

  @override
  Future<Map<String, dynamic>> generateSecureKeySDK({
    String algorithm = 'Ed25519',
    bool useHardwareModule = true,
    Map<String, dynamic>? keyPolicies,
  }) async {
    try {
      final result = await _sdkChannel.invokeMethod('generateSecureKeySDK', {
        'algorithm': algorithm,
        'useHardwareModule': useHardwareModule,
        'keyPolicies': keyPolicies ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK secure key generation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> performCryptoOperationSDK({
    required String operation,
    required String keyId,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? options,
  }) async {
    try {
      final result = await _sdkChannel
          .invokeMethod('performCryptoOperationSDK', {
            'operation': operation,
            'keyId': keyId,
            'payload': payload,
            'options': options ?? {},
          });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK crypto operation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> establishSecureChannelSDK({
    required String peerDid,
    String? keyId,
    Map<String, dynamic>? channelOptions,
  }) async {
    try {
      final result = await _sdkChannel
          .invokeMethod('establishSecureChannelSDK', {
            'peerDid': peerDid,
            'keyId': keyId ?? 'default-key',
            'channelOptions': channelOptions ?? {},
          });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK secure channel establishment failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Selective Disclosure Advanced Features
  // ========================

  @override
  Future<Map<String, dynamic>> createAdvancedSdJwtSDK({
    required String issuer,
    required Map<String, dynamic> claims,
    required Map<String, dynamic> disclosureTree,
    List<String>? alwaysDisclose,
    String? keyId,
  }) async {
    try {
      final result = await jwtChannel.invokeMethod('createAdvancedSdJwtSDK', {
        'issuer': issuer,
        'claims': claims,
        'disclosureTree': disclosureTree,
        'alwaysDisclose': alwaysDisclose ?? [],
        'keyId': keyId ?? 'default-key',
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK advanced SD-JWT creation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> presentSdJwtSDK({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
    String? keyId,
  }) async {
    try {
      final result = await jwtChannel.invokeMethod('presentSdJwtSDK', {
        'sdJwt': sdJwt,
        'disclosureRequest': disclosureRequest,
        'challenge': challenge,
        'keyId': keyId ?? 'default-key',
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK SD-JWT presentation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifySdJwtPresentationSDK({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  }) async {
    try {
      final result = await jwtChannel
          .invokeMethod('verifySdJwtPresentationSDK', {
            'presentation': presentation,
            'requiredClaims': requiredClaims,
            'policies': policies ?? [],
          });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK SD-JWT presentation verification failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // mDoc Advanced Operations
  // ========================

  @override
  Future<Map<String, dynamic>> initializeMdocSDK({
    required Map<String, dynamic> mdocData,
    bool enableProximityDetection = true,
    Map<String, dynamic>? deviceConfig,
  }) async {
    try {
      final result = await mdocChannel.invokeMethod('initializeMdocSDK', {
        'mdocData': mdocData,
        'enableProximityDetection': enableProximityDetection,
        'deviceConfig': deviceConfig ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc initialization failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> handleMdocOid4vpRequestSDK({
    required String requestUrl,
  }) async {
    try {
      final result = await mdocChannel.invokeMethod('createMdocResponse', {
        'requestUrl': requestUrl,
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc OID4VP request handling failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createMdocPresentationSDK({
    required String docType,
    required List<String> requestedAttributes,
    Map<String, dynamic>? ageVerificationOptions,
    List<String>? hiddenAttributes,
    String? keyId,
  }) async {
    try {
      final result = await mdocChannel
          .invokeMethod('createMdocPresentationSDK', {
            'docType': docType,
            'requestedAttributes': requestedAttributes,
            'ageVerificationOptions': ageVerificationOptions,
            'hiddenAttributes': hiddenAttributes ?? [],
            'keyId': keyId ?? 'default-key',
          });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc presentation creation failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> establishMdocSessionSDK({
    required Map<String, dynamic> sessionRequest,
    String? keyId,
    Map<String, dynamic>? securityOptions,
  }) async {
    try {
      final result = await mdocChannel.invokeMethod('establishMdocSessionSDK', {
        'sessionRequest': sessionRequest,
        'keyId': keyId ?? 'default-key',
        'securityOptions': securityOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK mDoc session establishment failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Credential Lifecycle Management
  // ========================

  @override
  Future<Stream<Map<String, dynamic>>> monitorCredentialStatusSDK(
    String credentialId,
  ) async {
    final StreamController<Map<String, dynamic>> controller =
        StreamController();

    try {
      // Set up platform channel stream for credential monitoring
      const EventChannel eventChannel = EventChannel(
        'spruce_id_credential_monitor',
      );

      await _sdkChannel.invokeMethod('startCredentialMonitoring', {
        'credentialId': credentialId,
      });

      eventChannel
          .receiveBroadcastStream(credentialId)
          .listen(
            (data) {
              controller.add(Map<String, dynamic>.from(data));
            },
            onError: (error) {
              controller.addError(
                SpruceIdException(
                  'MONITOR_ERROR',
                  'Credential monitoring error: $error',
                ),
              );
            },
            onDone: () {
              controller.close();
            },
          );

      return controller.stream;
    } catch (e) {
      controller.addError(
        SpruceIdException(
          'MONITOR_SETUP_ERROR',
          'Failed to setup credential monitoring: $e',
        ),
      );
      return controller.stream;
    }
  }

  @override
  Future<Map<String, dynamic>> refreshCredentialSDK({
    required String credentialId,
    String? keyId,
    Map<String, dynamic>? refreshOptions,
  }) async {
    try {
      final result = await walletChannel.invokeMethod('refreshCredentialSDK', {
        'credentialId': credentialId,
        'keyId': keyId ?? 'default-key',
        'refreshOptions': refreshOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential refresh failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> backupCredentialsSDK({
    List<String>? credentialIds,
    required String backupPassphrase,
    Map<String, dynamic>? backupOptions,
  }) async {
    try {
      final result = await walletChannel.invokeMethod('backupCredentialsSDK', {
        'credentialIds': credentialIds ?? [],
        'backupPassphrase': backupPassphrase,
        'backupOptions': backupOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential backup failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> restoreCredentialsSDK({
    required String backupData,
    required String backupPassphrase,
    Map<String, dynamic>? restoreOptions,
  }) async {
    try {
      final result = await walletChannel.invokeMethod('restoreCredentialsSDK', {
        'backupData': backupData,
        'backupPassphrase': backupPassphrase,
        'restoreOptions': restoreOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential restore failed: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Cross-Platform Sync and Integration
  // ========================

  @override
  Future<Map<String, dynamic>> syncCredentialsSDK({
    required String syncEndpoint,
    String? syncToken,
    Map<String, dynamic>? syncOptions,
  }) async {
    try {
      final result = await walletChannel.invokeMethod('syncCredentialsSDK', {
        'syncEndpoint': syncEndpoint,
        'syncToken': syncToken,
        'syncOptions': syncOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential sync failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> exportCredentialsSDK({
    required List<String> credentialIds,
    required String exportFormat,
    Map<String, dynamic>? exportOptions,
  }) async {
    try {
      final result = await walletChannel.invokeMethod('exportCredentialsSDK', {
        'credentialIds': credentialIds,
        'exportFormat': exportFormat,
        'exportOptions': exportOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential export failed: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> importCredentialsSDK({
    required String credentialData,
    String? expectedFormat,
    Map<String, dynamic>? importOptions,
  }) async {
    try {
      final result = await walletChannel.invokeMethod('importCredentialsSDK', {
        'credentialData': credentialData,
        'expectedFormat': expectedFormat,
        'importOptions': importOptions ?? {},
      });

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'SDK credential import failed: ${e.message}',
        e.details,
      );
    }
  }
}

/// Riverpod provider for extended platform service
final spruceIdPlatformServiceExtendedProvider =
    Provider<ISpruceIdPlatformServiceExtended>((ref) {
      return SpruceIdPlatformServiceExtended();
    });
