import 'dart:async';
import 'dart:math';

import 'package:carrywise_app/services/home_search_memory.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import '../helpers/fakes.dart';

/// [n] travelers with 1..n deliveries (so the last ones are "the top").
List<TravelerTrip> manyTravelers(int n) => [
  for (var i = 1; i <= n; i++)
    sampleTrip(
      tripId: 'trip-$i',
      travelerId: 'traveler-$i',
      firstName: 'Name$i',
      lastName: 'Last',
      itemsDelivered: i,
    ),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeTravelerService service;

  setUp(() => service = FakeTravelerService());

  Future<void> pumpHome(
    WidgetTester tester, {
    bool settle = true,
    Random? random,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(),
          travelerService: service,
          random: random,
          capitalLookup: fakeCapitalLookup,
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  group('Home default departure', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      Map<String, dynamic>? profile,
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(profile: profile),
            travelerService: service,
            capitalLookup: fakeCapitalLookup,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is the capital of the country of residence', (tester) async {
      await pumpWith(tester, profile: {'country_of_residence': 'CM'});

      expect(find.text('Yaoundé, Cameroon'), findsOneWidget);
      expect(service.searchCalls.first['departureCity'], 'Yaoundé');
      expect(service.searchCalls.first['departureCountry'], 'CM');
    });

    testWidgets('a route the user picked is kept when Home opens again', (
      tester,
    ) async {
      // What Home remembered from an earlier visit.
      HomeSearchMemory.departure = const LocationSelection(
        country: 'Ghana',
        countryCode: 'GH',
        city: 'Accra',
        displayLabel: 'Accra, Ghana',
      );
      HomeSearchMemory.destination = const LocationSelection(
        country: 'France',
        countryCode: 'FR',
        city: 'Paris',
        displayLabel: 'Paris, France',
      );

      await pumpWith(tester, profile: {'country_of_residence': 'CM'});

      expect(find.text('Accra, Ghana'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      // The default departure (Yaoundé) does not replace it.
      expect(find.text('Yaoundé, Cameroon'), findsNothing);
      expect(service.searchCalls.first['departureCity'], 'Accra');
      expect(service.searchCalls.first['arrivalCity'], 'Paris');
    });

    testWidgets('the default departure is remembered too', (tester) async {
      await pumpWith(tester, profile: {'country_of_residence': 'CM'});

      expect(HomeSearchMemory.departure?.city, 'Yaoundé');
    });

    testWidgets('travelers are only searched once it is known', (tester) async {
      await pumpWith(tester, profile: {'country_of_residence': 'GB'});

      // No unfiltered search before the default departure was found.
      expect(service.searchCalls.first['departureCity'], 'London');
    });

    testWidgets('without a saved country, uses the device country', (
      tester,
    ) async {
      PreferencesService().setCountry('US');
      await pumpWith(
        tester,
        profile: {'first_name': 'Old', 'last_name': 'Account'},
      );

      expect(find.text('Washington, United States'), findsOneWidget);
    });

    testWidgets('no known capital: no departure, search from anywhere', (
      tester,
    ) async {
      await pumpWith(tester, profile: {'country_of_residence': 'ZZ'});

      expect(find.text('Where are you sending from?'), findsOneWidget);
      expect(service.searchCalls.first['departureCountry'], isNull);
    });
  });

  group('Home "Available Travelers"', () {
    testWidgets('loads travelers for the default route (the capital)', (
      tester,
    ) async {
      await pumpHome(tester);

      final call = service.searchCalls.first;
      expect(call['departureCity'], 'Abuja');
      expect(call['departureCountry'], 'NG');
      expect(call['arrivalCity'], isNull);
      expect(call['date'], isNull);
    });

    testWidgets('shows a loading indicator until travelers arrive', (
      tester,
    ) async {
      await pumpHome(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Amara K.'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Amara K.'), findsOneWidget);
    });

    testWidgets('lists at most five travelers', (tester) async {
      service.trips = manyTravelers(8);
      await pumpHome(tester);

      // "1 delivery" or "N deliveries".
      expect(find.textContaining('deliver'), findsNWidgets(5));
    });

    testWidgets('lists everyone when there are fewer than five', (
      tester,
    ) async {
      await pumpHome(tester); // the default fake has three travelers

      expect(find.text('Amara K.'), findsOneWidget);
      expect(find.text('Daniel O.'), findsOneWidget);
      expect(find.text('Maya T.'), findsOneWidget);
    });

    testWidgets('a traveler with several trips is listed once', (tester) async {
      service.trips = [
        sampleTrip(tripId: 't1', departureCity: 'Lagos'),
        sampleTrip(tripId: 't2', departureCity: 'Abuja'), // same traveler
      ];
      await pumpHome(tester);

      expect(find.text('Amara K.'), findsOneWidget);
    });

    testWidgets('each row shows its own route, date, rating and deliveries', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Lagos → London'), findsOneWidget);
      expect(find.text('Accra → Paris'), findsOneWidget);
      expect(find.text('Jun 22'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.textContaining('28 deliveries'), findsOneWidget);
      expect(find.textContaining('41 deliveries'), findsOneWidget);
    });

    testWidgets('a traveler without a rating shows "New"', (tester) async {
      service.trips = [sampleTrip(avgRating: null)];
      await pumpHome(tester);

      expect(find.text('New'), findsOneWidget);
    });

    testWidgets(
      'a traveler without a last name is not shown with a stray dot',
      (tester) async {
        service.trips = [sampleTrip(firstName: 'Cher', lastName: '')];
        await pumpHome(tester);

        expect(find.text('Cher'), findsOneWidget);
      },
    );

    testWidgets('empty state when no travelers match', (tester) async {
      service.trips = [];
      await pumpHome(tester);

      expect(
        find.byKey(const ValueKey('home-travelers-empty')),
        findsOneWidget,
      );
      expect(find.text('Amara K.'), findsNothing);
    });

    testWidgets('error state with a working Retry', (tester) async {
      service.failSearch = true;
      await pumpHome(tester);

      expect(
        find.byKey(const ValueKey('home-travelers-error')),
        findsOneWidget,
      );

      service.failSearch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-travelers-error')), findsNothing);
      expect(find.text('Amara K.'), findsOneWidget);
    });
  });

  group('Home traveler row -> traveler profile', () {
    testWidgets('tapping a traveler opens that traveler\'s profile', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Amara K.'));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerProfileScreen), findsOneWidget);
      expect(find.text('Traveler Profile'), findsOneWidget);
      expect(find.text('Amara Kalu'), findsOneWidget);
      expect(find.text('Lagos'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      // It no longer goes to the generic results list.
      expect(find.byType(TravelerResultsScreen), findsNothing);
    });

    testWidgets('each row opens its own traveler', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Daniel O.'));
      await tester.pumpAndSettle();

      expect(find.text('Daniel Okafor'), findsOneWidget);
      expect(find.text('Amara Kalu'), findsNothing);
      expect(find.text('Accra'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Up to 5.0 kg'), findsOneWidget);
    });

    testWidgets('the profile also loads the full traveler profile', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Maya T.'));
      await tester.pumpAndSettle();

      expect(service.profileCalls, ['traveler-3']);
    });

    testWidgets('back returns to Home', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Amara K.'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerProfileScreen), findsNothing);
      expect(find.text('Available Travelers'), findsOneWidget);
    });

    testWidgets('"View all" opens the results for the selected route', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerResultsScreen), findsOneWidget);
      expect(find.text('Abuja → Anywhere'), findsOneWidget);
      expect(service.searchCalls.last['departureCity'], 'Abuja');
    });

    testWidgets('"Search Travelers" opens the results', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Search Travelers'));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerResultsScreen), findsOneWidget);
      expect(find.text('Travelers Found'), findsOneWidget);
    });
  });

  group('Home "Available Travelers" refreshes every 15 seconds', () {
    /// The first names currently shown, e.g. {Name12, Name15, ...}.
    Set<String> shown(WidgetTester tester) => {
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.data != null && RegExp(r'^Name\d+ L\.$').hasMatch(t.data!))
          t.data!.split(' ').first,
    };

    Future<void> afterSeconds(WidgetTester tester, int seconds) async {
      await tester.pump(Duration(seconds: seconds));
      await tester.pump(); // let the search result arrive
    }

    testWidgets('does not refresh before 15 seconds', (tester) async {
      await pumpHome(tester);
      expect(service.searchCalls.length, 1);

      await afterSeconds(tester, 14);

      expect(service.searchCalls.length, 1);
    });

    testWidgets('refreshes after 15 seconds, then again every 15', (
      tester,
    ) async {
      await pumpHome(tester);

      await afterSeconds(tester, 15);
      expect(service.searchCalls.length, 2);

      await afterSeconds(tester, 15);
      expect(service.searchCalls.length, 3);

      await afterSeconds(tester, 15);
      expect(service.searchCalls.length, 4);
    });

    testWidgets('each refresh asks for the same route as before', (
      tester,
    ) async {
      await pumpHome(tester);

      await afterSeconds(tester, 15);

      expect(service.searchCalls.last['departureCity'], 'Abuja');
      expect(service.searchCalls.last['limit'], 100);
    });

    testWidgets('always shows five of the top-delivery travelers', (
      tester,
    ) async {
      service.trips = manyTravelers(25); // top 10 = Name16 .. Name25
      await pumpHome(tester, random: Random(1));
      final top10 = {for (var i = 16; i <= 25; i++) 'Name$i'};

      for (var tick = 0; tick < 10; tick++) {
        expect(shown(tester).length, 5, reason: 'tick $tick');
        expect(
          top10.containsAll(shown(tester)),
          isTrue,
          reason: 'tick $tick showed ${shown(tester)}',
        );
        await afterSeconds(tester, 15);
      }
    });

    testWidgets('the selection changes from one refresh to the next', (
      tester,
    ) async {
      service.trips = manyTravelers(25);
      await pumpHome(tester, random: Random(42));

      final seen = <String>{};
      for (var tick = 0; tick < 8; tick++) {
        seen.add((shown(tester).toList()..sort()).join(','));
        await afterSeconds(tester, 15);
      }

      expect(seen.length, greaterThan(2));
    });

    testWidgets('over time every top traveler gets a turn', (tester) async {
      service.trips = manyTravelers(25);
      await pumpHome(tester, random: Random(5));

      final seen = <String>{};
      for (var tick = 0; tick < 40; tick++) {
        seen.addAll(shown(tester));
        await afterSeconds(tester, 15);
      }

      expect(seen, {for (var i = 16; i <= 25; i++) 'Name$i'});
    });

    testWidgets('picks are shown with the most deliveries first', (
      tester,
    ) async {
      service.trips = manyTravelers(25);
      await pumpHome(tester, random: Random(3));

      for (var tick = 0; tick < 5; tick++) {
        final counts = [
          for (final t in tester.widgetList<Text>(
            find.textContaining(' deliveries'),
          ))
            int.parse(
              RegExp(r'(\d+) deliveries').firstMatch(t.data!)!.group(1)!,
            ),
        ];
        expect(counts, [...counts]..sort((a, b) => b.compareTo(a)));
        await afterSeconds(tester, 15);
      }
    });

    testWidgets('new travelers appear on the next refresh', (tester) async {
      service.trips = [];
      await pumpHome(tester);
      expect(
        find.byKey(const ValueKey('home-travelers-empty')),
        findsOneWidget,
      );

      service.trips = sampleTravelers();
      await afterSeconds(tester, 15);

      expect(find.byKey(const ValueKey('home-travelers-empty')), findsNothing);
      expect(find.text('Amara K.'), findsOneWidget);
    });

    testWidgets('travelers that disappear are dropped on the next refresh', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.text('Amara K.'), findsOneWidget);

      service.trips = [sampleTravelers()[1]]; // only Daniel is left
      await afterSeconds(tester, 15);

      expect(find.text('Amara K.'), findsNothing);
      expect(find.text('Daniel O.'), findsOneWidget);
    });

    testWidgets('the refresh is quiet: no spinner, the list stays', (
      tester,
    ) async {
      await pumpHome(tester);
      service.searchGate = Completer<void>(); // the next search is "slow"

      await tester.pump(const Duration(seconds: 15));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Amara K.'), findsOneWidget);

      service.searchGate!.complete();
      await tester.pump();
      expect(find.text('Amara K.'), findsOneWidget);
    });

    testWidgets('a slow refresh is not started twice', (tester) async {
      await pumpHome(tester);
      service.searchGate = Completer<void>();

      await tester.pump(const Duration(seconds: 15)); // starts a refresh
      await tester.pump(const Duration(seconds: 15)); // still waiting
      await tester.pump(const Duration(seconds: 15)); // still waiting

      expect(service.searchCalls.length, 2); // initial + the one in flight

      service.searchGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      expect(service.searchCalls.length, 3); // and it carries on afterwards
    });

    testWidgets('a failed refresh keeps showing travelers (no error)', (
      tester,
    ) async {
      await pumpHome(tester);
      service.failSearch = true;

      await afterSeconds(tester, 15);
      await afterSeconds(tester, 15);

      expect(find.byKey(const ValueKey('home-travelers-error')), findsNothing);
      expect(find.text('Amara K.'), findsOneWidget);
      expect(find.text('Daniel O.'), findsOneWidget);
    });

    testWidgets('after a failed refresh it recovers by itself', (tester) async {
      await pumpHome(tester);
      service.failSearch = true;
      await afterSeconds(tester, 15);

      service.failSearch = false;
      service.trips = [sampleTravelers()[2]]; // only Maya now
      await afterSeconds(tester, 15);

      expect(find.text('Maya T.'), findsOneWidget);
      expect(find.text('Amara K.'), findsNothing);
    });

    testWidgets('a failed refresh does not clear an error that is showing', (
      tester,
    ) async {
      service.failSearch = true;
      await pumpHome(tester);
      expect(
        find.byKey(const ValueKey('home-travelers-error')),
        findsOneWidget,
      );

      await afterSeconds(tester, 15);

      expect(
        find.byKey(const ValueKey('home-travelers-error')),
        findsOneWidget,
      );
    });

    testWidgets('an error clears when a refresh succeeds', (tester) async {
      service.failSearch = true;
      await pumpHome(tester);

      service.failSearch = false;
      await afterSeconds(tester, 15);

      expect(find.byKey(const ValueKey('home-travelers-error')), findsNothing);
      expect(find.text('Amara K.'), findsOneWidget);
    });

    testWidgets('the calendar counts follow the refreshed data', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      service.trips = [sampleTrip(arrivalDate: today, departureDate: today)];
      await pumpHome(tester);

      service.trips = [
        sampleTrip(tripId: 'a', arrivalDate: today, departureDate: today),
        sampleTrip(
          tripId: 'b',
          travelerId: 'traveler-2',
          arrivalDate: today,
          departureDate: today,
        ),
      ];
      await afterSeconds(tester, 15);
      await tester.tap(find.text('Anytime this month'));
      await tester.pumpAndSettle();

      expect(find.text('2 flts'), findsOneWidget);
    });

    testWidgets('stops refreshing once Home is gone', (tester) async {
      await pumpHome(tester);
      expect(service.searchCalls.length, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 90));

      expect(service.searchCalls.length, 1);
    });

    testWidgets('does not refresh while another screen covers Home', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text('Amara K.'));
      await tester.pumpAndSettle();
      expect(find.byType(TravelerProfileScreen), findsOneWidget);
      final before = service.searchCalls.length;

      await tester.pump(const Duration(seconds: 60));

      expect(service.searchCalls.length, before);
    });

    testWidgets('resumes refreshing once Home is visible again', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text('Amara K.'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 45));
      final before = service.searchCalls.length;

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await afterSeconds(tester, 15);

      expect(service.searchCalls.length, before + 1);
    });

    testWidgets('pauses in the background and catches up when reopened', (
      tester,
    ) async {
      await pumpHome(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 120));
      expect(service.searchCalls.length, 1); // nothing while in the background

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.searchCalls.length, 2); // immediate catch-up

      await afterSeconds(tester, 15);
      expect(service.searchCalls.length, 3); // and the rhythm continues
    });

    testWidgets('a brief interruption (inactive) does not stop it', (
      tester,
    ) async {
      await pumpHome(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await afterSeconds(tester, 15);

      expect(service.searchCalls.length, 2);
    });
  });
}
