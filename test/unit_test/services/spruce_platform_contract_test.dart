import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/services/spruce_platform_service_web.dart';
import 'package:marty_authenticator/spruce_client.dart';
import 'package:marty_authenticator/utils/spruce_channels.dart';

const _credential = <String, dynamic>{
  'id': 'urn:credential:ob3',
  'type': ['VerifiableCredential', 'OpenBadgeCredential'],
  'credentialSubject': {
    'achievement': {'name': 'Course'},
  },
};
const _reply = <String, dynamic>{'id': 'result', 'verified': true};

class _Operation {
  final String name;
  final String channel;
  final String method;
  final Map<String, dynamic> arguments;
  final Future<dynamic> Function(SpruceIdPlatformService) invoke;

  const _Operation(
    this.name,
    this.channel,
    this.method,
    this.arguments,
    this.invoke,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <(String, MethodCall)>[];
  PlatformException? error;
  late SpruceIdPlatformService service;
  const channels = [
    SpruceIdChannels.w3c,
    SpruceIdChannels.pki,
    SpruceIdChannels.jwt,
    SpruceIdChannels.mdoc,
    SpruceIdChannels.wallet,
  ];

  setUp(() {
    service = SpruceIdPlatformService.protected();
    calls.clear();
    error = null;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        calls.add((channel, call));
        if (error != null) throw error!;
        return _reply;
      });
    }
  });
  tearDown(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  // These remain public verification/transport adapters. Issuer or holder
  // signing and arbitrary storage are no longer part of this channel API.
  final operations = <_Operation>[
    _Operation(
      'resolve DID',
      SpruceIdChannels.w3c,
      'resolveDid',
      {'did': 'did:web:issuer.test'},
      (s) => s.resolveDid('did:web:issuer.test'),
    ),
    _Operation(
      'client verify credential',
      SpruceIdChannels.w3c,
      'verifyVerifiableCredential',
      {'credential': _credential},
      (s) => SpruceIdClient(s).verifyCredential(_credential),
    ),
    _Operation(
      'certificate chain verification',
      SpruceIdChannels.pki,
      'verifyCertificateChain',
      {
        'certificateChain': ['leaf', 'root'],
      },
      (s) => s.verifyCertificateChain(['leaf', 'root']),
    ),
    _Operation(
      'JWT verification',
      SpruceIdChannels.jwt,
      'verifyJWT',
      {'jwt': 'signed.jwt.token', 'issuer': 'https://issuer.test'},
      (s) => s.verifyJWT('signed.jwt.token', 'https://issuer.test'),
    ),
    _Operation(
      'SD-JWT verification',
      SpruceIdChannels.jwt,
      'verifySdJwt',
      {
        'sdJwt': 'signed.jwt~disclosure~',
        'requiredClaims': ['age'],
      },
      (s) => s.verifySdJwt('signed.jwt~disclosure~', ['age']),
    ),
    _Operation(
      'initialize mobile document',
      SpruceIdChannels.mdoc,
      'initializeMdl',
      {
        'mdlData': {'given_name': 'Ada'},
      },
      (s) => SpruceIdMdocManager(s).initializeMdl({'given_name': 'Ada'}),
    ),
    _Operation(
      'age presentation transport',
      SpruceIdChannels.mdoc,
      'presentForAgeVerification',
      {'minimumAge': 21},
      (s) => SpruceIdMdocManager(s).presentForAgeVerification(minimumAge: 21),
    ),
  ];

  for (final operation in operations) {
    test('${operation.name} keeps its channel, arguments and result', () async {
      expect(await operation.invoke(service), _reply);
      expect(calls, hasLength(1));
      expect(calls.single.$1, operation.channel);
      expect(calls.single.$2.method, operation.method);
      expect(calls.single.$2.arguments, operation.arguments);
    });
    test('${operation.name} preserves actionable native errors', () async {
      error = PlatformException(
        code: 'ACCESS_DENIED',
        message: 'User declined',
        details: {'retryable': false},
      );
      await expectLater(
        operation.invoke(service),
        throwsA(
          isA<SpruceIdException>()
              .having((e) => e.code, 'code', 'ACCESS_DENIED')
              .having((e) => e.message, 'message', contains('User declined'))
              .having((e) => e.details, 'details', {'retryable': false}),
        ),
      );
      expect(calls, hasLength(1));
    });
  }

  test(
    'legacy wallet calls cannot admit or retrieve unverified records',
    () async {
      final wallet = SpruceIdWalletManager(service);
      final client = SpruceIdClient(service);
      for (final invoke in <Future<dynamic> Function()>[
        () => wallet.storeCredential(_credential),
        wallet.getAllCredentials,
        () => wallet.getCredentialsByType('OpenBadgeCredential'),
        () => wallet.deleteCredential('urn:credential:ob3'),
        client.getCredentials,
        () => client.getCredentialsByType('OpenBadgeCredential'),
      ]) {
        await expectLater(invoke(), throwsA(isA<UnsupportedError>()));
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'initialization failure remains retryable without marking service ready',
    () async {
      final client = SpruceIdClient(service);
      error = PlatformException(
        code: 'UNAVAILABLE',
        message: 'Native library missing',
      );
      await expectLater(client.initialize(), throwsA(isA<SpruceIdException>()));
      expect(service.isInitialized, isFalse);
      error = null;
      await client.initialize();
      expect(service.isInitialized, isTrue);
      expect(calls.map((entry) => entry.$2.method), [
        'initialize',
        'initialize',
      ]);
      expect(service.w3cChannel.name, SpruceIdChannels.w3c);
      expect(service.pkiChannel.name, SpruceIdChannels.pki);
      expect(service.jwtChannel.name, SpruceIdChannels.jwt);
      expect(service.mdocChannel.name, SpruceIdChannels.mdoc);
      expect(service.walletChannel.name, SpruceIdChannels.wallet);
      expect(
        const SpruceIdException('DENIED', 'Declined').toString(),
        'SpruceIdException(DENIED): Declined',
      );
    },
  );

  test(
    'initialization provider uses the injected service and surfaces failure',
    () async {
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [spruceIdPlatformServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      await container.read(spruceIdInitializationProvider.future);
      expect(service.isInitialized, isTrue);
      expect(calls.single.$2.method, 'initialize');
      error = PlatformException(code: 'OFFLINE');
      container.invalidate(spruceIdInitializationProvider);
      await expectLater(
        container.read(spruceIdInitializationProvider.future),
        throwsA(isA<SpruceIdException>()),
      );
    },
  );

  test('platform providers select the mobile or desktop implementation', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      final selected = container.read(spruceIdPlatformServiceProvider);
      expect(
        selected,
        {TargetPlatform.android, TargetPlatform.iOS}.contains(platform)
            ? isA<SpruceIdPlatformServiceExtended>()
            : isA<SpruceIdPlatformServiceWeb>(),
      );
      container.dispose();
    }
  });
}
