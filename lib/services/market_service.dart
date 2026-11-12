import 'package:supabase_flutter/supabase_flutter.dart';

double? _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// An item (or a bundle) a sender shows on the Parcel Market, as a traveler
/// with a fitting trip sees it (migration 20240213). The sender shows under
/// their public name with their photo blurred; no notes, photos or recipient.
class MarketListing {
  /// The request group: the first request's id.
  final String groupId;

  /// The traveler's own trip that fits it (the soonest one).
  final String tripId;
  final String itemName;
  final String category;
  final int itemCount;
  final List<String> categories;
  final double weightKg;
  final String fromCity;
  final String fromCountryCode;
  final String toCity;
  final String toCountryCode;
  final String senderName;
  final String? senderAvatar;
  final bool senderVerified;
  final double? senderRating;

  /// The sender's requests to travelers still waiting for an answer.
  final int pendingRequests;

  /// Travelers' offers waiting for the sender.
  final int offers;

  /// This traveler's own pending offer, if any.
  final String? myOfferId;

  /// A pending request the sender already sent this traveler for the item:
  /// offering accepts it.
  final String? myRequestId;

  const MarketListing({
    required this.groupId,
    required this.tripId,
    required this.itemName,
    required this.category,
    this.itemCount = 1,
    this.categories = const [],
    required this.weightKg,
    required this.fromCity,
    this.fromCountryCode = '',
    required this.toCity,
    this.toCountryCode = '',
    required this.senderName,
    this.senderAvatar,
    this.senderVerified = false,
    this.senderRating,
    this.pendingRequests = 0,
    this.offers = 0,
    this.myOfferId,
    this.myRequestId,
  });

  bool get offered => myOfferId != null;
  bool get requested => myRequestId != null;

  /// Kinds of item a traveler may have to check before carrying them.
  bool get restricted => (categories.isEmpty ? [category] : categories).any(
    (c) => c == 'documents' || c == 'electronics',
  );

  factory MarketListing.fromJson(Map<String, dynamic> j) => MarketListing(
    groupId: j['group_id'] as String,
    tripId: j['trip_id'] as String,
    itemName: j['item_name'] as String? ?? '',
    category: j['item_category'] as String? ?? '',
    itemCount: (j['item_count'] as num?)?.toInt() ?? 1,
    categories: [
      for (final c in (j['categories'] as List<dynamic>? ?? const []))
        if (c is String) c,
    ],
    weightKg: _num(j['item_weight_kg']) ?? 0,
    fromCity: j['departure_city'] as String? ?? '',
    fromCountryCode: j['departure_country'] as String? ?? '',
    toCity: j['arrival_city'] as String? ?? '',
    toCountryCode: j['arrival_country'] as String? ?? '',
    senderName: j['sender_name'] as String? ?? '',
    senderAvatar: j['sender_avatar'] as String?,
    senderVerified: j['sender_verified'] as bool? ?? false,
    senderRating: _num(j['sender_rating']),
    pendingRequests: (j['pending_requests'] as num?)?.toInt() ?? 0,
    offers: (j['offers'] as num?)?.toInt() ?? 0,
    myOfferId: j['my_offer_id'] as String?,
    myRequestId: j['my_request_id'] as String?,
  );
}

/// A traveler's offer to carry the sender's item.
class MarketOffer {
  final String id;
  final String tripId;
  final String travelerId;
  final String firstName;
  final String lastName;
  final String? avatarPath;
  final bool photoRevealed;
  final bool verified;
  final double? rating;
  final int itemsDelivered;
  final String fromCity;
  final String toCity;
  final DateTime? departureDate;
  final DateTime? arrivalDate;

  const MarketOffer({
    required this.id,
    required this.tripId,
    required this.travelerId,
    required this.firstName,
    this.lastName = '',
    this.avatarPath,
    this.photoRevealed = false,
    this.verified = false,
    this.rating,
    this.itemsDelivered = 0,
    this.fromCity = '',
    this.toCity = '',
    this.departureDate,
    this.arrivalDate,
  });

  /// "Amara K.", or the pseudonym alone.
  String get displayName {
    final last = lastName.trim();
    return last.isEmpty ? firstName : '$firstName ${last[0]}.';
  }

