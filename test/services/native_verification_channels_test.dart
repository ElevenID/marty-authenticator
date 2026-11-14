import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/utils/spruce_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void stub(String name, Future<Object?> Function(MethodCall) handler) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  test('native verification channels retain their typed operations', () async {
    final observed = <String, MethodCall>{};
    for (final name in [
      SpruceIdChannels.w3c,
      SpruceIdChannels.pki,
      SpruceIdChannels.jwt,
      SpruceIdChannels.mdoc,
    ]) {
      stub(name, (call) async {
        observed['$name:${call.method}'] = call;
        return {'verified': true};
      });
    }
    final service = SpruceIdPlatformService();
    await service.initializeW3C();
    expect(service.isInitialized, isTrue);
    expect(await service.resolveDid('did:web:issuer.example'), {
      'verified': true,
    });
    expect(await service.verifyVerifiableCredential(const {'id': 'vc'}), {
      'verified': true,
    });
    expect(await service.verifyCertificateChain(const ['public-certificate']), {
      'verified': true,
    });
    expect(await service.verifyJWT('jwt', 'https://issuer.example'), {
      'verified': true,
    });
    expect(await service.verifySdJwt('sd-jwt', const ['name']), {
      'verified': true,
    });
    expect(await service.initializeMdl(const {'docType': 'mDL'}), {
      'verified': true,
    });
    expect(await service.presentForAgeVerification(21), {'verified': true});

    expect(
      observed['${SpruceIdChannels.w3c}:${SpruceIdW3CMethods.resolveDid}']!
          .arguments,
      {'did': 'did:web:issuer.example'},
    );
    expect(
      observed['${SpruceIdChannels.jwt}:${SpruceIdJwtMethods.verifySdJwt}']!
          .arguments,
      {
        'sdJwt': 'sd-jwt',
        'requiredClaims': ['name'],
      },
    );
    expect(
      observed['${SpruceIdChannels.mdoc}:${SpruceIdMdocMethods.presentForAgeVerification}']!
          .arguments,
      {'minimumAge': 21},
    );
  });

  test('native verification failures never turn into local success', () async {
    for (final name in [
      SpruceIdChannels.w3c,
      SpruceIdChannels.pki,
      SpruceIdChannels.jwt,
      SpruceIdChannels.mdoc,
    ]) {
      stub(
        name,
        (_) async => throw PlatformException(code: 'VERIFY_UNAVAILABLE'),
      );
    }
    final service = SpruceIdPlatformService();
    final calls = <Future<Object?> Function()>[
      () => service.resolveDid('did:web:issuer.example'),
      () => service.verifyVerifiableCredential(const {'id': 'vc'}),
      () => service.verifyCertificateChain(const ['public-certificate']),
      () => service.verifyJWT('jwt', 'https://issuer.example'),
      () => service.verifySdJwt('sd-jwt', const ['name']),
      () => service.initializeMdl(const {'docType': 'mDL'}),
      () => service.presentForAgeVerification(21),
    ];
    for (final call in calls) {
      await expectLater(
        call(),
        throwsA(
          isA<SpruceIdException>().having(
            (error) => error.code,
            'code',
            'VERIFY_UNAVAILABLE',
          ),
        ),
      );
    }
  });
}
