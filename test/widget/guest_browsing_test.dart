import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/sign_up_screen.dart';
import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/splash_screen.dart';
import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:carrywise_app/services/auth_gate.dart';
import 'package:carrywise_app/widgets/sign_in_prompt_sheet.dart';
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
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(SignInPromptSheet), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(
        find.text(
          "Create a free account to see Daniel's profile and send a "
          'delivery request.',
        ),
        findsOneWidget,
      );
      expect(find.text('Verified travelers only'), findsOneWidget);
    });

    testWidgets('the prompt opens Sign In or Sign Up', (tester) async {
      signedOut();
      await pumpResults(tester);

      await tester.tap(find.text('Daniel Okafor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign-in-prompt-create')));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPromptSheet), findsNothing);
      expect(find.byType(SignUpScreen), findsOneWidget);
    });

    for (final key in ['sign-in-prompt-not-now', 'sign-in-prompt-close']) {
      testWidgets('$key keeps the visitor on the results', (tester) async {
        signedOut();
        await pumpResults(tester);
        await tester.tap(find.text('Daniel Okafor'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();

        expect(find.byType(SignInPromptSheet), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.text('Daniel Okafor'), findsOneWidget);
      });
    }

    testWidgets('closing Sign In goes back to the results', (tester) async {
      signedOut();
      await pumpResults(tester);
      await tester.tap(find.text('Daniel Okafor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign-in-prompt-sign-in')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

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

    testWidgets('the visitor Home, as designed', (tester) async {
      signedOut();
      await pumpHome(tester);

      // Header: the logo (no "Nata" title), Sign In and Sign Up.
      expect(find.byKey(const ValueKey('nata-logo')), findsOneWidget);
      expect(find.text('Nata'), findsNothing);
      expect(find.text('Send with trusted travelers'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-sign-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-sign-up')), findsOneWidget);
      // The banner, the search, the preview and how it works.
      expect(
        find.text('Send items abroad with a traveler already going there'),
        findsOneWidget,
      );
      expect(find.text('Create a free account'), findsOneWidget);
      expect(find.text('Search Travelers'), findsOneWidget);
      expect(find.text('Travelers Going Soon'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-preview-label')), findsOneWidget);
      expect(find.text('How it works'), findsOneWidget);
      // Nothing for signed-in users.
      expect(find.text('Hello,'), findsNothing);
      expect(find.byKey(const ValueKey('home-notifications')), findsNothing);
      expect(find.text('Add a Trip'), findsNothing);
      expect(find.text('View all'), findsNothing);
      expect(find.text('Requests'), findsNothing);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('Sign In ↔ Sign Up switch instantly, like the tabs', (
      tester,
    ) async {
      signedOut();
      await pumpHome(tester);
      await tester.tap(find.byKey(const ValueKey('home-sign-in')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up').first);
      await tester.pump(); // one frame: no slide
      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Still a way back to browsing.
      await tester.tap(find.byKey(const ValueKey('auth-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-guest-hero')), findsOneWidget);
    });

    testWidgets('Sign In opens it, with a way back', (tester) async {
      signedOut();
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-sign-in')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('auth-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-guest-hero')), findsOneWidget);
    });

    for (final key in ['home-sign-up', 'home-create-account']) {
      testWidgets('$key opens Sign Up', (tester) async {
        signedOut();
        await pumpHome(tester);

        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.byType(SignUpScreen), findsOneWidget);
      });
    }

    testWidgets('a traveler in the preview asks to sign in', (tester) async {
      signedOut();
      await pumpHome(tester);
      await tester.pumpAndSettle();

      final first = find.byKey(const ValueKey('home-preview-label'));
      expect(first, findsOneWidget);
      final traveler = find.textContaining(' K.').first;
      await tester.ensureVisible(traveler);
      await tester.tap(traveler);
      await tester.pumpAndSettle();
      expect(find.byType(SignInPromptSheet), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('nobody from their city: travelers from anywhere', (
      tester,
    ) async {
      signedOut();
      bigScreen(tester);
      final travelers = FakeTravelerService()..noneOnRoute = true;
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: travelers,
            capitalLookup: fakeCapitalLookup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(travelers.searchCalls.last['departureCity'], isNull);
      expect(find.text('No travelers on this route yet.'), findsNothing);
      expect(find.textContaining(' K.'), findsWidgets);
    });

    testWidgets('signed in, an empty route stays empty', (tester) async {
      bigScreen(tester);
      final travelers = FakeTravelerService()..noneOnRoute = true;
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: travelers,
            capitalLookup: fakeCapitalLookup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        travelers.searchCalls.every((c) => c['departureCity'] != null),
        isTrue,
      );
    });

    testWidgets('signed in: the name, notifications and tabs', (tester) async {
      await pumpHome(tester);

      expect(find.text('Fortune'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-notifications')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-sign-in')), findsNothing);
      expect(find.byKey(const ValueKey('home-guest-hero')), findsNothing);
      expect(find.text('How it works'), findsNothing);
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

      expect(find.text('Créer un compte gratuit'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Comment ça marche'), findsOneWidget);
    });
  });
}
