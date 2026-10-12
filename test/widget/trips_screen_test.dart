import 'package:carrywise_app/screens/add_trip_screen.dart';
import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/screens/trips_screen.dart';
import 'package:carrywise_app/services/trip_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

final _now = DateTime.now();
final today = DateTime(_now.year, _now.month, _now.day);
DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeTripService service;

  setUp(() => service = FakeTripService());

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWrapper(TripsScreen(service: service)));
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  /// A realistic mix: two upcoming, three past.
  List<Trip> mixedTrips() => [
    sampleMyTrip(
      id: 'live',
      status: TripStatus.live,
      requests: 3,
      departureDate: inDays(5),
    ),
    sampleMyTrip(
      id: 'review',
      status: TripStatus.pendingReview,
      departureCity: 'Accra',
      departureCountry: 'Ghana',
      arrivalCity: 'Paris',
      arrivalCountry: 'France',
      maxWeightKg: 1,
      maxSize: 'Envelope / Document',
      departureDate: inDays(12),
    ),
    sampleMyTrip(
      id: 'done',
      status: TripStatus.completed,
      departureCity: 'Lagos',
      arrivalCity: 'Nairobi',
      arrivalCountry: 'Kenya',
      departureDate: inDays(-40),
      delivered: 2,
    ),
    sampleMyTrip(
      id: 'cancelled',
      status: TripStatus.cancelled,
      departureCity: 'Abuja',
      arrivalCity: 'Dubai',
      departureDate: inDays(20),
    ),
    sampleMyTrip(
      id: 'expired',
      status: TripStatus.live,
      departureCity: 'Kano',
      arrivalCity: 'Cairo',
      departureDate: inDays(-3),
      arrivalDate: inDays(-2),
    ),
  ];

  group('My Trips header and tabs', () {
    testWidgets('shows the title and the add button', (tester) async {
      await pump(tester);

      expect(find.text('My Trips'), findsOneWidget);
      expect(find.text('Traveler mode'), findsOneWidget);
      expect(find.byKey(const ValueKey('trips-add')), findsOneWidget);
    });

    testWidgets('shows a loading indicator first', (tester) async {
      await pump(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Upcoming and Past tabs show their counts', (tester) async {
      service.trips = mixedTrips();
      await pump(tester);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      // 2 upcoming (live + in review), 3 past (completed, cancelled, expired)
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trips-tab-0')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trips-tab-1')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Upcoming is selected first and lists only upcoming trips', (
      tester,
    ) async {
      service.trips = mixedTrips();
      await pump(tester);

      expect(find.byKey(const ValueKey('trip-card-live')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-done')), findsNothing);
      expect(find.byKey(const ValueKey('trip-card-cancelled')), findsNothing);
      expect(find.byKey(const ValueKey('trip-card-expired')), findsNothing);
    });

    testWidgets('the Past tab lists finished, cancelled and expired trips', (
      tester,
    ) async {
      service.trips = mixedTrips();
      await pump(tester);

      await tapKey(tester, 'trips-tab-1');

      expect(find.byKey(const ValueKey('trip-card-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-cancelled')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-expired')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-live')), findsNothing);
    });

    testWidgets('past trips are listed most recent first', (tester) async {
      service.trips = mixedTrips();
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      double top(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('trip-card-$id'))).dy;
      // cancelled (+20 days) > expired (-3 days) > done (-40 days)
      expect(top('cancelled'), lessThan(top('expired')));
      expect(top('expired'), lessThan(top('done')));
    });

    testWidgets('can switch back to Upcoming', (tester) async {
      service.trips = mixedTrips();
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      await tapKey(tester, 'trips-tab-0');

      expect(find.byKey(const ValueKey('trip-card-live')), findsOneWidget);
    });
  });

  group('trip cards', () {
    testWidgets('show the route, countries and departure date', (tester) async {
      service.trips = [sampleMyTrip(departureDate: DateTime(2030, 6, 5))];
      await pump(tester);

      expect(find.text('Lagos → London'), findsOneWidget);
      expect(find.text('Nigeria · United Kingdom'), findsOneWidget);
      expect(find.text('Jun 05, 2030'), findsOneWidget);
      expect(find.text('Departure'), findsOneWidget);
    });

    testWidgets('show max weight, max size and the request count', (
      tester,
    ) async {
      service.trips = [sampleMyTrip(requests: 3)];
      await pump(tester);

      expect(find.text('3.0 kg'), findsOneWidget);
      expect(find.text('Max weight'), findsOneWidget);
      expect(find.text('Shoebox'), findsOneWidget);
      expect(find.text('Max size'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Requests'), findsWidgets);
    });

    testWidgets('a trip without a weight shows a dash', (tester) async {
      service.trips = [sampleMyTrip(maxWeightKg: null, maxSize: null)];
      await pump(tester);

      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('status chips: Published', (tester) async {
      service.trips = [sampleMyTrip(status: TripStatus.live)];
      await pump(tester);

      expect(find.text('Published'), findsOneWidget);
    });

    testWidgets('status chips: In review', (tester) async {
      service.trips = [sampleMyTrip(status: TripStatus.pendingReview)];
      await pump(tester);

      expect(find.text('In review'), findsOneWidget);
    });

    testWidgets('status chips: Completed and Cancelled', (tester) async {
      service.trips = [
        sampleMyTrip(
          id: 'a',
          status: TripStatus.completed,
          departureDate: inDays(-9),
        ),
        sampleMyTrip(
          id: 'b',
          status: TripStatus.cancelled,
          departureDate: inDays(-8),
        ),
      ];
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('a published trip offers Edit and View Requests', (
      tester,
    ) async {
      service.trips = [sampleMyTrip(id: 'live')];
      await pump(tester);

      expect(find.byKey(const ValueKey('trip-edit-live')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-requests-live')), findsOneWidget);
      expect(find.text('Edit Trip'), findsOneWidget);
      expect(find.text('View Requests'), findsOneWidget);
    });

    testWidgets('a trip in review can be edited and explains the wait', (
      tester,
    ) async {
      service.trips = [sampleMyTrip(id: 'r', status: TripStatus.pendingReview)];
      await pump(tester);

      expect(find.byKey(const ValueKey('trip-edit-r')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-requests-r')), findsNothing);
      expect(find.textContaining('reviewing your trip'), findsOneWidget);
    });

    testWidgets('a completed trip summarises deliveries (plural)', (
      tester,
    ) async {
      service.trips = [
        sampleMyTrip(
          status: TripStatus.completed,
          departureDate: inDays(-30),
          delivered: 2,
        ),
      ];
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      expect(find.text('2 items delivered'), findsOneWidget);
      expect(find.text('Edit Trip'), findsNothing);
      expect(find.text('View Requests'), findsNothing);
    });

    testWidgets('a completed trip summarises deliveries (singular)', (
      tester,
    ) async {
      service.trips = [
        sampleMyTrip(
          status: TripStatus.completed,
          departureDate: inDays(-30),
          delivered: 1,
        ),
      ];
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      expect(find.text('1 item delivered'), findsOneWidget);
    });

    testWidgets('past cards offer no edit actions', (tester) async {
      service.trips = [
        sampleMyTrip(
          id: 'old',
          departureDate: inDays(-9),
          arrivalDate: inDays(-8),
        ),
      ];
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      expect(find.byKey(const ValueKey('trip-edit-old')), findsNothing);
      expect(find.text('3.0 kg'), findsNothing); // no stats row on past cards
    });

    testWidgets('does not show invented flight numbers or earnings', (
      tester,
    ) async {
      service.trips = mixedTrips();
      await pump(tester);

      expect(find.textContaining('Flight BA'), findsNothing);
      expect(find.textContaining('earned'), findsNothing);
      expect(find.textContaining('LOS'), findsNothing);
    });
  });

  group('booking reference on cards', () {
    testWidgets('is shown next to the status', (tester) async {
      service.trips = [sampleMyTrip(bookingReference: 'X7KQ9R')];
      await pump(tester);

      expect(find.text('Ref X7KQ9R'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
    });

    testWidgets('is not shown when the trip has none', (tester) async {
      service.trips = [sampleMyTrip()];
      await pump(tester);

      expect(find.textContaining('Ref '), findsNothing);
    });

    testWidgets('is shown on past trips too', (tester) async {
      service.trips = [
        sampleMyTrip(
          status: TripStatus.completed,
          departureDate: inDays(-30),
          bookingReference: 'ABC123',
        ),
      ];
      await pump(tester);
      await tapKey(tester, 'trips-tab-1');

      expect(find.text('Ref ABC123'), findsOneWidget);
    });
  });

  group('empty and error states', () {
    testWidgets('no trips at all: upcoming empty state with an add button', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('trips-empty-upcoming')),
        findsOneWidget,
      );
      expect(find.text('No upcoming trips'), findsOneWidget);
      expect(find.byKey(const ValueKey('trips-empty-add')), findsOneWidget);
    });

    testWidgets('past tab empty state has no add button', (tester) async {
      await pump(tester);

      await tapKey(tester, 'trips-tab-1');

      expect(find.byKey(const ValueKey('trips-empty-past')), findsOneWidget);
      expect(find.text('No past trips yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('trips-empty-add')), findsNothing);
    });

    testWidgets('both tabs show 0 when there are no trips', (tester) async {
      await pump(tester);

      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('error state with a working Retry', (tester) async {
      service.failLoad = true;
      await pump(tester);

      expect(find.byKey(const ValueKey('trips-error')), findsOneWidget);
      expect(find.text('Could not load your trips.'), findsOneWidget);

      service.failLoad = false;
      service.trips = [sampleMyTrip(id: 'live')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('trips-error')), findsNothing);
      expect(find.byKey(const ValueKey('trip-card-live')), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('the + button opens Add a Trip', (tester) async {
      await pump(tester);

      await tapKey(tester, 'trips-add');

      expect(find.byType(AddTripScreen), findsOneWidget);
      expect(find.text('Add a Trip'), findsOneWidget);
    });

    testWidgets('the empty-state button opens Add a Trip too', (tester) async {
      await pump(tester);

      await tapKey(tester, 'trips-empty-add');

      expect(find.byType(AddTripScreen), findsOneWidget);
    });

    testWidgets('the list refreshes after a trip is saved', (tester) async {
      await pump(tester);
      expect(service.loadCount, 1);
      await tapKey(tester, 'trips-add');

      service.trips = [sampleMyTrip(id: 'new')];
      Navigator.of(tester.element(find.byType(AddTripScreen))).pop(true);
      await tester.pumpAndSettle();

      expect(service.loadCount, 2);
      expect(find.byKey(const ValueKey('trip-card-new')), findsOneWidget);
    });

    testWidgets('it does not reload when Add a Trip is cancelled', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'trips-add');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(service.loadCount, 1);
    });

    testWidgets('Edit Trip opens the form pre-filled with that trip', (
      tester,
    ) async {
      service.trips = [
        sampleMyTrip(
          id: 'live',
          departureCity: 'Lagos',
          price: 42,
          departureDate: inDays(7),
        ),
      ];
      await pump(tester);

      await tapKey(tester, 'trip-edit-live');

      expect(find.byType(AddTripScreen), findsOneWidget);
      expect(find.text('Edit Trip'), findsWidgets);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Lagos'), findsOneWidget);
      final price = tester.widget<TextField>(
        find.byKey(const ValueKey('add-trip-price')),
      );
      expect(price.controller!.text, '42');
    });

    testWidgets('the list refreshes after a trip is edited', (tester) async {
      service.trips = [sampleMyTrip(id: 'live', price: 42)];
      await pump(tester);
      await tapKey(tester, 'trip-edit-live');

      service.trips = [sampleMyTrip(id: 'live', price: 50, requests: 1)];
      Navigator.of(tester.element(find.byType(AddTripScreen))).pop(true);
      await tester.pumpAndSettle();

      expect(service.loadCount, 2);
    });

    testWidgets('View Requests opens the requests screen', (tester) async {
      service.trips = [sampleMyTrip(id: 'live')];
      await pump(tester);

      await tapKey(tester, 'trip-requests-live');

      expect(find.byType(RequestsScreen), findsOneWidget);
    });
  });

  group('bottom navigation', () {
    testWidgets('shows the same five tabs as every other screen', (
      tester,
    ) async {
      await pump(tester);

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

    testWidgets('Trips is the highlighted tab', (tester) async {
      await pump(tester);

      final trips = tester.widget<Text>(find.text('Trips'));
      final home = tester.widget<Text>(find.text('Home'));
      expect(trips.style?.fontWeight, FontWeight.w700);
      expect(home.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('tapping Trips on Home opens My Trips', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();

      expect(find.byType(TripsScreen), findsOneWidget);
      expect(find.text('My Trips'), findsOneWidget);
    });

    testWidgets('Home\'s "Add a Trip" button still opens the form directly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a Trip'));
      await tester.pumpAndSettle();

      expect(find.byType(AddTripScreen), findsOneWidget);
    });
  });

  group('date formatting', () {
    testWidgets('dates are zero padded like the design (Jul 04, 2030)', (
      tester,
    ) async {
      service.trips = [sampleMyTrip(departureDate: DateTime(2030, 7, 4))];
      await pump(tester);

      expect(
        find.text(DateFormat('MMM dd, yyyy').format(DateTime(2030, 7, 4))),
        findsOneWidget,
      );
      expect(find.text('Jul 04, 2030'), findsOneWidget);
    });
  });
}
