import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces_extended.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/frb_generated.dart';
import 'package:marty_authenticator/services/qr_scanner_service_enhanced.dart';

class _NativeQrParser implements RustLibApi {
  FrbWalletQrInput? result;

  @override
  Future<FrbWalletQrInput?> crateApiWalletValidateQrInput({
    required String rawData,
  }) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements ISpruceIdClientExtended {
  final calls = <Symbol>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    throw UnsupportedError('No SDK capability was supplied by this fixture');
  }
}

class _Wallet implements ISpruceIdWalletManagerExtended {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PresentationWallet extends _Wallet {
  final List<Map<String, dynamic>> credentials;

  _PresentationWallet(this.credentials);

  @override
  Future<List<Map<String, dynamic>>> getAllCredentials() async => credentials;
}

class _PresentationClient extends _Client {
  final Map<String, Map<String, dynamic>> capabilities;
  final requestedIds = <String>[];

  _PresentationClient(this.capabilities);

  @override
  Future<Map<String, dynamic>> getCredentialCapabilitiesSDK(
    String credentialId,
  ) async {
    requestedIds.add(credentialId);
    return capabilities[credentialId] ??
        (throw StateError('Unexpected capability lookup: $credentialId'));
  }
}

EnrichedQRResult offerWith(List<CredentialCompatibility>? compatibility) =>
    EnrichedQRResult(
      validatedResult: const ValidatedQRResult(
        parsedData: ParsedQRData(
          type: QRType.credentialOffer,
          format: QRFormat.openid,
          rawData: 'openid-credential-offer://fixture',
          metadata: {'native_validated': true},
        ),
        isValid: true,
        validationErrors: [],
        securityLevel: SecurityLevel.unknown,
        recommendedActions: [],
        sdkCapabilities: {},
      ),
      matchingCredentials: const [],
      availableActions: const [],
      credentialCompatibility: compatibility,
    );

CredentialCompatibility compatibility(CompatibilityLevel level) =>
    CredentialCompatibility(
      credentialType: 'ExampleCredential',
      format: 'jwt_vc_json',
      isSupported: true,
      supportLevel: level,
      requiredCapabilities: const [],
      availableCapabilities: const [],
      missingCapabilities: const [],
    );

void main() {
  final native = _NativeQrParser();
  setUpAll(() => RustLib.initMock(api: native));
  tearDownAll(RustLib.dispose);
  setUp(() => native.result = null);

  Future<EnrichedQRResult> processPresentation(
    Map<String, dynamic> content, {
    _Client? client,
    _Wallet? wallet,
  }) async {
    native.result = FrbWalletQrInput(
      kind: 'presentation_request',
      normalized: 'openid4vp://validated-request',
      parsedContentJson: jsonEncode(content),
      requiresExternalProvider: false,
    );
    final result = await QRScannerServiceEnhanced(
      spruceClientExtended: client ?? _Client(),
      walletManagerExtended: wallet ?? _PresentationWallet([]),
    ).processQRCode('scanned presentation request');
    expect(result.isSuccess, isTrue);
    return result.enrichedResult!;
  }

  test(
    'parsed offers do not fabricate compatibility or establish trust',
    () async {
      native.result = FrbWalletQrInput(
        kind: 'credential_offer',
        normalized: 'openid-credential-offer://fixture',
        parsedContentJson: jsonEncode({
          'issuer': {'name': 'Official Government Issuer'},
          'credentials': [
            {'type': 'ExampleCredential', 'format': 'jwt_vc_json'},
          ],
        }),
        requiresExternalProvider: false,
      );
      final client = _Client();
      final service = QRScannerServiceEnhanced(
        spruceClientExtended: client,
        walletManagerExtended: _Wallet(),
      );

      final result = await service.processQRCode('input');

      expect(result.isSuccess, isTrue);
      final enriched = result.enrichedResult!;
      expect(enriched.validatedResult.securityLevel, SecurityLevel.unknown);
      expect(enriched.credentialCompatibility!.single.isSupported, isFalse);
      expect(
        enriched.credentialCompatibility!.single.supportLevel,
        CompatibilityLevel.unknown,
      );
      expect(enriched.canAutoHandleOffer, isFalse);
      final review = enriched.availableActions.singleWhere(
        (action) => action.id == 'review_compatibility',
      );
      expect(review.metadata, {'unknown_count': 1, 'total_count': 1});
      expect(review.requiresUserConsent, isTrue);
      expect(
        enriched.availableActions.any(
          (action) => action.metadata.containsKey('unsupported_count'),
        ),
        isFalse,
      );
      expect(client.calls, isEmpty);
    },
  );

  test('native rejection never produces a reviewable success result', () async {
    native.result = null;
    final service = QRScannerServiceEnhanced(
      spruceClientExtended: _Client(),
      walletManagerExtended: _Wallet(),
    );

    final result = await service.processQRCode('unsupported content');

    expect(result.isSuccess, isFalse);
    expect(result.enrichedResult, isNull);
  });

  test('absent or empty compatibility cannot trigger automatic handling', () {
    expect(offerWith(null).canAutoHandleOffer, isFalse);
    expect(offerWith([]).canAutoHandleOffer, isFalse);
  });

  test('unknown and contradictory support claims require explicit review', () {
    expect(
      offerWith([compatibility(CompatibilityLevel.unknown)]).canAutoHandleOffer,
      isFalse,
    );
    expect(
      offerWith([
        compatibility(CompatibilityLevel.unsupported),
      ]).canAutoHandleOffer,
      isFalse,
    );
    expect(
      offerWith([
        compatibility(CompatibilityLevel.full),
        compatibility(CompatibilityLevel.unknown),
      ]).canAutoHandleOffer,
      isFalse,
    );
  });

  test('positive nonempty compatibility can still enter the review flow', () {
    expect(
      offerWith([compatibility(CompatibilityLevel.full)]).canAutoHandleOffer,
      isTrue,
    );
  });

  test(
    'presentation matches exclude retired credentials and require consent',
    () async {
      final client = _PresentationClient({
        'partial': {'hardware_backed': false},
        'full': {'hardware_backed': true},
      });
      final wallet = _PresentationWallet([
        {
          'id': 'partial',
          'credentialSubject': {'name': 'Example', 'country': 'IE'},
        },
        {
          'id': 'retired',
          '@context': 'https://w3id.org/openbadges/v2',
          'credentialSubject': {'name': 'Example', 'age_over_18': true},
        },
        {
          'id': 'unrelated',
          'credentialSubject': {'country': 'IE'},
        },
        {
          'id': 'full',
          'name': 'Identity credential',
          'issuer': 'https://issuer.test',
          'credentialSubject': {
            'name': 'Example',
            'age_over_18': true,
            'address': 'Private address',
          },
        },
      ]);

      final result = await processPresentation(
        {
          'requested_attributes': ['name', 'age_over_18'],
        },
        client: client,
        wallet: wallet,
      );

      expect(client.requestedIds, ['partial', 'full']);
      expect(client.calls, isEmpty);
      expect(result.matchingCredentials.map((c) => c.credentialId), [
        'full',
        'partial',
      ]);
      final full = result.matchingCredentials.first;
      expect(full.credentialName, 'Identity credential');
      expect(full.issuer, 'https://issuer.test');
      expect(full.matchingAttributes, ['name', 'age_over_18']);
      expect(full.totalAttributes, 3);
      expect(full.matchScore, 100);
      expect(full.securityLevel, SecurityLevel.high);
      final partial = result.matchingCredentials.last;
      expect(partial.credentialName, 'Unknown Credential');
      expect(partial.issuer, 'Unknown Issuer');
      expect(partial.matchingAttributes, ['name']);
      expect(partial.matchScore, 50);
      expect(partial.securityLevel, SecurityLevel.medium);
      // Wallet key capabilities do not authenticate the scanned verifier.
      expect(result.validatedResult.securityLevel, SecurityLevel.unknown);
      expect(result.canAutoHandleOffer, isFalse);
      expect(result.availableActions.map((action) => action.id), [
        'create_presentation',
        'selective_disclosure',
        'decline_request',
      ]);
      expect(result.availableActions.first.metadata, {
        'matching_credentials_count': 2,
        'best_match_score': 100,
      });
      expect(result.availableActions[1].metadata, {'total_attributes': 3});
      expect(result.availableActions[0].requiresUserConsent, isTrue);
      expect(result.availableActions[1].requiresUserConsent, isTrue);
      expect(result.availableActions.last.requiresUserConsent, isFalse);
    },
  );

  test('sensitive presentation attributes retain privacy warnings', () async {
    final result = await processPresentation({
      'requested_attributes': ['SSN', 'bank_account'],
    });

    final privacy = result.privacyAnalysis!;
    expect(privacy.overallRiskLevel, RiskLevel.high);
    expect(privacy.attributeRisks.keys, ['SSN', 'bank_account']);
    expect(
      privacy.recommendations,
      contains('High privacy risk detected - consider declining this request'),
    );
    expect(
      privacy.recommendations,
      contains("If you must share, verify the verifier's identity thoroughly"),
    );
    expect(
      privacy.recommendations,
      contains('Highly sensitive attributes requested: SSN, bank_account'),
    );
    expect(result.validatedResult.securityLevel, SecurityLevel.unknown);
  });

  test(
    'unmatched requests retain decline and data minimization choices',
    () async {
      final client = _PresentationClient({});
      final result = await processPresentation(
        {
          'requested_attributes': ['date_of_birth', 'address'],
          'optional_attributes': ['email'],
        },
        client: client,
        wallet: _PresentationWallet([
          {
            'id': 'unrelated',
            'credentialSubject': {'country': 'IE'},
          },
        ]),
      );

      expect(result.matchingCredentials, isEmpty);
      expect(client.requestedIds, isEmpty);
      expect(client.calls, isEmpty);
      expect(result.availableActions.map((action) => action.id), [
        'no_matching_credentials',
        'decline_request',
      ]);
      expect(result.availableActions.first.metadata, {'can_fulfill': false});
      expect(
        result.availableActions.every((action) => !action.requiresUserConsent),
        isTrue,
      );
      final privacy = result.privacyAnalysis!;
      expect(privacy.overallRiskLevel, RiskLevel.medium);
      expect(
        privacy.recommendations,
        contains(
          "Medium privacy risk - review what information you're sharing",
        ),
      );
      expect(
        privacy.recommendations,
        contains(
          'Consider using selective disclosure to share only necessary attributes',
        ),
      );
      expect(privacy.dataMinimizationOpportunities, [
        '1 optional attributes can be excluded',
        'Consider sharing age verification instead of full date of birth',
        'Consider sharing only city/state instead of full address',
      ]);
    },
  );

  for (final attribute in ['name', 'custom_claim']) {
    test(
      'advisory privacy analysis handles $attribute without trust claims',
      () async {
        final result = await processPresentation({
          'requested_attributes': [attribute],
        });

        expect(result.privacyAnalysis!.overallRiskLevel, RiskLevel.low);
        expect(result.privacyAnalysis!.attributeRisks.keys, [attribute]);
        expect(result.privacyAnalysis!.recommendations, [
          'Low privacy risk - standard precautions apply',
        ]);
        expect(result.privacyAnalysis!.dataMinimizationOpportunities, isEmpty);
        expect(result.validatedResult.securityLevel, SecurityLevel.unknown);
      },
    );
  }

  test(
    'a request without attributes cannot select or disclose a credential',
    () async {
      final client = _PresentationClient({});
      final result = await processPresentation(
        {},
        client: client,
        wallet: _PresentationWallet([
          {
            'id': 'stored',
            'credentialSubject': {'name': 'Example'},
          },
        ]),
      );

      expect(result.matchingCredentials, isEmpty);
      expect(client.requestedIds, isEmpty);
      expect(client.calls, isEmpty);
      expect(result.privacyAnalysis!.overallRiskLevel, RiskLevel.minimal);
      expect(result.privacyAnalysis!.attributeRisks, isEmpty);
      expect(result.privacyAnalysis!.recommendations, isEmpty);
      expect(result.availableActions.map((action) => action.id), [
        'no_matching_credentials',
        'decline_request',
      ]);
    },
  );

  test(
    'unavailable capability analysis cannot invent presentation actions',
    () async {
      final client = _Client();
      final result = await processPresentation(
        {
          'requested_attributes': ['name'],
        },
        client: client,
        wallet: _PresentationWallet([
          {
            'id': 'stored',
            'credentialSubject': {'name': 'Example'},
          },
        ]),
      );

      expect(client.calls, [#getCredentialCapabilitiesSDK]);
      expect(result.validatedResult.isValid, isTrue);
      expect(result.validatedResult.securityLevel, SecurityLevel.unknown);
      expect(result.matchingCredentials, isEmpty);
      expect(result.availableActions, isEmpty);
      expect(result.privacyAnalysis, isNull);
      expect(result.canAutoHandleOffer, isFalse);
    },
  );

  for (final (kind, type, format) in [
    ('mdoc_device_engagement', QRType.mdocDeviceEngagement, QRFormat.raw),
    ('push_registration', QRType.pushRegistration, QRFormat.url),
  ]) {
    test(
      '$kind retains the native route and external provider requirement',
      () async {
        native.result = FrbWalletQrInput(
          kind: kind,
          normalized: 'validated-$kind',
          parsedContentJson: '{"session":"fixture"}',
          requiresExternalProvider: true,
        );
        final client = _Client();
        final result = await QRScannerServiceEnhanced(
          spruceClientExtended: client,
          walletManagerExtended: _Wallet(),
        ).processQRCode('scanned input');

        expect(result.isSuccess, isTrue);
        final enriched = result.enrichedResult!;
        final validated = enriched.validatedResult;
        expect(validated.parsedData.type, type);
        expect(validated.parsedData.format, format);
        expect(validated.parsedData.rawData, 'validated-$kind');
        expect(validated.parsedData.parsedContent, {'session': 'fixture'});
        expect(
          validated.parsedData.metadata['requires_external_provider'],
          isTrue,
        );
        expect(validated.recommendedActions, [
          'Continue with the required external provider adapter',
        ]);
        expect(validated.securityLevel, SecurityLevel.unknown);
        expect(enriched.matchingCredentials, isEmpty);
        expect(enriched.availableActions, isEmpty);
        expect(enriched.canAutoHandleOffer, isFalse);
        expect(client.calls, isEmpty);
      },
    );
  }

  for (final (kind, content) in [
    ('unsupported_native_kind', '{}'),
    ('credential_offer', '{invalid json'),
    ('credential_offer', '[]'),
  ]) {
    test(
      'invalid native result $kind / $content returns a processing error',
      () async {
        native.result = FrbWalletQrInput(
          kind: kind,
          normalized: 'invalid-result',
          parsedContentJson: content,
          requiresExternalProvider: false,
        );
        final client = _Client();
        final result = await QRScannerServiceEnhanced(
          spruceClientExtended: client,
          walletManagerExtended: _Wallet(),
        ).processQRCode('scanned input');

        expect(result.isSuccess, isFalse);
        expect(result.enrichedResult, isNull);
        expect(result.errorMessage, startsWith('Failed to process QR code:'));
        expect(client.calls, isEmpty);
      },
    );
  }
}
