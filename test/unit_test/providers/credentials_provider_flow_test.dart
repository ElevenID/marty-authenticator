import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

// Offer parsing and receipt verification are exercised by
// verified_wallet_orchestration_test. The card provider consumes only receipts,
// and must not reinterpret legacy wallet objects as verified credentials.
StoredCredential _receipt(String id, String issuer) => StoredCredential(
  id: id,
  format: 'dc+sd-jwt',
  issuer: issuer,
  types: const ['EmployeeCredential'],
  rawJson: 'verified-test-receipt-$id',
  issuedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ProviderContainer> load() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(cardStateProvider.notifier).refreshCards();
    return container;
  }

  test(
    'malformed receipts are isolated and legacy records never become cards',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'marty:wallet:receipt:malformed': 'not-json',
        'marty:wallet:receipt:missing-fields': '{"id":"missing-fields"}',
        'marty:wallet:receipt:wrong-id': jsonEncode(
          _receipt('substituted', 'https://issuer.test').toJson(),
        ),
        'credentials': jsonEncode([
          {
            'id': 'legacy',
            'type': 'VerifiableCredential',
            'credentialSubject': {'name': 'Unverified'},
          },
        ]),
      });
      await WalletCredentialStore.store(_receipt('one', 'https://issuer.test'));
      await WalletCredentialStore.store(_receipt('two', 'https://other.test'));

      final container = await load();
      final groups = container.read(cardStateProvider);
      expect(groups.map((g) => g.title), [
        'https://issuer.test',
        'https://other.test',
      ]);
      expect(groups.expand((g) => g.cards).map((c) => c.id), ['one', 'two']);
      for (final card in groups.expand((g) => g.cards)) {
        expect(
          card.rawData,
          containsPair('_source', 'wallet_credential_store'),
        );
        expect(card.rawData, containsPair('format', 'dc+sd-jwt'));
        expect(
          jsonEncode(card.rawData),
          isNot(contains('verified-test-receipt')),
        );
      }
    },
  );

  test(
    'active and expired provider projections preserve issuer groups',
    () async {
      for (final (id, issuer) in [
        ('first', 'https://issuer.test'),
        ('second', 'https://issuer.test'),
        ('other', 'https://other.test'),
      ]) {
        await WalletCredentialStore.store(_receipt(id, issuer));
      }
      final container = await load();
      final notifier = container.read(cardStateProvider.notifier);
      final card = container.read(cardStateProvider).first.cards.first;
      notifier.toggleCardExpired(card);
      await notifier.saveCards();

      expect(container.read(expiredCardsProvider).map((c) => c.id), ['first']);
      final active = container.read(activeCardGroupsProvider);
      expect(active.map((g) => g.title), [
        'https://issuer.test',
        'https://other.test',
      ]);
      expect(active.expand((g) => g.cards).map((c) => c.id), [
        'second',
        'other',
      ]);
      expect(await WalletCredentialStore.getById('first'), isNotNull);

      await notifier.refreshCards();
      expect(container.read(expiredCardsProvider).single.id, 'first');
      notifier.toggleCardExpired(container.read(expiredCardsProvider).single);
      await notifier.saveCards();
      expect(container.read(expiredCardsProvider), isEmpty);
      expect(
        container
            .read(activeCardGroupsProvider)
            .expand((g) => g.cards)
            .map((c) => c.id),
        ['first', 'second', 'other'],
      );
    },
  );

  test(
    'receipt deletion removes only the selected card and survives refresh',
    () async {
      await WalletCredentialStore.store(
        _receipt('first', 'https://issuer.test'),
      );
      await WalletCredentialStore.store(
        _receipt('second', 'https://issuer.test'),
      );
      final container = await load();
      final notifier = container.read(cardStateProvider.notifier);
      final cards = container.read(cardStateProvider).single.cards;
      expect(cards.first.title, cards.last.title);

      await notifier.deleteCard(cards.first);
      await notifier.refreshCards();
      expect(
        container.read(cardStateProvider).single.cards.single.id,
        'second',
      );
      expect(await WalletCredentialStore.getById('first'), isNull);
      expect(await WalletCredentialStore.getById('second'), isNotNull);
    },
  );

  test(
    'an empty wallet stays empty until a real receipt is added and refreshed',
    () async {
      final container = await load();
      expect(container.read(cardStateProvider), isEmpty);
      expect(container.read(activeCardGroupsProvider), isEmpty);
      expect(container.read(expiredCardsProvider), isEmpty);

      await WalletCredentialStore.store(_receipt('new', 'https://issuer.test'));
      await container.read(cardStateProvider.notifier).refreshCards();
      expect(container.read(cardStateProvider).single.cards.single.id, 'new');
      await WalletCredentialStore.clear();
      await container.read(cardStateProvider.notifier).refreshCards();
      expect(container.read(activeCardGroupsProvider), isEmpty);
    },
  );
}
