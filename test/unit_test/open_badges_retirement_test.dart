import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/interfaces/spruce_interfaces.dart';
import 'package:marty_authenticator/utils/open_badges.dart';
import 'package:marty_authenticator/utils/riverpod/providers/credentials_provider.dart';
import 'package:marty_authenticator/utils/riverpod/providers/spruce_providers.dart';

const ob2 = <String, dynamic>{
  'id': 'urn:badge:retired',
  '@context': 'https://w3id.org/openbadges/v2',
  'type': 'Assertion',
  'badge': {'name': 'Legacy badge'},
};
const ob3 = <String, dynamic>{
  'id': 'urn:badge:current',
  '@context': ['https://www.w3.org/ns/credentials/v2', 'https://w3id.org/openbadges/v3'],
  'type': ['VerifiableCredential', 'OpenBadgeCredential'],
  'issuer': 'https://issuer.example',
  'credentialSubject': {
    'id': 'did:example:learner',
    'achievement': {'name': 'Current badge'},
  },
};

class _Wallet implements ISpruceIdWalletManager {
  final List<Map<String, dynamic>> credentials;
  _Wallet(this.credentials);

  @override
  Future<List<Map<String, dynamic>>> getAllCredentials() async => credentials;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retired raw, mixed and wrapped badges are rejected before generic VCs', () {
    final mixed = <String, dynamic>{
      ...ob3,
      '@context': ['https://w3id.org/openbadges/v3', 'https://w3id.org/openbadges/v2'],
    };
    for (final input in [
      ob2,
      mixed,
      {...ob3, 'context': 'https://w3id.org/openbadges/v2'},
      {...ob3, 'type': ['VerifiableCredential', 'Assertion']},
      {'credential': ob2},
      {'assertion': ob2},
      {'vp': {'verifiableCredential': [ob3, ob2]}},
    ]) {
      expect(isRetiredOpenBadge(input), isTrue, reason: '$input');
    }
    expect(isRetiredOpenBadge(ob3), isFalse);
    expect(isRetiredOpenBadge({'type': 'VerifiableCredential'}), isFalse);
    expect(isRetiredOpenBadge({'docType': 'org.iso.18013.5.1.mDL'}), isFalse);
  });

  test('legacy JWT contents are inspected only for rejection', () {
    String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${segment({'alg': 'EdDSA'})}.${segment({'vc': ob2})}.c2ln';
    expect(isRetiredOpenBadge(token), isTrue);
    expect(isRetiredOpenBadge('$token~'), isTrue);
    expect(isRetiredOpenBadge('not.a.jwt'), isFalse);
  });

  test('wallet preserves OB3 and refuses to relabel legacy assertions', () async {
    final container = ProviderContainer(overrides: [
      spruceIdWalletManagerProvider.overrideWithValue(_Wallet([ob2, ob3])),
    ]);
    addTearDown(container.dispose);
    container.read(credentialsProvider);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(credentialsProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, retiredOpenBadgesMessage);
    expect(state.verifiableCredentials.where((vc) => vc.id == ob2['id']), isEmpty);
    final current = state.verifiableCredentials.singleWhere((vc) => vc.id == ob3['id']);
    expect(current.types, contains('OpenBadgeCredential'));
    expect(current.credentialSubject['badge_name'], 'Current badge');
    expect(current.proof, isNull);
  });
}
