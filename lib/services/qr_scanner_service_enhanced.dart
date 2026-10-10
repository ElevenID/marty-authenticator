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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/marty_bridge.dart/api.dart' as rust_api;
import '../utils/logger.dart';

typedef NativeQrParser =
    Future<rust_api.FrbWalletQrInput?> Function({required String rawData});

final qrScannerServiceEnhancedProvider = Provider<QRScannerServiceEnhanced>(
  (ref) => QRScannerServiceEnhanced(),
);

/// Classifies supported QR protocols using the native Rust wallet parser.
/// Parsing never asserts issuer trust, holder custody, or offer compatibility.
class QRScannerServiceEnhanced {
  QRScannerServiceEnhanced({NativeQrParser? parseNativeQr})
    : _parseNativeQr = parseNativeQr ?? rust_api.walletValidateQrInput;

  final NativeQrParser _parseNativeQr;

  Future<ProcessedQRResult> processQRCode(String rawData) async {
    try {
      final native = await _parseNativeQr(rawData: rawData);
      if (native == null) {
        return ProcessedQRResult.error(
          'Unsupported QR content was not parsed by the native wallet',
        );
      }
      final content = jsonDecode(native.parsedContentJson);
      if (content is! Map<String, dynamic>) {
        throw const FormatException('Native QR content is invalid');
      }
      final type = switch (native.kind) {
        'credential_offer' => QRType.credentialOffer,
        'presentation_request' => QRType.presentationRequest,
        'mdoc_device_engagement' => QRType.mdocDeviceEngagement,
        'push_registration' => QRType.pushRegistration,
        'remote_pairing' => QRType.remotePairing,
        _ => throw const FormatException('Native QR kind is unsupported'),
      };
      final format = switch (type) {
        QRType.pushRegistration || QRType.remotePairing => QRFormat.url,
        QRType.mdocDeviceEngagement => QRFormat.raw,
        _ => QRFormat.openid,
      };
      return ProcessedQRResult.success(
        enrichedResult: EnrichedQRResult(
          validatedResult: ValidatedQRResult(
            parsedData: ParsedQRData(
              type: type,
              format: format,
              rawData: native.normalized,
              parsedContent: content,
              metadata: {
                'native_parsed': true,
                'requires_external_provider': native.requiresExternalProvider,
              },
            ),
            isValid: true,
          ),
        ),
      );
    } catch (_) {
      Logger.warning(
        'Native QR parsing failed',
        name: 'QRScannerServiceEnhanced',
      );
      return ProcessedQRResult.error('Unable to parse QR content');
    }
  }
}

enum QRType {
  presentationRequest,
  credentialOffer,
  mdocDeviceEngagement,
  pushRegistration,
  remotePairing,
  unknown,
}

enum QRFormat { url, openid, raw }

class ParsedQRData {
  final QRType type;
  final QRFormat format;
  final String rawData;
  final Map<String, dynamic> parsedContent;
  final Map<String, dynamic> metadata;

  const ParsedQRData({
    required this.type,
    required this.format,
    required this.rawData,
    required this.parsedContent,
    required this.metadata,
  });
}

/// Public offer details returned by the Rust parser for user review.
class CredentialOfferPreview {
  final String offerUri;
  final String issuer;
  final List<String> credentialConfigurationIds;

  const CredentialOfferPreview({
    required this.offerUri,
    required this.issuer,
    required this.credentialConfigurationIds,
  });

  factory CredentialOfferPreview.fromParsed(ParsedQRData parsed) {
    if (parsed.type != QRType.credentialOffer ||
        parsed.metadata['native_parsed'] != true ||
        parsed.metadata['requires_external_provider'] == true) {
      throw const FormatException(
        'Credential offer requires a supported native parser',
      );
    }
    final content = parsed.parsedContent;
    final uri = content['offer_uri'];
    final issuer = content['credential_issuer'];
    final ids = content['credential_configuration_ids'];
    if (uri is! String ||
        uri.isEmpty ||
        issuer is! String ||
        issuer.isEmpty ||
        ids is! List ||
        ids.isEmpty ||
        ids.any((id) => id is! String || id.isEmpty)) {
      throw const FormatException('Credential offer review data is invalid');
    }
    return CredentialOfferPreview(
      offerUri: uri,
      issuer: issuer,
      credentialConfigurationIds: List<String>.unmodifiable(ids.cast<String>()),
    );
  }
}

class ValidatedQRResult {
  final ParsedQRData parsedData;
  final bool isValid;

  const ValidatedQRResult({required this.parsedData, required this.isValid});
}

class EnrichedQRResult {
  final ValidatedQRResult validatedResult;

  const EnrichedQRResult({required this.validatedResult});
}

class ProcessedQRResult {
  final bool isSuccess;
  final String? errorMessage;
  final EnrichedQRResult? enrichedResult;

  const ProcessedQRResult._({
    required this.isSuccess,
    this.errorMessage,
    this.enrichedResult,
  });

  factory ProcessedQRResult.success({
    required EnrichedQRResult enrichedResult,
  }) => ProcessedQRResult._(isSuccess: true, enrichedResult: enrichedResult);

  factory ProcessedQRResult.error(String errorMessage) =>
      ProcessedQRResult._(isSuccess: false, errorMessage: errorMessage);
}
