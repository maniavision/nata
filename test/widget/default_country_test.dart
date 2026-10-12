import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/otp_screen.dart';
import 'package:carrywise_app/screens/sign_up_screen.dart';
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

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });

  Future<void> pumpLogin(WidgetTester tester, {FakeAuthService? auth}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Start from an empty tree: replacing the app root would otherwise keep
    // the navigation stack of whatever screen was open before.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(appWrapper(LoginScreen(authService: auth)));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSignUp(WidgetTester tester, {FakeAuthService? auth}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Start from an empty tree: replacing the app root would otherwise keep
    // the navigation stack of whatever screen was open before.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(appWrapper(SignUpScreen(authService: auth)));
    await tester.pumpAndSettle();
  }

  Finder field(int index) => find.byType(TextField).at(index);

  group('Sign in: default country', () {
    testWidgets('starts on the USA (+1) when nobody has registered here', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+234'), findsNothing);
    });

    testWidgets('starts on the country the user registered with', (
      tester,
    ) async {
      PreferencesService().setCountry('GB');

      await pumpLogin(tester);

      expect(find.text('🇬🇧'), findsOneWidget);
      expect(find.text('+44'), findsOneWidget);
      expect(find.text('+1'), findsNothing);
    });

    testWidgets('works for an African country too (Ghana)', (tester) async {
      PreferencesService().setCountry('GH');

      await pumpLogin(tester);

      expect(find.text('🇬🇭'), findsOneWidget);
      expect(find.text('+233'), findsOneWidget);
    });

    testWidgets('a country code that is not known falls back to the USA', (
      tester,
    ) async {
      PreferencesService().setCountry('ZZ');

      await pumpLogin(tester);

      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('after registering and logging out it keeps that country', (
      tester,
    ) async {
      PreferencesService().setCountry('GH'); // sign-up
      PreferencesService().reset(); // log out

      await pumpLogin(tester);

      expect(find.text('+233'), findsOneWidget);
    });

    testWidgets('the user can still pick a different country', (tester) async {
      PreferencesService().setCountry('GB');
      await pumpLogin(tester);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search country...'),
        'Ghana',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ghana').last);
      await tester.pumpAndSettle();

      expect(find.text('+233'), findsOneWidget);
      expect(find.text('+44'), findsNothing);
    });

    testWidgets('the default dialing code is the one used to sign in (USA)', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpLogin(tester, auth: auth);

      await tester.enterText(field(0), '202 555 0123');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(auth.otpRequests, ['+12025550123']);
      expect(find.byType(OtpScreen), findsOneWidget);
    });

    testWidgets('the registered country\'s code is the one used to sign in', (
      tester,
    ) async {
      PreferencesService().setCountry('GB');
      final auth = FakeAuthService();
      await pumpLogin(tester, auth: auth);

      await tester.enterText(field(0), '07911 123456');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      // The leading 0 of a national number is dropped.
      expect(auth.otpRequests, ['+447911123456']);
    });
  });

  group('Sign up: default country', () {
    testWidgets('starts on the USA with +1', (tester) async {
      await pumpSignUp(tester);

      expect(find.text('United States'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('🇺🇸'), findsWidgets);
      expect(find.text('Nigeria'), findsNothing);
    });

    testWidgets('starts on the remembered country when there is one', (
      tester,
    ) async {
      PreferencesService().setCountry('GB');

      await pumpSignUp(tester);

      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('+44'), findsOneWidget);
      expect(find.text('🇬🇧'), findsWidgets);
      expect(find.text('United States'), findsNothing);
    });

    testWidgets('filling in the remembered country does not open the '
        'suggestion list', (tester) async {
      PreferencesService().setCountry('GB');

      await pumpSignUp(tester);

      // Only the field itself shows the name; no dropdown row repeats it.
      expect(find.text('United Kingdom'), findsOneWidget);
    });

    testWidgets('the default dialing code is the one used to register', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpSignUp(tester, auth: auth);

      await tester.enterText(field(0), 'Ada');
      await tester.enterText(field(1), 'Lovelace');
      await tester.enterText(field(3), '202 555 0123');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(auth.otpRequests, ['+12025550123']);
      expect(PreferencesService().countryIsoCode, 'US');
    });

    testWidgets('registering with another country remembers it', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpSignUp(tester, auth: auth);

      await tester.tap(field(2));
      await tester.pump();
      await tester.enterText(field(2), 'Ghana');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ghana').last);
      await tester.pump();
      await tester.enterText(field(0), 'Kofi');
      await tester.enterText(field(1), 'Mensah');
      await tester.enterText(field(3), '24 123 4567');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(auth.otpRequests, ['+233241234567']);
      expect(PreferencesService().countryIsoCode, 'GH');

      // ... and it is written to the device, so it survives a restart.
      await PreferencesService().pendingWrites;
      expect(
        (await SharedPreferences.getInstance()).getString(
          'registered_country_iso',
        ),
        'GH',
      );
    });

    testWidgets('register, log out: sign-in starts on the registered country', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpSignUp(tester, auth: auth);
      await tester.tap(field(2));
      await tester.pump();
      await tester.enterText(field(2), 'Ghana');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ghana').last);
      await tester.pump();
      await tester.enterText(field(0), 'Kofi');
      await tester.enterText(field(1), 'Mensah');
      await tester.enterText(field(3), '24 123 4567');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      PreferencesService().reset(); // the user logs out
      await pumpLogin(tester);

      expect(find.text('+233'), findsOneWidget);
      expect(find.text('🇬🇭'), findsOneWidget);
    });

    testWidgets('a failed code request does not break the country default', (
      tester,
    ) async {
      final auth = FakeAuthService()..otpError = Exception('rate limit');
      await pumpSignUp(tester, auth: auth);

      await tester.enterText(field(0), 'Ada');
      await tester.enterText(field(1), 'Lovelace');
      await tester.enterText(field(3), '202 555 0123');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Too many requests. Please wait a moment and try again.'),
        findsOneWidget,
      );
      expect(find.text('+1'), findsOneWidget);
    });
  });
}
