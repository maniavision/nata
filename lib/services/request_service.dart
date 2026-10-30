import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'delivery_pricing.dart';
import 'exchange_rate_service.dart' show ExchangeRates;
import 'trip_service.dart' show PickedReceipt;
import 'traveler_service.dart'
    show TravelerReview, TravelerReviews, TravelerTrip;
import 'phone_number.dart';
import 'signed_urls.dart';

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

  /// What the sender says the item is worth (20240194), in [valueCurrency];
  /// null for requests sent before values were asked.
  final double? value;
  final String? valueCurrency;

  /// A receipt or listing photo was attached (only the sender and Nata's
  /// staff can open it).
  final bool hasReceipt;

  /// While sending: where the receipt was uploaded.
  final String? receiptPath;

  const RequestItem({
    required this.name,
    this.category = RequestCategory.electronics,
    this.description = '',
    this.value,
    this.valueCurrency,
    this.hasReceipt = false,
    this.receiptPath,
  });

  /// What the `create_delivery_request` function takes for this item.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category.dbValue,
    'description': description.trim(),
    if (value != null) 'value': value,
    if (receiptPath != null) 'receipt_path': receiptPath,
  };

  RequestItem withReceipt(String path) => RequestItem(
    name: name,
    category: category,
    description: description,
    value: value,
    valueCurrency: valueCurrency,
    hasReceipt: true,
    receiptPath: path,
  );

  factory RequestItem.fromJson(Map<String, dynamic> j) => RequestItem(
    name: (j['name'] as String?) ?? '',
    category: RequestCategory.values.firstWhere(
      (c) => c.dbValue == j['category'],
      orElse: () => RequestCategory.electronics,
    ),
    description: (j['description'] as String?) ?? '',
    value: (j['value'] as num?)?.toDouble(),
    valueCurrency: (j['value_currency'] as String?)?.trim(),
    hasReceipt: j['has_receipt'] == true,
  );
}

/// The items' total value and its currency, or null when no item has one
/// (requests sent before values were asked).
({double total, String currency})? declaredValue(List<RequestItem> items) {
  final valued = items.where((i) => i.value != null).toList();
  if (valued.isEmpty) return null;
  return (
    total: valued.fold<double>(0, (sum, i) => sum + i.value!),
    currency: valued.first.valueCurrency ?? 'USD',
  );
}

/// Why sending a request did not work.
enum RequestFailure {
  /// A problem was already reported on this delivery.
  alreadyReported,

  /// More than 3 days have passed since delivery, or it can't be reported yet.
  reportWindowClosed,

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

  /// Payments aren't set up on the server (no payment provider key).
  paymentsUnavailable,

  /// The user hasn't passed the identity check (only verified members post
  /// trips and send requests).
  notVerified,

  /// The trip already has 3 deliveries in progress (delivered ones free a place).
  tripFull,

  /// The traveler already has a delivery in progress from this sender on the trip.
  senderOnTrip,

  /// The request isn't paid, so it can't be picked up or delivered.
  notPaid,

  /// SMS isn't set up on the server.
  smsUnavailable,

  /// Asked again too soon (the code was just texted).
  tooSoon,

  /// Mobile money isn't available in that country.
  mobileMoneyUnavailable,

  /// That way to pay isn't offered for this request (mobile money only when
  /// the sender and the traveler both live where pawaPay takes it, card or
  /// Apple Pay otherwise).
  methodNotOffered,

  /// The payment provider refused the mobile money number or network.
  phoneRejected,

  /// The amount is more or less than the mobile money network allows.
  amountOutOfBounds,

  /// An item's estimated value isn't a number from 0 to 1,000,000.
  itemValueInvalid,

  /// The items are above the traveler's carrying limit: the deposit first
  /// (20240195).
  depositRequired,

  /// The mobile money network is down for now.
  networkUnavailable,

  /// The item isn't marked delivered yet.
  notDelivered,

  /// The sender already reviewed this delivery.
  alreadyReviewed,

  /// The Nata balance doesn't cover the price (any more).
  balanceTooLow,

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

/// How the sender chose to pay on the checkout page: Apple Pay and cards in
/// Stripe's sheet, mobile money through pawaPay.
enum PayMethod {
  applePay('apple_pay'),
  card('card'),
  mobileMoney('mobile_money');

  const PayMethod(this.wire);
  final String wire;
}

/// A payment started, and our reference for it: Stripe's payment sheet in
/// the app (cards, Apple Pay), or no page for mobile money, charged through
/// pawaPay: the payer approves a prompt on their phone. [link] is a payment
/// page, should a provider answer with one.
class PaymentLink {
  final Uri? link;
  final String txRef;

  /// What the app needs to show Stripe's payment sheet.
  final StripeSheet? stripe;

  const PaymentLink(this.link, this.txRef, {this.stripe});

  /// Charged directly: waiting for the payer to approve it on their phone.
  bool get direct => link == null && stripe == null;
}

/// A Stripe PaymentIntent to pay in the app's payment sheet (create-payment).
class StripeSheet {
  final String clientSecret;
  final String publishableKey;

  /// Where the merchant is, for Apple Pay and Google Pay.
  final String merchantCountry;

  /// Apple Pay's merchant ID; null until Apple Pay is set up (cards only).
  final String? appleMerchantId;

  /// The member's Stripe Customer and a short-lived key for it, so the sheet
  /// offers their saved cards (20240196); null without one.
  final String? customerId;
  final String? ephemeralKey;

  /// Saving a card (a SetupIntent) rather than paying.
  final bool setup;

  const StripeSheet({
    required this.clientSecret,
    required this.publishableKey,
    this.merchantCountry = 'US',
    this.appleMerchantId,
    this.customerId,
    this.ephemeralKey,
    this.setup = false,
  });
}

/// A mobile money network the payer picks, with pawaPay's provider code for
/// it (nata.mobile_money_networks).
class MobileMoneyNetwork {
  final String code;
  final String name;
  const MobileMoneyNetwork(this.code, this.name);

  factory MobileMoneyNetwork.fromJson(Map<String, dynamic> j) =>
      MobileMoneyNetwork(
        (j['code'] as String).trim(),
        (j['name'] as String? ?? '').trim(),
      );
}

/// How a request is paid: mobile money (pawaPay) or card and Apple Pay
/// (Stripe), from where the sender and the traveler live.
enum CheckoutKind { mobileMoney, card }

/// Where a payment stands.
enum PaymentStatus { pending, successful, failed }

/// A closed request the user sent or carried (delivered, cancelled or
/// expired): when it closed, and whether they swiped it into the Archive
/// (my_closed_requests, 20240167).
class ClosedRequest {
  final String id;
  final String status;
  final DateTime closedAt;
  final bool archivedByUser;