  factory MarketOffer.fromJson(Map<String, dynamic> j) => MarketOffer(
    id: j['offer_id'] as String,
    tripId: j['trip_id'] as String,
    travelerId: j['traveler_id'] as String,
    firstName: j['first_name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarPath: j['avatar_path'] as String?,
    photoRevealed: j['photo_revealed'] as bool? ?? false,
    verified: j['verified'] as bool? ?? false,
    rating: _num(j['avg_rating']),
    itemsDelivered: (j['items_delivered'] as num?)?.toInt() ?? 0,
    fromCity: j['departure_city'] as String? ?? '',
    toCity: j['arrival_city'] as String? ?? '',
    departureDate: DateTime.tryParse(j['departure_date'] as String? ?? ''),
    arrivalDate: DateTime.tryParse(j['arrival_date'] as String? ?? ''),
  );
}

/// The sender's own request on the market.
class MarketListingState {
  final bool listed;
  final int offers;
  const MarketListingState({required this.listed, this.offers = 0});
}

/// What an offer to carry did.
enum OfferOutcome {
  /// Sent to the sender, who accepts or declines it.
  offered,

  /// The sender had already asked this traveler: the request is accepted.
  accepted,
}

enum MarketFailure {
  /// Taken off, found a traveler, or expired.
  closed,

  /// The item already has 5 offers waiting.
  offerLimit,
  alreadyOffered,
  tripFull,
  tripDoesNotFit,
  offerGone,
  other,
}

class MarketException implements Exception {
  final MarketFailure reason;
  final Object? cause;
  const MarketException(this.reason, [this.cause]);

  @override
  String toString() => 'MarketException(${reason.name}, $cause)';
}

class MarketService {
  /// The most offers waiting on one item (enforced on the server too).
  static const maxOffers = 5;

  final SupabaseClient _client;
  MarketService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      final m = e.message;
      if (m.contains('nata:market_closed')) {
        throw MarketException(MarketFailure.closed, e);
      }
      if (m.contains('nata:offer_limit')) {
        throw MarketException(MarketFailure.offerLimit, e);
      }
      if (m.contains('nata:already_offered') || m.contains('nata:duplicate')) {
        throw MarketException(MarketFailure.alreadyOffered, e);
      }
      if (m.contains('nata:trip_full') || m.contains('nata:sender_on_trip')) {
        throw MarketException(MarketFailure.tripFull, e);
      }
      if (m.contains('nata:trip_does_not_fit') ||
          m.contains('nata:trip_unavailable')) {
        throw MarketException(MarketFailure.tripDoesNotFit, e);
      }
      if (m.contains('nata:offer_not_found') ||
          m.contains('nata:offer_not_pending') ||
          m.contains('nata:request_not_pending')) {
        throw MarketException(MarketFailure.offerGone, e);
      }
      throw MarketException(MarketFailure.other, e);
    }
  }

  /// The items that fit one of the signed-in traveler's live trips.
  Future<List<MarketListing>> listings() async {
    final rows = await _client.rpc('list_market') as List<dynamic>;
    return rows
        .map((r) => MarketListing.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Offers to carry [groupId] on [tripId]. Throws [MarketException].
  Future<OfferOutcome> offer(String groupId, String tripId) => _call(() async {
    final rows =
        await _client.rpc(
              'offer_to_carry',
              params: {'p_group_id': groupId, 'p_trip_id': tripId},
            )
            as List<dynamic>;
    final outcome = rows.isEmpty ? null : (rows.first as Map)['outcome'];
    return outcome == 'accepted' ? OfferOutcome.accepted : OfferOutcome.offered;
  });

  Future<void> withdraw(String offerId) => _call(
    () => _client.rpc('withdraw_market_offer', params: {'p_offer_id': offerId}),
  );

  /// Puts the sender's request [groupId] on the market, or takes it off.
  Future<void> setListed(String groupId, bool listed) => _call(
    () => _client.rpc(
      'set_market_listing',
      params: {'p_group_id': groupId, 'p_listed': listed},
    ),
  );

  /// Whether the sender's request is on the market; null when it isn't
  /// theirs.
  Future<MarketListingState?> listing(String groupId) async {
    final rows =
        await _client.rpc('my_market_listing', params: {'p_group_id': groupId})
            as List<dynamic>;
    if (rows.isEmpty) return null;
    final r = rows.first as Map;
    return MarketListingState(
      listed: r['listed'] as bool? ?? false,
      offers: (r['offers'] as num?)?.toInt() ?? 0,
    );
  }

  /// The offers waiting on the sender's request [groupId].
  Future<List<MarketOffer>> offers(String groupId) async {
    final rows =
        await _client.rpc('list_market_offers', params: {'p_group_id': groupId})
            as List<dynamic>;
    return rows
        .map((r) => MarketOffer.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Takes an offer: returns the new accepted request, for the sender to pay.
  Future<String> acceptOffer(String offerId) => _call(() async {
    final id = await _client.rpc(
      'accept_market_offer',
      params: {'p_offer_id': offerId},
    );
    return id as String;
  });

  Future<void> declineOffer(String offerId) => _call(
    () => _client.rpc('decline_market_offer', params: {'p_offer_id': offerId}),
  );
}
