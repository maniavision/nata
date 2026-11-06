import 'package:carrywise_app/screens/cost_estimate_screen.dart';
import 'package:carrywise_app/services/delivery_pricing.dart';
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
    expect(find.textContaining("You don't have to use it"), findsOneWidget);
    expect(find.textContaining("Nata's fee isn't included"), findsOneWidget);
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

  testWidgets('in French', (tester) async {
    await open(tester, locale: const Locale('fr'));
    expect(find.text('Estimer une livraison'), findsOneWidget);
    expect(
      find.textContaining("Vous n'êtes pas obligé de l'utiliser"),
      findsOneWidget,
    );
  });
}

Text textOf(Finder f) => f.evaluate().single.widget as Text;
