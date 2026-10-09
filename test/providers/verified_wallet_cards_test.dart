import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> storeReceipt(String id, String issuer) =>
      WalletCredentialStore.store(
        StoredCredential(
          id: id,
          format: 'dc+sd-jwt',
          issuer: issuer,
          types: const ['ExampleIdentity'],
          rawJson: 'public-test-receipt-$id',
          issuedAt: DateTime.utc(2026, 10, 9),
        ),
      );

  test(
    'deleting one verified receipt preserves another card with the same title',
    () async {
      for (final id in ['first', 'second']) {
        await storeReceipt(id, 'https://issuer.example');
      }

      final notifier = CardStateNotifier();
      addTearDown(notifier.dispose);
      await notifier.loadCards();
      final cards = notifier.state.expand((group) => group.cards).toList();
      expect(cards.map((card) => card.id), containsAll(['first', 'second']));
      expect(cards.map((card) => card.title).toSet(), hasLength(1));

      await notifier.deleteCard(cards.firstWhere((card) => card.id == 'first'));

      expect(
        notifier.state.expand((group) => group.cards).map((card) => card.id),
        ['second'],
      );
      expect(await WalletCredentialStore.getById('first'), isNull);
      expect(await WalletCredentialStore.getById('second'), isNotNull);
    },
  );

  test(
    'same-title expiry and wallet ordering survive reload by receipt ID',
    () async {
      await storeReceipt('first', 'https://issuer.example');
      await storeReceipt('second', 'https://issuer.example');
      await storeReceipt('other', 'https://other.example');

      final notifier = CardStateNotifier();
      await notifier.loadCards();
      notifier.toggleCardExpired(notifier.state.first.cards.first);
      notifier.reorderCard(notifier.state.first.cards.last, 0, 0);
      notifier.reorderGroup(0, 2);
      await notifier.saveCards();

      final raw = await const FlutterSecureStorage().read(
        key: 'card_groups_data',
      );
      expect(raw, isNotNull);
      expect(raw, isNot(contains('public-test-receipt')));
      final layout = jsonDecode(raw!) as Map<String, dynamic>;
      expect(layout['expired_ids'], ['first']);
      notifier.dispose();

      await storeReceipt('third', 'https://issuer.example');
      final reloaded = CardStateNotifier();
      addTearDown(reloaded.dispose);
      await reloaded.loadCards();
      expect(reloaded.state.map((group) => group.title), [
        'https://other.example',
        'https://issuer.example',
      ]);
      final cards = reloaded.state.last.cards;
      expect(cards.map((card) => card.id), ['second', 'first', 'third']);
      expect(cards.where((card) => card.isExpired).map((card) => card.id), [
        'first',
      ]);

      // A card cannot be moved under another issuer's group.
      reloaded.reorderCard(cards.first, 0, 0);
      expect(reloaded.state.first.cards.map((card) => card.id), ['other']);
    },
  );
}
