import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/card_data.dart';
import 'package:marty_authenticator/views/card_details_screen.dart';
import 'package:marty_authenticator/views/grouped_card_details_screen.dart';

CardData receipt(String id) => CardData(
  title: 'Digital ID',
  subtitle: 'https://issuer.example',
  icon: Icons.perm_identity,
  color: Colors.teal,
  gradient: const [Colors.teal, Colors.tealAccent],
  id: id,
  issuer: 'https://issuer.example',
  type: 'ExampleIdentity',
  metadata: const {'format': 'dc+sd-jwt'},
);

void main() {
  testWidgets('single card details show the real verified receipt identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CardDetailsScreen(card: receipt('receipt-first'))),
    );

    expect(find.text('receipt-first'), findsOneWidget);
    expect(find.text('https://issuer.example'), findsWidgets);
    expect(find.text('ExampleIdentity'), findsOneWidget);
    expect(find.text('dc+sd-jwt'), findsOneWidget);
    expect(find.text('Adam Burdett'), findsNothing);
  });

  testWidgets('same-title grouped cards retain separate receipt IDs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupedCardDetailsScreen(
          cardGroup: CardGroup(
            title: 'https://issuer.example',
            cards: [receipt('receipt-first'), receipt('receipt-second')],
          ),
        ),
      ),
    );

    expect(find.text('receipt-first'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('receipt-second'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Adam Burdett'), findsNothing);
  });
}
