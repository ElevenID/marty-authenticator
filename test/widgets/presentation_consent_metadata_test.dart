import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/widgets/presentation_request_view.dart';

void main() {
  testWidgets(
    'always-shared claims and signing identifiers remain when optional disclosure is cleared',
    (tester) async {
      Map<String, dynamic>? approved;
      await tester.pumpWidget(
        MaterialApp(
          home: PresentationRequestView(
            requestDetails: const {},
            matchingCredentials: const [
              {
                'id': 'credential',
                'requestedFields': {
                  'credential': ['email'],
                },
                'alwaysSharedClaims': {
                  'sub': '"signed-identifier"',
                  'nested': '{"visible":true}',
                  'numeric_id': '9007199254740993',
                  'decimal': '1.2300e+20',
                },
                'alwaysSharedHeader': {'kid': '"public-key-identifier"'},
              },
            ],
            onApprove: (value) => approved = value,
            onReject: () {},
          ),
        ),
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(find.text('sub: "signed-identifier"'), findsOneWidget);
      expect(find.text('nested: {"visible":true}'), findsOneWidget);
      expect(find.text('numeric_id: 9007199254740993'), findsOneWidget);
      expect(find.text('decimal: 1.2300e+20'), findsOneWidget);
      expect(find.text('kid: "public-key-identifier"'), findsOneWidget);
      await tester.tap(find.text('Share'));
      expect(approved, {
        'credentialId': 'credential',
        'selectedFields': <String>[],
      });
    },
  );
  testWidgets('switching credentials replaces all always-shared identifiers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PresentationRequestView(
          requestDetails: const {
            'verifier': 'verifier',
            'recipient': 'https://receiver.example/response',
          },
          matchingCredentials: const [
            {
              'id': 'one',
              'type': 'First',
              'requestedFields': <String, dynamic>{},
              'alwaysSharedClaims': {'sub': '"one"'},
              'alwaysSharedHeader': {'kid': '"key-one"'},
            },
            {
              'id': 'two',
              'type': 'Second',
              'requestedFields': <String, dynamic>{},
              'alwaysSharedClaims': {'sub': '"two"'},
              'alwaysSharedHeader': {'kid': '"key-two"'},
            },
          ],
          onApprove: (_) {},
          onReject: () {},
        ),
      ),
    );
    expect(find.text('sub: "one"'), findsOneWidget);
    expect(find.text('kid: "key-one"'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second').last);
    await tester.pumpAndSettle();
    expect(find.text('sub: "two"'), findsOneWidget);
    expect(find.text('kid: "key-two"'), findsOneWidget);
    expect(find.text('sub: "one"'), findsNothing);
    expect(find.text('kid: "key-one"'), findsNothing);
  });
}
