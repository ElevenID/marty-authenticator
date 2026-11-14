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
}
