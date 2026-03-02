/*
 * privacyIDEA Authenticator
 *
 * Author: Adam Burdett <adam.burdett@netknights.it>
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

import '../../../model/processor_result.dart';
import '../../../model/tokens/token.dart';
import '../../../providers/card_state_provider.dart';
import '../../../services/oid4vc_service.dart';
import '../../../services/wallet_credential_store.dart';
import '../../../services/wallet_key_service.dart';
import '../../../utils/globals.dart';
import '../../../utils/logger.dart';
import '../../../utils/object_validator.dart';
import '../../../utils/riverpod/riverpod_providers/generated_providers/token_notifier.dart';
import '../../../utils/view_utils.dart';
import 'token_import_scheme_processor_interface.dart';

class OID4VCSchemeProcessor extends TokenImportSchemeProcessor {
  static ObjectValidator<TokenNotifier> get resultHandlerType =>
      TokenImportSchemeProcessor.resultHandlerType;

  const OID4VCSchemeProcessor();

  @override
  Set<String> get supportedSchemes => {
    'openid-credential-offer',
    'openid4vp',
    'openid-credential',
  };

  @override
  Future<List<ProcessorResult<Token>>?> processUri(
    Uri uri, {
    bool fromInit = false,
  }) async {
    if (!supportedSchemes.contains(uri.scheme)) return null;

    Logger.info('Processing OID4VC URI: ${uri.scheme}');

    try {
      switch (uri.scheme) {
        case 'openid-credential-offer':
          return await _handleCredentialOffer(uri);
        case 'openid4vp':
          return await _handlePresentationRequest(uri);
        case 'openid-credential':
          return await _handleCredentialImport(uri);
        default:
          return null;
      }
    } catch (e, st) {
      Logger.error('Error processing OID4VC URI', error: e, stackTrace: st);
      return [
        ProcessorResult.failed(
          (l) => l.invalidLink('OID4VC'),
          resultHandlerType: resultHandlerType,
        ),
      ];
    }
  }

  // ===========================================================================
  // OID4VCI — Credential offer (pre-auth + auth-code)
  // ===========================================================================

  Future<List<ProcessorResult<Token>>> _handleCredentialOffer(Uri uri) async {
    const svc = OID4VCService();

    // 1. Parse the credential offer URI ----------------------------------------
    final CredentialOffer offer;
    try {
      offer = await svc.parseCredentialOffer(uri.toString());
    } catch (e) {
      Logger.error('Failed to parse credential offer', error: e);
      return [
        ProcessorResult.failed(
          (l) => l.invalidLink('OID4VC Credential Offer'),
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // 2. Fetch issuer metadata --------------------------------------------------
    final IssuerMetadata meta;
    try {
      meta = await svc.fetchIssuerMetadata(offer.credentialIssuer);
    } catch (e) {
      Logger.error('Failed to fetch issuer metadata', error: e);
      return [
        ProcessorResult.failed(
          (_) => 'Failed to fetch issuer metadata. Check your connection.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // 3. Choose flow -----------------------------------------------------------
    if (offer.preAuthorizedCode != null) {
      return _runPreAuthFlow(svc, offer, meta);
    }

    if (offer.issuerState != null) {
      // Auth-code flow requires an in-app browser; not yet supported.
      Logger.warning(
        'OID4VCI auth-code flow not yet implemented; '
        'issuer_state=${offer.issuerState}',
      );
      return [
        ProcessorResult.failed(
          (_) => 'Authorization code flow is not yet supported.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // No recognized grant type
    return [
      ProcessorResult.failed(
        (l) => l.invalidLink('OID4VCI grant type'),
        resultHandlerType: resultHandlerType,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Pre-authorized code flow
  // ---------------------------------------------------------------------------

  Future<List<ProcessorResult<Token>>> _runPreAuthFlow(
    OID4VCService svc,
    CredentialOffer offer,
    IssuerMetadata meta,
  ) async {
    // 3a. Exchange pre-auth code for token ------------------------------------
    final Oid4vciTokenResponse token;
    try {
      token = await svc.exchangePreAuthToken(
        meta.tokenEndpoint,
        offer.preAuthorizedCode!,
        // txCode (user PIN) — TODO: prompt user via UI if txCodeRequired
        txCode: null,
      );
    } catch (e) {
      Logger.error('Token exchange failed', error: e);
      return [
        ProcessorResult.failed(
          (_) => 'Token exchange failed. Please try again.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // 3b. Get / create the wallet holder key ----------------------------------
    HolderKeyInfo holderKey;
    try {
      holderKey = await WalletKeyService.getOrCreateHolderKey();
    } catch (e) {
      Logger.error('Failed to get holder key', error: e);
      return [
        ProcessorResult.failed(
          (_) => 'Failed to generate wallet key. Please try again.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // 3c. Create proof JWT (only when issuer returned a c_nonce) --------------
    String? proofJwt;
    if (token.cNonce != null) {
      try {
        proofJwt = await svc.createProofJwtAsync(
          holderKid: holderKey.kid,
          cNonce: token.cNonce!,
          issuerUrl: offer.credentialIssuer,
          jwkJson: holderKey.privateJwkJson,
        );
      } catch (e) {
        Logger.error('Failed to create proof JWT', error: e);
        return [
          ProcessorResult.failed(
            (_) => 'Failed to create credential proof. Please try again.',
            resultHandlerType: resultHandlerType,
          ),
        ];
      }
    }

    // 3d. Request credential for each configuration ID -----------------------
    int stored = 0;
    for (final configId in offer.credentialConfigurationIds) {
      // Determine format from issuer metadata — default to mso_mdoc
      final format = _credentialFormat(meta, configId);

      final Oid4vciCredentialResponse resp;
      try {
        resp = await svc.requestCredential(
          credentialEndpoint: meta.credentialEndpoint,
          accessToken: token.accessToken,
          credentialFormat: format,
          credentialConfigurationId: configId,
          proofJwt: proofJwt ?? '',
        );
      } catch (e) {
        Logger.error('Credential request failed for $configId', error: e);
        continue; // Try remaining configurations
      }

      // 3e. Persist credential ------------------------------------------------
      if (resp.credential != null) {
        try {
          final id = '${offer.credentialIssuer}/$configId/${DateTime.now().millisecondsSinceEpoch}';
          await WalletCredentialStore.store(
            StoredCredential(
              id: id,
              format: resp.format ?? format,
              issuer: offer.credentialIssuer,
              types: [configId],
              rawJson: jsonEncode({
                'credential': resp.credential,
                'format': resp.format ?? format,
                'c_nonce': resp.cNonce,
              }),
              issuedAt: DateTime.now(),
            ),
          );
          stored++;
          Logger.info('Stored credential for $configId');
        } catch (e) {
          Logger.error('Failed to store credential $configId', error: e);
        }
      } else if (resp.transactionId != null) {
        // Deferred issuance — credential not immediately available
        Logger.info('Deferred issuance for $configId, txId=${resp.transactionId}');
        // TODO: poll the deferred endpoint
      }
    }

    if (stored > 0) {
      showSuccessStatusMessage(
        message: (_) => 'Added $stored credential${stored == 1 ? '' : 's'} to wallet.',
      );
      // Trigger wallet card UI refresh so the new credential appears immediately.
      globalRef?.invalidate(cardStateProvider);
    } else {
      return [
        ProcessorResult.failed(
          (_) => 'Failed to receive credentials from issuer.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // No OTP tokens to add — the credential is stored in WalletCredentialStore.
    return [];
  }

  // ===========================================================================
  // OID4VP — Presentation request
  // ===========================================================================

  Future<List<ProcessorResult<Token>>> _handlePresentationRequest(Uri uri) async {
    const svc = OID4VCService();

    // 1. Parse the presentation request ---------------------------------------
    final PresentationRequest request;
    try {
      request = await svc.parsePresentationRequest(uri.toString());
    } catch (e) {
      Logger.error('Failed to parse presentation request', error: e);
      return [
        ProcessorResult.failed(
          (l) => l.invalidLink('OID4VP Presentation Request'),
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // 2. Load available credentials -------------------------------------------
    final List<StoredCredential> creds;
    try {
      creds = await WalletCredentialStore.getAll();
    } catch (e) {
      Logger.error('Failed to load credentials for presentation', error: e);
      return [
        ProcessorResult.failed(
          (_) => 'Failed to load credentials from wallet.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    if (creds.isEmpty) {
      return [
        ProcessorResult.failed(
          (_) => 'No credentials available in wallet for this request.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // 3. Build credentials JSON (array of raw credential strings) -------------
    //    The Rust layer matches credentials to the presentation definition.
    final credentialsJson = jsonEncode(
      creds.map((c) {
        final raw = jsonDecode(c.rawJson) as Map<String, dynamic>;
        return raw['credential'] ?? c.rawJson;
      }).toList(),
    );

    // 4. Submit presentation --------------------------------------------------
    final PresentationResult result;
    try {
      result = await svc.buildAndSubmitPresentation(
        responseUri: request.responseUri,
        presentationDefinitionJson: request.presentationDefinitionJson,
        credentialsJson: credentialsJson,
      );
    } catch (e) {
      Logger.error('Presentation submission failed', error: e);
      return [
        ProcessorResult.failed(
          (_) => 'Presentation submission failed. Please try again.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    if (result.ok) {
      showSuccessStatusMessage(
        message: (_) => 'Presentation submitted successfully.',
      );
      return [];
    } else {
      Logger.error(
        'Presentation rejected: ${result.error} — ${result.errorDescription}',
      );
      return [
        ProcessorResult.failed(
          (_) => 'Presentation rejected: ${result.error ?? 'unknown error'}.',
          resultHandlerType: resultHandlerType,
        ),
      ];
    }
  }

  // ===========================================================================
  // Direct credential import
  // ===========================================================================

  Future<List<ProcessorResult<Token>>> _handleCredentialImport(Uri uri) async {
    // openid-credential:// carries raw credential data in the query params
    Logger.info('Handling direct credential import');
    // TODO: implement direct credential import
    return [];
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// Resolve the credential format for [configId] from issuer metadata.
  ///
  /// Falls back to `mso_mdoc` if the configuration cannot be parsed.
  String _credentialFormat(IssuerMetadata meta, String configId) {
    try {
      final configs = jsonDecode(meta.credentialConfigurationsJson)
          as Map<String, dynamic>;
      final cfg = configs[configId] as Map<String, dynamic>?;
      return (cfg?['format'] as String?) ?? 'mso_mdoc';
    } catch (_) {
      return 'mso_mdoc';
    }
  }
}
