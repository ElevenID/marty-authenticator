import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service_web.dart';
import 'package:marty_authenticator/services/wasm/marty_wasm_stub.dart';
import 'package:marty_authenticator/spruce_client.dart';

void main() {
  test(
    'web wallet never stores arbitrary objects as verified credentials',
    () async {
      final service = SpruceIdPlatformServiceWeb();
      final wallet = SpruceIdWalletManager(service);
      final ob3 = <String, dynamic>{
        'id': 'badge-1',
        'type': ['VerifiableCredential', 'OpenBadgeCredential'],
        'proof': {'proofValue': 'not-yet-verified'},
      };
      for (final invoke in <Future<dynamic> Function()>[
        () => wallet.storeCredential(ob3),
        wallet.getAllCredentials,
        () => wallet.getCredentialsByType('OpenBadgeCredential'),
        () => wallet.deleteCredential('badge-1'),
        () => SpruceIdPlatformServiceWeb().getStoredCredentials(),
      ]) {
        await expectLater(invoke(), throwsA(isA<UnsupportedError>()));
      }
      expect(ob3['proof'], {'proofValue': 'not-yet-verified'});
    },
  );

  test('desktop initialization does not advertise WASM availability', () async {
    final service = SpruceIdPlatformServiceWeb();
    expect(service.isInitialized, isFalse);
    await service.initializeW3C();
    await service.initializeW3C();
    expect(service.isInitialized, isTrue);
    expect(MartyWasm.instance.isAvailable, isFalse);
    expect(MartyWasm.instance, same(MartyWasm.instance));
  });

  final unavailable =
      <String, Future<dynamic> Function(SpruceIdPlatformServiceWeb)>{
        'DID resolution': (s) => s.resolveDid('did:web:issuer.test'),
        'certificate chain verification': (s) =>
            s.verifyCertificateChain(['leaf']),
        'mobile document initialization': (s) =>
            s.initializeMdl({'docType': 'org.iso.18013.5.1.mDL'}),
        'age presentation': (s) => s.presentForAgeVerification(18),
      };
  for (final entry in unavailable.entries) {
    test('web service rejects unavailable ${entry.key}', () async {
      await expectLater(
        entry.value(SpruceIdPlatformServiceWeb()),
        throwsA(isA<UnimplementedError>()),
      );
    });
  }

  final verification =
      <String, Future<dynamic> Function(SpruceIdPlatformServiceWeb)>{
        'credential': (s) => s.verifyVerifiableCredential({'id': 'vc'}),
        'JWT': (s) => s.verifyJWT('signed.jwt.token', 'https://issuer.test'),
        'SD-JWT': (s) => s.verifySdJwt('signed.jwt.token~disclosure~', ['age']),
      };
  for (final entry in verification.entries) {
    test(
      'unavailable web ${entry.key} verification never reports success',
      () async {
        await expectLater(
          entry.value(SpruceIdPlatformServiceWeb()),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  }

  test(
    'non-web WASM adapter cannot fabricate an offer or authorization response',
    () async {
      final wasm = MartyWasm.instance;
      for (final invoke in <Future<dynamic> Function()>[
        () => wasm.createCredentialOffer(
          issuerUrl: 'https://issuer.test',
          credentialTypes: ['OpenBadgeCredential'],
        ),
        () => wasm.issueOpenBadgeV3(request: {'id': 'badge-1'}),
        () => wasm.verifyOpenBadgeV3(request: {'id': 'badge-1'}),
        () => wasm.createAuthorizationResponse(
          vpToken: 'vp-token',
          presentationSubmission: {'id': 'submission-1'},
        ),
      ]) {
        await expectLater(invoke(), throwsA(isA<UnsupportedError>()));
      }
      expect(
        () => wasm.generateOfferUri(
          issuerUrl: 'https://issuer.test',
          offerId: 'offer-1',
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(wasm.getVersion, throwsA(isA<UnsupportedError>()));
      expect(wasm.healthCheck, throwsA(isA<UnsupportedError>()));
    },
  );
}
