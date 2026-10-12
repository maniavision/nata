import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/delivery_request_screen.dart';
import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  group('TravelerProfileScreen Widget Tests', () {
    // The screen shows whatever traveler/trip it is given.
    final trip = TravelerTrip(
      tripId: 'trip-1',
      // Not a real user: the background profile fetch fails in tests and the
      // screen must keep showing the data it was given.
      travelerId: 'traveler-1',
      firstName: 'Amara',
      lastName: 'Kalu',
      avatarPath: null,
      avgRating: 4.9,
      itemsDelivered: 28,
      departureCity: 'Lagos',
      departureCountry: 'NG',
      arrivalCity: 'London',
      arrivalCountry: 'GB',
      departureDate: DateTime(2030, 6, 22),
      arrivalDate: DateTime(2030, 6, 23),
      price: 35,
      currency: 'USD',
      maxWeightKg: 3,
      maxSize: 'Shoebox (30×20×15 cm)',
    );

    Widget buildTravelerProfile([TravelerTrip? t]) =>
        appWrapper(TravelerProfileScreen(trip: t ?? trip));

    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('renders traveler profile header', (tester) async {
      await tester.pumpWidget(buildTravelerProfile());
      await tester.pump();

      expect(find.text('Traveler Profile'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders the name of the traveler it was opened for', (
      tester,
    ) async {
      await tester.pumpWidget(buildTravelerProfile());
      await tester.pump();
      expect(find.text('Amara Kalu'), findsOneWidget);

      await tester.pumpWidget(
        buildTravelerProfile(
          TravelerTrip(
            tripId: 'trip-2',
            travelerId: 'traveler-2',
            firstName: 'Daniel',
            lastName: 'Okafor',
            avatarPath: null,
            avgRating: null,
            itemsDelivered: 41,
            departureCity: 'Accra',
            departureCountry: 'GH',
            arrivalCity: 'Paris',
            arrivalCountry: 'FR',
            departureDate: DateTime(2030, 7, 1),
            arrivalDate: DateTime(2030, 7, 1),
            price: 20,
            currency: 'USD',
            maxWeightKg: null,
            maxSize: null,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Daniel Okafor'), findsOneWidget);
      expect(find.text('Amara Kalu'), findsNothing);
      expect(find.text('Accra'), findsWidgets);
    });

    testWidgets('renders stats from the traveler data', (tester) async {
      await tester.pumpWidget(buildTravelerProfile());
      await tester.pump();

      expect(find.text('28'), findsOneWidget); // items delivered
      expect(find.text('4.9'), findsOneWidget); // rating
    });

    testWidgets('shows "New" when the traveler has no rating yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTravelerProfile(
          TravelerTrip(
            tripId: 'trip-3',
            travelerId: 'traveler-3',
            firstName: 'New',
            lastName: 'Person',
            avatarPath: null,
            avgRating: null,
            itemsDelivered: 0,
            departureCity: 'Lagos',
            departureCountry: 'NG',
            arrivalCity: 'London',
            arrivalCountry: 'GB',
            departureDate: DateTime(2030, 6, 22),
            arrivalDate: DateTime(2030, 6, 22),
            price: 10,
            currency: 'USD',
            maxWeightKg: 1,
            maxSize: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('renders route, price and capacity for the trip', (
      tester,
    ) async {
      await tester.pumpWidget(buildTravelerProfile());
      await tester.pump();

      expect(find.text('Lagos'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      expect(find.text('NG · Jun 22'), findsOneWidget);
      expect(find.text('GB · Jun 23'), findsOneWidget);
      expect(find.text('USD 35.00'), findsOneWidget);
      expect(find.text('Up to 3.0 kg'), findsOneWidget);
      expect(find.text('Shoebox (30×20×15 cm)'), findsOneWidget);
    });

    testWidgets('renders send request button', (tester) async {
      await tester.pumpWidget(buildTravelerProfile());
      await tester.pump();

      expect(find.text('Send Request'), findsOneWidget);
    });
  });

  group('TravelerProfileScreen design and data', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<FakeTravelerService> pump(
      WidgetTester tester, {
      TravelerTrip? trip,
      TravelerProfile? profile,
    }) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final t = trip ?? sampleTrip();
      final service = FakeTravelerService(profile: profile);
      await tester.pumpWidget(
        appWrapper(TravelerProfileScreen(trip: t, service: service)),
      );
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('frequent travelers get the "Frequent traveler" subtitle', (
      tester,
    ) async {
      await pump(tester, trip: sampleTrip(itemsDelivered: 28));

      expect(
        find.text('Frequent traveler on Lagos ⇄ London route'),
        findsOneWidget,
      );
    });

    testWidgets('new travelers get the plain "Traveler" subtitle', (
      tester,
    ) async {
      await pump(tester, trip: sampleTrip(itemsDelivered: 3));

      expect(find.text('Traveler on Lagos ⇄ London route'), findsOneWidget);
    });

    testWidgets('shows the section titles from the design', (tester) async {
      await pump(tester);

      expect(find.text('TRAVEL DATE AND ROUTE'), findsOneWidget);
      expect(find.text('ITEM SIZE & WEIGHT LIMITS ACCEPTED'), findsOneWidget);
      expect(find.text('DELIVERY HISTORY & REVIEWS'), findsOneWidget);
      expect(find.text('Item Requirement'), findsOneWidget);
    });

    testWidgets('shows the stat labels', (tester) async {
      await pump(tester);

      expect(find.text('Items delivered'), findsOneWidget);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('Upcoming trips'), findsOneWidget);
    });

    testWidgets('shows pricing text and the trip price', (tester) async {
      await pump(tester);

      expect(
        find.textContaining('Pricing:', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('USD 35.00'), findsOneWidget);
    });

    testWidgets('does not show invented reviews', (tester) async {
      await pump(tester);

      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('Kofi Mensah'), findsNothing);
      expect(find.text('Sarah Jenkins'), findsNothing);
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('missing weight and size show a dash', (tester) async {
      await pump(tester, trip: sampleTrip(maxWeightKg: null, maxSize: null));

      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('Send Request opens the delivery request screen', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Send Request'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryRequestScreen), findsOneWidget);
    });

    testWidgets('back button leaves the screen', (tester) async {
      await tester.pumpWidget(
        appWrapper(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TravelerProfileScreen(
                      trip: sampleTrip(),
                      service: FakeTravelerService(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(TravelerProfileScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(TravelerProfileScreen), findsNothing);
    });

    group('with the full profile loaded', () {
      final lagosLondon = sampleTrip(tripId: 'trip-a');
      final abujaDubai = sampleTrip(
        tripId: 'trip-b',
        departureCity: 'Abuja',
        departureCountry: 'NG',
        arrivalCity: 'Dubai',
        arrivalCountry: 'AE',
        departureDate: DateTime(2030, 7, 4),
        arrivalDate: DateTime(2030, 7, 5),
        price: 50,
        maxWeightKg: 10,
        maxSize: 'Backpack size',
      );

      testWidgets('asks for the profile of the traveler on screen', (
        tester,
      ) async {
        final service = await pump(
          tester,
          trip: lagosLondon,
          profile: sampleProfile([lagosLondon, abujaDubai]),
        );

        expect(service.profileCalls, ['traveler-1']);
      });

      testWidgets('shows the upcoming-trips card when there are several', (
        tester,
      ) async {
        await pump(
          tester,
          trip: lagosLondon,
          profile: sampleProfile([lagosLondon, abujaDubai]),
        );

        expect(find.text('UPCOMING TRIPS'), findsOneWidget);
        expect(find.text('Lagos → London'), findsOneWidget);
        expect(find.text('Abuja → Dubai'), findsOneWidget);
        // "2" upcoming trips in the stats row.
        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('hides the upcoming-trips card for a single trip', (
        tester,
      ) async {
        await pump(
          tester,
          trip: lagosLondon,
          profile: sampleProfile([lagosLondon]),
        );

        expect(find.text('UPCOMING TRIPS'), findsNothing);
      });

      testWidgets('picking another trip switches the route, price and limits', (
        tester,
      ) async {
        await pump(
          tester,
          trip: lagosLondon,
          profile: sampleProfile([lagosLondon, abujaDubai]),
        );
        expect(find.text('USD 35.00'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('upcoming-trip-trip-b')));
        await tester.pumpAndSettle();

        expect(find.text('USD 50.00'), findsOneWidget);
        expect(find.text('Up to 10.0 kg'), findsOneWidget);
        expect(find.text('Backpack size'), findsOneWidget);
        expect(find.text('AE · Jul 5'), findsOneWidget);
        // Subtitle follows the selected trip too.
        expect(
          find.text('Frequent traveler on Abuja ⇄ Dubai route'),
          findsOneWidget,
        );
      });

      testWidgets('the loaded profile name replaces the search-result name', (
        tester,
      ) async {
        await pump(
          tester,
          trip: lagosLondon,
          profile: sampleProfile(
            [lagosLondon],
            firstName: 'Amara',
            lastName: 'Kalu-Obi',
          ),
        );

        expect(find.text('Amara Kalu-Obi'), findsOneWidget);
        expect(find.text('Amara Kalu'), findsNothing);
      });

      testWidgets('Send Request carries the trip that is selected', (
        tester,
      ) async {
        await pump(
          tester,
          trip: lagosLondon,
          profile: sampleProfile([lagosLondon, abujaDubai]),
        );

        // Switch to the second trip, then send a request.
        await tester.tap(find.byKey(const ValueKey('upcoming-trip-trip-b')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send Request'));
        await tester.pumpAndSettle();

        expect(find.byType(DeliveryRequestScreen), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('request-traveler-route')),
              )
              .data,
          'Abuja → Dubai · Jul 4',
        );
        expect(find.text('Max 10.0 kg'), findsOneWidget);
        expect(
          find.text('USD 50.00'),
          findsNothing,
        ); // request page, not profile
      });

      testWidgets('keeps the search-result data when the profile is missing', (
        tester,
      ) async {
        await pump(tester, trip: lagosLondon, profile: null);

        expect(find.text('Amara Kalu'), findsOneWidget);
        expect(find.text('Lagos'), findsOneWidget);
      });
    });
  });
}
