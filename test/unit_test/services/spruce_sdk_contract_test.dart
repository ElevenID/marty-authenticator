import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/frb_generated.dart';
import 'package:marty_authenticator/services/spruce_client_extended.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/utils/spruce_channels.dart';

const _credential = <String, dynamic>{
  'id': 'urn:credential:ob3',
  'type': ['VerifiableCredential', 'OpenBadgeCredential'],
};
const _result = <String, dynamic>{'status': 'complete', 'id': 'result'};
const _sdk = 'spruce_id_sdk';
const _monitor = 'spruce_id_credential_monitor';

class _WalletApi implements RustLibApi {
  String route = 'oid4vp';
  String? offer;
  String? request;
  String? contextJson;
  Object? rejection;

  @override
  Future<String> crateApiWalletNormalizeCredentialOffer({
    required String input,
  }) async {
    offer = input;
    if (rejection != null) throw rejection!;
    return '{"credential_offer_uri":"https://issuer.test/offer"}';
  }

  @override
  Future<String> crateApiWalletRoutePresentationRequest({
    required String input,
  }) async {
    request = input;
    if (rejection != null) throw rejection!;
    return route;
  }

  @override
  Future<FrbPresentationBindingContext>
  crateApiWalletValidatePresentationContext({
    required String requestJson,
  }) async {
    contextJson = requestJson;
    if (rejection != null) throw rejection!;
    return const FrbPresentationBindingContext(
      challenge: 'validated-nonce',
      domain: 'https://verifier.test',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SdkOperation {
  final String name;
  final String channel;
  final String method;
  final Map<String, dynamic> arguments;
  final Future<dynamic> Function(SpruceIdPlatformServiceExtended) invoke;
  final dynamic result;

  const _SdkOperation(
    this.name,
    this.channel,
    this.method,
    this.arguments,
    this.invoke, {
    this.result = _result,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final native = _WalletApi();
  final service = SpruceIdPlatformServiceExtended();
  final calls = <(String, MethodCall)>[];
  dynamic response;
  PlatformException? failure;
  const channels = [
    SpruceIdChannels.w3c,
    SpruceIdChannels.jwt,
    SpruceIdChannels.mdoc,
    SpruceIdChannels.wallet,
    _sdk,
    _monitor,
  ];

  setUpAll(() => RustLib.initMock(api: native));
  tearDownAll(RustLib.dispose);
  setUp(() {
    native.route = 'oid4vp';
    native.offer = null;
    native.request = null;
    native.contextJson = null;
    native.rejection = null;
    calls.clear();
    response = _result;
    failure = null;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        calls.add((channel, call));
        if (failure != null) throw failure!;
        return response;
      });
    }
  });
  tearDown(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  final operations = <_SdkOperation>[
    _SdkOperation(
      'credential offer',
      SpruceIdChannels.w3c,
      'handleOID4VCOfferRefactored',
      {
        'offer': '{"credential_offer_uri":"https://issuer.test/offer"}',
        'pin': '1234',
        'keyId': 'holder-key',
      },
      (s) => SpruceIdClientExtended(s).handleOID4VCOfferSDK(
        credentialOffer: 'openid-credential-offer://raw',
        pin: '1234',
        keyId: 'holder-key',
      ),
    ),
    _SdkOperation(
      'OID4VP selected credential request',
      SpruceIdChannels.w3c,
      'handleOID4VPRequestRefactored',
      {
        'request': 'openid4vp://request',
        'selectedCredentials': [_credential],
        'disclosureOptions': ['achievement'],
        'keyId': 'default-key',
      },
      (s) => SpruceIdClientExtended(s).handleOID4VPRequestSDK(
        presentationRequest: 'openid4vp://request',
        selectedCredentials: [_credential],
        disclosureOptions: ['achievement'],
      ),
    ),
    _SdkOperation(
      'bound presentation',
      SpruceIdChannels.w3c,
      'createPresentationRefactored',
      {
        'credentials': [_credential],
        'challenge': 'nonce',
        'domain': 'https://verifier.test',
        'selectiveDisclosure': {
          'urn:credential:ob3': ['achievement'],
        },
        'keyId': 'holder-key',
      },
      (s) => SpruceIdClientExtended(s).createPresentationSDK(
        credentials: [_credential],
        challenge: 'nonce',
        domain: 'https://verifier.test',
        selectiveDisclosure: {
          'urn:credential:ob3': ['achievement'],
        },
        keyId: 'holder-key',
      ),
    ),
    _SdkOperation(
      'holder initialization defaults',
      _sdk,
      'initializeHolderSDK',
      {'keyId': 'default-key', 'config': <String, dynamic>{}},
      (s) => SpruceIdClientExtended(s).initializeHolderSDK(),
    ),
    _SdkOperation(
      'holder presentation defaults',
      _sdk,
      'createVerifiablePresentationSDK',
      {
        'credentials': [_credential],
        'challenge': 'nonce',
        'domain': '',
        'selectiveDisclosure': <String, dynamic>{},
        'presentationFormat': 'jwt_vp',
        'keyId': 'default-key',
      },
      (s) => SpruceIdClientExtended(s).createVerifiablePresentationSDK(
        credentials: [_credential],
        challenge: 'nonce',
      ),
    ),
    _SdkOperation(
      'holder presentation custom binding',
      _sdk,
      'createVerifiablePresentationSDK',
      {
        'credentials': [_credential],
        'challenge': 'nonce',
        'domain': 'https://verifier.test',
        'selectiveDisclosure': {
          'urn:credential:ob3': ['achievement'],
        },
        'presentationFormat': 'ldp_vp',
        'keyId': 'holder-key',
      },
      (s) => SpruceIdClientExtended(s).createVerifiablePresentationSDK(
        credentials: [_credential],
        challenge: 'nonce',
        domain: 'https://verifier.test',
        selectiveDisclosure: {
          'urn:credential:ob3': ['achievement'],
        },
        presentationFormat: 'ldp_vp',
        keyId: 'holder-key',
      ),
    ),
    _SdkOperation(
      'presentation signing',
      _sdk,
      'signPresentationSDK',
      {
        'presentation': {'id': 'vp-7'},
        'keyId': 'holder-key',
        'verificationMethod': 'did:key:z#z',
        'proofPurpose': 'authentication',
      },
      (s) => SpruceIdClientExtended(s).signPresentationSDK(
        presentation: {'id': 'vp-7'},
        keyId: 'holder-key',
        verificationMethod: 'did:key:z#z',
      ),
    ),
    _SdkOperation(
      'credential batch',
      _sdk,
      'batchProcessCredentialsSDK',
      {
        'operations': [
          {'verify': _credential},
        ],
        'keyId': 'default-key',
      },
      (s) => SpruceIdClientExtended(s).batchProcessCredentialsSDK(
        operations: [
          {'verify': _credential},
        ],
      ),
      result: <Map<String, dynamic>>[],
    ),
    _SdkOperation(
      'credential capabilities',
      _sdk,
      'getCredentialCapabilitiesSDK',
      {'credentialId': 'urn:credential:ob3'},
      (s) => SpruceIdClientExtended(
        s,
      ).getCredentialCapabilitiesSDK('urn:credential:ob3'),
    ),
    _SdkOperation(
      'credential validation',
      _sdk,
      'validateCredentialSDK',
      {
        'credential': _credential,
        'schemaId': 'schema-7',
        'policies': ['issuer-trust'],
      },
      (s) => SpruceIdClientExtended(s).validateCredentialSDK(
        credential: _credential,
        schemaId: 'schema-7',
        policies: ['issuer-trust'],
      ),
    ),
    _SdkOperation(
      'hardware key generation',
      _sdk,
      'generateSecureKeySDK',
      {
        'algorithm': 'Ed25519',
        'useHardwareModule': true,
        'keyPolicies': <String, dynamic>{},
      },
      (s) => SpruceIdClientExtended(s).generateSecureKeySDK(),
    ),
    _SdkOperation(
      'key operation',
      _sdk,
      'performCryptoOperationSDK',
      {
        'operation': 'sign',
        'keyId': 'holder-key',
        'payload': {'bytes': 'base64'},
        'options': {'purpose': 'proof'},
      },
      (s) => SpruceIdClientExtended(s).performCryptoOperationSDK(
        operation: 'sign',
        keyId: 'holder-key',
        payload: {'bytes': 'base64'},
        options: {'purpose': 'proof'},
      ),
    ),
    _SdkOperation(
      'secure peer channel',
      _sdk,
      'establishSecureChannelSDK',
      {
        'peerDid': 'did:example:peer',
        'keyId': 'default-key',
        'channelOptions': <String, dynamic>{},
      },
      (s) => SpruceIdClientExtended(
        s,
      ).establishSecureChannelSDK(peerDid: 'did:example:peer'),
    ),
    _SdkOperation(
      'advanced SD-JWT creation',
      SpruceIdChannels.jwt,
      'createAdvancedSdJwtSDK',
      {
        'issuer': 'https://issuer.test',
        'claims': {'age': 25},
        'disclosureTree': {'age': true},
        'alwaysDisclose': ['iss'],
        'keyId': 'default-key',
      },
      (s) => s.createAdvancedSdJwtSDK(
        issuer: 'https://issuer.test',
        claims: {'age': 25},
        disclosureTree: {'age': true},
        alwaysDisclose: ['iss'],
      ),
    ),
    _SdkOperation(
      'SD-JWT presentation',
      SpruceIdChannels.jwt,
      'presentSdJwtSDK',
      {
        'sdJwt': 'signed.jwt~disclosure~',
        'disclosureRequest': {'age': true},
        'challenge': 'nonce',
        'keyId': 'default-key',
      },
      (s) => s.presentSdJwtSDK(
        sdJwt: 'signed.jwt~disclosure~',
        disclosureRequest: {'age': true},
        challenge: 'nonce',
      ),
    ),
    _SdkOperation(
      'SD-JWT presentation verification',
      SpruceIdChannels.jwt,
      'verifySdJwtPresentationSDK',
      {
        'presentation': 'signed.vp',
        'requiredClaims': ['age'],
        'policies': <String>[],
      },
      (s) => s.verifySdJwtPresentationSDK(
        presentation: 'signed.vp',
        requiredClaims: ['age'],
      ),
    ),
    _SdkOperation(
      'mobile document initialization',
      SpruceIdChannels.mdoc,
      'initializeMdocSDK',
      {
        'mdocData': {'docType': 'org.iso.18013.5.1.mDL'},
        'enableProximityDetection': true,
        'deviceConfig': <String, dynamic>{},
      },
      (s) =>
          s.initializeMdocSDK(mdocData: {'docType': 'org.iso.18013.5.1.mDL'}),
    ),
    _SdkOperation(
      'mobile document OID4VP',
      SpruceIdChannels.mdoc,
      'createMdocResponse',
      {'requestUrl': 'openid4vp://mdoc-request'},
      (s) =>
          s.handleMdocOid4vpRequestSDK(requestUrl: 'openid4vp://mdoc-request'),
    ),
    _SdkOperation(
      'mobile document selective presentation',
      SpruceIdChannels.mdoc,
      'createMdocPresentationSDK',
      {
        'docType': 'org.iso.18013.5.1.mDL',
        'requestedAttributes': ['age_over_18'],
        'ageVerificationOptions': {'minimumAge': 18},
        'hiddenAttributes': ['birth_date'],
        'keyId': 'default-key',
      },
      (s) => s.createMdocPresentationSDK(
        docType: 'org.iso.18013.5.1.mDL',
        requestedAttributes: ['age_over_18'],
        ageVerificationOptions: {'minimumAge': 18},
        hiddenAttributes: ['birth_date'],
      ),
    ),
    _SdkOperation(
      'mobile document session',
      SpruceIdChannels.mdoc,
      'establishMdocSessionSDK',
      {
        'sessionRequest': {'nonce': 'session-nonce'},
        'keyId': 'default-key',
        'securityOptions': <String, dynamic>{},
      },
      (s) =>
          s.establishMdocSessionSDK(sessionRequest: {'nonce': 'session-nonce'}),
    ),
    _SdkOperation(
      'refresh one credential',
      SpruceIdChannels.wallet,
      'refreshCredentialSDK',
      {
        'credentialId': 'urn:credential:ob3',
        'keyId': 'default-key',
        'refreshOptions': <String, dynamic>{},
      },
      (s) => s.refreshCredentialSDK(credentialId: 'urn:credential:ob3'),
    ),
    _SdkOperation(
      'encrypted backup',
      SpruceIdChannels.wallet,
      'backupCredentialsSDK',
      {
        'credentialIds': ['urn:credential:ob3'],
        'backupPassphrase': 'test-only-passphrase',
        'backupOptions': <String, dynamic>{},
      },
      (s) => s.backupCredentialsSDK(
        credentialIds: ['urn:credential:ob3'],
        backupPassphrase: 'test-only-passphrase',
      ),
    ),
    _SdkOperation(
      'restore backup',
      SpruceIdChannels.wallet,
      'restoreCredentialsSDK',
      {
        'backupData': 'encrypted-backup',
        'backupPassphrase': 'test-only-passphrase',
        'restoreOptions': <String, dynamic>{},
      },
      (s) => s.restoreCredentialsSDK(
        backupData: 'encrypted-backup',
        backupPassphrase: 'test-only-passphrase',
      ),
    ),
    _SdkOperation(
      'credential sync',
      SpruceIdChannels.wallet,
      'syncCredentialsSDK',
      {
        'syncEndpoint': 'https://wallet.test/sync',
        'syncToken': 'test-only-token',
        'syncOptions': {'direction': 'pull'},
      },
      (s) => SpruceIdClientExtended(s).syncCredentialsSDK(
        syncEndpoint: 'https://wallet.test/sync',
        syncToken: 'test-only-token',
        syncOptions: {'direction': 'pull'},
      ),
    ),
    _SdkOperation(
      'credential export',
      SpruceIdChannels.wallet,
      'exportCredentialsSDK',
      {
        'credentialIds': ['urn:credential:ob3'],
        'exportFormat': 'json',
        'exportOptions': <String, dynamic>{},
      },
      (s) => SpruceIdClientExtended(s).exportCredentialsSDK(
        credentialIds: ['urn:credential:ob3'],
        exportFormat: 'json',
      ),
    ),
    _SdkOperation(
      'credential import',
      SpruceIdChannels.wallet,
      'importCredentialsSDK',
      {
        'credentialData': '{"id":"ob3"}',
        'expectedFormat': 'json',
        'importOptions': <String, dynamic>{},
      },
      (s) => SpruceIdClientExtended(s).importCredentialsSDK(
        credentialData: '{"id":"ob3"}',
        expectedFormat: 'json',
      ),
    ),
  ];

  for (final operation in operations) {
    test('${operation.name} preserves native arguments and result', () async {
      response = operation.result;
      expect(await operation.invoke(service), operation.result);
      expect(calls, hasLength(1));
      expect(calls.single.$1, operation.channel);
      expect(calls.single.$2.method, operation.method);
      expect(calls.single.$2.arguments, operation.arguments);
    });
    test('${operation.name} propagates native failure details', () async {
      failure = PlatformException(
        code: 'CONSENT_REQUIRED',
        message: 'Unlock wallet',
        details: {'retryable': true},
      );
      await expectLater(
        operation.invoke(service),
        throwsA(
          isA<SpruceIdException>()
              .having((e) => e.code, 'code', 'CONSENT_REQUIRED')
              .having((e) => e.message, 'message', contains('Unlock wallet'))
              .having((e) => e.details, 'details', {'retryable': true}),
        ),
      );
    });
  }

  test(
    'request routing uses the Rust decision and passes raw request once',
    () async {
      final client = SpruceIdClientExtended(service);
      for (final route in ['oid4vp', 'mdoc']) {
        native.route = route;
        calls.clear();
        expect(
          await client.initiateOID4VPRequestSDK(
            presentationRequest: 'request-payload',
          ),
          _result,
        );
        expect(native.request, 'request-payload');
        expect(
          calls.single.$1,
          route == 'mdoc' ? SpruceIdChannels.mdoc : SpruceIdChannels.w3c,
        );
        expect(calls.single.$2.arguments, {
          'request': 'request-payload',
          'requestUrl': 'request-payload',
        });
      }
      native.route = 'unsupported';
      calls.clear();
      await expectLater(
        client.initiateOID4VPRequestSDK(presentationRequest: 'request-payload'),
        throwsStateError,
      );
      expect(calls, isEmpty);
      native.route = 'oid4vp';
      failure = PlatformException(
        code: 'VERIFIER_DENIED',
        message: 'Untrusted verifier',
      );
      await expectLater(
        client.initiateOID4VPRequestSDK(presentationRequest: 'request-payload'),
        throwsA(isA<SpruceIdException>()),
      );
    },
  );

  test(
    'selection-required response carries session and verifier details',
    () async {
      response = {
        'status': 'user_selection_required',
        'sessionId': 'session-7',
        'matches': <Map<String, dynamic>>[],
        'verifier': 'Example verifier',
        'purpose': 'Age check',
      };
      await expectLater(
        service.initiateOID4VPRequestSDK(presentationRequest: 'request'),
        throwsA(
          isA<UserSelectionRequiredException>()
              .having((e) => e.sessionId, 'session', 'session-7')
              .having((e) => e.matches, 'matches', isEmpty)
              .having((e) => e.requestDetails, 'details', {
                'verifier': 'Example verifier',
                'purpose': 'Age check',
              })
              .having((e) => e.toString(), 'display', contains('session-7')),
        ),
      );
    },
  );

  test(
    'OID4VP completion passes selected fields and uses mdoc fallback only after failure',
    () async {
      final client = SpruceIdClientExtended(service);
      expect(
        await client.completeOID4VPRequestSDK(
          sessionId: 'session-7',
          selectedCredentialId: 'urn:credential:ob3',
          selectedFields: ['achievement'],
        ),
        _result,
      );
      expect(calls.single.$1, SpruceIdChannels.w3c);
      expect(calls.single.$2.arguments, {
        'sessionId': 'session-7',
        'selectedCredentialId': 'urn:credential:ob3',
        'selectedFields': ['achievement'],
      });
      calls.clear();
      messenger.setMockMethodCallHandler(
        const MethodChannel(SpruceIdChannels.w3c),
        (call) async {
          calls.add((SpruceIdChannels.w3c, call));
          throw PlatformException(code: 'NOT_W3C_SESSION');
        },
      );
      expect(
        await client.completeOID4VPRequestSDK(
          sessionId: 'mdoc-session',
          selectedCredentialId: 'mdl',
        ),
        _result,
      );
      expect(calls.map((call) => call.$1), [
        SpruceIdChannels.w3c,
        SpruceIdChannels.mdoc,
      ]);
      expect(calls.last.$2.arguments, {
        'sessionId': 'mdoc-session',
        'selectedCredentialId': 'mdl',
        'selectedFields': null,
      });
      failure = PlatformException(
        code: 'SESSION_EXPIRED',
        message: 'Start again',
      );
      await expectLater(
        client.completeOID4VPRequestSDK(
          sessionId: 'expired',
          selectedCredentialId: 'mdl',
        ),
        throwsA(
          isA<SpruceIdException>().having(
            (e) => e.code,
            'code',
            'SESSION_EXPIRED',
          ),
        ),
      );
    },
  );

  test(
    'advanced presentation uses validated binding and rejects before native signing',
    () async {
      final client = SpruceIdClientExtended(service);
      final request = {
        'nonce': 'original-nonce',
        'client_id': 'https://verifier.test',
      };
      expect(
        await client.createAdvancedPresentation(
          credentials: [_credential],
          presentationRequest: request,
          selectiveDisclosure: {
            'urn:credential:ob3': ['achievement'],
          },
        ),
        _result,
      );
      expect(jsonDecode(native.contextJson!), request);
      expect(calls.single.$2.arguments['challenge'], 'validated-nonce');
      expect(calls.single.$2.arguments['domain'], 'https://verifier.test');
      native.rejection = StateError('Invalid presentation binding');
      calls.clear();
      await expectLater(
        client.createAdvancedPresentation(
          credentials: [_credential],
          presentationRequest: {},
          selectiveDisclosure: {},
        ),
        throwsStateError,
      );
      expect(calls, isEmpty);
      await expectLater(
        client.handleOID4VCFlow(credentialOffer: 'invalid-offer'),
        throwsStateError,
      );
      expect(native.offer, 'invalid-offer');
      expect(calls, isEmpty);
    },
  );

  test(
    'client initialization options and convenience methods keep SDK boundaries',
    () async {
      final client = SpruceIdClientExtended(service);
      await client.initializeSDK(config: {'storage': 'secure'});
      expect(calls.map((call) => call.$2.method), [
        'initialize',
        'initializeHolderSDK',
      ]);
      expect(calls.last.$2.arguments['config'], {'storage': 'secure'});
      calls.clear();
      await client.initializeSDK(enableAdvancedFeatures: false);
      expect(calls.single.$2.method, 'initialize');
      calls.clear();
      await client.handleOID4VCFlow(credentialOffer: 'raw-offer', pin: '5678');
      expect(native.offer, 'raw-offer');
      expect(calls.single.$2.arguments['pin'], '5678');
      calls.clear();
      expect(await client.getCredentialMetadata('urn:credential:ob3'), _result);
      expect(calls.single.$2.arguments, {'credentialId': 'urn:credential:ob3'});
      await client.enableCredentialMonitoring();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(spruceIdPlatformServiceExtendedProvider),
        same(service),
      );
      expect(
        container.read(spruceIdClientExtendedProvider),
        isA<SpruceIdClientExtended>(),
      );
    },
  );

  test(
    'credential monitoring forwards events, reports errors and closes',
    () async {
      final stream = await service.monitorCredentialStatusSDK(
        'urn:credential:ob3',
      );
      final assertion = expectLater(
        stream,
        emitsInOrder([
          {'id': 'urn:credential:ob3', 'revoked': true},
          emitsError(
            isA<SpruceIdException>().having(
              (e) => e.code,
              'code',
              'MONITOR_ERROR',
            ),
          ),
          emitsDone,
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls.first.$2.method, 'startCredentialMonitoring');
      expect(calls.first.$2.arguments, {'credentialId': 'urn:credential:ob3'});
      expect(calls.last.$2.method, 'listen');
      const codec = StandardMethodCodec();
      await messenger.handlePlatformMessage(
        _monitor,
        codec.encodeSuccessEnvelope({
          'id': 'urn:credential:ob3',
          'revoked': true,
        }),
        (_) {},
      );
      await messenger.handlePlatformMessage(
        _monitor,
        codec.encodeErrorEnvelope(code: 'OFFLINE', message: 'Disconnected'),
        (_) {},
      );
      await messenger.handlePlatformMessage(_monitor, null, (_) {});
      await assertion;
    },
  );

  test('monitor setup failure is emitted to the subscriber', () async {
    failure = PlatformException(code: 'NOT_READY');
    final stream = await service.monitorCredentialStatusSDK(
      'urn:credential:ob3',
    );
    await expectLater(
      stream,
      emitsError(
        isA<SpruceIdException>().having(
          (e) => e.code,
          'code',
          'MONITOR_SETUP_ERROR',
        ),
      ),
    );
  });
}
