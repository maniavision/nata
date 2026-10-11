import 'dart:async';

import 'package:carrywise_app/services/traveler_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// What `client.rpc(...)` returns: something `await`-able that yields [value]
/// (or throws [error]).
class FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeRpcBuilder({this.value, this.error});
  final dynamic value;
  final Object? error;

  @override
  Future<U> then<U>(FutureOr<U> Function(dynamic value) onValue,
      {Function? onError}) {
    final future = error != null
        ? Future<dynamic>.error(error!)
        : Future<dynamic>.value(value);
    return future.then(onValue, onError: onError);
  }
}

Map<String, dynamic> tripJson({
  String tripId = 'trip-1',
  String travelerId = 'user-1',
  String firstName = 'Amara',
  String lastName = 'Kalu',
  Object? avgRating = 4.9,
  Object? maxWeight = 3.0,
}) =>
    {
      'trip_id': tripId,
      'traveler_id': travelerId,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_path': 'https://example.com/a.jpg',
      'avg_rating': avgRating,
      'items_delivered_count': 28,
      'departure_city': 'Lagos',
      'departure_country': 'NG',
      'arrival_city': 'London',
      'arrival_country': 'GB',
      'departure_date': '2030-06-22',
      'arrival_date': '2030-06-23',
      'price': 35,
      'currency': 'USD',
      'max_weight_kg': maxWeight,
      'max_size': 'Shoebox',
    };

