import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
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
    displayLabel: 'Lagos, Nigeria');
const london = LocationSelection(
    country: 'United Kingdom',
    countryCode: 'GB',
    city: 'London',
    displayLabel: 'London, United Kingdom');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeTravelerService service;
  setUp(() => service = FakeTravelerService());

  Future<void> pumpResults(
    WidgetTester tester, {
    LocationSelection? departure,
    LocationSelection? destination,
    DateTime? date,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWrapper(TravelerResultsScreen(
      departure: departure,
      destination: destination,
      date: date,
      service: service,
    )));
    if (settle) await tester.pumpAndSettle();
  }

  group('TravelerResultsScreen', () {
    testWidgets('sends the search criteria to the service', (tester) async {
      await pumpResults(tester,
          departure: lagos, destination: london, date: DateTime(2030, 6, 30));

      final call = service.searchCalls.single;
      expect(call['departureCountry'], 'NG');
      expect(call['departureCity'], 'Lagos');
      expect(call['arrivalCountry'], 'GB');
      expect(call['arrivalCity'], 'London');
      expect(call['date'], DateTime(2030, 6, 30));
    });

    testWidgets('with no criteria it searches everything', (tester) async {
      await pumpResults(tester);

      final call = service.searchCalls.single;
      expect(call['departureCity'], isNull);
      expect(call['arrivalCity'], isNull);
      expect(call['date'], isNull);
    });

    testWidgets('summarises the search in the header', (tester) async {
      await pumpResults(tester,
          departure: lagos, destination: london, date: DateTime(2030, 6, 30));

      expect(find.text('Lagos → London · by Jun 30'), findsOneWidget);
    });

    testWidgets('header says "Anywhere" for missing criteria', (tester) async {
      await pumpResults(tester);

      expect(find.text('Anywhere → Anywhere'), findsOneWidget);
    });

    testWidgets('shows a card per traveler and the count', (tester) async {
      await pumpResults(tester);

      expect(find.text('Amara Kalu'), findsOneWidget);
      expect(find.text('Daniel Okafor'), findsOneWidget);
      expect(find.text('Maya Tariq'), findsOneWidget);
      expect(find.text('3 available'), findsOneWidget);
    });

    testWidgets('card shows route, delivered count, rating and capacity',
        (tester) async {
      await pumpResults(tester);

      expect(find.text('Lagos → London'), findsOneWidget);
      expect(find.text('28 delivered'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('Accepts up to 3.0 kg'), findsOneWidget);
    });

    testWidgets('shows a loading indicator first', (tester) async {
      await pumpResults(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty state when nobody matches', (tester) async {
      service.trips = [];
      await pumpResults(tester);

      expect(find.text('No travelers on this route yet'), findsOneWidget);
      expect(find.text('0 available'), findsOneWidget);
      // The "Need a different date?" banner is still offered.
      expect(find.text('Need a different date?'), findsOneWidget);
    });

    testWidgets('error state with a working Retry', (tester) async {
      service.failSearch = true;
      await pumpResults(tester);

      expect(find.text('Could not load travelers. Please try again.'),
          findsOneWidget);

      service.failSearch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Amara Kalu'), findsOneWidget);
      expect(service.searchCalls.length, 2);
    });

    testWidgets('tapping a traveler opens that traveler\'s profile',
        (tester) async {
      await pumpResults(tester);

      await tester.tap(find.text('Daniel Okafor'));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerProfileScreen), findsOneWidget);
      expect(find.text('Traveler Profile'), findsOneWidget);
      expect(find.text('Daniel Okafor'), findsOneWidget);
      expect(find.text('Accra'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(service.profileCalls, ['traveler-2']);
    });

    testWidgets('shows the same bottom navigation as the other screens',
        (tester) async {
      await pumpResults(tester);

      for (final label in ['Home', 'Requests', 'Trips', 'Messages', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
