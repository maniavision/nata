import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/splash_screen.dart';
import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:carrywise_app/services/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Visitors who aren't signed in can browse Home and search travelers; going
/// further asks them to sign in, with a way back.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void signedOut() => AuthGate.isSignedIn = () => false;

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('after the splash', () {
    Future<void> continueFromSplash(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(
          SplashScreen(
            regionService: FakeRegionService(),
            guestHomeBuilder: (_) => const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('a visitor goes straight to Home', (tester) async {
      signedOut();
      await continueFromSplash(tester);

      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('someone with a saved session goes to Sign In (Face ID)', (
      tester,
    ) async {
      await continueFromSplash(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });
  });

  group('searching travelers', () {
    late FakeTravelerService service;

    setUp(() => service = FakeTravelerService());

    Future<void> pumpResults(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(TravelerResultsScreen(service: service)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a visitor sees the results', (tester) async {
      signedOut();
      await pumpResults(tester);

      expect(service.searchCalls, hasLength(1));
      expect(find.text('Daniel Okafor'), findsOneWidget);
    });

    testWidgets('opening a traveler asks a visitor to sign in', (tester) async {
      signedOut();
      await pumpResults(tester);

      await tester.tap(find.text('Daniel Okafor'));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerProfileScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Sign in or create an account to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('closing Sign In goes back to the results', (tester) async {
      signedOut();
      await pumpResults(tester);
      await tester.tap(find.text('Daniel Okafor'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('auth-close')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Daniel Okafor'), findsOneWidget);
    });

    testWidgets('signed in, the traveler opens as before', (tester) async {
      await pumpResults(tester);

      await tester.tap(find.text('Daniel Okafor'));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerProfileScreen), findsOneWidget);
    });
  });

  group('Home for a visitor', () {
    Future<void> pumpHome(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
            capitalLookup: fakeCapitalLookup,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('greets the guest, without notifications or tabs', (
      tester,
    ) async {
      signedOut();
      await pumpHome(tester);

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Fortune Niama'), findsNothing);
      expect(find.byKey(const ValueKey('home-notifications')), findsNothing);
      expect(find.text('Requests'), findsNothing);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('signed in: the name, notifications and tabs', (tester) async {
      await pumpHome(tester);

      expect(find.text('Fortune Niama'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-notifications')), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
    });

    testWidgets('translated', (tester) async {
      signedOut();
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
            capitalLookup: fakeCapitalLookup,
          ),
          locale: const Locale('fr'),
        ),
      );
      await tester.pump();

      expect(find.text('Invité'), findsOneWidget);
    });
  });
}
