import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/messages_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/screens/trips_screen.dart';
import 'package:carrywise_app/screens/wallet_screen.dart';
import 'package:carrywise_app/services/route_alert_service.dart';
import 'package:carrywise_app/widgets/app_bottom_nav.dart';
import 'package:carrywise_app/widgets/coach_tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

class _NoRoutes extends Fake implements RouteAlertService {
  @override
  Future<List<RouteAlert>> list() async => const [];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CoachTips.enabled = true;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(
            profile: const {
              'id': 'me',
              'first_name': 'Fortune',
              'last_name': 'Niama',
              'verification_status': 'verified',
              'country_of_residence': 'NG',
            },
          ),
          travelerService: FakeTravelerService(),
          routeAlertService: _NoRoutes(),
          capitalLookup: fakeCapitalLookup,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('a first visit to Home starts with the profile tip', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Your profile'), findsOneWidget);
    expect(
      find.text('Tap your photo or name to open your profile and settings.'),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Next goes through every tip, then they are gone', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Your profile'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
    await tester.pumpAndSettle();
    expect(find.text('Do you have an upcoming trip?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
    await tester.pumpAndSettle();
    expect(find.text('Need to send something?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
    await tester.pumpAndSettle();
    expect(find.text('Your updates'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
    await tester.pumpAndSettle();
    expect(find.text('Everything in one place'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachTipsOverlay), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(CoachTips.seenKey('home', 'test-user')), isTrue);
    expect(
      prefs.getBool(CoachTips.seenKey('home-profile', 'test-user')),
      isTrue,
    );

    // The profile tip doesn't come back on its own afterwards.
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);
    expect(find.byType(CoachTipsOverlay), findsNothing);
  });

  testWidgets('members who saw the tour before get the profile tip alone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      CoachTips.seenKey('home', 'test-user'): true,
    });
    await pumpHome(tester);
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachTipsOverlay), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);
    expect(find.byType(CoachTipsOverlay), findsNothing);
  });

  testWidgets('Skip ends the tips and they are not shown again', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('coach-tip-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(CoachTipsOverlay), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);
    expect(find.byType(CoachTipsOverlay), findsNothing);
  });

  testWidgets('tips are in French for a French phone', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(
            profile: const {'id': 'me', 'first_name': 'Fortune'},
          ),
          travelerService: FakeTravelerService(),
          routeAlertService: _NoRoutes(),
          capitalLookup: fakeCapitalLookup,
        ),
        locale: const Locale('fr'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Votre profil'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
  });

  testWidgets('tips seen before are not shown again', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: Center(child: SizedBox(key: key, width: 50)),
        ),
      ),
    );
    SharedPreferences.setMockInitialValues({
      CoachTips.seenKey('home', 'me'): true,
    });
    await CoachTips.showOnce(
      key.currentContext!,
      name: 'home',
      userId: 'me',
      tips: [CoachTip(target: key, title: 'T', body: 'B', icon: Icons.add)],
    );
    await tester.pumpAndSettle();
    expect(find.byType(CoachTipsOverlay), findsNothing);
  });

  group('the other tabs have their own tips', () {
    Future<void> show(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appWrapper(page));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }

    /// Goes through every tip with Next, checking each title.
    Future<void> walk(WidgetTester tester, List<String> titles) async {
      for (final title in titles) {
        expect(
          find.descendant(
            of: find.byType(CoachTipsOverlay),
            matching: find.text(title),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
        await tester.pumpAndSettle();
      }
      expect(find.byType(CoachTipsOverlay), findsNothing);
    }

    testWidgets('Requests', (tester) async {
      await show(
        tester,
        RequestsScreen(
          requestService: FakeRequestService(),
          exchangeRates: FakeExchangeRateService(),
        ),
      );
      await walk(tester, ['Sent and received', 'Active and Archive']);
    });

    testWidgets('Trips', (tester) async {
      await show(tester, TripsScreen(service: FakeTripService(trips: [])));
      await walk(tester, ['Post a trip', 'Upcoming and past']);
    });

    testWidgets('Messages', (tester) async {
      await show(
        tester,
        MessagesScreen(service: FakeMessageService(conversations: [])),
      );
      await walk(tester, ['Find a chat', 'When chats open']);
    });

    testWidgets('Profile', (tester) async {
      await show(tester, ProfileScreen(authService: FakeAuthService()));
      await walk(tester, [
        'Your Nata Wallet',
        'Travel under a pseudonym',
        'Route alerts',
      ]);
    });

    testWidgets('Profile: those who saw it get the pseudonym tip alone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        CoachTips.seenKey('profile', 'test-user'): true,
      });
      await show(tester, ProfileScreen(authService: FakeAuthService()));
      await walk(tester, ['Travel under a pseudonym']);

      // ...once.
      await tester.pumpWidget(const SizedBox());
      await show(tester, ProfileScreen(authService: FakeAuthService()));
      expect(find.byType(CoachTipsOverlay), findsNothing);
    });

    testWidgets('Wallet', (tester) async {
      await show(
        tester,
        WalletScreen(
          authService: FakeAuthService(),
          paymentService: FakePaymentService(),
        ),
      );
      await walk(tester, ['Your Nata Wallet', 'Get paid']);
    });

    testWidgets('a tip further down scrolls its row into view first', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(ProfileScreen(authService: FakeAuthService())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('profile-route-alerts'));
      final nav = tester.getRect(find.byType(AppBottomNav));
      // Behind the tab bar or off screen before.
      expect(tester.getRect(row).bottom, greaterThan(nav.top));

      // Wallet, then the public name, then route alerts.
      await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('coach-tip-next')));
      await tester.pumpAndSettle();
      final shown = tester.getRect(row);
      expect(shown.top, greaterThanOrEqualTo(0));
      expect(shown.bottom, lessThan(nav.top));
    });

    testWidgets('each page remembers its own tips', (tester) async {
      await show(tester, TripsScreen(service: FakeTripService(trips: [])));
      await tester.tap(find.byKey(const ValueKey('coach-tip-skip')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await show(tester, TripsScreen(service: FakeTripService(trips: [])));
      expect(find.byType(CoachTipsOverlay), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await show(
        tester,
        MessagesScreen(service: FakeMessageService(conversations: [])),
      );
      expect(find.text('Find a chat'), findsOneWidget);
    });
  });
}
