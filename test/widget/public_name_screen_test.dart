import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/screens/public_name_screen.dart';
import 'package:carrywise_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Travelers choose how people who find them see their name.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<FakeAuthService> pump(
    WidgetTester tester, {
    bool usePseudonym = false,
    String? pseudonym,
    FakeAuthService? auth,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final a = auth ?? FakeAuthService();
    await tester.pumpWidget(
      appWrapper(
        PublicNameScreen(
          firstName: 'Daniel',
          lastName: 'Okafor',
          verified: true,
          rating: 4.9,
          usePseudonym: usePseudonym,
          pseudonym: pseudonym,
          authService: a,
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return a;
  }

  Finder shown() => find.byKey(const ValueKey('public-name-shown'));

  testWidgets('starts on the real name: first name and last initial', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('My name'), findsOneWidget);
    expect(find.byKey(const ValueKey('public-name-field')), findsNothing);
    expect(tester.widget<Text>(shown()).data, 'Daniel O.');
  });

  testWidgets('choosing a pseudonym previews it and saves it', (tester) async {
    final auth = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('public-name-pseudonym')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('public-name-field')),
      ' SkyCourier ',
    );
    await tester.pump();
    expect(tester.widget<Text>(shown()).data, 'SkyCourier');

    await tester.tap(find.byKey(const ValueKey('public-name-save')));
    await tester.pumpAndSettle();

    expect(auth.publicNames.single.use, isTrue);
    expect(auth.publicNames.single.pseudonym, 'SkyCourier');
  });

  testWidgets('a too-short pseudonym is refused before saving', (tester) async {
    final auth = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('public-name-pseudonym')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('public-name-field')),
      'D',
    );
    await tester.tap(find.byKey(const ValueKey('public-name-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Use 2 to 20 letters or numbers (spaces and . _ - are fine).'),
      findsOneWidget,
    );
    expect(auth.publicNames, isEmpty);
  });

  testWidgets('a name kept for Nata is refused', (tester) async {
    final auth = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('public-name-pseudonym')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('public-name-field')),
      'NataSupport',
    );
    await tester.tap(find.byKey(const ValueKey('public-name-save')));
    await tester.pumpAndSettle();

    expect(
      find.text("This name can't be used. Please choose another."),
      findsOneWidget,
    );
    expect(auth.publicNames, isEmpty);
  });

  testWidgets('the server refusing it says so too', (tester) async {
    final auth = FakeAuthService()
      ..publicNameError = const PseudonymException(reserved: true);
    await pump(tester, auth: auth);

    await tester.tap(find.byKey(const ValueKey('public-name-pseudonym')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('public-name-field')),
      'Kofi Flies',
    );
    await tester.tap(find.byKey(const ValueKey('public-name-save')));
    await tester.pumpAndSettle();

    expect(
      find.text("This name can't be used. Please choose another."),
      findsOneWidget,
    );
  });

  testWidgets('switching back to the real name saves that', (tester) async {
    final auth = await pump(
      tester,
      usePseudonym: true,
      pseudonym: 'SkyCourier',
    );
    expect(tester.widget<Text>(shown()).data, 'SkyCourier');

    await tester.tap(find.byKey(const ValueKey('public-name-real')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(shown()).data, 'Daniel O.');
    await tester.tap(find.byKey(const ValueKey('public-name-save')));
    await tester.pumpAndSettle();

    expect(auth.publicNames.single.use, isFalse);
  });

  test('pseudonym rules', () {
    expect(PublicNameScreen.check('SkyCourier'), isNull);
    expect(PublicNameScreen.check('Kofi M.'), isNull);
    expect(PublicNameScreen.check('Élodie_2'), isNull);
    expect(PublicNameScreen.check('D'), PseudonymProblem.invalid);
    expect(PublicNameScreen.check('-Sky'), PseudonymProblem.invalid);
    expect(PublicNameScreen.check('a' * 21), PseudonymProblem.invalid);
    expect(PublicNameScreen.check('Sky!'), PseudonymProblem.invalid);
    expect(PublicNameScreen.check('admin1'), PseudonymProblem.reserved);
  });

  testWidgets('in French', (tester) async {
    await pump(tester, locale: const Locale('fr'));

    expect(find.text('Nom public'), findsOneWidget);
    expect(find.text('Un pseudonyme'), findsOneWidget);
  });

  testWidgets('Profile shows the public name and opens the setting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = FakeAuthService(
      profile: const {
        'first_name': 'Fortune',
        'last_name': 'Niama',
        'verification_status': 'verified',
        'use_pseudonym': true,
        'pseudonym': 'SkyCourier',
      },
    );
    await tester.pumpWidget(appWrapper(ProfileScreen(authService: auth)));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('profile-public-name'));
    expect(
      find.descendant(of: row, matching: find.text('SkyCourier')),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(PublicNameScreen), findsOneWidget);
  });
}
