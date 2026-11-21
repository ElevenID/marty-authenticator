import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/views/main_view/document_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marty_authenticator/services/browser_storage_migration.dart';
import 'package:marty_authenticator/services/browser_storage_inventory.dart';

const options = <String, String>{
  'dbName': 'FlutterEncryptedStorage',
  'publicKey': 'FlutterSecureStorage',
  'wrapKey': '',
  'wrapKeyIv': '',
  'useSessionStorage': 'false',
};
const legacyPrefix = '__flutter_secure_storage__FlutterEncryptedStorage_';
const receiptPrefix = 'marty:wallet:receipt:';

Future<T> unlocked<T>(String _, Future<T> Function() action) => action();

String receipt(String id) => jsonEncode({
  'id': id,
  'format': 'dc+sd-jwt',
  'issuer': 'did:web:synthetic.example',
  'types': ['SyntheticIdentity'],
  'rawJson': 'synthetic-unverified-storage-value',
  'issuedAt': '2026-11-16T00:00:00Z',
});
String encoded(String value) => base64Encode(utf8.encode(value));

/// Controlled failure adapter, not WebCrypto/browser acceptance.
class Storage extends FlutterSecureStoragePlatform {
  final values = <String, String>{};
  int writes = 0;
  int? failWrite;
  bool wrongReadback = false;
  bool unavailable = false;
  bool missingKey = false;
  int reads = 0;
  Future<void> Function()? onRead;
  String name(String key, Map<String, String> options) =>
      '${options['publicKey']}:${options['useSessionStorage']}:$key';
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    writes++;
    if (writes == failWrite) throw StateError('controlled write failure');
    values[name(key, options)] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    reads++;
    await onRead?.call();
    return wrongReadback ? null : values[name(key, options)];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(name(key, options));
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => values.remove(name(key, options));
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    if (unavailable) throw StateError('controlled storage unavailable');
    final prefix = name('', options);
    return {
      for (final entry in values.entries)
        if (entry.key.startsWith(prefix))
          entry.key.substring(prefix.length): entry.value,
    };
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.removeWhere((key, _) => key.startsWith(name('', options)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Storage backend;
  late MigratingBrowserStorage storage;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = Storage();
    storage = MigratingBrowserStorage(
      backend,
      withLock: unlocked,
      inventory: (target) async => BrowserStorageInventory(
        keys: backend.values.keys
            .where((key) => key.startsWith(backend.name('', target)))
            .map((key) => key.substring(backend.name('', target).length))
            .toList(),
        keyPresent: !backend.missingKey,
      ),
    );
  });

  test(
    'copies Unicode receipt and layout, verifies readback and preserves unrelated data',
    () async {
      final value = receipt('識別🪪');
      await prefs.setString('$legacyPrefix$receiptPrefix識別🪪', encoded(value));
      final layout = jsonEncode({
        'version': 1,
        'groups': [
          {
            'title': '身分',
            'ids': ['識別🪪'],
          },
        ],
        'expired_ids': <String>[],
      });
      await prefs.setString('${legacyPrefix}card_groups_data', encoded(layout));
      await prefs.setString('unrelated-preference', 'keep');
      await prefs.setString(
        '${legacyPrefix}retired-raw-import',
        'keep-original',
      );
      final result = await storage.readAll(options: options);
      expect(result, {'$receiptPrefix識別🪪': value, 'card_groups_data': layout});
      expect(prefs.getString('$legacyPrefix$receiptPrefix識別🪪'), isNull);
      expect(prefs.getString('${legacyPrefix}card_groups_data'), isNull);
      expect(prefs.getString('unrelated-preference'), 'keep');
      expect(
        prefs.getString('${legacyPrefix}retired-raw-import'),
        'keep-original',
      );
      expect(await storage.readAll(options: options), result);
      expect(backend.writes, 2);
    },
  );

  test('write failure retains the exact legacy original', () async {
    final source = '$legacyPrefix${receiptPrefix}a';
    final original = encoded(receipt('a'));
    await prefs.setString(source, original);
    backend.failWrite = 1;
    await expectLater(storage.readAll(options: options), throwsStateError);
    expect(prefs.getString(source), original);
    expect(backend.values, isEmpty);
    backend.failWrite = null;
    expect((await storage.readAll(options: options)).length, 1);
    expect(prefs.getString(source), isNull);
  });

