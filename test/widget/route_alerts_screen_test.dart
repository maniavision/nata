import 'package:carrywise_app/screens/route_alerts_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:carrywise_app/services/route_alert_service.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

class FakeRouteAlertService extends Fake implements RouteAlertService {
  List<RouteAlert> routes = [];
  RouteAlertFailure? addFailure;
  bool failList = false;
  final added = <(int, int, int?)>[];

  /// The weight given with each route added (null: any).
  final weights = <double?>[];
  final removed = <String>[];
  final restarted = <String>[];
  bool failRestart = false;

  @override
  Future<List<RouteAlert>> list() async {
    if (failList) throw Exception('list failed');
    return [...routes];
  }

  @override
  Future<void> add({
    required int fromCityId,
    required int toCityId,
    int? maxAlerts,
    double? minWeightKg,
  }) async {
    if (addFailure != null) throw RouteAlertException(addFailure!);
    added.add((fromCityId, toCityId, maxAlerts));
    weights.add(minWeightKg);
    routes = [
      route('new-${added.length}', 'Lagos', 'NG', 'Nigeria', 'London', 'GB'),
      ...routes,
    ];
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    routes = routes.where((r) => r.id != id).toList();
  }

  @override
  Future<void> restart(String id) async {
    if (failRestart) throw Exception('restart failed');
    restarted.add(id);
    routes = [
      for (final r in routes)
        r.id == id
            ? RouteAlert(
                id: r.id,
                fromCityId: r.fromCityId,
                fromCity: r.fromCity,
                fromCountryCode: r.fromCountryCode,
                fromCountry: r.fromCountry,
                toCityId: r.toCityId,
                toCity: r.toCity,
                toCountryCode: r.toCountryCode,
                toCountry: r.toCountry,
                maxAlerts: r.maxAlerts,
              )
            : r,
    ];
  }
}

RouteAlert route(
  String id,
  String from,
  String fromCode,
  String fromCountry,
  String to,
  String toCode, {
  String toCountry = 'United Kingdom',
  int? maxAlerts,
  int alertsSent = 0,
  double? minWeightKg,
}) => RouteAlert(
  id: id,
  fromCityId: 1,
  fromCity: from,
  fromCountryCode: fromCode,
  fromCountry: fromCountry,
  toCityId: 2,
  toCity: to,
  toCountryCode: toCode,
  toCountry: toCountry,
  maxAlerts: maxAlerts,
  alertsSent: alertsSent,
  minWeightKg: minWeightKg,
);

