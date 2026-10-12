import 'dart:math';

/// Distance between two points on Earth (the Haversine formula).
class DistanceCalculator {
  /// Earth's radius in kilometres.
  static const earthRadiusKm = 6371;

  /// The distance in kilometres between two latitude / longitude points given
  /// in degrees.
  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    double rad(double deg) => deg * pi / 180;

    final lat1Rad = rad(lat1);
    final lat2Rad = rad(lat2);
    final dLat = rad(lat2) - lat1Rad;
    final dLon = rad(lon2) - rad(lon1);

    final a =
        pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final c = 2 * asin(sqrt(a));
    return earthRadiusKm * c;
  }
}

/// The delivery cost, in US dollars.
///
/// Mirrors the CostCalculator used by the Nata back end. The database
/// (`nata.delivery_cost_usd`, migration 20240117) runs the same formula when a
/// request is saved, so the price the sender sees is the one that is stored.
///
/// cost = 5.00 + distanceKm × 0.0123456789 + weightKg × 3.00 + 750 ÷ hours
///
/// The closer the flight, the fewer hours, the bigger the last term.
class CostCalculator {
  static const baseCost = 5.0;
  static const costPerKm = 0.0123456789;
  static const costPerKg = 3.0;
  static const urgencyFactor = 750.0;

  /// A delivery is priced as if it had at least this many hours.
  static const minimumHours = 24;

  /// Whole dollars-and-cents, rounded half up (like Java's BigDecimal).
  static double calculateCost({
    required double distanceKm,
    required int deliveryTimeInHours,
    required double weightKg,
  }) {
    if (distanceKm < 0) {
      throw ArgumentError('Distance cannot be negative.');
    }
    if (weightKg < 0) {
      throw ArgumentError('Weight cannot be negative.');
    }
    if (deliveryTimeInHours < minimumHours) {
      throw ArgumentError(
        'Delivery time must be at least $minimumHours hours.',
      );
    }

    final distanceCost = distanceKm * costPerKm;
    final weightCost = weightKg * costPerKg;
    // The urgency term is rounded to 4 decimals first, as in the original.
    final urgencyCost = _roundHalfUp(urgencyFactor / deliveryTimeInHours, 4);

    return _roundHalfUp(baseCost + distanceCost + weightCost + urgencyCost, 2);
  }

  /// Rounds half up. The tiny nudge keeps values such as 27.485, which a
  /// double stores as 27.48499999..., from rounding the wrong way.
  static double _roundHalfUp(double value, int decimals) {
    final f = pow(10, decimals).toDouble();
    return ((value * f) + 1e-9).round() / f;
  }
}

/// Everything about the price of one request, in US dollars.
class DeliveryQuote {
  /// Kilometres between the departure and the arrival city.
  final double distanceKm;

  /// The hours the price is based on (at least 24).
  final int hours;

  final double weightKg;

  /// The delivery cost.
  final double costUsd;

  /// Platform protection & escrow: 10% of the cost.
  final double feeUsd;

  const DeliveryQuote({
    required this.distanceKm,
    required this.hours,
    required this.weightKg,
    required this.costUsd,
    required this.feeUsd,
  });

  static const feeRate = 0.10;

  double get totalUsd => _cents(costUsd + feeUsd);

  /// The hours from [now] to the day of departure. A trip only has a date, so
  /// whole days are counted (in UTC, the same as the database). A flight
  /// today (under a whole day away) is priced as 24 hours. Trips are never
  /// in the past; the minimum also keeps the formula from dividing by zero.
  static int hoursUntilDeparture(DateTime departureDate, DateTime now) {
    final today = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day,
    );
    final departure = DateTime.utc(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final days = departure.difference(today).inDays;
    final hours = days * 24;
    return hours < CostCalculator.minimumHours
        ? CostCalculator.minimumHours
        : hours;
  }

  factory DeliveryQuote.compute({
    required double distanceKm,
    required DateTime departureDate,
    required DateTime now,
    required double weightKg,
  }) {
    final hours = hoursUntilDeparture(departureDate, now);
    final cost = CostCalculator.calculateCost(
      distanceKm: distanceKm,
      deliveryTimeInHours: hours,
      weightKg: weightKg,
    );
    return DeliveryQuote(
      distanceKm: distanceKm,
      hours: hours,
      weightKg: weightKg,
      costUsd: cost,
      feeUsd: _cents(cost * feeRate),
    );
  }

  static double _cents(double v) => ((v * 100) + 1e-9).round() / 100;
}
