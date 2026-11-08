import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces_extended.dart';
import 'package:marty_authenticator/model/promotional_credential.dart';
import 'package:marty_authenticator/models/credentials.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/frb_generated.dart';
import 'package:marty_authenticator/services/spruce_client_extended.dart';
import 'package:marty_authenticator/utils/riverpod/providers/credentials_provider.dart';
import 'package:marty_authenticator/utils/riverpod/providers/spruce_providers.dart';

class _Wallet implements ISpruceIdWalletManager {
  List<Map<String, dynamic>> records = [];
  Object? failure;
  int reads = 0;

  @override
  Future<List<Map<String, dynamic>>> getAllCredentials() async {
    reads++;
    if (failure != null) throw failure!;
    return records;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NativeOffers implements RustLibApi {
  String normalized = 'openid-credential-offer://?credential_offer=fixture';
  String? input;
  Object? failure;

  @override
  Future<String> crateApiWalletNormalizeCredentialOffer({
    required String input,
  }) async {
    this.input = input;
    if (failure != null) throw failure!;
    return normalized;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfferClient implements ISpruceIdClientExtended {
  String? offered;
  Object? failure;

  @override
  Future<Map<String, dynamic>> handleOID4VCFlow({
    required String credentialOffer,
    String? pin,
    Map<String, dynamic>? presentationOptions,
  }) async {
    offered = credentialOffer;
    if (failure != null) throw failure!;
    return {'stored': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SdkOfferClient implements SpruceIdClientExtended {
  String? offered;

  @override
  Future<Map<String, dynamic>> handleOID4VCOfferSDK({
    required String credentialOffer,
    String? pin,
    String? keyId,
  }) async {
    offered = credentialOffer;
    return {'stored': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _record(
  String id, {
  dynamic type = 'VerifiableCredential',
}) => {
  'id': id,
  '@context': 'https://www.w3.org/ns/credentials/v2',
  'type': type,
  'issuer': {'id': 'did:web:issuer.test', 'name': 'Issuer'},
  'credentialSubject': {'id': 'did:example:holder', 'name': 'Ada'},
  'issuanceDate': '2026-01-01T00:00:00Z',
};

VerifiableCredential _vc(String id, String issuer, {String? expires}) =>
    VerifiableCredential(
      id: id,
      types: const ['VerifiableCredential'],
      issuer: {'name': issuer},
      credentialSubject: const {'name': 'Ada'},
      issuanceDate: '2020-01-01T00:00:00Z',
      expirationDate: expires,
    );

MDocCredential _mdoc(
  String id,
  String issuer, {
  String type = 'org.iso.18013.5.1.mDL',
  DateTime? expires,
}) => MDocCredential(
  id: id,
  docType: type,
  issuerSigned: {
    'nameSpaces': {
      'org.iso.18013.5.1': {'issuing_authority': issuer},
    },
  },
  deviceSigned: const {},
  expiryDate: expires,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = _NativeOffers();
  setUpAll(() => RustLib.initMock(api: native));
  tearDownAll(RustLib.dispose);
  setUp(() {
    native.normalized = 'openid-credential-offer://?credential_offer=fixture';
    native.input = null;
    native.failure = null;
  });

  Future<ProviderContainer> load(
    _Wallet wallet, {
    ISpruceIdClientExtended? client,
  }) async {
    final container = ProviderContainer(
      overrides: [
        spruceIdWalletManagerProvider.overrideWithValue(wallet),
        if (client != null)
          spruceIdClientExtendedProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    container.read(credentialsProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test(
    'wallet parsing preserves supported formats and skips malformed records independently',
    () async {
      final issue = DateTime.utc(2026, 1, 1);
      final wallet = _Wallet()
        ..records = [
          {
            ..._record('vc'),
            'proof': {'type': 'DataIntegrityProof'},
            'credentialStatus': {'id': 'status'},
            'expirationDate': '2100-01-01',
          },
          {..._record('default-type', type: 17), 'issuer': null},
          {
            ..._record('list-type', type: ['VerifiableCredential']),
            'issuer': 'did:web:issuer.test',
            '@context': ['https://www.w3.org/ns/credentials/v2'],
          },
          {
            ..._record('achievement', type: 'AchievementCredential'),
            'credentialSubject': {
              'recipient': {'identity': 'Learner'},
              'achievement': {'name': 'Course', 'description': 'Completed'},
            },
          },
          {
            ..._record('context-badge', type: 'Badge'),
            '@context': 'https://purl.imsglobal.org/spec/ob/v3p0/context.json',
            'credentialSubject': 'malformed-subject',
          },
          {..._record('malformed'), 'proof': 'not-a-map'},
          {
            'docType': 'org.iso.18013.5.1.mDL',
            'issuerSigned': {},
            'issueDate': issue,
            'expiryDate': '2100-01-01',
            'portrait': 'portrait',
          },
          {
            'docType': 'date-fallback',
            'deviceSigned': {},
            'issueDate': 'invalid-date',
            'expiryDate': 42,
          },
          {'docType': 'invalid-mdoc', 'issuerSigned': 'not-a-map'},
          {'unrecognized': true},
        ];
      final container = await load(wallet);
      final state = container.read(credentialsProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      final parsed = {for (final c in state.verifiableCredentials) c.id: c};
      expect(parsed['vc']!.proof, {'type': 'DataIntegrityProof'});
      expect(parsed['vc']!.credentialStatus, {'id': 'status'});
      expect(parsed['default-type']!.types, ['VerifiableCredential']);
      expect(parsed['default-type']!.issuer, {'id': 'unknown:issuer'});
      expect(parsed['list-type']!.issuer, {'id': 'did:web:issuer.test'});
      expect(parsed['achievement']!.types, [
        'AchievementCredential',
        'VerifiableCredential',
      ]);
      expect(parsed['achievement']!.credentialSubject['name'], 'Learner');
      expect(
        parsed['achievement']!.credentialSubject['badge_description'],
        'Completed',
      );
      expect(parsed['context-badge']!.credentialSubject, {'name': null});
      expect(parsed, isNot(contains('malformed')));
      final actualMdoc = state.mDocCredentials.firstWhere(
        (c) => c.portrait == 'portrait',
      );
      expect(actualMdoc.issueDate, issue);
      expect(actualMdoc.expiryDate, DateTime(2100));
      final fallback = state.mDocCredentials.firstWhere(
        (c) => c.docType == 'date-fallback',
      );
      expect(fallback.issueDate, isNull);
      expect(fallback.expiryDate, isNull);
      expect(
        state.mDocCredentials.where((c) => c.docType == 'invalid-mdoc'),
        isEmpty,
      );
    },
  );

  test(
    'state groups active credentials by issuer with promotions and holder documents first',
    () {
      final now = DateTime.now();
      const promo = PromotionalCredential(
        id: 'active',
        title: 'Title',
        subtitle: 'Sub',
        description: 'Info',
        icon: Icons.info,
        gradientColors: [Colors.blue],
      );
      final state = CredentialsState(
        verifiableCredentials: [
          _vc('same', 'Z Holder'),
          _vc('a', 'A Other'),
          _vc('b', 'B Other'),
          _vc('expired', 'Expired', expires: '2000-01-01'),
        ],
        mDocCredentials: [
          _mdoc('z', 'Z Holder'),
          _mdoc('a', 'A Holder', type: 'org.iso.18013.5.1.mID'),
          _mdoc('custom', 'A Other', type: 'custom'),
          _mdoc(
            'expired',
            'Expired',
            expires: now.subtract(const Duration(days: 1)),
          ),
        ],
        promotionalCredentials: [
          promo,
          promo.copyWith(id: 'dismissed', isDismissed: true),
          promo.copyWith(
            id: 'expired',
            expiresAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      );
      expect(CredentialsState().hasCredentials, isFalse);
      expect(CredentialsState().totalCredentials, 0);
      expect(state.hasCredentials, isTrue);
      expect(state.totalCredentials, 11);
      final groups = state.groupedCredentials;
      expect(groups.map((g) => g.issuerName), [
        'PrivacyIDEA Wallet',
        'A Holder',
        'Z Holder',
        'A Other',
        'B Other',
      ]);
      expect(groups.first.promotionalCredentials.map((p) => p.id), ['active']);
      expect(groups[2].verifiableCredentials.single.id, 'same');
      expect(groups[2].mDocCredentials.single.id, 'z');
      expect(groups[3].totalCount, 2);
      final loading = state.copyWith(isLoading: true, error: 'pending');
      expect(loading.totalCredentials, state.totalCredentials);
      expect(loading.isLoading, isTrue);
      expect(loading.error, 'pending');
    },
  );

  test(
    'wallet failure remains visible and a later refresh restores real records',
    () async {
      final wallet = _Wallet()..failure = StateError('offline');
      final container = await load(wallet);
      expect(container.read(credentialsProvider).error, contains('offline'));
      expect(container.read(credentialsProvider).isLoading, isFalse);
      wallet.failure = null;
      wallet.records = [_record('recovered')];
      await container.read(credentialsProvider.notifier).refreshCredentials();
      final recovered = container.read(credentialsProvider);
      expect(recovered.error, isNull);
      expect(
        recovered.verifiableCredentials.map((c) => c.id),
        contains('recovered'),
      );
      expect(wallet.reads, 2);
    },
  );

  test(
    'local add/remove and promotion dismissal preserve other credentials',
    () async {
      final container = await load(_Wallet());
      final notifier = container.read(credentialsProvider.notifier);
      final original = container.read(credentialsProvider);
      final credential = _vc('added', 'Local Issuer');
      await notifier.addVerifiableCredential(credential);
      await notifier.addMDocCredential(_mdoc('new-mdoc', 'Local Authority'));
      expect(
        container.read(credentialsProvider).totalCredentials,
        original.totalCredentials + 2,
      );
      await notifier.removeVerifiableCredential('added');
      expect(
        container.read(credentialsProvider).verifiableCredentials,
        original.verifiableCredentials,
      );
      expect(
        container.read(credentialsProvider).mDocCredentials.last.id,
        'new-mdoc',
      );
      notifier.dismissPromotionalCard('welcome');
      notifier.dismissPromotionalCard('missing');
      final promos = container.read(credentialsProvider).promotionalCredentials;
      expect(promos.singleWhere((p) => p.id == 'welcome').isDismissed, isTrue);
      expect(promos.where((p) => p.isDismissed).length, 1);
    },
  );

  test(
    'normalized offers reach concrete SDK and interface clients then reload wallet state',
    () async {
      for (final client in <ISpruceIdClientExtended>[
        _SdkOfferClient(),
        _OfferClient(),
      ]) {
        final wallet = _Wallet();
        final container = await load(wallet, client: client);
        final handled = await container
            .read(credentialsProvider.notifier)
            .handleCredentialOffer('https://issuer.test/offer');
        expect(handled, isTrue);
        expect(native.input, 'https://issuer.test/offer');
        expect(
          client is _SdkOfferClient
              ? client.offered
              : (client as _OfferClient).offered,
          native.normalized,
        );
        expect(wallet.reads, 2);
        expect(container.read(credentialsProvider).isLoading, isFalse);
      }
    },
  );

  test(
    'invalid, unsupported, native-rejected and failed offers do not report success',
    () async {
      final client = _OfferClient();
      final wallet = _Wallet();
      final container = await load(wallet, client: client);
      final notifier = container.read(credentialsProvider.notifier);
      expect(await notifier.handleCredentialOffer('http://['), isFalse);
      expect(native.input, isNull);
      native.normalized = 'https://issuer.test/not-an-offer';
      expect(
        await notifier.handleCredentialOffer('https://issuer.test/input'),
        isFalse,
      );
      expect(client.offered, isNull);
      native.failure = StateError('bad native offer');
      expect(
        await notifier.handleCredentialOffer('https://issuer.test/input'),
        isFalse,
      );
      expect(
        container.read(credentialsProvider).error,
        contains('bad native offer'),
      );
      native.failure = null;
      native.normalized = 'openid-vc://offer';
      client.failure = StateError('issuer unavailable');
      expect(
        await notifier.handleCredentialOffer('https://issuer.test/input'),
        isFalse,
      );
      expect(
        container.read(credentialsProvider).error,
        contains('does not support OID4VC offer handling'),
      );
      expect(container.read(credentialsProvider).isLoading, isFalse);
      expect(wallet.reads, 1);
    },
  );
}
