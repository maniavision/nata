import 'package:carrywise_app/screens/cost_estimate_screen.dart';
import 'package:carrywise_app/services/city_service.dart';
import 'package:carrywise_app/services/delivery_pricing.dart';
import 'package:carrywise_app/services/screen_cache.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

const lagos = LocationSelection(
  country: 'Nigeria',
  countryCode: 'NG',
  city: 'Lagos',
  displayLabel: 'Lagos, Nigeria',
  cityId: 1,
);
const london = LocationSelection(
  country: 'United Kingdom',
  countryCode: 'GB',
  city: 'London',
  displayLabel: 'London, United Kingdom',
  cityId: 2,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final km = DistanceCalculator.haversine(6.5244, 3.3792, 51.5074, -0.1278);

  Future<FakeCityService> open(
    WidgetTester tester, {
    String currency = 'USD',
    LocationSelection to = london,
    Locale locale = const Locale('en'),
  }) async {
    final cities = FakeCityService();
    await tester.pumpWidget(
      appWrapper(
        CostEstimateScreen(
          currency: currency,
          cityService: cities,
          exchangeRates: FakeExchangeRateService(),
          pickPlace: (context, title) async =>
              title == 'From' || title == 'Départ' ? lagos : to,
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return cities;
  }

  Future<void> fill(WidgetTester tester, String weight) async {
    await tester.tap(find.byKey(const ValueKey('estimate-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('estimate-to')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('estimate-weight')),
      weight,
    );
    await tester.pumpAndSettle();
  }

  String price() =>
      textOf(find.byKey(const ValueKey('estimate-price'))).data ?? '';

  testWidgets('says it is only a guide, before anything is entered', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.text('Choose both cities and enter a weight to see the estimate.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'help the sender and the traveler come up with a fair price',
      ),
      findsOneWidget,
    );
    expect(find.textContaining("Nata's fee"), findsNothing);
    expect(find.byKey(const ValueKey('estimate-price')), findsNothing);
  });

  testWidgets('prices the route and the weight in kg, with no Nata fee', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, '5');
    final usd = CostEstimateScreen.priceUsd(distanceKm: km, kg: 5);
    // 5 + km × 0.0123… + 5 × 3 + 750 ÷ 168, rounded up.
    expect(usd, ceilWhole(5 + km * 0.0123456789 + 15 + 4.4643).toDouble());
    expect(price(), '\$${usd.toInt()}');
    expect(find.textContaining('5 kg'), findsOneWidget);
  });

  testWidgets('within an African country it is 65% less, unmentioned', (
    tester,
  ) async {
    const abuja = LocationSelection(
      country: 'Nigeria',
      countryCode: 'NG',
      city: 'Abuja',
      displayLabel: 'Abuja, Nigeria',
      cityId: 3,
    );
    final cities = await open(tester, to: abuja);
    cities.cities['NG|Abuja'] = const CityCoordinates(9.0765, 7.3986);
    await fill(tester, '5');
    final local = DistanceCalculator.haversine(6.5244, 3.3792, 9.0765, 7.3986);
    final full = CostCalculator.calculateCost(
      distanceKm: local,
      deliveryTimeInHours: CostEstimateScreen.assumedHours,
      weightKg: 5,
    );
    final usd = CostEstimateScreen.priceUsd(
      distanceKm: local,
      kg: 5,
      discountPercent: 65,
    );
    expect(usd, ceilWhole(full * 0.35).toDouble());
    expect(price(), '\$${usd.toInt()}');
    expect(find.textContaining('Within one country'), findsNothing);
  });

  test('65% less in Africa, 45% anywhere else', () {
    expect(CostEstimateScreen.localDiscountPercent('NG'), 65);
    expect(CostEstimateScreen.localDiscountPercent('CG'), 65);
    expect(CostEstimateScreen.localDiscountPercent('US'), 45);
    expect(CostEstimateScreen.localDiscountPercent('GB'), 45);
    expect(CostEstimateScreen.localDiscountPercent('FR'), 45);
    expect(CostEstimateScreen.localDiscountPercent('CH'), 45);
    expect(CostEstimateScreen.localDiscountPercent('CA'), 45);
    expect(CostEstimateScreen.localDiscountPercent('BR'), 45);
    expect(CostEstimateScreen.localDiscountPercent('IN'), 45);
    expect(CostEstimateScreen.localDiscountPercent('AE'), 45);
    expect(CostEstimateScreen.localDiscountPercent('AU'), 45);
    expect(
      CostEstimateScreen.priceUsd(distanceKm: 400, kg: 5, discountPercent: 45),
      ceilWhole(
        CostCalculator.calculateCost(
              distanceKm: 400,
              deliveryTimeInHours: CostEstimateScreen.assumedHours,
              weightKg: 5,
            ) *
            0.55,
      ).toDouble(),
    );
  });

  testWidgets('within France nothing is said about a discount', (tester) async {
    const paris = LocationSelection(
      country: 'France',
      countryCode: 'FR',
      city: 'Paris',
      displayLabel: 'Paris, France',
      cityId: 4,
    );
    const lyon = LocationSelection(
      country: 'France',
      countryCode: 'FR',
      city: 'Lyon',
      displayLabel: 'Lyon, France',
      cityId: 5,
    );
    final cities = FakeCityService()
      ..cities['FR|Lyon'] = const CityCoordinates(45.764, 4.8357);
    await tester.pumpWidget(
      appWrapper(
        CostEstimateScreen(
          currency: 'USD',
          cityService: cities,
          exchangeRates: FakeExchangeRateService(),
          pickPlace: (context, title) async => title == 'From' ? paris : lyon,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fill(tester, '5');
    expect(find.textContaining('Within one country'), findsNothing);
  });

  testWidgets('pounds are turned into kg', (tester) async {
    await open(tester);
    await fill(tester, '11');
    await tester.tap(find.byKey(const ValueKey('estimate-unit-lb')));
    await tester.pumpAndSettle();
    final usd = CostEstimateScreen.priceUsd(
      distanceKm: km,
      kg: 11 * CostEstimateScreen.kgPerLb,
    );
    expect(price(), '\$${usd.toInt()}');
    expect(find.textContaining('11 lb'), findsOneWidget);
    expect(
      CostEstimateScreen.parseKg('11', WeightUnit.lb),
      closeTo(4.99, 0.01),
    );
  });

  testWidgets('shown in the member\'s currency, marked ≈', (tester) async {
    await open(tester, currency: 'EUR');
    await fill(tester, '5');
    expect(price(), startsWith('≈ '));
    expect(price(), contains('€'));
  });

  testWidgets('a weight that is not a number asks for one', (tester) async {
    await open(tester);
    await fill(tester, 'abc');
    expect(find.byKey(const ValueKey('estimate-weight-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('estimate-price')), findsNothing);
  });

  testWidgets('the same city twice is refused', (tester) async {
    await open(tester, to: lagos);
    await fill(tester, '5');
    expect(find.text('Choose two different cities.'), findsOneWidget);
    expect(find.byKey(const ValueKey('estimate-price')), findsNothing);
  });

  testWidgets('a city with no coordinates says so', (tester) async {
    final cities = await open(tester);
    cities.cities.remove('GB|London');
    await fill(tester, '5');
    expect(
      find.textContaining("We couldn't work out the distance"),
      findsOneWidget,
    );
  });

  group('coming back to the page', () {
    Future<void> openFrom(WidgetTester tester, FakeCityService cities) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        appWrapper(const Scaffold(body: Text('profile')), navigatorKey: nav),
      );
      nav.currentState!.push(
        MaterialPageRoute(
          builder: (_) => CostEstimateScreen(
            currency: 'USD',
            cityService: cities,
            exchangeRates: FakeExchangeRateService(),
            pickPlace: (context, title) async =>
                title == 'From' ? lagos : london,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('estimate-back')));
      await tester.pumpAndSettle();
      expect(find.text('profile'), findsOneWidget);
    }

    testWidgets('keeps the cities, the weight and the unit', (tester) async {
      final cities = FakeCityService();
      await openFrom(tester, cities);
      await fill(tester, '11');
      await tester.tap(find.byKey(const ValueKey('estimate-unit-lb')));
      await tester.pumpAndSettle();
      final shown = price();
      await back(tester);

      await openFrom(tester, cities);
      expect(find.text('Lagos, Nigeria'), findsOneWidget);
      expect(find.text('London, United Kingdom'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(price(), shown);
      expect(find.textContaining('11 lb'), findsOneWidget);
    });

    testWidgets('an untouched page keeps nothing', (tester) async {
      final cities = FakeCityService();
      await openFrom(tester, cities);
      await back(tester);
      await openFrom(tester, cities);
      expect(
        find.text('Choose both cities and enter a weight to see the estimate.'),
        findsOneWidget,
      );
    });

    testWidgets('signing out forgets them', (tester) async {
      final cities = FakeCityService();
      await openFrom(tester, cities);
      await fill(tester, '5');
      await back(tester);
      ScreenCache.clear();
      await openFrom(tester, cities);
      expect(find.text('Lagos, Nigeria'), findsNothing);
      expect(find.byKey(const ValueKey('estimate-price')), findsNothing);
    });
  });

  testWidgets('in French', (tester) async {
    await open(tester, locale: const Locale('fr'));
    expect(find.text('Estimer une livraison'), findsOneWidget);
    expect(
      find.textContaining("Aucun de vous n'est obligé de l'utiliser"),
      findsOneWidget,
    );
  });
}

Text textOf(Finder f) => f.evaluate().single.widget as Text;
