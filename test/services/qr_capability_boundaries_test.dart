import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/services/qr_scanner_service_enhanced.dart';
import 'package:marty_authenticator/utils/presentation_privacy.dart';
import 'package:marty_authenticator/widgets/presentation_request_view.dart';

// The QR adapter now classifies native protocols only. Credential matching,
// capabilities and disclosure approval belong to the verified wallet flow.
// A scanned advisory/compatibility field must never create those authorities.
void main() {
  Future<ProcessedQRResult> parse(
    String kind,
    dynamic content, {
    bool external = false,
  }) {
    return QRScannerServiceEnhanced(
      parseNativeQr: ({required rawData}) async => FrbWalletQrInput(
        kind: kind,
        normalized: 'native-normalized-request',
        parsedContentJson: jsonEncode(content),
        requiresExternalProvider: external,
      ),
    ).processQRCode('untrusted scanned content');
  }

  test('native rejection cannot produce a reviewable success', () async {
    final result = await QRScannerServiceEnhanced(
      parseNativeQr: ({required rawData}) async => null,
    ).processQRCode('untrusted');
    expect(result.isSuccess, isFalse);
    expect(result.enrichedResult, isNull);
  });

  for (final compatibility in [
    null,
    [],
    ['unknown'],
    ['unsupported'],
    ['full'],
    ['full', 'unknown'],
  ]) {
    test(
      'scanned compatibility $compatibility cannot confer offer authority',
      () async {
        final content = {
          'offer_uri': 'openid-credential-offer://reviewed',
          'credential_issuer': 'https://issuer.example',
          'credential_configuration_ids': ['age'],
          'credentialCompatibility': compatibility,
          'securityLevel': 'trusted',
          'canAutoHandleOffer': true,
        };
        final result = await parse('credential_offer', content);
        expect(result.isSuccess, isTrue);
        final parsed = result.enrichedResult!.validatedResult.parsedData;
        expect(parsed.metadata, {
          'native_parsed': true,
          'requires_external_provider': false,
        });
        expect(
          CredentialOfferPreview.fromParsed(parsed).credentialConfigurationIds,
          ['age'],
        );
        // No arbitrary capability, match or trust projection is created.
        expect(parsed.parsedContent, content);
      },
    );
  }

  for (final kind in [
    'credential_offer',
    'presentation_request',
    'mdoc_device_engagement',
    'push_registration',
    'remote_pairing',
  ]) {
    for (final external in [false, true]) {
      test(
        '$kind preserves the native external-provider hold $external',
        () async {
          final result = await parse(kind, {
            'requested_attributes': ['SSN'],
          }, external: external);
          expect(result.isSuccess, isTrue);
          final parsed = result.enrichedResult!.validatedResult.parsedData;
          expect(parsed.metadata['requires_external_provider'], external);
          expect(parsed.rawData, 'native-normalized-request');
          expect(parsed.parsedContent, {
            'requested_attributes': ['SSN'],
          });
          if (external && kind == 'credential_offer') {
            expect(
              () => CredentialOfferPreview.fromParsed(parsed),
              throwsFormatException,
            );
          }
        },
      );
    }
  }

  for (final content in [null, [], 'string', 42]) {
    test('non-object native content $content is rejected', () async {
      final result = await parse('presentation_request', content);
      expect(result.isSuccess, isFalse);
      expect(result.enrichedResult, isNull);
    });
  }
  test('unknown native kinds cannot route a presentation', () async {
    expect((await parse('unsupported', {})).isSuccess, isFalse);
  });
  test('native failures are redacted', () async {
    final result = await QRScannerServiceEnhanced(
      parseNativeQr: ({required rawData}) async {
        throw StateError('sensitive-credential-payload');
      },
    ).processQRCode('sensitive-credential-payload');
    expect(result.isSuccess, isFalse);
    expect(
      result.errorMessage,
      isNot(contains('sensitive-credential-payload')),
    );
  });
  for (final content in [
    <String, dynamic>{},
    {
      'offer_uri': '',
      'credential_issuer': 'https://issuer.example',
      'credential_configuration_ids': ['age'],
    },
    {
      'offer_uri': 'uri',
      'credential_issuer': '',
      'credential_configuration_ids': ['age'],
    },
    {
      'offer_uri': 'uri',
      'credential_issuer': 'https://issuer.example',
      'credential_configuration_ids': [],
    },
    {
      'offer_uri': 'uri',
      'credential_issuer': 'https://issuer.example',
      'credential_configuration_ids': [42],
    },
  ]) {
    test('incomplete offer cannot enter acceptance: $content', () async {
      final parsed = (await parse(
        'credential_offer',
        content,
      )).enrichedResult!.validatedResult.parsedData;
      expect(
        () => CredentialOfferPreview.fromParsed(parsed),
        throwsFormatException,
      );
    });
  }

  for (final name in [
    'SSN',
    'social_security_number',
    'bank_account',
    'passport_number',
    'DateOfBirth',
  ]) {
    test('actual consent retains a sensitive-field advisory for $name', () {
      expect(requestsSensitivePresentationFields(['credential/$name']), isTrue);
    });
  }
  test('ordinary consent fields do not fabricate a privacy warning', () {
    expect(
      requestsSensitivePresentationFields([
        'credential/age_over_18',
        'credential/country',
      ]),
      isFalse,
    );
    expect(requestsSensitivePresentationFields([]), isFalse);
  });
  testWidgets(
    'consent shows the actual response destination and sensitive-field notice',
    (tester) async {
      Map<String, dynamic>? approved;
      await tester.pumpWidget(
        MaterialApp(
          home: PresentationRequestView(
            requestDetails: const {
              'verifier': 'did:web:verifier.example',
              'recipient': 'https://receiver.example/response',
            },
            matchingCredentials: const [
              {
                'id': 'verified-receipt',
                'requestedFields': {
                  'credential': ['SSN'],
                },
              },
            ],
            onApprove: (value) => approved = value,
            onReject: () {},
          ),
        ),
      );
      expect(
        find.text('Send to: https://receiver.example/response'),
        findsOneWidget,
      );
      expect(
        find.textContaining('sensitive personal information'),
        findsOneWidget,
      );
      expect(approved, isNull);
      await tester.tap(find.text('Share'));
      expect(approved, {
        'credentialId': 'verified-receipt',
        'selectedFields': ['credential/SSN'],
      });
    },
  );
}
