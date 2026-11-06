import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/selectable_credential.dart';
import 'package:marty_authenticator/utils/open_badges.dart';
import 'package:marty_authenticator/widgets/spruce_credential_selection_widget.dart';

Map<String, dynamic> _credential(String id, {Map<String, dynamic>? claims}) => {
  'id': id,
  'name': 'Employee card $id',
  'type': 'VerifiableCredential',
  'issuer': 'Example issuer',
  'credentialSubject':
      claims ??
      {
        'id': 'did:example:holder',
        'name': 'Ada',
        'department': 'Research',
        'address': 'City',
      },
};

Widget _screen(Widget child) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'required disclosure stays selected while optional choices update privacy and presentation payload',
    (tester) async {
      var selected = <SelectableCredential>[];
      var disclosure = <String, List<String>>{};
      List<String>? presentedIds;
      Map<String, List<String>>? presentedDisclosure;
      final completion = Completer<void>();
      await tester.pumpWidget(
        _screen(
          SpruceCredentialSelectionWidget(
            availableCredentials: [_credential('one')],
            requestedAttributes: const ['id'],
            onSelectionChanged: (credentials, attributes) {
              selected = credentials;
              disclosure = attributes;
            },
            onPresentationCreate: (credentials, attributes) {
              presentedIds = credentials.map((c) => c.id).toList();
              presentedDisclosure = attributes;
              return completion.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(selected.single.id, 'one');
      expect(disclosure, {
        'one': ['id'],
      });
      expect(find.text('75% Private'), findsOneWidget);
      await tester.tap(find.text('Employee card one'));
      await tester.pumpAndSettle();
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(5));
      expect(tester.widget<Checkbox>(checkboxes.at(1)).onChanged, isNull);

      await tester.ensureVisible(checkboxes.at(2));
      await tester.tap(checkboxes.at(2));
      await tester.pumpAndSettle();
      expect(disclosure, {
        'one': ['id', 'name'],
      });
      expect(selected.single.privacyLevel, PrivacyLevel.moderate);
      expect(find.text('50% Private'), findsOneWidget);
      expect(
        find.textContaining('Optional attributes disclosed in'),
        findsOneWidget,
      );
      await tester.ensureVisible(checkboxes.at(3));
      await tester.tap(checkboxes.at(3));
      await tester.pumpAndSettle();
      expect(selected.single.privacyLevel, PrivacyLevel.full);
      expect(
        find.textContaining('Consider reducing disclosure'),
        findsOneWidget,
      );
      await tester.ensureVisible(checkboxes.at(4));
      await tester.tap(checkboxes.at(4));
      await tester.pumpAndSettle();
      expect(disclosure['one'], ['id', 'name', 'department', 'address']);
      expect(find.text('0% Private'), findsOneWidget);

      await tester.ensureVisible(find.text('Create Presentation'));
      await tester.tap(find.text('Create Presentation'));
      await tester.pump();
      expect(presentedIds, ['one']);
      expect(presentedDisclosure, disclosure);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      completion.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(disclosure, isEmpty);
      expect(find.text('100% Private'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('presentation failure displays an error and re-enables retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _screen(
        SpruceCredentialSelectionWidget(
          availableCredentials: [
            _credential('one', claims: {'id': 'holder'}),
          ],
          requestedAttributes: const ['id'],
          onSelectionChanged: (_, _) {},
          onPresentationCreate: (_, _) async {
            calls++;
            throw StateError('verifier unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Presentation'));
    await tester.tap(find.text('Create Presentation'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.textContaining('Failed to create presentation:'),
      findsOneWidget,
    );
    expect(find.textContaining('verifier unavailable'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'empty and retired-only wallets do not allow presentation, and replacement input recovers',
    (tester) async {
      var selected = <SelectableCredential>[];
      Future<void> show(
        List<Map<String, dynamic>> credentials,
        List<String> requested,
      ) async {
        await tester.pumpWidget(
          _screen(
            SpruceCredentialSelectionWidget(
              key: const ValueKey('selection'),
              availableCredentials: credentials,
              requestedAttributes: requested,
              onSelectionChanged: (value, _) => selected = value,
              onPresentationCreate: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show([], []);
      expect(find.text('No credentials available'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await show(
        [
          {
            'id': 'old',
            '@context': 'https://w3id.org/openbadges/v2',
            'type': 'Assertion',
          },
        ],
        ['id'],
      );
      expect(find.text(retiredOpenBadgesMessage), findsOneWidget);
      expect(selected, isEmpty);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await show(
        [
          {'id': 'bad', 'credentialSubject': 'not-a-map'},
        ],
        ['id'],
      );
      expect(
        find.textContaining('Failed to initialize credentials:'),
        findsOneWidget,
      );
      await show([_credential('new')], ['name']);
      expect(
        find.textContaining('Failed to initialize credentials:'),
        findsNothing,
      );
      expect(find.text(retiredOpenBadgesMessage), findsNothing);
      expect(selected.single.id, 'new');
      expect(selected.single.disclosedAttributes, ['name']);
    },
  );

  testWidgets(
    'multiple credentials stay independently selectable when requirements change',
    (tester) async {
      var selected = <SelectableCredential>[];
      final records = [
        _credential('one'),
        _credential('two', claims: {'department': 'Finance'}),
      ];
      Future<void> show(List<String> requested) async {
        await tester.pumpWidget(
          _screen(
            SpruceCredentialSelectionWidget(
              key: const ValueKey('selection'),
              availableCredentials: records,
              requestedAttributes: requested,
              onSelectionChanged: (value, _) => selected = value,
              onPresentationCreate: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(['id']);
      expect(selected.map((c) => c.id), ['one']);
      final secondCheckbox = find
          .descendant(
            of: find.byType(ExpansionTile).at(1),
            matching: find.byType(Checkbox),
          )
          .first;
      await tester.ensureVisible(secondCheckbox);
      await tester.tap(secondCheckbox);
      await tester.pumpAndSettle();
      expect(selected.map((c) => c.id), ['one', 'two']);
      expect(selected.last.disclosedAttributes, isEmpty);
      await show(['department']);
      expect(selected.map((c) => c.id), ['one', 'two']);
      expect(
        selected.every((c) => c.disclosedAttributes.single == 'department'),
        isTrue,
      );
    },
  );

  testWidgets(
    'cancel returns to the previous route without creating a presentation',
    (tester) async {
      var created = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: SingleChildScrollView(
                          child: SpruceCredentialSelectionWidget(
                            availableCredentials: [
                              _credential('one', claims: {}),
                            ],
                            requestedAttributes: const [],
                            onSelectionChanged: (_, _) {},
                            onPresentationCreate: (_, _) => created = true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open wallet selection'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open wallet selection'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Open wallet selection'), findsOneWidget);
      expect(created, isFalse);
    },
  );
}
