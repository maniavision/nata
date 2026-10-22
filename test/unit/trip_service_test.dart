import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/services/trip_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockQuerySchema extends Mock implements SupabaseQuerySchema {}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockStorage extends Mock implements SupabaseStorageClient {}

class MockFileApi extends Mock implements StorageFileApi {}

class FakeFileOptions extends Fake implements FileOptions {}

/// An awaitable query that records the filters applied to it.
class FakeQuery<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeQuery(this.value, {this.error});
  final T value;
  final Object? error;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    calls.add('eq:$column=$value');
    return this;
  }

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) {
    calls.add('in:$column=${values.join(',')}');
    return this;
  }

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    calls.add('order:$column:${ascending ? 'asc' : 'desc'}');
    return this;
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    final future = error != null
        ? Future<T>.error(error!)
        : Future<T>.value(value);
    return future.then(onValue, onError: onError);
  }
}

Map<String, dynamic> tripRow({
  String id = 'trip-1',
  Object price = 30,
  Object? maxWeight = 3,
  String status = 'live',
  Map<String, dynamic>? departure,
  Map<String, dynamic>? arrival,
}) => {
  'id': id,
  'departure_city_id': 1,
  'arrival_city_id': 2,
  'departure_date': '2030-06-22',
  'arrival_date': '2030-06-23',
  'price': price,
  'currency': 'USD',
  'max_weight_kg': maxWeight,
  'max_size': 'Shoebox (30×20×15 cm)',
  'ticket_receipt_path': 'user-1/1.pdf',
  'status': status,
  'departure':
      departure ??
      {
        'id': 1,
        'name': 'Lagos',
        'country_code': 'NG',
        'countries': {'name': 'Nigeria'},
      },
  'arrival':
      arrival ??
      {
        'id': 2,
        'name': 'London',
        'country_code': 'GB',
        'countries': {'name': 'United Kingdom'},
      },
};

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(FakeFileOptions());
  });

  group('Trip.fromJson', () {
    test('parses the trip with both cities and country names', () {
      final t = Trip.fromJson(tripRow());

      expect(t.id, 'trip-1');
      expect(t.departureCityId, 1);
      expect(t.departureCity, 'Lagos');
      expect(t.departureCountryCode, 'NG');
      expect(t.departureCountry, 'Nigeria');
      expect(t.arrivalCityId, 2);
      expect(t.arrivalCity, 'London');
      expect(t.arrivalCountry, 'United Kingdom');
      expect(t.departureDate, DateTime(2030, 6, 22));
      expect(t.arrivalDate, DateTime(2030, 6, 23));
      expect(t.price, 30.0);
      expect(t.currency, 'USD');
      expect(t.maxWeightKg, 3.0);
      expect(t.maxSize, 'Shoebox (30×20×15 cm)');
      expect(t.ticketReceiptPath, 'user-1/1.pdf');
      expect(t.status, 'live');
      expect(t.requestsCount, 0);
    });

    test('accepts numeric strings for price and weight', () {
      final t = Trip.fromJson(tripRow(price: '35.50', maxWeight: '10.00'));

      expect(t.price, 35.5);
      expect(t.maxWeightKg, 10.0);
    });

    test('a missing weight stays null', () {
      expect(Trip.fromJson(tripRow(maxWeight: null)).maxWeightKg, isNull);
    });

    test('falls back to the country code when the name is unavailable', () {
      final t = Trip.fromJson(
        tripRow(departure: {'id': 1, 'name': 'Lagos', 'country_code': 'NG'}),
      );

      expect(t.departureCountry, 'NG');
    });

    test('trims the padded currency code', () {
      final row = tripRow()..['currency'] = 'XO ';

      expect(Trip.fromJson(row).currency, 'XO');
    });

    test('withCounts keeps everything else', () {
      final t = Trip.fromJson(tripRow()).withCounts(requests: 3, delivered: 2);

      expect(t.requestsCount, 3);
      expect(t.deliveredCount, 2);
      expect(t.id, 'trip-1');
      expect(t.departureCity, 'Lagos');
      expect(t.price, 30.0);
    });
  });

  group('Trip.isUpcoming', () {
    final today = DateTime(2030, 6, 22);
    Trip trip(String status, DateTime arrival) => Trip.fromJson(
      tripRow(status: status)..['arrival_date'] = TripDraft.isoDate(arrival),
    );

    test('live and in-review trips that have not arrived are upcoming', () {
      expect(trip('live', DateTime(2030, 6, 30)).isUpcoming(today), isTrue);
      expect(
        trip('pending_review', DateTime(2030, 6, 30)).isUpcoming(today),
        isTrue,
      );
    });

    test('a trip arriving today is still upcoming', () {
      expect(trip('live', today).isUpcoming(today), isTrue);
    });

    test('a trip that already arrived is past', () {
      expect(trip('live', DateTime(2030, 6, 21)).isUpcoming(today), isFalse);
    });

    test(
      'completed and cancelled trips are past even if the date is ahead',
      () {
        expect(
          trip('completed', DateTime(2030, 7, 1)).isUpcoming(today),
          isFalse,
        );
        expect(
          trip('cancelled', DateTime(2030, 7, 1)).isUpcoming(today),
          isFalse,
        );
      },
    );

    test('the time of day does not matter', () {
      expect(
        trip('live', today).isUpcoming(DateTime(2030, 6, 22, 23, 59)),
        isTrue,
      );
    });
  });

  group('Trip.sizeShortLabel', () {
    String label(String? size) =>
        Trip.fromJson(tripRow()..['max_size'] = size).sizeShortLabel;

    test('shortens the known size options', () {
      expect(label('Envelope / Document'), 'Envelope');
      expect(label('Shoebox (30×20×15 cm)'), 'Shoebox');
      expect(label('Backpack size'), 'Backpack');
    });

    test('shows a dash when there is no size', () {
      expect(label(null), '—');
      expect(label(''), '—');
    });
  });

  group('TripDraft', () {
    final draft = TripDraft(
      departureCityId: 1,
      arrivalCityId: 2,
      departureDate: DateTime(2030, 6, 5),
      arrivalDate: DateTime(2030, 6, 6),
      price: 30.5,
      currency: 'EUR',
      maxWeightKg: 5,
      maxSize: 'Backpack size',
      ticketReceiptPath: 'user-1/1.pdf',
    );

    test('insert payload has the traveler and is published straight away', () {
      expect(draft.toInsertJson('user-1'), {
        'traveler_id': 'user-1',
        'departure_city_id': 1,
        'arrival_city_id': 2,
        'departure_date': '2030-06-05',
        'arrival_date': '2030-06-06',
        'price': 30.5,
        'currency': 'EUR',
        'max_weight_kg': 5.0,
        'max_size': 'Backpack size',
        'ticket_receipt_path': 'user-1/1.pdf',
        'ticket_shared_path': null,
        'booking_reference': null,
        'status': 'live',
      });
    });

    test('update payload never touches the traveler or the status', () {
      final json = draft.toUpdateJson();

      expect(json.containsKey('traveler_id'), isFalse);
      expect(json.containsKey('status'), isFalse);
      expect(json['departure_city_id'], 1);
      expect(json['ticket_receipt_path'], 'user-1/1.pdf');
    });

    test('dates are zero padded as yyyy-MM-dd', () {
      expect(TripDraft.isoDate(DateTime(2030, 1, 2)), '2030-01-02');
      expect(TripDraft.isoDate(DateTime(2030, 12, 31, 23, 59)), '2030-12-31');
    });
  });

  group('PickedReceipt', () {
    PickedReceipt r(String ext) => PickedReceipt(
      bytes: Uint8List(1500),
      name: 'file.$ext',
      extension: ext,
    );

    test('knows its size', () => expect(r('pdf').sizeBytes, 1500));

    test('maps extensions to content types', () {
      expect(r('pdf').contentType, 'application/pdf');
      expect(r('png').contentType, 'image/png');
      expect(r('PNG').contentType, 'image/png');
      expect(r('heic').contentType, 'image/heic');
      expect(r('jpg').contentType, 'image/jpeg');
      expect(r('jpeg').contentType, 'image/jpeg');
    });
  });

  group('booking reference', () {
    Trip withRef(Object? ref) =>
        Trip.fromJson(tripRow()..['booking_reference'] = ref);

    test('is read from the trip', () {
      expect(withRef('X7KQ9R').bookingReference, 'X7KQ9R');
    });

    test('a blank or missing reference is null', () {
      expect(withRef(null).bookingReference, isNull);
      expect(withRef('').bookingReference, isNull);
      expect(withRef('   ').bookingReference, isNull);
      expect(Trip.fromJson(tripRow()).bookingReference, isNull);
    });

    test('is kept when counts are added', () {
      final t = withRef('X7KQ9R').withCounts(requests: 1, delivered: 0);

      expect(t.bookingReference, 'X7KQ9R');
    });

    test('is part of the trips query', () {
      expect(Trip.selectColumns, contains('booking_reference'));
    });

    TripDraft draft(String? ref) => TripDraft(
      departureCityId: 1,
      arrivalCityId: 2,
      departureDate: DateTime(2030, 6, 5),
      arrivalDate: DateTime(2030, 6, 6),
      price: 30,
      currency: 'USD',
      maxWeightKg: 3,
      maxSize: 'Backpack size',
      ticketReceiptPath: 'user-1/1.pdf',
      bookingReference: ref,
    );

    test('is sent when creating a trip', () {
      expect(draft('X7KQ9R').toInsertJson('u')['booking_reference'], 'X7KQ9R');
    });

    test('is sent when updating a trip', () {
      expect(draft('X7KQ9R').toUpdateJson()['booking_reference'], 'X7KQ9R');
    });

    test('is sent as null so an edit can clear it', () {
      final json = draft(null).toUpdateJson();

      expect(json.containsKey('booking_reference'), isTrue);
      expect(json['booking_reference'], isNull);
    });

    group('pattern (matches the database check)', () {
      final re = TripDraft.bookingReferencePattern;

      for (final ok in [
        'X7KQ9R',
        'ABC12',
        'ABCDEFG8',
        '12345',
        'abcde'.toUpperCase(),
      ]) {
        test('accepts "$ok"', () => expect(re.hasMatch(ok), isTrue));
      }
      for (final bad in [
        'AB12', // too short
        'ABCDEFGH9', // too long
        'abc123', // lower case
        'AB 123', // space
        'AB-123', // symbol
        '',
        'ÀBCDE', // accented
      ]) {
        test('rejects "$bad"', () => expect(re.hasMatch(bad), isFalse));
      }
    });
  });

  group('TripService', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late MockQuerySchema schema;
    late MockQueryBuilder trips;
    late MockQueryBuilder requests;
    late MockStorage storage;
    late MockFileApi files;
    late TripService service;

    final draft = TripDraft(
      departureCityId: 1,
      arrivalCityId: 2,
      departureDate: DateTime(2030, 6, 5),
      arrivalDate: DateTime(2030, 6, 6),
      price: 30,
      currency: 'USD',
      maxWeightKg: 3,
      maxSize: 'Backpack size',
      ticketReceiptPath: 'user-1/1.pdf',
    );

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      final user = MockUser();
      schema = MockQuerySchema();
      trips = MockQueryBuilder();
      requests = MockQueryBuilder();
      storage = MockStorage();
      files = MockFileApi();

      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('user-1');
      when(() => client.schema('nata')).thenReturn(schema);
      when(() => schema.from('trips')).thenAnswer((_) => trips);
      when(() => schema.from('delivery_requests')).thenAnswer((_) => requests);
      when(() => client.storage).thenReturn(storage);
      when(() => storage.from('trip-receipts')).thenReturn(files);

      service = TripService(client: client);
    });

    group('myTrips', () {
      test(
        'loads only the signed-in traveler\'s trips, soonest first',
        () async {
          final query = FakeQuery<List<Map<String, dynamic>>>([]);
          when(() => trips.select(any())).thenAnswer((_) => query);

          await service.myTrips();

          expect(query.calls, [
            'eq:traveler_id=user-1',
            'order:departure_date:asc',
          ]);
        },
      );

      test('selects the cities and their country names', () async {
        final query = FakeQuery<List<Map<String, dynamic>>>([]);
        when(() => trips.select(any())).thenAnswer((_) => query);

        await service.myTrips();

        final cols =
            verify(() => trips.select(captureAny())).captured.single as String;
        expect(cols, contains('departure:departure_city_id'));
        expect(cols, contains('arrival:arrival_city_id'));
        expect(cols, contains('countries(name)'));
      });

      test('returns an empty list without asking for request counts', () async {
        when(
          () => trips.select(any()),
        ).thenAnswer((_) => FakeQuery<List<Map<String, dynamic>>>([]));

        expect(await service.myTrips(), isEmpty);
        verifyNever(() => schema.from('delivery_requests'));
      });

      test('adds request and delivered counts per trip', () async {
        when(() => trips.select(any())).thenAnswer(
          (_) => FakeQuery<List<Map<String, dynamic>>>([
            tripRow(id: 'a'),
            tripRow(id: 'b'),
          ]),
        );
        final reqQuery = FakeQuery<List<Map<String, dynamic>>>([
          {'trip_id': 'a', 'status': 'pending'},
          {'trip_id': 'a', 'status': 'delivered'},
          {'trip_id': 'a', 'status': 'delivered'},
        ]);
        when(() => requests.select(any())).thenAnswer((_) => reqQuery);

        final result = await service.myTrips();

        expect(reqQuery.calls, ['in:trip_id=a,b']);
        final a = result.firstWhere((t) => t.id == 'a');
        final b = result.firstWhere((t) => t.id == 'b');
        expect(a.requestsCount, 3);
        expect(a.deliveredCount, 2);
        expect(b.requestsCount, 0);
        expect(b.deliveredCount, 0);
      });

      test(
        'still returns the trips when request counts cannot be read',
        () async {
          when(() => trips.select(any())).thenAnswer(
            (_) => FakeQuery<List<Map<String, dynamic>>>([tripRow(id: 'a')]),
          );
          when(() => requests.select(any())).thenAnswer(
            (_) => FakeQuery<List<Map<String, dynamic>>>(
              [],
              error: Exception('permission denied'),
            ),
          );

          final result = await service.myTrips();

          expect(result.single.id, 'a');
          expect(result.single.requestsCount, 0);
        },
      );

      test('rethrows when the trips cannot be loaded', () async {
        when(() => trips.select(any())).thenAnswer(
          (_) => FakeQuery<List<Map<String, dynamic>>>(
            [],
            error: Exception('network'),
          ),
        );

        expect(service.myTrips(), throwsException);
      });

      test('fails clearly when nobody is signed in', () async {
        when(() => auth.currentUser).thenReturn(null);

        expect(service.myTrips(), throwsA(isA<Exception>()));
      });
    });

    group('createTrip / updateTrip', () {
      test('createTrip inserts the draft for the signed-in traveler', () async {
        final query = FakeQuery<dynamic>(null);
        when(() => trips.insert(any())).thenAnswer((_) => query);

        await service.createTrip(draft);

        final sent =
            verify(() => trips.insert(captureAny())).captured.single
                as Map<String, dynamic>;
        expect(sent['traveler_id'], 'user-1');
        expect(sent['status'], 'live');
        expect(sent['departure_city_id'], 1);
        expect(sent['departure_date'], '2030-06-05');
      });

      test('createTrip surfaces database errors', () async {
        when(
          () => trips.insert(any()),
        ).thenAnswer((_) => FakeQuery<dynamic>(null, error: Exception('rls')));

        expect(service.createTrip(draft), throwsException);
      });

      test('updateTrip only touches that trip and that traveler', () async {
        final query = FakeQuery<dynamic>(null);
        when(() => trips.update(any())).thenAnswer((_) => query);

        await service.updateTrip('trip-9', draft);

        expect(query.calls, ['eq:id=trip-9', 'eq:traveler_id=user-1']);
        final sent =
            verify(() => trips.update(captureAny())).captured.single
                as Map<String, dynamic>;
        expect(sent.containsKey('status'), isFalse);
        expect(sent.containsKey('traveler_id'), isFalse);
      });
    });

    group('receipts', () {
      test('uploads to the private bucket inside the user\'s folder', () async {
        when(
          () => files.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        ).thenAnswer((_) async => 'ok');
        final receipt = PickedReceipt(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'ticket.PDF',
          extension: 'PDF',
        );

        final path = await service.uploadReceipt(receipt);

        expect(path, matches(RegExp(r'^user-1/\d+\.pdf$')));
        final captured = verify(
          () => files.uploadBinary(
            captureAny(),
            captureAny(),
            fileOptions: captureAny(named: 'fileOptions'),
          ),
        ).captured;
        expect(captured[0], path);
        expect(captured[1], receipt.bytes);
        expect((captured[2] as FileOptions).contentType, 'application/pdf');
      });

      test('a failed upload is reported', () async {
        when(
          () => files.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ),
        ).thenThrow(Exception('too big'));

        expect(
          service.uploadReceipt(
            PickedReceipt(bytes: Uint8List(1), name: 'a.pdf', extension: 'pdf'),
          ),
          throwsException,
        );
      });

      test('deleteReceipt removes only the user\'s own files', () async {
        when(() => files.remove(any())).thenAnswer((_) async => []);

        await service.deleteReceipt('user-1/1.pdf');
        verify(() => files.remove(['user-1/1.pdf'])).called(1);

        await service.deleteReceipt('someone-else/1.pdf');
        await service.deleteReceipt('');
        await service.deleteReceipt(null);
        verifyNever(() => files.remove(['someone-else/1.pdf']));
      });

      test('deleteReceipt never throws', () async {
        when(() => files.remove(any())).thenThrow(Exception('gone'));

        await service.deleteReceipt('user-1/1.pdf'); // completes normally
      });
    });
  });

  group('TripDraft.asksForBookingReference', () {
    test('every international trip asks for one', () {
      expect(TripDraft.asksForBookingReference('NG', 'GB'), isTrue);
      expect(TripDraft.asksForBookingReference('CM', 'NG'), isTrue);
      expect(TripDraft.asksForBookingReference('BR', 'AR'), isTrue);
      expect(TripDraft.asksForBookingReference('US', 'FR'), isTrue);
    });

    test('a domestic trip in Africa or South America does not', () {
      for (final iso in [
        'NG',
        'CM',
        'CG',
        'CD',
        'ZA',
        'EG',
        'BR',
        'CO',
        'AR',
      ]) {
        expect(
          TripDraft.asksForBookingReference(iso, iso),
          isFalse,
          reason: iso,
        );
      }
    });

    test('a domestic trip elsewhere still does', () {
      for (final iso in ['US', 'GB', 'FR', 'MX', 'CA']) {
        expect(
          TripDraft.asksForBookingReference(iso, iso),
          isTrue,
          reason: iso,
        );
      }
    });

    test('ignores case and spaces in the country codes', () {
      expect(TripDraft.asksForBookingReference(' ng', 'NG '), isFalse);
    });
  });
}
