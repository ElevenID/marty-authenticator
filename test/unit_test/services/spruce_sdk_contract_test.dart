import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces_extended.dart';
import 'package:marty_authenticator/services/spruce_client_extended.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/services/verified_wallet_bridge.dart';
import 'package:marty_authenticator/utils/spruce_channels.dart';

const _receipt = <String, dynamic>{
  'id': 'verified-receipt',
  'format': 'dc+sd-jwt',
  'issuer': 'https://issuer.test',
};

class _BoundWalletPlatform implements ISpruceIdPlatformServiceExtended {
  bool initialized = false;
  Map<String, dynamic>? received;
  Object? rejection;
  final selection = UserSelectionRequiredException(
    sessionId: 'selection-session',
    matches: const [
      {'id': 'verified-receipt'},
    ],
    requestDetails: const {'verifier': 'https://verifier.test'},
  );

  @override
  bool get isInitialized => initialized;

  @override
  Future<void> initializeW3C() async {
    if (rejection != null) throw rejection!;
    initialized = true;
  }

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
  }) async {
    received = {'offer': credentialOffer, 'pin': pin};
    if (rejection != null) throw rejection!;
    return _receipt;
  }

  @override
  Future<Map<String, dynamic>> initiateOID4VPRequestSDK({
    required String presentationRequest,
  }) async {
    received = {'request': presentationRequest};
    if (rejection != null) throw rejection!;
    throw selection;
  }

  @override
  Future<Map<String, dynamic>> completeOID4VPRequestSDK({
    required String sessionId,
    required String selectedCredentialId,
    List<String>? selectedFields,
  }) async {
    received = {
      'session': sessionId,
      'credential': selectedCredentialId,
      'fields': selectedFields,
    };
    if (rejection != null) throw rejection!;
    return {'ok': true, 'redirect_uri': 'https://verifier.test/done'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedBridge implements VerifiedWalletBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unsupported SDK operation reached the Rust bridge');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('client preserves the approved offer and transaction code', () async {
    final platform = _BoundWalletPlatform();
    final client = SpruceIdClientExtended(platform);
    expect(
      await client.handleOID4VCOfferSDK(
        credentialOffer: 'openid-credential-offer://approved',
        pin: '1234',
      ),
      _receipt,
    );
    expect(platform.received, {
      'offer': 'openid-credential-offer://approved',
      'pin': '1234',
    });
    expect(
      await client.handleOID4VCFlow(
        credentialOffer: 'openid-credential-offer://second',
      ),
      _receipt,
    );
    expect(platform.received, {
      'offer': 'openid-credential-offer://second',
      'pin': null,
    });
  });

  test(
    'client preserves the selection session and explicit disclosure approval',
    () async {
      final platform = _BoundWalletPlatform();
      final client = SpruceIdClientExtended(platform);
      await expectLater(
        client.initiateOID4VPRequestSDK(
          presentationRequest: 'openid4vp://request',
        ),
        throwsA(same(platform.selection)),
      );
      expect(platform.received, {'request': 'openid4vp://request'});
      expect(
        await client.completeOID4VPRequestSDK(
          sessionId: platform.selection.sessionId,
          selectedCredentialId: 'verified-receipt',
          selectedFields: ['credential/given_name'],
        ),
        {'ok': true, 'redirect_uri': 'https://verifier.test/done'},
      );
      expect(platform.received, {
        'session': 'selection-session',
        'credential': 'verified-receipt',
        'fields': ['credential/given_name'],
      });
    },
  );

  test(
    'rejected receipt and presentation errors reach the caller unchanged',
    () async {
      final platform = _BoundWalletPlatform();
      final client = SpruceIdClientExtended(platform);
      final failure = StateError('Remote proof was rejected');
      platform.rejection = failure;
      for (final invoke in <Future<dynamic> Function()>[
        () => client.handleOID4VCOfferSDK(
          credentialOffer: 'openid-credential-offer://approved',
        ),
        () => client.initiateOID4VPRequestSDK(
          presentationRequest: 'openid4vp://request',
        ),
        () => client.completeOID4VPRequestSDK(
          sessionId: 'selection-session',
          selectedCredentialId: 'verified-receipt',
          selectedFields: ['credential/given_name'],
        ),
      ]) {
        await expectLater(invoke(), throwsA(same(failure)));
      }
    },
  );

  test(
    'client provider uses its injected platform without choosing a local key',
    () async {
      final platform = _BoundWalletPlatform();
      final container = ProviderContainer(
        overrides: [
          spruceIdPlatformServiceExtendedProvider.overrideWithValue(platform),
        ],
      );
      addTearDown(container.dispose);
      final client = container.read(spruceIdClientExtendedProvider);
      await client.initializeSDK(enableAdvancedFeatures: false);
      expect(platform.isInitialized, isTrue);
      expect(
        await client.handleOID4VCOfferSDK(
          credentialOffer: 'openid-credential-offer://approved',
        ),
        _receipt,
      );
      await expectLater(
        client.initializeSDK(config: {'keyId': 'caller-selected-key'}),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );

  // These operations still have interface methods for callers to receive an
  // explicit unsupported result. A successful native-channel stub must not
  // turn an unimplemented custody or verification path into success.
  final unsupported =
      <String, Future<dynamic> Function(SpruceIdPlatformServiceExtended)>{
        'credential batch': (s) =>
            SpruceIdClientExtended(s).batchProcessCredentialsSDK(
              operations: [
                {
                  'verify': {'id': 'credential'},
                },
              ],
            ),
        'credential capabilities': (s) => SpruceIdClientExtended(
          s,
        ).getCredentialCapabilitiesSDK('credential'),
        'credential validation': (s) =>
            SpruceIdClientExtended(s).validateCredentialSDK(
              credential: {'id': 'credential'},
              schemaId: 'schema',
              policies: ['issuer-trust'],
            ),
        'advanced SD-JWT creation': (s) => s.createAdvancedSdJwtSDK(
          issuer: 'https://issuer.test',
          claims: {'age': 25},
          disclosureTree: {'age': true},
        ),
        'unbound SD-JWT presentation': (s) => s.presentSdJwtSDK(
          sdJwt: 'signed.jwt~disclosure~',
          disclosureRequest: {'age': true},
          challenge: 'nonce',
        ),
        'SD-JWT presentation verification': (s) => s.verifySdJwtPresentationSDK(
          presentation: 'signed.vp',
          requiredClaims: ['age'],
        ),
        'mobile document initialization': (s) =>
            s.initializeMdocSDK(mdocData: {'docType': 'org.iso.18013.5.1.mDL'}),
        'mobile document OID4VP': (s) =>
            s.handleMdocOid4vpRequestSDK(requestUrl: 'openid4vp://request'),
        'mobile document presentation': (s) => s.createMdocPresentationSDK(
          docType: 'org.iso.18013.5.1.mDL',
          requestedAttributes: ['age_over_18'],
          hiddenAttributes: ['birth_date'],
        ),
        'mobile document session': (s) =>
            s.establishMdocSessionSDK(sessionRequest: {'nonce': 'nonce'}),
        'credential monitoring': (s) =>
            s.monitorCredentialStatusSDK('credential'),
        'credential refresh': (s) =>
            s.refreshCredentialSDK(credentialId: 'credential'),
        'credential backup': (s) =>
            s.backupCredentialsSDK(backupPassphrase: 'unused'),
        'credential restore': (s) => s.restoreCredentialsSDK(
          backupData: 'unverified',
          backupPassphrase: 'unused',
        ),
        'credential sync': (s) => SpruceIdClientExtended(
          s,
        ).syncCredentialsSDK(syncEndpoint: 'https://sync.test'),
        'credential export': (s) =>
            SpruceIdClientExtended(s).exportCredentialsSDK(
              credentialIds: ['credential'],
              exportFormat: 'json',
            ),
        'credential import': (s) => SpruceIdClientExtended(
          s,
        ).importCredentialsSDK(credentialData: 'unverified'),
      };
  for (final entry in unsupported.entries) {
    test(
      '${entry.key} rejects before Rust, signer or native-channel dispatch',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <MethodCall>[];
        const channels = [
          SpruceIdChannels.w3c,
          SpruceIdChannels.jwt,
          SpruceIdChannels.mdoc,
          SpruceIdChannels.wallet,
          'spruce_id_sdk',
          'spruce_id_credential_monitor',
        ];
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), (
            call,
          ) async {
            calls.add(call);
            return {'ok': true};
          });
        }
        addTearDown(() {
          for (final channel in channels) {
            messenger.setMockMethodCallHandler(MethodChannel(channel), null);
          }
        });
        final service = SpruceIdPlatformServiceExtended.withDependencies(
          _UnusedBridge(),
          () => throw StateError(
            'Unsupported SDK operation requested holder custody',
          ),
        );
        await expectLater(
          entry.value(service),
          throwsA(isA<UnsupportedError>()),
        );
        expect(calls, isEmpty);
      },
    );
  }
}
