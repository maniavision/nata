import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/login_screen.dart';
import '../helpers/app_wrapper.dart';

void main() {
  group('LoginScreen UI', () {
    Widget buildLogin() => appWrapper(const LoginScreen());

    testWidgets('renders Sign In / Sign Up tab switcher', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('Sign In'), findsWidgets); // tab + button
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('renders phone number label', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      // Field label (uppercase)
      expect(find.textContaining('PHONE'), findsOneWidget);
    });

    testWidgets('renders the +1 (USA) country code by default', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('renders the US flag emoji by default', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('🇺🇸'), findsOneWidget);
    });

    testWidgets('renders Remember me checkbox', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('Remember me'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('Remember me checkbox starts checked', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('tapping Remember me toggles it off', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('renders Face ID button', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('Face ID'), findsOneWidget);
    });

    testWidgets('Sign In button present', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets(
      'Sign In button enabled (phone field empty → shows error not crash)',
      (tester) async {
        await tester.pumpWidget(buildLogin());
        await tester.pump();

        // Button should be tappable (not null onPressed) since _loading is false
        final btn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Sign In'),
        );
        expect(btn.onPressed, isNotNull);
      },
    );

    testWidgets('tapping Sign In with empty phone shows error banner', (
      tester,
    ) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      // Clear whatever default text exists
      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Please enter your phone number.'), findsOneWidget);
    });

    testWidgets('footer shows "New to Nata?" text', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.textContaining('New to'), findsOneWidget);
    });

    testWidgets('footer shows tagline', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.textContaining('100% verified'), findsOneWidget);
    });

    testWidgets('renders hero image widget', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      // Image.network inside the hero
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('brand pill shows app name', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('Nata'), findsOneWidget);
    });
  });
}
