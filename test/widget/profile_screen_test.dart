import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/services/biometric_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  group('ProfileScreen Widget Tests', () {
    Widget buildProfile() =>
        appWrapper(ProfileScreen(authService: FakeAuthService()));

    setUpAll(() {
      // Avoid issues with GoogleFonts in tests
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('renders account and profile header', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      expect(find.text('Account & Profile'), findsOneWidget);
    });

    testWidgets('renders profile name', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      expect(find.text('Fortune Niama'), findsOneWidget);
    });

    testWidgets('renders avatar with camera icon overlay', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      // The camera icon is inside a GestureDetector
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('renders verified badge', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('a Payment methods row, no wallet', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      expect(find.text('Payment methods'), findsOneWidget);
      expect(find.text('Wallet'), findsNothing);
      expect(find.text('\$320.00 available'), findsNothing);
    });

    testWidgets('renders settings list items', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('Identity Verification'), findsOneWidget);
    });

    group('currency picker', () {
      tearDown(() => PreferencesService().setCurrency(AppCurrency.usd));

      Future<void> openPicker(WidgetTester tester, String? local) async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          appWrapper(
            ProfileScreen(
              authService: FakeAuthService(),
              localCurrencyLookup: (iso) async => iso == 'NG' ? local : null,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Currency'));
        await tester.pumpAndSettle();
      }

      testWidgets('offers the currency of the country of residence', (
        tester,
      ) async {
        await openPicker(tester, 'NGN');
        expect(find.text('USD, EUR, GBP, NGN'), findsOneWidget);
        expect(find.byKey(const ValueKey('currency-XOF')), findsNothing);
        expect(find.text('Local currency'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('currency-NGN')));
        await tester.pumpAndSettle();
        expect(PreferencesService().currency.code, 'NGN');
      });

      testWidgets('no fourth choice when it is already offered', (
        tester,
      ) async {
        await openPicker(tester, 'EUR');
        expect(find.text('USD, EUR, GBP'), findsOneWidget);
        expect(find.byKey(const ValueKey('currency-EUR')), findsOneWidget);
        expect(find.text('Local currency'), findsNothing);
      });

      testWidgets('three choices when the country has no known currency', (
        tester,
      ) async {
        await openPicker(tester, null);
        expect(find.byKey(const ValueKey('currency-GBP')), findsOneWidget);
        expect(find.text('Local currency'), findsNothing);
      });
    });

    testWidgets('renders logout button', (tester) async {
      await tester.pumpWidget(buildProfile());
      await tester.pump();

      expect(find.text('Log Out'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });
  });

  group('ProfileScreen verification status', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pump(
      WidgetTester tester,
      String status, {
      Locale locale = const Locale('en'),
    }) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = FakeAuthService()
        ..profile = {
          'first_name': 'Fortune',
          'last_name': 'Niama',
          'verification_status': status,
          'created_at': '2025-03-01T10:00:00+00:00',
        };
      await tester.pumpWidget(
        appWrapper(ProfileScreen(authService: auth), locale: locale),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('verified: badge and tier line, no stray comma', (
      tester,
    ) async {
      await pump(tester, 'verified');

      expect(find.text('Tier 1 Verified'), findsOneWidget);
      expect(find.text('Tier 1 Verified,'), findsNothing);
      expect(
        find.text('Tier 1 Verified · Passport & Biometrics'),
        findsOneWidget,
      );
    });

    testWidgets('pending: badge, subtitle and trailing label', (tester) async {
      await pump(tester, 'pending');

      expect(find.text('Verification pending'), findsOneWidget);
      expect(find.text('Verification pending,'), findsNothing);
      expect(
        find.text('Verification is currently under review'),
        findsOneWidget,
      );
      expect(find.text('Reviewing'), findsOneWidget);
    });

    testWidgets('unverified: badge and the call to action', (tester) async {
      await pump(tester, 'unverified');

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Unverified,'), findsNothing);
      expect(
        find.text('Action Required: Verify your identity'),
        findsOneWidget,
      );
    });

    testWidgets('the call to action is translated to Spanish', (tester) async {
      await pump(tester, 'unverified', locale: const Locale('es'));

      expect(
        find.text('Acción requerida: verifica tu identidad'),
        findsOneWidget,
      );
      expect(find.text('Sin verificar'), findsOneWidget);
      expect(find.text('Action Required: Verify your identity'), findsNothing);
    });

    testWidgets('the call to action is translated to French', (tester) async {
      await pump(tester, 'unverified', locale: const Locale('fr'));

      expect(
        find.text('Action requise : vérifiez votre identité'),
        findsOneWidget,
      );
      expect(find.text('Non vérifié'), findsOneWidget);
    });

    testWidgets('the pending state is translated too', (tester) async {
      await pump(tester, 'pending', locale: const Locale('es'));

      expect(
        find.text('La verificación está actualmente en revisión'),
        findsOneWidget,
      );
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Verificación pendiente'), findsOneWidget);
    });
  });

  group('ProfileScreen data and actions', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    testWidgets('shows the name from the account', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        appWrapper(ProfileScreen(authService: FakeAuthService())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fortune Niama'), findsOneWidget);
    });

    testWidgets('keeps working when the profile cannot be loaded', (
      tester,
    ) async {
      final auth = FakeAuthService()..failProfile = true;

      await tester.pumpWidget(appWrapper(ProfileScreen(authService: auth)));
      await tester.pumpAndSettle();

      expect(find.text('Account & Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Log Out signs out and returns to the sign-in screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = FakeAuthService();

      await tester.pumpWidget(appWrapper(ProfileScreen(authService: auth)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    testWidgets('shows the same bottom navigation as every screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWrapper(ProfileScreen(authService: FakeAuthService())),
      );
      await tester.pumpAndSettle();

      for (final l in ['Home', 'Requests', 'Trips', 'Messages', 'Profile']) {
        expect(find.text(l), findsWidgets);
      }
    });
  });

  group('Face ID row', () {
    setUp(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      await PreferencesService().resetAll();
    });
    tearDown(() => PreferencesService().resetAll());

    Future<void> show(WidgetTester tester, FakeBiometricService bio) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          ProfileScreen(authService: FakeAuthService(), biometrics: bio),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder row() => find.byKey(const ValueKey('profile-face-id'));

    testWidgets('says Off, and turning it on asks for the face', (
      tester,
    ) async {
      final bio = FakeBiometricService();
      await show(tester, bio);

      expect(
        find.descendant(of: row(), matching: find.text('Off')),
        findsOneWidget,
      );
      await tester.tap(row());
      await tester.pumpAndSettle();

      expect(bio.authenticateCalls, 1);
      expect(PreferencesService().faceIdEnabled, isTrue);
      expect(
        find.descendant(of: row(), matching: find.text('On')),
        findsOneWidget,
      );
    });

    testWidgets('says On when enabled, and tapping turns it off', (
      tester,
    ) async {
      PreferencesService().setFaceIdEnabled(true);
      final bio = FakeBiometricService();
      await show(tester, bio);

      expect(
        find.descendant(of: row(), matching: find.text('On')),
        findsOneWidget,
      );
      await tester.tap(row());
      await tester.pumpAndSettle();

      expect(bio.authenticateCalls, 0);
      expect(PreferencesService().faceIdEnabled, isFalse);
      expect(
        find.descendant(of: row(), matching: find.text('Off')),
        findsOneWidget,
      );
    });

    testWidgets('stays off when the face is not recognised', (tester) async {
      final bio = FakeBiometricService()..result = BiometricResult.failed;
      await show(tester, bio);

      await tester.tap(row());
      await tester.pumpAndSettle();

      expect(PreferencesService().faceIdEnabled, isFalse);
    });

    testWidgets('is hidden on a phone without Face ID', (tester) async {
      final bio = FakeBiometricService()
        ..availabilityResult = BiometricAvailability.unsupported;
      await show(tester, bio);

      expect(row(), findsNothing);
    });
  });
}