  const ClosedRequest({
    required this.id,
    this.status = 'delivered',
    required this.closedAt,
    this.archivedByUser = false,
  });

  /// The statuses that end up in the Archive.
  static const statuses = {'delivered', 'cancelled', 'expired'};

  /// How long a closed request stays with the active ones.
  static const keptActiveFor = Duration(hours: 24);

  factory ClosedRequest.fromJson(Map<String, dynamic> j) => ClosedRequest(
    id: j['request_id'] as String,
    status: (j['status'] as String?) ?? 'delivered',
    closedAt: DateTime.parse(j['closed_at'] as String),
    archivedByUser: j['archived'] == true,
  );

  /// In the Archive: swiped away, or closed 24 hours ago or more.
  bool archivedAt(DateTime now) =>
      archivedByUser || !now.isBefore(closedAt.add(keptActiveFor));
}

/// A country whose mobile money the sender can pay with, and what it would
/// charge: the fixed price converted into that country's currency. The
/// payer's number and network are charged through pawaPay (a prompt on
/// their phone, no payment page).
class MobileMoneyOption {
  final String countryCode;
  final String countryName;
  final String currency;
  final double amount;

  /// The sender's own country (profile, else phone number).
  final bool suggested;

  /// The country's calling code ("+242").
  final String dialCode;

  /// The networks pawaPay charges there, in the order to show them.
  final List<MobileMoneyNetwork> networks;

  const MobileMoneyOption({
    required this.countryCode,
    required this.countryName,
    required this.currency,
    required this.amount,
    this.suggested = false,
    this.dialCode = '',
    this.networks = const [],
  });

  factory MobileMoneyOption.fromJson(Map<String, dynamic> j) =>
      MobileMoneyOption(
        countryCode: (j['country_code'] as String).trim(),
        countryName: (j['country_name'] as String? ?? '').trim(),
        currency: (j['currency'] as String).trim(),
        amount: (j['amount'] as num).toDouble(),
        suggested: j['suggested'] == true,
        dialCode: (j['dial_code'] as String? ?? '').trim(),
        networks: [
          for (final n in (j['networks'] as List? ?? const []))
            MobileMoneyNetwork.fromJson(Map<String, dynamic>.from(n as Map)),
        ],
      );

  /// "KES 14,230"
  String get amountText => PriceFormatter.write(amount, currency);
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

  /// [amount] in [from], written in [to] at today's [rates] (rounded up to
  /// a whole amount); in [from] when [to] is the same or a rate is missing.
  static String writeIn(
    double amount,
    String from,
    String to,
    ExchangeRates? rates,
  ) {
    if (from == to) return write(amount, from);
    final fromRate = rates?.rateFor(from);
    final toRate = rates?.rateFor(to);
    if (fromRate == null || toRate == null || fromRate <= 0) {
      return write(amount, from);
    }
    return write(ceilWhole(amount / fromRate * toRate).toDouble(), to);
  }

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
    // Keeps the 0 where it belongs to the number (see phone_number.dart).
    final e164 = internationalPhoneNumber(dialCode: phoneCode, input: typed);
    return e164 == null ? null : normalizePhone(e164);
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

  /// The traveler's identity is verified (ID checked, face matched).
  final bool travelerVerified;

  /// When the sender confirmed they received the item.
  final DateTime? receiptConfirmedAt;

  /// The sender has already reviewed the traveler for this request.
  final bool reviewed;

  /// The copy of the traveler's flight ticket senders may open (private
  /// bucket), with the booking reference blurred; only given once the
  /// traveler accepted, and null when no copy could be made.
  final String? ticketReceiptPath;

  /// Whether the traveler uploaded a ticket at all.
  final bool hasTicket;

  /// Whether the trip has a booking reference. The reference itself is
  /// never given to senders.
  final bool hasBookingReference;
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
    this.travelerVerified = false,
    this.receiptConfirmedAt,
    this.reviewed = false,
    this.ticketReceiptPath,
    bool? hasTicket,
    this.hasBookingReference = false,
    required this.items,
    required this.weightKg,
    required this.dimensions,
    required this.sizeClass,
    required this.recipientName,
    required this.recipientPhone,
    required this.photoPaths,
    required this.trip,
  }) : hasTicket = hasTicket ?? ticketReceiptPath != null;

  /// Only a request the traveler has not answered yet can be changed.
  bool get isEditable => status == 'pending';

  /// Paid, and not delivered yet: the delivery code is in use.
  bool get isPaid => status == 'paid' || status == 'handed_off';

  /// The traveler accepted: their photo shows clearly (blurred before).
  bool get photoRevealed =>
      const {'accepted', 'paid', 'handed_off', 'delivered'}.contains(status);

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

  /// Delivered, and the sender hasn't confirmed receipt yet.
  bool get awaitingReceipt =>
      status == 'delivered' && receiptConfirmedAt == null;

  /// Delivered and confirmed, but not reviewed yet.
  bool get canReview =>
      status == 'delivered' && receiptConfirmedAt != null && !reviewed;

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
    travelerVerified: j['traveler_verified'] == true,
    receiptConfirmedAt: _time(j['receipt_confirmed_at']),
    reviewed: j['reviewed'] == true,
    ticketReceiptPath: _blankToNull(j['ticket_shared_path']),
    hasTicket: j['ticket_on_file'] == true,
    hasBookingReference: j['has_booking_reference'] == true,
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

/// A request made on one of the signed-in traveler's trips
/// (`public.list_incoming_requests`).
class IncomingRequest {
  final String id;

  /// pending, accepted, paid, handed_off or delivered.
  final String status;
  final DateTime createdAt;

  /// The deadline to answer (pending) or for the sender to pay (accepted).
  final DateTime? expiresAt;

  /// What the traveler earns (the delivery cost), in US dollars.
  final double payoutUsd;
  final List<RequestItem> items;
  final double weightKg;
  final String? dimensions;
  final RequestSizeClass? sizeClass;
  final List<String> photoPaths;

  final String senderId;
  final String senderFirstName;
  final String senderLastName;
  final String? senderAvatarPath;
  final bool senderVerified;

  /// Deliveries the sender has completed before.
  final int senderDeliveries;

  /// Only given once the traveler accepted. Never their phone: the
  /// traveler writes to them from the app (RecipientChatScreen).
  final String? recipientName;

