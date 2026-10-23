import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:carrywise_app/services/delivery_pricing.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/trip_service.dart' show PickedReceipt;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockStorage extends Mock implements SupabaseStorageClient {}

class MockFileApi extends Mock implements StorageFileApi {}

class MockFunctions extends Mock implements FunctionsClient {}

class FakeFileOptions extends Fake implements FileOptions {}

class FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeRpc({this.error, this.value});
  final Object? error;
  final Object? value;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    final f = error != null
        ? Future<dynamic>.error(error!)
        : Future<dynamic>.value(value);
    return f.then(onValue, onError: onError);
  }
}

PickedReceipt photo(String ext, {int n = 3}) =>
    PickedReceipt(bytes: Uint8List(n), name: 'p.$ext', extension: ext);

RequestDraft draft({
  String name = 'Apple AirPods Max',
  RequestCategory category = RequestCategory.electronics,
  String description = 'Brand new, sealed',
  String dims = '24 × 24 × 8 cm',
  List<RequestItem>? items,
}) => RequestDraft(
  tripId: 'trip-1',
  items:
      items ??
      [RequestItem(name: name, category: category, description: description)],
  weightKg: 0.9,
  dimensions: dims,
  sizeClass: RequestSizeClass.shoebox,
  recipientName: 'Jane Doe',
  recipientPhone: '+447700900123',
  expectedTotal: 110.75,
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(FakeFileOptions());
  });

  group('RequestPricing', () {
    // $100.00 cost + $10.00 fee = $110.00
    RequestPricing p({
      String currency = 'USD',
      double rate = 1,
      double cost = 100,
      double fee = 10,
    }) => RequestPricing(
      costUsd: cost,
      feeUsd: fee,
      currency: currency,
      rate: rate,
    );

    test('in dollars nothing is converted', () {
      final x = p();

      expect(x.totalUsd, 110);
      expect(x.cost, 100);
      expect(x.fee, 10);
      expect(x.total, 110);
      expect(x.totalText, r'$110');
      expect(x.costText, r'$100');
      expect(x.feeText, r'$10');
    });

    test('euros: each line is converted and rounded up', () {
      final x = p(currency: 'EUR', rate: 0.892438);

      expect(x.cost, 90); // 89.24
      expect(x.fee, 9); // 8.92
      expect(x.total, 99);
      expect(x.costText, '€90');
      expect(x.feeText, '€9');
    });

    test('pounds', () {
      final x = p(currency: 'GBP', rate: 0.755923);

      expect(x.cost, 76); // 75.59
      expect(x.fee, 8); // 7.56
      expect(x.totalText, '£84');
    });

    test('the CFA franc has no cents', () {
      final x = p(currency: 'XOF', rate: 585.399478);

      expect(x.cost, 58540);
      expect(x.fee, 5854);
      expect(x.costText, 'XOF 58,540');
      expect(x.totalText, 'XOF 64,394');
    });

    test('XAF is treated the same way', () {
      expect(p(currency: 'XAF', rate: 585.399478).totalText, 'XAF 64,394');
    });

    test('the converted lines always add up to the converted total', () {
      for (final rate in [0.892438, 0.755923, 585.399478, 1.0, 1.2345]) {
        for (final cost in [20.63, 36.25, 100.68, 313.16]) {
          final x = RequestPricing(
            costUsd: cost,
            feeUsd: (cost * 10).round() / 100,
            currency: 'EUR',
            rate: rate,
          );
          expect(x.total, x.cost + x.fee, reason: 'rate $rate cost $cost');
        }
      }
    });

    test('what is stored is always the dollar total, whatever is shown', () {
      expect(p(currency: 'EUR', rate: 0.9).totalUsd, 110);
      expect(p(currency: 'XOF', rate: 585).totalUsd, 110);
    });

    test('large amounts get thousands separators', () {
      expect(
        p(currency: 'USD', cost: 1234.5, fee: 123.45).totalText,
        r'$1,359', // 1,235 + 124
      );
    });

    test('an unlisted currency shows its code', () {
      expect(p(currency: 'JPY', rate: 150).totalText, 'JPY 16,500');
    });

    test('every currency shows whole amounts, never rounded down', () {
      for (final c in ['USD', 'EUR', 'GBP', 'XOF', 'JPY']) {
        for (final rate in [0.755923, 0.892438, 1.0, 1.2345, 585.399478]) {
          final x = p(currency: c, rate: rate, cost: 37, fee: 4);
          for (final (shown, usd) in [(x.cost, 37.0), (x.fee, 4.0)]) {
            expect(shown, shown.roundToDouble(), reason: '$c $rate');
            expect(shown, greaterThanOrEqualTo(usd * rate - 1e-9));
            expect(shown - usd * rate, lessThan(1));
          }
          expect(x.totalText, isNot(contains('.')), reason: '$c $rate');
        }
      }
    });

    test('an amount that converts to a whole number is not bumped up', () {
      expect(p(currency: 'EUR', rate: 0.5).total, 55); // 50 + 5
    });

    test('built from a quote', () {
      final q = DeliveryQuote.compute(
        distanceKm: 5000,
        departureDate: DateTime(2030, 6, 11),
        now: DateTime.utc(2030, 6, 10),
        weightKg: 0.9,
      );

      final x = RequestPricing.forQuote(q, currency: 'eur', rate: 0.9);

      expect(x.costUsd, 101);
      expect(x.feeUsd, 11);
      expect(x.currency, 'EUR');
      expect(x.cost, 91); // 90.90
    });

    test('a blank currency or a bad rate falls back to dollars', () {
      final q = DeliveryQuote.compute(
        distanceKm: 100,
        departureDate: DateTime(2030, 7, 1),
        now: DateTime.utc(2030, 6, 10),
        weightKg: 1,
      );

      final blank = RequestPricing.forQuote(q, currency: '  ', rate: 0.9);
      final bad = RequestPricing.forQuote(q, currency: 'EUR', rate: 0);

      expect(blank.currency, 'USD');
      expect(bad.rate, 1);
    });
  });

  group('RequestInput.parseWeightKg', () {
    double? w(String s) => RequestInput.parseWeightKg(s);

    test('plain numbers are kilograms', () {
      expect(w('0.9'), 0.9);
      expect(w('3'), 3.0);
    });

    test('with the unit', () {
      expect(w('0.9 kg'), 0.9);
      expect(w('0.9kg'), 0.9);
      expect(w('2 KG'), 2.0);
      expect(w('2 kgs'), 2.0);
    });

    test('a comma is a decimal point', () {
      expect(w('0,9'), 0.9);
      expect(w('1,25 kg'), 1.25);
    });

    test('grams are converted', () {
      expect(w('900 g'), 0.9);
      expect(w('450g'), 0.45);
    });

    test('spaces around are ignored', () {
      expect(w('  0.9 kg  '), 0.9);
    });

    test('rounds to 2 decimals', () {
      expect(w('0.456'), 0.46);
    });

    test('rejects zero, negatives, empty and words', () {
      for (final bad in ['0', '0 kg', '-1', '', '   ', 'abc', 'heavy', 'kg']) {
        expect(w(bad), isNull, reason: '"$bad"');
      }
    });

    test('rejects other units instead of guessing', () {
      for (final bad in ['2 lbs', '2 lb', '2 oz', '5 stone', '1.5 pounds']) {
        expect(w(bad), isNull, reason: '"$bad"');
      }
    });

    test('rejects several numbers and absurd weights', () {
      expect(w('1 2'), isNull);
      expect(w('1.2.3'), isNull);
      expect(w('1000'), isNull);
      expect(w('5000 g'), 5.0); // 5 kg is a normal weight
      expect(w('1000 g'), 1.0); // 1 kg
      expect(w('1000000 g'), isNull); // 1000 kg is not a parcel
    });
  });

  group('RequestInput.normalizePhone', () {
    String? n(String s) => RequestInput.normalizePhone(s);

    test('keeps a clean international number', () {
      expect(n('+447700900123'), '+447700900123');
    });

    test('removes spaces, dashes, dots and brackets', () {
      expect(n('+44 7700 900123'), '+447700900123');
      expect(n('+44 (7700) 900-123'), '+447700900123');
      expect(n('+1.202.555.0123'), '+12025550123');
    });

    test('ignores spaces around', () {
      expect(n('  +233 24 123 4567 '), '+233241234567');
    });

    test('needs the country code (a leading +)', () {
      expect(n('07700 900123'), isNull);
      expect(n('447700900123'), isNull);
    });

    test('a country code cannot start with 0', () {
      expect(n('+0447700900123'), isNull);
    });

    test('length limits: 8 to 15 digits', () {
      expect(n('+1234567'), isNull); // 7
      expect(n('+12345678'), '+12345678'); // 8
      expect(n('+123456789012345'), '+123456789012345'); // 15
      expect(n('+1234567890123456'), isNull); // 16
    });

    test('rejects letters and empty', () {
      expect(n('+44 77OO 900123'), isNull);
      expect(n(''), isNull);
      expect(n('+'), isNull);
    });
  });

  group('RequestItem', () {
    test('is sent as name, category and description', () {
      expect(
        const RequestItem(
          name: 'Apple AirPods Max',
          category: RequestCategory.apparel,
          description: 'sealed',
        ).toJson(),
        {
          'name': 'Apple AirPods Max',
          'category': 'apparel',
          'description': 'sealed',
        },
      );
    });

    test('name and notes are trimmed', () {
      final j = const RequestItem(
        name: '  Watch ',
        description: '  new  ',
      ).toJson();

      expect(j['name'], 'Watch');
      expect(j['description'], 'new');
    });

    test(
      'no notes means an empty description, and electronics is the default',
      () {
        final j = const RequestItem(name: 'Watch', description: '   ').toJson();

        expect(j['description'], '');
        expect(j['category'], 'electronics');
      },
    );

    test('the name and category are not mixed into the notes', () {
      final j = draft().items.first.toJson();

      expect(j['description'], isNot(contains('AirPods')));
      expect(j['description'], isNot(contains('electronics')));
    });
  });

  group('RequestDraft', () {
    test('holds up to five items', () => expect(RequestDraft.maxItems, 5));

    test('keeps the items in the order they were added', () {
      final d = draft(
        items: const [
          RequestItem(name: 'A'),
          RequestItem(name: 'B', category: RequestCategory.documents),
          RequestItem(name: 'C', category: RequestCategory.apparel),
        ],
      );

      expect(d.items.map((i) => i.name), ['A', 'B', 'C']);
    });

    test('item_size is the dimensions, null when blank', () {
      expect(draft().itemSize, '24 × 24 × 8 cm');
      expect(draft(dims: '  ').itemSize, isNull);
      expect(draft(dims: '').itemSize, isNull);
    });

    test('categories are stored as lower-case words', () {
      expect(RequestCategory.electronics.dbValue, 'electronics');
      expect(RequestCategory.apparel.dbValue, 'apparel');
      expect(RequestCategory.documents.dbValue, 'documents');
    });
  });

  group('RequestSizeClass', () {
    test('are stored as the words the database accepts', () {
      expect(RequestSizeClass.values.map((c) => c.dbValue), [
        'envelope',
        'shoebox',
        'backpack',
      ]);
    });

    test('are ordered from small to big', () {
      expect(
        RequestSizeClass.envelope.rank,
        lessThan(RequestSizeClass.shoebox.rank),
      );
      expect(
        RequestSizeClass.shoebox.rank,
        lessThan(RequestSizeClass.backpack.rank),
      );
    });

    test('are read from the trip\'s size text', () {
      expect(
        RequestSizeClass.fromTripSize('Envelope / Document'),
        RequestSizeClass.envelope,
      );
      expect(
        RequestSizeClass.fromTripSize('Shoebox (30×20×15 cm)'),
        RequestSizeClass.shoebox,
      );
      expect(
        RequestSizeClass.fromTripSize('Backpack size'),
        RequestSizeClass.backpack,
      );
    });

    test('reading ignores capitals and spaces', () {
      expect(
        RequestSizeClass.fromTripSize('  SHOEBOX size '),
        RequestSizeClass.shoebox,
      );
    });

    test('an unknown or missing size is "no limit"', () {
      expect(RequestSizeClass.fromTripSize('Large suitcase'), isNull);
      expect(RequestSizeClass.fromTripSize(''), isNull);
      expect(RequestSizeClass.fromTripSize(null), isNull);
    });

    test('a parcel fits a traveler who accepts the same size or bigger', () {
      expect(RequestSizeClass.shoebox.fitsIn(RequestSizeClass.shoebox), isTrue);
      expect(
        RequestSizeClass.envelope.fitsIn(RequestSizeClass.backpack),
        isTrue,
      );
      expect(
        RequestSizeClass.envelope.fitsIn(RequestSizeClass.shoebox),
        isTrue,
      );
    });

    test('a parcel does not fit a traveler who accepts smaller', () {
      expect(
        RequestSizeClass.backpack.fitsIn(RequestSizeClass.shoebox),
        isFalse,
      );
      expect(
        RequestSizeClass.shoebox.fitsIn(RequestSizeClass.envelope),
        isFalse,
      );
    });

    test('with no limit everything fits', () {
      for (final c in RequestSizeClass.values) {
        expect(c.fitsIn(null), isTrue);
      }
    });
  });

  group('generateUuidV4', () {
    final shape = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('is a valid version 4 uuid', () {
      for (var i = 0; i < 200; i++) {
        expect(generateUuidV4(Random(i)), matches(shape));
      }
    });

    test('is different every time', () {
      final ids = {for (var i = 0; i < 500; i++) generateUuidV4()};

      expect(ids.length, 500);
    });

    test('is repeatable with a seeded random', () {
      expect(generateUuidV4(Random(5)), generateUuidV4(Random(5)));
    });
  });

  group('RequestService.reasonFor', () {
    RequestFailure of(String m) => RequestService.reasonFor(m);

    test('maps every database error', () {
      expect(of('nata:not_signed_in'), RequestFailure.notSignedIn);
      expect(of('nata:trip_unavailable'), RequestFailure.tripUnavailable);
      expect(of('nata:own_trip'), RequestFailure.ownTrip);
      expect(of('nata:weight_too_heavy'), RequestFailure.weightTooHeavy);
      expect(of('nata:duplicate'), RequestFailure.duplicate);
      expect(of('nata:destination_limit'), RequestFailure.destinationLimit);
      expect(of('nata:price_changed'), RequestFailure.priceChanged);
      expect(of('nata:size_too_big'), RequestFailure.sizeTooBig);
      for (final c in [
        'item_required',
        'too_many_items',
        'item_category_invalid',
        'recipient_required',
        'phone_invalid',
        'weight_invalid',
        'size_required',
        'photo_required',
        'photo_invalid',
      ]) {
        expect(of('nata:$c'), RequestFailure.invalid, reason: c);
      }
    });

    test('finds the code inside a longer message', () {
      expect(of('P0001: nata:duplicate (context)'), RequestFailure.duplicate);
    });

    test('anything else is "other"', () {
      expect(of('permission denied for table'), RequestFailure.other);
      expect(of(''), RequestFailure.other);
    });
  });

  group('RequestService.send', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late MockStorage storage;
    late MockFileApi files;
    late RequestService service;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      final user = MockUser();
      storage = MockStorage();
      files = MockFileApi();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('user-1');
      when(() => client.storage).thenReturn(storage);
      when(() => storage.from('request-photos')).thenReturn(files);
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((_) async => 'ok');
      when(() => files.remove(any())).thenAnswer((_) async => []);
      service = RequestService(client: client);
    });

    void rpcOk() => when(
      () => client.rpc<dynamic>(
        'create_delivery_request',
        params: any(named: 'params'),
      ),
    ).thenAnswer((_) => FakeRpc());

    void rpcFails(Object error) => when(
      () => client.rpc<dynamic>(
        'create_delivery_request',
        params: any(named: 'params'),
      ),
    ).thenAnswer((_) => FakeRpc(error: error));

    Map<dynamic, dynamic> sentParams() =>
        verify(
              () => client.rpc<dynamic>(
                'create_delivery_request',
                params: captureAny(named: 'params'),
              ),
            ).captured.single
            as Map<dynamic, dynamic>;

    test(
      'uploads each photo into the sender\'s folder for this request',
      () async {
        rpcOk();

        await service.send('req-9', draft(), [photo('JPG'), photo('png')]);

        final paths = verify(
          () => files.uploadBinary(
            captureAny(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        ).captured;
        expect(paths, ['user-1/req-9/0.jpg', 'user-1/req-9/1.png']);
      },
    );

    test(
      'photo names do not depend on the time, so retries do not pile up',
      () async {
        rpcOk();

        await service.send('req-9', draft(), [photo('jpg')]);
        await service.send('req-9', draft(), [photo('jpg')]);

        final paths = verify(
          () => files.uploadBinary(
            captureAny(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        ).captured;
        expect(paths.toSet().length, 1);
      },
    );

    test('uploads allow replacing an earlier attempt\'s file', () async {
      rpcOk();

      await service.send('req-9', draft(), [photo('jpg')]);

      final opts =
          verify(
                () => files.uploadBinary(
                  any(),
                  any(),
                  fileOptions: captureAny(named: 'fileOptions'),
                ),
              ).captured.single
              as FileOptions;
      expect(opts.upsert, isTrue);
      expect(opts.contentType, 'image/jpeg');
    });

    test(
      'creates the request in one database call with everything in it',
      () async {
        rpcOk();

        final id = await service.send('req-9', draft(), [photo('jpg')]);

        expect(id, 'req-9');
        expect(sentParams(), {
          'p_id': 'req-9',
          'p_trip_id': 'trip-1',
          'p_items': [
            {
              'name': 'Apple AirPods Max',
              'category': 'electronics',
              'description': 'Brand new, sealed',
            },
          ],
          'p_item_weight_kg': 0.9,
          'p_item_size': '24 × 24 × 8 cm',
          'p_item_size_class': 'shoebox',
          'p_recipient_name': 'Jane Doe',
          'p_recipient_phone': '+447700900123',
          'p_photo_paths': ['user-1/req-9/0.jpg'],
          'p_expected_total': 110.75,
        });
      },
    );

    test('several items go in one call, in order', () async {
      rpcOk();

      await service.send(
        'req-9',
        draft(
          items: const [
            RequestItem(name: 'AirPods', description: 'sealed'),
            RequestItem(name: 'Shirt', category: RequestCategory.apparel),
            RequestItem(
              name: 'Passport copy',
              category: RequestCategory.documents,
            ),
          ],
        ),
        [photo('jpg')],
      );

      final items = sentParams()['p_items'] as List;
      expect(items.map((i) => (i as Map)['name']), [
        'AirPods',
        'Shirt',
        'Passport copy',
      ]);
      expect(items.map((i) => (i as Map)['category']), [
        'electronics',
        'apparel',
        'documents',
      ]);
    });

    test('the request is only created after the photos are uploaded', () async {
      rpcOk();
      final order = <String>[];
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((_) async {
        order.add('upload');
        return 'ok';
      });
      when(
        () => client.rpc<dynamic>(
          'create_delivery_request',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) {
        order.add('rpc');
        return FakeRpc();
      });

      await service.send('req-9', draft(), [photo('jpg'), photo('jpg')]);

      expect(order, ['upload', 'upload', 'rpc']);
    });

    test('a failed upload stops before any request is created', () async {
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenThrow(Exception('storage down'));

      await expectLater(
        service.send('req-9', draft(), [photo('jpg')]),
        throwsA(
          isA<RequestException>().having(
            (e) => e.reason,
            'reason',
            RequestFailure.other,
          ),
        ),
      );

      verifyNever(
        () => client.rpc<dynamic>(
          'create_delivery_request',
          params: any(named: 'params'),
        ),
      );
    });

    for (final c in {
      'nata:trip_unavailable': RequestFailure.tripUnavailable,
      'nata:own_trip': RequestFailure.ownTrip,
      'nata:weight_too_heavy': RequestFailure.weightTooHeavy,
      'nata:duplicate': RequestFailure.duplicate,
      'nata:destination_limit': RequestFailure.destinationLimit,
      'nata:price_changed': RequestFailure.priceChanged,
      'nata:size_too_big': RequestFailure.sizeTooBig,
      'nata:photo_required': RequestFailure.invalid,
    }.entries) {
      test('${c.key}: reported, and the uploaded photos are removed', () async {
        rpcFails(PostgrestException(message: c.key));

        await expectLater(
          service.send('req-9', draft(), [photo('jpg')]),
          throwsA(
            isA<RequestException>().having((e) => e.reason, 'reason', c.value),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verify(() => files.remove(['user-1/req-9/0.jpg'])).called(1);
      });
    }

    test(
      'an unclear failure KEEPS the photos (the request may exist)',
      () async {
        rpcFails(PostgrestException(message: 'connection reset'));

        await expectLater(
          service.send('req-9', draft(), [photo('jpg')]),
          throwsA(
            isA<RequestException>().having(
              (e) => e.reason,
              'reason',
              RequestFailure.other,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => files.remove(any()));
      },
    );

    test('a non-database error is "other" and keeps the photos', () async {
      rpcFails(StateError('socket closed'));

      await expectLater(
        service.send('req-9', draft(), [photo('jpg')]),
        throwsA(
          isA<RequestException>().having(
            (e) => e.reason,
            'reason',
            RequestFailure.other,
          ),
        ),
      );

      verifyNever(() => files.remove(any()));
    });

    test('nobody signed in: refused before anything happens', () async {
      when(() => auth.currentUser).thenReturn(null);

      await expectLater(
        service.send('req-9', draft(), [photo('jpg')]),
        throwsA(
          isA<RequestException>().having(
            (e) => e.reason,
            'reason',
            RequestFailure.notSignedIn,
          ),
        ),
      );

      verifyNever(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      );
    });
  });

  group('SentRequest.fromJson', () {
    final row = {
      'request_id': 'r1',
      'status': 'pending',
      'created_at': '2030-06-01T10:00:00Z',
      'total_amount': 110.91,
      'currency': 'USD',
      'item_weight_kg': 0.9,
      'item_size': '20 x 18 x 9',
      'item_size_class': 'shoebox',
      'items': [
        {
          'name': 'AirPods Max',
          'category': 'electronics',
          'description': 'Boxed',
        },
        {'name': 'Scarf', 'category': 'apparel', 'description': ''},
      ],
      'recipient_name': 'Jane Doe',
      'recipient_phone': '+447700900123',
      'photo_paths': ['u/r1/0.jpg'],
      'trip_id': 't1',
      'traveler_id': 'tr1',
      'first_name': 'Amara',
      'last_name': 'Kalu',
      'avatar_path': null,
      'avg_rating': 4.9,
      'items_delivered_count': 28,
      'departure_city': 'Lagos',
      'departure_country': 'NG',
      'arrival_city': 'London',
      'arrival_country': 'GB',
      'departure_date': '2030-06-22',
      'arrival_date': '2030-06-22',
      'price': 35,
      'trip_currency': 'USD',
      'max_weight_kg': 3,
      'max_size': 'Shoebox (30×20×15 cm)',
    };

    test('reads the request, its items and its trip', () {
      final r = SentRequest.fromJson(row);
      expect(r.id, 'r1');
      expect(r.isEditable, isTrue);
      expect(r.totalUsd, 110.91);
      expect(r.items.map((i) => i.category), [
        RequestCategory.electronics,
        RequestCategory.apparel,
      ]);
      expect(r.itemsSummary, 'AirPods Max, Scarf');
      expect(r.sizeClass, RequestSizeClass.shoebox);
      expect(r.photoPaths, ['u/r1/0.jpg']);
      expect(r.trip.tripId, 't1');
      expect(r.trip.fullName, 'Amara Kalu');
      expect(r.trip.arrivalCountry, 'GB');
      expect(r.trip.maxWeightKg, 3);
    });

    test('the price is an estimate until the traveler accepts', () {
      final r = SentRequest.fromJson({...row, 'display_currency': 'XOF'});
      expect(r.displayCurrency, 'XOF');
      expect(r.priceFixed, isFalse);
      expect(r.fixedTotalText, isNull);
    });

    test('reads the checkout checks and the traveler\'s verification', () {
      final r = SentRequest.fromJson({
        ...row,
        'status': 'accepted',
        'ticket_checked_at': '2030-06-21T09:00:00Z',
        'id_checked_at': '2030-06-21T09:05:00Z',
        'traveler_verified': true,
        'ticket_on_file': true,
        'ticket_shared_path': 'tr1/ticket-shared.jpg',
        'has_booking_reference': true,
        'expires_at': '2030-06-22T09:00:00Z',
      });
      expect(r.ticketCheckedAt, DateTime.utc(2030, 6, 21, 9));
      expect(r.travelerVerified, isTrue);
      expect(r.ticketReceiptPath, 'tr1/ticket-shared.jpg');
      expect(r.hasTicket, isTrue);
      expect(r.hasBookingReference, isTrue);
      expect(r.expiresAt, DateTime.utc(2030, 6, 22, 9));
      expect(r.awaitingPayment, isTrue);

      final bare = SentRequest.fromJson({...row, 'ticket_shared_path': ''});
      expect(bare.travelerVerified, isFalse);
      expect(bare.ticketReceiptPath, isNull);
      expect(bare.hasTicket, isFalse);
      expect(bare.hasBookingReference, isFalse);

      // A ticket on file without a blurred copy: described, not shown.
      final noCopy = SentRequest.fromJson({...row, 'ticket_on_file': true});
      expect(noCopy.hasTicket, isTrue);
      expect(noCopy.ticketReceiptPath, isNull);
    });

    test('reads the price fixed when the traveler accepted', () {
      final r = SentRequest.fromJson({
        ...row,
        'status': 'accepted',
        'display_currency': 'xof ',
        'display_total': 65566,
      });
      expect(r.priceFixed, isTrue);
      expect(r.fixedTotalText, 'XOF 65,566');
      // 10% of 65,566, rounded up.
      expect(r.fixedCancellationFeeText, 'XOF 6,557');
    });

    test('only pending requests are editable', () {
      for (final s in [
        'accepted',
        'declined',
        'expired',
        'paid',
        'delivered',
      ]) {
        expect(SentRequest.fromJson({...row, 'status': s}).isEditable, isFalse);
      }
    });
  });

  group('Cancelling', () {
    final base = SentRequest.fromJson({
      'request_id': 'r1',
      'status': 'pending',
      'created_at': '2030-06-01T10:00:00Z',
      'total_amount': 110.91,
      'items': const [],
      'trip_id': 't1',
      'traveler_id': 'tr1',
      'first_name': 'Amara',
      'last_name': 'Kalu',
      'departure_city': 'Lagos',
      'departure_country': 'NG',
      'arrival_city': 'London',
      'arrival_country': 'GB',
      'departure_date': '2030-06-22',
      'arrival_date': '2030-06-22',
      'price': 35,
      'trip_currency': 'USD',
    });
    SentRequest withStatus(String s, {Map<String, dynamic> extra = const {}}) =>
        SentRequest.fromJson({
          'request_id': base.id,
          'status': s,
          'created_at': '2030-06-01T10:00:00Z',
          'total_amount': base.totalUsd,
          'items': const [],
          'trip_id': 't1',
          'traveler_id': 'tr1',
          'first_name': 'Amara',
          'last_name': 'Kalu',
          'departure_city': 'Lagos',
          'departure_country': 'NG',
          'arrival_city': 'London',
          'arrival_country': 'GB',
          'departure_date': '2030-06-22',
          'arrival_date': '2030-06-22',
          'price': 35,
          'trip_currency': 'USD',
          ...extra,
        });

    test('free before the traveler accepts', () {
      expect(base.cancellationFeeNow, 0);
      expect(base.isCancellable, isTrue);
    });

    test('10% of the total, rounded up to a whole dollar, once accepted', () {
      // 10% of 110.91 is 11.091.
      expect(withStatus('accepted').cancellationFeeNow, 12);
      expect(withStatus('paid').cancellationFeeNow, 12);
    });

    test('not possible once handed off or over', () {
      for (final s in [
        'handed_off',
        'delivered',
        'declined',
        'expired',
        'cancelled',
      ]) {
        expect(withStatus(s).isCancellable, isFalse, reason: s);
        expect(withStatus(s).cancellationFeeNow, isNull, reason: s);
      }
    });

    test('reads the fee of a request the sender cancelled', () {
      final r = withStatus(
        'cancelled',
        extra: {
          'cancellation_fee': 11.09,
          'cancelled_at': '2030-06-10T09:00:00Z',
        },
      );
      expect(r.cancelledBySender, isTrue);
      expect(r.cancellationFee, 11.09);
      expect(r.cancelledAt, DateTime.utc(2030, 6, 10, 9));

      // Cancelled by someone else (no cancelled_at): no fee line.
      expect(withStatus('cancelled').cancelledBySender, isFalse);
    });

    test('maps the database refusals', () {
      expect(
        RequestService.reasonFor('nata:request_not_cancellable'),
        RequestFailure.notCancellable,
      );
      expect(
        RequestService.reasonFor('nata:fee_changed'),
        RequestFailure.feeChanged,
      );
    });

    group('RequestService.cancel', () {
      late MockSupabaseClient client;
      late MockGoTrueClient auth;
      late RequestService service;

      setUp(() {
        client = MockSupabaseClient();
        auth = MockGoTrueClient();
        final user = MockUser();
        when(() => client.auth).thenReturn(auth);
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.id).thenReturn('user-1');
        service = RequestService(client: client);
      });

      test(
        'sends the fee the sender was shown and returns the charged fee',
        () async {
          when(
            () => client.rpc<dynamic>(
              'cancel_delivery_request',
              params: any(named: 'params'),
            ),
          ).thenAnswer((_) => FakeRpc(value: 12));

          final fee = await service.cancel(withStatus('accepted'));

          expect(fee, 12);
          final params =
              verify(
                    () => client.rpc<dynamic>(
                      'cancel_delivery_request',
                      params: captureAny(named: 'params'),
                    ),
                  ).captured.single
                  as Map;
          expect(params, {'p_id': 'r1', 'p_expected_fee': 12.0});
        },
      );

      test('a pending request is sent with a fee of 0', () async {
        when(
          () => client.rpc<dynamic>(
            'cancel_delivery_request',
            params: any(named: 'params'),
          ),
        ).thenAnswer((_) => FakeRpc(value: 0));

        expect(await service.cancel(base), 0);
        final params =
            verify(
                  () => client.rpc<dynamic>(
                    'cancel_delivery_request',
                    params: captureAny(named: 'params'),
                  ),
                ).captured.single
                as Map;
        expect(params['p_expected_fee'], 0);
      });

      test('database refusals become RequestExceptions', () async {
        when(
          () => client.rpc<dynamic>(
            'cancel_delivery_request',
            params: any(named: 'params'),
          ),
        ).thenAnswer(
          (_) => FakeRpc(
            error: const PostgrestException(message: 'nata:fee_changed'),
          ),
        );

        await expectLater(
          service.cancel(base),
          throwsA(
            isA<RequestException>().having(
              (e) => e.reason,
              'reason',
              RequestFailure.feeChanged,
            ),
          ),
        );
      });

      test('signed out: refused before calling the database', () async {
        when(() => auth.currentUser).thenReturn(null);

        await expectLater(
          service.cancel(base),
          throwsA(
            isA<RequestException>().having(
              (e) => e.reason,
              'reason',
              RequestFailure.notSignedIn,
            ),
          ),
        );
        verifyNever(
          () => client.rpc<dynamic>(any(), params: any(named: 'params')),
        );
      });
    });
  });

  group('RequestService.accept', () {
    late MockSupabaseClient client;
    late RequestService service;

    setUp(() {
      client = MockSupabaseClient();
      final auth = MockGoTrueClient();
      final user = MockUser();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('traveler-1');
      service = RequestService(client: client);
    });

    test('asks the database to accept (and fix the price)', () async {
      when(
        () => client.rpc<dynamic>(
          'accept_delivery_request',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) => FakeRpc());

      await service.accept('r1');

      verify(
        () => client.rpc<dynamic>(
          'accept_delivery_request',
          params: {'p_id': 'r1'},
        ),
      ).called(1);
    });

    for (final c in {
      'nata:rate_unavailable': RequestFailure.rateUnavailable,
      'nata:request_not_pending': RequestFailure.notPending,
      'nata:request_not_found': RequestFailure.requestNotFound,
    }.entries) {
      test('${c.key} is reported', () async {
        when(
          () => client.rpc<dynamic>(
            'accept_delivery_request',
            params: any(named: 'params'),
          ),
        ).thenAnswer((_) => FakeRpc(error: PostgrestException(message: c.key)));

        await expectLater(
          service.accept('r1'),
          throwsA(
            isA<RequestException>().having((e) => e.reason, 'reason', c.value),
          ),
        );
      });
    }
  });

  group('IncomingRequest.fromJson', () {
    final row = {
      'request_id': 'in-1',
      'status': 'pending',
      'created_at': '2030-06-20T09:00:00Z',
      'expires_at': '2030-06-22T09:00:00Z',
      'payout_usd': 101,
      'items': [
        {'name': 'Apple Watch', 'category': 'electronics', 'description': ''},
      ],
      'item_weight_kg': 0.45,
      'item_size': ' 15 x 8 x 4 cm ',
      'item_size_class': 'shoebox',
      'photo_paths': ['s1/in-1/0.jpg'],
      'sender_id': 's1',
      'sender_first_name': 'Chioma',
      'sender_last_name': 'Eze',
      'sender_avatar_path': null,
      'sender_verified': true,
      'sender_deliveries': 5,
      'recipient_name': null,
      'recipient_phone': null,
      'trip_id': 't1',
      'departure_city': 'Lagos',
      'departure_country': 'NG',
      'arrival_city': 'London',
      'arrival_country': 'GB',
      'departure_date': '2030-06-22',
      'arrival_date': '2030-06-22',
    };

    test('reads the request, its sender and its trip', () {
      final r = IncomingRequest.fromJson(row);
      expect(r.isPending, isTrue);
      expect(r.isInProgress, isFalse);
      expect(r.payoutUsd, 101);
      expect(r.senderName, 'Chioma Eze');
      expect(r.senderVerified, isTrue);
      expect(r.senderDeliveries, 5);
      expect(r.itemsSummary, 'Apple Watch');
      expect(r.dimensions, '15 x 8 x 4 cm');
      expect(r.sizeClass, RequestSizeClass.shoebox);
      expect(r.routeLabel, 'Lagos → London');
      expect(r.recipientName, isNull);
      expect(r.expiresAt, DateTime.utc(2030, 6, 22, 9));
    });

    test('in progress once accepted, paid, handed off or delivered', () {
      for (final s in ['accepted', 'paid', 'handed_off', 'delivered']) {
        final r = IncomingRequest.fromJson({...row, 'status': s});
        expect(r.isInProgress, isTrue, reason: s);
        expect(r.isPending, isFalse, reason: s);
      }
    });
  });

  group('RequestService.decline', () {
    late MockSupabaseClient client;
    late RequestService service;

    setUp(() {
      client = MockSupabaseClient();
      final auth = MockGoTrueClient();
      final user = MockUser();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('traveler-1');
      service = RequestService(client: client);
    });

    test('sends the request and the reason', () async {
      when(
        () => client.rpc<dynamic>(
          'decline_delivery_request',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) => FakeRpc());

      await service.decline('in-1', reason: 'Bag is full');

      verify(
        () => client.rpc<dynamic>(
          'decline_delivery_request',
          params: {'p_id': 'in-1', 'p_reason': 'Bag is full'},
        ),
      ).called(1);
    });

    test('an answered request is reported', () async {
      when(
        () => client.rpc<dynamic>(
          'decline_delivery_request',
          params: any(named: 'params'),
        ),
      ).thenAnswer(
        (_) => FakeRpc(
          error: const PostgrestException(message: 'nata:request_not_pending'),
        ),
      );

      await expectLater(
        service.decline('in-1'),
        throwsA(
          isA<RequestException>().having(
            (e) => e.reason,
            'reason',
            RequestFailure.notPending,
          ),
        ),
      );
    });
  });

  test('database refusals for edits', () {
    expect(
      RequestService.reasonFor('nata:request_not_editable'),
      RequestFailure.notEditable,
    );
    expect(
      RequestService.reasonFor('nata:request_not_found'),
      RequestFailure.requestNotFound,
    );
  });

  group('mobile money charged directly', () {
    late MockSupabaseClient client;
    late MockFunctions functions;
    late RequestService service;
    Map<String, dynamic>? sent;

    setUp(() {
      client = MockSupabaseClient();
      functions = MockFunctions();
      sent = null;
      when(() => client.functions).thenReturn(functions);
      service = RequestService(client: client);
    });

    void answer(Map<String, dynamic> data) =>
        when(
          () => functions.invoke('create-payment', body: any(named: 'body')),
        ).thenAnswer((inv) async {
          sent = Map<String, dynamic>.from(
            inv.namedArguments[#body] as Map<dynamic, dynamic>,
          );
          return FunctionResponse(data: data, status: 200);
        });

    test('sends the number and network, and gets no page back', () async {
      answer({'tx_ref': 'nata-1', 'direct': true});
      final payment = await service.startPayment(
        'req-1',
        PayMethod.mobileMoney,
        country: 'CM',
        phone: '+237677123456',
        network: 'MTN',
      );
      expect(sent, {
        'request_id': 'req-1',
        'method': 'mobile_money',
        'country': 'CM',
        'phone': '+237677123456',
        'network': 'MTN',
      });
      expect(payment.direct, isTrue);
      expect(payment.link, isNull);
      expect(payment.txRef, 'nata-1');
    });

    test('a page in the answer is opened instead', () async {
      answer({'tx_ref': 'nata-1', 'link': 'https://pay.test/1'});
      final payment = await service.startPayment(
        'req-1',
        PayMethod.mobileMoney,
        country: 'GH',
      );
      expect(sent!.containsKey('phone'), isFalse);
      expect(payment.direct, isFalse);
      expect(payment.link, Uri.parse('https://pay.test/1'));
    });

    test('a refused number is phoneRejected', () async {
      when(
        () => functions.invoke('create-payment', body: any(named: 'body')),
      ).thenThrow(
        const FunctionException(
          status: 422,
          details: {'error': 'phone_rejected'},
        ),
      );
      await expectLater(
        service.startPayment('req-1', PayMethod.mobileMoney, country: 'KE'),
        throwsA(
          isA<RequestException>().having(
            (e) => e.reason,
            'reason',
            RequestFailure.phoneRejected,
          ),
        ),
      );
    });

    test('each country comes with its calling code and networks', () {
      final option = MobileMoneyOption.fromJson({
        'country_code': 'CG ',
        'country_name': 'Congo',
        'currency': 'XAF',
        'amount': 65566,
        'suggested': true,
        'dial_code': '+242',
        'networks': [
          {'code': 'MTN_MOMO_COG', 'name': 'MTN Mobile Money'},
          {'code': 'AIRTEL_COG', 'name': 'Airtel Money'},
        ],
      });
      expect(option.countryCode, 'CG');
      expect(option.dialCode, '+242');
      expect(option.networks.map((n) => n.code), [
        'MTN_MOMO_COG',
        'AIRTEL_COG',
      ]);
      expect(option.networks.last.name, 'Airtel Money');
    });

    test('an older server without networks still parses', () {
      final option = MobileMoneyOption.fromJson({
        'country_code': 'KE',
        'currency': 'KES',
        'amount': 100,
      });
      expect(option.networks, isEmpty);
      expect(option.dialCode, '');
    });

    for (final (code, reason) in [
      ('amount_out_of_bounds', RequestFailure.amountOutOfBounds),
      ('network_unavailable', RequestFailure.networkUnavailable),
    ]) {
      test('$code is explained', () async {
        when(
          () => functions.invoke('create-payment', body: any(named: 'body')),
        ).thenThrow(FunctionException(status: 409, details: {'error': code}));
        await expectLater(
          service.startPayment('req-1', PayMethod.mobileMoney, country: 'CG'),
          throwsA(
            isA<RequestException>().having((e) => e.reason, 'reason', reason),
          ),
        );
      });
    }
  });
}
