import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';

void main() {
  final service = SpruceIdPlatformServiceExtended();

  test(
    'base platform signing entry points fail before native channels',
    () async {
      final base = SpruceIdPlatformService();
      final calls = <Future<Object?> Function()>[
        () => base.createDid(),
        () => base.signVerifiableCredential(const {}),
        () => base.generateKeyPair(),
        () => base.createCSR('unused'),
        () => base.signWithCertificate(const {}, 'unused'),
        () => base.createJWT('unused', const {}),
        () => base.createSdJwt('unused', const {}, const []),
        () => base.createMdocResponse(const [], const []),
      ];
      for (final call in calls) {
        await expectLater(call(), throwsA(isA<UnsupportedError>()));
      }
    },
  );

  test('credential offers reject legacy local-key selection', () async {
    await expectLater(
      service.handleOID4VCOfferSDK(
        credentialOffer: 'openid-credential-offer://unused',
        keyId: 'local-key',
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('old presentation handler cannot invoke a local signing key', () async {
    await expectLater(
      service.handleOID4VPRequestSDK(
        presentationRequest: 'openid4vp://unused',
        selectedCredentials: const [],
        disclosureOptions: const [],
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test(
    'ad hoc presentation creation requires the verified request flow',
    () async {
      await expectLater(
        service.createPresentationSDK(
          credentials: const [],
          challenge: 'challenge',
          domain: 'https://verifier.example',
          selectiveDisclosure: const {},
        ),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );

  test('unregistered holder SDK key and signing methods fail closed', () async {
    await expectLater(
      service.initializeHolderSDK(keyId: 'local-key'),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      service.generateSecureKeySDK(),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      service.signPresentationSDK(presentation: const {}, keyId: 'local-key'),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      service.monitorCredentialStatusSDK('credential-id'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test(
    'registered native wrappers cannot request a default local key',
    () async {
      await expectLater(
        service.createAdvancedSdJwtSDK(
          issuer: 'https://issuer.example',
          claims: const {},
          disclosureTree: const {},
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.presentSdJwtSDK(
          sdJwt: 'unused',
          disclosureRequest: const {},
          challenge: 'unused',
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.createMdocPresentationSDK(
          docType: 'unused',
          requestedAttributes: const [],
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.establishMdocSessionSDK(sessionRequest: const {}),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.refreshCredentialSDK(credentialId: 'unused'),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );
}
