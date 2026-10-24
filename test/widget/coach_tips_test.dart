import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/services/route_alert_service.dart';
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

  testWidgets('a first visit to Home starts with the Add a Trip tip', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Do you have an upcoming trip?'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Next goes through every tip, then they are gone', (
    tester,
  ) async {
    await pumpHome(tester);
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
    expect(prefs.getBool(CoachTips.seenKey('home', 'me')), isTrue);
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
    expect(find.text('Vous avez un voyage prévu ?'), findsOneWidget);
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
}
