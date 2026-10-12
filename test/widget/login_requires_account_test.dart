import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/otp_screen.dart';
import 'package:carrywise_app/screens/sign_up_screen.dart';
import 'package:carrywise_app/services/auth_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(appWrapper(screen, locale: locale));
    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '06 123 4567');
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
  }

  const notFound = 'No account found for this number. Please sign up first.';

  group('logging in', () {
    testWidgets('asks for a code without allowing a new account', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pump(tester, LoginScreen(authService: auth));

      await submitLogin(tester);

      expect(auth.otpRequests.length, 1);
      expect(auth.otpCreateUser, [false]);
      expect(find.byType(OtpScreen), findsOneWidget);
    });

    testWidgets('a number with no account never reaches the code screen', (
      tester,
    ) async {
      final auth = FakeAuthService()
        ..otpError = const AccountNotFoundException();
      await pump(tester, LoginScreen(authService: auth));

      await submitLogin(tester);

      expect(find.byType(OtpScreen), findsNothing);
      expect(find.text(notFound), findsOneWidget);
    });

    testWidgets('the message is translated', (tester) async {
      final auth = FakeAuthService()
        ..otpError = const AccountNotFoundException();
      await pump(
        tester,
        LoginScreen(authService: auth),
        locale: const Locale('fr'),
      );

      await submitLogin(tester);

      expect(
        find.text(
          "Aucun compte n'existe pour ce numéro. Veuillez d'abord vous inscrire.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('the button works again afterwards', (tester) async {
      final auth = FakeAuthService()
        ..otpError = const AccountNotFoundException();
      await pump(tester, LoginScreen(authService: auth));
      await submitLogin(tester);

      auth.otpError = null;
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(find.byType(OtpScreen), findsOneWidget);
      expect(auth.otpRequests.length, 2);
    });

    testWidgets('other failures keep their own message', (tester) async {
      final auth = FakeAuthService()..otpError = Exception('rate limit');
      await pump(tester, LoginScreen(authService: auth));

      await submitLogin(tester);

      expect(
        find.text('Too many requests. Please wait a moment.'),
        findsOneWidget,
      );
      expect(find.text(notFound), findsNothing);
    });

    testWidgets('an empty number sends nothing', (tester) async {
      final auth = FakeAuthService();
      await pump(tester, LoginScreen(authService: auth));

      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(auth.otpRequests, isEmpty);
    });
  });

  group('signing up', () {
    testWidgets('may create the account', (tester) async {
      final auth = FakeAuthService();
      await pump(tester, SignUpScreen(authService: auth));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ada');
      await tester.enterText(fields.at(1), 'Lovelace');
      await tester.enterText(fields.at(3), '06 123 4567');

      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(auth.otpCreateUser, [true]);
      expect(find.byType(OtpScreen), findsOneWidget);
    });
  });

  group('"Resend code"', () {
    Future<void> resend(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Resend code'));
      await tester.pump();
    }

    testWidgets('when logging in, still does not create an account', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pump(
        tester,
        OtpScreen(
          phone: '+242061234567',
          isSignUp: false,
          onSuccess: () {},
          authService: auth,
        ),
      );

      await resend(tester);

      expect(auth.otpRequests, ['+242061234567']);
      expect(auth.otpCreateUser, [false]);
    });

    testWidgets('when signing up, may create the account', (tester) async {
      final auth = FakeAuthService();
      await pump(
        tester,
        OtpScreen(
          phone: '+242061234567',
          isSignUp: true,
          firstName: 'Ada',
          lastName: 'L',
          onSuccess: () {},
          authService: auth,
        ),
      );

      await resend(tester);

      expect(auth.otpCreateUser, [true]);
    });
  });
}
