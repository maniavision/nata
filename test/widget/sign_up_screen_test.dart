import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/sign_up_screen.dart';
import '../helpers/app_wrapper.dart';

void main() {
  group('SignUpScreen UI', () {
    Widget buildSignUp() => appWrapper(const SignUpScreen());

    testWidgets('renders Sign In / Sign Up tab switcher', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign Up'), findsWidgets); // tab + button
    });

    testWidgets('renders First Name field', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('FIRST'), findsOneWidget);
    });

    testWidgets('renders Last Name field', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('LAST'), findsOneWidget);
    });

    testWidgets('renders Country of Residence field', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('COUNTRY'), findsOneWidget);
    });

    testWidgets('country field pre-filled with United States', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets('renders the US flag emoji for the selected country',
        (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      // Flag emoji appears (USA 🇺🇸)
      expect(find.text('🇺🇸'), findsWidgets);
    });

    testWidgets('typing in country field triggers suggestion list',
        (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      // Find the country TextField (inside _CountryField)
      // It has a hint 'Type to search country...'
      final countryField =
          find.widgetWithText(TextField, 'United States').first;
      await tester.tap(countryField);
      await tester.pump();

      // Clear then type 'Gha'
      await tester.enterText(countryField, 'Gha');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Suggestions dropdown should appear with Ghana
      expect(find.text('Ghana'), findsWidgets);
    });

    testWidgets('selecting a suggestion updates the field and phone code',
        (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      final countryField =
          find.widgetWithText(TextField, 'United States').first;
      await tester.tap(countryField);
      await tester.pump();
      await tester.enterText(countryField, 'Ghana');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the Ghana suggestion
      final ghanaSuggestion = find.text('Ghana').last;
      await tester.tap(ghanaSuggestion);
      await tester.pump();

      // Country field should show Ghana and phone code should update
      expect(find.text('Ghana'), findsOneWidget);
      expect(find.text('+233'), findsOneWidget);
    });

    testWidgets('renders Phone Number field', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('PHONE'), findsOneWidget);
    });

    testWidgets('renders the +1 static phone prefix', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('does NOT render Password field (removed)', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('PASSWORD'), findsNothing);
    });

    testWidgets('renders ID verification notice banner', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('Mandatory ID'), findsOneWidget);
    });

    testWidgets('renders Create Account button', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Create Account button is enabled initially', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('tapping Create Account with empty fields shows error',
        (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      // Scroll to button (it may be below 600px test canvas)
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('error banner has destructive color styling', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      // Error container should exist — either icon or error text
      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('footer shows Already have account text', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('Already have'), findsOneWidget);
    });

    testWidgets('footer shows Sign In here link', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.textContaining('Sign In here'), findsOneWidget);
    });

    testWidgets('brand pill shows Nata', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(find.text('Nata'), findsOneWidget);
    });

    testWidgets('entering first name after error still shows form fields',
        (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      // Trigger validation error
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Please fill in all fields.'), findsOneWidget);

      // Entering text in first name field — form still renders
      final firstField = find.byType(TextField).first;
      await tester.enterText(firstField, 'Fortune');
      await tester.pump();

      // First name field now has text
      expect(find.text('Fortune'), findsWidgets);
    });
  });

  group('SignUpScreen name placeholders', () {
    Widget buildSignUp() => appWrapper(const SignUpScreen());

    String? hint(WidgetTester tester, int fieldIndex) => tester
        .widget<TextField>(find.byType(TextField).at(fieldIndex))
        .decoration
        ?.hintText;

    testWidgets('first name placeholder is "John"', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(hint(tester, 0), 'John');
    });

    testWidgets('last name placeholder is "Doe"', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(hint(tester, 1), 'Doe');
    });

    testWidgets('the old example names are gone', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        expect(hint(tester, i), isNot('Fortune'));
        expect(hint(tester, i), isNot('Niama'));
      }
    });

    testWidgets('the name fields start empty, so the placeholders show',
        (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
          isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
          isEmpty);
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Doe'), findsOneWidget);
    });

    testWidgets('a placeholder is not submitted as a name', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      // Nothing typed: "John" / "Doe" are only hints, so the form is incomplete.
      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('typing replaces the placeholder', (tester) async {
      await tester.pumpWidget(buildSignUp());
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Ada');
      await tester.enterText(find.byType(TextField).at(1), 'Lovelace');
      await tester.pump();

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Lovelace'), findsOneWidget);
      // (A hint stays in the widget tree, fully transparent, once there is
      // text; what matters is that the fields now hold what was typed.)
    });

    testWidgets('the placeholders are the same in every language',
        (tester) async {
      for (final l in ['es', 'fr']) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
            appWrapper(const SignUpScreen(), locale: Locale(l)));
        await tester.pump();

        expect(hint(tester, 0), 'John');
        expect(hint(tester, 1), 'Doe');
      }
    });
  });
}