  final String tripId;
  final String departureCity;
  final String departureCountry;
  final String arrivalCity;
  final String arrivalCountry;
  final DateTime departureDate;
  final DateTime arrivalDate;

  /// When the traveler picked the item up, and delivered it.
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  /// Wrong delivery codes the traveler can still enter (5 at first).
  final int codeAttemptsLeft;

  /// The sender's average rating as a sender, once travelers rated them.
  final double? senderRating;

  /// The traveler has already rated the sender for this request.
  final bool senderReviewed;

  const IncomingRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    required this.payoutUsd,
    required this.items,
    required this.weightKg,
    this.dimensions,
    this.sizeClass,
    this.photoPaths = const [],
    required this.senderId,
    required this.senderFirstName,
    required this.senderLastName,
    this.senderAvatarPath,
    this.senderVerified = false,
    this.senderDeliveries = 0,
    this.recipientName,
    required this.tripId,
    required this.departureCity,
    required this.departureCountry,
    required this.arrivalCity,
    required this.arrivalCountry,
    required this.departureDate,
    required this.arrivalDate,
    this.pickedUpAt,
    this.deliveredAt,
    this.codeAttemptsLeft = 5,
    this.senderRating,
    this.senderReviewed = false,
  });

  /// Delivered, and the traveler hasn't rated the sender yet.
  bool get needsSenderReview => status == 'delivered' && !senderReviewed;

  /// Waiting for the traveler's answer.
  bool get isPending => status == 'pending';

  /// Paid: the traveler can pick the item up and deliver it.
  bool get isPaid => status == 'paid' || status == 'handed_off';

  bool get isPickedUp => status == 'handed_off' || status == 'delivered';

  /// Accepted and under way (or just delivered).
  bool get isInProgress =>
      const {'accepted', 'paid', 'handed_off', 'delivered'}.contains(status);

  String get senderName => [
    senderFirstName,
    senderLastName,
  ].where((s) => s.trim().isNotEmpty).join(' ');

  /// "AirPods Max, Charger".
  String get itemsSummary => items.map((i) => i.name).join(', ');

  String get routeLabel => '$departureCity → $arrivalCity';

  factory IncomingRequest.fromJson(Map<String, dynamic> j) {
    DateTime? time(Object? v) => v == null ? null : DateTime.parse(v as String);
    String? text(Object? v) {
      final s = (v as String?)?.trim();
      return s == null || s.isEmpty ? null : s;
    }

    return IncomingRequest(
      id: j['request_id'] as String,
      status: (j['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(j['created_at'] as String),
      expiresAt: time(j['expires_at']),
      payoutUsd: (j['payout_usd'] as num?)?.toDouble() ?? 0,
      items: [
        for (final i in (j['items'] as List? ?? const []))
          RequestItem.fromJson(Map<String, dynamic>.from(i as Map)),
      ],
      weightKg: (j['item_weight_kg'] as num?)?.toDouble() ?? 0,
      dimensions: text(j['item_size']),
      sizeClass: RequestSizeClass.fromDb(j['item_size_class'] as String?),
      photoPaths: [
        for (final p in (j['photo_paths'] as List? ?? const [])) p as String,
      ],
      senderId: j['sender_id'] as String,
      senderFirstName: (j['sender_first_name'] as String?)?.trim() ?? '',
      senderLastName: (j['sender_last_name'] as String?)?.trim() ?? '',
      senderAvatarPath: text(j['sender_avatar_path']),
      senderVerified: j['sender_verified'] == true,
      senderDeliveries: (j['sender_deliveries'] as num?)?.toInt() ?? 0,
      recipientName: text(j['recipient_name']),
      tripId: j['trip_id'] as String,
      departureCity: (j['departure_city'] as String?) ?? '',
      departureCountry: (j['departure_country'] as String?) ?? '',
      arrivalCity: (j['arrival_city'] as String?) ?? '',
      arrivalCountry: (j['arrival_country'] as String?) ?? '',
      departureDate: DateTime.parse(j['departure_date'] as String),
      arrivalDate: DateTime.parse(j['arrival_date'] as String),
      pickedUpAt: time(j['picked_up_at']),
      deliveredAt: time(j['delivered_at']),
      codeAttemptsLeft: (j['code_attempts_left'] as num?)?.toInt() ?? 5,
      senderRating: (j['sender_rating'] as num?)?.toDouble(),
      senderReviewed: j['sender_reviewed'] == true,
    );
  }
}

/// The sender's delivery code for a paid request, and when it was last
/// texted to the recipient.
class DeliveryCode {
  final String code;
  final DateTime? smsSentAt;
  const DeliveryCode(this.code, {this.smsSentAt});
}

/// What happened when the traveler entered the recipient's code.
enum DeliveryCheck {
  /// The code was right: delivered, payout queued.
  delivered,

  /// Wrong code; [DeliveryCheckResult.attemptsLeft] tries remain.
  wrongCode,

  /// Too many wrong codes: support has to unlock it.
  locked,

  /// The request had no code yet (paid before codes existed); the sender
  /// now has one to share.
  noCode,
}

typedef DeliveryCheckResult = ({DeliveryCheck result, int attemptsLeft});

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
    List<PickedReceipt> photos, {
    Map<int, PickedReceipt> receipts = const {},
  }) async {
    final uid = _userId;

    final paths = <String>[
      for (var i = 0; i < photos.length; i++)
        '$uid/$requestId/$i.${photos[i].extension.toLowerCase()}',
    ];
    final items = _withReceipts(draft.items, receipts, '$uid/$requestId', '');

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
      await _uploadReceipts(items, receipts, upsert: true);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }

    try {
      await _client.rpc(
        'create_delivery_request',
        params: {
          'p_id': requestId,
          'p_trip_id': draft.tripId,
          'p_items': [for (final i in items) i.toJson()],
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
    Map<int, PickedReceipt> receipts = const {},
  }) async {
    final uid = _userId;
    // New names, so a receipt being replaced stays valid until the update is
    // in. Items without a new receipt keep the one in their place.
    final items = _withReceipts(
      draft.items,
      receipts,
      '$uid/${request.id}',
      'e${DateTime.now().millisecondsSinceEpoch}_',
    );
    try {
      await _uploadReceipts(items, receipts);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
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
          'p_items': [for (final i in items) i.toJson()],
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

  /// Starts paying [requestId] into escrow, for the price fixed when the
  /// traveler accepted (create-payment): Stripe's payment sheet for cards
  /// and Apple Pay.
  /// Mobile money is charged through pawaPay on the wallet's [phone]
  /// (international) and [network] (MobileMoneyNetwork.code): no page, a
  /// prompt on the phone.
  Future<PaymentLink> startPayment(
    String requestId,
    PayMethod method, {
    String? country,
    String? phone,
    String? network,
    bool deposit = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-payment',
        body: {
          'request_id': requestId,
          'method': method.wire,
          if (deposit) 'purpose': 'deposit',
          if (country != null) 'country': country,
          if (phone != null) 'phone': phone,
          if (network != null) 'network': network,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final link = data['link'] as String?;
      final clientSecret = data['client_secret'] as String?;
      return PaymentLink(
        link == null ? null : Uri.parse(link),
        data['tx_ref'] as String,
        stripe: clientSecret == null
            ? null
            : StripeSheet(
                clientSecret: clientSecret,
                publishableKey: data['publishable_key'] as String? ?? '',
                merchantCountry: data['merchant_country'] as String? ?? 'US',
                appleMerchantId: data['apple_merchant_id'] as String?,
                customerId: data['customer_id'] as String?,
                ephemeralKey: data['ephemeral_key'] as String?,
              ),
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['error']}' : '';
      throw RequestException(switch (code) {
        'not_payable' ||
        'expired' ||
        'checks_missing' ||
        'not_allowed' => RequestFailure.notPayable,
        'payments_unavailable' => RequestFailure.paymentsUnavailable,
        'mobile_money_unavailable' => RequestFailure.mobileMoneyUnavailable,
        'method_not_offered' => RequestFailure.methodNotOffered,
        'phone_rejected' => RequestFailure.phoneRejected,
        'amount_out_of_bounds' => RequestFailure.amountOutOfBounds,
        'network_unavailable' => RequestFailure.networkUnavailable,
        'rate_unavailable' => RequestFailure.rateUnavailable,
        'unauthorized' => RequestFailure.notSignedIn,
        _ => RequestFailure.other,
      }, e);
    }
  }

  /// How [requestId] is paid (checkout_kind, 20240173): mobile money when
  /// the sender and the traveler both live where pawaPay takes it, card or
  /// Apple Pay through Stripe otherwise.
  Future<CheckoutKind> checkoutKind(String requestId) async {
    final kind = await _client.rpc(
      'checkout_kind',
      params: {'p_request_id': requestId},
    );
    return kind == 'mobile_money'
        ? CheckoutKind.mobileMoney
        : CheckoutKind.card;
  }

  /// The countries whose mobile money can pay [requestId], each with the
  /// amount in its currency at today's rate.
  Future<List<MobileMoneyOption>> mobileMoneyOptions(String requestId) async {
    final rows = await _client.rpc(
      'mobile_money_options',
      params: {'p_request_id': requestId},
    );
    return [
      for (final r in (rows as List))
        MobileMoneyOption.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Where the traveler's deposit for [requestId] stands (request_deposit,
  /// 20240195): whether one is due, how much, and whether it is held.
  Future<RequestDeposit> requestDeposit(String requestId) async {
    _userId;
    final row = await _client.rpc(
      'request_deposit',
      params: {'p_request_id': requestId},
    );
    return RequestDeposit.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// The countries whose mobile money can pay the deposit for [requestId],
  /// each with the amount in its currency at today's rate.
  Future<List<MobileMoneyOption>> depositMobileMoneyOptions(
    String requestId,
  ) async {
    final rows = await _client.rpc(
      'deposit_mobile_money_options',
      params: {'p_request_id': requestId},
    );
    return [
      for (final r in (rows as List))
        MobileMoneyOption.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Where the payment [txRef] stands, checked with its provider
  /// (verify-payment). The request becomes paid once it is successful.
  Future<PaymentStatus> paymentStatus(String txRef) async {
    final response = await _client.functions.invoke(
      'verify-payment',
      body: {'tx_ref': txRef},
    );
    return switch ((response.data as Map?)?['status']) {
      'successful' => PaymentStatus.successful,
      'failed' => PaymentStatus.failed,
      _ => PaymentStatus.pending,
    };
  }

  /// A short-lived link to the traveler's ticket (private bucket).
  Future<String> ticketUrl(String path) => SignedUrls.get(
    'trip-receipts',
    path,
    lifetime: const Duration(seconds: 600),
    create: () =>
        _client.storage.from('trip-receipts').createSignedUrl(path, 600),
  );

  /// The sender confirms they received the item.
  Future<void> confirmReceipt(String requestId) =>
      _call('confirm_receipt', {'p_id': requestId});

  /// The delivered, cancelled and expired requests the user sent or
  /// carried, by id, for the Archive (20240167).
  Future<Map<String, ClosedRequest>> closedRequests() async {
    final rows = await _client.rpc('my_closed_requests') as List;
    return {
      for (final r in rows)
        (r as Map)['request_id'] as String: ClosedRequest.fromJson(
          Map<String, dynamic>.from(r),
        ),
    };
  }

  /// Moves a closed request to the user's Archive straight away.
  Future<void> archiveRequest(String requestId) =>
      _call('archive_request', {'p_request_id': requestId});

  /// Sends the sender's pending refunds (send-refunds): after cancelling a
  /// paid request, everything but the 10% fee goes back to them.
  Future<void> sendRefunds() async {
    await _client.functions.invoke('send-refunds');
  }

  /// Reports a problem with a delivery (report_problem,
  /// 20240143_disputes.sql).
  Future<void> reportProblem(
    String requestId, {
    required ProblemReason reason,
    String details = '',
  }) => _call('report_problem', {
    'p_request_id': requestId,
    'p_reason': reason.dbValue,
    'p_details': details.trim(),
  });

  /// The sender rates the traveler of a delivered request.
  Future<void> submitReview(
    String requestId, {
    required int rating,
    List<String> tags = const [],
    String comment = '',
  }) => _call('submit_traveler_review', {
    'p_request_id': requestId,
    'p_rating': rating,
    'p_tags': tags,
    'p_comment': comment.trim(),
  });

  /// The traveler rates the sender of a delivered request (20240179).
  Future<void> submitSenderReview(
    String requestId, {
    required int rating,
    List<String> tags = const [],
    String comment = '',
  }) => _call('submit_sender_review', {
    'p_request_id': requestId,
    'p_rating': rating,
    'p_tags': tags,
    'p_comment': comment.trim(),
  });

  /// A suggestion to improve Nata, after reviewing [requestId] (20240189).
  /// [source] is 'review_traveler' (a sender reviewed their traveler) or
  /// 'review_sender' (a traveler reviewed their sender).
  Future<void> sendAppFeedback(
    String message, {
    required String source,
    String? requestId,
  }) => _call('send_app_feedback', {
    'p_message': message.trim(),
    'p_source': source,
    'p_request_id': requestId,
  });

  /// What travelers said about the sender [senderId], newest first, with
  /// their total count (20240180: only for travelers they sent a request).
  Future<TravelerReviews> listSenderReviews(
    String senderId, {
    int limit = 3,
  }) async {
    final rows =
        await _client.rpc(
              'list_sender_reviews',
              params: {'p_sender_id': senderId, 'p_limit': limit},
            )
            as List;
    final list = [
      for (final r in rows)
        TravelerReview.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
    final total = rows.isEmpty
        ? 0
        : ((rows.first as Map)['total'] as num?)?.toInt() ?? list.length;
    return (reviews: list, total: total);
  }

  /// The traveler's chat with the recipient, who replies from the link
  /// texted to them (20240181_recipient_link.sql). Reading it marks the
  /// recipient's messages read.
  Future<RecipientChat> recipientChat(String requestId) async {
    try {
      final data = await _client.rpc(
        'recipient_chat',
        params: {'p_request_id': requestId},
      );
      return RecipientChat.fromJson(Map<String, dynamic>.from(data as Map));
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    }
  }

  /// A signed-in member opened the recipient link [token] in the app: they
  /// take it, and the chat moves into their Messages. Returns the request.
  /// Throws [RecipientLinkException] when it can't be theirs
  /// (20240186_recipient_in_app.sql).
  Future<String> claimRecipientLink(String token) async {
    try {
      final id = await _client.rpc(
        'claim_recipient_link',
        params: {'p_token': token},
      );
      return id as String;
    } on PostgrestException catch (e) {
      throw RecipientLinkException(
        e.message.contains('link_taken')
            ? RecipientLinkProblem.taken
            : e.message.contains('not_recipient')
            ? RecipientLinkProblem.notRecipient
            : RecipientLinkProblem.invalid,
      );
    }
  }

  /// The member recipient's side of the chat: the parcel and the messages.
  Future<RecipientChat> myRecipientChat(String requestId) async {
    try {
      final data = await _client.rpc(
        'my_recipient_chat',
        params: {'p_request_id': requestId},
      );
      return RecipientChat.fromView(Map<String, dynamic>.from(data as Map));
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    }
  }

  /// The member recipient writes to the traveler.
  Future<void> sendAsRecipient(String requestId, String body) =>
      _call('send_as_recipient', {'p_request_id': requestId, 'p_body': body});

  /// What the sender's Nata balance holds in the request's currency, and
  /// whether it covers the whole price (null when it can't be told).
  Future<BalanceCheckout?> balanceCheckout(String requestId) async {
    final data = await _client.rpc(
      'balance_checkout',
      params: {'p_request_id': requestId},
    );
    if (data == null) return null;
    return BalanceCheckout.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Pays [requestId] from the Nata balance: into escrow at once, as a
  /// card payment would (20240187_nata_balance.sql).
  Future<void> payWithBalance(String requestId) =>
      _call('pay_with_balance', {'p_request_id': requestId});

  /// The traveler/recipient chats for Messages, newest first.
  Future<List<RecipientChatSummary>> recipientChats() async {
    final rows = await _client.rpc('list_recipient_chats') as List;
    return [
      for (final r in rows)
        RecipientChatSummary.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// The traveler writes to the recipient; they get a text with the link
  /// when they haven't opened it lately.
  Future<void> sendRecipientMessage(String requestId, String body) => _call(
    'send_recipient_message',
    {'p_request_id': requestId, 'p_body': body},
  );

  Future<void> _call(String fn, Map<String, dynamic> params) async {
    _userId;
    try {
      await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  /// The delivery code of the sender's paid request [requestId]; null when
  /// there is none (not paid yet).
  Future<DeliveryCode?> deliveryCode(String requestId) async {
    final rows =
        await _client.rpc(
              'my_delivery_code',
              params: {'p_request_id': requestId},
            )
            as List;
    if (rows.isEmpty) return null;
    final r = Map<String, dynamic>.from(rows.first as Map);
    return DeliveryCode(
      r['code'] as String,
      smsSentAt: r['sms_sent_at'] == null
          ? null
          : DateTime.parse(r['sms_sent_at'] as String),
    );
  }

  /// Texts the delivery code to the recipient (send-delivery-code).
  Future<void> sendDeliveryCode(String requestId) async {
    try {
      await _client.functions.invoke(
        'send-delivery-code',
        body: {'request_id': requestId},
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['error']}' : '';
      throw RequestException(switch (code) {
        'too_soon' => RequestFailure.tooSoon,
        'sms_unavailable' => RequestFailure.smsUnavailable,
        'not_allowed' => RequestFailure.notPaid,
        'unauthorized' => RequestFailure.notSignedIn,
        _ => RequestFailure.other,
      }, e);
    }
  }

  /// The traveler has the item (paid -> picked up).
  Future<void> markPickedUp(String requestId) =>
      _call('mark_picked_up', {'p_id': requestId});

  /// At most this many photos at pickup, and at handover.
  static const maxDeliveryPhotos = 3;

  /// Uploads the traveler's photos (1 to 3) of the sealed item at pickup,
  /// or of the handover to the recipient, and makes them that step's photos
  /// (20240184_three_delivery_photos.sql). Each upload has its own file, so
  /// a retake never overwrites a photo someone may be looking at.
  Future<void> uploadDeliveryPhotos(
    String requestId,
    DeliveryPhotoKind kind,
    List<Uint8List> photos,
  ) async {
    if (photos.isEmpty || photos.length > maxDeliveryPhotos) {
      throw const RequestException(RequestFailure.other);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final paths = [
      for (var i = 0; i < photos.length; i++)
        '$requestId/${kind.name}-$stamp-$i.jpg',
    ];
    try {
      for (var i = 0; i < photos.length; i++) {
        await _client.storage
            .from(_deliveryPhotoBucket)
            .uploadBinary(
              paths[i],
              photos[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
      }
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
    await _call('set_delivery_photos', {
      'p_request_id': requestId,
      'p_kind': kind.name,
      'p_paths': paths,
    });
  }

  /// Short-lived links to a request's pickup and handover photos, in order
  /// (empty where there are none).
  Future<({List<String> pickup, List<String> handover})> deliveryPhotoUrls(
    String requestId,
  ) async {
    final rows =
        await _client.rpc(
              'delivery_photos',
              params: {'p_request_id': requestId},
            )
            as List;
    if (rows.isEmpty) return (pickup: <String>[], handover: <String>[]);
    final r = Map<String, dynamic>.from(rows.first as Map);
    Future<String> url(String path) => SignedUrls.get(
      _deliveryPhotoBucket,
      path,
      lifetime: const Duration(seconds: 600),
      create: () =>
          _client.storage.from(_deliveryPhotoBucket).createSignedUrl(path, 600),
    );
    // The lists, or the single photo of an older app.
    List<String> paths(String many, String one) {
      final list = [for (final p in (r[many] as List? ?? const [])) '$p'];
      final single = r[one] as String?;
      return list.isNotEmpty ? list : [if (single != null) single];
    }

    return (
      pickup: await Future.wait(
        paths('pickup_photo_paths', 'pickup_photo_path').map(url),
      ),
      handover: await Future.wait(
        paths('handover_photo_paths', 'handover_photo_path').map(url),
      ),
    );
  }

  static const _deliveryPhotoBucket = 'handover-photos';

  /// The traveler enters the recipient's [code]. The right code marks the
  /// request delivered and queues the payout to [payoutAccountId].
  Future<DeliveryCheckResult> confirmDelivery(
    String requestId,
    String code, {
    String? payoutAccountId,
  }) async {
    _userId;
    try {
      final rows =
          await _client.rpc(
                'confirm_delivery',
                params: {
                  'p_id': requestId,
                  'p_code': code.trim(),
                  'p_payout_account_id': payoutAccountId,
                },
              )
              as List;
      final r = Map<String, dynamic>.from(rows.first as Map);
      return (
        result: switch (r['result']) {
          'delivered' => DeliveryCheck.delivered,
          'locked' => DeliveryCheck.locked,
          'no_code' => DeliveryCheck.noCode,
          _ => DeliveryCheck.wrongCode,
        },
        attemptsLeft: (r['attempts_left'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    }
  }

  /// Requests made on the signed-in traveler's trips, newest first.
  Future<List<IncomingRequest>> incomingRequests() async {
    _userId;
    final rows = await _client.rpc('list_incoming_requests') as List;
    return [
      for (final r in rows)
        IncomingRequest.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// The traveler turns down [requestId], optionally saying why.
  Future<void> decline(String requestId, {String? reason}) async {
    _userId;
    try {
      await _client.rpc(
        'decline_delivery_request',
        params: {'p_id': requestId, 'p_reason': reason},
      );
    } on PostgrestException catch (e) {
      throw RequestException(reasonFor(e.message), e);
    } catch (e) {
      throw RequestException(RequestFailure.other, e);
    }
  }

  /// A short-lived link to one of a request's item photos.
  Future<String> photoUrl(String path) => SignedUrls.get(
    _bucket,
    path,
    lifetime: const Duration(seconds: 600),
    create: () => _client.storage.from(_bucket).createSignedUrl(path, 600),
  );

  /// The signed-in traveler's carrying limit (20240194).
  Future<CarryLimit> myCarryLimit() async {
    _userId;
    final rows = await _client.rpc('my_carry_limit') as List<dynamic>;
    if (rows.isEmpty) return CarryLimit.starting;
    return CarryLimit.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

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

  /// [items] with the storage path of their receipt, from [receipts] (by
  /// item index), in [folder].
  List<RequestItem> _withReceipts(
    List<RequestItem> items,
    Map<int, PickedReceipt> receipts,
    String folder,
    String prefix,
  ) => [
    for (var i = 0; i < items.length; i++)
      receipts[i] == null
          ? items[i]
          : items[i].withReceipt(
              '$folder/${prefix}receipt-$i.'
              '${receipts[i]!.extension.toLowerCase()}',
            ),
  ];

  Future<void> _uploadReceipts(
    List<RequestItem> items,
    Map<int, PickedReceipt> receipts, {
    bool upsert = false,
  }) async {
    for (final e in receipts.entries) {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            items[e.key].receiptPath!,
            e.value.bytes,
            fileOptions: FileOptions(
              contentType: e.value.contentType,
              upsert: upsert,
            ),
          );
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
    if (has('item_value_invalid')) return RequestFailure.itemValueInvalid;
    if (has('deposit_required')) return RequestFailure.depositRequired;
    if (has('not_verified')) return RequestFailure.notVerified;
    if (has('trip_full')) return RequestFailure.tripFull;
    if (has('sender_on_trip')) return RequestFailure.senderOnTrip;
    if (has('trip_unavailable')) return RequestFailure.tripUnavailable;
    if (has('own_trip')) return RequestFailure.ownTrip;
    if (has('weight_too_heavy')) return RequestFailure.weightTooHeavy;
    if (has('duplicate')) return RequestFailure.duplicate;
    if (has('destination_limit')) return RequestFailure.destinationLimit;
    if (has('rate_unavailable')) return RequestFailure.rateUnavailable;
    if (has('request_not_pending')) return RequestFailure.notPending;
    if (has('request_not_payable')) return RequestFailure.notPayable;
    if (has('request_not_paid')) return RequestFailure.notPaid;
    if (has('request_not_delivered')) return RequestFailure.notDelivered;
    if (has('already_reviewed')) return RequestFailure.alreadyReviewed;
    if (has('balance_too_low')) return RequestFailure.balanceTooLow;
    if (has('price_changed')) return RequestFailure.priceChanged;
    if (has('size_too_big')) return RequestFailure.sizeTooBig;
    if (has('request_not_found')) return RequestFailure.requestNotFound;
    if (has('request_not_editable')) return RequestFailure.notEditable;
    if (has('request_not_cancellable')) return RequestFailure.notCancellable;
    if (has('fee_changed')) return RequestFailure.feeChanged;
    if (has('already_reported')) return RequestFailure.alreadyReported;
    if (has('report_window_closed') || has('not_reportable')) {
      return RequestFailure.reportWindowClosed;
    }
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
      'review_invalid',
    ];
    if (invalid.any(has)) return RequestFailure.invalid;
    return RequestFailure.other;
  }
}

/// What went wrong with a delivery, as `nata.disputes.reason` stores it.
enum ProblemReason {
  notReceived('not_received'),
  damaged('damaged'),
  wrongItem('wrong_item'),
  opened('opened'),
  other('other');

  const ProblemReason(this.dbValue);
  final String dbValue;
}

/// Which delivery photo: the sealed item at pickup, or the handover.
enum DeliveryPhotoKind { pickup, handover }

/// One message between the traveler and the recipient.
class RecipientMessage {
  final String id;

  /// Written by the recipient (from their link), not the traveler.
  final bool fromRecipient;
  final String body;
  final DateTime at;
  final bool read;

  const RecipientMessage({
    required this.id,
    required this.fromRecipient,
    required this.body,
    required this.at,
    this.read = false,
  });

  factory RecipientMessage.fromJson(Map<String, dynamic> j) => RecipientMessage(
    id: j['id'] as String,
    fromRecipient: j['author'] == 'recipient',
    body: (j['body'] as String?) ?? '',
    at: DateTime.parse(j['at'] as String).toLocal(),
    read: j['read'] == true,
  );
}

/// The traveler's chat with the recipient of a delivery, or (when
/// [asRecipient]) the member recipient's chat with the traveler.
class RecipientChat {
  final String recipientName;
  final String senderName;
  final String item;

  /// The recipient's side ([RecipientChat.fromView]): the traveler and the
  /// parcel, for the status card.
  final bool asRecipient;
  final String travelerName;
  final String? travelerAvatar;
  final String status;
  final String? code;
  final String fromCity;
  final String toCity;
  final DateTime? arrivalDate;

  /// When the recipient last opened their link (null: not yet).
  final DateTime? seenAt;

  /// Open until a day after the delivery.
  final bool open;
  final List<RecipientMessage> messages;

  const RecipientChat({
    required this.recipientName,
    required this.senderName,
    required this.item,
    required this.open,
    required this.messages,
    this.seenAt,
    this.asRecipient = false,
    this.travelerName = '',
    this.travelerAvatar,
    this.status = '',
    this.code,
    this.fromCity = '',
    this.toCity = '',
    this.arrivalDate,
  });

  /// From the recipient page's view (public.recipient_view).
  factory RecipientChat.fromView(Map<String, dynamic> j) {
    final traveler = Map<String, dynamic>.from(j['traveler'] as Map? ?? {});
    final first = (traveler['first_name'] as String?)?.trim() ?? '';
    final initial = (traveler['initial'] as String?)?.trim() ?? '';
    final items = [for (final i in (j['items'] as List? ?? const [])) '$i'];
    final arrival = j['arrival_date'] as String?;
    return RecipientChat(
      asRecipient: true,
      recipientName: (j['recipient'] as String?) ?? '',
      senderName: (j['sender'] as String?) ?? '',
      item: items.isEmpty ? '' : items.first,
      travelerName: initial.isEmpty ? first : '$first $initial.',
      travelerAvatar: traveler['avatar_path'] as String?,
      status: (j['status'] as String?) ?? '',
      code: j['code'] as String?,
      fromCity: (j['from_city'] as String?) ?? '',
      toCity: (j['to_city'] as String?) ?? '',
      arrivalDate: arrival == null ? null : DateTime.tryParse(arrival),
      open: j['chat_open'] == true,
      messages: [
        for (final m in (j['messages'] as List? ?? const []))
          RecipientMessage.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
    );
  }

  factory RecipientChat.fromJson(Map<String, dynamic> j) => RecipientChat(
    recipientName: (j['recipient'] as String?) ?? '',
    senderName: (j['sender'] as String?) ?? '',
    item: (j['item'] as String?) ?? '',
    seenAt: j['seen_at'] == null
        ? null
        : DateTime.parse(j['seen_at'] as String).toLocal(),
    open: j['chat_open'] == true,
    messages: [
      for (final m in (j['messages'] as List? ?? const []))
        RecipientMessage.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

/// A traveler/recipient chat as Messages lists it.
class RecipientChatSummary {
  final String requestId;

  /// The signed-in member is the recipient (not the traveler).
  final bool asRecipient;
  final String otherName;
  final String? otherAvatar;
  final String senderName;
  final String item;
  final String? lastBody;
  final bool lastMine;
  final DateTime? lastAt;
  final int unread;
  final bool open;

  const RecipientChatSummary({
    required this.requestId,
    required this.asRecipient,
    required this.otherName,
    required this.senderName,
    required this.item,
    this.otherAvatar,
    this.lastBody,
    this.lastMine = false,
    this.lastAt,
    this.unread = 0,
    this.open = true,
  });

  factory RecipientChatSummary.fromJson(Map<String, dynamic> j) =>
      RecipientChatSummary(
        requestId: j['request_id'] as String,
        asRecipient: j['role'] == 'recipient',
        otherName: (j['other_name'] as String?) ?? '',
        otherAvatar: j['other_avatar'] as String?,
        senderName: (j['sender_name'] as String?) ?? '',
        item: (j['item'] as String?) ?? '',
        lastBody: j['last_body'] as String?,
        lastMine: j['last_mine'] == true,
        lastAt: j['last_at'] == null
            ? null
            : DateTime.parse(j['last_at'] as String).toLocal(),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        open: j['chat_open'] != false,
      );
}

/// Why a recipient link can't be opened in the app.
enum RecipientLinkProblem { invalid, taken, notRecipient }

class RecipientLinkException implements Exception {
  final RecipientLinkProblem problem;
  const RecipientLinkException(this.problem);
}

/// The Nata balance at checkout, in the request's currency.
class BalanceCheckout {
  final double total;
  final String currency;
  final double available;
  final bool covers;

  const BalanceCheckout({
    required this.total,
    required this.currency,
    required this.available,
    required this.covers,
  });

  factory BalanceCheckout.fromJson(Map<String, dynamic> j) => BalanceCheckout(
    total: (j['total'] as num?)?.toDouble() ?? 0,
    currency: (j['currency'] as String?) ?? 'USD',
    available: (j['available'] as num?)?.toDouble() ?? 0,
    covers: j['covers'] == true,
  );
}

/// How much an item may be worth for a traveler to carry it without a
/// deposit (`public.my_carry_limit`, 20240194): $100 to start, $300 after 3
/// deliveries, $1,000 after 10 rated 4.5 or more.
class CarryLimit {
  /// 1, 2 or 3.
  final int level;

  /// The limit, in US dollars.
  final double limitUsd;

  /// Deliveries completed as a traveler, and their average rating.
  final int delivered;
  final double? rating;

  /// The next level's limit (null at the highest), and what it still takes.
  final double? nextLimitUsd;
  final int deliveriesNeeded;
  final double? ratingNeeded;

  /// The limit in the traveler's own currency, from where they live
  /// (20240197): \$200, £200, €200, XAF 60,000, or \$100 elsewhere. Null
  /// from older servers: the dollar amounts are shown then.
  final String currency;
  final double? limitAmount;
  final double? nextLimitAmount;

  /// The three levels' limits, in [currency].
  final List<double> tiers;

  const CarryLimit({
    required this.level,
    required this.limitUsd,
    this.delivered = 0,
    this.rating,
    this.nextLimitUsd,
    this.deliveriesNeeded = 0,
    this.ratingNeeded,
    this.currency = 'USD',
    this.limitAmount,
    this.nextLimitAmount,
    this.tiers = levels,
  });

  /// A new traveler's.
  static const starting = CarryLimit(
    level: 1,
    limitUsd: 100,
    nextLimitUsd: 300,
    deliveriesNeeded: 3,
  );

  /// The limits of the three levels, in US dollars.
  static const levels = [100.0, 300.0, 1000.0];

  bool get isTop => nextLimitUsd == null;

  /// "\$200", "£200" or "XAF 60,000".
  String get limitText =>
      PriceFormatter.write(limitAmount ?? limitUsd, currency);

  String? get nextLimitText {
    final next = nextLimitAmount ?? nextLimitUsd;
    return next == null ? null : PriceFormatter.write(next, currency);
  }

  /// The limit in the member's display currency [to] (a round amount when
  /// it is the limit's own currency).
  String limitTextIn(String to, ExchangeRates? rates) => PriceFormatter.writeIn(
    limitAmount ?? limitUsd,
    limitAmount == null ? 'USD' : currency,
    to,
    rates,
  );

  String? nextLimitTextIn(String to, ExchangeRates? rates) {
    final next = nextLimitAmount ?? nextLimitUsd;
    if (next == null) return null;
    return PriceFormatter.writeIn(
      next,
      nextLimitAmount == null ? 'USD' : currency,
      to,
      rates,
    );
  }

  String tierTextIn(int level, String to, ExchangeRates? rates) =>
      PriceFormatter.writeIn(
        tiers[(level - 1).clamp(0, tiers.length - 1)],
        currency,
        to,
        rates,
      );

  /// Level [level] (1 to 3)'s limit, written in [currency].
  String tierText(int level) => PriceFormatter.write(
    tiers[(level - 1).clamp(0, tiers.length - 1)],
    currency,
  );

  factory CarryLimit.fromJson(Map<String, dynamic> j) => CarryLimit(
    level: (j['level'] as num?)?.toInt() ?? 1,
    limitUsd: (j['limit_usd'] as num?)?.toDouble() ?? 100,
    delivered: (j['delivered'] as num?)?.toInt() ?? 0,
    rating: (j['rating'] as num?)?.toDouble(),
    nextLimitUsd: (j['next_limit_usd'] as num?)?.toDouble(),
    deliveriesNeeded: (j['deliveries_needed'] as num?)?.toInt() ?? 0,
    ratingNeeded: (j['rating_needed'] as num?)?.toDouble(),
    currency: (j['currency'] as String?)?.trim() ?? 'USD',
    limitAmount: (j['limit_amount'] as num?)?.toDouble(),
    nextLimitAmount: (j['next_limit_amount'] as num?)?.toDouble(),
    tiers: switch (j['tiers']) {
      final List t when t.length == 3 => [
        for (final v in t) (v as num).toDouble(),
      ],
      _ => levels,
    },
  );
}

/// Where a traveler's deposit stands.
enum DepositStatus { none, pending, held, refunding, refunded, paidToSender }

/// The refundable deposit a traveler pays before picking up items worth more
/// than their carrying limit (20240195).
class RequestDeposit {
  /// A deposit is due: the declared value is above the traveler's limit.
  final bool required;

  /// The declared value, which the deposit is, in its currency.
  final double? amount;
  final String? currency;

  /// The traveler's limit, in US dollars, and in their own currency
  /// (20240197).
  final double? limitUsd;
  final double? limitAmount;
  final String? limitCurrency;

  final DepositStatus status;

  /// What was paid, in the currency charged (mobile money converts it).
  final double? paidAmount;
  final String? paidCurrency;

  /// How the request is paid, so the deposit too: mobile money or card.
  final CheckoutKind kind;

  const RequestDeposit({
    this.required = false,
    this.amount,
    this.currency,
    this.limitUsd,
    this.limitAmount,
    this.limitCurrency,
    this.status = DepositStatus.none,
    this.paidAmount,
    this.paidCurrency,
    this.kind = CheckoutKind.card,
  });

  static const notDue = RequestDeposit();

  /// Pickup waits for it.
  bool get blocksPickup => required && status != DepositStatus.held;

  /// "\$450" or "XOF 271,000".
  String? get amountText => amount == null || currency == null
      ? null
      : PriceFormatter.write(amount!, currency!);

  /// "£200" (or the dollars, from an older server).
  String get limitText => limitAmount != null && limitCurrency != null
      ? PriceFormatter.write(limitAmount!, limitCurrency!)
      : PriceFormatter.write(limitUsd ?? 100, 'USD');

  /// The limit in the member's display currency [to].
  String limitTextIn(String to, ExchangeRates? rates) =>
      limitAmount != null && limitCurrency != null
      ? PriceFormatter.writeIn(limitAmount!, limitCurrency!, to, rates)
      : PriceFormatter.writeIn(limitUsd ?? 100, 'USD', to, rates);

  String? get paidText => paidAmount == null || paidCurrency == null
      ? amountText
      : PriceFormatter.write(paidAmount!, paidCurrency!);

  factory RequestDeposit.fromJson(Map<String, dynamic> j) => RequestDeposit(
    required: j['required'] == true,
    amount: (j['amount'] as num?)?.toDouble(),
    currency: (j['currency'] as String?)?.trim(),
    limitUsd: (j['limit_usd'] as num?)?.toDouble(),
    limitAmount: (j['limit_amount'] as num?)?.toDouble(),
    limitCurrency: (j['limit_currency'] as String?)?.trim(),
    status: switch (j['status']) {
      'pending' => DepositStatus.pending,
      'held' => DepositStatus.held,
      'refunding' => DepositStatus.refunding,
      'refunded' => DepositStatus.refunded,
      'paid_to_sender' => DepositStatus.paidToSender,
      _ => DepositStatus.none,
    },
    paidAmount: (j['paid_amount'] as num?)?.toDouble(),
    paidCurrency: (j['paid_currency'] as String?)?.trim(),
    kind: j['kind'] == 'mobile_money'
        ? CheckoutKind.mobileMoney
        : CheckoutKind.card,
  );
}
