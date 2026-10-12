import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a city is (`nata.cities.latitude` / `longitude`).
class CityCoordinates {
  final double latitude;
  final double longitude;
  const CityCoordinates(this.latitude, this.longitude);
}

/// Looks up city coordinates, which the delivery price is based on (the
/// distance between the departure and the arrival city).
class CityService {
  final SupabaseClient _client;
  final Map<String, CityCoordinates> _cache = {};

  CityService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// The coordinates of [city] in the country with ISO code [countryCode], or
  /// null if there is no such city. Throws if the lookup itself fails.
  Future<CityCoordinates?> coordinates(String countryCode, String city) async {
    final key =
        '${countryCode.trim().toUpperCase()}|${city.trim().toLowerCase()}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final row = await _client
        .schema('nata')
        .from('cities')
        .select('latitude, longitude')
        .eq('country_code', countryCode.trim().toUpperCase())
        .eq('name', city.trim())
        .maybeSingle();
    if (row == null) return null;

    final lat = _num(row['latitude']);
    final lon = _num(row['longitude']);
    if (lat == null || lon == null) return null;
    return _cache[key] = CityCoordinates(lat, lon);
  }

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    debugPrint('[CityService] unexpected coordinate value: $v');
    return null;
  }
}