  test(
    'failed readback cannot retire an original and resume verifies the existing copy',
    () async {
      final source = '$legacyPrefix${receiptPrefix}a';
      final original = encoded(receipt('a'));
      await prefs.setString(source, original);
      backend.wrongReadback = true;
      await expectLater(storage.readAll(options: options), throwsStateError);
      expect(prefs.getString(source), original);
      backend.wrongReadback = false;
      expect(
        await storage.read(key: '${receiptPrefix}a', options: options),
        receipt('a'),
      );
      expect(backend.writes, 1);
      expect(prefs.getString(source), isNull);
    },
  );

  test('partial migration is resumable without losing either record', () async {
    for (final id in ['a', 'b']) {
      await prefs.setString(
        '$legacyPrefix$receiptPrefix$id',
        encoded(receipt(id)),
      );
    }
    backend.failWrite = 2;
    await expectLater(storage.readAll(options: options), throwsStateError);
    expect(prefs.getString('$legacyPrefix${receiptPrefix}a'), isNull);
    expect(
      prefs.getString('$legacyPrefix${receiptPrefix}b'),
      encoded(receipt('b')),
    );
    expect(backend.values.values.single, receipt('a'));
    backend.failWrite = null;
    expect((await storage.readAll(options: options)).keys.toSet(), {
      '${receiptPrefix}a',
      '${receiptPrefix}b',
    });
    expect(backend.writes, 3);
  });

  test(
    'conflicting destination and concurrently changed source are both preserved',
    () async {
      final key = '${receiptPrefix}a';
      await storage.write(key: key, value: 'newer-value', options: options);
      await prefs.setString('$legacyPrefix$key', encoded(receipt('a')));
      await expectLater(
        storage.read(key: key, options: options),
        throwsStateError,
      );
      expect(backend.values.values.single, 'newer-value');
      expect(prefs.getString('$legacyPrefix$key'), encoded(receipt('a')));
      backend.values.clear();
      backend.onRead = () async =>
          prefs.setString('$legacyPrefix$key', 'changed-original');
      await expectLater(storage.readAll(options: options), throwsStateError);
      expect(prefs.getString('$legacyPrefix$key'), 'changed-original');
      expect(backend.values.values.single, receipt('a'));
    },
  );

  test(
    'malformed, raw plaintext and ID-substituted originals have no fallback',
    () async {
      for (final original in [
        'bad-base64!',
        receipt('a'),
        encoded(receipt('different')),
        encoded('[]'),
        'wyg=',
      ]) {
        await prefs.setString('$legacyPrefix${receiptPrefix}a', original);
        await expectLater(storage.readAll(options: options), throwsStateError);
        expect(prefs.getString('$legacyPrefix${receiptPrefix}a'), original);
        expect(backend.values, isEmpty);
      }
    },
  );

  test(
    'database, public-key and session namespaces remain isolated on deleteAll',
    () async {
      for (final opt in [
        options,
        {...options, 'dbName': 'other'},
        {...options, 'publicKey': 'other'},
        {...options, 'useSessionStorage': 'true'},
      ]) {
        await storage.write(
          key: 'sentinel',
          value: jsonEncode(opt),
          options: opt,
        );
      }
      await storage.deleteAll(options: options);
      expect(await storage.readAll(options: options), isEmpty);
      expect(backend.values.length, 3);
    },
  );

  test(
    'custom keys and session stores cannot consume persistent legacy records',
    () async {
      final source = '$legacyPrefix${receiptPrefix}a';
      await prefs.setString(source, encoded(receipt('a')));
      for (final opt in [
        {...options, 'publicKey': 'custom'},
        {...options, 'useSessionStorage': 'true'},
      ]) {
        expect(await storage.readAll(options: opt), isEmpty);
        await storage.deleteAll(options: opt);
        expect(prefs.getString(source), encoded(receipt('a')));
      }
      expect(backend.writes, 0);
    },
  );

  test(
    'database prefix collisions and unknown old imports are not promoted',
    () async {
      await prefs.setString(
        '${legacyPrefix}other_card_groups_data',
        encoded('{}'),
      );
      await prefs.setString(
        '${legacyPrefix}wallet_credential_ids',
        encoded('["old"]'),
      );
      expect(await storage.readAll(options: options), isEmpty);
      expect(prefs.getKeys().length, 2);
      expect(backend.values, isEmpty);
    },
  );

  test(
    'concurrent new-client operations cannot resurrect a deleted legacy receipt',
    () async {
      await prefs.setString(
        '$legacyPrefix${receiptPrefix}a',
        encoded(receipt('a')),
      );
      await Future.wait([
        storage.readAll(options: options),
        storage.delete(key: '${receiptPrefix}a', options: options),
        storage.write(
          key: '${receiptPrefix}b',
          value: receipt('b'),
          options: options,
        ),
      ]);
      expect((await storage.readAll(options: options)).keys, [
        '${receiptPrefix}b',
      ]);
      expect(prefs.getString('$legacyPrefix${receiptPrefix}a'), isNull);
    },
  );

