import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a country entry from nata.countries.
class Country {
  final String isoCode;
  final String name;
  final String phoneCode;

  const Country({
    required this.isoCode,
    required this.name,
    required this.phoneCode,
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        isoCode: (json['iso_code'] as String? ?? '').trim(),
        name: (json['name'] as String? ?? '').trim(),
        phoneCode: (json['phone_code'] as String? ?? '').trim(),
      );

  @override
  String toString() => name;
}

/// Searches countries from nata.countries via the public RPC function.
/// Falls back to the bundled list if the DB has no rows or the RPC
/// isn't set up yet.
class CountryService {
  static final CountryService _instance = CountryService._();
  factory CountryService() => _instance;
  CountryService._();

  /// Cached full list after first load.
  List<Country>? _cache;

  /// Every known country, alphabetically. Used to list them all before the
  /// user types anything (including the one currently selected).
  Future<List<Country>> all() async {
    final list = [...await _loadAll()];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Returns countries whose name starts with or contains [query].
  Future<List<Country>> search(String query) async {
    final all = await _loadAll();
    if (query.trim().isEmpty) return all.take(8).toList();
    final q = query.toLowerCase();
    return all
        .where((c) => c.name.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  /// The country with this ISO code (e.g. 'US'), or null if it is unknown.
  Future<Country?> byIsoCode(String isoCode) async {
    final iso = isoCode.trim().toUpperCase();
    final all = await _loadAll();
    for (final c in all) {
      if (c.isoCode.toUpperCase() == iso) return c;
    }
    return null;
  }

  Future<List<Country>> _loadAll() async {
    if (_cache != null) return _cache!;

    try {
      // Query nata.countries directly via PostgREST (nata schema is exposed).
      // Requires the RLS policy "public read countries" to be applied:
      //   CREATE POLICY "public read countries" ON nata.countries FOR SELECT USING (true);
      final rows = await Supabase.instance.client
          .schema('nata')
          .from('countries')
          .select('iso_code, name, phone_code')
          .order('name') as List<dynamic>;

      if (rows.isNotEmpty) {
        _cache = rows
            .map((r) => Country.fromJson(r as Map<String, dynamic>))
            .toList();
        return _cache!;
      }
    } catch (_) {
      // RLS not configured yet or schema not exposed — fall through to bundled list.
    }

    _cache = _bundled;
    return _cache!;
  }

  /// Bundled list — covers the most common countries for the app's market.
  /// Populated from Africa, Europe, North America, Middle East.
  static const List<Country> _bundled = [
    Country(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234'),
    Country(isoCode: 'GH', name: 'Ghana', phoneCode: '+233'),
    Country(isoCode: 'KE', name: 'Kenya', phoneCode: '+254'),
    Country(isoCode: 'ZA', name: 'South Africa', phoneCode: '+27'),
    Country(isoCode: 'TZ', name: 'Tanzania', phoneCode: '+255'),
    Country(isoCode: 'UG', name: 'Uganda', phoneCode: '+256'),
    Country(isoCode: 'ET', name: 'Ethiopia', phoneCode: '+251'),
    Country(isoCode: 'CI', name: "Côte d'Ivoire", phoneCode: '+225'),
    Country(isoCode: 'SN', name: 'Senegal', phoneCode: '+221'),
    Country(isoCode: 'CM', name: 'Cameroon', phoneCode: '+237'),
    Country(isoCode: 'EG', name: 'Egypt', phoneCode: '+20'),
    Country(isoCode: 'MA', name: 'Morocco', phoneCode: '+212'),
    Country(isoCode: 'DZ', name: 'Algeria', phoneCode: '+213'),
    Country(isoCode: 'TN', name: 'Tunisia', phoneCode: '+216'),
    Country(isoCode: 'AO', name: 'Angola', phoneCode: '+244'),
    Country(isoCode: 'ZM', name: 'Zambia', phoneCode: '+260'),
    Country(isoCode: 'ZW', name: 'Zimbabwe', phoneCode: '+263'),
    Country(isoCode: 'RW', name: 'Rwanda', phoneCode: '+250'),
    Country(isoCode: 'CD', name: 'DR Congo', phoneCode: '+243'),
    Country(isoCode: 'GB', name: 'United Kingdom', phoneCode: '+44'),
    Country(isoCode: 'US', name: 'United States', phoneCode: '+1'),
    Country(isoCode: 'CA', name: 'Canada', phoneCode: '+1'),
    Country(isoCode: 'FR', name: 'France', phoneCode: '+33'),
    Country(isoCode: 'DE', name: 'Germany', phoneCode: '+49'),
    Country(isoCode: 'IT', name: 'Italy', phoneCode: '+39'),
    Country(isoCode: 'ES', name: 'Spain', phoneCode: '+34'),
    Country(isoCode: 'NL', name: 'Netherlands', phoneCode: '+31'),
    Country(isoCode: 'BE', name: 'Belgium', phoneCode: '+32'),
    Country(isoCode: 'PT', name: 'Portugal', phoneCode: '+351'),
    Country(isoCode: 'CH', name: 'Switzerland', phoneCode: '+41'),
    Country(isoCode: 'SE', name: 'Sweden', phoneCode: '+46'),
    Country(isoCode: 'NO', name: 'Norway', phoneCode: '+47'),
    Country(isoCode: 'DK', name: 'Denmark', phoneCode: '+45'),
    Country(isoCode: 'AE', name: 'UAE', phoneCode: '+971'),
    Country(isoCode: 'SA', name: 'Saudi Arabia', phoneCode: '+966'),
    Country(isoCode: 'QA', name: 'Qatar', phoneCode: '+974'),
    Country(isoCode: 'CN', name: 'China', phoneCode: '+86'),
    Country(isoCode: 'IN', name: 'India', phoneCode: '+91'),
    Country(isoCode: 'AU', name: 'Australia', phoneCode: '+61'),
    Country(isoCode: 'BR', name: 'Brazil', phoneCode: '+55'),
  ];
}
