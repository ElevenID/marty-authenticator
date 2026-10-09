import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';
import 'package:marty_authenticator/views/expired_passes_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('deleting one same-title expired pass preserves the other', (
    tester,
  ) async {
    for (final id in ['first', 'second']) {
      await WalletCredentialStore.store(
        StoredCredential(
          id: id,
          format: 'dc+sd-jwt',
          issuer: 'https://issuer.example',
          types: const ['ExampleIdentity'],
          rawJson: 'public-test-receipt-$id',
          issuedAt: DateTime.utc(2026, 10, 9),
        ),
      );
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cardStateProvider.notifier);
    await notifier.loadCards();
    for (final card in notifier.state.single.cards) {
      notifier.toggleCardExpired(card);
    }
    await notifier.saveCards();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ExpiredPassesView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));

    await tester.tap(find.text('Edit').first);
    await tester.pump();
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(find.text('1 Pass Selected'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(expiredCardsProvider).map((card) => card.id), [
      'second',
    ]);
    expect(await WalletCredentialStore.getById('first'), isNull);
    expect(await WalletCredentialStore.getById('second'), isNotNull);
  });
}
