import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'delivery_pricing.dart';
import 'trip_service.dart' show PickedReceipt;

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

  /// The traveler changed their price after the sender looked at it.
  priceChanged,

  /// The parcel is bigger than the traveler accepts.
  sizeTooBig,

  /// Something in the form was rejected by the database.
  invalid,

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

  /// What is stored and what the database checks (always US dollars).
  double get totalUsd => _round(costUsd + feeUsd, 2);

  /// The CFA franc has no cents.
  static const _noDecimals = {'XOF', 'XAF'};

  static int decimalsFor(String currency) =>
      _noDecimals.contains(currency.toUpperCase()) ? 0 : 2;

  int get decimals => decimalsFor(currency);

  /// A dollar amount, converted and rounded the way the currency is written.
  double convert(double usd) => _round(usd * rate, decimals);

  double get cost => convert(costUsd);
  double get fee => convert(feeUsd);

  /// The two converted lines added up, so what is shown always adds up.
  double get total => _round(cost + fee, decimals);

  static double _round(double v, int decimals) {
    final f = pow(10, decimals).toDouble();
    return ((v * f) + 1e-9).round() / f;
  }

  static const _symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£'};

  /// "$27.50", "€24.55", "£20.80" or "XOF 16,000".
  String format(double amount) {
    final text = NumberFormat(
      decimals == 0 ? '#,##0' : '#,##0.00',
      'en_US',
    ).format(amount);
    final symbol = _symbols[currency];
    return symbol != null ? '$symbol$text' : '$currency $text';
  }

  String get costText => format(cost);
  String get feeText => format(fee);
  String get totalText => format(total);
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
    if (has('price_changed')) return RequestFailure.priceChanged;
    if (has('size_too_big')) return RequestFailure.sizeTooBig;
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
