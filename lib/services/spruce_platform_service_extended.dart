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
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../interfaces/spruce_interfaces_extended.dart';
import 'remote_holder_pairing_service.dart';
import 'verified_wallet_bridge.dart';
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
  final String? requestUri;
  final String clientId;
  final List<String> requiredClaims;
  // Storage IDs select opaque native review handles, never replacement tokens.
  final Map<String, String> credentials;
  final Set<String> nativeHandles;
  DateTime expiresAt;
  bool active = true;

  _PendingVerifiedPresentation({
    required this.requestUri,
    required this.clientId,
    required this.requiredClaims,
    required this.credentials,
    required this.expiresAt,
    required this.nativeHandles,
  });
}

/// Extended platform service implementation with SDK capabilities
/// Uses the refactored Android and iOS handlers with SDK integration
class SpruceIdPlatformServiceExtended extends SpruceIdPlatformService
    implements ISpruceIdPlatformServiceExtended {
  static final _instance = SpruceIdPlatformServiceExtended._internal(
    const RustVerifiedWalletBridge(),
    () => RemoteHolderPairingService(),
  );
  factory SpruceIdPlatformServiceExtended() => _instance;
  SpruceIdPlatformServiceExtended._internal(this._bridge, this._holderFactory)
    : super.protected();

  @visibleForTesting
  SpruceIdPlatformServiceExtended.withDependencies(
    VerifiedWalletBridge bridge,
    RemoteHolderPairingService Function() holderFactory,
  ) : this._internal(bridge, holderFactory);

  final VerifiedWalletBridge _bridge;
  final RemoteHolderPairingService Function() _holderFactory;

  // The unregistered holder SDK channel is retired. Live wallet paths use Rust.
  final Set<String> _presentationSessions = {};
  final Map<String, _PendingVerifiedPresentation>
  _pendingVerifiedPresentations = {};
  int _initiationEpoch = 0;

  // ========================
  // SDK-Enhanced OID4VC Operations
  // ========================

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
  }) async {
    final holder = _holderFactory();
    try {
      final publicJwk = await holder.publicJwkForPurpose(
        'presentation_signing',
      );
      final initialAuthority = await holder.fetchIssuerKeysJson();
      final prepared = await _bridge.prepareReceipt(
        offerUri: credentialOffer,
        txCode: pin,
        holderPublicJwkJson: jsonEncode(publicJwk),
        issuerSnapshotJson: initialAuthority,
      );
      final signature = await holder.signInput(
        purpose: 'presentation_signing',
        signingInput: prepared.signingInput,
      );
      final snapshot = await holder.fetchIssuerKeysJson();
      final responseId = await _bridge.completeReceipt(
        sessionId: prepared.sessionId,
        remoteSignature: signature,
        issuerSnapshotJson: snapshot,
      );
      final finalAuthority = await holder.fetchIssuerKeysJson();
      final receipt = await _bridge.finalizeReceipt(
        responseId: responseId,
        issuerSnapshotJson: finalAuthority,
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
    final epoch = ++_initiationEpoch;
    final holder = _holderFactory();
    try {
      final route = await _bridge.routePresentation(input: presentationRequest);
      if (route == 'mdoc') {
        throw UnsupportedError(
          'mDoc presentation requires a verified remote-KMS session',
        );
      }
      if (route != 'oid4vp') {
        throw StateError(
          'Native wallet returned an unsupported presentation route',
        );
      }
      await holder.renewIfDue();
      if (epoch != _initiationEpoch) {
        throw StateError('Presentation request superseded');
      }
      return await _initiateVerifiedPresentation(
        presentationRequest,
        holder,
        epoch,
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
    if (!_presentationSessions.remove(sessionId)) {
      throw StateError('Presentation selection session is unknown');
    }
    return await _completeVerifiedPresentation(
      sessionId,
      selectedCredentialId,
      selectedFields,
    );
  }

  Future<void> _cancelNative(String handle) async {
    try {
      await _bridge.cancelPresentation(sessionId: handle);
    } catch (_) {
      // Native sessions also expire independently. Never log handles/evidence.
      debugPrint('Could not retire native presentation session');
    }
  }

  Future<void> _releasePresentation(
    _PendingVerifiedPresentation pending,
  ) async {
    pending.active = false;
    final handles = pending.nativeHandles.toList();
    pending.nativeHandles.clear();
    await Future.wait(handles.map(_cancelNative));
  }

  @override
  Future<void> cancelOID4VPRequestSDK({required String sessionId}) async {
    _presentationSessions.remove(sessionId);
    final pending = _pendingVerifiedPresentations.remove(sessionId);
    if (pending != null) await _releasePresentation(pending);
  }

  static void _requireActive(_PendingVerifiedPresentation pending) {
    if (!pending.active || !pending.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw StateError('Presentation approval expired or cancelled');
    }
  }

  Future<Map<String, dynamic>> _initiateVerifiedPresentation(
    String input,
    RemoteHolderPairingService holder,
    int epoch,
  ) async {
    // These untrusted QR fields select only a governed record through the fixed
    // paired-device endpoint. No URL from the QR is fetched by Dart.
    final qr = Uri.tryParse(input);
    final parameters = qr?.queryParametersAll;
    if (input.length > 65536 ||
        qr == null ||
        qr.scheme != 'openid4vp' ||
        (qr.host.isNotEmpty && qr.host != "authorize") ||
        qr.hasPort ||
        qr.path.isNotEmpty ||
        qr.hasFragment ||
        qr.userInfo.isNotEmpty ||
        parameters == null ||
        parameters.values.any((values) => values.length != 1)) {
      throw StateError('A signed verifier request is required');
    }
    final clientId = parameters['client_id']?.single;
    if (clientId == null || clientId.isEmpty) {
      throw StateError('Verifier client ID is missing');
    }
    final managed = clientId.startsWith('decentralized_identifier:did:');
    final byValue = parameters.containsKey('request');
    final allowed = byValue
        ? {'client_id', 'request'}
        : {'client_id', 'request_uri', 'request_uri_method'};
    if ((managed && byValue) ||
        (!managed && clientId.contains(':')) ||
        parameters.keys.any((key) => !allowed.contains(key)) ||
        (!byValue && !parameters.containsKey('request_uri')) ||
        (parameters['request_uri_method']?.single ?? 'get') != 'get') {
      throw StateError('Unsupported verifier request transport');
    }
    final locator = managed ? parameters['request_uri']!.single : 'openid4vp://?${qr.query}';
    final ownerLocator = managed ? locator : null;
    for (final entry in _pendingVerifiedPresentations.entries.toList()) {
      if (!entry.value.expiresAt.isAfter(DateTime.now().toUtc())) {
        await cancelOID4VPRequestSDK(sessionId: entry.key);
      }
    }
    if (_pendingVerifiedPresentations.length >= 16) {
      await cancelOID4VPRequestSDK(
        sessionId: _pendingVerifiedPresentations.keys.first,
      );
    }
    final handles = <String>{};
    final pending = _PendingVerifiedPresentation(
      requestUri: ownerLocator,
      clientId: clientId,
      requiredClaims: [],
      credentials: {},
      nativeHandles: handles,
      expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
    );
    Map<String, dynamic>? authenticatedRequest;
    final matches = <Map<String, dynamic>>[];
    var handedToConsent = false;
    try {
      final governance = await holder.fetchVerifierAuthorityJson(
        clientId: clientId,
        requestUri: ownerLocator,
        deviceScope: ownerLocator == null,
      );
      final snapshot = await holder.fetchIssuerKeysJson();
      final publicJwk = jsonEncode(
        await holder.publicJwkForPurpose('presentation_signing'),
      );
      if (epoch != _initiationEpoch) {
        throw StateError('Presentation request superseded');
      }
      for (final stored in await WalletCredentialStore.getAll()) {
        if (!{'dc+sd-jwt', 'vc+sd-jwt', 'sd_jwt_vc'}.contains(stored.format)) {
          continue;
        }
        final token = _storedSdJwt(stored.rawJson);
        if (token == null) continue;
        late final String raw;
        try {
          raw = await _bridge.reviewCredential(
            requestUri: locator,
            governanceJson: governance,
            credential: token,
            issuerSnapshotJson: snapshot,
            holderPublicJwkJson: publicJwk,
          );
        } catch (_) {
          // Failed issuer/holder/type policy does not remove stored credentials
          // or suppress other valid candidates. No decoded fallback exists.
          if (epoch != _initiationEpoch) {
            throw StateError('Presentation request superseded');
          }
          continue;
        }
        if (raw.length > 768 * 1024) {
          throw StateError('Native consent response is too large');
        }
        final envelope = jsonDecode(raw);
        if (envelope is! Map<String, dynamic> ||
            envelope['session_id'] is! String ||
            !RegExp(
              r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
            ).hasMatch(envelope['session_id'] as String)) {
          throw StateError('Native consent handle is invalid');
        }
        final handle = envelope['session_id'] as String;
        // Register before checking staleness or parsing display fields so every
        // newly returned handle is retired if this callback loses its owner.
        if (!handles.add(handle)) {
          throw StateError('Duplicate native consent handle');
        }
        if (epoch != _initiationEpoch) {
          throw StateError('Presentation request superseded');
        }
        final expires = envelope['expires_at'] is String
            ? DateTime.tryParse(envelope['expires_at'] as String)?.toUtc()
            : null;
        if (expires == null ||
            !expires.isAfter(DateTime.now().toUtc()) ||
            expires.isAfter(
              DateTime.now().toUtc().add(const Duration(seconds: 60)),
            )) {
          throw StateError('Native consent response expired');
        }
        if (expires.isBefore(pending.expiresAt)) pending.expiresAt = expires;
        final request = envelope['request'];
        final review = envelope['credential'];
        if (request is! Map<String, dynamic> ||
            review is! Map<String, dynamic>) {
          throw StateError('Native consent response is invalid');
        }
        final claims = _authenticatedClaims(request, clientId);
        if (authenticatedRequest != null &&
            jsonEncode(authenticatedRequest) != jsonEncode(request)) {
          throw StateError('Authenticated presentation changed during review');
        }
        authenticatedRequest = request;
        pending.requiredClaims.clear();
        pending.requiredClaims.addAll(claims);
        if (review['issuer'] is! String ||
            review['credential_type'] is! String ||
            !{'dc+sd-jwt', 'vc+sd-jwt'}.contains(review['format']) ||
            review['always_shared'] is! Map<String, dynamic> ||
            review['protected_header'] is! Map<String, dynamic> ||
            !(review['always_shared'] as Map).values.every(
              (value) => value is String,
            ) ||
            !(review['protected_header'] as Map).values.every(
              (value) => value is String,
            )) {
          throw StateError('Verified consent projection is invalid');
        }
        pending.credentials[stored.id] = handle;
        matches.add({
          'id': stored.id,
          'type': review['credential_type'],
          'issuer': review['issuer'],
          'alwaysSharedClaims': review['always_shared'],
          'alwaysSharedHeader': review['protected_header'],
          'requestedFields': {'credential': List<String>.of(claims)},
        });
      }
      if (matches.isEmpty || authenticatedRequest == null) {
        throw StateError('No verified SD-JWT credential is available');
      }
      _requireActive(pending);
      if (epoch != _initiationEpoch) {
        throw StateError('Presentation request superseded');
      }
      final random = Random.secure();
      final sessionId = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      ).replaceAll('=', '');
      if (!_presentationSessions.add(sessionId)) {
        throw StateError('Presentation session collision');
      }
      _pendingVerifiedPresentations[sessionId] = pending;
      handedToConsent = true;
      throw UserSelectionRequiredException(
        sessionId: sessionId,
        matches: matches,
        requestDetails: {
          'verifier': authenticatedRequest['client_id'],
          'recipient': authenticatedRequest['response_uri'],
        },
      );
    } finally {
      if (!handedToConsent) await _releasePresentation(pending);
    }
  }

  static List<String> _authenticatedClaims(
    Map<String, dynamic> request,
    String clientId,
  ) {
    if (request['client_id'] != clientId ||
        request['nonce'] is! String ||
        (request['nonce'] as String).isEmpty ||
        request['request_digest'] is! String ||
        (request['request_digest'] as String).isEmpty ||
        request['query_type'] != 'dcql_query') {
      throw StateError('Authenticated presentation request is invalid');
    }
    final recipient = request['response_uri'] is String
        ? Uri.tryParse(request['response_uri'] as String)
        : null;
    if (recipient == null ||
        recipient.scheme != 'https' ||
        recipient.host.isEmpty ||
        recipient.userInfo.isNotEmpty ||
        recipient.hasFragment) {
      throw StateError('Authenticated presentation recipient is invalid');
    }
    final query = request['dcql_query_json'] is String
        ? jsonDecode(request['dcql_query_json'] as String)
        : null;
    if (query is! Map<String, dynamic> ||
        query['credentials'] is! List ||
        (query['credentials'] as List).length != 1) {
      throw StateError('Authenticated presentation query is unsupported');
    }
    final credential = (query['credentials'] as List).single;
    if (credential is! Map<String, dynamic> ||
        credential['id'] is! String ||
        (credential['id'] as String).isEmpty ||
        credential['format'] != 'dc+sd-jwt') {
      throw StateError('Authenticated presentation credential is unsupported');
    }
    // VCT and algorithm policy has already been enforced by native Core. Dart
    // extracts display paths only; it does not decide whether a token matches.
    final fields = credential['claims'] ?? [];
    if (fields is! List || fields.length > 64) {
      throw StateError('Authenticated disclosure fields are invalid');
    }
    final claims = <String>[];
    for (final field in fields) {
      if (field is! Map<String, dynamic> ||
          field['path'] is! List ||
          (field['path'] as List).length != 1 ||
          (field['path'] as List).single is! String) {
        throw StateError('Authenticated disclosure path is unsupported');
      }
      final name = (field['path'] as List).single as String;
      if (name.length > 256 ||
          !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name) ||
          claims.contains(name)) {
        throw StateError('Authenticated disclosure fields are invalid');
      }
      claims.add(name);
    }
    return claims;
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
    final pending = _pendingVerifiedPresentations[sessionId];
    if (pending == null) throw StateError('Presentation approval expired');
    RemoteHolderPairingService? holder;
    try {
      _requireActive(pending);
      final handle = pending.credentials[selectedCredentialId];
      if (handle == null) {
        throw StateError('Selected credential is unavailable');
      }
      if (selectedFields == null) {
        throw StateError('Presentation disclosures require explicit approval');
      }
      final selected = <String>[];
      for (final field in selectedFields) {
        if (!field.startsWith('credential/')) {
          throw StateError('Selected disclosure field is invalid');
        }
        selected.add(field.substring('credential/'.length));
      }
      if (selected.length != selected.toSet().length ||
          selected.length != pending.requiredClaims.length ||
          !selected.toSet().containsAll(pending.requiredClaims)) {
        throw StateError(
          'Selected disclosure does not match the approved request',
        );
      }
      for (final other in pending.nativeHandles.toList()) {
        if (other != handle) {
          pending.nativeHandles.remove(other);
          await _cancelNative(other);
        }
      }
      holder = _holderFactory();
      final governance = await holder.fetchVerifierAuthorityJson(
        clientId: pending.clientId,
        requestUri: pending.requestUri,
        deviceScope: pending.requestUri == null,
      );
      final issuer = await holder.fetchIssuerKeysJson();
      final publicJwk = jsonEncode(
        await holder.publicJwkForPurpose('presentation_signing'),
      );
      _requireActive(pending);
      final prepared = await _bridge.preparePresentation(
        sessionId: handle,
        claimsToDisclose: selected,
        governanceJson: governance,
        issuerSnapshotJson: issuer,
        holderPublicJwkJson: publicJwk,
      );
      pending.nativeHandles.remove(handle);
      pending.nativeHandles.add(prepared.sessionId);
      _requireActive(pending);
      final signature = await holder.signInput(
        purpose: 'presentation_signing',
        signingInput: prepared.signingInput,
      );
      _requireActive(pending);
      // Signing may overlap revocation, bearer rotation or key replacement.
      // Fetch all evidence again after the remote result; native compares it
      // to the frozen scope and reauthenticates the retained original request.
      final completionGovernance = await holder.fetchVerifierAuthorityJson(
        clientId: pending.clientId,
        requestUri: pending.requestUri,
        deviceScope: pending.requestUri == null,
      );
      final completionIssuer = await holder.fetchIssuerKeysJson();
      final completionHolder = jsonEncode(
        await holder.publicJwkForPurpose('presentation_signing'),
      );
      _requireActive(pending);
      final response = await _bridge.completePresentation(
        sessionId: prepared.sessionId,
        remoteSignature: signature,
        governanceJson: completionGovernance,
        issuerSnapshotJson: completionIssuer,
        holderPublicJwkJson: completionHolder,
      );
      _requireActive(pending);
      if (!response.ok) {
        throw StateError(
          response.errorDescription ?? 'Verifier rejected presentation',
        );
      }
      return {'ok': true, 'redirect_uri': response.redirectUri};
    } finally {
      _pendingVerifiedPresentations.remove(sessionId);
      await _releasePresentation(pending);
      holder?.close();
    }
  }

  // ========================
  // Advanced Credential Operations
  // ========================

  @override
  Future<List<Map<String, dynamic>>> batchProcessCredentialsSDK({
    required List<Map<String, dynamic>> operations,
  }) async {
    throw UnsupportedError(
      'batchProcessCredentialsSDK requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(
    String credentialId,
  ) async {
    throw UnsupportedError(
      'getCredentialCapabilitiesSDK requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> validateCredentialSDK({
    required Map<String, dynamic> credential,
    String? schemaId,
    List<String>? policies,
  }) async {
    throw UnsupportedError(
      'validateCredentialSDK requires a verified remote-KMS flow',
    );
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
  }) async {
    throw UnsupportedError(
      'createAdvancedSdJwtSDK requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> presentSdJwtSDK({
    required String sdJwt,
    required Map<String, dynamic> disclosureRequest,
    required String challenge,
  }) async {
    throw UnsupportedError(
      'presentSdJwtSDK requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> verifySdJwtPresentationSDK({
    required String presentation,
    required List<String> requiredClaims,
    List<String>? policies,
  }) async {
    throw UnsupportedError(
      'SD-JWT presentation verification requires a trusted Rust verifier',
    );
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
    throw UnsupportedError(
      'mDoc initialization requires a verified remote-KMS session',
    );
  }

  @override
  Future<Map<String, dynamic>> handleMdocOid4vpRequestSDK({
    required String requestUrl,
  }) async {
    throw UnsupportedError(
      'mDoc OID4VP requires a verified remote-KMS session',
    );
  }

  @override
  Future<Map<String, dynamic>> createMdocPresentationSDK({
    required String docType,
    required List<String> requestedAttributes,
    Map<String, dynamic>? ageVerificationOptions,
    List<String>? hiddenAttributes,
  }) async {
    throw UnsupportedError(
      'createMdocPresentationSDK requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> establishMdocSessionSDK({
    required Map<String, dynamic> sessionRequest,
    Map<String, dynamic>? securityOptions,
  }) async {
    throw UnsupportedError(
      'establishMdocSessionSDK requires a verified remote-KMS flow',
    );
  }

  // ========================
  // Credential Lifecycle Management
  // ========================

  @override
  Future<Stream<Map<String, dynamic>>> monitorCredentialStatusSDK(
    String credentialId,
  ) async {
    throw UnsupportedError(
      'Credential monitoring requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> refreshCredentialSDK({
    required String credentialId,
    Map<String, dynamic>? refreshOptions,
  }) async {
    throw UnsupportedError(
      'refreshCredentialSDK requires a verified remote-KMS flow',
    );
  }

  @override
  Future<Map<String, dynamic>> backupCredentialsSDK({
    List<String>? credentialIds,
    required String backupPassphrase,
    Map<String, dynamic>? backupOptions,
  }) async {
    throw UnsupportedError(
      'Credential backup requires verified remote-KMS custody',
    );
  }

  @override
  Future<Map<String, dynamic>> restoreCredentialsSDK({
    required String backupData,
    required String backupPassphrase,
    Map<String, dynamic>? restoreOptions,
  }) async {
    throw UnsupportedError(
      'Credential restore requires verified remote-KMS custody',
    );
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
    throw UnsupportedError(
      'Credential sync requires verified remote-KMS custody',
    );
  }

  @override
  Future<Map<String, dynamic>> exportCredentialsSDK({
    required List<String> credentialIds,
    required String exportFormat,
    Map<String, dynamic>? exportOptions,
  }) async {
    throw UnsupportedError(
      'Credential export requires verified remote-KMS custody',
    );
  }

  @override
  Future<Map<String, dynamic>> importCredentialsSDK({
    required String credentialData,
    String? expectedFormat,
    Map<String, dynamic>? importOptions,
  }) async {
    throw UnsupportedError(
      'Credential import requires cryptographic verification and remote-KMS custody',
    );
  }
}

/// Riverpod provider for extended platform service
final spruceIdPlatformServiceExtendedProvider =
    Provider<ISpruceIdPlatformServiceExtended>((ref) {
      return SpruceIdPlatformServiceExtended();
    });
