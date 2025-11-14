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

import '../../../model/processor_result.dart';
import '../../../model/tokens/token.dart';
import '../../../model/tokens/hotp_token.dart';
import '../../../model/enums/algorithms.dart';
import '../../../model/enums/token_types.dart';
import '../../../oid4vc_client.dart';
import '../../../utils/logger.dart';
import '../../../utils/object_validator.dart';
import '../../../utils/riverpod/riverpod_providers/generated_providers/token_notifier.dart';
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
          return await _handleCredentialOffer(uri, fromInit);
        case 'openid4vp':
          return await _handlePresentationRequest(uri, fromInit);
        case 'openid-credential':
          return await _handleCredentialImport(uri, fromInit);
        default:
          return null;
      }
    } catch (e) {
      Logger.error('Error processing OID4VC URI', error: e);
      return [
        ProcessorResult.failed(
          (l) => l.invalidLink('OID4VC'),
          resultHandlerType: resultHandlerType,
        ),
      ];
    }
  }

  Future<List<ProcessorResult<Token>>?> _handleCredentialOffer(
    Uri uri,
    bool fromInit,
  ) async {
    final client = OID4VCClient(baseUrl: 'https://issuer.example.com');
    final offer = await client.parseCredentialOffer(uri.toString());

    if (offer == null) {
      return [
        ProcessorResult.failed(
          (l) => l.invalidLink('OID4VC Credential Offer'),
          resultHandlerType: resultHandlerType,
        ),
      ];
    }

    // Create a placeholder HOTP token for OID4VC credentials
    // In a real implementation, this would be a proper OID4VCToken class
    final token = HOTPToken(
      label: 'OID4VC Credential',
      issuer: offer.credentialIssuer,
      id: 'oid4vc_${DateTime.now().millisecondsSinceEpoch}',
      algorithm: Algorithms.SHA1,
      digits: 6,
      counter: 0,
      secret: 'PLACEHOLDER', // pragma: allowlist secret
      type: TokenTypes.HOTP.name,
    );

    return [
      ProcessorResult.success(token, resultHandlerType: resultHandlerType),
    ];
  }

  Future<List<ProcessorResult<Token>>?> _handlePresentationRequest(
    Uri uri,
    bool fromInit,
  ) async {
    // Handle OID4VP presentation requests
    Logger.info('Handling OID4VP presentation request');

    final requestParam = uri.queryParameters['request'];
    if (requestParam == null) return null;

    // TODO: Process presentation request
    // This would typically trigger a credential selection UI
    // rather than creating a new token

    return [];
  }

  Future<List<ProcessorResult<Token>>?> _handleCredentialImport(
    Uri uri,
    bool fromInit,
  ) async {
    // Handle direct credential imports
    Logger.info('Handling direct credential import');

    // TODO: Process credential data
    return [];
  }
}
