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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../mmf/credential_transport.dart';
import '../../interfaces/spruce_interfaces.dart';
import '../../utils/oid4vci_offer_uri.dart';
import '../../utils/spruce_channels.dart';
import '../../utils/logger.dart';

/// SpruceID-backed implementation of ICredentialTransport.
///
/// Handles OID4VCI/VP protocol flows using SpruceID platform services.
/// This is transport-only - credential parsing/validation is done by Marty Rust layer.
class SpruceCredentialTransport implements ICredentialTransport {
  // ignore: unused_field - reserved for future direct service calls
  final ISpruceIdPlatformService _platformService;
  final MethodChannel _walletChannel;
  final MethodChannel _mdocChannel;

  SpruceCredentialTransport({
    required ISpruceIdPlatformService platformService,
    MethodChannel? walletChannel,
    MethodChannel? mdocChannel,
  }) : _platformService = platformService,
       _walletChannel =
           walletChannel ?? const MethodChannel(SpruceIdChannels.wallet),
       _mdocChannel = mdocChannel ?? const MethodChannel(SpruceIdChannels.mdoc);

  // ============================================================================
  // OID4VCI - Credential Issuance
  // ============================================================================

  @override
  Future<IssuanceSession> initiateIssuance(String credentialOfferUri) async {
    try {
      final normalizedOfferUri = normalizeOid4vciCredentialOfferUri(
        credentialOfferUri,
      );
      final result = await _walletChannel.invokeMethod<Map<dynamic, dynamic>>(
        'initiateIssuance',
        {'credentialOfferUri': normalizedOfferUri},
      );

      if (result == null) {
        throw Exception('No response from platform');
      }

      return IssuanceSession(
        sessionId: result['sessionId'] as String? ?? '',
        issuerUrl: result['issuerUrl'] as String? ?? '',
        authorizationEndpoint: result['authorizationEndpoint'] as String? ?? '',
        tokenEndpoint: result['tokenEndpoint'] as String? ?? '',
        credentialEndpoint: result['credentialEndpoint'] as String? ?? '',
        credentialTypes:
            (result['credentialTypes'] as List<dynamic>?)?.cast<String>() ?? [],
        codeVerifier: result['codeVerifier'] as String? ?? '',
        state: result['state'] as String? ?? '',
      );
    } on PlatformException catch (e) {
      Logger.error('Failed to initiate issuance', error: e);
      rethrow;
    }
  }

  @override
  Future<TokenResponse> completeAuthorization({
    required IssuanceSession session,
    required String authorizationCode,
  }) async {
    try {
      final result = await _walletChannel
          .invokeMethod<Map<dynamic, dynamic>>('completeAuthorization', {
            'sessionId': session.sessionId,
            'authorizationCode': authorizationCode,
            'codeVerifier': session.codeVerifier,
            'tokenEndpoint': session.tokenEndpoint,
          });

      if (result == null) {
        throw Exception('No response from platform');
      }

      return TokenResponse(
        accessToken: result['accessToken'] as String? ?? '',
        tokenType: result['tokenType'] as String? ?? 'Bearer',
        expiresIn: result['expiresIn'] as int?,
        refreshToken: result['refreshToken'] as String?,
        cNonce: result['c_nonce'] as String?,
        cNonceExpiresIn: result['c_nonce_expires_in'] as int?,
      );
    } on PlatformException catch (e) {
      Logger.error('Failed to complete authorization', error: e);
      rethrow;
    }
  }

  @override
  Future<CredentialResponse> requestCredential({
    required IssuanceSession session,
    required TokenResponse tokens,
    required String credentialType,
    Uint8List? proofJwt,
  }) async {
    try {
      final result = await _walletChannel
          .invokeMethod<Map<dynamic, dynamic>>('requestCredential', {
            'sessionId': session.sessionId,
            'accessToken': tokens.accessToken,
            'credentialEndpoint': session.credentialEndpoint,
            'credentialType': credentialType,
            if (proofJwt != null) 'proofJwt': base64Encode(proofJwt),
            if (tokens.cNonce != null) 'c_nonce': tokens.cNonce,
          });

      if (result == null) {
        throw Exception('No response from platform');
      }

      return CredentialResponse(
        format: result['format'] as String? ?? 'unknown',
        credential: result['credential'],
        cNonce: result['c_nonce'] as String?,
        transactionId: result['transaction_id'] as String?,
      );
    } on PlatformException catch (e) {
      Logger.error('Failed to request credential', error: e);
      rethrow;
    }
  }

  @override
  Future<List<CredentialResponse>> requestBatchCredentials({
    required IssuanceSession session,
    required TokenResponse tokens,
    required List<String> credentialTypes,
    Uint8List? proofJwt,
  }) async {
    // Request credentials one by one
    final responses = <CredentialResponse>[];
    TokenResponse currentTokens = tokens;

    for (final type in credentialTypes) {
      final response = await requestCredential(
        session: session,
        tokens: currentTokens,
        credentialType: type,
        proofJwt: proofJwt,
      );
      responses.add(response);

      // Update nonce if provided
      if (response.cNonce != null) {
        currentTokens = TokenResponse(
          accessToken: currentTokens.accessToken,
          tokenType: currentTokens.tokenType,
          expiresIn: currentTokens.expiresIn,
          refreshToken: currentTokens.refreshToken,
          cNonce: response.cNonce,
          cNonceExpiresIn: currentTokens.cNonceExpiresIn,
        );
      }
    }

    return responses;
  }

