import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/services/spruce_platform_service_web.dart';
import 'package:marty_authenticator/spruce_client.dart';
import 'package:marty_authenticator/utils/riverpod/providers/spruce_providers.dart';
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
  final Map<String, dynamic>? arguments;
  final Future<dynamic> Function(SpruceIdPlatformService) invoke;
  final dynamic reply;
  final dynamic expected;

  const _Operation(
    this.name,
    this.channel,
    this.method,
    this.arguments,
    this.invoke, {
    this.reply = _reply,
    this.expected = _reply,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <(String, MethodCall)>[];
  dynamic response;
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
    response = _reply;
    error = null;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        calls.add((channel, call));
        if (error != null) throw error!;
        return response;
      });
    }
  });
  tearDown(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  final operations = <_Operation>[
    _Operation(
      'resolve DID',
      SpruceIdChannels.w3c,
      'resolveDid',
      {'did': 'did:web:issuer.test'},
      (s) => s.resolveDid('did:web:issuer.test'),
    ),
    _Operation(
      'sign credential with explicit key',
      SpruceIdChannels.w3c,
      'signVerifiableCredential',
      {'credential': _credential, 'keyId': 'key-7'},
      (s) => s.signVerifiableCredential(_credential, keyId: 'key-7'),
    ),
    _Operation(
      'client sign credential omits optional key',
      SpruceIdChannels.w3c,
      'signVerifiableCredential',
      {'credential': _credential},
      (s) => SpruceIdClient(s).signCredential(_credential),
    ),
    _Operation(
      'client verify credential',
      SpruceIdChannels.w3c,
      'verifyVerifiableCredential',
      {'credential': _credential},
      (s) => SpruceIdClient(s).verifyCredential(_credential),
    ),
    _Operation(
      'generate default RSA key',
      SpruceIdChannels.pki,
      'generateKeyPair',
      {'keyType': 'RSA', 'keySize': 2048},
      (s) => s.generateKeyPair(),
    ),
    _Operation(
      'generate requested key',
      SpruceIdChannels.pki,
      'generateKeyPair',
      {'keyType': 'EC', 'keySize': 256},
      (s) => s.generateKeyPair(keyType: 'EC', keySize: 256),
    ),
    _Operation(
      'create CSR',
      SpruceIdChannels.pki,
      'createCSR',
      {'subject': 'CN=Example', 'keyId': 'key-7'},
      (s) => s.createCSR('CN=Example', keyId: 'key-7'),
    ),
    _Operation(
      'certificate signing',
      SpruceIdChannels.pki,
      'signWithCertificate',
      {'document': _credential, 'certificateId': 'cert-7'},
      (s) => s.signWithCertificate(_credential, 'cert-7'),
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
      'JWT creation',
      SpruceIdChannels.jwt,
      'createJWT',
      {
        'issuer': 'https://issuer.test',
        'claims': {'role': 'student'},
      },
      (s) => s.createJWT('https://issuer.test', {'role': 'student'}),
    ),
    _Operation(
      'JWT verification',
      SpruceIdChannels.jwt,
      'verifyJWT',
      {'jwt': 'signed.jwt.token', 'issuer': 'https://issuer.test'},
      (s) => s.verifyJWT('signed.jwt.token', 'https://issuer.test'),
    ),
    _Operation(
      'SD-JWT creation',
      SpruceIdChannels.jwt,
      'createSdJwt',
      {
        'issuer': 'https://issuer.test',
        'claims': {'age': 25},
        'selectivelyDisclosableClaims': ['age'],
      },
      (s) => SpruceIdSdJwtManager(s).createSdJwt(
        issuer: 'https://issuer.test',
        claims: {'age': 25},
        selectivelyDisclosableClaims: ['age'],
      ),
    ),
    _Operation(
      'SD-JWT presentation',
      SpruceIdChannels.jwt,
      'createSdJwt',
      {
        'issuer': 'https://issuer.test',
        'claims': {'age': 25},
        'selectivelyDisclosableClaims': ['age'],
      },
      (s) => SpruceIdSdJwtManager(s).present(
        issuer: 'https://issuer.test',
        claims: {'age': 25},
        discloseClaims: ['age'],
      ),
    ),
    _Operation(
      'client SD-JWT presentation',
      SpruceIdChannels.jwt,
      'createSdJwt',
      {
        'issuer': 'https://issuer.test',
        'claims': {'age': 25},
        'selectivelyDisclosableClaims': ['age'],
      },
      (s) => SpruceIdClient(s).createSdJwtPresentation(
        issuer: 'https://issuer.test',
        claims: {'age': 25},
        discloseKeys: ['age'],
      ),
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
      'age-only presentation',
      SpruceIdChannels.mdoc,
      'presentForAgeVerification',
      {'minimumAge': 21},
      (s) => SpruceIdMdocManager(s).presentForAgeVerification(minimumAge: 21),
    ),
    _Operation(
      'document presentation preserves hidden attributes',
      SpruceIdChannels.mdoc,
      'createMdocResponse',
      {
        'requestedAttributes': ['given_name'],
        'hiddenAttributes': ['birth_date'],
      },
      (s) => SpruceIdMdocManager(s).presentForIdVerification(
        requestedAttributes: ['given_name'],
        hiddenAttributes: ['birth_date'],
      ),
    ),
    _Operation(
      'client document presentation defaults hidden attributes',
      SpruceIdChannels.mdoc,
      'createMdocResponse',
      {
        'requestedAttributes': ['given_name'],
        'hiddenAttributes': <String>[],
      },
      (s) => SpruceIdClient(
        s,
      ).createMdocResponse(requestedAttributes: ['given_name']),
    ),
    _Operation(
      'store credential',
      SpruceIdChannels.wallet,
      'storeCredential',
      {'credential': _credential},
      (s) => SpruceIdWalletManager(s).storeCredential(_credential),
      reply: null,
      expected: null,
    ),
    _Operation(
      'read empty wallet',
      SpruceIdChannels.wallet,
      'getCredentials',
      null,
      (s) => SpruceIdWalletManager(s).getAllCredentials(),
      reply: null,
      expected: <Map<String, dynamic>>[],
    ),
    _Operation(
      'client reads empty wallet',
      SpruceIdChannels.wallet,
      'getCredentials',
      null,
      (s) => SpruceIdClient(s).getCredentials(),
      reply: <Map<String, dynamic>>[],
      expected: <Map<String, dynamic>>[],
    ),
    _Operation(
      'filter wallet',
      SpruceIdChannels.wallet,
      'getCredentialsByType',
      {'type': 'OpenBadgeCredential'},
      (s) =>
          SpruceIdWalletManager(s).getCredentialsByType('OpenBadgeCredential'),
      reply: null,
      expected: <Map<String, dynamic>>[],
    ),
    _Operation(
      'client filters wallet',
      SpruceIdChannels.wallet,
      'getCredentialsByType',
      {'type': 'OpenBadgeCredential'},
      (s) => SpruceIdClient(s).getCredentialsByType('OpenBadgeCredential'),
      reply: <Map<String, dynamic>>[],
      expected: <Map<String, dynamic>>[],
    ),
    _Operation(
      'delete only requested credential',
      SpruceIdChannels.wallet,
      'deleteCredential',
      {'id': 'urn:credential:ob3'},
      (s) => SpruceIdWalletManager(s).deleteCredential('urn:credential:ob3'),
      reply: null,
      expected: null,
    ),
  ];

  for (final operation in operations) {
    test('${operation.name} keeps its channel, arguments and result', () async {
      response = operation.reply;
      expect(await operation.invoke(service), operation.expected);
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
    });
  }

  test(
    'DID creation initializes once and the client returns the DID',
    () async {
      expect(service.isInitialized, isFalse);
      response = {'did': 'did:key:zHolder', 'keyId': 'holder-key'};
      final client = SpruceIdClient(service);
      expect(await client.createDid(), 'did:key:zHolder');
      expect(calls.map((entry) => entry.$2.method), [
        'initialize',
        'createDid',
      ]);
      expect(calls.last.$2.arguments, {'method': 'key'});
      expect(service.isInitialized, isTrue);
      calls.clear();
      await client.createDid(method: 'web');
      expect(calls.single.$2.arguments, {'method': 'web'});
      error = PlatformException(code: 'KEY_LOCKED', message: 'Unlock required');
      await expectLater(
        client.createDid(),
        throwsA(
          isA<SpruceIdException>().having((e) => e.code, 'code', 'KEY_LOCKED'),
        ),
      );
      expect(service.w3cChannel.name, SpruceIdChannels.w3c);
      expect(service.pkiChannel.name, SpruceIdChannels.pki);
      expect(service.jwtChannel.name, SpruceIdChannels.jwt);
      expect(service.mdocChannel.name, SpruceIdChannels.mdoc);
      expect(service.walletChannel.name, SpruceIdChannels.wallet);
    },
  );

  test('failed initialization never marks the service ready', () async {
    error = PlatformException(
      code: 'UNAVAILABLE',
      message: 'Native library missing',
    );
    await expectLater(
      SpruceIdClient(service).initialize(),
      throwsA(isA<SpruceIdException>()),
    );
    expect(service.isInitialized, isFalse);
    expect(
      const SpruceIdException('DENIED', 'Declined').toString(),
      'SpruceIdException(DENIED): Declined',
    );
  });

  test(
    'injected providers initialize the same service and surface failure',
    () async {
      final container = ProviderContainer(
        overrides: [spruceIdPlatformServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      expect(container.read(spruceIdClientProvider), isA<SpruceIdClient>());
      expect(
        container.read(spruceIdWalletManagerProvider),
        isA<SpruceIdWalletManager>(),
      );
      expect(
        container.read(spruceIdMdocManagerProvider),
        isA<SpruceIdMdocManager>(),
      );
      expect(
        container.read(spruceIdSdJwtManagerProvider),
        isA<SpruceIdSdJwtManager>(),
      );
      expect(await container.read(spruceIdInitializedProvider.future), isTrue);
      await container.read(spruceIdInitializationProvider.future);
      expect(service.isInitialized, isTrue);
      error = PlatformException(code: 'OFFLINE');
      container.invalidate(spruceIdInitializedProvider);
      expect(await container.read(spruceIdInitializedProvider.future), isFalse);
    },
  );

  test(
    'platform providers select the existing mobile or desktop implementation',
    () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final container = ProviderContainer();
        final selected = container.read(spruceIdPlatformServiceProvider);
        expect(
          selected,
          platform == TargetPlatform.android
              ? isA<SpruceIdPlatformServiceExtended>()
              : isA<SpruceIdPlatformServiceWeb>(),
        );
        container.dispose();
      }
    },
  );
}
