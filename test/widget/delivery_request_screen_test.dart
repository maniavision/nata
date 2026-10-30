import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/screens/delivery_request_screen.dart';
import 'package:carrywise_app/services/city_service.dart';
import 'package:carrywise_app/services/exchange_rate_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:carrywise_app/services/trip_service.dart' show PickedReceipt;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

PickedReceipt photo({String name = 'IMG.jpg', int bytes = 2000}) =>
    PickedReceipt(bytes: Uint8List(bytes), name: name, extension: 'jpg');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });

  late FakeRequestService service;
  late FakeCityService cities;
  late FakeExchangeRateService rates;
  late TravelerTrip trip;
  PickedReceipt? nextPhoto;
  Object? pickerError;
  final pickerCalls = <bool>[];
  var idCounter = 0;
  bool popped = false;

  // "Now" is the day before the flight, so the price is the 24-hour price.
  final fixedNow = DateTime.utc(2030, 6, 21, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    service = FakeRequestService();
    cities = FakeCityService();
    rates = FakeExchangeRateService();
    trip = sampleTrip(
      tripId: 'trip-77',
      firstName: 'Amara',
      lastName: 'Kalu',
      departureCity: 'Lagos',
      arrivalCity: 'London',
      departureDate: DateTime(2030, 6, 22),
      maxWeightKg: 3,
      maxSize: 'Shoebox (30×20×15 cm)',
      price: 25,
      currency: 'USD',
    );
    nextPhoto = photo();
    pickerError = null;
    pickerCalls.clear();
    idCounter = 0;
    popped = false;
  });

  Future<PickedReceipt?> fakePicker({required bool camera}) async {
    pickerCalls.add(camera);
    if (pickerError != null) throw pickerError!;
    return nextPhoto;
  }

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    TravelerTrip? tripOverride,
    AppCurrency currency = AppCurrency.usd,
    bool settle = true,
  }) async {
    PreferencesService().setCurrency(currency);
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    // Opened on top of a host page, as in the app, so "back to start" works.
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryRequestScreen(
                      trip: tripOverride ?? trip,
                      service: service,
                      photoPicker: fakePicker,
                      idGenerator: () => 'req-${++idCounter}',
                      cityService: cities,
                      exchangeRates: rates,
                      now: () => fixedNow,
                    ),
                  ),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Let the page slide in, but don't wait for the spinner to stop.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
    // Naming an item also gives it a value, so tests about other fields
    // get past the value check; the value tests clear it again.
    final item = RegExp(r'^request-item-(\d+)$').firstMatch(key);
    if (item != null && text.trim().isNotEmpty) {
      final value = find.byKey(ValueKey('request-item-value-${item[1]}'));
      if (value.evaluate().isNotEmpty) {
        await tester.enterText(value, '100');
        await tester.pump();
      }
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> addPhoto(WidgetTester tester, {bool camera = true}) async {
    await tapKey(tester, 'request-add-photo');
    await tapKey(
      tester,
      camera ? 'request-photo-camera' : 'request-photo-library',
    );
  }

  /// A completely valid form.
  Future<void> fillValid(WidgetTester tester) async {
    await enter(tester, 'request-item-0', 'Apple AirPods Max');
    await enter(tester, 'request-recipient-name', 'Jane Doe');
    await enter(tester, 'request-recipient-phone', '+44 7700 900123');
    await enter(tester, 'request-weight', '0.9 kg');
    await tapKey(tester, 'request-size-shoebox');
    await addPhoto(tester);
  }

  String? errorText(WidgetTester tester) {
    final f = find.descendant(
      of: find.byKey(const ValueKey('request-error')),
      matching: find.byType(Text),
    );
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  Future<void> send(WidgetTester tester) => tapKey(tester, 'request-send');

  group('selected traveler', () {
    testWidgets('shows who and where', (tester) async {
      await pump(tester);

      expect(find.text('SELECTED TRAVELER'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('request-traveler-name')))
            .data,
        'Amara Kalu',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('request-traveler-route')))
            .data,
        'Lagos → London · Jun 22',
      );
    });

    testWidgets('shows the weight limit chip', (tester) async {
      await pump(tester);

      expect(find.text('Max 3.0 kg'), findsOneWidget);
    });

    testWidgets('no chip when the traveler set no limit', (tester) async {
      await pump(tester, tripOverride: sampleTrip(maxWeightKg: null));

      expect(find.byKey(const ValueKey('request-max-chip')), findsNothing);
    });

    testWidgets('is the traveler the screen was opened for', (tester) async {
      await pump(
        tester,
        tripOverride: sampleTrip(
          firstName: 'Daniel',
          lastName: 'Okafor',
          departureCity: 'Accra',
          arrivalCity: 'Paris',
        ),
      );

      expect(find.text('Daniel Okafor'), findsOneWidget);
      expect(find.text('Amara Kalu'), findsNothing);
      expect(find.textContaining('Accra → Paris'), findsOneWidget);
    });
  });

  group('the form', () {
    testWidgets('has every section', (tester) async {
      await pump(tester);

      for (final t in [
        'Delivery Request',
        'Item Requirement',
        'WHAT IS THE ITEM?',
        'ITEM CATEGORY',
        'ITEM DESCRIPTION',
        'Recipient Details',
        'RECIPIENT NAME',
        'RECIPIENT PHONE NUMBER',
        'Size and Weight',
        'PACKAGE WEIGHT',
        'PACKAGE DIMENSIONS',
        'Item Photos (Sealed Box)',
        'Calculated Item Price',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // A single page: no step counter.
      expect(find.textContaining('Step 1'), findsNothing);
    });

    testWidgets('starts empty: no made-up AirPods or recipient', (
      tester,
    ) async {
      await pump(tester);

      for (final k in [
        'request-item-0',
        'request-description-0',
        'request-recipient-name',
        'request-recipient-phone',
        'request-weight',
        'request-dimensions',
      ]) {
        expect(
          tester.widget<TextField>(find.byKey(ValueKey(k))).controller!.text,
          isEmpty,
          reason: k,
        );
      }
      expect(find.textContaining('AirPods'), findsNothing);
    });

    testWidgets('shows the placeholders from the design', (tester) async {
      await pump(tester);

      expect(
        find.text('e.g. Sony Headphones, Sealed Cosmetics, etc.'),
        findsOneWidget,
      );
      expect(find.text('Full name as on their ID'), findsOneWidget);
      expect(find.text('e.g. 7700 900123'), findsOneWidget);
      expect(
        find.text('Provide details about the item and packaging...'),
        findsOneWidget,
      );
    });

    testWidgets('says the phone is shared only after the traveler accepts', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.text(
          'Shared with the traveler only after they accept your request',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the traveler\'s limits next to weight and size', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Traveler limit: 3.0 kg'), findsOneWidget);
      expect(
        find.text('Traveler limit: Shoebox (30×20×15 cm)'),
        findsOneWidget,
      );
    });

    testWidgets('limits show a dash when the traveler set none', (
      tester,
    ) async {
      await pump(
        tester,
        tripOverride: sampleTrip(maxWeightKg: null, maxSize: null),
      );

      expect(find.text('Traveler limit: —'), findsNWidgets(2));
    });

    testWidgets('the phone field only accepts phone characters', (
      tester,
    ) async {
      await pump(tester);

      await enter(tester, 'request-recipient-phone', 'abc+44 (77)-00.9x');

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('request-recipient-phone')),
            )
            .controller!
            .text,
        '+44 (77)-00.9',
      );
    });

    testWidgets('back leaves without sending', (tester) async {
      await pump(tester);

      await tapKey(tester, 'request-back');

      expect(popped, isTrue);
      expect(service.sent, isEmpty);
    });
  });

  group('several items', () {
    String text(WidgetTester t, String key) =>
        t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

    String total(WidgetTester t) =>
        t.widget<Text>(find.byKey(const ValueKey('request-price-total'))).data!;

    Future<void> addItem(WidgetTester t) => tapKey(t, 'request-add-item');

    testWidgets('starts with one item, and nothing to remove', (tester) async {
      await pump(tester);

      expect(find.text('Items'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('ITEM 1'), findsOneWidget);
      expect(find.text('ITEM 2'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Add another item'), findsOneWidget);
    });

    testWidgets('"Add another item" adds an empty card', (tester) async {
      await pump(tester);

      await addItem(tester);

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('ITEM 2'), findsOneWidget);
      expect(text(tester, 'request-item-1'), isEmpty);
      expect(text(tester, 'request-description-1'), isEmpty);
    });

    testWidgets('once there are two, each can be removed', (tester) async {
      await pump(tester);

      await addItem(tester);

      expect(find.text('Remove'), findsNWidgets(2));
    });

    testWidgets('each item keeps what was typed for it', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'AirPods');
      await addItem(tester);

      await enter(tester, 'request-item-1', 'Shirt');
      await enter(tester, 'request-description-1', 'Blue, size M');

      expect(text(tester, 'request-item-0'), 'AirPods');
      expect(text(tester, 'request-item-1'), 'Shirt');
      expect(text(tester, 'request-description-0'), isEmpty);
      expect(text(tester, 'request-description-1'), 'Blue, size M');
    });

    testWidgets('each item has its own category', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await addItem(tester);
      await enter(tester, 'request-item-1', 'Contract');

      await tapKey(tester, 'request-category-1-documents');
      await send(tester);

      final items = service.sent.single.draft.items;
      expect(items[0].category, RequestCategory.electronics);
      expect(items[1].category, RequestCategory.documents);
    });

    testWidgets('a new item starts as Electronics', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await tapKey(tester, 'request-category-0-apparel');
      await addItem(tester);
      await enter(tester, 'request-item-1', 'Phone');

      await send(tester);

      final items = service.sent.single.draft.items;
      expect(items[0].category, RequestCategory.apparel); // chosen for item 0
      expect(items[1].category, RequestCategory.electronics);
    });

    testWidgets('all items are sent together, in order, as one request', (
      tester,
    ) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-description-0', 'sealed');
      await addItem(tester);
      await enter(tester, 'request-item-1', '  Shirt ');
      await tapKey(tester, 'request-category-1-apparel');
      await addItem(tester);
      await enter(tester, 'request-item-2', 'Passport copy');
      await tapKey(tester, 'request-category-2-documents');

      await send(tester);

      expect(service.sent.length, 1);
      final items = service.sent.single.draft.items;
      expect(items.map((i) => i.name.trim()), [
        'Apple AirPods Max',
        'Shirt',
        'Passport copy',
      ]);
      expect(items.map((i) => i.category), [
        RequestCategory.electronics,
        RequestCategory.apparel,
        RequestCategory.documents,
      ]);
      expect(items[0].description, 'sealed');
      expect(items[1].description, isEmpty);
    });

    testWidgets('removing an item keeps the others as they were', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'AirPods');
      await addItem(tester);
      await enter(tester, 'request-item-1', 'Shirt');
      await tapKey(tester, 'request-category-1-apparel');
      await addItem(tester);
      await enter(tester, 'request-item-2', 'Contract');

      await tapKey(tester, 'request-item-remove-0');

      expect(find.text('2 items'), findsOneWidget);
      expect(text(tester, 'request-item-0'), 'Shirt');
      expect(text(tester, 'request-item-1'), 'Contract');
      await fillValid(tester); // overwrites item 0's name only
      await enter(tester, 'request-item-0', 'Shirt');
      await send(tester);
      final items = service.sent.single.draft.items;
      expect(items.map((i) => i.name), ['Shirt', 'Contract']);
      expect(items[0].category, RequestCategory.apparel); // went with "Shirt"
    });

    testWidgets('removing back to one item hides Remove again', (tester) async {
      await pump(tester);
      await addItem(tester);

      await tapKey(tester, 'request-item-remove-1');

      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('ITEM 2'), findsNothing);
    });

    testWidgets('numbers close up after a removal', (tester) async {
      await pump(tester);
      await addItem(tester);
      await addItem(tester);

      await tapKey(tester, 'request-item-remove-1');

      expect(find.text('ITEM 1'), findsOneWidget);
      expect(find.text('ITEM 2'), findsOneWidget);
      expect(find.text('ITEM 3'), findsNothing);
    });

    testWidgets('up to five items, then the button gives way to a note', (
      tester,
    ) async {
      await pump(tester);

      for (var i = 0; i < 4; i++) {
        await addItem(tester);
      }

      expect(find.text('5 items'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-add-item')), findsNothing);
      expect(
        find.text('You can send up to 5 items in one request.'),
        findsOneWidget,
      );
    });

    testWidgets('below five the note is not shown', (tester) async {
      await pump(tester);
      await addItem(tester);

      expect(find.byKey(const ValueKey('request-items-max')), findsNothing);
    });

    testWidgets('after removing one at the limit, adding is possible again', (
      tester,
    ) async {
      await pump(tester);
      for (var i = 0; i < 4; i++) {
        await addItem(tester);
      }

      await tapKey(tester, 'request-item-remove-4');

      expect(find.byKey(const ValueKey('request-add-item')), findsOneWidget);
    });

    testWidgets('the error names the item that is missing its name', (
      tester,
    ) async {
      await pump(tester);
      await fillValid(tester);
      await addItem(tester);
      await addItem(tester);
      await enter(tester, 'request-item-2', 'Shirt'); // item 2 left empty

      await send(tester);

      expect(errorText(tester), 'Tell us what item 2 is.');
      expect(service.attempts, 0);
    });

    testWidgets('with one item the plain message is used', (tester) async {
      await pump(tester);

      await send(tester);

      expect(errorText(tester), 'Tell us what the item is.');
    });

    testWidgets('a name made of spaces does not count', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await addItem(tester);
      await enter(tester, 'request-item-1', '    ');

      await send(tester);

      expect(errorText(tester), 'Tell us what item 2 is.');
    });

    testWidgets('adding an item clears an old error', (tester) async {
      await pump(tester);
      await send(tester);
      expect(find.byKey(const ValueKey('request-error')), findsOneWidget);

      await addItem(tester);

      expect(find.byKey(const ValueKey('request-error')), findsNothing);
    });

    testWidgets('the price does not depend on the number of items', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'request-weight', '0.9 kg');
      final one = total(tester);

      await addItem(tester);
      await addItem(tester);

      expect(total(tester), one);
      expect(one, r'$112');
    });

    testWidgets('weight, size and photos are still for the whole parcel', (
      tester,
    ) async {
      await pump(tester);

      await addItem(tester);
      await addItem(tester);

      expect(find.byKey(const ValueKey('request-weight')), findsOneWidget);
      expect(find.byKey(const ValueKey('request-dimensions')), findsOneWidget);
      expect(find.byKey(const ValueKey('request-add-photo')), findsOneWidget);
    });

    testWidgets('a failed send keeps every item', (tester) async {
      service.fail = const RequestException(RequestFailure.other);
      await pump(tester);
      await fillValid(tester);
      await addItem(tester);
      await enter(tester, 'request-item-1', 'Shirt');

      await send(tester);

      expect(find.byKey(const ValueKey('request-error')), findsOneWidget);
      expect(text(tester, 'request-item-0'), 'Apple AirPods Max');
      expect(text(tester, 'request-item-1'), 'Shirt');
    });

    testWidgets('a retry sends all the items again under the same request id', (
      tester,
    ) async {
      service.fail = const RequestException(RequestFailure.other);
      await pump(tester);
      await fillValid(tester);
      await addItem(tester);
      await enter(tester, 'request-item-1', 'Shirt');
      await send(tester);

      service.fail = null;
      await send(tester);

      expect(service.attemptIds.toSet().length, 1);
      expect(service.sent.single.draft.items.length, 2);
    });

    testWidgets('translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      await tapKey(tester, 'request-add-item');

      expect(find.text('Articles'), findsOneWidget);
      expect(find.text('2 articles'), findsOneWidget);
      expect(find.text('ARTICLE 2'), findsOneWidget);
      expect(find.text('Retirer'), findsNWidgets(2));
    });
  });

  group('category', () {
    testWidgets('three categories, Electronics selected first', (tester) async {
      await pump(tester);

      for (final t in ['Electronics', 'Apparel', 'Documents']) {
        expect(find.text(t), findsOneWidget);
      }
      Color? color(String name) =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byKey(
                                ValueKey('request-category-0-$name'),
                              ),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(color('electronics'), isNot(color('apparel')));
    });

    testWidgets('the chosen category is what is sent', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await tapKey(tester, 'request-category-0-documents');

      await send(tester);

      expect(
        service.sent.single.draft.items.single.category,
        RequestCategory.documents,
      );
      expect(
        service.sent.single.draft.items.single.category.dbValue,
        'documents',
      );
    });

    testWidgets('Electronics is the default', (tester) async {
      await pump(tester);
      await fillValid(tester);

      await send(tester);

      expect(
        service.sent.single.draft.items.single.category,
        RequestCategory.electronics,
      );
    });
  });

  group('validation', () {
    testWidgets('an empty form asks for the item first', (tester) async {
      await pump(tester);

      await send(tester);

      expect(errorText(tester), 'Tell us what the item is.');
      expect(service.attempts, 0);
    });

    testWidgets('then the recipient name', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');

      await send(tester);

      expect(errorText(tester), "Enter the recipient's full name.");
    });

    testWidgets('a one-letter name is not a name', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-recipient-name', 'J');

      await send(tester);

      expect(errorText(tester), "Enter the recipient's full name.");
    });

    testWidgets('then the phone number', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-recipient-name', 'Jane Doe');

      await send(tester);

      expect(
        errorText(tester),
        'Enter a valid phone number for the recipient.',
      );
    });

    for (final bad in ['+44 12', '+0 1234567890', '12', 'hello']) {
      testWidgets('rejects the phone "$bad"', (tester) async {
        await pump(tester);
        await enter(tester, 'request-item-0', 'Watch');
        await enter(tester, 'request-recipient-name', 'Jane Doe');
        await enter(tester, 'request-recipient-phone', bad);

        await send(tester);

        expect(
          errorText(tester),
          'Enter a valid phone number for the recipient.',
        );
        expect(service.attempts, 0);
      });
    }

    testWidgets('then the weight', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-recipient-name', 'Jane Doe');
      await enter(tester, 'request-recipient-phone', '+447700900123');

      await send(tester);

      expect(errorText(tester), 'Enter the package weight, e.g. 0.9 kg.');
    });

    for (final bad in ['0', 'abc', '2 lbs', '-1']) {
      testWidgets('rejects the weight "$bad"', (tester) async {
        await pump(tester);
        await enter(tester, 'request-item-0', 'Watch');
        await enter(tester, 'request-recipient-name', 'Jane Doe');
        await enter(tester, 'request-recipient-phone', '+447700900123');
        await enter(tester, 'request-weight', bad);

        await send(tester);

        expect(errorText(tester), 'Enter the package weight, e.g. 0.9 kg.');
      });
    }

    testWidgets('a parcel heavier than the traveler accepts is refused', (
      tester,
    ) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-weight', '3.5 kg');

      await send(tester);

      expect(errorText(tester), 'This traveler accepts up to 3.0 kg.');
      expect(service.attempts, 0);
    });

    testWidgets('exactly the limit is fine', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-weight', '3 kg');

      await send(tester);

      expect(service.sent.single.draft.weightKg, 3.0);
    });

    testWidgets('no weight limit means any sensible weight is fine', (
      tester,
    ) async {
      await pump(tester, tripOverride: sampleTrip(maxWeightKg: null));
      await fillValid(tester);
      await enter(tester, 'request-weight', '12 kg');

      await send(tester);

      expect(service.sent.single.draft.weightKg, 12.0);
    });

    testWidgets('then at least one photo', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-recipient-name', 'Jane Doe');
      await enter(tester, 'request-recipient-phone', '+447700900123');
      await enter(tester, 'request-weight', '0.5');
      await tapKey(tester, 'request-size-shoebox');

      await send(tester);

      expect(errorText(tester), 'Add at least one photo of the sealed item.');
      expect(service.attempts, 0);
    });

    testWidgets('the message goes away as soon as the user edits a field', (
      tester,
    ) async {
      await pump(tester);
      await send(tester);
      expect(errorText(tester), isNotNull);

      await enter(tester, 'request-item-0', 'W');

      expect(errorText(tester), isNull);
    });
  });

  group('package size', () {
    testWidgets('three sizes to choose from, none chosen at first', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('PACKAGE SIZE'), findsOneWidget);
      for (final t in ['Envelope / Document', 'Shoebox', 'Backpack']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('a size is required', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-recipient-name', 'Jane Doe');
      await enter(tester, 'request-recipient-phone', '+447700900123');
      await enter(tester, 'request-weight', '0.5');

      await send(tester);

      expect(errorText(tester), 'Choose the package size.');
      expect(service.attempts, 0);
    });

    testWidgets('the chosen size is what is sent', (tester) async {
      await pump(tester); // traveler accepts up to a shoebox
      await fillValid(tester);
      await tapKey(tester, 'request-size-envelope');

      await send(tester);

      expect(service.sent.single.draft.sizeClass, RequestSizeClass.envelope);
    });

    testWidgets('a parcel bigger than the traveler accepts is refused', (
      tester,
    ) async {
      await pump(tester); // shoebox limit
      await fillValid(tester);
      await tapKey(tester, 'request-size-backpack');

      await send(tester);

      expect(
        errorText(tester),
        'This package is bigger than the traveler accepts.',
      );
      expect(service.attempts, 0);
    });

    testWidgets('the traveler\'s own size is fine', (tester) async {
      await pump(tester);
      await fillValid(tester); // shoebox

      await send(tester);

      expect(service.sent.single.draft.sizeClass, RequestSizeClass.shoebox);
    });

    testWidgets('a traveler who accepts a backpack accepts everything', (
      tester,
    ) async {
      await pump(
        tester,
        tripOverride: sampleTrip(maxSize: 'Backpack size', maxWeightKg: 10),
      );
      await fillValid(tester);
      await tapKey(tester, 'request-size-backpack');

      await send(tester);

      expect(service.sent.single.draft.sizeClass, RequestSizeClass.backpack);
    });

    testWidgets('a traveler who accepts only envelopes refuses a shoebox', (
      tester,
    ) async {
      await pump(
        tester,
        tripOverride: sampleTrip(maxSize: 'Envelope / Document'),
      );
      await fillValid(tester);

      await send(tester);

      expect(
        errorText(tester),
        'This package is bigger than the traveler accepts.',
      );
    });

    testWidgets('a trip with no recognisable size limit accepts any size', (
      tester,
    ) async {
      await pump(tester, tripOverride: sampleTrip(maxSize: null));
      await fillValid(tester);
      await tapKey(tester, 'request-size-backpack');

      await send(tester);

      expect(service.sent.single.draft.sizeClass, RequestSizeClass.backpack);
    });

    testWidgets('choosing again clears the message', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await tapKey(tester, 'request-size-backpack');
      await send(tester);
      expect(errorText(tester), isNotNull);

      await tapKey(tester, 'request-size-envelope');

      expect(errorText(tester), isNull);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('es'));

      expect(find.text('TAMAÑO DEL PAQUETE'), findsOneWidget);
      expect(find.text('Caja de zapatos'), findsOneWidget);
    });
  });

  group('photos', () {
    testWidgets('start with none and an add button', (tester) async {
      await pump(tester);

      expect(find.text('No photos'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-add-photo')), findsOneWidget);
      expect(find.text('Photo must show sealed factory seal'), findsOneWidget);
    });

    testWidgets('adding opens a choice of camera or library', (tester) async {
      await pump(tester);

      await tapKey(tester, 'request-add-photo');

      expect(
        find.byKey(const ValueKey('request-photo-camera')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('request-photo-library')),
        findsOneWidget,
      );
    });

    testWidgets('the camera option takes a photo', (tester) async {
      await pump(tester);

      await addPhoto(tester, camera: true);

      expect(pickerCalls, [true]);
      expect(find.byKey(const ValueKey('request-photo-0')), findsOneWidget);
      expect(find.text('1 photo attached'), findsOneWidget);
    });

    testWidgets('the library option chooses one', (tester) async {
      await pump(tester);

      await addPhoto(tester, camera: false);

      expect(pickerCalls, [false]);
      expect(find.text('1 photo attached'), findsOneWidget);
    });

    testWidgets('the count follows the photos', (tester) async {
      await pump(tester);

      await addPhoto(tester);
      await addPhoto(tester);

      expect(find.text('2 photos attached'), findsOneWidget);
    });

    testWidgets('a photo can be removed', (tester) async {
      await pump(tester);
      await addPhoto(tester);

      await tapKey(tester, 'request-photo-remove-0');

      expect(find.byKey(const ValueKey('request-photo-0')), findsNothing);
      expect(find.text('No photos'), findsOneWidget);
    });

    testWidgets('removing the middle one keeps the others', (tester) async {
      await pump(tester);
      nextPhoto = photo(name: 'a.jpg', bytes: 10);
      await addPhoto(tester);
      nextPhoto = photo(name: 'b.jpg', bytes: 20);
      await addPhoto(tester);
      nextPhoto = photo(name: 'c.jpg', bytes: 30);
      await addPhoto(tester);

      await tapKey(tester, 'request-photo-remove-1');
      await fillValidWithoutPhoto(tester);
      await send(tester);

      expect(service.sent.single.photos.map((p) => p.name), ['a.jpg', 'c.jpg']);
    });

    testWidgets('at most three, and the add button goes away', (tester) async {
      await pump(tester);
      for (var i = 0; i < 3; i++) {
        await addPhoto(tester);
      }

      expect(find.text('3 photos attached'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-add-photo')), findsNothing);
      expect(find.byKey(const ValueKey('request-photo-3')), findsNothing);
    });

    testWidgets('cancelling the choice adds nothing', (tester) async {
      await pump(tester);

      await tapKey(tester, 'request-add-photo');
      await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
      await tester.pumpAndSettle();

      expect(pickerCalls, isEmpty);
      expect(find.text('No photos'), findsOneWidget);
    });

    testWidgets('cancelling the camera adds nothing and shows no error', (
      tester,
    ) async {
      nextPhoto = null;
      await pump(tester);

      await addPhoto(tester);

      expect(find.text('No photos'), findsOneWidget);
      expect(errorText(tester), isNull);
    });

    testWidgets('a camera problem is reported', (tester) async {
      pickerError = Exception('no camera');
      await pump(tester);

      await addPhoto(tester);

      expect(errorText(tester), 'Could not open the camera or photos.');
    });

    testWidgets('a photo over 10 MB is refused', (tester) async {
      nextPhoto = photo(bytes: 10 * 1024 * 1024 + 1);
      await pump(tester);

      await addPhoto(tester);

      expect(errorText(tester), 'That photo is too large (max 10 MB).');
      expect(find.text('No photos'), findsOneWidget);
    });

    testWidgets('a later good photo clears the error', (tester) async {
      pickerError = Exception('x');
      await pump(tester);
      await addPhoto(tester);
      expect(errorText(tester), isNotNull);

      pickerError = null;
      await addPhoto(tester);

      expect(errorText(tester), isNull);
    });
  });

  group('price', () {
    // Lagos -> London is 5,012 km; the flight is tomorrow (24 hours), so
    // cost = 5 + 61.88 + 3 * kg + 31.25, rounded up to a whole dollar, and
    // the fee is 10% of that, rounded up.
    String total(WidgetTester t) =>
        t.widget<Text>(find.byKey(const ValueKey('request-price-total'))).data!;

    testWidgets('is worked out from the distance between the two cities', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.text('Based on distance (5012 km), weight & delivery date'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows the cost, the fee and the total once a weight is entered',
      (tester) async {
        await pump(tester);

        await enter(tester, 'request-weight', '0.9 kg');

        // 100.83 -> 101; 10% of 101 = 10.10 -> 11
        expect(total(tester), r'$112');
        expect(find.text(r'$101'), findsOneWidget);
        expect(find.text(r'$11'), findsOneWidget);
        expect(find.text('Platform protection & escrow'), findsOneWidget);
      },
    );

    testWidgets('updates as the weight changes', (tester) async {
      await pump(tester);
      await enter(tester, 'request-weight', '1');
      final one = total(tester);

      await enter(tester, 'request-weight', '2');

      expect(total(tester), isNot(one));
      expect(total(tester), r'$116'); // 104.13 -> 105, + 11
    });

    testWidgets('a heavier parcel costs more, in whole dollars', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'request-weight', '1');
      expect(total(tester), r'$113'); // 101.13 -> 102, + 11

      await enter(tester, 'request-weight', '3');
      expect(total(tester), r'$119'); // 107.13 -> 108, + 11
    });

    testWidgets('before a weight is typed it asks for one', (tester) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('request-price-weight-hint')),
        findsOneWidget,
      );
      expect(
        find.text('Enter the package weight to see the final price.'),
        findsOneWidget,
      );
    });

    testWidgets('the hint goes away once there is a weight', (tester) async {
      await pump(tester);

      await enter(tester, 'request-weight', '0.9');

      expect(
        find.byKey(const ValueKey('request-price-weight-hint')),
        findsNothing,
      );
    });

    testWidgets('an invalid weight is treated as not entered yet', (
      tester,
    ) async {
      await pump(tester);

      await enter(tester, 'request-weight', 'abc');

      expect(
        find.byKey(const ValueKey('request-price-weight-hint')),
        findsOneWidget,
      );
    });

    testWidgets('the closer the flight, the more it costs', (tester) async {
      await pump(tester);
      await enter(tester, 'request-weight', '1');
      final tomorrow = total(tester);

      // Same trip, but the flight is a month away.
      await pump(
        tester,
        tripOverride: sampleTrip(
          tripId: 'far',
          departureDate: DateTime(2030, 7, 21),
          maxWeightKg: 3,
        ),
      );
      await enter(tester, 'request-weight', '1');

      final far = double.parse(total(tester).substring(1));
      expect(far, lessThan(double.parse(tomorrow.substring(1))));
    });

    testWidgets('a flight today is priced like tomorrow, not as free', (
      tester,
    ) async {
      await pump(
        tester,
        tripOverride: sampleTrip(departureDate: DateTime(2030, 6, 21)),
      );
      await enter(tester, 'request-weight', '1');
      final today = total(tester);

      await pump(
        tester,
        tripOverride: sampleTrip(departureDate: DateTime(2030, 6, 22)),
      );
      await enter(tester, 'request-weight', '1');

      expect(today, total(tester));
    });

    testWidgets('a different route costs a different amount', (tester) async {
      await pump(tester);
      await enter(tester, 'request-weight', '1');
      final lagosLondon = total(tester);

      await pump(
        tester,
        tripOverride: sampleTrip(
          departureCity: 'Accra',
          departureCountry: 'GH',
          arrivalCity: 'Paris',
          arrivalCountry: 'FR',
          departureDate: DateTime(2030, 6, 22),
        ),
      );
      await enter(tester, 'request-weight', '1');

      expect(total(tester), isNot(lagosLondon));
      expect(find.textContaining('4815 km'), findsOneWidget);
    });

    testWidgets('the send button carries the total', (tester) async {
      await pump(tester);
      await enter(tester, 'request-weight', '0.9');

      expect(find.text(r'Send Request · $112'), findsOneWidget);
    });

    testWidgets('says nothing is charged yet', (tester) async {
      await pump(tester);

      expect(find.textContaining('Nothing is charged now'), findsOneWidget);
    });

    testWidgets('does not use the traveler\'s own price any more', (
      tester,
    ) async {
      await pump(
        tester,
        tripOverride: sampleTrip(
          price: 9999,
          departureDate: DateTime(2030, 6, 22),
        ),
      );
      await enter(tester, 'request-weight', '0.9');

      expect(total(tester), r'$112');
      expect(find.textContaining('9999'), findsNothing);
      expect(find.text("Traveler's price"), findsNothing);
    });

    testWidgets('no exchange rate is asked for when the currency is dollars', (
      tester,
    ) async {
      await pump(tester);

      expect(rates.calls, 0);
      expect(find.byKey(const ValueKey('request-price-rate')), findsNothing);
    });
  });

  group('price in the user\'s currency', () {
    String total(WidgetTester t) =>
        t.widget<Text>(find.byKey(const ValueKey('request-price-total'))).data!;

    testWidgets('euros', (tester) async {
      await pump(tester, currency: AppCurrency.eur);
      await enter(tester, 'request-weight', '0.9 kg');

      // 101 * 0.892438 = 90.14 -> 91 ; 11 * 0.892438 = 9.82 -> 10
      expect(find.text('€91'), findsOneWidget);
      expect(find.text('€10'), findsOneWidget);
      // Converted amounts are an estimate until the traveler accepts.
      expect(total(tester), '≈ €101');
    });

    testWidgets('pounds', (tester) async {
      await pump(tester, currency: AppCurrency.gbp);
      await enter(tester, 'request-weight', '0.9 kg');

      // 101 * 0.755923 = 76.35 -> 77 ; 11 * 0.755923 = 8.32 -> 9
      expect(total(tester), '≈ £86');
    });

    testWidgets('says a converted price is an estimate until accepted', (
      tester,
    ) async {
      await pump(tester, currency: AppCurrency.eur);
      await enter(tester, 'request-weight', '0.9 kg');

      expect(
        find.text(
          "This is an estimate in EUR at today's rate. The price is fixed when the traveler accepts.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('dollars are exact: no estimate mark or note', (tester) async {
      await pump(tester);
      await enter(tester, 'request-weight', '0.9 kg');

      expect(total(tester), r'$112');
      expect(
        find.byKey(const ValueKey('request-price-estimate-note')),
        findsNothing,
      );
    });

    testWidgets('the CFA franc, without cents', (tester) async {
      await pump(tester, currency: AppCurrency.xof);
      await enter(tester, 'request-weight', '0.9 kg');

      // 101 * 585.399478 = 59,125.35 -> 59,126 ; 11 * 585.399478 =
      // 6,439.39 -> 6,440
      expect(find.text('XOF 59,126'), findsOneWidget);
      expect(find.text('XOF 6,440'), findsOneWidget);
      expect(total(tester), '≈ XOF 65,566');
    });

    testWidgets('shows the rate used and when it was updated', (tester) async {
      await pump(tester, currency: AppCurrency.xof);

      expect(find.text('1 USD = 585.40 XOF · updated Jun 21'), findsOneWidget);
    });

    testWidgets('small rates keep four decimals', (tester) async {
      await pump(tester, currency: AppCurrency.eur);

      expect(find.text('1 USD = 0.8924 EUR · updated Jun 21'), findsOneWidget);
    });

    testWidgets('credits the rate provider', (tester) async {
      await pump(tester, currency: AppCurrency.eur);

      expect(find.text('Exchange rates by Exchange Rate API'), findsOneWidget);
    });

    testWidgets('asks for the rates once', (tester) async {
      await pump(tester, currency: AppCurrency.eur);

      expect(rates.calls, 1);
    });

    testWidgets('the send button shows the converted total', (tester) async {
      await pump(tester, currency: AppCurrency.gbp);
      await enter(tester, 'request-weight', '0.9 kg');

      expect(find.text('Send Request · ≈ £86'), findsOneWidget);
    });

    testWidgets('but what is sent is always the dollar total', (tester) async {
      await pump(tester, currency: AppCurrency.xof);
      await fillValid(tester);

      await send(tester);

      expect(service.sent.single.draft.expectedTotal, 112);
    });

    testWidgets('when rates are unavailable it shows dollars and says why', (
      tester,
    ) async {
      rates.result = null;
      await pump(tester, currency: AppCurrency.eur);
      await enter(tester, 'request-weight', '0.9 kg');

      expect(total(tester), r'$112');
      expect(
        find.byKey(const ValueKey('request-price-rate-missing')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Exchange rate unavailable, so prices are shown in US dollars.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('request-price-rate')), findsNothing);
    });

    testWidgets('a currency missing from the rates falls back to dollars', (
      tester,
    ) async {
      rates.result = ExchangeRates(
        perUsd: const {'USD': 1, 'GBP': 0.75},
        updatedAt: DateTime.utc(2030, 6, 21),
      );
      await pump(tester, currency: AppCurrency.eur);
      await enter(tester, 'request-weight', '0.9 kg');

      expect(total(tester), r'$112');
    });

    testWidgets('the CFA franc works when only XAF is listed', (tester) async {
      rates.result = ExchangeRates(
        perUsd: const {'XAF': 600},
        updatedAt: DateTime.utc(2030, 6, 21),
      );
      await pump(tester, currency: AppCurrency.xof);
      await enter(tester, 'request-weight', '0.9 kg');

      expect(find.byKey(const ValueKey('request-price-rate')), findsOneWidget);
      expect(total(tester), startsWith('≈ XOF '));
    });

    testWidgets('shows the price loading until the rates arrive', (
      tester,
    ) async {
      rates.gate = Completer<void>();
      await pump(tester, currency: AppCurrency.eur, settle: false);

      expect(
        find.byKey(const ValueKey('request-price-loading')),
        findsOneWidget,
      );
      expect(find.text('Calculating the price…'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('request-send')),
      );
      expect(button.onPressed, isNull);

      rates.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('request-price-loading')), findsNothing);
      expect(find.byKey(const ValueKey('request-price-total')), findsOneWidget);
    });

    testWidgets('translated', (tester) async {
      await pump(tester, currency: AppCurrency.eur, locale: const Locale('es'));

      expect(
        find.text(
          'Esto es una estimación en EUR al tipo de cambio de hoy. El precio se fija cuando el viajero acepta.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Según la distancia (5012 km)'),
        findsOneWidget,
      );
      expect(
        find.text('1 USD = 0.8924 EUR · actualizado 21 jun'),
        findsOneWidget,
      );
    });
  });

  group('when the price cannot be worked out', () {
    testWidgets('a failed city lookup says so, with a Retry', (tester) async {
      cities.fail = true;
      await pump(tester);

      expect(find.byKey(const ValueKey('request-quote-error')), findsOneWidget);
      expect(
        find.text(
          'Could not calculate the price. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('request-price-total')), findsNothing);
    });

    testWidgets('sending is blocked until there is a price', (tester) async {
      cities.fail = true;
      await pump(tester);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('request-send')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Send Request'), findsOneWidget);
    });

    testWidgets('Retry works once the connection is back', (tester) async {
      cities.fail = true;
      await pump(tester);

      cities.fail = false;
      await tapKey(tester, 'request-quote-retry');

      expect(find.byKey(const ValueKey('request-quote-error')), findsNothing);
      expect(find.byKey(const ValueKey('request-price-total')), findsOneWidget);
    });

    testWidgets('a city that is not in the database is the same problem', (
      tester,
    ) async {
      cities.cities = {};
      await pump(tester);

      expect(find.byKey(const ValueKey('request-quote-error')), findsOneWidget);
    });

    testWidgets('only one of the two cities known is not enough', (
      tester,
    ) async {
      cities.cities = {'NG|Lagos': const CityCoordinates(6.5, 3.4)};
      await pump(tester);

      expect(find.byKey(const ValueKey('request-quote-error')), findsOneWidget);
    });

    testWidgets('shows the price loading while the cities are looked up', (
      tester,
    ) async {
      cities.gate = Completer<void>();
      await pump(tester, settle: false);

      expect(
        find.byKey(const ValueKey('request-price-loading')),
        findsOneWidget,
      );

      cities.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('request-price-total')), findsOneWidget);
    });

    testWidgets('the form can still be filled in meanwhile', (tester) async {
      cities.fail = true;
      await pump(tester);

      await enter(tester, 'request-item-0', 'Watch');

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('request-item-0')))
            .controller!
            .text,
        'Watch',
      );
    });

    testWidgets('after a retry the form can be sent', (tester) async {
      cities.fail = true;
      await pump(tester);
      cities.fail = false;
      await tapKey(tester, 'request-quote-retry');

      await fillValid(tester);
      await send(tester);

      expect(service.sent.length, 1);
    });
  });

  group('sending', () {
    testWidgets('sends everything entered, for this trip', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', '  Apple AirPods Max  ');
      await enter(tester, 'request-description-0', 'Brand new, sealed');
      await enter(tester, 'request-recipient-name', '  Jane Doe ');
      await enter(tester, 'request-recipient-phone', '+44 (7700) 900-123');
      await enter(tester, 'request-weight', '900 g');
      await enter(tester, 'request-dimensions', '24 × 24 × 8 cm');
      await tapKey(tester, 'request-size-shoebox');
      await addPhoto(tester);

      await send(tester);

      final d = service.sent.single.draft;
      expect(d.tripId, 'trip-77');
      expect(d.items.single.name.trim(), 'Apple AirPods Max');
      expect(d.items.single.description, 'Brand new, sealed');
      expect(d.sizeClass, RequestSizeClass.shoebox);
      expect(d.expectedTotal, 112); // what the sender was shown, in USD
      expect(d.weightKg, 0.9);
      expect(d.itemSize, '24 × 24 × 8 cm');
      expect(d.recipientName.trim(), 'Jane Doe');
      expect(d.recipientPhone, '+447700900123'); // cleaned up
      expect(service.sent.single.photos.length, 1);
    });

    testWidgets('dimensions and description are optional', (tester) async {
      await pump(tester);
      await fillValid(tester);

      await send(tester);

      expect(service.sent.single.draft.itemSize, isNull);
      expect(service.sent.single.draft.items.single.description, isEmpty);
    });

    testWidgets('on success it confirms and goes back to the start', (
      tester,
    ) async {
      await pump(tester);
      await fillValid(tester);

      await send(tester);

      expect(popped, isTrue);
      expect(find.byType(DeliveryRequestScreen), findsNothing);
      expect(
        find.text('Request sent. The traveler will review it.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a busy state and ignores a second tap', (tester) async {
      service.gate = Completer<void>();
      await pump(tester);
      await fillValid(tester);

      await tester.tap(find.byKey(const ValueKey('request-send')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('request-send')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('request-send')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(service.attempts, 1);

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(service.sent.length, 1);
    });

    testWidgets('the request id is made once for this screen', (tester) async {
      await pump(tester);
      await fillValid(tester);

      await send(tester);

      expect(service.sent.single.id, 'req-1');
    });
  });

  group('when sending fails', () {
    testWidgets('stays on the form with a message, nothing is lost', (
      tester,
    ) async {
      service.fail = const RequestException(RequestFailure.other);
      await pump(tester);
      await fillValid(tester);

      await send(tester);

      expect(
        errorText(tester),
        'Could not send your request. Please try again.',
      );
      expect(popped, isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('request-item-0')))
            .controller!
            .text,
        'Apple AirPods Max',
      );
      expect(find.byKey(const ValueKey('request-photo-0')), findsOneWidget);
    });

    testWidgets('a retry after a failure reuses the SAME request id', (
      tester,
    ) async {
      service.fail = const RequestException(RequestFailure.other);
      await pump(tester);
      await fillValid(tester);
      await send(tester);

      service.fail = null;
      await send(tester);

      expect(service.sent.single.id, 'req-1');
      expect(idCounter, 1); // no second id was ever created
      expect(popped, isTrue);
    });

    for (final c in {
      RequestFailure.notSignedIn: 'Your session expired. Please sign in again.',
      RequestFailure.tripUnavailable: 'This trip is no longer available.',
      RequestFailure.ownTrip: "You can't send a parcel with your own trip.",
      RequestFailure.duplicate:
          'You already have an open request on this trip.',
      RequestFailure.destinationLimit:
          'You already have 5 open requests going to London. You can send another once one of them is delivered, declined or expires.',
      RequestFailure.invalid:
          'Some details were rejected. Please check the form.',
      RequestFailure.priceChanged:
          'The price has changed since you opened this request. Go back and open it again to see the new price.',
      RequestFailure.sizeTooBig:
          'This package is bigger than the traveler accepts.',
      RequestFailure.weightTooHeavy: 'This traveler accepts up to 3.0 kg.',
    }.entries) {
      testWidgets('${c.key.name}: "${c.value}"', (tester) async {
        service.fail = RequestException(c.key);
        await pump(tester);
        await fillValid(tester);

        await send(tester);

        expect(errorText(tester), c.value);
        expect(popped, isFalse);
      });
    }

    testWidgets('an unexpected error is a friendly message, not a crash', (
      tester,
    ) async {
      await pump(tester);
      await fillValid(tester);
      service.fail = null;
      // Anything that is not a RequestException:
      final broken = _ThrowingService();
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(900, 3600);
      await tester.pumpWidget(
        appWrapper(
          DeliveryRequestScreen(
            trip: trip,
            service: broken,
            photoPicker: fakePicker,
            cityService: cities,
            exchangeRates: rates,
            now: () => fixedNow,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fillValid(tester);

      await send(tester);

      expect(
        errorText(tester),
        'Could not send your request. Please try again.',
      );
    });

    testWidgets('the button works again after a failure', (tester) async {
      service.fail = const RequestException(RequestFailure.other);
      await pump(tester);
      await fillValid(tester);
      await send(tester);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('request-send')),
      );
      expect(button.onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('item values', () {
    testWidgets('each item needs a value', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-item-value-0', '');
      await send(tester);

      expect(errorText(tester), 'Enter what the item is worth.');
      expect(service.sent, isEmpty);
    });

    for (final bad in ['abc', '12.345', '2000000']) {
      testWidgets('rejects the value "$bad"', (tester) async {
        await pump(tester);
        await fillValid(tester);
        await enter(tester, 'request-item-value-0', bad);
        await send(tester);

        expect(errorText(tester), 'Enter what the item is worth.');
        expect(service.sent, isEmpty);
      });
    }

    testWidgets('the value is sent with the item', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-item-value-0', '450.50');
      await send(tester);

      expect(service.sent.single.draft.items.single.value, 450.5);
    });

    testWidgets('the declared total adds up every item', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-item-value-0', '100');
      await tapKey(tester, 'request-add-item');
      await enter(tester, 'request-item-1', 'Shirt');
      await enter(tester, 'request-item-value-1', '250');

      expect(find.text(r'Declared value: $350'), findsOneWidget);
    });

    testWidgets('a receipt can be attached, removed and sent', (tester) async {
      await pump(tester);
      await fillValid(tester);
      nextPhoto = photo(name: 'receipt.jpg');
      await tapKey(tester, 'request-item-receipt-add-0');
      await tapKey(tester, 'request-photo-library');

      expect(find.byKey(const ValueKey('request-item-receipt-0')), findsOne);
      await tapKey(tester, 'request-item-receipt-remove-0');
      expect(
        find.byKey(const ValueKey('request-item-receipt-0')),
        findsNothing,
      );

      await tapKey(tester, 'request-item-receipt-add-0');
      await tapKey(tester, 'request-photo-library');
      await send(tester);

      expect(service.receipts.keys, [0]);
      expect(service.receipts[0]!.name, 'receipt.jpg');
    });

    testWidgets('no receipt is fine', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await send(tester);

      expect(service.sent, hasLength(1));
      expect(service.receipts, isEmpty);
    });
  });

  group('translations', () {
    testWidgets('Spanish', (tester) async {
      await pump(tester, locale: const Locale('es'));

      expect(find.text('Datos del destinatario'), findsOneWidget);
      expect(find.text('Tamaño y peso'), findsOneWidget);
      expect(find.text('Sin fotos'), findsOneWidget);
      expect(find.textContaining('Enviar solicitud'), findsOneWidget);
      expect(find.text('Máx. 3.0 kg'), findsOneWidget);
    });

    testWidgets('French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Informations du destinataire'), findsOneWidget);
      expect(find.text('Taille et poids'), findsOneWidget);
      expect(find.text('Aucune photo'), findsOneWidget);
      expect(find.text('Max 3.0 kg'), findsOneWidget);
    });

    testWidgets('messages are translated', (tester) async {
      await pump(tester, locale: const Locale('es'));

      await send(tester);

      expect(errorText(tester), 'Indica qué es el artículo.');
    });
  });

  group('recipient phone', () {
    Future<void> fillRest(WidgetTester tester) async {
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-recipient-name', 'Jane Doe');
    }

    Finder prefix() => find.byKey(const ValueKey('request-recipient-country'));

    testWidgets("starts with the destination country's code", (tester) async {
      await pump(tester); // Lagos -> London

      expect(
        find.descendant(of: prefix(), matching: find.text('+44')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: prefix(), matching: find.text('🇬🇧')),
        findsOneWidget,
      );
    });

    testWidgets('follows the trip: a trip to France gets +33', (tester) async {
      await pump(
        tester,
        tripOverride: sampleTrip(arrivalCity: 'Paris', arrivalCountry: 'FR'),
      );

      expect(
        find.descendant(of: prefix(), matching: find.text('+33')),
        findsOneWidget,
      );
    });

    testWidgets('a local number gets the code, without its leading 0', (
      tester,
    ) async {
      await pump(tester);
      await fillRest(tester);
      await enter(tester, 'request-recipient-phone', '07700 900123');

      expect(errorText(tester), isNull);
    });
  });
}

Future<void> fillValidWithoutPhoto(WidgetTester tester) async {
  Future<void> enter(String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  await enter('request-item-0', 'Apple AirPods Max');
  await enter('request-item-value-0', '100');
  await enter('request-recipient-name', 'Jane Doe');
  await enter('request-recipient-phone', '+44 7700 900123');
  await enter('request-weight', '0.9 kg');
  await tester.tap(find.byKey(const ValueKey('request-size-shoebox')));
  await tester.pump();
}

class _ThrowingService extends FakeRequestService {
  @override
  Future<String> send(
    String requestId,
    RequestDraft draft,
    List<PickedReceipt> photos, {
    Map<int, PickedReceipt> receipts = const {},
  }) async => throw StateError('boom');
}