  // ============================================================================
  // OID4VP - Credential Presentation
  // ============================================================================

  @override
  Future<PresentationRequest> parsePresentationRequest(
    String requestUri,
  ) async {
    try {
      final result = await _walletChannel.invokeMethod<Map<dynamic, dynamic>>(
        'parsePresentationRequest',
        {'requestUri': requestUri},
      );

      if (result == null) {
        throw Exception('No response from platform');
      }

      final requestedCredentials = <RequestedCredential>[];
      final rawRequested = result['requestedCredentials'] as List<dynamic>?;
      if (rawRequested != null) {
        for (final item in rawRequested) {
          if (item is Map) {
            requestedCredentials.add(
              RequestedCredential(
                type: item['type'] as String? ?? '',
                requiredAttributes:
                    (item['requiredAttributes'] as List<dynamic>?)
                        ?.cast<String>() ??
                    [],
                optionalAttributes:
                    (item['optionalAttributes'] as List<dynamic>?)
                        ?.cast<String>() ??
                    [],
                formats: (item['formats'] as List<dynamic>?)?.cast<String>(),
              ),
            );
          }
        }
      }

      return PresentationRequest(
        id: result['id'] as String? ?? '',
        verifierId: result['verifierId'] as String? ?? '',
        verifierName: result['verifierName'] as String?,
        requestedCredentials: requestedCredentials,
        responseUri: result['responseUri'] as String? ?? '',
        nonce: result['nonce'] as String? ?? '',
        presentationDefinition:
            result['presentationDefinition'] as Map<String, dynamic>?,
        dcqlQuery: result['dcqlQuery'] as Map<String, dynamic>?,
        queryType:
          result['queryType'] as String? ??
          (result['dcqlQuery'] != null
            ? 'dcql_query'
            : (result['presentationDefinition'] != null
              ? 'presentation_definition'
              : null)),
      );
    } on PlatformException catch (e) {
      Logger.error('Failed to parse presentation request', error: e);
      rethrow;
    }
  }

  @override
  Future<PresentationResponse> submitPresentation({
    required PresentationRequest request,
    required List<CredentialSubmission> credentials,
    Uint8List? holderKeyProof,
  }) async {
    try {
      final credentialsJson = credentials
          .map(
            (c) => {
              'format': c.format,
              'credentialData': c.credentialData,
              if (c.disclosedAttributes != null)
                'disclosedAttributes': c.disclosedAttributes,
            },
          )
          .toList();

      final result = await _walletChannel
          .invokeMethod<Map<dynamic, dynamic>>('submitPresentation', {
            'requestId': request.id,
            'responseUri': request.responseUri,
            'nonce': request.nonce,
            'credentials': credentialsJson,
            if (holderKeyProof != null)
              'holderKeyProof': base64Encode(holderKeyProof),
          });

      if (result == null) {
        throw Exception('No response from platform');
      }

      return PresentationResponse(
        accepted: result['accepted'] as bool? ?? false,
        redirectUrl: result['redirectUrl'] as String?,
        error: result['error'] as String?,
      );
    } on PlatformException catch (e) {
      Logger.error('Failed to submit presentation', error: e);
      rethrow;
    }
  }

  // ============================================================================
  // BLE/NFC Transport (ISO 18013-5)
  // ============================================================================

  @override
  Future<void> startBlePresentation({
    required Uint8List deviceEngagement,
    required Function(PresentationRequest) onRequest,
    required Function(String) onError,
  }) async {
    try {
      await _mdocChannel.invokeMethod('startBlePresentation', {
        'deviceEngagement': base64Encode(deviceEngagement),
      });

      // Set up event channel for incoming requests
      // TODO: Implement event channel handling
      Logger.info('BLE presentation started');
    } on PlatformException catch (e) {
      Logger.error('Failed to start BLE presentation', error: e);
      onError(e.message ?? 'Unknown error');
    }
  }

  @override
  Future<void> stopBlePresentation() async {
    try {
      await _mdocChannel.invokeMethod('stopBlePresentation');
    } on PlatformException catch (e) {
      Logger.error('Failed to stop BLE presentation', error: e);
    }
  }

  @override
  Future<bool> isNfcAvailable() async {
    try {
      final result = await _mdocChannel.invokeMethod<Map<dynamic, dynamic>>(
        'isNfcAvailable',
      );
      return result?['available'] as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> startNfcReader({
    required Function(Uint8List) onDeviceEngagement,
    required Function(String) onError,
  }) async {
    try {
      await _mdocChannel.invokeMethod('startNfcReader');
      // TODO: Implement event channel handling
      Logger.info('NFC reader started');
    } on PlatformException catch (e) {
      Logger.error('Failed to start NFC reader', error: e);
      onError(e.message ?? 'Unknown error');
    }
  }

  @override
  Future<void> stopNfcReader() async {
    try {
      await _mdocChannel.invokeMethod('stopNfcReader');
    } on PlatformException catch (e) {
      Logger.error('Failed to stop NFC reader', error: e);
    }
  }
}
