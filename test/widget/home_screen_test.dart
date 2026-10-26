import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('HomeScreen UI', () {
    late FakeTravelerService travelers;

    setUp(() => travelers = FakeTravelerService());

    Widget buildHome() => appWrapper(
      HomeScreen(
        authService: FakeAuthService(),
        travelerService: travelers,
        capitalLookup: fakeCapitalLookup,
      ),
    );

    testWidgets('renders greeting "Hello,"', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Hello,'), findsOneWidget);
    });

    testWidgets('greets the member by their first name only', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Fortune'), findsOneWidget);
      expect(find.text('Fortune Niama'), findsNothing);
    });

    testWidgets('a two-word first name shows its first word', (tester) async {
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(
              profile: const {'first_name': 'Mary Jane', 'last_name': 'Okafor'},
            ),
            travelerService: travelers,
            capitalLookup: fakeCapitalLookup,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mary'), findsOneWidget);
    });

    testWidgets('renders "Where are you sending?" search card heading', (
      tester,
    ) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Where are you sending?'), findsOneWidget);
    });

    testWidgets('renders Departure row', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('DEPARTURE'), findsOneWidget);
      expect(find.text('Abuja, Nigeria'), findsOneWidget);
    });

    testWidgets('renders Destination row', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('DESTINATION'), findsOneWidget);
    });

    testWidgets('renders Delivery Date row', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('DELIVERY DATE'), findsOneWidget);
    });

    testWidgets('renders Search Travelers button', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Search Travelers'), findsOneWidget);
    });

    testWidgets('renders Add a Trip button', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Add a Trip'), findsOneWidget);
    });

    testWidgets('renders Available Travelers section', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Available Travelers'), findsOneWidget);
    });

    testWidgets('renders traveler cards', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Amara K.'), findsOneWidget);
      expect(find.text('Daniel O.'), findsOneWidget);
      expect(find.text('Maya T.'), findsOneWidget);
    });

    testWidgets('renders traveler routes', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Lagos → London'), findsOneWidget);
      expect(find.text('Accra → Paris'), findsOneWidget);
      expect(find.text('Nairobi → Dubai'), findsOneWidget);
    });

    testWidgets('renders traveler date badges', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Jun 22'), findsOneWidget);
      expect(find.text('Jun 24'), findsOneWidget);
      expect(find.text('Jun 26'), findsOneWidget);
    });

    testWidgets('renders traveler capacity text from each trip weight limit', (
      tester,
    ) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('Up to 3.0 kg'), findsOneWidget);
      expect(find.text('Up to 5.0 kg'), findsOneWidget);
      expect(find.text('Up to 2.0 kg'), findsOneWidget);
    });

    testWidgets('renders View all link', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('bottom nav has 5 items', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      // 5 nav labels: Home, Requests, Trips, Messages, Profile
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('notification bell icon is present', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('date picker sheet opens on tapping date row', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();

      await tester.tap(find.text('Anytime this month'));
      await tester.pumpAndSettle();

      expect(find.text('Desired Delivery Date'), findsOneWidget);
    });
  });
}
