import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/screens/add_trip_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/ticket_check_service.dart';
import 'package:carrywise_app/services/trip_service.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

final _now = DateTime.now();
final today = DateTime(_now.year, _now.month, _now.day);

String longDate(DateTime d) => DateFormat('MMMM d, yyyy', 'en').format(d);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => PreferencesService().setCurrency(AppCurrency.usd));

  late FakeTripService service;
  late List<({String title, LocationSelection? initial})> pickerCalls;
  late LocationSelection lagos;
  late LocationSelection london;
  PickedReceipt? nextReceipt;
  Object? receiptError;
  PickedReceipt? nextPhoto;
  Object? cameraError;
  bool? popResult;
  bool popped = false;
  late FakeTicketCheck ticketCheck;
  late FakeTicketRedaction redaction;

  setUp(() {
    service = FakeTripService();
    ticketCheck = FakeTicketCheck();
    redaction = FakeTicketRedaction();
    pickerCalls = [];
    lagos = city('Lagos', 'NG', 'Nigeria', 1);
    london = city('London', 'GB', 'United Kingdom', 2);
    nextReceipt = sampleReceipt();
    receiptError = null;
    nextPhoto = sampleReceipt(name: 'photo.jpg', bytes: 4096);
    cameraError = null;
    popResult = null;
    popped = false;
  });

  Future<LocationSelection?> fakeLocationPicker(
    BuildContext context, {
    required String title,
    LocationSelection? initial,
  }) async {
    pickerCalls.add((title: title, initial: initial));
    return title == 'Departing From' ? lagos : london;
  }

  Future<PickedReceipt?> fakeReceiptPicker() async {
    if (receiptError != null) throw receiptError!;
    return nextReceipt;
  }

  Future<PickedReceipt?> fakeReceiptCamera() async {
    if (cameraError != null) throw cameraError!;
    return nextPhoto;
  }

  /// Opens AddTripScreen on top of a host page so pop(true) can be observed.
  Future<void> pump(WidgetTester tester, {Trip? trip}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddTripScreen(
                        trip: trip,
                        service: service,
                        locationPicker: fakeLocationPicker,
                        receiptPicker: fakeReceiptPicker,
                        receiptCamera: fakeReceiptCamera,
                        ticketCheck: ticketCheck,
                        ticketRedaction: redaction,
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(
    WidgetTester tester,
    String fieldKey,
    int day, {
    int monthsAhead = 0,
  }) async {
    await tapKey(tester, fieldKey);
    for (var i = 0; i < monthsAhead; i++) {
      await tapKey(tester, 'calendar-next-month');
    }
    await tapKey(tester, 'calendar-day-$day');
    await tapKey(tester, 'date-confirm');
  }

  Future<void> save(WidgetTester tester) async {
    await tapKey(tester, 'add-trip-save');
  }

  String? errorText(WidgetTester tester) {
    final f = find.descendant(
      of: find.byKey(const ValueKey('add-trip-error')),
      matching: find.byType(Text),
    );
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  /// Fills every required field with valid values.
  Future<void> fillValidForm(WidgetTester tester) async {
    await tapKey(tester, 'add-trip-departure-country');
    await tapKey(tester, 'add-trip-arrival-country');
    await pickDate(tester, 'add-trip-departure-date', today.day);
    await tapKey(tester, 'add-trip-upload-receipt');
  }

  group('AddTripScreen form', () {
    testWidgets('shows every section with empty pickers', (tester) async {
      await pump(tester);

      expect(find.text('Add a Trip'), findsOneWidget);
      expect(find.text('DEPARTURE DATE'), findsOneWidget);
      expect(find.text('ARRIVAL DATE'), findsOneWidget);
      expect(find.text('DEPARTURE COUNTRY'), findsOneWidget);
      expect(find.text('DEPARTURE CITY'), findsOneWidget);
      expect(find.text('ARRIVAL COUNTRY'), findsOneWidget);
      expect(find.text('ARRIVAL CITY'), findsOneWidget);
      expect(find.text('Select country'), findsNWidgets(2));
      expect(find.text('Select city'), findsNWidgets(2));
      expect(find.text('Select date'), findsNWidgets(2));
      expect(find.text('Save & Publish Trip'), findsOneWidget);
    });

    testWidgets('does not ask for a price', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('add-trip-price')), findsNothing);
      expect(find.textContaining('PRICE PER ITEM'), findsNothing);
    });

    testWidgets('does not show any made-up default data', (tester) async {
      await pump(tester);

      expect(find.textContaining('June 22, 2025'), findsNothing);
      expect(find.textContaining('British_Airways'), findsNothing);
      expect(find.textContaining('BA075'), findsNothing);
      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
    });

    testWidgets('capacity defaults to 3.0 kg and a shoebox', (tester) async {
      await pump(tester);

      expect(find.text('Up to 3.0 kg'), findsOneWidget);
      expect(find.text('Shoebox (30×20×15 cm)'), findsOneWidget);
    });

    testWidgets('back button leaves without saving', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(popResult, isNull);
      expect(service.created, isEmpty);
    });
  });

  group('country and city pickers', () {
    testWidgets('choosing a departure fills both country and city', (
      tester,
    ) async {
      await pump(tester);

      await tapKey(tester, 'add-trip-departure-country');

      expect(find.text('Nigeria'), findsOneWidget);
      expect(find.text('Lagos'), findsOneWidget);
      expect(pickerCalls.single.title, 'Departing From');
    });

    testWidgets('choosing an arrival fills both fields', (tester) async {
      await pump(tester);

      await tapKey(tester, 'add-trip-arrival-country');

      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      expect(pickerCalls.single.title, 'Arriving In');
    });

    testWidgets('the country field starts from the country list', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');

      await tapKey(tester, 'add-trip-departure-country');

      expect(pickerCalls.last.initial, isNull);
    });

    testWidgets('the city field opens on the chosen country\'s cities', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');

      await tapKey(tester, 'add-trip-departure-city');

      expect(pickerCalls.last.initial?.countryCode, 'NG');
      expect(pickerCalls.last.initial?.city, 'Lagos');
    });

    testWidgets('the city field with nothing chosen starts at countries', (
      tester,
    ) async {
      await pump(tester);

      await tapKey(tester, 'add-trip-arrival-city');

      expect(pickerCalls.single.initial, isNull);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // A picker the user dismisses without choosing.
      await tester.pumpWidget(
        appWrapper(
          AddTripScreen(
            service: service,
            locationPicker: (context, {required title, initial}) async => null,
            receiptPicker: fakeReceiptPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapKey(tester, 'add-trip-departure-country');

      expect(find.text('Select country'), findsNWidgets(2));
      expect(find.text('Select city'), findsNWidgets(2));
    });
  });

  group('date pickers', () {
    testWidgets('departure uses the shared calendar sheet', (tester) async {
      await pump(tester);

      await tapKey(tester, 'add-trip-departure-date');

      expect(find.text('Departure Date'), findsOneWidget);
      expect(find.text('Select a date'), findsWidgets);
      expect(find.text('This Week'), findsNothing); // plain mode, no chips
    });

    testWidgets('picking a departure shows it in the field', (tester) async {
      await pump(tester);

      await pickDate(tester, 'add-trip-departure-date', today.day);

      expect(find.text(longDate(today)), findsWidgets);
    });

    testWidgets('arrival defaults to the departure day', (tester) async {
      await pump(tester);

      await pickDate(tester, 'add-trip-departure-date', today.day);

      // Both date fields now show the same day.
      expect(find.text(longDate(today)), findsNWidgets(2));
    });

    testWidgets('arrival cannot be picked before the departure', (
      tester,
    ) async {
      await pump(tester);
      await pickDate(tester, 'add-trip-departure-date', 15, monthsAhead: 1);

      await tapKey(tester, 'add-trip-arrival-date');

      expect(find.text('Arrival Date'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-day-14')), findsNothing);
      expect(find.byKey(const ValueKey('calendar-day-15')), findsOneWidget);
    });

    testWidgets('departure cannot be in the past', (tester) async {
      await pump(tester);

      await tapKey(tester, 'add-trip-departure-date');

      if (today.day > 1) {
        expect(find.byKey(const ValueKey('calendar-day-1')), findsNothing);
      }
    });

    testWidgets('moving the departure past the arrival moves the arrival', (
      tester,
    ) async {
      await pump(tester);
      await pickDate(tester, 'add-trip-departure-date', today.day);
      await pickDate(tester, 'add-trip-arrival-date', 10, monthsAhead: 1);
      final arrival = DateTime(today.year, today.month + 1, 10);
      expect(find.text(longDate(arrival)), findsOneWidget);

      await pickDate(tester, 'add-trip-departure-date', 25, monthsAhead: 1);

      final newDeparture = DateTime(today.year, today.month + 1, 25);
      expect(find.text(longDate(arrival)), findsNothing);
      expect(find.text(longDate(newDeparture)), findsNWidgets(2));
    });

    testWidgets('an earlier departure keeps a later arrival', (tester) async {
      await pump(tester);
      await pickDate(tester, 'add-trip-departure-date', 20, monthsAhead: 1);
      await pickDate(tester, 'add-trip-arrival-date', 25, monthsAhead: 0);
      final arrival = DateTime(today.year, today.month + 1, 25);

      // The sheet reopens on the month of the current departure (next month).
      await pickDate(tester, 'add-trip-departure-date', 21);

      expect(find.text(longDate(arrival)), findsOneWidget);
    });
  });

  group('flight receipt', () {
    testWidgets('picking a receipt shows its name and size', (tester) async {
      nextReceipt = sampleReceipt(name: 'my_ticket.pdf', bytes: 2048);
      await pump(tester);

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(
        find.byKey(const ValueKey('add-trip-receipt-card')),
        findsOneWidget,
      );
      expect(find.text('my_ticket.pdf'), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);
      expect(find.text('✓ Attached'), findsOneWidget);
      // Both ways of attaching stay available, to replace the receipt.
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Upload File'), findsOneWidget);
    });

    testWidgets('large files show megabytes', (tester) async {
      nextReceipt = sampleReceipt(name: 'scan.png', bytes: 3 * 1024 * 1024);
      await pump(tester);

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(find.textContaining('3.0 MB'), findsOneWidget);
    });

    testWidgets('the receipt can be removed', (tester) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-upload-receipt');

      await tapKey(tester, 'add-trip-remove-receipt');

      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Upload File'), findsOneWidget);
    });

    testWidgets('a file over 10 MB is rejected', (tester) async {
      nextReceipt = sampleReceipt(
        name: 'huge.pdf',
        bytes: 10 * 1024 * 1024 + 1,
      );
      await pump(tester);

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(errorText(tester), 'That file is too large (max 10 MB).');
      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
    });

    testWidgets('cancelling the file picker changes nothing', (tester) async {
      nextReceipt = null;
      await pump(tester);

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
      expect(errorText(tester), isNull);
    });

    testWidgets('a picker failure shows an error instead of crashing', (
      tester,
    ) async {
      receiptError = Exception('no access');
      await pump(tester);

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(errorText(tester), 'Could not open that file.');
    });
  });

  group('take photo', () {
    testWidgets('shows Take Photo and Upload File side by side', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('add-trip-take-photo')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-trip-upload-receipt')),
        findsOneWidget,
      );
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Upload File'), findsOneWidget);

      final take = tester.getTopLeft(
        find.byKey(const ValueKey('add-trip-take-photo')),
      );
      final upload = tester.getTopLeft(
        find.byKey(const ValueKey('add-trip-upload-receipt')),
      );
      expect(take.dy, upload.dy); // same row
      expect(take.dx, lessThan(upload.dx)); // photo first, as in the design
    });

    testWidgets('a photo is attached as the receipt', (tester) async {
      nextPhoto = sampleReceipt(name: 'IMG_0042.jpg', bytes: 4096);
      await pump(tester);

      await tapKey(tester, 'add-trip-take-photo');

      expect(
        find.byKey(const ValueKey('add-trip-receipt-card')),
        findsOneWidget,
      );
      expect(find.text('IMG_0042.jpg'), findsOneWidget);
      expect(find.textContaining('4.0 KB'), findsOneWidget);
      expect(find.text('✓ Attached'), findsOneWidget);
    });

    testWidgets('the photo does not use the file picker', (tester) async {
      receiptError = Exception('file picker should not be used');
      await pump(tester);

      await tapKey(tester, 'add-trip-take-photo');

      expect(
        find.byKey(const ValueKey('add-trip-receipt-card')),
        findsOneWidget,
      );
      expect(errorText(tester), isNull);
    });

    testWidgets('the file picker does not use the camera', (tester) async {
      cameraError = Exception('camera should not be used');
      await pump(tester);

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(
        find.byKey(const ValueKey('add-trip-receipt-card')),
        findsOneWidget,
      );
      expect(errorText(tester), isNull);
    });

    testWidgets('cancelling the camera changes nothing', (tester) async {
      nextPhoto = null;
      await pump(tester);

      await tapKey(tester, 'add-trip-take-photo');

      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
      expect(errorText(tester), isNull);
    });

    testWidgets('an unavailable camera shows a clear message', (tester) async {
      cameraError = Exception('no camera available');
      await pump(tester);

      await tapKey(tester, 'add-trip-take-photo');

      expect(errorText(tester), 'Could not open the camera.');
      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
    });

    testWidgets('a photo over 10 MB is rejected like any other file', (
      tester,
    ) async {
      nextPhoto = sampleReceipt(name: 'huge.jpg', bytes: 10 * 1024 * 1024 + 1);
      await pump(tester);

      await tapKey(tester, 'add-trip-take-photo');

      expect(errorText(tester), 'That file is too large (max 10 MB).');
      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
    });

    testWidgets('a photo replaces a file that was already attached', (
      tester,
    ) async {
      nextReceipt = sampleReceipt(name: 'ticket.pdf');
      nextPhoto = sampleReceipt(name: 'photo.jpg');
      await pump(tester);
      await tapKey(tester, 'add-trip-upload-receipt');
      expect(find.text('ticket.pdf'), findsOneWidget);

      await tapKey(tester, 'add-trip-take-photo');

      expect(find.text('photo.jpg'), findsOneWidget);
      expect(find.text('ticket.pdf'), findsNothing);
    });

    testWidgets('a file replaces a photo that was already attached', (
      tester,
    ) async {
      nextReceipt = sampleReceipt(name: 'ticket.pdf');
      nextPhoto = sampleReceipt(name: 'photo.jpg');
      await pump(tester);
      await tapKey(tester, 'add-trip-take-photo');

      await tapKey(tester, 'add-trip-upload-receipt');

      expect(find.text('ticket.pdf'), findsOneWidget);
      expect(find.text('photo.jpg'), findsNothing);
    });

    testWidgets('the photo can be removed again', (tester) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-take-photo');

      await tapKey(tester, 'add-trip-remove-receipt');

      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
    });

    testWidgets('a retaken photo clears an earlier error', (tester) async {
      cameraError = Exception('no camera');
      await pump(tester);
      await tapKey(tester, 'add-trip-take-photo');
      expect(errorText(tester), isNotNull);

      cameraError = null;
      await tapKey(tester, 'add-trip-take-photo');

      expect(errorText(tester), isNull);
    });

    testWidgets('a photo satisfies the receipt requirement and is uploaded', (
      tester,
    ) async {
      nextPhoto = sampleReceipt(name: 'photo.jpg', bytes: 3000);
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');
      await tapKey(tester, 'add-trip-arrival-country');
      await pickDate(tester, 'add-trip-departure-date', today.day);
      await tapKey(tester, 'add-trip-take-photo');

      await save(tester);

      expect(service.uploaded.single.name, 'photo.jpg');
      expect(service.uploaded.single.contentType, 'image/jpeg');
      expect(service.created, hasLength(1));
      expect(popResult, isTrue);
    });

    testWidgets('a photo is required if nothing else is attached', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');
      await tapKey(tester, 'add-trip-arrival-country');
      await pickDate(tester, 'add-trip-departure-date', today.day);

      await save(tester);

      expect(errorText(tester), 'Attach your flight receipt.');
    });

    testWidgets('while editing, a photo replaces the receipt on file', (
      tester,
    ) async {
      await pump(
        tester,
        trip: sampleMyTrip(id: 'trip-7', receipt: 'user-1/old.pdf'),
      );
      expect(find.textContaining('Receipt on file'), findsOneWidget);

      await tapKey(tester, 'add-trip-take-photo');
      await save(tester);

      expect(service.uploaded.single.name, 'photo.jpg');
      expect(
        service.updated.single.draft.ticketReceiptPath,
        FakeTripService.uploadedPath,
      );
      expect(service.deletedReceipts, contains('user-1/old.pdf'));
    });
  });

  group('validation', () {
    testWidgets('an empty form asks for the departure first', (tester) async {
      await pump(tester);

      await save(tester);

      expect(errorText(tester), 'Choose where you are departing from.');
      expect(service.created, isEmpty);
      expect(service.uploaded, isEmpty);
    });

    testWidgets('then the destination', (tester) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');

      await save(tester);

      expect(errorText(tester), 'Choose your destination.');
    });

    testWidgets('departure and arrival must be different cities', (
      tester,
    ) async {
      london = lagos;
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');
      await tapKey(tester, 'add-trip-arrival-country');

      await save(tester);

      expect(
        errorText(tester),
        'Departure and arrival must be different cities.',
      );
    });

    testWidgets('then the departure date', (tester) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');
      await tapKey(tester, 'add-trip-arrival-country');

      await save(tester);

      expect(errorText(tester), 'Choose a departure date.');
    });

    testWidgets('then the flight receipt', (tester) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');
      await tapKey(tester, 'add-trip-arrival-country');
      await pickDate(tester, 'add-trip-departure-date', today.day);

      await save(tester);

      expect(errorText(tester), 'Attach your flight receipt.');
    });

    testWidgets('the error clears once the user fixes the field', (
      tester,
    ) async {
      await pump(tester);
      await save(tester);
      expect(errorText(tester), isNotNull);

      await tapKey(tester, 'add-trip-departure-country');

      expect(errorText(tester), isNull);
    });
  });

  group('saving a new trip', () {
    testWidgets('uploads a copy with the booking reference blurred', (
      tester,
    ) async {
      redaction.result = Uint8List.fromList([0xFF, 0xD8, 1, 2]);
      nextReceipt = sampleReceipt(name: 'ticket.pdf');
      await pump(tester);
      await fillValidForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('add-trip-booking-reference')),
        'X7KQ9R',
      );

      await save(tester);

      expect(redaction.calls.single.fileName, 'ticket.pdf');
      expect(redaction.calls.single.reference, 'X7KQ9R');
      expect(service.uploaded.map((r) => r.name), [
        'ticket.pdf',
        'ticket-shared.jpg',
      ]);
      final d = service.created.single;
      expect(d.ticketReceiptPath, FakeTripService.uploadedPath);
      expect(d.ticketSharedPath, FakeTripService.sharedPath);
    });

    testWidgets('no reference found: the trip is saved without a copy', (
      tester,
    ) async {
      nextReceipt = sampleReceipt(name: 'ticket.pdf');
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(service.uploaded, hasLength(1));
      expect(service.created.single.ticketSharedPath, isNull);
      expect(popResult, isTrue);
    });

    testWidgets('a failed save removes both uploads', (tester) async {
      redaction.result = Uint8List.fromList([0xFF, 0xD8, 1, 2]);
      service.failSave = true;
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(
        service.deletedReceipts,
        containsAll([FakeTripService.uploadedPath, FakeTripService.sharedPath]),
      );
    });

    testWidgets('uploads the receipt, then creates the trip', (tester) async {
      nextReceipt = sampleReceipt(name: 'ticket.pdf');
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(service.uploaded.single.name, 'ticket.pdf');
      expect(service.created, hasLength(1));
    });

    testWidgets('sends the chosen cities, dates and capacity', (tester) async {
      await pump(tester);
      await tapKey(tester, 'add-trip-departure-country');
      await tapKey(tester, 'add-trip-arrival-country');
      await pickDate(tester, 'add-trip-departure-date', today.day);
      await pickDate(tester, 'add-trip-arrival-date', 20, monthsAhead: 1);
      await tapKey(tester, 'add-trip-upload-receipt');
      await tester.tap(find.byKey(const ValueKey('add-trip-weight')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Up to 5.0 kg').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-trip-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backpack size').last);
      await tester.pumpAndSettle();

      await save(tester);

      final d = service.created.single;
      expect(d.departureCityId, 1);
      expect(d.arrivalCityId, 2);
      expect(d.departureDate, today);
      expect(d.arrivalDate, DateTime(today.year, today.month + 1, 20));
      // No price is asked for: prices come from the pricing formula.
      expect(d.price, 0);
      expect(d.currency, 'USD');
      expect(d.maxWeightKg, 5.0);
      expect(d.maxSize, 'Backpack size');
      expect(d.ticketReceiptPath, FakeTripService.uploadedPath);
      // And it is always submitted for review.
      expect(d.toInsertJson('u')['status'], 'pending_review');
    });

    testWidgets('uses the user\'s preferred currency', (tester) async {
      PreferencesService().setCurrency(AppCurrency.eur);
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(service.created.single.currency, 'EUR');
    });

    testWidgets('closes with true and confirms to the user', (tester) async {
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(popped, isTrue);
      expect(popResult, isTrue);
      expect(find.text('Trip submitted for review'), findsOneWidget);
    });

    testWidgets('shows a busy state and ignores a second tap', (tester) async {
      service.saveGate = Completer<void>();
      await pump(tester);
      await fillValidForm(tester);

      await tester.tap(find.byKey(const ValueKey('add-trip-save')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('add-trip-save')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('add-trip-save')),
        warnIfMissed: false,
      );
      await tester.pump();

      service.saveGate!.complete();
      await tester.pumpAndSettle();

      expect(service.created, hasLength(1)); // not saved twice
      expect(service.uploaded, hasLength(1));
      expect(popResult, isTrue);
    });
  });

  group('when saving fails', () {
    testWidgets('a failed save shows an error and stays on the form', (
      tester,
    ) async {
      service.failSave = true;
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(errorText(tester), 'Could not save your trip. Please try again.');
      expect(popped, isFalse);
      expect(find.text('Save & Publish Trip'), findsOneWidget);
    });

    testWidgets('the form keeps its values so the user can retry', (
      tester,
    ) async {
      service.failSave = true;
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);

      service.failSave = false;
      await save(tester);

      expect(service.created, hasLength(1));
      expect(popResult, isTrue);
    });

    testWidgets('a receipt uploaded for a failed save is cleaned up', (
      tester,
    ) async {
      service.failSave = true;
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(service.deletedReceipts, contains(FakeTripService.uploadedPath));
    });

    testWidgets('a failed upload creates nothing', (tester) async {
      service.failUpload = true;
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(errorText(tester), 'Could not save your trip. Please try again.');
      expect(service.created, isEmpty);
      expect(popped, isFalse);
    });
  });

  group('clear', () {
    testWidgets('resets everything', (tester) async {
      await pump(tester);
      await fillValidForm(tester);

      await tapKey(tester, 'add-trip-clear');

      expect(find.text('Select country'), findsNWidgets(2));
      expect(find.text('Select city'), findsNWidgets(2));
      expect(find.text('Select date'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('add-trip-receipt-card')), findsNothing);
    });
  });

  group('editing a trip', () {
    late Trip trip;

    setUp(() {
      trip = sampleMyTrip(
        id: 'trip-42',
        departureDate: DateTime(today.year, today.month + 1, 12),
        arrivalDate: DateTime(today.year, today.month + 1, 13),
        price: 30,
        maxWeightKg: 5,
        maxSize: 'Backpack size',
        receipt: 'user-1/old.pdf',
      );
    });

    testWidgets('shows the edit title and button', (tester) async {
      await pump(tester, trip: trip);

      expect(find.text('Edit Trip'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save & Publish Trip'), findsNothing);
    });

    testWidgets('is pre-filled with the trip', (tester) async {
      await pump(tester, trip: trip);

      expect(find.text('Nigeria'), findsOneWidget);
      expect(find.text('Lagos'), findsOneWidget);
      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      expect(find.text(longDate(trip.departureDate)), findsOneWidget);
      expect(find.text(longDate(trip.arrivalDate)), findsOneWidget);
      expect(find.text('Up to 5.0 kg'), findsOneWidget);
      expect(find.text('Backpack size'), findsOneWidget);
      expect(find.text('old.pdf'), findsOneWidget);
      expect(find.textContaining('Receipt on file'), findsOneWidget);
    });

    testWidgets('saving updates that trip without re-uploading', (
      tester,
    ) async {
      await pump(tester, trip: trip);

      await save(tester);

      expect(service.created, isEmpty);
      expect(service.uploaded, isEmpty);
      final u = service.updated.single;
      expect(u.id, 'trip-42');
      expect(u.draft.departureCityId, 1);
      expect(u.draft.arrivalCityId, 2);
      expect(u.draft.ticketReceiptPath, 'user-1/old.pdf');
      // The trip's existing price is kept as it was.
      expect(u.draft.price, 30.0);
      expect(popResult, isTrue);
      expect(find.text('Trip updated'), findsOneWidget);
    });

    testWidgets('changing fields is sent in the update', (tester) async {
      await pump(tester, trip: trip);
      await tapKey(
        tester,
        'add-trip-arrival-country',
      ); // London -> london again
      lagos = city('Abuja', 'NG', 'Nigeria', 7);
      await tapKey(tester, 'add-trip-departure-country');

      await save(tester);

      final d = service.updated.single.draft;
      expect(d.price, 30.0); // unchanged
      expect(d.departureCityId, 7);
    });

    testWidgets('replacing the receipt uploads it and removes the old one', (
      tester,
    ) async {
      await pump(tester, trip: trip);

      await tapKey(tester, 'add-trip-upload-receipt');
      await save(tester);

      expect(service.uploaded, hasLength(1));
      expect(
        service.updated.single.draft.ticketReceiptPath,
        FakeTripService.uploadedPath,
      );
      expect(service.deletedReceipts, contains('user-1/old.pdf'));
    });

    testWidgets('the blurred copy is kept when the ticket is unchanged', (
      tester,
    ) async {
      await pump(tester, trip: trip);

      await save(tester);

      expect(redaction.calls, isEmpty);
      expect(
        service.updated.single.draft.ticketSharedPath,
        'user-1/111-shared.jpg',
      );
      expect(service.deletedReceipts, isEmpty);
    });

    testWidgets('a new ticket replaces the blurred copy too', (tester) async {
      redaction.result = Uint8List.fromList([0xFF, 0xD8, 1, 2]);
      await pump(tester, trip: trip);

      await tapKey(tester, 'add-trip-upload-receipt');
      await save(tester);

      expect(
        service.updated.single.draft.ticketSharedPath,
        FakeTripService.sharedPath,
      );
      expect(
        service.deletedReceipts,
        containsAll(['user-1/old.pdf', 'user-1/111-shared.jpg']),
      );
    });

    testWidgets('an older trip without a copy gets one when saved', (
      tester,
    ) async {
      redaction.result = Uint8List.fromList([0xFF, 0xD8, 1, 2]);
      await pump(
        tester,
        trip: sampleMyTrip(
          id: 'trip-7',
          receipt: 'user-1/old.pdf',
          sharedTicket: null,
        ),
      );

      await save(tester);

      expect(service.downloadedReceipts, ['user-1/old.pdf']);
      expect(redaction.calls.single.fileName, 'user-1/old.pdf');
      expect(service.uploaded.single.name, 'ticket-shared.jpg');
      expect(
        service.updated.single.draft.ticketSharedPath,
        FakeTripService.sharedPath,
      );
    });

    testWidgets('removing the receipt without a new one is not allowed', (
      tester,
    ) async {
      await pump(tester, trip: trip);
      await tapKey(tester, 'add-trip-remove-receipt');

      await save(tester);

      expect(errorText(tester), 'Attach your flight receipt.');
      expect(service.updated, isEmpty);
    });

    testWidgets('a failed update does not delete the old receipt', (
      tester,
    ) async {
      service.failSave = true;
      await pump(tester, trip: trip);
      await tapKey(tester, 'add-trip-upload-receipt');

      await save(tester);

      expect(service.deletedReceipts, isNot(contains('user-1/old.pdf')));
      expect(errorText(tester), isNotNull);
    });

    testWidgets('a weight that is not in the list is still offered', (
      tester,
    ) async {
      trip = sampleMyTrip(maxWeightKg: 7.5);
      await pump(tester, trip: trip);

      expect(find.text('Up to 7.5 kg'), findsOneWidget);

      await save(tester);
      expect(service.updated.single.draft.maxWeightKg, 7.5);
    });

    testWidgets('a size that is not in the list is preserved', (tester) async {
      trip = sampleMyTrip(maxSize: 'Large suitcase');
      await pump(tester, trip: trip);

      expect(find.text('Large suitcase'), findsOneWidget);

      await save(tester);
      expect(service.updated.single.draft.maxSize, 'Large suitcase');
    });
  });

  group('booking reference', () {
    Future<void> typeRef(WidgetTester tester, String text) async {
      await tester.enterText(
        find.byKey(const ValueKey('add-trip-booking-reference')),
        text,
      );
      await tester.pump();
    }

    String refText(WidgetTester tester) => tester
        .widget<TextField>(
          find.byKey(const ValueKey('add-trip-booking-reference')),
        )
        .controller!
        .text;

    testWidgets('shows the booking reference card', (tester) async {
      await pump(tester);

      expect(find.text('BOOKING REFERENCE'), findsOneWidget);
      expect(
        find.text('Enter the reference code from your flight booking (PNR)'),
        findsOneWidget,
      );
      expect(find.text('e.g. X7KQ9R'), findsOneWidget);
    });

    testWidgets('sits between the flight receipt and the capacity cards', (
      tester,
    ) async {
      await pump(tester);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('FLIGHT TICKET RECEIPT'), lessThan(top('BOOKING REFERENCE')));
      expect(
        top('BOOKING REFERENCE'),
        lessThan(top('LUGGAGE CAPACITY YOU CAN CARRY')),
      );
    });

    testWidgets('upper-cases what the user types', (tester) async {
      await pump(tester);

      await typeRef(tester, 'x7kq9r');

      expect(refText(tester), 'X7KQ9R');
    });

    testWidgets('drops spaces and symbols', (tester) async {
      await pump(tester);

      await typeRef(tester, 'ab-1 2_3!');

      expect(refText(tester), 'AB123');
    });

    testWidgets('stops at 8 characters', (tester) async {
      await pump(tester);

      await typeRef(tester, 'abcdefghij12');

      expect(refText(tester), 'ABCDEFGH');
    });

    testWidgets('accented letters are not accepted', (tester) async {
      await pump(tester);

      await typeRef(tester, 'éàX7KQ');

      expect(refText(tester), 'X7KQ');
    });

    testWidgets('is optional: a trip can be saved without one', (tester) async {
      await pump(tester);
      await fillValidForm(tester);

      await save(tester);

      expect(service.created.single.bookingReference, isNull);
      expect(popResult, isTrue);
    });

    testWidgets('a valid reference is saved with the trip', (tester) async {
      await pump(tester);
      await fillValidForm(tester);
      await typeRef(tester, 'x7kq9r');

      await save(tester);

      expect(service.created.single.bookingReference, 'X7KQ9R');
      expect(
        service.created.single.toInsertJson('u')['booking_reference'],
        'X7KQ9R',
      );
    });

    for (final ok in ['ABC12', 'ABCDEFG8']) {
      testWidgets('accepts the boundary length "$ok"', (tester) async {
        await pump(tester);
        await fillValidForm(tester);
        await typeRef(tester, ok);

        await save(tester);

        expect(service.created.single.bookingReference, ok);
      });
    }

    testWidgets('a reference that is too short is rejected', (tester) async {
      await pump(tester);
      await fillValidForm(tester);
      await typeRef(tester, 'AB12');

      await save(tester);

      expect(
        errorText(tester),
        'Booking reference must be 5–8 letters or numbers.',
      );
      expect(service.created, isEmpty);
      expect(service.uploaded, isEmpty);
    });

    testWidgets('the error clears when the user edits the field', (
      tester,
    ) async {
      await pump(tester);
      await fillValidForm(tester);
      await typeRef(tester, 'AB12');
      await save(tester);
      expect(errorText(tester), isNotNull);

      await typeRef(tester, 'AB123');

      expect(errorText(tester), isNull);
    });

    testWidgets('an invalid one stops the save', (tester) async {
      await pump(tester);
      await fillValidForm(tester);
      await typeRef(tester, 'AB1');

      await save(tester);

      expect(
        errorText(tester),
        'Booking reference must be 5–8 letters or numbers.',
      );
    });

    testWidgets('Clear empties it', (tester) async {
      await pump(tester);
      await typeRef(tester, 'X7KQ9R');

      await tapKey(tester, 'add-trip-clear');

      expect(refText(tester), isEmpty);
    });

    group('depends on the route', () {
      Finder card() => find.text('BOOKING REFERENCE');

      testWidgets('shows before the countries are picked', (tester) async {
        await pump(tester);

        expect(card(), findsOneWidget);
      });

      testWidgets('shows for an international trip', (tester) async {
        await pump(tester);
        await fillValidForm(tester); // Lagos -> London

        expect(card(), findsOneWidget);
      });

      for (final (from, to) in [
        (
          city('Lagos', 'NG', 'Nigeria', 11),
          city('Abuja', 'NG', 'Nigeria', 12),
        ),
        (
          city('Sao Paulo', 'BR', 'Brazil', 13),
          city('Rio de Janeiro', 'BR', 'Brazil', 14),
        ),
      ]) {
        testWidgets('hides for a domestic trip in ${from.country}', (
          tester,
        ) async {
          lagos = from;
          london = to;
          await pump(tester);
          await typeRef(tester, 'X7KQ9R');
          await fillValidForm(tester);

          expect(card(), findsNothing);

          await save(tester);

          // What was typed before the route was picked is not saved.
          expect(service.created.single.bookingReference, isNull);
        });
      }

      testWidgets('shows for a domestic trip elsewhere (US)', (tester) async {
        lagos = city('New York', 'US', 'United States', 15);
        london = city('Chicago', 'US', 'United States', 16);
        await pump(tester);
        await fillValidForm(tester);

        expect(card(), findsOneWidget);
      });
    });

    group('when editing', () {
      testWidgets('is pre-filled from the trip', (tester) async {
        await pump(tester, trip: sampleMyTrip(bookingReference: 'X7KQ9R'));

        expect(refText(tester), 'X7KQ9R');
      });

      testWidgets('is empty for a trip that has none', (tester) async {
        await pump(tester, trip: sampleMyTrip());

        expect(refText(tester), isEmpty);
      });

      testWidgets('can be changed', (tester) async {
        await pump(
          tester,
          trip: sampleMyTrip(id: 't1', bookingReference: 'OLD123'),
        );
        await typeRef(tester, 'new456');

        await save(tester);

        expect(service.updated.single.draft.bookingReference, 'NEW456');
      });

      testWidgets('can be added to a trip that had none', (tester) async {
        await pump(tester, trip: sampleMyTrip(id: 't1'));
        await typeRef(tester, 'x7kq9r');

        await save(tester);

        expect(service.updated.single.draft.bookingReference, 'X7KQ9R');
      });

      testWidgets('can be removed, which clears it on the trip', (
        tester,
      ) async {
        await pump(
          tester,
          trip: sampleMyTrip(id: 't1', bookingReference: 'X7KQ9R'),
        );
        await typeRef(tester, '');

        await save(tester);

        expect(service.updated.single.draft.bookingReference, isNull);
        expect(
          service.updated.single.draft.toUpdateJson()['booking_reference'],
          isNull,
        );
      });

      testWidgets('an unchanged reference is sent back as it was', (
        tester,
      ) async {
        await pump(
          tester,
          trip: sampleMyTrip(id: 't1', bookingReference: 'X7KQ9R'),
        );

        await save(tester);

        expect(service.updated.single.draft.bookingReference, 'X7KQ9R');
      });
    });
  });

  group('the flight ticket is checked', () {
    testWidgets('with the trip\'s dates, before saving', (tester) async {
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);

      expect(ticketCheck.calls.single.fileName, 'ticket.pdf');
      expect(ticketCheck.calls.single.departure, today);
      expect(service.created, hasLength(1));
      expect(popResult, isTrue);
    });

    testWidgets('someone else\'s ticket is refused', (tester) async {
      ticketCheck.result = TicketCheckResult.nameMismatch;
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);

      expect(
        errorText(tester),
        "The name on this ticket doesn't match your profile name. "
        'Upload a ticket in your name, or update your profile name.',
      );
      expect(service.created, isEmpty);
      expect(service.uploaded, isEmpty); // nothing uploaded either
      expect(popped, isFalse);
    });

    testWidgets('a ticket for another day is refused, naming the date', (
      tester,
    ) async {
      ticketCheck.result = TicketCheckResult.dateMismatch;
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);

      expect(
        errorText(tester),
        "This ticket isn't for ${longDate(today)}. "
        "Check the trip's dates, or upload the ticket for this flight.",
      );
      expect(service.created, isEmpty);
    });

    testWidgets('an unreadable ticket is refused', (tester) async {
      ticketCheck.result = TicketCheckResult.unreadable;
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);

      expect(errorText(tester), startsWith("We couldn't read this ticket."));
      expect(service.created, isEmpty);
    });

    testWidgets('no profile name to compare: saved on the date alone', (
      tester,
    ) async {
      ticketCheck.result = TicketCheckResult.unverifiable;
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);

      expect(service.created, hasLength(1));
    });

    testWidgets('fixing the problem lets it save', (tester) async {
      ticketCheck.result = TicketCheckResult.dateMismatch;
      await pump(tester);
      await fillValidForm(tester);
      await save(tester);
      expect(service.created, isEmpty);

      ticketCheck.result = TicketCheckResult.passed;
      await save(tester);

      expect(service.created, hasLength(1));
    });

    group('when editing', () {
      Trip trip() => sampleMyTrip(
        id: 'trip-42',
        departureDate: DateTime(today.year, today.month + 1, 12),
        arrivalDate: DateTime(today.year, today.month + 1, 12),
        receipt: 'user-1/old.pdf',
      );

      testWidgets('same dates, same ticket: not checked again', (tester) async {
        await pump(tester, trip: trip());
        await save(tester);

        expect(ticketCheck.calls, isEmpty);
        expect(service.downloadedReceipts, isEmpty);
        expect(service.updated, hasLength(1));
      });

      testWidgets('new dates: the ticket on file is checked against them', (
        tester,
      ) async {
        ticketCheck.result = TicketCheckResult.dateMismatch;
        await pump(tester, trip: trip());
        // The calendar opens on the trip's month.
        await pickDate(tester, 'add-trip-departure-date', 20);
        await save(tester);

        expect(service.downloadedReceipts, ['user-1/old.pdf']);
        expect(
          ticketCheck.calls.single.departure,
          DateTime(today.year, today.month + 1, 20),
        );
        expect(service.updated, isEmpty);
        expect(errorText(tester), startsWith("This ticket isn't for"));
      });
    });
  });
}