void main() {
  group('TravelerTrip.fromJson', () {
    test('parses every field', () {
      final t = TravelerTrip.fromJson(tripJson());

      expect(t.tripId, 'trip-1');
      expect(t.travelerId, 'user-1');
      expect(t.fullName, 'Amara Kalu');
      expect(t.avatarPath, 'https://example.com/a.jpg');
      expect(t.avgRating, 4.9);
      expect(t.itemsDelivered, 28);
      expect(t.departureCity, 'Lagos');
      expect(t.departureCountry, 'NG');
      expect(t.arrivalCity, 'London');
      expect(t.arrivalCountry, 'GB');
      expect(t.departureDate, DateTime(2030, 6, 22));
      expect(t.arrivalDate, DateTime(2030, 6, 23));
      expect(t.price, 35.0);
      expect(t.currency, 'USD');
      expect(t.maxWeightKg, 3.0);
      expect(t.maxSize, 'Shoebox');
    });

    test('accepts ints where the database sends numeric values', () {
      final t = TravelerTrip.fromJson(tripJson(avgRating: 5, maxWeight: 10));

      expect(t.avgRating, 5.0);
      expect(t.maxWeightKg, 10.0);
    });

    test('keeps missing optional values as null', () {
      final t = TravelerTrip.fromJson(
          tripJson(avgRating: null, maxWeight: null)..['max_size'] = null);

      expect(t.avgRating, isNull);
      expect(t.maxWeightKg, isNull);
      expect(t.maxSize, isNull);
    });

    test('trims the padded currency code from a char(3) column', () {
      final t = TravelerTrip.fromJson(tripJson()..['currency'] = 'XO ');

      expect(t.currency, 'XO');
    });

    test('fullName copes with a missing last name', () {
      final t = TravelerTrip.fromJson(tripJson(lastName: ''));

      expect(t.fullName, 'Amara');
    });
  });

  group('TravelerProfile.fromJson', () {
    Map<String, dynamic> profileJson({List<Map<String, dynamic>>? trips}) => {
          'id': 'user-1',
          'first_name': 'Amara',
          'last_name': 'Kalu',
          'avatar_path': 'https://example.com/a.jpg',
          'verification_status': 'verified',
          'avg_rating': 4.9,
          'items_delivered_count': 28,
          'member_since': '2025-03-01T10:00:00+00:00',
          // Trips from the database do NOT repeat the traveler fields.
          'trips': trips ??
              [
                {
                  'trip_id': 'trip-1',
                  'traveler_id': 'user-1',
                  'departure_city': 'Lagos',
                  'departure_country': 'NG',
                  'arrival_city': 'London',
                  'arrival_country': 'GB',
                  'departure_date': '2030-06-22',
                  'arrival_date': '2030-06-22',
                  'price': 35,
                  'currency': 'USD',
                  'max_weight_kg': 3,
                  'max_size': 'Shoebox',
                },
              ],
        };

    test('parses the profile', () {
      final p = TravelerProfile.fromJson(profileJson());

      expect(p.id, 'user-1');
      expect(p.fullName, 'Amara Kalu');
      expect(p.isVerified, isTrue);
      expect(p.avgRating, 4.9);
      expect(p.itemsDelivered, 28);
      expect(p.memberSince?.year, 2025);
    });

    test('each trip carries the traveler\'s name, rating and avatar', () {
      final p = TravelerProfile.fromJson(profileJson());

      final trip = p.trips.single;
      expect(trip.fullName, 'Amara Kalu');
      expect(trip.avgRating, 4.9);
      expect(trip.itemsDelivered, 28);
      expect(trip.avatarPath, 'https://example.com/a.jpg');
      expect(trip.departureCity, 'Lagos');
    });

    test('no trips gives an empty list', () {
      final p = TravelerProfile.fromJson(profileJson(trips: []));

      expect(p.trips, isEmpty);
    });

    test('a missing trips key gives an empty list', () {
      final json = profileJson()..remove('trips');

      expect(TravelerProfile.fromJson(json).trips, isEmpty);
    });

    test('unverified travelers are not marked verified', () {
      final json = profileJson()..['verification_status'] = 'pending';

      expect(TravelerProfile.fromJson(json).isVerified, isFalse);
    });
  });

  group('TravelerService.search', () {
    late MockSupabaseClient client;
    late TravelerService service;

    setUp(() {
      client = MockSupabaseClient();
      service = TravelerService(client: client);
    });

    Map<dynamic, dynamic> sentParams() {
      final captured = verify(() => client.rpc<dynamic>(
            'search_travelers',
            params: captureAny(named: 'params'),
          )).captured;
      return captured.single as Map<dynamic, dynamic>;
    }

    test('returns the parsed trips', () async {
      when(() => client.rpc<dynamic>('search_travelers',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(value: [
                tripJson(),
                tripJson(tripId: 'trip-2', firstName: 'Daniel'),
              ]));

      final results = await service.search();

      expect(results.map((t) => t.tripId), ['trip-1', 'trip-2']);
      expect(results.last.firstName, 'Daniel');
    });

    test('sends only the filters that were provided', () async {
      when(() => client.rpc<dynamic>('search_travelers',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(value: []));

      await service.search(departureCountry: 'NG', departureCity: 'Lagos');

      expect(sentParams(), {
        'p_departure_country': 'NG',
        'p_departure_city': 'Lagos',
        'p_limit': 50,
      });
    });

    test('formats the date as yyyy-MM-dd', () async {
      when(() => client.rpc<dynamic>('search_travelers',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(value: []));

      await service.search(date: DateTime(2030, 6, 5, 18, 30));

      expect(sentParams()['p_date'], '2030-06-05');
    });

    test('sends the destination and the limit', () async {
      when(() => client.rpc<dynamic>('search_travelers',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(value: []));

      await service.search(
          arrivalCountry: 'GB', arrivalCity: 'London', limit: 100);

      final params = sentParams();
      expect(params['p_arrival_country'], 'GB');
      expect(params['p_arrival_city'], 'London');
      expect(params['p_limit'], 100);
      expect(params.containsKey('p_date'), isFalse);
    });

    test('rethrows failures so screens can show an error state', () async {
      when(() => client.rpc<dynamic>('search_travelers',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(error: Exception('boom')));

      expect(service.search(), throwsException);
    });
  });

  group('TravelerService.getProfile', () {
    late MockSupabaseClient client;
    late TravelerService service;

    setUp(() {
      client = MockSupabaseClient();
      service = TravelerService(client: client);
    });

    test('asks for the right traveler and parses the result', () async {
      when(() => client.rpc<dynamic>('get_traveler_profile',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(value: {
                'id': 'user-1',
                'first_name': 'Amara',
                'last_name': 'Kalu',
                'verification_status': 'verified',
                'items_delivered_count': 28,
                'trips': <dynamic>[],
              }));

      final profile = await service.getProfile('user-1');

      expect(profile?.fullName, 'Amara Kalu');
      verify(() => client.rpc<dynamic>('get_traveler_profile',
          params: {'p_traveler_id': 'user-1'})).called(1);
    });

    test('returns null when the traveler does not exist', () async {
      when(() => client.rpc<dynamic>('get_traveler_profile',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(value: null));

      expect(await service.getProfile('missing'), isNull);
    });
  });
}
