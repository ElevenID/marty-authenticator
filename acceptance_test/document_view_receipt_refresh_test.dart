import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';
import 'package:marty_authenticator/views/grouped_card_details_screen.dart';
import 'package:marty_authenticator/views/main_view/document_view.dart';
import 'package:marty_authenticator/views/qr_scanner_view/qr_scanner_view.dart';
import 'package:marty_authenticator/widgets/stacked_wallet_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This explicit acceptance suite lives outside Flutter's default test tree.
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('wallet refreshes verified receipts after the scanner closes', (
    tester,
  ) async {
    const permissions = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (_) async => 1);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissions, null),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const DocumentView(),
          routes: {
            QRScannerView.routeName: (_) =>
                const Scaffold(body: Center(child: Text('Test scanner'))),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(cardStateProvider), isEmpty);

    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    expect(find.text('Test scanner'), findsOneWidget);
    await WalletCredentialStore.store(
      StoredCredential(
        id: 'verified-receipt',
        format: 'dc+sd-jwt',
        issuer: 'https://issuer.example',
        types: const ['ExampleIdentity'],
        rawJson: 'verified-test-receipt',
        issuedAt: DateTime.utc(2026, 10, 9),
      ),
    );
    Navigator.of(
      tester.element(find.text('Test scanner')),
    ).pop('scanner-result');
    await tester.pumpAndSettle();

    expect(
      container.read(cardStateProvider).single.cards.single.id,
      'verified-receipt',
    );
    expect(find.text('Digital ID'), findsWidgets);
  });

  testWidgets('same-title wallet cards open the matching issuer receipt', (
    tester,
  ) async {
    for (final issuer in ['a', 'b']) {
      await WalletCredentialStore.store(
        StoredCredential(
          id: 'receipt-$issuer',
          format: 'dc+sd-jwt',
          issuer: 'https://issuer-$issuer.example',
          types: const ['ExampleIdentity'],
          rawJson: 'verified-test-receipt-$issuer',
          issuedAt: DateTime.utc(2026, 10, 9),
        ),
      );
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(cardStateProvider.notifier).loadCards();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DocumentView()),
      ),
    );
    await tester.pumpAndSettle();

    final selected = tester
        .widgetList<StackedWalletCard>(find.byType(StackedWalletCard))
        .singleWhere(
          (card) => card.cardGroup.title == 'https://issuer-b.example',
        );
    selected.onTap!();
    await tester.pumpAndSettle();
    final details = tester.widget<GroupedCardDetailsScreen>(
      find.byType(GroupedCardDetailsScreen),
    );
    expect(details.cardGroup.title, 'https://issuer-b.example');
    expect(details.cardGroup.cards.single.id, 'receipt-b');
  });
}
