import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacyidea_authenticator/widgets/dialogs/add_to_wallet_dialog.dart';

void main() {
  testWidgets('AddToWalletDialog shows correct content', (
    WidgetTester tester,
  ) async {
    // Set a realistic screen size for the test
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Setup: Pump a MaterialApp with a button to open the dialog
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // 1. Open the dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle(); // Wait for dialog animation

    // 2. Verify Content
    expect(find.text('Add Documents'), findsOneWidget);
    expect(
      find.text(
        'Keep all the cards, keys, and passes you use every day all in one place.',
      ),
      findsOneWidget,
    );
    expect(find.text('Available Cards'), findsOneWidget);
    expect(find.text('Previous Cards'), findsOneWidget);
    expect(find.text('Transit Card'), findsOneWidget);
    expect(find.text('Driver\'s License and ID Cards'), findsOneWidget);
  });

  testWidgets('AddToWalletDialog close button works', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.text('Add Documents'), findsOneWidget);

    // Tap close button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Verify dialog is closed
    expect(find.text('Add Documents'), findsNothing);
  });

  testWidgets('AddToWalletDialog navigates to PreviousCardsDialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Previous Cards'));
    await tester.pumpAndSettle();

    // Verify PreviousCardsDialog content
    // Note: PreviousCardsDialog title is "Previous Cards" which is also on the button,
    // but the title style is different (32 bold).
    // However, find.text finds both.
    // Let's check for the back button which is specific to the new dialog.
    expect(find.text('Back'), findsOneWidget);
    // And verify the original dialog title is not visible (it might be behind, but let's check top widget)
    // Actually, since it's a fullscreen dialog, it covers the previous one.
  });

  testWidgets('AddToWalletDialog navigates to TransitCardDialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transit Card'));
    await tester.pumpAndSettle();

    // Verify TransitCardDialog content
    expect(
      find.text(
        'Quickly pass through gates by holding your iPhone or Apple Watch near a reader.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AddToWalletDialog navigates to DriverLicenseDialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Driver\'s License and ID Cards'));
    await tester.pumpAndSettle();

    // Verify DriverLicenseDialog content
    // The title has a newline in the code: 'Driver\'s License and\nID Cards'
    expect(find.text('Driver\'s License and\nID Cards'), findsOneWidget);
  });

  testWidgets('AddToWalletDialog has correct styling and icons', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Background Color
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, const Color(0xFF1C1C1E));

    // Verify Title Style
    final titleText = tester.widget<Text>(find.text('Add Documents'));
    expect(titleText.style?.color, Colors.white);
    expect(titleText.style?.fontSize, 32);
    expect(titleText.style?.fontWeight, FontWeight.bold);

    // Verify Subtitle Style
    final subtitleText = tester.widget<Text>(
      find.text(
        'Keep all the cards, keys, and passes you use every day all in one place.',
      ),
    );
    expect(subtitleText.style?.color, Colors.grey);
    expect(subtitleText.style?.fontSize, 16);

    // Verify Section Header Style
    final sectionHeader = tester.widget<Text>(find.text('Available Cards'));
    expect(sectionHeader.style?.color, Colors.white);
    expect(sectionHeader.style?.fontSize, 24);
    expect(sectionHeader.style?.fontWeight, FontWeight.bold);

    // Verify Icons are present
    expect(find.byIcon(Icons.credit_card), findsOneWidget);
    expect(find.byIcon(Icons.train), findsOneWidget);
    expect(find.byIcon(Icons.badge), findsOneWidget);

    // Verify Close Button Icon
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('AddToWalletDialog has correct layout and decorations', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddToWalletDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Close Button Decoration
    // The close button is in a Container with a circle shape and specific color
    final closeButtonContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(Container),
          )
          .first,
    );
    final closeDecoration = closeButtonContainer.decoration as BoxDecoration;
    expect(closeDecoration.color, const Color(0xFF48484A));
    expect(closeDecoration.shape, BoxShape.circle);

    // Verify Option Card Decorations
    // Find the container wrapping "Previous Cards"
    final previousCardsContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Previous Cards'),
            matching: find.byType(Container),
          )
          .first,
    );
    final cardDecoration = previousCardsContainer.decoration as BoxDecoration;
    expect(cardDecoration.color, const Color(0xFF2C2C2E));
    expect(cardDecoration.borderRadius, BorderRadius.circular(12));

    // Verify Chevron Visibility
    // "Previous Cards" should NOT have a chevron
    // We need to find the row containing "Previous Cards" and check its children
    final previousCardsRow = tester.widget<Row>(
      find
          .ancestor(of: find.text('Previous Cards'), matching: find.byType(Row))
          .first,
    );
    // The row children: Icon container, SizedBox, Expanded(Column), [Chevron if present]
    // If no chevron, length is 3. If chevron, length is 4.
    // Wait, the code structure is:
    // Row(children: [Container(Icon), SizedBox, Expanded(Column), if(showArrow) Icon])
    expect(previousCardsRow.children.length, 3);

    // "Transit Card" SHOULD have a chevron
    final transitCardRow = tester.widget<Row>(
      find
          .ancestor(of: find.text('Transit Card'), matching: find.byType(Row))
          .first,
    );
    expect(transitCardRow.children.length, 4);
    expect(transitCardRow.children.last, isA<Icon>());
    final chevronIcon = transitCardRow.children.last as Icon;
    expect(chevronIcon.icon, Icons.chevron_right);
    expect(chevronIcon.color, Colors.grey);
  });
}
