// Widget/storage orchestration with synthetic receipts and controlled OS
// permission responses. Native issuer/signature and installed acceptance are
// qualified separately; these values never establish credential trust.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/l10n/app_localizations.dart';
import 'package:marty_authenticator/main_document.dart';
import 'package:marty_authenticator/providers/card_state_provider.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';
import 'package:marty_authenticator/views/expired_passes_view.dart';
import 'package:marty_authenticator/views/grouped_card_details_screen.dart';
import 'package:marty_authenticator/views/main_view/document_view.dart';
import 'package:marty_authenticator/views/qr_scanner_view/qr_scanner_view.dart';
import 'package:marty_authenticator/widgets/cascading_card_list.dart';
import 'package:marty_authenticator/widgets/stacked_wallet_card.dart';

const permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

Future<void> store(String id, String issuer) => WalletCredentialStore.store(
  StoredCredential(
    id: id,
    issuer: issuer,
    format: 'dc+sd-jwt',
    types: const ['SyntheticIdentity'],
    rawJson: 'synthetic-widget-receipt-$id',
    issuedAt: DateTime.utc(2026, 11, 16),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 1;
          if (call.method == 'requestPermissions') return <int, int>{1: 0};
          throw StateError('Unexpected controlled permission operation');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null),
  );

  Future<ProviderContainer> container() async {
    final value = ProviderContainer();
    addTearDown(value.dispose);
    await value.read(cardStateProvider.notifier).refreshCards();
    return value;
  }

  Future<void> mount(
    WidgetTester tester,
    ProviderContainer value,
    Widget home, {
    Map<String, WidgetBuilder> routes = const {},
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: value,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: routes,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'wallet groups durable receipts and opens the selected issuer group',
    (tester) async {
      await store('single', 'issuer-a');
      await store('group-first', 'issuer-b');
      await store('group-second', 'issuer-b');
      final value = await container();
      await mount(tester, value, const DocumentView());
      final group = find.byWidgetPredicate(
        (widget) =>
            widget is StackedWalletCard && widget.cardGroup.title == 'issuer-b',
      );
      expect(group, findsOneWidget);
      await tester.ensureVisible(group);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(group) + const Offset(80, 30));
      await tester.pumpAndSettle();
      final details = tester.widget<GroupedCardDetailsScreen>(
        find.byType(GroupedCardDetailsScreen),
      );
      expect(details.cardGroup.title, 'issuer-b');
      expect(details.cardGroup.cards.map((card) => card.id), [
        'group-first',
        'group-second',
      ]);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      await tester.tap(find.text('Back').first);
      await tester.pumpAndSettle();
      expect(find.byType(DocumentView), findsOneWidget);
      expect((await WalletCredentialStore.getAll()).length, 3);
    },
  );

  for (final size in [1, 2]) {
    testWidgets(
      'a $size-receipt standalone wallet stack opens its own details',
      (tester) async {
        for (var index = 0; index < size; index++) {
          await store('standalone-$index', 'issuer-standalone');
        }
        final value = await container();
        final group = value.read(cardStateProvider).single;
        await mount(
          tester,
          value,
          Scaffold(
            body: Center(child: StackedWalletCard(cardGroup: group)),
          ),
        );
        await tester.tapAt(
          tester.getTopLeft(find.byType(StackedWalletCard)) +
              const Offset(80, 30),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<GroupedCardDetailsScreen>(
                find.byType(GroupedCardDetailsScreen),
              )
              .cardGroup
              .cards
              .length,
          size,
        );
        expect(find.text('RECEIPT ID'), findsWidgets);
        await tester.tap(find.text('Back').first);
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'cancelled card dragging clears transient drag state and keeps receipts',
    (tester) async {
      await store('drag-single', 'issuer-drag');
      final value = await container();
      var longPresses = 0;
      await mount(
        tester,
        value,
        Scaffold(
          body: Center(
            child: StackedWalletCard(
              cardGroup: value.read(cardStateProvider).single,
              onLongPress: () => longPresses++,
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(StackedWalletCard)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(value.read(draggingCardProvider)?.id, 'drag-single');
      await gesture.moveBy(const Offset(100, 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(value.read(draggingCardProvider), isNull);
      expect(longPresses, 1);
      expect((await WalletCredentialStore.getAll()).single.id, 'drag-single');
    },
  );

  testWidgets(
    'same-title issuer groups reorder by receipt identity and persist the layout',
    (tester) async {
      await store('a', 'issuer-a');
      await store('b-first', 'issuer-b');
      await store('b-second', 'issuer-b');
      final value = await container();
      final moves = <(int, int)>[];
      final groups = value.read(cardStateProvider);
      expect(groups[0].cards.first.title, groups[1].cards.first.title);
      await mount(
        tester,
        value,
        Scaffold(
          body: Center(
            child: CascadingCardList(
              cardGroups: groups,
              onReorder: (from, to) {
                moves.add((from, to));
                value.read(cardStateProvider.notifier).reorderGroup(from, to);
              },
            ),
          ),
        ),
      );
      final stacks = find.byType(StackedWalletCard);
      final start = tester.getTopLeft(stacks.at(1)) + const Offset(80, 30);
      final target = tester.getTopLeft(stacks.at(0)) + const Offset(80, 30);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      expect(value.read(draggingCardProvider)?.id, 'b-first');
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, [(1, 0)]);
      expect(value.read(draggingCardProvider), isNull);
      await value.read(cardStateProvider.notifier).saveCards();
      await value.read(cardStateProvider.notifier).refreshCards();
      expect(value.read(cardStateProvider).map((group) => group.title), [
        'issuer-b',
        'issuer-a',
      ]);
      expect(
        (await WalletCredentialStore.getAll())
            .map((receipt) => receipt.id)
            .toSet(),
        {'a', 'b-first', 'b-second'},
      );
    },
  );

  testWidgets(
    'scanner return refreshes receipts once without starting a second issuance',
    (tester) async {
      final value = await container();
      var scannerCompletions = 0;
      await mount(
        tester,
        value,
        const DocumentView(),
        routes: {
          '/qr_scanner': (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                scannerCompletions++;
                await store('scanner-result', 'issuer-scanner');
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Finish controlled scanner'),
            ),
          ),
        },
      );
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish controlled scanner'));
      await tester.pumpAndSettle();
      expect(scannerCompletions, 1);
      expect(
        value.read(cardStateProvider).single.cards.single.id,
        'scanner-result',
      );
      expect(
        (await WalletCredentialStore.getAll()).single.id,
        'scanner-result',
      );
    },
  );

  testWidgets(
    'expired receipt navigation preserves active and expired identities',
    (tester) async {
      await store('active', 'issuer-shared');
      await store('expired', 'issuer-shared');
      final value = await container();
      value
          .read(cardStateProvider.notifier)
          .toggleCardExpired(value.read(cardStateProvider).single.cards.last);
      await value.read(cardStateProvider.notifier).saveCards();
      await mount(tester, value, const DocumentView());
      final footer = find.text('View 1 Expired Pass');
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(find.byType(ExpiredPassesView), findsOneWidget);
      expect(value.read(expiredCardsProvider).single.id, 'expired');
      expect(
        value.read(activeCardGroupsProvider).single.cards.single.id,
        'active',
      );
      expect((await WalletCredentialStore.getAll()).length, 2);
    },
  );
  testWidgets('permanent camera denial is visible without a global navigator', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 4;
          throw StateError('Permanently denied camera must not be requested');
        });
    await store('kept', 'issuer-kept');
    final value = await container();
    await mount(tester, value, const DocumentView());
    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(QRScannerView), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect((await WalletCredentialStore.getAll()).single.id, 'kept');
  });

  testWidgets(
    'the actual document app registers the scanner route and returns after denial',
    (tester) async {
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (call) async {
            if (call.method == 'checkPermissionStatus') return 1;
            if (call.method == 'requestPermissions') {
              requests++;
              return <int, int>{1: 0};
            }
            throw StateError('Unexpected permission operation');
          });
      await tester.pumpWidget(const DocumentApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();
      expect(find.byType(QRScannerView), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      final labels = AppLocalizations.of(
        tester.element(find.byType(QRScannerView)),
      )!;
      await tester.tap(find.text(labels.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentView), findsOneWidget);
      expect(requests, 1);
      expect(await WalletCredentialStore.getAll(), isEmpty);
    },
  );

  testWidgets('scanner permission retry respects a new permanent denial', (
    tester,
  ) async {
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 1;
          if (call.method == 'requestPermissions') {
            requests++;
            return <int, int>{1: requests == 1 ? 0 : 4};
          }
          throw StateError('Unexpected permission operation');
        });
    await tester.pumpWidget(const DocumentApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    final labels = AppLocalizations.of(
      tester.element(find.byType(QRScannerView)),
    )!;
    await tester.tap(find.text(labels.grantCameraPermissionDialogButton));
    await tester.pumpAndSettle();
    expect(
      find.text(labels.grantCameraPermissionDialogPermanentlyDenied),
      findsOneWidget,
    );
    expect(find.text(labels.grantCameraPermissionDialogButton), findsNothing);
    expect(requests, 2);
    expect(await WalletCredentialStore.getAll(), isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DocumentView), findsOneWidget);
  });
}
