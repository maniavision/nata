import 'package:supabase_flutter/supabase_flutter.dart';

/// A route the member often sends on: they are notified when a trip on it
/// goes live (migration 20240159).
class RouteAlert {
  final String id;
  final int fromCityId;
  final String fromCity;
  final String fromCountryCode;
  final String fromCountry;
  final int toCityId;
  final String toCity;
  final String toCountryCode;
  final String toCountry;

  const RouteAlert({
    required this.id,
    required this.fromCityId,
    required this.fromCity,
    required this.fromCountryCode,
    required this.fromCountry,
    required this.toCityId,
    required this.toCity,
    required this.toCountryCode,
    required this.toCountry,
  });

  factory RouteAlert.fromJson(Map<String, dynamic> j) => RouteAlert(
    id: j['id'] as String,
    fromCityId: (j['from_city_id'] as num).toInt(),
    fromCity: j['from_city'] as String? ?? '',
    fromCountryCode: j['from_country_code'] as String? ?? '',
    fromCountry: j['from_country'] as String? ?? '',
    toCityId: (j['to_city_id'] as num).toInt(),
    toCity: j['to_city'] as String? ?? '',
    toCountryCode: j['to_country_code'] as String? ?? '',
    toCountry: j['to_country'] as String? ?? '',
  );
}

/// Why a route could not be saved.
enum RouteAlertFailure { limit, exists, samePlace, failed }

class RouteAlertException implements Exception {
  final RouteAlertFailure reason;
  const RouteAlertException(this.reason);
}

class RouteAlertService {
  /// The most routes a member can save (enforced on the server too).
  static const maxRoutes = 5;

  final SupabaseClient _client;
  RouteAlertService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// The member's routes, newest first.
  Future<List<RouteAlert>> list() async {
    final rows = await _client.rpc('my_route_alerts') as List<dynamic>;
    return rows
        .map((r) => RouteAlert.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Saves a route. Throws [RouteAlertException].
  Future<void> add({required int fromCityId, required int toCityId}) async {
    if (fromCityId == toCityId) {
      throw const RouteAlertException(RouteAlertFailure.samePlace);
    }
    try {
      await _client.schema('nata').from('route_alerts').insert({
        'from_city_id': fromCityId,
        'to_city_id': toCityId,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('route_alert_limit')) {
        throw const RouteAlertException(RouteAlertFailure.limit);
      }
      if (e.code == '23505') {
        throw const RouteAlertException(RouteAlertFailure.exists);
      }
      throw const RouteAlertException(RouteAlertFailure.failed);
    }
  }

  Future<void> remove(String id) =>
      _client.schema('nata').from('route_alerts').delete().eq('id', id);
}
