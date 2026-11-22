import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_storage_environment.dart' as environment;
import 'browser_storage_inventory.dart';

typedef BrowserStorageLock =
    Future<T> Function<T>(String, Future<T> Function());

/// Native platform storage is unchanged. Web plugin registration has already
/// selected the upstream WebCrypto backend before this application hook runs.
void configureBrowserSecureStorage() {
  if (!kIsWeb ||
      FlutterSecureStoragePlatform.instance is MigratingBrowserStorage) {
    return;
  }
  if (!environment.browserStorageBackendSupported(
    FlutterSecureStoragePlatform.instance,
  )) {
    throw UnsupportedError(
      'The reviewed browser storage backend is unavailable',
    );
  }
  FlutterSecureStoragePlatform.instance = MigratingBrowserStorage(
    FlutterSecureStoragePlatform.instance,
  );
}

/// Move only recognized wallet records from the retired base64 override.
/// Unknown records remain in place; migration never authenticates a credential.
/// New writes use only the upstream backend, with no plaintext fallback.
class MigratingBrowserStorage extends FlutterSecureStoragePlatform {
  MigratingBrowserStorage(
    this.backend, {
    Future<SharedPreferences> Function()? preferences,
    BrowserStorageLock? withLock,
    Future<BrowserStorageInventory> Function(Map<String, String>)? inventory,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _withLock = withLock ?? environment.withBrowserStorageLock,
       _inventory = inventory ?? environment.browserStorageInventory;

  final FlutterSecureStoragePlatform backend;
  final Future<SharedPreferences> Function() _preferences;
  final BrowserStorageLock _withLock;
  final Future<BrowserStorageInventory> Function(Map<String, String>)
  _inventory;
  final Map<String, Future<void>> _tails = {};
  static const _receipt = 'marty:wallet:receipt:';
  static const _pairing = 'marty:remote-holder-enrollment';
  static const _layout = 'card_groups_data';

  static bool _recognized(String key) =>
      key == _pairing ||
      key == _layout ||
      (key.startsWith(_receipt) && key.length > _receipt.length);

  Map<String, String> _options(Map<String, String> options) {
    final database = options['dbName'] ?? 'FlutterEncryptedStorage';
    final publicKey = options['publicKey'] ?? 'FlutterSecureStorage';
    for (final name in [database, publicKey]) {
      if (name.isEmpty || name.length > 256 || name.contains('\u0000')) {
        throw ArgumentError('Browser storage namespace is invalid');
      }
    }
    // Upstream2.1.1 selects storage by publicKey, not dbName. Encode both
    // components unambiguously so different databases cannot share a keyspace.
    final namespace = base64UrlEncode(
      utf8.encode(jsonEncode([database, publicKey])),
    ).replaceAll('=', '');
    return {...options, 'publicKey': 'marty.storage.v1.$namespace'};
  }

  Future<T> _run<T>(
    Map<String, String> options,
    Future<T> Function(Map<String, String>) action,
  ) {
    final target = _options(options);
    final lock =
        '${target['publicKey']}:${options['useSessionStorage'] == 'true'}';
    final result = (_tails[lock] ?? Future<void>.value()).then(
      (_) => _withLock(lock, () async {
        await _checkEncryptedRecords(target);
        await _migrate(options, target);
        return action(target);
      }),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[lock] = tail;
    return result.whenComplete(() {
      if (identical(_tails[lock], tail)) _tails.remove(lock);
    });
  }

  Future<void> _checkEncryptedRecords(Map<String, String> target) async {
    final inventory = await _inventory(target);
    if (inventory.keys.length > 1024 ||
        (inventory.keys.isNotEmpty && !inventory.keyPresent)) {
      // Upstream read can initialize a new key if it is missing. Never do that
      // while old ciphertext exists; preserve it for recovery instead.
      throw StateError('Encrypted browser storage preserved for recovery');
    }
    for (final key in inventory.keys) {
      String? value;
      try {
        value = await backend.read(key: key, options: target);
      } catch (_) {
        throw StateError('Encrypted browser storage could not be opened');
      }
      // Upstream2.1.1 returns null on decrypt failure and readAll omits it.
      // Existing ciphertext must never silently disappear from the wallet.
      if (value == null) {
        throw StateError('Encrypted browser storage could not be opened');
      }
    }
  }

  Future<void> _migrate(
    Map<String, String> options,
    Map<String, String> target,
  ) async {
    // The old override ignored publicKey and session options. Do not assign its
    // persistent records to a new custom key or a session-only store.
    if ((options['publicKey'] ?? 'FlutterSecureStorage') !=
            'FlutterSecureStorage' ||
        options['useSessionStorage'] == 'true') {
      return;
    }
    final prefs = await _preferences();
    await prefs.reload();
    final prefix =
        '__flutter_secure_storage__${options['dbName'] ?? 'FlutterEncryptedStorage'}_';
    final keys =
        prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith(prefix) &&
                  _recognized(key.substring(prefix.length)),
            )
            .toList()
          ..sort();
    if (keys.length > 1024) {
      throw StateError('Legacy wallet storage exceeds migration bounds');
    }
    for (final sourceKey in keys) {
      final original = prefs.get(sourceKey);
      final key = sourceKey.substring(prefix.length);
      final value = _decode(key, original);
      final exists = await backend.containsKey(key: key, options: target);
      if (exists) {
        if (await backend.read(key: key, options: target) != value) {
          throw StateError(
            'Conflicting browser storage preserved for recovery',
          );
        }
      } else {
        await backend.write(key: key, value: value, options: target);
      }
      if (await backend.read(key: key, options: target) != value) {
        throw StateError('Browser storage migration readback failed');
      }
      await prefs.reload();
      if (prefs.get(sourceKey) != original) {
        throw StateError(
          'Changed legacy browser storage preserved for recovery',
        );
      }
      if (!await prefs.remove(sourceKey)) {
        throw StateError(
          'Verified browser storage copy retained; migration incomplete',
        );
      }
    }
  }

  String _decode(String key, Object? encoded) {
    try {
      if (encoded is! String || encoded.length > 2 * 1024 * 1024) {
        throw const FormatException();
      }
      final bytes = base64Decode(encoded);
      if (base64Encode(bytes) != encoded) throw const FormatException();
      final value = utf8.decode(bytes, allowMalformed: false);
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (key.startsWith(_receipt)) {
        if (data['id'] != key.substring(_receipt.length) ||
            data['format'] is! String ||
            data['issuer'] is! String ||
            data['rawJson'] is! String ||
            data['types'] is! List ||
            !(data['types'] as List).every((v) => v is String) ||
            data['issuedAt'] is! String ||
            DateTime.tryParse(data['issuedAt']) == null) {
          throw const FormatException();
        }
      } else if (key == _layout) {
        if (value.length > 64 * 1024 ||
            data['version'] != 1 ||
            data['groups'] is! List ||
            data['expired_ids'] is! List ||
            !(data['expired_ids'] as List).every((v) => v is String) ||
            !(data['groups'] as List).every(
              (v) =>
                  v is Map<String, dynamic> &&
                  v['title'] is String &&
                  v['ids'] is List &&
                  (v['ids'] as List).every((id) => id is String),
            )) {
          throw const FormatException();
        }
      } else if (key == _pairing) {
        if (data['api_origin'] is! String ||
            data['device_credential'] is! String ||
            data['registration_id'] is! String ||
            data['pairing_id'] is! String ||
            data['device_id'] is! String ||
            data['confirmed'] is! bool ||
            data['holder_binding_public_jwk'] is! Map ||
            data['presentation_signing_public_jwk'] is! Map ||
            _hasPrivateField(data)) {
          throw const FormatException();
        }
      }
      return value;
    } catch (_) {
      throw StateError('Invalid legacy wallet storage preserved for recovery');
    }
  }

  bool _hasPrivateField(Object? value) {
    if (value is List) return value.any(_hasPrivateField);
    if (value is! Map) return false;
    return value.entries.any((entry) {
      final key = entry.key.toString().toLowerCase().replaceAll(
        RegExp('[^a-z0-9]'),
        '',
      );
      return {'d', 'p', 'q', 'dp', 'dq', 'qi', 'oth', 'k'}.contains(key) ||
          key.contains('private') ||
          key.contains('secret') ||
          key.contains('seed') ||
          _hasPrivateField(entry.value);
    });
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) => _run(
    options,
    (target) => backend.write(key: key, value: value, options: target),
  );
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) => _run(options, (target) => backend.read(key: key, options: target));
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) =>
      _run(options, (target) => backend.containsKey(key: key, options: target));
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => _run(options, (target) => backend.delete(key: key, options: target));
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _run(options, (target) => backend.readAll(options: target));
  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      _run(options, (target) => backend.deleteAll(options: target));
  @override
  Future<SecureStorageUpgradeStatus> checkUpgradeStatus({
    required Map<String, String> options,
  }) => _run(options, (target) => backend.checkUpgradeStatus(options: target));
}