const lagos = LocationSelection(
  country: 'Nigeria',
  countryCode: 'NG',
  city: 'Lagos',
  displayLabel: 'Lagos, Nigeria',
  cityId: 10,
);
const london = LocationSelection(
  country: 'United Kingdom',
  countryCode: 'GB',
  city: 'London',
  displayLabel: 'London, United Kingdom',
  cityId: 20,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late FakeRouteAlertService service;
  setUp(() => service = FakeRouteAlertService());

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        RouteAlertsScreen(
          service: service,
          pickPlace: (context, title) async => title == 'From' ? lagos : london,
        ),
        locale: locale ?? const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no routes yet: explains and offers to add one', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('route-alerts-empty')), findsOneWidget);
    expect(find.text('No routes yet'), findsOneWidget);
    expect(find.text('Add a route'), findsOneWidget);
  });

  testWidgets('lists saved routes with the count', (tester) async {
    service.routes = [
      route('a', 'Lagos', 'NG', 'Nigeria', 'London', 'GB'),
      route('b', 'Accra', 'GH', 'Ghana', 'Paris', 'FR', toCountry: 'France'),
    ];
    await pump(tester);
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.textContaining('Accra'), findsOneWidget);
    expect(find.textContaining('Paris'), findsOneWidget);
  });

  testWidgets('adding a route: pick From and To, save', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('route-alerts-add')));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('route-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('route-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-to')));
    await tester.pumpAndSettle();
    expect(find.text('Lagos, Nigeria'), findsOneWidget);
    expect(find.text('London, United Kingdom'), findsOneWidget);

    await tester.tap(save);
    await tester.pumpAndSettle();

    // 3 travelers unless another number is picked.
    expect(service.added, [(10, 20, 3)]);
    expect(find.byKey(const ValueKey('route-add-sheet')), findsNothing);
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets('the 6th route is refused with the reason', (tester) async {
    service.addFailure = RouteAlertFailure.limit;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('route-alerts-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-to')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('You can save up to 5 routes. Remove one to add another.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('route-add-sheet')), findsOneWidget);
  });

  testWidgets('with 5 routes, Add a route is off', (tester) async {
    service.routes = [
      for (var i = 0; i < 5; i++)
        route('r$i', 'Lagos', 'NG', 'Nigeria', 'London', 'GB'),
    ];
    await pump(tester);
    final add = tester.widget<FilledButton>(
      find.byKey(const ValueKey('route-alerts-add')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('removing a route', (tester) async {
    service.routes = [route('a', 'Lagos', 'NG', 'Nigeria', 'London', 'GB')];
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('route-remove-a')));
    await tester.pumpAndSettle();
    expect(service.removed, ['a']);
    expect(find.byKey(const ValueKey('route-alerts-empty')), findsOneWidget);
  });

  testWidgets('a loading error says so', (tester) async {
    service.failList = true;
    await pump(tester);
    expect(find.byKey(const ValueKey('route-alerts-error')), findsOneWidget);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));
    expect(find.text('Alertes trajets'), findsOneWidget);
    expect(find.text('Ajouter un trajet'), findsOneWidget);
  });

  group('the search a route alert opens', () {
    test('from the in-app notification (numbers)', () {
      final w = resultsForRouteAlert({
        'from_city_id': 10,
        'from_city': 'Lagos',
        'from_country': 'Nigeria',
        'from_country_code': 'NG',
        'to_city_id': 20,
        'to_city': 'London',
        'to_country': 'United Kingdom',
        'to_country_code': 'GB',
      });
      expect(w, isA<TravelerResultsScreen>());
      final r = w! as TravelerResultsScreen;
      expect(r.departure!.cityId, 10);
      expect(r.destination!.displayLabel, 'London, United Kingdom');
    });

    test('from a push (text)', () {
      final w = resultsForRouteAlert({
        'from_city_id': '10',
        'from_city': 'Lagos',
        'to_city_id': '20',
        'to_city': 'London',
      });
      expect((w! as TravelerResultsScreen).destination!.cityId, 20);
    });

    test('missing places: nothing to open', () {
      expect(resultsForRouteAlert({'trip_id': 'x'}), isNull);
    });
  });

  group('travelers limit', () {
    Future<void> openSheet(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('route-alerts-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('route-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('route-to')));
      await tester.pumpAndSettle();
    }

    testWidgets('offers 1, 3, 5, 10 travelers or all; 3 to start', (
      tester,
    ) async {
      await openSheet(tester);
      for (final label in [
        '1 traveler',
        '3 travelers',
        '5 travelers',
        '10 travelers',
        'All',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.text('We stop after 3 travelers. You can restart it anytime.'),
        findsOneWidget,
      );
    });

    testWidgets('the number picked is saved with the route', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('route-limit-5')));
      await tester.pumpAndSettle();
      expect(find.textContaining('We stop after 5 travelers'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-save')));
      await tester.pumpAndSettle();
      expect(service.added, [(10, 20, 5)]);
    });

    testWidgets('no weight: any traveler', (tester) async {
      await openSheet(tester);
      expect(find.text('WEIGHT TO SEND (OPTIONAL)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-save')));
      await tester.pumpAndSettle();
      expect(service.weights, [null]);
    });

    testWidgets('a weight is saved with the route', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byKey(const ValueKey('route-weight')), '2,5');
      await tester.ensureVisible(find.byKey(const ValueKey('route-save')));
      await tester.tap(find.byKey(const ValueKey('route-save')));
      await tester.pumpAndSettle();
      expect(service.weights, [2.5]);
    });

    testWidgets('with the keyboard up, the sheet sits above it', (
      tester,
    ) async {
      await openSheet(tester);
      final before = tester.getRect(
        find.byKey(const ValueKey('route-add-sheet')),
      );
      // A phone keyboard over the lower part of the screen.
      tester.view.viewInsets = const FakeViewPadding(bottom: 700);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final sheet = tester.getRect(
        find.byKey(const ValueKey('route-add-sheet')),
      );
      expect(sheet.bottom, lessThanOrEqualTo(2000 - 700));
      expect(sheet.bottom, lessThan(before.bottom));
      // Save can be reached by scrolling inside the sheet.
      await tester.enterText(find.byKey(const ValueKey('route-weight')), '4');
      await tester.ensureVisible(find.byKey(const ValueKey('route-save')));
      await tester.pumpAndSettle();
      final save = tester.getRect(find.byKey(const ValueKey('route-save')));
      expect(save.bottom, lessThanOrEqualTo(2000 - 700));
      await tester.tap(find.byKey(const ValueKey('route-save')));
      await tester.pumpAndSettle();
      expect(service.weights, [4.0]);
    });

    testWidgets('a weight that makes no sense is explained', (tester) async {
      await openSheet(tester);
      for (final bad in ['abc', '150']) {
        await tester.enterText(find.byKey(const ValueKey('route-weight')), bad);
        await tester.ensureVisible(find.byKey(const ValueKey('route-save')));
        await tester.tap(find.byKey(const ValueKey('route-save')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Enter a weight between 0.1 and 100 kg, or leave it empty.',
          ),
          findsOneWidget,
          reason: bad,
        );
      }
      expect(service.weights, isEmpty);
    });

    testWidgets('a saved route shows its weight', (tester) async {
      service.routes = [
        route(
          'a',
          'Lagos',
          'NG',
          'Nigeria',
          'London',
          'GB',
          maxAlerts: 3,
          minWeightKg: 5,
        ),
        route('b', 'Accra', 'GH', 'Ghana', 'Paris', 'FR', minWeightKg: 2.5),
        route('c', 'Accra', 'GH', 'Ghana', 'Berlin', 'DE'),
      ];
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('5 kg+'), findsOneWidget);
      expect(find.text('2.5 kg+'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-weight-c')), findsNothing);
    });

    testWidgets('All saves no limit', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('route-limit-all')));
      await tester.pumpAndSettle();
      expect(find.textContaining('every traveler'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-save')));
      await tester.pumpAndSettle();
      expect(service.added, [(10, 20, null)]);
    });

    testWidgets('each route shows how many travelers were found', (
      tester,
    ) async {
      service.routes = [
        route(
          'a',
          'Lagos',
          'NG',
          'Nigeria',
          'London',
          'GB',
          maxAlerts: 3,
          alertsSent: 2,
        ),
        route(
          'b',
          'Accra',
          'GH',
          'Ghana',
          'Berlin',
          'DE',
          toCountry: 'Germany',
        ),
      ];
      await pump(tester);
      expect(find.text('2 of 3 travelers found'), findsOneWidget);
      expect(find.text('Every traveler'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-restart-a')), findsNothing);
    });

    testWidgets('a route at its limit can be restarted', (tester) async {
      service.routes = [
        route(
          'a',
          'Lagos',
          'NG',
          'Nigeria',
          'London',
          'GB',
          maxAlerts: 3,
          alertsSent: 3,
        ),
      ];
      await pump(tester);
      expect(find.text('Done · 3 of 3 travelers found'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('route-restart-a')));
      await tester.pumpAndSettle();
      expect(service.restarted, ['a']);
      expect(find.text('0 of 3 travelers found'), findsOneWidget);
      expect(find.textContaining('Restarted'), findsOneWidget);
    });

    testWidgets('a failed restart is explained', (tester) async {
      service.failRestart = true;
      service.routes = [
        route(
          'a',
          'Lagos',
          'NG',
          'Nigeria',
          'London',
          'GB',
          maxAlerts: 1,
          alertsSent: 1,
        ),
      ];
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('route-restart-a')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Couldn't restart this route"),
        findsOneWidget,
      );
    });
  });
}
