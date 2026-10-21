import 'package:carrywise_app/screens/splash_screen.dart';
import 'package:carrywise_app/services/auth_gate.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_wrapper.dart';

/// Which page the app opens on.
void main() {
  late bool signedIn;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    signedIn = false;
    AuthGate.isSignedIn = () => signedIn;
  });
  tearDown(() async {
    AuthGate.isSignedIn = () => false;
    await PreferencesService().resetAll();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      appWrapper(
        startScreen(
          login: (_) => const Text('SIGN IN'),
          splash: (_) => const Text('SPLASH'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a first-time visitor sees the splash', (tester) async {
    await open(tester);
    expect(find.text('SPLASH'), findsOneWidget);
  });

  testWidgets('a member who used this device goes straight to Sign In', (
    tester,
  ) async {
    PreferencesService().rememberAccount();
    await open(tester);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('SPLASH'), findsNothing);
  });

  testWidgets('a kept session goes to Sign In too (Face ID)', (tester) async {
    signedIn = true;
    await open(tester);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('after the account is deleted: the splash again', (tester) async {
    PreferencesService()
      ..rememberAccount()
      ..forgetAccount();
    await open(tester);
    expect(find.text('SPLASH'), findsOneWidget);
  });

  testWidgets('their language is back on the next launch', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language': 'fr',
      'currency': 'EUR',
      'has_account': true,
    });
    await PreferencesService().restore();
    expect(PreferencesService().language, AppLanguage.french);
    expect(PreferencesService().currency, AppCurrency.eur);
    await open(tester);
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
