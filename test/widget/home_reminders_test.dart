import 'package:carrywise_app/services/route_alert_service.dart';
import 'package:carrywise_app/widgets/home_reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carrywise_app/services/biometric_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

class _Routes extends Fake implements RouteAlertService {
  _Routes(this.count);
  int count;

  @override
  Future<List<RouteAlert>> list() async => [
    for (var i = 0; i < count; i++)
      RouteAlert(
        id: '$i',
        fromCityId: 1,
        fromCity: 'Lagos',
        fromCountryCode: 'NG',
        fromCountry: 'Nigeria',
        toCityId: 2,
        toCity: 'London',
        toCountryCode: 'GB',
        toCountry: 'United Kingdom',
      ),
  ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late FakeBiometricService bio;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    bio = FakeBiometricService();
  });
  tearDown(() => PreferencesService().resetAll());

  Future<void> pump(
    WidgetTester tester, {
    String? status = 'unverified',
    int routes = 0,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: HomeReminders(
            verificationStatus: status,
            userId: 'me',
            routeService: _Routes(routes),
            verifyBuilder: (_) => const Scaffold(body: Text('VERIFY')),
            routesBuilder: (_) => const Scaffold(body: Text('ROUTES')),
            biometrics: bio,
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new member sees both reminders', (tester) async {
    await pump(tester);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-verify')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-routes')), findsOneWidget);
  });

  testWidgets('"Verify now" opens verification', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('reminder-verify-action')));
    await tester.pumpAndSettle();
    expect(find.text('VERIFY'), findsOneWidget);
  });

  testWidgets('"Add a route" opens route alerts', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('reminder-routes-action')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTES'), findsOneWidget);
  });

  testWidgets('verified or under review: no verify reminder', (tester) async {
    await pump(tester, status: 'verified');
    expect(find.byKey(const ValueKey('reminder-verify')), findsNothing);
    expect(find.byKey(const ValueKey('reminder-routes')), findsOneWidget);

    await pump(tester, status: 'pending');
    expect(find.byKey(const ValueKey('reminder-verify')), findsNothing);
  });

  testWidgets('with a saved route: no routes reminder', (tester) async {
    PreferencesService().setFaceIdEnabled(true);
    await pump(tester, status: 'verified', routes: 1);
    expect(find.byKey(const ValueKey('home-reminders')), findsNothing);
  });

  testWidgets('closing the routes reminder keeps it closed', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('reminder-routes-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reminder-routes')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester);
    expect(find.byKey(const ValueKey('reminder-routes')), findsNothing);
    expect(find.byKey(const ValueKey('reminder-verify')), findsOneWidget);
  });

  testWidgets('nothing while the profile is loading', (tester) async {
    PreferencesService().setFaceIdEnabled(true);
    await pump(tester, status: null, routes: 1);
    expect(find.byKey(const ValueKey('home-reminders')), findsNothing);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));
    expect(find.text('Vérifiez votre identité'), findsOneWidget);
    expect(find.text('Ajouter un trajet'), findsOneWidget);
  });

  group('Face ID reminder', () {
    testWidgets('shows while Face ID is off on a phone that has it', (
      tester,
    ) async {
      await pump(tester, status: 'verified', routes: 1);
      expect(find.byKey(const ValueKey('reminder-faceid')), findsOneWidget);
      expect(find.text('Sign in with Face ID'), findsOneWidget);
    });

    testWidgets('"Turn on Face ID" asks for the face, then turns it on', (
      tester,
    ) async {
      await pump(tester, status: 'verified', routes: 1);
      await tester.tap(find.byKey(const ValueKey('reminder-faceid-action')));
      await tester.pumpAndSettle();

      expect(bio.authenticateCalls, 1);
      expect(bio.lastReason, "Confirm it's you to turn on Face ID");
      expect(PreferencesService().faceIdEnabled, isTrue);
      expect(find.byKey(const ValueKey('reminder-faceid')), findsNothing);
      expect(find.textContaining('Face ID is on'), findsOneWidget);
    });

    testWidgets('a face not recognised leaves it off and says so', (
      tester,
    ) async {
      bio.result = BiometricResult.failed;
      await pump(tester, status: 'verified', routes: 1);
      await tester.tap(find.byKey(const ValueKey('reminder-faceid-action')));
      await tester.pumpAndSettle();
      expect(PreferencesService().faceIdEnabled, isFalse);
      expect(find.byKey(const ValueKey('reminder-faceid')), findsOneWidget);
      expect(find.textContaining("didn't recognise you"), findsOneWidget);
    });

    testWidgets('already on: no reminder', (tester) async {
      PreferencesService().setFaceIdEnabled(true);
      await pump(tester, status: 'verified', routes: 1);
      expect(find.byKey(const ValueKey('home-reminders')), findsNothing);
    });

    testWidgets('a phone without Face ID or fingerprint: no reminder', (
      tester,
    ) async {
      bio.availabilityResult = BiometricAvailability.notEnrolled;
      await pump(tester, status: 'verified', routes: 1);
      expect(find.byKey(const ValueKey('reminder-faceid')), findsNothing);
    });

    testWidgets('closing it keeps it closed', (tester) async {
      await pump(tester, status: 'verified', routes: 1);
      await tester.tap(find.byKey(const ValueKey('reminder-faceid-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reminder-faceid')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, status: 'verified', routes: 1);
      expect(find.byKey(const ValueKey('reminder-faceid')), findsNothing);
    });

    testWidgets('shows with the other reminders too', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('reminder-verify')), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-routes')), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-faceid')), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      await pump(
        tester,
        status: 'verified',
        routes: 1,
        locale: const Locale('fr'),
      );
      expect(find.text('Connexion avec Face ID'), findsOneWidget);
      expect(find.text('Activer Face ID'), findsOneWidget);
    });
  });
}
