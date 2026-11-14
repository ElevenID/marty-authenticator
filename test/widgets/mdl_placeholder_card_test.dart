import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/providers/verification_state_provider.dart';
import 'package:marty_authenticator/views/document_verification/document_scanning_view.dart';
import 'package:marty_authenticator/views/main_view/main_view_widgets/card_widgets/mdl_placeholder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NavigationObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

class _UnavailableCamera extends CameraPlatform {
  int requests = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    requests++;
    return [];
  }
}

Future<void> _pumpCard(WidgetTester tester, VerificationStatus status) async {
  SharedPreferences.setMockInitialValues({
    'verification_status': status.toString(),
  });
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: MdlPlaceholderCard())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('issued credentials hide the enrollment placeholder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'verification_status': VerificationStatus.issued.toString(),
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MdlPlaceholderCard())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Mobile Driver's License"), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('pending enrollment cannot open a prototype presentation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'verification_status': VerificationStatus.pendingApproval.toString(),
    });
    final observer = _NavigationObserver();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: MdlPlaceholderCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    observer.pushed.clear();

    await tester.tap(find.text('Waiting for approval...'));
    await tester.pumpAndSettle();

    expect(observer.pushed, isEmpty);
    expect(find.text('Waiting for approval...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new enrollment opens the driver license scanning flow', (
    tester,
  ) async {
    final originalCamera = CameraPlatform.instance;
    final camera = _UnavailableCamera();
    CameraPlatform.instance = camera;
    addTearDown(() => CameraPlatform.instance = originalCamera);
    await _pumpCard(tester, VerificationStatus.none);

    await tester.tap(find.text("Add your driver's license to Wallet"));
    await tester.pump();
    // The camera loading indicator deliberately remains active in this fixture.
    await tester.pump(const Duration(milliseconds: 400));

    final scanning = tester.widget<DocumentScanningView>(
      find.byType(DocumentScanningView),
    );
    expect(scanning.config.type, DocumentType.driverLicense);
    expect(scanning.config.steps, [
      VerificationStep.scanFront,
      VerificationStep.scanBack,
      VerificationStep.liveness,
    ]);
    expect(scanning.currentStepIndex, 0);
    expect(camera.requests, 1);
    expect(find.text('Scan Document'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.byType(DocumentScanningView))).pop();
    await tester.pumpAndSettle();
    expect(find.text("Add your driver's license to Wallet"), findsOneWidget);
  });

  for (final (status, label) in [
    (VerificationStatus.none, 'Not Submitted'),
    (VerificationStatus.pendingApproval, 'Pending Approval'),
  ]) {
    testWidgets('card details show $label without changing enrollment', (
      tester,
    ) async {
      await _pumpCard(tester, status);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Card Details'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
      expect(find.text("Type: Driver's License"), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('verification_status'), status.toString());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'canceling pending verification restores and persists enrollment',
    (tester) async {
      await _pumpCard(tester, VerificationStatus.pendingApproval);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Verification'), findsOneWidget);
      await tester.tap(find.text('Cancel Verification'));
      await tester.pumpAndSettle();

      expect(find.text('Waiting for approval...'), findsNothing);
      expect(find.text("Add your driver's license to Wallet"), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('verification_status'),
        VerificationStatus.none.toString(),
      );
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Verification'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('license information navigation leaves enrollment unchanged', (
    tester,
  ) async {
    await _pumpCard(tester, VerificationStatus.none);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drivers License and ID cards'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Drivers License and ID cards'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text("Add your driver's license to Wallet"), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('verification_status'),
      VerificationStatus.none.toString(),
    );
    expect(tester.takeException(), isNull);
  });
}
