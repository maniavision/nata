import 'package:carrywise_app/services/route_alert_service.dart';
import 'package:carrywise_app/widgets/verified_route_nudge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

class _Routes extends Fake implements RouteAlertService {
  _Routes(this.count);
  int count;
  bool fail = false;

  @override
  Future<List<RouteAlert>> list() async {
    if (fail) throw Exception('offline');
    return [
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
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final card = find.byKey(const ValueKey('verified-route-nudge'));

  Future<void> pump(
    WidgetTester tester, {
    required _Routes routes,
    FakeTripService? trips,
  }) async {
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: VerifiedRouteNudge(
            routeService: routes,
            tripService: trips ?? FakeTripService(),
            // Saving a route on the next page.
            routesBuilder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  routes.count = 1;
                  Navigator.of(context).pop();
                },
                child: const Text('save route'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks a likely sender to create a route alert', (tester) async {
    await pump(tester, routes: _Routes(0));

    expect(card, findsOneWidget);
    expect(find.text('Sending something soon?'), findsOneWidget);
  });

  testWidgets('not for a member who posted a trip', (tester) async {
    await pump(
      tester,
      routes: _Routes(0),
      trips: FakeTripService(trips: [sampleMyTrip()]),
    );

    expect(card, findsNothing);
  });

  testWidgets('not when they already have a route alert', (tester) async {
    await pump(tester, routes: _Routes(1));

    expect(card, findsNothing);
  });

  testWidgets('nothing when it cannot load', (tester) async {
    await pump(tester, routes: _Routes(0)..fail = true);

    expect(card, findsNothing);
  });

  testWidgets('opens route alerts, and goes once a route is saved', (
    tester,
  ) async {
    await pump(tester, routes: _Routes(0));
    await tester.tap(find.byKey(const ValueKey('verified-route-nudge-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save route'));
    await tester.pumpAndSettle();

    expect(card, findsNothing);
  });

  testWidgets('"Maybe later" hides it', (tester) async {
    await pump(tester, routes: _Routes(0));
    await tester.tap(find.byKey(const ValueKey('verified-route-nudge-later')));
    await tester.pump();

    expect(card, findsNothing);
  });
}
