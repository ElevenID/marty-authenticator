import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/services/spruce_platform_service_web.dart';

void main() {
  final service = SpruceIdPlatformServiceExtended();

  test('legacy platform credential stores reject unverified data', () async {
    final stores = [SpruceIdPlatformService(), SpruceIdPlatformServiceWeb()];
    for (final store in stores) {
      await expectLater(
        store.storeCredential(const {'id': 'unverified'}),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        store.getStoredCredentials(),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        store.getCredentialsByType('Example'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        store.deleteCredential('unverified'),
        throwsA(isA<UnsupportedError>()),
      );
    }
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

  test(
    'unsupported wallet and mDoc channels fail before native dispatch',
    () async {
      final calls = <Future<Object?> Function()>[
        () => service.verifySdJwtPresentationSDK(
          presentation: 'unverified',
          requiredClaims: const [],
        ),
        () => service.initializeMdocSDK(mdocData: const {}),
        () => service.handleMdocOid4vpRequestSDK(requestUrl: 'unverified'),
        () => service.backupCredentialsSDK(backupPassphrase: 'unused'),
        () => service.restoreCredentialsSDK(
          backupData: 'unverified',
          backupPassphrase: 'unused',
        ),
        () =>
            service.syncCredentialsSDK(syncEndpoint: 'https://unused.example'),
        () => service.exportCredentialsSDK(
          credentialIds: const [],
          exportFormat: 'unverified',
        ),
        () => service.importCredentialsSDK(credentialData: 'unverified'),
      ];
      for (final call in calls) {
        await expectLater(call(), throwsA(isA<UnsupportedError>()));
      }
    },
  );
}
