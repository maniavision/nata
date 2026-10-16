import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A country result from nata.countries.
class CountryResult {
  final String isoCode;
  final String name;
  final String phoneCode;

  const CountryResult({
    required this.isoCode,
    required this.name,
    required this.phoneCode,
  });

  factory CountryResult.fromJson(Map<String, dynamic> j) => CountryResult(
    isoCode: (j['iso_code'] as String? ?? '').trim(),
    name: (j['name'] as String? ?? '').trim(),
    phoneCode: (j['phone_code'] as String? ?? '').trim(),
  );

  /// Display label shown in the UI.
  String get displayName => name;

  @override
  String toString() => name;
}

/// A city result from nata.cities joined with nata.countries.
class CityResult {
  final int id;
  final String name;
  final String countryCode;
  final String countryName;

  const CityResult({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
  });

  factory CityResult.fromJson(Map<String, dynamic> j) {
    final country = j['countries'] as Map<String, dynamic>? ?? {};
    return CityResult(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String? ?? '').trim(),
      countryCode: (j['country_code'] as String? ?? '').trim(),
      countryName: (country['name'] as String? ?? '').trim(),
    );
  }

  /// e.g. "Lagos, Nigeria"
  String get displayName => '$name, $countryName';

  @override
  String toString() => displayName;
}

/// Queries nata.countries and nata.cities with autocomplete search.
/// Falls back to bundled data if Supabase is unreachable or RLS blocks.
class LocationSearchService {
  static final LocationSearchService _instance = LocationSearchService._();
  factory LocationSearchService() => _instance;
  LocationSearchService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// A to Z, ignoring case. The database is also asked for ascending order
  /// (supabase-dart's `order()` is descending unless told otherwise), which
  /// matters because results are capped; this keeps the list right whatever
  /// the server sends.
  @visibleForTesting
  static List<T> sortByName<T>(Iterable<T> items, String Function(T) name) =>
      items.toList()..sort(
        (a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()),
      );

  /// Every country fits (there are fewer than 300), so the list is complete
  /// before the user types anything.
  static const _maxCountries = 300;

  /// Enough to browse a country's cities; typing narrows it down.
  static const _maxCities = 200;

  // ── Countries ─────────────────────────────────────────────────────────────

  Future<List<CountryResult>> searchCountries(String query) async {
    if (query.trim().isEmpty) {
      return _searchCountriesRemote('');
    }
    try {
      return await _searchCountriesRemote(query);
    } catch (e) {
      debugPrint('[LocationSearch] countries error: $e');
      return sortByName(
        _bundledCountries
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .take(8),
        (c) => c.name,
      );
    }
  }

  Future<List<CountryResult>> _searchCountriesRemote(String query) async {
    final q = query.trim();
    List<dynamic> rows;

    if (q.isEmpty) {
      rows =
          await _client
                  .schema('nata')
                  .from('countries')
                  .select('iso_code, name, phone_code')
                  .order('name', ascending: true)
                  .limit(_maxCountries)
              as List<dynamic>;
    } else {
      rows =
          await _client
                  .schema('nata')
                  .from('countries')
                  .select('iso_code, name, phone_code')
                  .ilike('name', '%$q%')
                  .order('name', ascending: true)
                  .limit(_maxCountries)
              as List<dynamic>;
    }

    return sortByName(
      rows.map((r) => CountryResult.fromJson(r as Map<String, dynamic>)),
      (c) => c.name,
    );
  }

  // ── Cities ────────────────────────────────────────────────────────────────

  Future<List<CityResult>> searchCities(
    String query, {
    String? countryCode,
  }) async {
    if (query.trim().length < 2 && countryCode == null) return [];
    try {
      return await _searchCitiesRemote(query, countryCode: countryCode);
    } catch (e) {
      debugPrint('[LocationSearch] cities error: $e');
      return [];
    }
  }

  Future<List<CityResult>> _searchCitiesRemote(
    String query, {
    String? countryCode,
  }) async {
    final q = query.trim();
    List<dynamic> rows;

    // Build query with filters before limit
    if (countryCode != null && q.isNotEmpty) {
      rows =
          await _client
                  .schema('nata')
                  .from('cities')
                  .select('id, name, country_code, countries!inner(name)')
                  .eq('country_code', countryCode)
                  .ilike('name', '%$q%')
                  .order('name', ascending: true)
                  .limit(_maxCities)
              as List<dynamic>;
    } else if (countryCode != null) {
      rows =
          await _client
                  .schema('nata')
                  .from('cities')
                  .select('id, name, country_code, countries!inner(name)')
                  .eq('country_code', countryCode)
                  .order('name', ascending: true)
                  .limit(_maxCities)
              as List<dynamic>;
    } else if (q.isNotEmpty) {
      rows =
          await _client
                  .schema('nata')
                  .from('cities')
                  .select('id, name, country_code, countries!inner(name)')
                  .ilike('name', '%$q%')
                  .order('name', ascending: true)
                  .limit(_maxCities)
              as List<dynamic>;
    } else {
      rows =
          await _client
                  .schema('nata')
                  .from('cities')
                  .select('id, name, country_code, countries!inner(name)')
                  .order('name', ascending: true)
                  .limit(_maxCities)
              as List<dynamic>;
    }

    return sortByName(
      rows.map((r) => CityResult.fromJson(r as Map<String, dynamic>)),
      (c) => c.name,
    );
  }

  // ── Bundled fallback (subset of major cities) ─────────────────────────────

  static const _bundledCountries = [
    CountryResult(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234'),
    CountryResult(isoCode: 'GH', name: 'Ghana', phoneCode: '+233'),
    CountryResult(isoCode: 'KE', name: 'Kenya', phoneCode: '+254'),
    CountryResult(isoCode: 'ZA', name: 'South Africa', phoneCode: '+27'),
    CountryResult(isoCode: 'GB', name: 'United Kingdom', phoneCode: '+44'),
    CountryResult(isoCode: 'US', name: 'United States', phoneCode: '+1'),
    CountryResult(isoCode: 'FR', name: 'France', phoneCode: '+33'),
    CountryResult(isoCode: 'DE', name: 'Germany', phoneCode: '+49'),
    CountryResult(
      isoCode: 'AE',
      name: 'United Arab Emirates',
      phoneCode: '+971',
    ),
    CountryResult(isoCode: 'CN', name: 'China', phoneCode: '+86'),
    CountryResult(isoCode: 'IN', name: 'India', phoneCode: '+91'),
    CountryResult(isoCode: 'BR', name: 'Brazil', phoneCode: '+55'),
    CountryResult(isoCode: 'CA', name: 'Canada', phoneCode: '+1'),
    CountryResult(isoCode: 'SN', name: 'Senegal', phoneCode: '+221'),
    CountryResult(isoCode: 'CI', name: "Côte d'Ivoire", phoneCode: '+225'),
    CountryResult(isoCode: 'EG', name: 'Egypt', phoneCode: '+20'),
    CountryResult(isoCode: 'ET', name: 'Ethiopia', phoneCode: '+251'),
    CountryResult(isoCode: 'CM', name: 'Cameroon', phoneCode: '+237'),
  ];
}
