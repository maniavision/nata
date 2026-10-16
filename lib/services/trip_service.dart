import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'region_service.dart';

/// Values of `nata.trips.status`.
class TripStatus {
  static const pendingReview = 'pending_review';
  static const live = 'live';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

/// A trip of the signed-in traveler, as listed on the "My Trips" screen.
class Trip {
  final String id;
  final int departureCityId;
  final String departureCity;
  final String departureCountryCode;
  final String departureCountry;
  final int arrivalCityId;
  final String arrivalCity;
  final String arrivalCountryCode;
  final String arrivalCountry;
  final DateTime departureDate;
  final DateTime arrivalDate;
  final double price;
  final String currency;
  final double? maxWeightKg;
  final String? maxSize;
  final String ticketReceiptPath;

  /// The copy of the ticket senders see, with the booking reference
  /// blurred. Null when there is none (it could not be made, or the ticket
  /// was uploaded before copies existed).
  final String? ticketSharedPath;
  final String status;

  /// Flight booking reference (PNR), 5-8 letters or digits. Optional.
  final String? bookingReference;

  /// Delivery requests made on this trip / how many were delivered.
  final int requestsCount;
  final int deliveredCount;

  const Trip({
    required this.id,
    required this.departureCityId,
    required this.departureCity,
    required this.departureCountryCode,
    required this.departureCountry,
    required this.arrivalCityId,
    required this.arrivalCity,
    required this.arrivalCountryCode,
    required this.arrivalCountry,
    required this.departureDate,
    required this.arrivalDate,
    required this.price,
    required this.currency,
    required this.maxWeightKg,
    required this.maxSize,
    required this.ticketReceiptPath,
    this.ticketSharedPath,
    required this.status,
    this.bookingReference,
    this.requestsCount = 0,
    this.deliveredCount = 0,
  });

  /// Query used by [TripService.myTrips]: the trip plus both cities and their
  /// country names.
  static const selectColumns =
      'id, departure_city_id, arrival_city_id, departure_date, arrival_date, '
      'price, currency, max_weight_kg, max_size, ticket_receipt_path, '
      'ticket_shared_path, status, '
      'booking_reference, '
      'departure:departure_city_id(id, name, country_code, countries(name)), '
      'arrival:arrival_city_id(id, name, country_code, countries(name))';

  factory Trip.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> city(String key) =>
        (j[key] as Map?)?.cast<String, dynamic>() ?? const {};
    String countryName(Map<String, dynamic> c) =>
        ((c['countries'] as Map?)?['name'] as String?)?.trim() ??
        (c['country_code'] as String? ?? '').trim();
    double? numOrNull(Object? v) =>
        v == null ? null : double.tryParse(v.toString());

    final dep = city('departure');
    final arr = city('arrival');
    return Trip(
      id: j['id'] as String,
      departureCityId: (j['departure_city_id'] as num).toInt(),
      departureCity: (dep['name'] as String? ?? '').trim(),
      departureCountryCode: (dep['country_code'] as String? ?? '').trim(),
      departureCountry: countryName(dep),
      arrivalCityId: (j['arrival_city_id'] as num).toInt(),
      arrivalCity: (arr['name'] as String? ?? '').trim(),
      arrivalCountryCode: (arr['country_code'] as String? ?? '').trim(),
      arrivalCountry: countryName(arr),
      departureDate: DateTime.parse(j['departure_date'] as String),
      arrivalDate: DateTime.parse(j['arrival_date'] as String),
      price: numOrNull(j['price']) ?? 0,
      currency: ((j['currency'] as String?) ?? 'USD').trim(),
      maxWeightKg: numOrNull(j['max_weight_kg']),
      maxSize: j['max_size'] as String?,
      ticketReceiptPath: (j['ticket_receipt_path'] as String?) ?? '',
      ticketSharedPath: _cleanReference(j['ticket_shared_path'] as String?),
      status: (j['status'] as String?) ?? TripStatus.pendingReview,
      bookingReference: _cleanReference(j['booking_reference'] as String?),
    );
  }

