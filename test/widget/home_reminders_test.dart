import 'package:carrywise_app/services/route_alert_service.dart';
import 'package:carrywise_app/widgets/home_reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_wrapper.dart';

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    await pump(tester, status: null, routes: 1);
    expect(find.byKey(const ValueKey('home-reminders')), findsNothing);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));
    expect(find.text('Vérifiez votre identité'), findsOneWidget);
    expect(find.text('Ajouter un trajet'), findsOneWidget);
  });
}
