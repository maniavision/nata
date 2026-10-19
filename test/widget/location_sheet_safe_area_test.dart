import 'package:carrywise_app/services/location_search_service.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

class FakeLocationSearchService extends Fake implements LocationSearchService {
  @override
  Future<List<CountryResult>> searchCountries(String query) async => const [
    CountryResult(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234'),
  ];

  @override
  Future<List<CityResult>> searchCities(
    String query, {
    String? countryCode,
  }) async => const [
    CityResult(
      id: 1,
      name: 'Albuquerque',
      countryCode: 'US',
      countryName: 'United States',
    ),
  ];
}

/// An iPhone 16-sized screen: a 59pt status bar and the keyboard up.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const statusBar = 59.0;

  Future<void> openCityStep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: statusBar, bottom: 34);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => LocationSearchSheet.show(
                context,
                title: 'Select City',
                service: FakeLocationSearchService(),
                initial: const LocationSelection(
                  country: 'United States',
                  countryCode: 'US',
                  city: '',
                  displayLabel: '',
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets('with the keyboard up, the back arrow stays below the '
      'status bar', (tester) async {
    await openCityStep(tester);

    final back = find.byIcon(Icons.arrow_back_rounded);
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dy, greaterThanOrEqualTo(statusBar));
    expect(
      tester.getTopLeft(find.byIcon(Icons.close_rounded)).dy,
      greaterThanOrEqualTo(statusBar),
    );
  });

  testWidgets('the back arrow goes back to the countries', (tester) async {
    await openCityStep(tester);
    expect(find.text('Albuquerque'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nigeria'), findsOneWidget);
  });

  testWidgets('tapping the country in the breadcrumb goes back too', (
    tester,
  ) async {
    await openCityStep(tester);
    await tester.tap(find.byKey(const ValueKey('location-breadcrumb-country')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nigeria'), findsOneWidget);
  });
}
