import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/services/qr_scanner_service_enhanced.dart';

void main() {
  test(
    'Rust-parsed offer remains a review request, not a compatibility claim',
    () async {
      const offerUri = 'openid-credential-offer://approved';
      final service = QRScannerServiceEnhanced(
        parseNativeQr: ({required rawData}) async {
          expect(rawData, offerUri);
          return const FrbWalletQrInput(
            kind: 'credential_offer',
            normalized: offerUri,
            parsedContentJson:
                '{"offer_uri":"openid-credential-offer://approved","credential_issuer":"https://issuer.example","credential_configuration_ids":["ExampleIdentity"]}',
            requiresExternalProvider: false,
          );
        },
      );

      final result = await service.processQRCode(offerUri);
      expect(result.isSuccess, isTrue);
      final parsed = result.enrichedResult!.validatedResult.parsedData;
      expect(parsed.type, QRType.credentialOffer);
      expect(
        parsed.parsedContent['credential_issuer'],
        'https://issuer.example',
      );
      expect(parsed.metadata['native_parsed'], isTrue);
      final preview = CredentialOfferPreview.fromParsed(parsed);
      expect(preview.offerUri, offerUri);
      expect(preview.issuer, 'https://issuer.example');
      expect(preview.credentialConfigurationIds, ['ExampleIdentity']);
    },
  );

  test('unrecognized and malformed native QR output fail closed', () async {
    final unknown = QRScannerServiceEnhanced(
      parseNativeQr: ({required rawData}) async => null,
    );
    final unsupported = QRScannerServiceEnhanced(
      parseNativeQr: ({required rawData}) async => const FrbWalletQrInput(
        kind: 'unexpected_kind',
        normalized: 'unexpected',
        parsedContentJson: '{}',
        requiresExternalProvider: false,
      ),
    );
    for (final service in [unknown, unsupported]) {
      final result = await service.processQRCode('unrecognized QR');
      expect(result.isSuccess, isFalse);
      expect(result.enrichedResult, isNull);
      expect(result.errorMessage, isNot(contains('unrecognized QR')));
    }
  });

  test(
    'native request and pairing kinds retain their routing metadata',
    () async {
      for (final caseData in [
        ('presentation_request', QRType.presentationRequest, QRFormat.openid),
        ('mdoc_device_engagement', QRType.mdocDeviceEngagement, QRFormat.raw),
        ('remote_pairing', QRType.remotePairing, QRFormat.url),
        ('push_registration', QRType.pushRegistration, QRFormat.url),
      ]) {
        final service = QRScannerServiceEnhanced(
          parseNativeQr: ({required rawData}) async => FrbWalletQrInput(
            kind: caseData.$1,
            normalized: 'native-normalized',
            parsedContentJson: '{}',
            requiresExternalProvider: true,
          ),
        );
        final result = await service.processQRCode('raw input');
        expect(result.isSuccess, isTrue);
        final parsed = result.enrichedResult!.validatedResult.parsedData;
        expect(parsed.type, caseData.$2);
        expect(parsed.format, caseData.$3);
        expect(parsed.rawData, 'native-normalized');
        expect(parsed.metadata['requires_external_provider'], isTrue);
      }
    },
  );

  test('offer review rejects external-provider and incomplete native data', () {
    ParsedQRData parsed(
      Map<String, dynamic> content, {
      bool external = false,
    }) => ParsedQRData(
      type: QRType.credentialOffer,
      format: QRFormat.openid,
      rawData: 'openid-credential-offer://approved',
      parsedContent: content,
      metadata: {'native_parsed': true, 'requires_external_provider': external},
    );

    final valid = {
      'offer_uri': 'openid-credential-offer://approved',
      'credential_issuer': 'https://issuer.example',
      'credential_configuration_ids': ['ExampleIdentity'],
    };
    expect(
      () => CredentialOfferPreview.fromParsed(parsed(valid, external: true)),
      throwsFormatException,
    );
    expect(
      () => CredentialOfferPreview.fromParsed(
        parsed({...valid}..remove('offer_uri')),
      ),
      throwsFormatException,
    );
    expect(
      () => CredentialOfferPreview.fromParsed(
        parsed({...valid, 'credential_configuration_ids': []}),
      ),
      throwsFormatException,
    );
  });
}