  static String? _cleanReference(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Trip withCounts({required int requests, required int delivered}) => Trip(
    id: id,
    departureCityId: departureCityId,
    departureCity: departureCity,
    departureCountryCode: departureCountryCode,
    departureCountry: departureCountry,
    arrivalCityId: arrivalCityId,
    arrivalCity: arrivalCity,
    arrivalCountryCode: arrivalCountryCode,
    arrivalCountry: arrivalCountry,
    departureDate: departureDate,
    arrivalDate: arrivalDate,
    price: price,
    currency: currency,
    maxWeightKg: maxWeightKg,
    maxSize: maxSize,
    ticketReceiptPath: ticketReceiptPath,
    ticketSharedPath: ticketSharedPath,
    status: status,
    bookingReference: bookingReference,
    requestsCount: requests,
    deliveredCount: delivered,
  );

  bool get isLive => status == TripStatus.live;
  bool get isInReview => status == TripStatus.pendingReview;

  /// Still to come: not finished or cancelled, and not yet arrived.
  bool isUpcoming(DateTime today) {
    final active =
        status == TripStatus.pendingReview || status == TripStatus.live;
    final arrival = DateTime(
      arrivalDate.year,
      arrivalDate.month,
      arrivalDate.day,
    );
    return active &&
        !arrival.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// "Envelope / Document" -> "Envelope", "Shoebox (30×20×15 cm)" -> "Shoebox".
  String get sizeShortLabel {
    final s = (maxSize ?? '').trim();
    if (s.isEmpty) return '—';
    return s.split(RegExp(r'[\s/(]')).first;
  }
}

/// A receipt (PDF or image) the traveler picked, before it is uploaded.
class PickedReceipt {
  final Uint8List bytes;
  final String name;
  final String extension;

  const PickedReceipt({
    required this.bytes,
    required this.name,
    required this.extension,
  });

  int get sizeBytes => bytes.length;

  String get contentType {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

/// The values the traveler enters on the Add Trip form.
class TripDraft {
  final int departureCityId;
  final int arrivalCityId;
  final DateTime departureDate;
  final DateTime arrivalDate;
  final double price;
  final String currency;
  final double maxWeightKg;
  final String maxSize;

  /// Storage path of the uploaded receipt.
  final String ticketReceiptPath;

  /// Storage path of the copy senders see (booking reference blurred).
  final String? ticketSharedPath;

  /// Flight booking reference (PNR); null when the traveler left it blank.
  final String? bookingReference;

  /// What the database accepts (`trips_booking_reference_check`).
  static final bookingReferencePattern = RegExp(r'^[A-Z0-9]{5,8}$');

  /// Whether a trip asks for a booking reference (PNR). Every international
  /// trip does; a domestic trip within an African or South American country
  /// doesn't. Other domestic trips still do.
  static bool asksForBookingReference(
    String departureCountryCode,
    String arrivalCountryCode,
  ) {
    final from = departureCountryCode.trim().toUpperCase();
    final to = arrivalCountryCode.trim().toUpperCase();
    return from != to || !RegionService.isAfricanOrSouthAmerican(from);
  }

  const TripDraft({
    required this.departureCityId,
    required this.arrivalCityId,
    required this.departureDate,
    required this.arrivalDate,
    required this.price,
    required this.currency,
    required this.maxWeightKg,
    required this.maxSize,
    required this.ticketReceiptPath,
    this.ticketSharedPath,
    this.bookingReference,
  });

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _fields() => {
    'departure_city_id': departureCityId,
    'arrival_city_id': arrivalCityId,
    'departure_date': isoDate(departureDate),
    'arrival_date': isoDate(arrivalDate),
    'price': price,
    'currency': currency,
    'max_weight_kg': maxWeightKg,
    'max_size': maxSize,
    'ticket_receipt_path': ticketReceiptPath,
    'ticket_shared_path': ticketSharedPath,
    // null clears the reference when a traveler removes it while editing.
    'booking_reference': bookingReference,
  };

  /// New trips always start in review; the database only accepts that.
  Map<String, dynamic> toInsertJson(String travelerId) => {
    'traveler_id': travelerId,
    ..._fields(),
    'status': TripStatus.pendingReview,
  };

  /// Edits never touch the traveler or the status.
  Map<String, dynamic> toUpdateJson() => _fields();
}

/// Reads and writes the signed-in traveler's trips.
///
/// Needs `supabase/migrations/20240110_trips_management.sql`.
class TripService {
  final SupabaseClient _client;

  TripService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Not signed in');
    return id;
  }

  /// The traveler's trips, soonest departure first, with request counts.
  Future<List<Trip>> myTrips() async {
    final uid = _userId;
    final rows =
        await _client
                .schema('nata')
                .from('trips')
                .select(Trip.selectColumns)
                .eq('traveler_id', uid)
                .order('departure_date', ascending: true)
            as List<dynamic>;

    final trips = rows
        .map((r) => Trip.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    if (trips.isEmpty) return trips;

    // Request counts are a nice-to-have: if they cannot be read the trips are
    // still shown.
    try {
      final reqRows =
          await _client
                  .schema('nata')
                  .from('delivery_requests')
                  .select('trip_id, status')
                  .inFilter('trip_id', trips.map((t) => t.id).toList())
              as List<dynamic>;
      final requests = <String, int>{};
      final delivered = <String, int>{};
      for (final r in reqRows) {
        final id = r['trip_id'] as String;
        requests[id] = (requests[id] ?? 0) + 1;
        if (r['status'] == 'delivered') {
          delivered[id] = (delivered[id] ?? 0) + 1;
        }
      }
      return trips
          .map(
            (t) => t.withCounts(
              requests: requests[t.id] ?? 0,
              delivered: delivered[t.id] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[TripService] request counts unavailable: $e');
      return trips;
    }
  }

  /// Uploads a flight receipt to the private `trip-receipts` bucket and
  /// returns its storage path. [suffix] tells copies apart ("-shared").
  Future<String> uploadReceipt(
    PickedReceipt receipt, {
    String suffix = '',
  }) async {
    final path =
        '$_userId/${DateTime.now().millisecondsSinceEpoch}$suffix.${receipt.extension.toLowerCase()}';
    await _client.storage
        .from('trip-receipts')
        .uploadBinary(
          path,
          receipt.bytes,
          fileOptions: FileOptions(contentType: receipt.contentType),
        );
    return path;
  }

  /// Best-effort removal of a receipt that was replaced or never used.
  /// The receipt already on file, to check it again when a trip's dates are
  /// changed.
  Future<Uint8List> downloadReceipt(String path) =>
      _client.storage.from('trip-receipts').download(path);

  Future<void> deleteReceipt(String? path) async {
    if (path == null || path.isEmpty) return;
    if (!path.startsWith('$_userId/')) return; // only the user's own files
    try {
      await _client.storage.from('trip-receipts').remove([path]);
    } catch (e) {
      debugPrint('[TripService] deleteReceipt error: $e');
    }
  }

  Future<void> createTrip(TripDraft draft) async {
    await _client
        .schema('nata')
        .from('trips')
        .insert(draft.toInsertJson(_userId));
  }

  Future<void> updateTrip(String tripId, TripDraft draft) async {
    await _client
        .schema('nata')
        .from('trips')
        .update(draft.toUpdateJson())
        .eq('id', tripId)
        .eq('traveler_id', _userId);
  }
}
