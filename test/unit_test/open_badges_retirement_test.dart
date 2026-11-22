import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:marty_authenticator/services/spruce_platform_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_web.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';
import 'package:marty_authenticator/utils/open_badges.dart';
import 'package:marty_authenticator/widgets/spruce_credential_selection_widget.dart';

const ob2 = <String, dynamic>{
  'id': 'urn:badge:retired',
  '@context': 'https://w3id.org/openbadges/v2',
  'type': 'Assertion',
  'badge': {'name': 'Legacy badge'},
};
const ob3 = <String, dynamic>{
  'id': 'urn:badge:current',
  '@context': [
    'https://www.w3.org/ns/credentials/v2',
    'https://w3id.org/openbadges/v3',
  ],
  'type': ['VerifiableCredential', 'OpenBadgeCredential'],
  'issuer': 'https://issuer.example',
  'credentialSubject': {
    'id': 'did:example:learner',
    'achievement': {'name': 'Current badge'},
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'retired raw, mixed and wrapped badges are rejected before generic VCs',
    () {
      final mixed = <String, dynamic>{
        ...ob3,
        '@context': [
          'https://w3id.org/openbadges/v3',
          'https://w3id.org/openbadges/v2',
        ],
      };
      for (final input in [
        ob2,
        mixed,
        {...ob3, 'context': 'https://w3id.org/openbadges/v2'},
        {
          ...ob3,
          'type': ['VerifiableCredential', 'Assertion'],
        },
        {
          ...ob3,
          'type': ['OpenBadgeCredential', 'OpenBadgeV2'],
        },
        {...ob3, 'type': 'open_badge_v2'},
        {...ob3, 'type': 'openbadge-v2'},
        {
          ...ob3,
          'type': ['VerifiableCredential', 'assertion'],
        },
        {'credential': ob2},
        {'assertion': ob2},
        {
          'vp': {
            'verifiableCredential': [ob3, ob2],
          },
        },
      ]) {
        expect(isRetiredOpenBadge(input), isTrue, reason: '$input');
      }
      expect(isRetiredOpenBadge(ob3), isFalse);
      expect(isRetiredOpenBadge({'type': 'VerifiableCredential'}), isFalse);
      expect(isRetiredOpenBadge({'docType': 'org.iso.18013.5.1.mDL'}), isFalse);
    },
  );

  test('legacy JWT contents are inspected only for rejection', () {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${segment({'alg': 'EdDSA'})}.${segment({'vc': ob2})}.c2ln';
    expect(isRetiredOpenBadge(token), isTrue);
    expect(isRetiredOpenBadge('$token~'), isTrue);
    expect(isRetiredOpenBadge('not.a.jwt'), isFalse);
  });

  test(
    'legacy storage cannot promote either raw badge format into a verified receipt',
    () async {
      for (final platform in [
        SpruceIdPlatformService.protected(),
        SpruceIdPlatformServiceWeb(),
      ]) {
        for (final raw in [ob2, ob3]) {
          await expectLater(
            platform.storeCredential(raw),
            throwsA(isA<UnsupportedError>()),
          );
        }
      }
      expect(await WalletCredentialStore.getAll(), isEmpty);
      expect(ob2['type'], 'Assertion');
      expect(ob3['type'], ['VerifiableCredential', 'OpenBadgeCredential']);
    },
  );

  testWidgets(
    'presentation selection excludes legacy records with matching claims',
    (tester) async {
      var selectedIds = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SpruceCredentialSelectionWidget(
                availableCredentials: [
                  {
                    ...ob2,
                    'credentialSubject': {'id': 'did:example:legacy'},
                  },
                  ob3,
                ],
                requestedAttributes: const ['id'],
                onSelectionChanged: (credentials, disclosure) {
                  selectedIds = credentials
                      .map((credential) => credential.id)
                      .toList();
                },
                onPresentationCreate: (credentials, disclosure) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(selectedIds, ['urn:badge:current']);
    },
  );
}
