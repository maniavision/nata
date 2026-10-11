import 'package:carrywise_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// "Mon, Jun 22" – how Home shows the chosen date.
String fmt(DateTime d) => DateFormat('EEE, MMM d', 'en').format(d);

/// "Mon, June 22" – how the picker's summary line shows it.
String fmtLong(DateTime d) => DateFormat('EEE, MMMM d', 'en').format(d);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // The Sunday that ends this week / next week (what the chips select).
  DateTime endOfWeek(int weeksAhead) =>
      today.add(Duration(days: (7 - today.weekday) + 7 * weeksAhead));

  late FakeTravelerService service;

  setUp(() {
    // Two travelers arrive today, one arrives on the 15th of next month.
    final nextMonth = DateTime(today.year, today.month + 1, 15);
    service = FakeTravelerService(trips: [
      sampleTrip(tripId: 'a', departureDate: today, arrivalDate: today),
      sampleTrip(
          tripId: 'b',
          travelerId: 'traveler-2',
          firstName: 'Daniel',
          lastName: 'Okafor',
          departureDate: today,
          arrivalDate: today),
      sampleTrip(
          tripId: 'c',
          travelerId: 'traveler-3',
          firstName: 'Maya',
          lastName: 'Tariq',
          departureDate: nextMonth,
          arrivalDate: nextMonth),
    ]);
  });

  /// Pumps Home on a tall screen so the whole calendar sheet is visible.
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWrapper(HomeScreen(
      authService: FakeAuthService(),
      travelerService: service,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Anytime this month'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Text summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('date-summary')));

  group('Home date picker', () {
    testWidgets('opens with no date selected (no stale default date)',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      expect(find.text('Desired Delivery Date'), findsOneWidget);
      expect(summary(tester).data, 'Any date');
      expect(find.text('Confirm Date (Anytime)'), findsOneWidget);
    });

    testWidgets('shows real traveler counts per day and per month',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      // Two travelers arrive today.
      expect(find.text('2 flts'), findsOneWidget);
      expect(find.text('2 traveler flights'), findsOneWidget);

      // One arrives next month.
      await tapKey(tester, 'calendar-next-month');
      expect(find.text('1 traveler flight'), findsOneWidget);
      expect(find.text('2 flts'), findsNothing);
    });

    testWidgets('calendar counts follow the data (nothing fake)',
        (tester) async {
      service.trips = [];
      await pumpHome(tester);
      await openSheet(tester);

      expect(find.text('0 traveler flights'), findsOneWidget);
      expect(find.textContaining('flts'), findsNothing);
      expect(find.textContaining('14 verified'), findsNothing);
    });

    testWidgets('past days cannot be selected', (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      if (today.day > 1) {
        expect(find.byKey(const ValueKey('calendar-day-1')), findsNothing);
      }
      expect(find.byKey(ValueKey('calendar-day-${today.day}')), findsOneWidget);
    });

    testWidgets('cannot navigate to months before the current one',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      final heading = DateFormat('MMMM yyyy', 'en').format(today);
      expect(find.text(heading), findsOneWidget);

      await tapKey(tester, 'calendar-prev-month');
      expect(find.text(heading), findsOneWidget);
    });

    testWidgets('next month arrow moves the calendar forward', (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'calendar-next-month');

      final next = DateFormat('MMMM yyyy', 'en')
          .format(DateTime(today.year, today.month + 1));
      expect(find.text(next), findsOneWidget);
    });

    testWidgets('picking a day and confirming updates the Home date row',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'calendar-day-${today.day}');
      expect(summary(tester).data, startsWith(fmtLong(today)));
      expect(summary(tester).data, contains('2 flights'));

      await tapKey(tester, 'date-confirm');

      // Sheet closed, Home shows the chosen date.
      expect(find.text('Desired Delivery Date'), findsNothing);
      expect(find.text(fmt(today)), findsOneWidget);
      expect(find.text('Anytime this month'), findsNothing);
    });

    testWidgets('re-opening the picker keeps the previous choice',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);
      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-confirm');

      await tester.tap(find.text(fmt(today)));
      await tester.pumpAndSettle();

      expect(summary(tester).data, startsWith(fmtLong(today)));
    });

    testWidgets('"This Week" chip selects the end of this week',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'date-filter-1');
      expect(summary(tester).data, startsWith(fmtLong(endOfWeek(0))));

      await tapKey(tester, 'date-confirm');
      expect(find.text(fmt(endOfWeek(0))), findsOneWidget);
    });

    testWidgets('"Next Week" chip selects the end of next week',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'date-filter-2');
      expect(summary(tester).data, startsWith(fmtLong(endOfWeek(1))));

      await tapKey(tester, 'date-confirm');
      expect(find.text(fmt(endOfWeek(1))), findsOneWidget);
    });

    testWidgets('"Anytime" chip clears the date', (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-filter-0');
      expect(summary(tester).data, 'Any date');

      await tapKey(tester, 'date-confirm');
      expect(find.text('Anytime this month'), findsOneWidget);
    });

    testWidgets('"Anytime" chip is highlighted when no date is chosen',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      Color? chipColor(int i) => (tester
              .widget<AnimatedContainer>(find.descendant(
                  of: find.byKey(ValueKey('date-filter-$i')),
                  matching: find.byType(AnimatedContainer)))
              .decoration as BoxDecoration)
          .color;

      expect(chipColor(0), isNot(chipColor(1))); // Anytime is the active one
      await tapKey(tester, 'date-filter-1');
      expect(chipColor(0), isNot(chipColor(1)));
      // After choosing a week, "This Week" is now the highlighted chip.
      final active = chipColor(1);
      await tapKey(tester, 'date-filter-0');
      expect(chipColor(1), isNot(active));
    });

    testWidgets('"Flexible" chip adds ±3 days and shows on Home',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-filter-3');
      expect(summary(tester).data, contains('±3 days'));

      await tapKey(tester, 'date-confirm');
      expect(find.text('${fmt(today)} (±3d)'), findsOneWidget);
    });

    testWidgets('"Flexible" chip toggles off again', (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-filter-3');
      await tapKey(tester, 'date-filter-3');
      expect(summary(tester).data, isNot(contains('±3 days')));
    });

    testWidgets('closing the sheet without confirming changes nothing',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);

      await tapKey(tester, 'calendar-day-${today.day}');
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Anytime this month'), findsOneWidget);
    });
  });

  group('Home date picker -> traveler search', () {
    Future<void> search(WidgetTester tester) async {
      await tester.tap(find.text('Search Travelers'));
      await tester.pumpAndSettle();
    }

    testWidgets('search is sent without a date when "Anytime"',
        (tester) async {
      await pumpHome(tester);
      await search(tester);

      expect(service.searchCalls.last['date'], isNull);
      expect(service.searchCalls.last['departureCity'], 'Lagos');
    });

    testWidgets('search is sent with the picked date', (tester) async {
      await pumpHome(tester);
      await openSheet(tester);
      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-confirm');

      await search(tester);

      expect(service.searchCalls.last['date'], today);
    });

    testWidgets('flexible search accepts arrivals up to 3 days later',
        (tester) async {
      await pumpHome(tester);
      await openSheet(tester);
      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-filter-3');
      await tapKey(tester, 'date-confirm');

      await search(tester);

      expect(service.searchCalls.last['date'],
          today.add(const Duration(days: 3)));
    });
  });
}
