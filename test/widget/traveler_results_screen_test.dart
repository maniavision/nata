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
  displayLabel: 'Lagos, Nigeria',
);
const london = LocationSelection(
  country: 'United Kingdom',
  countryCode: 'GB',
  city: 'London',
  displayLabel: 'London, United Kingdom',
);

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
    await tester.pumpWidget(
      appWrapper(
        TravelerResultsScreen(
          departure: departure,
          destination: destination,
          date: date,
          service: service,
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  group('sorting by date', () {
    /// The travelers' names, top to bottom.
    List<String> order(WidgetTester tester) {
      final names = ['Amara Kalu', 'Daniel Okafor', 'Maya Tariq', 'Zoe Kalu'];
      final shown = names.where((n) => find.text(n).evaluate().isNotEmpty);
      return shown.toList()..sort(
        (a, b) => tester
            .getTopLeft(find.text(a))
            .dy
            .compareTo(tester.getTopLeft(find.text(b)).dy),
      );
    }

    testWidgets('earliest departure first by default', (tester) async {
      // Returned out of order by the search.
      service.trips = sampleTravelers().reversed.toList();
      await pumpResults(tester);

      expect(find.text('Sort by date'), findsOneWidget);
      expect(order(tester), ['Amara Kalu', 'Daniel Okafor', 'Maya Tariq']);
    });

    testWidgets('Latest puts the last departure first, and back', (
      tester,
    ) async {
      await pumpResults(tester);

      await tester.tap(find.byKey(const ValueKey('sort-latest')));
      await tester.pumpAndSettle();
      expect(order(tester), ['Maya Tariq', 'Daniel Okafor', 'Amara Kalu']);

      await tester.tap(find.byKey(const ValueKey('sort-earliest')));
      await tester.pumpAndSettle();
      expect(order(tester), ['Amara Kalu', 'Daniel Okafor', 'Maya Tariq']);
    });

    testWidgets('trips on the same day keep the search order', (tester) async {
      service.trips = [
        sampleTrip(tripId: 'a', departureDate: DateTime(2030, 6, 22)),
        sampleTrip(
          tripId: 'z',
          travelerId: 'traveler-9',
          firstName: 'Zoe',
          departureDate: DateTime(2030, 6, 22),
        ),
      ];
      await pumpResults(tester);
      expect(order(tester), ['Amara Kalu', 'Zoe Kalu']);

      await tester.tap(find.byKey(const ValueKey('sort-latest')));
      await tester.pumpAndSettle();
      expect(order(tester), ['Amara Kalu', 'Zoe Kalu']);
    });

    testWidgets('no sort bar without results', (tester) async {
      service.trips = [];
      await pumpResults(tester);

      expect(find.text('Sort by date'), findsNothing);
    });

    testWidgets('is translated', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          TravelerResultsScreen(service: service),
          locale: const Locale('fr'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trier par date'), findsOneWidget);
      expect(find.text('Plus tôt'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
    });
  });

  // Amara carries 3 kg, Daniel 5 kg, Maya 2 kg.
  group('weight filter', () {
    bool shown(String name) => find.text(name).evaluate().isNotEmpty;
    bool selected(WidgetTester tester, String key) => tester
        .widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .selected!;

    testWidgets('everyone by default, with Any selected', (tester) async {
      await pumpResults(tester);

      expect(find.text('Weight to send'), findsOneWidget);
      expect(selected(tester, 'weight-any'), isTrue);
      expect(selected(tester, 'weight-5'), isFalse);
      expect(find.text('3 available'), findsOneWidget);
    });

    testWidgets('a chip keeps only travelers who can carry it', (tester) async {
      await pumpResults(tester);

      await tester.tap(find.byKey(const ValueKey('weight-5')));
      await tester.pumpAndSettle();

      expect(shown('Daniel Okafor'), isTrue);
      expect(shown('Amara Kalu'), isFalse);
      expect(shown('Maya Tariq'), isFalse);
      expect(find.text('1 available'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // in the field too
      expect(selected(tester, 'weight-5'), isTrue);

      await tester.tap(find.byKey(const ValueKey('weight-any')));
      await tester.pumpAndSettle();
      expect(find.text('3 available'), findsOneWidget);
    });

    testWidgets('a typed weight filters, at least that much', (tester) async {
      await pumpResults(tester);

      await tester.enterText(
        find.byKey(const ValueKey('results-weight')),
        '2,5',
      );
      await tester.pumpAndSettle();

      expect(shown('Amara Kalu'), isTrue);
      expect(shown('Daniel Okafor'), isTrue);
      expect(shown('Maya Tariq'), isFalse);
      expect(find.text('2 available'), findsOneWidget);
    });

    testWidgets('a trip without a capacity stays', (tester) async {
      service.trips = [
        ...sampleTravelers(),
        sampleTrip(
          tripId: 'z',
          travelerId: 'traveler-9',
          firstName: 'Zoe',
          maxWeightKg: null,
        ),
      ];
      await pumpResults(tester);

      await tester.tap(find.byKey(const ValueKey('weight-20')));
      await tester.pumpAndSettle();

      expect(shown('Zoe Kalu'), isTrue);
      expect(find.text('Capacity not specified'), findsOneWidget);
    });

    testWidgets('not a weight: says so and shows everyone', (tester) async {
      await pumpResults(tester);

      await tester.enterText(
        find.byKey(const ValueKey('results-weight')),
        'heavy',
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a weight in kg, e.g. 5'), findsOneWidget);
      expect(find.text('3 available'), findsOneWidget);
    });

    testWidgets('nobody can carry it: says so, and shows all again', (
      tester,
    ) async {
      await pumpResults(tester);

      await tester.tap(find.byKey(const ValueKey('weight-10')));
      await tester.pumpAndSettle();

      expect(find.text('No traveler here can carry 10 kg'), findsOneWidget);
      expect(find.text('Sort by date'), findsNothing);
      expect(find.text('0 available'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('weight-clear')));
      await tester.pumpAndSettle();
      expect(find.text('3 available'), findsOneWidget);
      expect(find.byKey(const ValueKey('results-weight')), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          TravelerResultsScreen(service: service),
          locale: const Locale('fr'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Poids à envoyer'), findsOneWidget);
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('5 kg+'), findsOneWidget);
    });
  });

  group('TravelerResultsScreen', () {
    testWidgets('sends the search criteria to the service', (tester) async {
      await pumpResults(
        tester,
        departure: lagos,
        destination: london,
        date: DateTime(2030, 6, 30),
      );

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
      await pumpResults(
        tester,
        departure: lagos,
        destination: london,
        date: DateTime(2030, 6, 30),
      );

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

    testWidgets('card shows route, delivered count, rating and capacity', (
      tester,
    ) async {
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

      expect(
        find.text('Could not load travelers. Please try again.'),
        findsOneWidget,
      );

      service.failSearch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Amara Kalu'), findsOneWidget);
      expect(service.searchCalls.length, 2);
    });

    testWidgets('tapping a traveler opens that traveler\'s profile', (
      tester,
    ) async {
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

    testWidgets('shows the same bottom navigation as the other screens', (
      tester,
    ) async {
      await pumpResults(tester);

      for (final label in [
        'Home',
        'Requests',
        'Trips',
        'Messages',
        'Profile',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
