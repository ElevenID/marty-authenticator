import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/widgets/common/back_button.dart';

void main() {
  testWidgets('uses callback and adapts its label to available width', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 100,
              child: CustomBackButton(onPressed: () => pressed = true),
            ),
            const SizedBox(width: 40, child: CustomBackButton()),
          ],
        ),
      ),
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNWidgets(2));
    await tester.tap(find.text('Back'));
    expect(pressed, isTrue);
    await tester.tap(find.byIcon(Icons.chevron_left).last);
  });

  testWidgets('uses the current navigator when no callback is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: SizedBox(width: 100, child: CustomBackButton()),
                ),
              ),
            ),
            child: const Text('Open route'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open route'), findsOneWidget);
  });
}
