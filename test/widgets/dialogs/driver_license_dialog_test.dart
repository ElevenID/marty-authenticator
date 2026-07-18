import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/widgets/dialogs/driver_license_dialog.dart';

void main() {
  testWidgets('state selection provides feedback and back closes dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => DriverLicenseDialog.show(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Arizona'));
    await tester.tap(find.text('Arizona'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Arizona selected'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Driver\'s License and\nID Cards'), findsNothing);
  });
}
