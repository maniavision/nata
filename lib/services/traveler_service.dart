import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One upcoming trip together with the public details of its traveler,
/// as returned by the `public.search_travelers` database function.
class TravelerTrip {
  final String tripId;
  final String travelerId;
  final String firstName;
  final String lastName;
  final String? avatarPath;
  final double? avgRating;
  final int itemsDelivered;
  final String departureCity;
  final String departureCountry;
  final String arrivalCity;
  final String arrivalCountry;
  final DateTime departureDate;
  final DateTime arrivalDate;
  final double price;
  final String currency;
  final double? maxWeightKg;
  final String? maxSize;

  const TravelerTrip({
    required this.tripId,
    required this.travelerId,
    required this.firstName,
    required this.lastName,
    required this.avatarPath,
    required this.avgRating,
    required this.itemsDelivered,
    required this.departureCity,
    required this.departureCountry,
    required this.arrivalCity,
    required this.arrivalCountry,
    required this.departureDate,
    required this.arrivalDate,
    required this.price,
    required this.currency,
    required this.maxWeightKg,
    required this.maxSize,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory TravelerTrip.fromJson(Map<String, dynamic> j) => TravelerTrip(
    tripId: j['trip_id'] as String,
    travelerId: j['traveler_id'] as String,
    firstName: (j['first_name'] as String?) ?? '',
    lastName: (j['last_name'] as String?) ?? '',
    avatarPath: j['avatar_path'] as String?,
    avgRating: (j['avg_rating'] as num?)?.toDouble(),
    itemsDelivered: (j['items_delivered_count'] as num?)?.toInt() ?? 0,
    departureCity: (j['departure_city'] as String?) ?? '',
    departureCountry: (j['departure_country'] as String?) ?? '',
    arrivalCity: (j['arrival_city'] as String?) ?? '',
    arrivalCountry: (j['arrival_country'] as String?) ?? '',
    departureDate: DateTime.parse(j['departure_date'] as String),
    arrivalDate: DateTime.parse(j['arrival_date'] as String),
    price: (j['price'] as num?)?.toDouble() ?? 0,
    currency: ((j['currency'] as String?) ?? 'USD').trim(),
    maxWeightKg: (j['max_weight_kg'] as num?)?.toDouble(),
    maxSize: j['max_size'] as String?,
  );
}

/// A traveler's public profile plus their upcoming live trips, as returned by
/// `public.get_traveler_profile`.
class TravelerProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarPath;
  final String verificationStatus;
  final double? avgRating;
  final int itemsDelivered;
  final DateTime? memberSince;
  final List<TravelerTrip> trips;

  const TravelerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.avatarPath,
    required this.verificationStatus,
    required this.avgRating,
    required this.itemsDelivered,
    required this.memberSince,
    required this.trips,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isVerified => verificationStatus == 'verified';

  factory TravelerProfile.fromJson(Map<String, dynamic> j) {
    // Each trip repeats the traveler fields so it can be a TravelerTrip.
    final travelerFields = <String, dynamic>{
      'first_name': j['first_name'],
      'last_name': j['last_name'],
      'avatar_path': j['avatar_path'],
      'avg_rating': j['avg_rating'],
      'items_delivered_count': j['items_delivered_count'],
    };
    final rawTrips = (j['trips'] as List<dynamic>?) ?? const [];
    return TravelerProfile(
      id: j['id'] as String,
      firstName: (j['first_name'] as String?) ?? '',
      lastName: (j['last_name'] as String?) ?? '',
      avatarPath: j['avatar_path'] as String?,
      verificationStatus: (j['verification_status'] as String?) ?? 'unverified',
      avgRating: (j['avg_rating'] as num?)?.toDouble(),
      itemsDelivered: (j['items_delivered_count'] as num?)?.toInt() ?? 0,
      memberSince: j['member_since'] == null
          ? null
          : DateTime.tryParse(j['member_since'] as String),
      trips: rawTrips
          .map(
            (t) => TravelerTrip.fromJson({
              ...travelerFields,
              ...Map<String, dynamic>.from(t as Map),
            }),
          )
          .toList(),
    );
  }
}

/// Finds travelers (upcoming live trips) through `public.search_travelers`.
/// See supabase/migrations/20240108_search_travelers_rpc.sql.
class TravelerService {
  final SupabaseClient _client;

  TravelerService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// All filters are optional. Throws if the request fails so the caller can
  /// show an error state.
  Future<List<TravelerTrip>> search({
    String? departureCountry,
    String? departureCity,
    String? arrivalCountry,
    String? arrivalCity,
    DateTime? date,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      'p_departure_country': departureCountry,
      'p_departure_city': departureCity,
      'p_arrival_country': arrivalCountry,
      'p_arrival_city': arrivalCity,
      'p_date': date == null ? null : _isoDate(date),
      'p_limit': limit,
    }..removeWhere((_, v) => v == null);

    try {
      final rows =
          await _client.rpc('search_travelers', params: params)
              as List<dynamic>;
      return rows
          .map(
            (r) => TravelerTrip.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('[TravelerService] search error: $e');
      rethrow;
    }
  }

  /// Public profile + upcoming trips of one traveler, or null if not found.
  Future<TravelerProfile?> getProfile(String travelerId) async {
    try {
      final res = await _client.rpc(
        'get_traveler_profile',
        params: {'p_traveler_id': travelerId},
      );
      if (res == null) return null;
      return TravelerProfile.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('[TravelerService] getProfile error: $e');
      rethrow;
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
