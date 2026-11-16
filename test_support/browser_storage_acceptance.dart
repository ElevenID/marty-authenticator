/// Executed only on a nonce-marked fresh loopback origin by the owned browser
/// qualification runner. Synthetic storage values do not qualify credentials.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/browser_storage_migration.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

const _legacy = '__flutter_secure_storage__FlutterEncryptedStorage_';
const _receipt = 'marty:wallet:receipt:';
const _pairing = 'marty:remote-holder-enrollment';
const _marker = 'marty-owned-browser-qualification';
const _unrelated = 'marty-browser-synthetic-unrelated';
const _ids = ['storage-a', '識別🪪'];
const _issuer = 'did:web:synthetic-browser.example';
const _raw = 'synthetic-storage-only-not-a-verified-credential';
const _storage = FlutterSecureStorage();

StoredCredential _value(String id) => StoredCredential(
  id: id,
  format: 'dc+sd-jwt',
  issuer: _issuer,
  types: const ['SyntheticIdentity'],
  rawJson: _raw,
  issuedAt: DateTime.utc(2026, 11, 16),
);
void require(bool value) {
  if (!value) throw StateError('Owned browser storage assertion failed');
}

String encode(String value) => base64Encode(utf8.encode(value));

Future<void> _readConsumers() async {
  final receipts = await WalletCredentialStore.getAll();
  require(receipts.length == 2);
  require(receipts.map((v) => v.id).toSet().containsAll(_ids));
  require(receipts.every((v) => v.rawJson == _raw && v.issuer == _issuer));
  final container = ProviderContainer();
  try {
    await container.read(cardStateProvider.notifier).refreshCards();
    final groups = container.read(cardStateProvider);
    require(groups.length == 1 && groups.single.title == _issuer);
    require(
      groups.single.cards.map((v) => v.id).join('|') == _ids.reversed.join('|'),
    );
    require(
      groups.single.cards.last.isExpired &&
          !groups.single.cards.first.isExpired,
    );
    await container.read(cardStateProvider.notifier).saveCards();
  } finally {
    container.dispose();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mode = Uri.base.queryParameters['phase'];
  final nonce = Uri.base.queryParameters['nonce'] ?? '';
  try {
    require(RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce));
    require(
      Uri.base.scheme == 'http' &&
          Uri.base.hasPort &&
          {'127.0.0.1', '127.0.0.1.nip.io'}.contains(Uri.base.host),
    );
    final guard = await http.get(
      Uri.base.resolve('/__marty_owned_browser_guard'),
    );
    require(guard.statusCode == 200 && guard.body == nonce);
    if (mode == 'seed' || mode == 'insecure') {
      require(
        web.window.localStorage.length == 0 &&
            web.window.sessionStorage.length == 0,
      );
    } else {
      require(web.window.localStorage.getItem(_marker) == nonce);
    }
    configureBrowserSecureStorage();
    if (mode == 'insecure') {
      require(!web.window.isSecureContext);
      var refused = false;
      try {
        await _storage.readAll();
      } on UnsupportedError {
        refused = true;
      }
      require(
        refused &&
            web.window.localStorage.length == 0 &&
            web.window.sessionStorage.length == 0,
      );
    } else {
      require(web.window.isSecureContext && Uri.base.host == '127.0.0.1');
      final prefs = await SharedPreferences.getInstance();
      if (mode == 'seed') {
        web.window.localStorage.setItem(_marker, nonce);
        for (final id in _ids) {
          await prefs.setString(
            '$_legacy$_receipt$id',
            encode(jsonEncode(_value(id).toJson())),
          );
        }
        await prefs.setString(
          '${_legacy}card_groups_data',
          encode(
            jsonEncode({
              'version': 1,
              'groups': [
                {'title': _issuer, 'ids': _ids.reversed.toList()},
              ],
              'expired_ids': [_ids.first],
            }),
          ),
        );
        await prefs.setString(
          '$_legacy$_pairing',
          encode(
            jsonEncode({
              'api_origin': 'https://synthetic-browser.example',
              'device_credential': 'synthetic-storage-value',
              'registration_id': 'synthetic-registration',
              'pairing_id': 'synthetic-pairing',
              'device_id': 'synthetic-device',
              'confirmed': true,
              'holder_binding_public_jwk': {'kty': 'OKP'},
              'presentation_signing_public_jwk': {'kty': 'EC'},
            }),
          ),
        );
        await prefs.setString(
          '${_legacy}retired-raw-import',
          'synthetic-preserved-original',
        );
        await prefs.setString(_unrelated, 'synthetic-unrelated-value');
      } else if (mode == 'migrate' || mode == 'reload') {
        await _readConsumers();
        await prefs.reload();
        require(!prefs.getKeys().any((v) => v.startsWith('$_legacy$_receipt')));
        require(
          !prefs.containsKey('${_legacy}card_groups_data') &&
              !prefs.containsKey('$_legacy$_pairing'),
        );
        require(
          prefs.getString('${_legacy}retired-raw-import') ==
              'synthetic-preserved-original',
        );
        require(await _storage.read(key: _pairing) != null);
        for (var i = 0; i < web.window.localStorage.length; i++) {
          final key = web.window.localStorage.key(i)!;
          if (key.startsWith('marty.storage.v1.')) {
            final value = web.window.localStorage.getItem(key)!;
            require(
              !value.contains(_raw) &&
                  !value.contains(
                    encode(jsonEncode(_value(_ids.first).toJson())),
                  ),
            );
          }
        }
      } else if (mode == 'namespaces') {
        const other = FlutterSecureStorage(
          webOptions: WebOptions(dbName: 'FlutterEncryptedStorage_other'),
        );
        const custom = FlutterSecureStorage(
          webOptions: WebOptions(publicKey: 'synthetic-custom'),
        );
        const session = FlutterSecureStorage(
          webOptions: WebOptions(useSessionStorage: true),
        );
        for (final target in [other, custom, session]) {
          await target.write(
            key: 'sentinel',
            value: 'synthetic-isolated-value',
          );
        }
        await other.deleteAll();
        require(await other.read(key: 'sentinel') == null);
        require(
          await custom.read(key: 'sentinel') == 'synthetic-isolated-value',
        );
        require(
          await session.read(key: 'sentinel') == 'synthetic-isolated-value',
        );
        require((await WalletCredentialStore.getAll()).length == 2);
        await custom.deleteAll();
        await session.deleteAll();
      } else if (mode == 'malformed') {
        final source = '$_legacy${_receipt}malformed';
        for (final bad in [
          'not-base64!',
          jsonEncode(_value('malformed').toJson()),
          encode(jsonEncode(_value('substituted').toJson())),
        ]) {
          await prefs.setString(source, bad);
          var refused = false;
          try {
            await WalletCredentialStore.getAll();
          } on StateError {
            refused = true;
          }
          require(refused && prefs.getString(source) == bad);
          final container = ProviderContainer();
          try {
            await container.read(cardStateProvider.notifier).refreshCards();
            require(container.read(walletStorageUnavailableProvider));
            require(prefs.getString(source) == bad);
            require(await prefs.remove(source));
            await container.read(cardStateProvider.notifier).refreshCards();
            require(!container.read(walletStorageUnavailableProvider));
          } finally {
            container.dispose();
          }
        }
        await _readConsumers();
      } else if (mode == 'encrypted-recovery') {
        final suffix = '.$_receipt${_ids.first}';
        final keys = <String>[
          for (var i = 0; i < web.window.localStorage.length; i++)
            web.window.localStorage.key(i)!,
        ];
        final record = keys.singleWhere(
          (v) => v.startsWith('marty.storage.v1.') && v.endsWith(suffix),
        );
        final master = record.substring(0, record.length - suffix.length);
        final ciphertext = web.window.localStorage.getItem(record)!;
        final encryptionKey = web.window.localStorage.getItem(master)!;
        final container = ProviderContainer();
        try {
          for (final damage in ['ciphertext', 'missing-key', 'corrupt-key']) {
            try {
              if (damage == 'ciphertext') {
                web.window.localStorage.setItem(
                  record,
                  'synthetic-corrupt-ciphertext',
                );
              } else if (damage == 'missing-key') {
                web.window.localStorage.removeItem(master);
              } else {
                web.window.localStorage.setItem(
                  master,
                  'synthetic-corrupt-key',
                );
              }
              var refused = false;
              try {
                await WalletCredentialStore.getAll();
              } on StateError {
                refused = true;
              }
              require(refused);
              await container.read(cardStateProvider.notifier).refreshCards();
              require(container.read(walletStorageUnavailableProvider));
              if (damage == 'missing-key') {
                require(web.window.localStorage.getItem(master) == null);
              }
              if (damage == 'corrupt-key') {
                require(
                  web.window.localStorage.getItem(master) ==
                      'synthetic-corrupt-key',
                );
              }
              if (damage != 'ciphertext') {
                require(web.window.localStorage.getItem(record) == ciphertext);
              }
            } finally {
              // Restore only this nonce-admitted synthetic fixture's own bytes.
              web.window.localStorage.setItem(record, ciphertext);
              web.window.localStorage.setItem(master, encryptionKey);
            }
            await container.read(cardStateProvider.notifier).refreshCards();
            require(!container.read(walletStorageUnavailableProvider));
            require((await WalletCredentialStore.getAll()).length == 2);
          }
        } finally {
          container.dispose();
        }
      } else if (mode == 'delete') {
        await WalletCredentialStore.clear();
        require((await WalletCredentialStore.getAll()).isEmpty);
        require(
          await _storage.read(key: _pairing) != null &&
              await _storage.read(key: 'card_groups_data') != null,
        );
        await _storage.deleteAll();
        require((await _storage.readAll()).isEmpty);
        require(prefs.getString(_unrelated) == 'synthetic-unrelated-value');
        require(
          prefs.getString('${_legacy}retired-raw-import') ==
              'synthetic-preserved-original',
        );
      } else {
        throw StateError('Unknown browser qualification phase');
      }
    }
    web.document.documentElement!.setAttribute(
      'data-marty-storage-result',
      jsonEncode({'phase': mode, 'status': 'passed'}),
    );
    runApp(
      MaterialApp(
        home: Scaffold(body: Text('Storage qualification: $mode passed')),
      ),
    );
  } catch (_) {
    // Browser/driver evidence never includes source values or recovery data.
    web.document.documentElement!.setAttribute(
      'data-marty-storage-result',
      jsonEncode({'phase': mode, 'status': 'failed'}),
    );
    runApp(
      const MaterialApp(
        home: Scaffold(body: Text('Storage qualification failed')),
      ),
    );
  }
}
