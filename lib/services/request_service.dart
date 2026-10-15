import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'delivery_pricing.dart';
import 'trip_service.dart' show PickedReceipt;
import 'traveler_service.dart' show TravelerTrip;

/// What kind of item is being sent.
enum RequestCategory {
  electronics('Electronics'),
  apparel('Apparel'),
  documents('Documents');

  const RequestCategory(this.label);

  /// English display name.
  final String label;

  /// What `delivery_requests.item_category` stores ('electronics', ...).
  String get dbValue => name;
}

/// How big the parcel is, in the same three steps as `trips.max_size`, so it
/// can be checked against what the traveler accepts (like weight).
enum RequestSizeClass {
  envelope('envelope', 1),
  shoebox('shoebox', 2),
  backpack('backpack', 3);

  const RequestSizeClass(this.dbValue, this.rank);

  /// What `delivery_requests.item_size_class` stores.
  final String dbValue;

  /// Bigger number = bigger parcel.
  final int rank;

  /// The size class of a trip's `max_size` text ("Envelope / Document",
  /// "Shoebox (30×20×15 cm)", "Backpack size"), or null if it is not one of
  /// those (then there is no size limit to check).
  static RequestSizeClass? fromDb(String? value) {
    for (final c in values) {
      if (c.dbValue == value) return c;
    }
    return null;
  }

  static RequestSizeClass? fromTripSize(String? maxSize) {
    final t = (maxSize ?? '').trim().toLowerCase();
    for (final c in RequestSizeClass.values) {
      if (t.startsWith(c.dbValue)) return c;
    }
    return null;
  }

  /// A parcel of this size fits a traveler who accepts up to [limit].
  bool fitsIn(RequestSizeClass? limit) => limit == null || rank <= limit.rank;
}

/// One thing in a parcel: what it is, what kind it is, and any notes.
class RequestItem {
  final String name;
  final RequestCategory category;
  final String description;

  const RequestItem({
    required this.name,
    this.category = RequestCategory.electronics,
    this.description = '',
  });

  /// What the `create_delivery_request` function takes for this item.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category.dbValue,
    'description': description.trim(),
  };

  factory RequestItem.fromJson(Map<String, dynamic> j) => RequestItem(
    name: (j['name'] as String?) ?? '',
    category: RequestCategory.values.firstWhere(
      (c) => c.dbValue == j['category'],
      orElse: () => RequestCategory.electronics,
    ),
    description: (j['description'] as String?) ?? '',
  );
}

/// Why sending a request did not work.
enum RequestFailure {
  /// The session ended.
  notSignedIn,

  /// The trip is no longer open (it left, was cancelled, or is not published).
  tripUnavailable,

  /// You cannot send a parcel with your own trip.
  ownTrip,

  /// The item is heavier than the traveler accepts.
  weightTooHeavy,

  /// There is already an open request for this trip.
  duplicate,

  /// The sender already has 5 open requests going to this city.
  destinationLimit,

  /// No recent exchange rate on the server, so the price can't be fixed yet.
  rateUnavailable,

  /// The request was already answered, expired or cancelled.
  notPending,

  /// The request can't be paid (not accepted, or it expired).
  notPayable,

  /// The database priced the request differently from what the sender was
  /// shown (the flight got a day closer, or the app and the database price
  /// differently because a pricing migration has not been run).
  priceChanged,

  /// The parcel is bigger than the traveler accepts.
  sizeTooBig,

  /// Something in the form was rejected by the database.
  invalid,

  /// The request no longer exists, or is not the user's.
  requestNotFound,

  /// The traveler already answered (or it expired): it can't be edited.
  notEditable,

  /// The parcel is already with the traveler, or the request is over.
  notCancellable,

  /// The traveler answered while the sender was deciding, so the
  /// cancellation fee is no longer what they were shown.
  feeChanged,

  /// Anything else: network, server, permissions.
  other,
}

class RequestException implements Exception {
  final RequestFailure reason;
  final Object? cause;
  const RequestException(this.reason, [this.cause]);

  @override
  String toString() => 'RequestException(${reason.name}, $cause)';
}

