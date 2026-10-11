import 'package:carrywise_app/widgets/date_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  /// Opens the sheet from a button and records what it returned.
  Future<List<DatePickerResult?>> open(
    WidgetTester tester, {
    String title = 'Departure Date',
    DateTime? initialDate,
    bool initialFlexible = false,
    Map<DateTime, int>? flightCounts,
    bool showFilters = false,
    bool allowAnytime = false,
    DateTime? firstDate,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final results = <DatePickerResult?>[];
    await tester.pumpWidget(appWrapper(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => results.add(await DatePickerSheet.show(
            context,
            title: title,
            initialDate: initialDate,
            initialFlexible: initialFlexible,
            flightCounts: flightCounts,
            showFilters: showFilters,
            allowAnytime: allowAnytime,
            firstDate: firstDate,
          )),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Text summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('date-summary')));

  ElevatedButton confirm(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.byKey(const ValueKey('date-confirm')));

  group('DatePickerSheet (plain trip-date mode)', () {
    testWidgets('shows the title it was given', (tester) async {
      await open(tester, title: 'Arrival Date');

      expect(find.text('Arrival Date'), findsOneWidget);
    });

    testWidgets('has no quick filters', (tester) async {
      await open(tester);

      for (final label in ['Anytime', 'This Week', 'Next Week']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('Flexible (±3d)'), findsNothing);
    });

    testWidgets('has no traveler counts', (tester) async {
      await open(tester);

      expect(find.textContaining('traveler flight'), findsNothing);
      expect(find.textContaining('flts'), findsNothing);
    });

    testWidgets('requires a date: confirm is disabled until one is picked',
        (tester) async {
      await open(tester);

      expect(summary(tester).data, 'Select a date');
      expect(find.text('Select a date'), findsWidgets);
      expect(confirm(tester).onPressed, isNull);

      await tapKey(tester, 'calendar-day-${today.day}');
      expect(confirm(tester).onPressed, isNotNull);
    });

    testWidgets('confirming returns the picked day', (tester) async {
      final results = await open(tester);

      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-confirm');

      expect(results.single?.date, today);
      expect(results.single?.flexible, isFalse);
      expect(find.text('Departure Date'), findsNothing); // sheet closed
    });

    testWidgets('the summary shows the chosen day without flight counts',
        (tester) async {
      await open(tester);

      await tapKey(tester, 'calendar-day-${today.day}');

      expect(summary(tester).data,
          DateFormat('EEE, MMMM d', 'en').format(today));
    });

    testWidgets('the confirm button names the chosen day', (tester) async {
      await open(tester);

      await tapKey(tester, 'calendar-day-${today.day}');

      expect(find.text('Confirm Date (${DateFormat('MMM d', 'en').format(today)})'),
          findsOneWidget);
    });

    testWidgets('closing without confirming returns null', (tester) async {
      final results = await open(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(results, [null]);
    });

    testWidgets('starts on the month of the initial date', (tester) async {
      final initial = DateTime(today.year, today.month + 2, 12);
      await open(tester, initialDate: initial);

      expect(find.text(DateFormat('MMMM yyyy', 'en').format(initial)),
          findsOneWidget);
      expect(summary(tester).data, DateFormat('EEE, MMMM d', 'en').format(initial));
    });

    testWidgets('re-confirming the initial date returns it unchanged',
        (tester) async {
      final initial = DateTime(today.year, today.month + 1, 9);
      final results = await open(tester, initialDate: initial);

      await tapKey(tester, 'date-confirm');

      expect(results.single?.date, initial);
    });

    testWidgets('days before the first allowed date cannot be picked',
        (tester) async {
      final first = DateTime(today.year, today.month + 1, 15);
      await open(tester, firstDate: first);

      // Opens on the first allowed month.
      expect(find.text(DateFormat('MMMM yyyy', 'en').format(first)),
          findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-day-14')), findsNothing);
      expect(find.byKey(const ValueKey('calendar-day-15')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-day-16')), findsOneWidget);
    });

    testWidgets('cannot go back before the first allowed month',
        (tester) async {
      final first = DateTime(today.year, today.month + 1, 15);
      await open(tester, firstDate: first);
      final heading = DateFormat('MMMM yyyy', 'en').format(first);

      await tapKey(tester, 'calendar-prev-month');

      expect(find.text(heading), findsOneWidget);
    });

    testWidgets('the first allowed day itself can be picked', (tester) async {
      final first = DateTime(today.year, today.month + 1, 15);
      final results = await open(tester, firstDate: first);

      await tapKey(tester, 'calendar-day-15');
      await tapKey(tester, 'date-confirm');

      expect(results.single?.date, first);
    });

    testWidgets('can move forward to later months', (tester) async {
      final results = await open(tester);

      await tapKey(tester, 'calendar-next-month');
      await tapKey(tester, 'calendar-day-20');
      await tapKey(tester, 'date-confirm');

      expect(results.single?.date, DateTime(today.year, today.month + 1, 20));
    });

    testWidgets('defaults to today as the earliest date', (tester) async {
      await open(tester);

      if (today.day > 1) {
        expect(find.byKey(const ValueKey('calendar-day-1')), findsNothing);
      }
      expect(find.byKey(ValueKey('calendar-day-${today.day}')), findsOneWidget);
    });
  });

  group('DatePickerSheet (Home mode)', () {
    testWidgets('shows the quick filters when asked', (tester) async {
      await open(tester,
          title: 'Desired Delivery Date',
          showFilters: true,
          allowAnytime: true,
          flightCounts: const {});

      expect(find.text('Anytime'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Next Week'), findsOneWidget);
      expect(find.text('Flexible (±3d)'), findsOneWidget);
    });

    testWidgets('can confirm "anytime" (returns no date)', (tester) async {
      final results = await open(tester,
          allowAnytime: true, showFilters: true, flightCounts: const {});

      expect(summary(tester).data, 'Any date');
      expect(confirm(tester).onPressed, isNotNull);

      await tapKey(tester, 'date-confirm');

      expect(results.single?.date, isNull);
      expect(results.single?.flexible, isFalse);
    });

    testWidgets('shows per-day and per-month traveler counts', (tester) async {
      await open(tester,
          allowAnytime: true,
          showFilters: true,
          flightCounts: {today: 3});

      expect(find.text('3 flts'), findsOneWidget);
      expect(find.text('3 traveler flights'), findsOneWidget);
    });

    testWidgets('flexible is returned with the date', (tester) async {
      final results = await open(tester,
          allowAnytime: true, showFilters: true, flightCounts: const {});

      await tapKey(tester, 'calendar-day-${today.day}');
      await tapKey(tester, 'date-filter-3');
      await tapKey(tester, 'date-confirm');

      expect(results.single?.date, today);
      expect(results.single?.flexible, isTrue);
    });

    testWidgets('a remembered flexible choice is restored', (tester) async {
      await open(tester,
          initialDate: today,
          initialFlexible: true,
          allowAnytime: true,
          showFilters: true,
          flightCounts: const {});

      expect(summary(tester).data, contains('±3 days'));
    });
  });
}