  test(
    'private recovery material in a pairing record is preserved, never imported',
    () async {
      final pairing = jsonEncode({
        'api_origin': 'https://synthetic.example',
        'device_credential': 'synthetic-token',
        'registration_id': 'synthetic-registration',
        'pairing_id': 'synthetic-pairing',
        'device_id': 'synthetic-device',
        'confirmed': true,
        'holder_binding_public_jwk': {'kty': 'OKP'},
        'presentation_signing_public_jwk': {
          'kty': 'EC',
          'private_key': 'synthetic-rejected-value',
        },
      });
      final source = '${legacyPrefix}marty:remote-holder-enrollment';
      await prefs.setString(source, encoded(pairing));
      await expectLater(storage.readAll(options: options), throwsStateError);
      expect(prefs.getString(source), encoded(pairing));
      expect(backend.values, isEmpty);
    },
  );

  test(
    'unavailable secure-context lock touches neither source nor destination',
    () async {
      await prefs.setString(
        '$legacyPrefix${receiptPrefix}a',
        encoded(receipt('a')),
      );
      final guarded = MigratingBrowserStorage(backend, withLock: denied);
      await expectLater(
        guarded.deleteAll(options: options),
        throwsUnsupportedError,
      );
      expect(prefs.getKeys().length, 1);
      expect(backend.values, isEmpty);
    },
  );
  test(
    'the wallet surfaces a recoverable storage failure and clears it after retry',
    () async {
      final source = '$legacyPrefix${receiptPrefix}malformed';
      await prefs.setString(source, 'malformed-original');
      final previous = FlutterSecureStoragePlatform.instance;
      FlutterSecureStoragePlatform.instance = storage;
      final container = ProviderContainer();
      try {
        await container.read(cardStateProvider.notifier).refreshCards();
        expect(container.read(walletStorageUnavailableProvider), isTrue);
        expect(prefs.getString(source), 'malformed-original');
        await prefs.remove(source);
        await container.read(cardStateProvider.notifier).refreshCards();
        expect(container.read(walletStorageUnavailableProvider), isFalse);
        expect(container.read(cardStateProvider), isEmpty);
      } finally {
        container.dispose();
        FlutterSecureStoragePlatform.instance = previous;
      }
    },
  );
  testWidgets('the wallet retry action recovers without a destructive reset', (
    tester,
  ) async {
    final previous = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = storage;
    backend.unavailable = true;
    final container = ProviderContainer();
    try {
      await container.read(cardStateProvider.notifier).refreshCards();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DocumentView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your wallet storage could not be opened. Your existing data has been kept.',
        ),
        findsOneWidget,
      );
      backend.unavailable = false;
      await tester.tap(find.text('Retry opening wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Retry opening wallet'), findsNothing);
      expect(container.read(walletStorageUnavailableProvider), isFalse);
      expect(backend.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      container.dispose();
      FlutterSecureStoragePlatform.instance = previous;
    }
  });
  test(
    'missing encryption key blocks reads, writes and deletes before backend access',
    () async {
      await storage.write(
        key: '${receiptPrefix}a',
        value: receipt('a'),
        options: options,
      );
      final original = Map<String, String>.of(backend.values);
      backend.missingKey = true;
      final reads = backend.reads;
      await expectLater(storage.readAll(options: options), throwsStateError);
      await expectLater(
        storage.write(
          key: '${receiptPrefix}a',
          value: 'replacement',
          options: options,
        ),
        throwsStateError,
      );
      await expectLater(storage.deleteAll(options: options), throwsStateError);
      expect(backend.values, original);
      expect(backend.reads, reads);
      expect(backend.writes, 1);
      backend.missingKey = false;
      expect(
        await storage.read(key: '${receiptPrefix}a', options: options),
        receipt('a'),
      );
    },
  );
  test(
    'silent upstream decrypt failure becomes an explicit preserved-data error',
    () async {
      await storage.write(
        key: '${receiptPrefix}a',
        value: receipt('a'),
        options: options,
      );
      final original = Map<String, String>.of(backend.values);
      backend.wrongReadback = true;
      await expectLater(storage.readAll(options: options), throwsStateError);
      expect(backend.values, original);
      expect(backend.writes, 1);
      backend.wrongReadback = false;
      expect(
        (await storage.readAll(options: options)).values.single,
        receipt('a'),
      );
    },
  );
}

Future<T> denied<T>(String _, Future<T> Function() action) =>
    Future.error(UnsupportedError('controlled unavailable browser'));
