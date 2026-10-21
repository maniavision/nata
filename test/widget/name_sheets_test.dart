import 'package:carrywise_app/services/auth_service.dart';
import 'package:carrywise_app/widgets/name_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<(String, String)> saved;
  Object? saveError;
  Uri? emailed;
  bool? result;

  setUp(() {
    saved = [];
    saveError = null;
    emailed = null;
    result = null;
  });

  Future<void> open(
    WidgetTester tester,
    String status, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showNameSheet(
                  context,
                  verificationStatus: status,
                  firstName: 'Fortune',
                  lastName: 'Niama',
                  save: (f, l) async {
                    if (saveError != null) throw saveError!;
                    saved.add((f, l));
                  },
                  openEmail: (u) async => emailed = u,
                );
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  group('not verified yet', () {
    testWidgets('edits the name, trimmed', (tester) async {
      await open(tester, 'unverified');
      expect(find.byKey(const ValueKey('edit-name-sheet')), findsOneWidget);
      expect(find.text('Fortune'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('edit-last-name')),
        '  Niama-Kouba ',
      );
      await tester.tap(find.byKey(const ValueKey('edit-name-save')));
      await tester.pumpAndSettle();

      expect(saved, [('Fortune', 'Niama-Kouba')]);
      expect(result, isTrue);
      expect(find.byKey(const ValueKey('edit-name-sheet')), findsNothing);
    });

    testWidgets('both names are needed', (tester) async {
      await open(tester, 'unverified');
      await tester.enterText(find.byKey(const ValueKey('edit-first-name')), '');
      await tester.tap(find.byKey(const ValueKey('edit-name-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your first and last name.'), findsOneWidget);
      expect(saved, isEmpty);
    });

    testWidgets('locked meanwhile by the server: says so', (tester) async {
      saveError = const NameLockedException();
      await open(tester, 'rejected');
      await tester.tap(find.byKey(const ValueKey('edit-name-save')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Your name can't be changed now that your identity check has started.",
        ),
        findsOneWidget,
      );
    });
  });

  for (final status in ['pending', 'verified']) {
    testWidgets('$status: locked, with a way to contact support', (
      tester,
    ) async {
      await open(tester, status);
      expect(find.byKey(const ValueKey('name-locked-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-name-sheet')), findsNothing);
      expect(find.text('Your name matches your ID'), findsOneWidget);
      expect(find.text('Fortune Niama'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('name-contact-support')));
      await tester.pumpAndSettle();
      expect(emailed?.scheme, 'mailto');
      expect(emailed?.path, 'support@nata.com');
      expect(emailed?.query, contains('Name%20change%20request'));
    });
  }

  testWidgets('is translated', (tester) async {
    await open(tester, 'verified', locale: const Locale('es'));
    expect(find.text('Tu nombre coincide con tu documento'), findsOneWidget);
    expect(find.text('Contactar con soporte'), findsOneWidget);
  });
}
