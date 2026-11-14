import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/providers/verification_state_provider.dart';
import 'package:marty_authenticator/views/main_view/main_view_widgets/card_widgets/mdl_placeholder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NavigationObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
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
}
