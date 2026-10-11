import 'dart:math';

import 'package:carrywise_app/services/traveler_ranking.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/fakes.dart';

TravelerTrip trav(
  String id, {
  int delivered = 10,
  double? rating = 4.5,
  String tripId = '',
  String city = 'Lagos',
}) =>
    sampleTrip(
      tripId: tripId.isEmpty ? 'trip-$id' : tripId,
      travelerId: id,
      firstName: id,
      lastName: 'X',
      itemsDelivered: delivered,
      avgRating: rating,
      departureCity: city,
    );

List<String> ids(List<TravelerTrip> l) => l.map((t) => t.travelerId).toList();

void main() {
  group('topTravelerPool', () {
    test('ranks by deliveries, most first', () {
      final pool = topTravelerPool([
        trav('a', delivered: 5),
        trav('b', delivered: 50),
        trav('c', delivered: 20),
      ]);

      expect(ids(pool), ['b', 'c', 'a']);
    });

    test('keeps only the top N', () {
      final trips = [for (var i = 1; i <= 20; i++) trav('t$i', delivered: i)];

      final pool = topTravelerPool(trips, poolSize: 10);

      expect(pool.length, 10);
      expect(ids(pool).first, 't20');
      expect(ids(pool).last, 't11');
    });

    test('the default pool is the top 10', () {
      final trips = [for (var i = 1; i <= 30; i++) trav('t$i', delivered: i)];

      expect(topTravelerPool(trips).length, 10);
    });

    test('ties are broken by rating, higher first', () {
      final pool = topTravelerPool([
        trav('low', delivered: 10, rating: 4.1),
        trav('high', delivered: 10, rating: 4.9),
      ]);

      expect(ids(pool), ['high', 'low']);
    });

    test('unrated travelers come after rated ones on a tie', () {
      final pool = topTravelerPool([
        trav('new', delivered: 10, rating: null),
        trav('rated', delivered: 10, rating: 3.0),
      ]);

      expect(ids(pool), ['rated', 'new']);
    });

    test('a full tie keeps the original order', () {
      final pool = topTravelerPool([
        trav('first', delivered: 10, rating: 4.5),
        trav('second', delivered: 10, rating: 4.5),
        trav('third', delivered: 10, rating: 4.5),
      ]);

      expect(ids(pool), ['first', 'second', 'third']);
    });

    test('a traveler with several trips appears once, with their first trip',
        () {
      final pool = topTravelerPool([
        trav('a', delivered: 30, tripId: 'a-soon', city: 'Lagos'),
        trav('b', delivered: 10),
        trav('a', delivered: 30, tripId: 'a-later', city: 'Abuja'),
      ]);

      expect(ids(pool), ['a', 'b']);
      expect(pool.first.tripId, 'a-soon');
    });

    test('an empty list gives an empty pool', () {
      expect(topTravelerPool([]), isEmpty);
    });

    test('does not change the list it is given', () {
      final trips = [trav('a', delivered: 1), trav('b', delivered: 9)];

      topTravelerPool(trips);

      expect(ids(trips), ['a', 'b']);
    });
  });

  group('pickTopTravelers', () {
    final many = [for (var i = 1; i <= 25; i++) trav('t$i', delivered: i)];
    // The 10 travelers with the most deliveries: t16 .. t25.
    final top10 = {for (var i = 16; i <= 25; i++) 't$i'};

    test('picks 5 by default', () {
      expect(pickTopTravelers(many, Random(1)).length, 5);
    });

    test('only ever picks from the top-delivery pool', () {
      for (var seed = 0; seed < 200; seed++) {
        final picked = ids(pickTopTravelers(many, Random(seed)));
        expect(top10.containsAll(picked), isTrue,
            reason: 'seed $seed picked $picked');
      }
    });

    test('never picks the same traveler twice', () {
      for (var seed = 0; seed < 50; seed++) {
        final picked = ids(pickTopTravelers(many, Random(seed)));
        expect(picked.toSet().length, picked.length);
      }
    });

    test('is shown with the most deliveries first', () {
      for (var seed = 0; seed < 50; seed++) {
        final picked = pickTopTravelers(many, Random(seed));
        final deliveries = picked.map((t) => t.itemsDelivered).toList();
        expect(deliveries, [...deliveries]..sort((a, b) => b.compareTo(a)));
      }
    });

    test('the same seed gives the same picks', () {
      expect(ids(pickTopTravelers(many, Random(7))),
          ids(pickTopTravelers(many, Random(7))));
    });

    test('different draws give different travelers over time', () {
      final random = Random(42);
      final sets = {
        for (var i = 0; i < 12; i++)
          ids(pickTopTravelers(many, random)).join(','),
      };

      expect(sets.length, greaterThan(3));
    });

    test('over many draws every top traveler gets a turn', () {
      final random = Random(3);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.addAll(ids(pickTopTravelers(many, random)));
      }

      expect(seen, top10);
    });

    test('with 5 or fewer travelers it shows all of them', () {
      final few = [for (var i = 1; i <= 4; i++) trav('t$i', delivered: i)];

      expect(ids(pickTopTravelers(few, Random(1))), ['t4', 't3', 't2', 't1']);
    });

    test('exactly 5 travelers are all shown', () {
      final five = [for (var i = 1; i <= 5; i++) trav('t$i', delivered: i)];

      expect(pickTopTravelers(five, Random(9)).length, 5);
    });

    test('with 6 to 10 travelers it still picks 5 of them', () {
      final eight = [for (var i = 1; i <= 8; i++) trav('t$i', delivered: i)];

      final picked = pickTopTravelers(eight, Random(5));

      expect(picked.length, 5);
      expect(eight.map((t) => t.travelerId).toSet().containsAll(ids(picked)),
          isTrue);
    });

    test('an empty list gives nothing', () {
      expect(pickTopTravelers([], Random(1)), isEmpty);
    });

    test('count and pool size can be changed', () {
      final picked = pickTopTravelers(many, Random(1), poolSize: 3, count: 2);

      expect(picked.length, 2);
      expect({'t25', 't24', 't23'}.containsAll(ids(picked)), isTrue);
    });
  });
}
