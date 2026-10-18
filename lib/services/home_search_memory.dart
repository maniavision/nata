import '../widgets/location_search_sheet.dart';

/// What the user last entered in the Home search (departure, destination,
/// date), kept in memory so it is still there when they come back to Home
/// from another page. Home is rebuilt from scratch each time it is opened, so
/// its own state cannot hold it.
///
/// Lasts until the app is closed or the user signs out ([clear]).
class HomeSearchMemory {
  HomeSearchMemory._();

  static LocationSelection? departure;
  static LocationSelection? destination;
  static DateTime? date;
  static bool flexible = false;

  /// The remembered date, or null when it has passed (yesterday's date is no
  /// use to search with).
  static DateTime? dateFrom(DateTime now) {
    final d = date;
    if (d == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).isBefore(today) ? null : d;
  }

  static void clear() {
    departure = null;
    destination = null;
    date = null;
    flexible = false;
  }
}
