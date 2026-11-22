import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  StoredCredential receipt(String id) => StoredCredential(
    id: id,
    format: 'dc+sd-jwt',
    issuer: 'https://issuer.example',
    types: const ['ExampleIdentity'],
    rawJson: 'public-test-receipt-$id',
    issuedAt: DateTime.utc(2026, 10, 9),
  );

  test(
    'parallel verified receipts remain independently discoverable',
    () async {
      await Future.wait([
        for (var index = 0; index < 20; index++)
          WalletCredentialStore.store(receipt('receipt-$index')),
      ]);
      final stored = await WalletCredentialStore.getAll();
      expect(stored, hasLength(20));
      expect(stored.map((item) => item.id).toSet(), {
        for (var index = 0; index < 20; index++) 'receipt-$index',
      });

      await WalletCredentialStore.delete('receipt-7');
      expect(await WalletCredentialStore.getById('receipt-7'), isNull);
      expect(await WalletCredentialStore.getAll(), hasLength(19));
    },
  );

  test('enumeration rejects a receipt stored under a different ID', () async {
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'marty:wallet:receipt:expected',
      value: jsonEncode(receipt('unexpected').toJson()),
    );
    expect(await WalletCredentialStore.getAll(), isEmpty);
    expect(await WalletCredentialStore.getById('expected'), isNull);
  });

  test(
    'clearing receipts leaves unrelated secure-storage data intact',
    () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'remote-holder-token', value: 'opaque-token');
      await WalletCredentialStore.store(receipt('receipt-1'));
      await WalletCredentialStore.clear();

      expect(await WalletCredentialStore.getAll(), isEmpty);
      expect(await storage.read(key: 'remote-holder-token'), 'opaque-token');
    },
  );
}