/// The price shown for a request.
///
/// It is calculated in US dollars (see [DeliveryQuote]); the dollar amounts are
/// what is stored. For display they are converted into the currency the user
/// picked, using [rate]. Nothing is charged when a request is sent (payment
/// comes after the traveler accepts).
class RequestPricing {
  /// The delivery cost in USD.
  final double costUsd;

  /// Platform protection & escrow in USD.
  final double feeUsd;

  /// The currency the amounts are shown in.
  final String currency;

  /// How many units of [currency] one US dollar buys.
  final double rate;

  const RequestPricing({
    required this.costUsd,
    required this.feeUsd,
    this.currency = 'USD',
    this.rate = 1,
  });

  factory RequestPricing.forQuote(
    DeliveryQuote quote, {
    String currency = 'USD',
    double rate = 1,
  }) => RequestPricing(
    costUsd: quote.costUsd,
    feeUsd: quote.feeUsd,
    currency: currency.trim().isEmpty ? 'USD' : currency.trim().toUpperCase(),
    rate: rate > 0 ? rate : 1,
  );

  /// What is stored and what the database checks (always US dollars, whole).
  double get totalUsd => costUsd + feeUsd;

  /// A dollar amount converted to [currency] and rounded up to a whole
  /// amount: prices are always whole, in every currency.
  double convert(double usd) => ceilWhole(usd * rate).toDouble();

  double get cost => convert(costUsd);
  double get fee => convert(feeUsd);

  /// The two converted lines added up, so what is shown always adds up.
  double get total => cost + fee;

  /// "$28", "€26", "£22" or "XOF 16,400".
  String format(double amount) => PriceFormatter.write(amount, currency);

  String get costText => format(cost);
  String get feeText => format(fee);
  String get totalText => format(total);

  /// Converted amounts follow the exchange rate until the traveler accepts,
  /// when the price is fixed. Dollars are what is stored, so they are exact.
  bool get isEstimate => currency != 'USD';

  /// The total as shown to the sender: "≈ €101" while it is an estimate.
  String get shownTotalText => isEstimate ? '≈ $totalText' : totalText;
}

/// The photo on a traveler's ID, as the traveler-id-photo edge function
/// gives it.
class TravelerIdPhoto {
  /// A short-lived link to the face crop.
  final String url;

  /// passport, drivers_license or national_id.
  final String? idDocumentType;
  final DateTime? verifiedAt;

  const TravelerIdPhoto({
    required this.url,
    this.idDocumentType,
    this.verifiedAt,
  });

  factory TravelerIdPhoto.fromJson(Map<String, dynamic> j) => TravelerIdPhoto(
    url: j['url'] as String,
    idDocumentType: j['idDocumentType'] as String?,
    verifiedAt: j['verifiedAt'] == null
        ? null
        : DateTime.parse(j['verifiedAt'] as String),
  );
}

/// Shows dollar amounts (what is stored) in the user's currency: converted
/// with [rate] and rounded up to a whole amount, like [RequestPricing].
class PriceFormatter {
  /// The currency amounts are shown in.
  final String currency;

  /// How many units of [currency] one US dollar buys.
  final double rate;

  const PriceFormatter({this.currency = 'USD', this.rate = 1});

  /// Dollars, unconverted: the fallback while no rate is known.
  static const usd = PriceFormatter();

  /// [currency] at [rate], or dollars when the rate is not known.
  factory PriceFormatter.forCurrency(String currency, double? rate) {
    final c = currency.trim().toUpperCase();
    if (c.isEmpty || c == 'USD' || rate == null || rate <= 0) return usd;
    return PriceFormatter(currency: c, rate: rate);
  }

  /// [usd] dollars in [currency], e.g. "XOF 65,566".
  String format(double usd) =>
      write(ceilWhole(usd * rate).toDouble(), currency);

  static const _symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£'};

  /// [amount], already in [currency], written as "$28" or "XOF 16,400".
  static String write(double amount, String currency) {
    final text = NumberFormat('#,##0', 'en_US').format(amount);
    final symbol = _symbols[currency];
    return symbol != null ? '$symbol$text' : '$currency $text';
  }
}

