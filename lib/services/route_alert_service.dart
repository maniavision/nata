import 'package:supabase_flutter/supabase_flutter.dart';

/// A route the member often sends on: they are notified when a trip on it
/// goes live (migration 20240159), up to [maxAlerts] travelers (20240168),
/// and only those who can carry [minWeightKg] when it is set (20240177).
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

  /// How many travelers to be notified about; null for every one.
  final int? maxAlerts;

  /// How many travelers were notified about so far.
  final int alertsSent;

  /// What the member wants to send, in kg; null for any weight.
  final double? minWeightKg;

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
    this.maxAlerts,
    this.alertsSent = 0,
    this.minWeightKg,
  });

  /// Reached its limit: quiet until restarted.
  bool get done => maxAlerts != null && alertsSent >= maxAlerts!;

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
    maxAlerts: (j['max_alerts'] as num?)?.toInt(),
    alertsSent: (j['alerts_sent'] as num?)?.toInt() ?? 0,
    minWeightKg: switch (j['min_weight_kg']) {
      final num v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    },
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

  /// The travelers limits offered when saving a route; null is every one.
  static const travelerLimits = <int?>[1, 3, 5, 10, null];
  static const defaultTravelerLimit = 3;

  /// The most a member can ask a traveler to carry (the server's limit).
  static const maxWeightKg = 100.0;

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

  /// Saves a route, notified about up to [maxAlerts] travelers (null: every
  /// one) who can carry [minWeightKg] (null: any weight). Throws
  /// [RouteAlertException].
  Future<void> add({
    required int fromCityId,
    required int toCityId,
    int? maxAlerts,
    double? minWeightKg,
  }) async {
    if (fromCityId == toCityId) {
      throw const RouteAlertException(RouteAlertFailure.samePlace);
    }
    try {
      await _client.schema('nata').from('route_alerts').insert({
        'from_city_id': fromCityId,
        'to_city_id': toCityId,
        'max_alerts': maxAlerts,
        'min_weight_kg': ?minWeightKg,
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

  /// Starts counting travelers again on a route that reached its limit.
  Future<void> restart(String id) =>
      _client.rpc('restart_route_alert', params: {'p_id': id});
}
