import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';

void main() {
  final service = SpruceIdPlatformServiceExtended();

  test(
    'old credential-offer handler cannot invoke a local signing key',
    () async {
      await expectLater(
        service.handleOID4VCOfferSDK(
          credentialOffer: 'openid-credential-offer://unused',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );

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
}
