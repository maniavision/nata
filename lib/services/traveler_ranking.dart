import 'dart:math';

import 'traveler_service.dart';

/// The travelers with the most deliveries, one entry per traveler.
///
/// Travelers are ranked by items delivered, then by rating (unrated last).
/// When a traveler has several trips, their first one in [trips] is used (the
/// search returns the soonest departure first).
List<TravelerTrip> topTravelerPool(
  List<TravelerTrip> trips, {
  int poolSize = 10,
}) {
  final seen = <String>{};
  final unique = <TravelerTrip>[];
  for (final t in trips) {
    if (seen.add(t.travelerId)) unique.add(t);
  }

  // Sort with the original position as the last tie-breaker, so the result
  // does not depend on how the sort treats equal items.
  final indexed = [for (var i = 0; i < unique.length; i++) (i, unique[i])];
  indexed.sort((a, b) {
    final byDeliveries = b.$2.itemsDelivered.compareTo(a.$2.itemsDelivered);
    if (byDeliveries != 0) return byDeliveries;
    final ra = a.$2.avgRating ?? -1;
    final rb = b.$2.avgRating ?? -1;
    final byRating = rb.compareTo(ra);
    if (byRating != 0) return byRating;
    return a.$1.compareTo(b.$1);
  });

  return [for (final e in indexed.take(poolSize)) e.$2];
}

/// Picks [count] travelers at random from the top-delivery pool, so the list
/// can change from one refresh to the next while only ever showing the most
/// experienced travelers. They are shown with the most deliveries first.
List<TravelerTrip> pickTopTravelers(
  List<TravelerTrip> trips,
  Random random, {
  int poolSize = 10,
  int count = 5,
}) {
  final pool = topTravelerPool(trips, poolSize: poolSize);
  final chosen = pool.length <= count
      ? [...pool]
      : ([...pool]..shuffle(random)).take(count).toList();

  // Keep the pool's order (most deliveries first) for display.
  chosen.sort((a, b) => pool.indexOf(a).compareTo(pool.indexOf(b)));
  return chosen;
}
