import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/screens/delivery_request_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/screen_cache.dart';
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
    List<TravelerTrip> moreTrips = const [],
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
                      moreTrips: moreTrips,
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
    await enter(tester, 'request-weight', '0.9 kg');
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
        'WHAT IS THE ITEM?',
        'ITEM CATEGORY',
        'ITEM DESCRIPTION',
        'Package Weight',
        'Item Photos',
        'Nata fee',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // No sealed-box requirement any more.
      expect(find.text('Item Requirement'), findsNothing);
      // No recipient any more (20240200).
      expect(find.text('Recipient Details'), findsNothing);
      // A single page: no step counter.
      expect(find.textContaining('Step 1'), findsNothing);
    });

    testWidgets('asks for no value, receipt, dimensions or size', (
      tester,
    ) async {
      await pump(tester);

      for (final k in [
        'request-item-value-0',
        'request-item-receipt-add-0',
        'request-dimensions',
        'request-size-shoebox',
      ]) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      for (final t in [
        'ESTIMATED VALUE *',
        'PACKAGE DIMENSIONS',
        'PACKAGE SIZE',
        'Size and Weight',
      ]) {
        expect(find.text(t), findsNothing, reason: t);
      }
    });

    testWidgets('starts empty: no made-up AirPods', (tester) async {
      await pump(tester);

      for (final k in [
        'request-item-0',
        'request-description-0',
        'request-weight',
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
        find.text('e.g. Sony Headphones, Cosmetics, etc.'),
        findsOneWidget,
      );
      expect(
        find.text('Provide details about the item and packaging...'),
        findsOneWidget,
      );
    });

    testWidgets('shows the traveler\'s weight limit, and no size limit', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Traveler limit: 3.0 kg'), findsOneWidget);
      expect(find.textContaining('Shoebox'), findsNothing);
    });

    testWidgets('limits show a dash when the traveler set none', (
      tester,
    ) async {
      await pump(
        tester,
        tripOverride: sampleTrip(maxWeightKg: null, maxSize: null),
      );

      expect(find.text('Traveler limit: —'), findsOneWidget);
    });

    testWidgets('back leaves without sending', (tester) async {
      await pump(tester);

      await tapKey(tester, 'request-back');

      expect(popped, isTrue);
      expect(service.sent, isEmpty);
    });
  });

  group('coming back to the form', () {
    String text(WidgetTester t, String key) =>
        t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

    Future<void> leaveAndReopen(WidgetTester tester) async {
      await tapKey(tester, 'request-back');
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('keeps what was entered', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-description-0', 'In its box');
      await tapKey(tester, 'request-category-0-apparel');
      await tapKey(tester, 'request-add-item');
      await enter(tester, 'request-item-1', 'Shirt');
      await enter(tester, 'request-weight', '1.5');
      await addPhoto(tester);

      await leaveAndReopen(tester);

      expect(text(tester, 'request-item-0'), 'Watch');
      expect(text(tester, 'request-description-0'), 'In its box');
      expect(text(tester, 'request-item-1'), 'Shirt');
      expect(text(tester, 'request-weight'), '1.5');
      expect(find.byKey(const ValueKey('request-photo-0')), findsOneWidget);

      await send(tester);

      final d = service.sent.single.draft;
      expect(d.items.map((i) => i.name), ['Watch', 'Shirt']);
      expect(d.items.first.category, RequestCategory.apparel);
      expect(service.sent.single.photos, hasLength(1));
    });

    testWidgets('a sent request starts the next form empty', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await send(tester);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(text(tester, 'request-item-0'), isEmpty);
      expect(text(tester, 'request-weight'), isEmpty);
      expect(find.byKey(const ValueKey('request-photo-0')), findsNothing);
    });

    testWidgets('is forgotten when signing out', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');
      await tapKey(tester, 'request-back');

      ScreenCache.clear(); // what signing out does
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(text(tester, 'request-item-0'), isEmpty);
    });
  });

  group('several items', () {
    String text(WidgetTester t, String key) =>
        t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

    String fee(WidgetTester t) => t
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('request-fee-0')),
            matching: find.text(r'$4.99'),
          ),
        )
        .data!;

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

    testWidgets('the fee does not depend on the number of items', (
      tester,
    ) async {
      await pump(tester);
      final one = fee(tester);

      await addItem(tester);
      await addItem(tester);

      expect(fee(tester), one);
      expect(one, r'$4.99');
    });

    testWidgets('weight and photos are still for the whole parcel', (
      tester,
    ) async {
      await pump(tester);

      await addItem(tester);
      await addItem(tester);

      expect(find.byKey(const ValueKey('request-weight')), findsOneWidget);
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

    testWidgets('then the weight', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Watch');

      await send(tester);

      expect(errorText(tester), 'Enter the package weight, e.g. 0.9 kg.');
    });

    for (final bad in ['0', 'abc', '2 lbs', '-1']) {
      testWidgets('rejects the weight "$bad"', (tester) async {
        await pump(tester);
        await enter(tester, 'request-item-0', 'Watch');
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
      await enter(tester, 'request-weight', '0.5');

      await send(tester);

      expect(errorText(tester), 'Add at least one photo of the item.');
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

  group('photos', () {
    testWidgets('start with none and an add button', (tester) async {
      await pump(tester);

      expect(find.text('No photos'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-add-photo')), findsOneWidget);
      expect(find.text('Photo must show the item clearly'), findsOneWidget);
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

  group('sending', () {
    testWidgets('sends everything entered, for this trip', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', '  Apple AirPods Max  ');
      await enter(tester, 'request-description-0', 'Brand new, sealed');
      await enter(tester, 'request-weight', '900 g');
      await addPhoto(tester);

      await send(tester);

      final d = service.sent.single.draft;
      expect(d.tripIds, ['trip-77']);
      expect(d.items.single.name.trim(), 'Apple AirPods Max');
      expect(d.items.single.description, 'Brand new, sealed');
      expect(d.sizeClass, isNull); // no size asked any more (20240204)
      expect(d.items.single.value, isNull);
      expect(d.expectedTotal, isNull); // a flat fee: nothing to re-check
      expect(d.weightKg, 0.9);
      expect(d.itemSize, isNull);
      expect(d.recipientName, isEmpty); // no recipient any more
      expect(d.recipientPhone, isEmpty);
      expect(service.sent.single.photos.length, 1);
    });

    testWidgets('the description is optional', (tester) async {
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

  group('contact details', () {
    const note =
        'No phone numbers, emails or contact details here. Once the traveler '
        'accepts, you can chat in Nata.';

    testWidgets('a number in the item name shows a note under it', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Shoes, call 06 123 45 67');

      expect(
        find.byKey(const ValueKey('request-item-0-contact')),
        findsOneWidget,
      );
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('the note goes once the number is removed', (tester) async {
      await pump(tester);
      await enter(tester, 'request-item-0', 'Shoes, whatsapp me');
      await enter(tester, 'request-item-0', 'Shoes');

      expect(find.text(note), findsNothing);
    });

    testWidgets('contact details in the notes stop the request', (
      tester,
    ) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-description-0', 'jane.doe@gmail.com');

      await send(tester);

      expect(
        find.byKey(const ValueKey('request-description-0-contact')),
        findsOneWidget,
      );
      expect(errorText(tester), note);
      expect(service.attempts, 0);
    });

    testWidgets('ordinary numbers are fine', (tester) async {
      await pump(tester);
      await fillValid(tester);
      await enter(tester, 'request-description-0', 'Size 42, 2 pairs');

      await send(tester);

      expect(find.text(note), findsNothing);
      expect(service.sent.length, 1);
    });
  });

  group('Nata fee', () {
    testWidgets('shows the fee for the traveler, and when it is paid', (
      tester,
    ) async {
      service.fees = {
        'trip-77': const FlatFee(amount: 2.99, currency: 'USD', isLocal: true),
      };
      await pump(tester);

      expect(find.text('Nata fee'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('request-fee-0')),
          matching: find.text(r'$2.99'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Local'), findsOneWidget);
      expect(
        find.textContaining('This flat fee connects you with the traveler'),
        findsOneWidget,
      );
      // No distance price or estimate any more.
      expect(find.text('Calculated Item Price'), findsNothing);
      expect(service.feeCalls, 1);
    });

    testWidgets('euros and pounds keep their cents', (tester) async {
      service.fees = {
        'trip-77': const FlatFee(amount: 3.99, currency: 'EUR', isLocal: false),
      };
      await pump(tester);

      expect(find.text('€3.99'), findsOneWidget);
      expect(find.textContaining('International'), findsOneWidget);
    });

    testWidgets('no single total for one traveler', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('request-fee-total')), findsNothing);
    });

    testWidgets('a failed quote can be retried, and sending waits', (
      tester,
    ) async {
      service.failFees = true;
      await pump(tester);

      expect(find.byKey(const ValueKey('request-fee-error')), findsOneWidget);
      await fillValid(tester);
      await send(tester);
      expect(service.attempts, 0);

      service.failFees = false;
      await tapKey(tester, 'request-fee-retry');

      expect(find.byKey(const ValueKey('request-fee-0')), findsOneWidget);
      await send(tester);
      expect(service.sent, hasLength(1));
    });

    testWidgets('translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Frais Nata'), findsOneWidget);
    });
  });

  group('several travelers', () {
    late TravelerTrip second;

    setUp(() {
      second = sampleTrip(
        tripId: 'trip-88',
        firstName: 'Kofi',
        lastName: 'Mensah',
        departureCity: 'Paris',
        arrivalCity: 'London',
        departureDate: DateTime(2030, 6, 25),
        maxWeightKg: 2,
        maxSize: 'Envelope',
      );
    });

    Future<void> pumpBoth(WidgetTester tester) =>
        pump(tester, moreTrips: [second]);

    testWidgets('lists each traveler with their fee, and the total', (
      tester,
    ) async {
      service.fees = {
        'trip-77': const FlatFee(amount: 4.99, currency: 'USD', isLocal: false),
        'trip-88': const FlatFee(amount: 2.99, currency: 'USD', isLocal: true),
      };
      await pumpBoth(tester);

      expect(find.text('Amara Kalu'), findsWidgets);
      expect(find.text('Kofi Mensah'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('request-fee-total')))
            .data,
        r'$7.98',
      );
      expect(find.text('If they all accept'), findsOneWidget);
      expect(find.text('Send to 2 travelers'), findsOneWidget);
    });

    testWidgets('the smallest limits apply to the parcel', (tester) async {
      await pumpBoth(tester);

      expect(find.text('Traveler limit: 2.0 kg'), findsOneWidget);

      await enter(tester, 'request-item-0', 'Watch');
      await enter(tester, 'request-weight', '2.5');
      await addPhoto(tester);
      await send(tester);

      expect(errorText(tester), contains('2.0 kg'));
      expect(service.attempts, 0);
    });

    testWidgets('one send goes to every trip', (tester) async {
      await pumpBoth(tester);
      await enter(tester, 'request-item-0', 'Passport');
      await enter(tester, 'request-weight', '0.2');
      await addPhoto(tester);

      await send(tester);

      expect(service.sent.single.draft.tripIds, ['trip-77', 'trip-88']);
    });

    testWidgets('different cities are refused with a clear message', (
      tester,
    ) async {
      service.fail = const RequestException(
        RequestFailure.differentDestinations,
      );
      await pumpBoth(tester);
      await enter(tester, 'request-item-0', 'Passport');
      await enter(tester, 'request-weight', '0.2');
      await addPhoto(tester);

      await send(tester);

      expect(errorText(tester), 'Pick travelers going to the same city.');
    });
  });

  group('translations', () {
    testWidgets('Spanish', (tester) async {
      await pump(tester, locale: const Locale('es'));

      expect(find.text('Tarifa de Nata'), findsOneWidget);
      expect(find.text('Peso del paquete'), findsOneWidget);
      expect(find.text('Sin fotos'), findsOneWidget);
      expect(find.textContaining('Enviar solicitud'), findsOneWidget);
      expect(find.text('Máx. 3.0 kg'), findsOneWidget);
    });

    testWidgets('French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Frais Nata'), findsOneWidget);
      expect(find.text('Poids du colis'), findsOneWidget);
      expect(find.text('Aucune photo'), findsOneWidget);
      expect(find.text('Max 3.0 kg'), findsOneWidget);
    });

    testWidgets('messages are translated', (tester) async {
      await pump(tester, locale: const Locale('es'));

      await send(tester);

      expect(errorText(tester), 'Indica qué es el artículo.');
    });
  });
}

Future<void> fillValidWithoutPhoto(WidgetTester tester) async {
  Future<void> enter(String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  await enter('request-item-0', 'Apple AirPods Max');
  await enter('request-weight', '0.9 kg');
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
