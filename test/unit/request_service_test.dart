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

class FakeFileOptions extends Fake implements FileOptions {}

class FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeRpc({this.error});
  final Object? error;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    final f = error != null
        ? Future<dynamic>.error(error!)
        : Future<dynamic>.value(null);
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
      expect(x.totalText, r'$110.00');
      expect(x.costText, r'$100.00');
      expect(x.feeText, r'$10.00');
    });

    test('euros: each line is converted', () {
      final x = p(currency: 'EUR', rate: 0.892438);

      expect(x.cost, 89.24);
      expect(x.fee, 8.92);
      expect(x.costText, '€89.24');
      expect(x.feeText, '€8.92');
    });

    test('pounds', () {
      final x = p(currency: 'GBP', rate: 0.755923);

      expect(x.cost, 75.59);
      expect(x.fee, 7.56);
      expect(x.totalText, '£83.15');
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
      expect(RequestPricing.decimalsFor('XAF'), 0);
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
          expect(
            x.total,
            closeTo(x.cost + x.fee, 0.0001),
            reason: 'rate $rate cost $cost',
          );
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
        r'$1,357.95',
      );
    });

    test('an unlisted currency shows its code', () {
      expect(p(currency: 'JPY', rate: 150).totalText, 'JPY 16,500.00');
    });

    test('decimals follow the currency', () {
      expect(RequestPricing.decimalsFor('USD'), 2);
      expect(RequestPricing.decimalsFor('EUR'), 2);
      expect(RequestPricing.decimalsFor('xof'), 0);
    });

    test('built from a quote', () {
      final q = DeliveryQuote.compute(
        distanceKm: 5000,
        departureDate: DateTime(2030, 6, 11),
        now: DateTime.utc(2030, 6, 10),
        weightKg: 0.9,
      );

      final x = RequestPricing.forQuote(q, currency: 'eur', rate: 0.9);

      expect(x.costUsd, 100.68);
      expect(x.feeUsd, 10.07);
      expect(x.currency, 'EUR');
      expect(x.cost, 90.61);
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
}
