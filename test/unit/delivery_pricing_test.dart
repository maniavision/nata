import 'package:carrywise_app/services/delivery_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DistanceCalculator.haversine', () {
    double d(double a, double b, double c, double e) =>
        DistanceCalculator.haversine(a, b, c, e);

    test('the same point is 0 km', () {
      expect(d(6.5244, 3.3792, 6.5244, 3.3792), 0);
    });

    test('Lagos to London is about 5,012 km', () {
      expect(d(6.5244, 3.3792, 51.5074, -0.1278), closeTo(5012.31, 0.01));
    });

    test('Accra to Paris is about 4,815 km', () {
      expect(d(5.6037, -0.187, 48.8566, 2.3522), closeTo(4815.48, 0.01));
    });

    test('is the same in both directions', () {
      expect(
        d(6.5244, 3.3792, 51.5074, -0.1278),
        closeTo(d(51.5074, -0.1278, 6.5244, 3.3792), 1e-9),
      );
    });

    test('a quarter of the equator is about 10,008 km', () {
      expect(d(0, 0, 0, 90), closeTo(10007.54, 0.01));
    });

    test('pole to pole is half the circumference, about 20,015 km', () {
      expect(d(90, 0, -90, 0), closeTo(20015.09, 0.01));
    });

    test('crossing the date line takes the short way round', () {
      expect(d(0, 179, 0, -179), closeTo(222.39, 0.01));
    });

    test('one degree of latitude is about 111 km', () {
      expect(d(10, 20, 11, 20), closeTo(111.19, 0.01));
    });

    test('never negative and never NaN', () {
      for (final p in [
        [0.0, 0.0, 0.0, 0.0],
        [90.0, 0.0, 90.0, 180.0],
        [-33.9, 18.4, 35.7, 139.7],
        [51.5, -0.1, 51.5, -0.1000001],
      ]) {
        final km = d(p[0], p[1], p[2], p[3]);
        expect(km.isNaN, isFalse);
        expect(km, greaterThanOrEqualTo(0));
      }
    });
  });

  group('CostCalculator.calculateCost', () {
    // Reference values computed with exact decimal arithmetic and the same
    // rounding as the Java original (BigDecimal, HALF_UP). The SQL function
    // nata.delivery_cost_usd is checked against the same table (see
    // supabase/migrations/20240117_delivery_pricing.sql).
    const cases = [
      (0.0, 24, 0.0, 36.25),
      (100.0, 24, 1.0, 40.48),
      (5000.0, 24, 0.9, 100.68),
      (5000.0, 48, 0.9, 85.05),
      (5000.0, 720, 0.9, 70.47),
      (5000.0, 100000, 3.0, 75.74),
      (4994.6, 168, 2.5, 78.63),
      (1234.5678, 33, 0.45, 44.32),
      (20000.0, 24, 10.0, 313.16),
    ];

    for (final c in cases) {
      test('${c.$1} km, ${c.$2} h, ${c.$3} kg → \$${c.$4}', () {
        expect(
          CostCalculator.calculateCost(
            distanceKm: c.$1,
            deliveryTimeInHours: c.$2,
            weightKg: c.$3,
          ),
          c.$4,
        );
      });
    }

    test('the closer the flight, the more it costs', () {
      double at(int hours) => CostCalculator.calculateCost(
        distanceKm: 5000,
        deliveryTimeInHours: hours,
        weightKg: 1,
      );

      expect(at(24), greaterThan(at(48)));
      expect(at(48), greaterThan(at(168)));
      expect(at(168), greaterThan(at(720)));
      expect(at(720), greaterThan(at(5000)));
    });

    test('a longer distance costs more', () {
      double at(double km) => CostCalculator.calculateCost(
        distanceKm: km,
        deliveryTimeInHours: 72,
        weightKg: 1,
      );

      expect(at(1000), lessThan(at(5000)));
    });

    test('a heavier parcel costs more', () {
      double at(double kg) => CostCalculator.calculateCost(
        distanceKm: 3000,
        deliveryTimeInHours: 72,
        weightKg: kg,
      );

      expect(at(1), lessThan(at(2)));
      expect(at(2) - at(1), closeTo(3.0, 0.011)); // $3 per kg
    });

    test('the result always has whole cents', () {
      for (var km = 0.0; km < 20000; km += 777.7) {
        for (final h in [24, 25, 50, 101, 999]) {
          for (final kg in [0.0, 0.33, 1.25, 7.77]) {
            final v = CostCalculator.calculateCost(
              distanceKm: km,
              deliveryTimeInHours: h,
              weightKg: kg,
            );
            expect(
              (v * 100).roundToDouble(),
              closeTo(v * 100, 1e-6),
              reason: '$km $h $kg → $v',
            );
          }
        }
      }
    });

    test('rounds half up: exactly 20.625 becomes 20.63, not 20.62', () {
      // 5.00 + 750 / 48 h (= 15.6250) = 20.6250: a true half cent.
      expect(
        CostCalculator.calculateCost(
          distanceKm: 0,
          deliveryTimeInHours: 48,
          weightKg: 0,
        ),
        20.63,
      );
    });

    test('the urgency term is rounded to 4 decimals before adding', () {
      // 750 / 168 h = 4.464285… → 4.4643 ; 5 + 4.4643 = 9.4643 → 9.46
      expect(
        CostCalculator.calculateCost(
          distanceKm: 0,
          deliveryTimeInHours: 168,
          weightKg: 0,
        ),
        9.46,
      );
    });

    group('refuses impossible input (as the original does)', () {
      test('negative distance', () {
        expect(
          () => CostCalculator.calculateCost(
            distanceKm: -1,
            deliveryTimeInHours: 24,
            weightKg: 1,
          ),
          throwsArgumentError,
        );
      });

      test('negative weight', () {
        expect(
          () => CostCalculator.calculateCost(
            distanceKm: 1,
            deliveryTimeInHours: 24,
            weightKg: -0.1,
          ),
          throwsArgumentError,
        );
      });

      test('under 24 hours', () {
        expect(
          () => CostCalculator.calculateCost(
            distanceKm: 1,
            deliveryTimeInHours: 23,
            weightKg: 1,
          ),
          throwsArgumentError,
        );
      });
    });

    test('the constants are the agreed ones', () {
      expect(CostCalculator.baseCost, 5.0);
      expect(CostCalculator.costPerKm, 0.0123456789);
      expect(CostCalculator.costPerKg, 3.0);
      expect(CostCalculator.urgencyFactor, 750.0);
      expect(CostCalculator.minimumHours, 24);
    });
  });

  group('DeliveryQuote.hoursUntilDeparture', () {
    int h(DateTime departure, DateTime now) =>
        DeliveryQuote.hoursUntilDeparture(departure, now);

    final now = DateTime.utc(2030, 6, 10, 15, 30);

    test('counts whole days, times 24', () {
      expect(h(DateTime(2030, 6, 20), now), 10 * 24);
      expect(h(DateTime(2030, 7, 10), now), 30 * 24);
    });

    test('tomorrow is exactly the 24-hour minimum', () {
      expect(h(DateTime(2030, 6, 11), now), 24);
    });

    test('a flight today is priced as 24 hours, not 0', () {
      expect(h(DateTime(2030, 6, 10), now), 24);
    });

    test('never goes below 24 hours (guard; trips are never in the past)', () {
      expect(h(DateTime(2030, 6, 1), now), 24);
    });

    test('the time of day does not change it', () {
      expect(h(DateTime(2030, 6, 20), DateTime.utc(2030, 6, 10, 0, 1)), 240);
      expect(h(DateTime(2030, 6, 20), DateTime.utc(2030, 6, 10, 23, 59)), 240);
    });

    test('changes at midnight UTC, the same as the database', () {
      expect(h(DateTime(2030, 6, 20), DateTime.utc(2030, 6, 10, 23, 59)), 240);
      expect(h(DateTime(2030, 6, 20), DateTime.utc(2030, 6, 11, 0, 0)), 216);
    });

    test('uses the UTC day, whatever the phone\'s time zone', () {
      // 23:30 in UTC-5 is already the next day in UTC.
      final local = DateTime.parse('2030-06-10T23:30:00-05:00');
      expect(h(DateTime(2030, 6, 20), local), 9 * 24);
    });
  });

  group('DeliveryQuote.compute', () {
    final now = DateTime.utc(2030, 6, 10, 12);

    test('puts it all together', () {
      final q = DeliveryQuote.compute(
        distanceKm: 5000,
        departureDate: DateTime(2030, 6, 11), // 24 hours away
        now: now,
        weightKg: 0.9,
      );

      expect(q.hours, 24);
      expect(q.costUsd, 100.68);
      expect(q.feeUsd, 10.07); // 10% of 100.68, rounded
      expect(q.totalUsd, 110.75);
    });

    test('a flight further away is cheaper', () {
      final soon = DeliveryQuote.compute(
        distanceKm: 5000,
        departureDate: DateTime(2030, 6, 12),
        now: now,
        weightKg: 1,
      );
      final later = DeliveryQuote.compute(
        distanceKm: 5000,
        departureDate: DateTime(2030, 7, 12),
        now: now,
        weightKg: 1,
      );

      expect(later.totalUsd, lessThan(soon.totalUsd));
    });

    test('the fee is 10% of the cost', () {
      for (final km in [100.0, 2500.0, 9000.0]) {
        final q = DeliveryQuote.compute(
          distanceKm: km,
          departureDate: DateTime(2030, 7, 1),
          now: now,
          weightKg: 2,
        );
        expect(q.feeUsd, closeTo(q.costUsd * 0.10, 0.006));
      }
    });

    test('the total is the cost plus the fee', () {
      final q = DeliveryQuote.compute(
        distanceKm: 4321,
        departureDate: DateTime(2030, 7, 1),
        now: now,
        weightKg: 1.7,
      );

      expect(q.totalUsd, closeTo(q.costUsd + q.feeUsd, 0.0001));
    });

    test('a weight of 0 (not typed yet) still gives a price', () {
      final q = DeliveryQuote.compute(
        distanceKm: 5000,
        departureDate: DateTime(2030, 7, 1),
        now: now,
        weightKg: 0,
      );

      expect(q.costUsd, greaterThan(5));
    });

    test('Lagos to London tomorrow, 0.9 kg', () {
      final km = DistanceCalculator.haversine(6.5244, 3.3792, 51.5074, -0.1278);
      final q = DeliveryQuote.compute(
        distanceKm: km,
        departureDate: DateTime(2030, 6, 11),
        now: now,
        weightKg: 0.9,
      );

      // 5 + 61.88 (5012.31 km) + 2.70 (0.9 kg) + 31.25 (750 / 24 h) = 100.83
      expect(q.costUsd, 100.83);
    });
  });
}
