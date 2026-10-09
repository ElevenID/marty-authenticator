import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'deleting one verified receipt preserves another card with the same title',
    () async {
      final issuedAt = DateTime.utc(2026, 10, 9);
      for (final id in ['first', 'second']) {
        await WalletCredentialStore.store(
          StoredCredential(
            id: id,
            format: 'dc+sd-jwt',
            issuer: 'https://issuer.example',
            types: const ['ExampleIdentity'],
            rawJson: 'public-test-receipt-$id',
            issuedAt: issuedAt,
          ),
        );
      }

      final notifier = CardStateNotifier();
      addTearDown(notifier.dispose);
      await notifier.loadCards();
      final cards = notifier.state.expand((group) => group.cards).toList();
      expect(cards.map((card) => card.id), containsAll(['first', 'second']));
      expect(cards.map((card) => card.title).toSet(), hasLength(1));

      await notifier.deleteCard(cards.firstWhere((card) => card.id == 'first'));

      expect(
        notifier.state
            .expand((group) => group.cards)
            .map((card) => card.id),
        ['second'],
      );
      expect(await WalletCredentialStore.getById('first'), isNull);
      expect(await WalletCredentialStore.getById('second'), isNotNull);
    },
  );
}