/// Reads what people type into the form.
class RequestInput {
  /// "0.9", "0,9", "0.9 kg" or "900 g" → kilograms. Anything else (other
  /// units, words, zero, negatives) → null, so a wrong unit is never silently
  /// read as kilograms.
  static double? parseWeightKg(String input) {
    final m = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*(kgs?|g)?$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (m == null) return null;
    var value = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    if ((m.group(2) ?? '').toLowerCase() == 'g') value /= 1000;
    value = (value * 100).round() / 100;
    return value > 0 && value < 1000 ? value : null;
  }

  /// "+44 (7700) 900-123" → "+447700900123"; null unless it is an international
  /// number (a "+", then 8 to 15 digits).
  static String? normalizePhone(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(cleaned) ? cleaned : null;
  }

  /// A local number in international format, given its country's dialling
  /// code ("+44", "07700 900123" -> "+447700900123"): the leading trunk "0"
  /// is dropped. A number typed with its own "+" code is taken as is. Null
  /// if the result is not a valid international number.
  static String? internationalPhone(String phoneCode, String input) {
    final typed = input.trim();
    if (typed.startsWith('+')) return normalizePhone(typed);
    final local = typed
        .replaceAll(RegExp(r'[\s\-().]'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (local.isEmpty) return null;
    return normalizePhone('$phoneCode$local');
  }
}

/// Everything entered on the Delivery Request form.
class RequestDraft {
  /// The most items one request can carry.
  static const maxItems = 5;

  final String tripId;

  /// What is in the parcel (at least one, at most [maxItems]).
  final List<RequestItem> items;

  /// The weight and size are those of the whole parcel.
  final double weightKg;
  final String dimensions;
  final RequestSizeClass sizeClass;
  final String recipientName;
  final String recipientPhone;

  /// The total the sender was shown. The database refuses the request if the
  /// traveler's price has changed since, instead of charging something else.
  final double expectedTotal;

  const RequestDraft({
    required this.tripId,
    required this.items,
    required this.weightKg,
    required this.dimensions,
    required this.sizeClass,
    required this.recipientName,
    required this.recipientPhone,
    required this.expectedTotal,
  });

  /// Stored in `item_size`; null when left blank.
  String? get itemSize {
    final d = dimensions.trim();
    return d.isEmpty ? null : d;
  }
}

/// A random version-4 UUID (the request gets its id before it is saved).
String generateUuidV4([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// A request the signed-in user sent (`public.list_my_sent_requests`), with
/// everything needed to show it on Requests and to edit it.
class SentRequest {
  final String id;

  /// pending, accepted, declined, expired, paid, handed_off, delivered or
  /// cancelled.
  final String status;
  final DateTime createdAt;

  /// What the sender pays, in US dollars.
  final double totalUsd;

  /// Set once the sender cancelled: the fee they owe, in US dollars (0 when
  /// they cancelled before the traveler answered).
  final double? cancellationFee;
  final DateTime? cancelledAt;

  /// The sender's currency, recorded when the request was made.
  final String? displayCurrency;

  /// Set once the traveler accepted: the price in [displayCurrency], fixed at
  /// that day's rate. Null before (the shown price is then an estimate).
  final double? displayTotal;

  /// The cancellation fee in [displayCurrency], once the price was fixed.
  final double? displayCancellationFee;

  /// The delivery cost and platform fee in [displayCurrency], once fixed.
  final double? displayCost;
  final double? displayFee;

  /// The deadline: to be answered while pending, to be paid once accepted.
  final DateTime? expiresAt;

  /// When the sender confirmed they checked the traveler's ticket.
  final DateTime? ticketCheckedAt;

  /// When the sender confirmed they checked the traveler's ID photo.
  final DateTime? idCheckedAt;

  /// The traveler's identity is verified (ID checked, face matched).
  final bool travelerVerified;

  /// The traveler's flight ticket (private bucket) and booking reference;
  /// only given once the traveler accepted.
  final String? ticketReceiptPath;
  final String? bookingReference;
  final List<RequestItem> items;
  final double weightKg;
  final String? dimensions;
  final RequestSizeClass? sizeClass;
  final String recipientName;
  final String recipientPhone;
  final List<String> photoPaths;

  /// The trip and its traveler.
  final TravelerTrip trip;

  const SentRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.totalUsd,
    this.cancellationFee,
    this.cancelledAt,
    this.displayCurrency,
    this.displayTotal,
    this.displayCancellationFee,
    this.displayCost,
    this.displayFee,
    this.expiresAt,
    this.ticketCheckedAt,
    this.idCheckedAt,
    this.travelerVerified = false,
    this.ticketReceiptPath,
    this.bookingReference,
    required this.items,
    required this.weightKg,
    required this.dimensions,
    required this.sizeClass,
    required this.recipientName,
    required this.recipientPhone,
    required this.photoPaths,
    required this.trip,
  });

  /// Only a request the traveler has not answered yet can be changed.
  bool get isEditable => status == 'pending';

  /// The fee for cancelling now, in US dollars, or null when it can no longer
  /// be cancelled. Free until the traveler accepts, then 10% of the total,
  /// rounded up to whole dollars.
  /// Matches `nata.cancellation_fee_for` in the database, which has the final
  /// word.
  double? get cancellationFeeNow => switch (status) {
    'pending' => 0,
    'accepted' || 'paid' => ceilWhole(totalUsd * 0.10).toDouble(),
    _ => null,
  };

  bool get isCancellable => cancellationFeeNow != null;

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  static String? _blankToNull(Object? v) {
    final s = (v as String?)?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  /// Accepted and waiting for the sender's payment.
  bool get awaitingPayment => status == 'accepted';

  /// The traveler accepted and the price is fixed in [displayCurrency].
  bool get priceFixed => displayTotal != null && displayCurrency != null;

  /// The fixed price, e.g. "XOF 65,566"; null while it is an estimate.
  String? get fixedTotalText =>
      priceFixed ? PriceFormatter.write(displayTotal!, displayCurrency!) : null;

  /// The cancellation fee for cancelling now in the fixed currency (10% of
  /// the fixed price, rounded up), or null when the price isn't fixed.
  String? get fixedCancellationFeeText {
    final usd = cancellationFeeNow;
    if (!priceFixed || usd == null) return null;
    final fee = usd == 0 ? 0.0 : ceilWhole(displayTotal! * 0.10).toDouble();
    return PriceFormatter.write(fee, displayCurrency!);
  }

  /// The sender cancelled it (not the traveler or the system).
  bool get cancelledBySender => status == 'cancelled' && cancelledAt != null;

  /// "AirPods Max, Charger".
  String get itemsSummary => items.map((i) => i.name).join(', ');

  factory SentRequest.fromJson(Map<String, dynamic> j) => SentRequest(
    id: j['request_id'] as String,
    status: (j['status'] as String?) ?? 'pending',
    createdAt: DateTime.parse(j['created_at'] as String),
    totalUsd: (j['total_amount'] as num?)?.toDouble() ?? 0,
    cancellationFee: (j['cancellation_fee'] as num?)?.toDouble(),
    cancelledAt: j['cancelled_at'] == null
        ? null
        : DateTime.parse(j['cancelled_at'] as String),
    displayCurrency: (j['display_currency'] as String?)?.trim().toUpperCase(),
    displayTotal: (j['display_total'] as num?)?.toDouble(),
    displayCancellationFee: (j['display_cancellation_fee'] as num?)?.toDouble(),
    displayCost: (j['display_cost'] as num?)?.toDouble(),
    displayFee: (j['display_fee'] as num?)?.toDouble(),
    expiresAt: _time(j['expires_at']),
    ticketCheckedAt: _time(j['ticket_checked_at']),
    idCheckedAt: _time(j['id_checked_at']),
    travelerVerified: j['traveler_verified'] == true,
    ticketReceiptPath: _blankToNull(j['ticket_receipt_path']),
    bookingReference: _blankToNull(j['booking_reference']),
    items: [
      for (final i in (j['items'] as List? ?? const []))
        RequestItem.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
    weightKg: (j['item_weight_kg'] as num?)?.toDouble() ?? 0,
    dimensions: j['item_size'] as String?,
    sizeClass: RequestSizeClass.fromDb(j['item_size_class'] as String?),
    recipientName: (j['recipient_name'] as String?) ?? '',
    recipientPhone: (j['recipient_phone'] as String?) ?? '',
    photoPaths: [
      for (final p in (j['photo_paths'] as List? ?? const [])) p as String,
    ],
    trip: TravelerTrip.fromJson({...j, 'currency': j['trip_currency']}),
  );
}

/// Sends delivery requests.
///
/// Needs `supabase/migrations/20240114_delivery_requests.sql`.
class RequestService {
  final SupabaseClient _client;

  static const _bucket = 'request-photos';

  RequestService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const RequestException(RequestFailure.notSignedIn);
    return id;
  }

  /// Uploads the photos, then creates the request and its photo rows in one
  /// step. Returns the request id.
  ///
  /// [requestId] must stay the same when the user retries after a failure: the
  /// database then recognises the request and never creates a second one, and
  /// the photos are written to the same file names instead of piling up.
  Future<String> send(
    String requestId,
    RequestDraft draft,
    List<PickedReceipt> photos,
  ) async {
    final uid = _userId;

    final paths = <String>[
      for (var i = 0; i < photos.length; i++)
        '$uid/$requestId/$i.${photos[i].extension.toLowerCase()}',
    ];

    try {
      for (var i = 0; i < photos.length; i++) {
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              paths[i],
              photos[i].bytes,
              fileOptions: FileOptions(
                contentType: photos[i].contentType,
                upsert: true,
              ),
            );
      }
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }

    try {
      await _client.rpc(
        'create_delivery_request',
        params: {
          'p_id': requestId,
          'p_trip_id': draft.tripId,
          'p_items': [for (final i in draft.items) i.toJson()],
          'p_item_weight_kg': draft.weightKg,
          'p_item_size': draft.itemSize,
          'p_item_size_class': draft.sizeClass.dbValue,
          'p_recipient_name': draft.recipientName.trim(),
          'p_recipient_phone': draft.recipientPhone,
          'p_photo_paths': paths,
          'p_expected_total': draft.expectedTotal,
        },
      );
      return requestId;
    } on PostgrestException catch (e) {
      final reason = reasonFor(e.message);
      // A clear "no" from the database means no request exists, so the files
      // are not needed. Any other failure might have succeeded on the server
      // (the answer may simply have been lost), so the files are kept: they are
      // the request's photos and a retry reuses the same names.
      if (reason != RequestFailure.other) {
        unawaited(_removeFiles(paths));
      }
      throw RequestException(reason, e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  /// The user's sent requests, newest first.
  Future<List<SentRequest>> myRequests() async {
    final rows = await _client.rpc('list_my_sent_requests') as List;
    return [
      for (final r in rows) SentRequest.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  /// Downloads a request's photos (to show and edit them).
  Future<List<PickedReceipt>> downloadPhotos(List<String> paths) async {
    return [
      for (final path in paths)
        PickedReceipt(
          bytes: await _client.storage.from(_bucket).download(path),
          name: path.split('/').last,
          extension: path.split('.').last,
        ),
    ];
  }

  /// Saves changes to a pending request. [photos] replace the current ones
  /// when given (null keeps them). The database checks the request is still
  /// the user's and pending, and prices it again.
  Future<void> update(
    SentRequest request,
    RequestDraft draft, {
    List<PickedReceipt>? photos,
  }) async {
    final uid = _userId;
    List<String>? paths;
    if (photos != null) {
      // New names, so the current photos stay valid until the update is in.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      paths = [
        for (var i = 0; i < photos.length; i++)
          '$uid/${request.id}/e${stamp}_$i.${photos[i].extension.toLowerCase()}',
      ];
      try {
        for (var i = 0; i < photos.length; i++) {
          await _client.storage
              .from(_bucket)
              .uploadBinary(
                paths[i],
                photos[i].bytes,
                fileOptions: FileOptions(contentType: photos[i].contentType),
              );
        }
      } catch (e) {
        unawaited(_removeFiles(paths));
        throw RequestException(RequestFailure.other, e);
      }
    }

    try {
      await _client.rpc(
        'update_delivery_request',
        params: {
          'p_id': request.id,
          'p_items': [for (final i in draft.items) i.toJson()],
          'p_item_weight_kg': draft.weightKg,
          'p_item_size': draft.itemSize,
          'p_item_size_class': draft.sizeClass.dbValue,
          'p_recipient_name': draft.recipientName.trim(),
          'p_recipient_phone': draft.recipientPhone,
          'p_photo_paths': paths,
          'p_expected_total': draft.expectedTotal,
        },
      );
    } on PostgrestException catch (e) {
      if (paths != null) unawaited(_removeFiles(paths));
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }

    // The replaced photos are no longer referenced.
    if (paths != null) unawaited(_removeFiles(request.photoPaths));
  }

  /// Cancels [request] and returns the fee charged, in US dollars. The
  /// database checks the fee is still the one the sender was shown
  /// ([SentRequest.cancellationFeeNow]); if the traveler answered in the
  /// meantime it fails with [RequestFailure.feeChanged].
  Future<double> cancel(SentRequest request) async {
    _userId;
    try {
      final fee = await _client.rpc(
        'cancel_delivery_request',
        params: {
          'p_id': request.id,
          'p_expected_fee': request.cancellationFeeNow,
        },
      );
      return (fee as num?)?.toDouble() ?? 0;
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  /// The sender confirms they checked the traveler's ticket before paying.
  /// Returns when it was first confirmed.
  Future<DateTime> confirmTicketChecked(String requestId) async {
    _userId;
    try {
      final at = await _client.rpc(
        'confirm_ticket_checked',
        params: {'p_id': requestId},
      );
      return at is String ? DateTime.parse(at) : DateTime.now();
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  /// The sender confirms they checked the traveler's ID photo before paying.
  Future<DateTime> confirmIdChecked(String requestId) async {
    _userId;
    try {
      final at = await _client.rpc(
        'confirm_id_checked',
        params: {'p_id': requestId},
      );
      return at is String ? DateTime.parse(at) : DateTime.now();
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  /// The face photo on the traveler's ID (never the whole document), for
  /// the sender of [requestId] once the traveler accepted. Null when the
  /// traveler isn't verified or no photo could be made.
  Future<TravelerIdPhoto?> travelerIdPhoto(String requestId) async {
    try {
      final response = await _client.functions.invoke(
        'traveler-id-photo',
        body: {'request_id': requestId},
      );
      return TravelerIdPhoto.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// A short-lived link to the traveler's ticket (private bucket).
  Future<String> ticketUrl(String path) =>
      _client.storage.from('trip-receipts').createSignedUrl(path, 600);

  /// The traveler accepts [requestId]. The database fixes the price in the
  /// sender's currency at that day's rate in the same step.
  Future<void> accept(String requestId) async {
    _userId;
    try {
      await _client.rpc('accept_delivery_request', params: {'p_id': requestId});
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  Future<void> _removeFiles(List<String> paths) async {
    try {
      await _client.storage.from(_bucket).remove(paths);
    } catch (e) {
      debugPrint('[RequestService] could not remove files: $e');
    }
  }

  /// Maps the database's `nata:xxx` error to a [RequestFailure].
  @visibleForTesting
  static RequestFailure reasonFor(String message) {
    bool has(String code) => message.contains('nata:$code');

    if (has('not_signed_in')) return RequestFailure.notSignedIn;
    if (has('trip_unavailable')) return RequestFailure.tripUnavailable;
    if (has('own_trip')) return RequestFailure.ownTrip;
    if (has('weight_too_heavy')) return RequestFailure.weightTooHeavy;
    if (has('duplicate')) return RequestFailure.duplicate;
    if (has('destination_limit')) return RequestFailure.destinationLimit;
    if (has('rate_unavailable')) return RequestFailure.rateUnavailable;
    if (has('request_not_pending')) return RequestFailure.notPending;
    if (has('request_not_payable')) return RequestFailure.notPayable;
    if (has('price_changed')) return RequestFailure.priceChanged;
    if (has('size_too_big')) return RequestFailure.sizeTooBig;
    if (has('request_not_found')) return RequestFailure.requestNotFound;
    if (has('request_not_editable')) return RequestFailure.notEditable;
    if (has('request_not_cancellable')) return RequestFailure.notCancellable;
    if (has('fee_changed')) return RequestFailure.feeChanged;
    const invalid = [
      'item_required',
      'too_many_items',
      'item_category_invalid',
      'recipient_required',
      'phone_invalid',
      'weight_invalid',
      'size_required',
      'photo_required',
      'photo_invalid',
    ];
    if (invalid.any(has)) return RequestFailure.invalid;
    return RequestFailure.other;
  }
}
