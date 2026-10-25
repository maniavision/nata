import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Exchange rates against the US dollar.
class ExchangeRates {
  /// How many units of each currency one US dollar buys (e.g. EUR -> 0.89).
  final Map<String, double> perUsd;

  /// When the provider last updated these rates.
  final DateTime updatedAt;

  /// When the provider will next update them.
  final DateTime? nextUpdateAt;

  const ExchangeRates({
    required this.perUsd,
    required this.updatedAt,
    this.nextUpdateAt,
  });

  /// Currencies that are the same money under two codes: the CFA franc of West
  /// Africa (XOF) and of Central Africa (XAF) are both fixed to the euro at the
  /// same rate, so either code can stand in for the other.
  static const _sameValue = {'XOF': 'XAF', 'XAF': 'XOF'};

  /// Units of [currency] per US dollar, or null if the rate is not known.
  double? rateFor(String currency) {
    final code = currency.trim().toUpperCase();
    if (code == 'USD') return 1;
    final direct = perUsd[code];
    if (direct != null && direct > 0) return direct;
    final alt = perUsd[_sameValue[code]];
    return (alt != null && alt > 0) ? alt : null;
  }

  /// Reads the provider's answer (https://open.er-api.com/v6/latest/USD).
  /// Returns null if it is not a successful, usable answer.
  static ExchangeRates? fromApi(Map<String, dynamic> json) {
    if (json['result'] != 'success') return null;
    final raw = json['rates'];
    if (raw is! Map) return null;

    final rates = <String, double>{};
    raw.forEach((key, value) {
      if (value is num && value > 0) {
        rates[key.toString().toUpperCase()] = value.toDouble();
      }
    });
    if (rates.isEmpty) return null;

    DateTime? fromUnix(Object? v) => v is num && v > 0
        ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000, isUtc: true)
        : null;

    return ExchangeRates(
      perUsd: rates,
      updatedAt:
          fromUnix(json['time_last_update_unix']) ?? DateTime.now().toUtc(),
      nextUpdateAt: fromUnix(json['time_next_update_unix']),
    );
  }

  Map<String, dynamic> toJson() => {
    'rates': perUsd,
    'updated': updatedAt.millisecondsSinceEpoch,
    'next': nextUpdateAt?.millisecondsSinceEpoch,
  };

  static ExchangeRates? fromJson(Map<String, dynamic> json) {
    final raw = json['rates'];
    final updated = json['updated'];
    if (raw is! Map || updated is! num) return null;
    final rates = {
      for (final e in raw.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
    };
    if (rates.isEmpty) return null;
    final next = json['next'];
    return ExchangeRates(
      perUsd: rates,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updated.toInt(),
        isUtc: true,
      ),
      nextUpdateAt: next is num
          ? DateTime.fromMillisecondsSinceEpoch(next.toInt(), isUtc: true)
          : null,
    );
  }
}

/// Fetches USD exchange rates from open.er-api.com.
///
/// Rates change once a day, so one answer is reused until the provider says it
/// will update (or for six hours if it does not say). The last good answer is
/// also kept on the device, so prices still convert when the phone is offline.
class ExchangeRateService {
  static const url = 'https://open.er-api.com/v6/latest/USD';

  /// One for the whole app, so screens share what it already fetched.
  static final shared = ExchangeRateService();
  static const _storeKey = 'exchange_rates_usd';
  static const _fallbackLifetime = Duration(hours: 6);

  final http.Client _http;
  final DateTime Function() _now;
  final Duration timeout;

  ExchangeRates? _memory;
  DateTime? _memoryFetchedAt;
  Future<ExchangeRates?>? _inFlight;

  ExchangeRateService({
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 8),
  }) : _http = client ?? http.Client(),
       _now = now ?? DateTime.now;

  bool _isFresh(ExchangeRates r, DateTime fetchedAt) {
    final now = _now().toUtc();
    final until = r.nextUpdateAt ?? fetchedAt.add(_fallbackLifetime);
    return now.isBefore(until);
  }

  /// The rates fetched last, without fetching: null until [rates] has
  /// answered once.
  ExchangeRates? get latest => _memory;

  /// The current rates, or null when they cannot be had at all (never fetched
  /// and offline). Never throws.
  Future<ExchangeRates?> rates() {
    final cached = _memory;
    final at = _memoryFetchedAt;
    if (cached != null && at != null && _isFresh(cached, at)) {
      return Future.value(cached);
    }
    // Several callers at once share one request.
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<ExchangeRates?> _refresh() async {
    try {
      final response = await _http.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final fresh = body is Map<String, dynamic>
            ? ExchangeRates.fromApi(body)
            : null;
        if (fresh != null) {
          _memory = fresh;
          _memoryFetchedAt = _now().toUtc();
          await _save(fresh);
          return fresh;
        }
      }
    } catch (e) {
      debugPrint('[ExchangeRateService] fetch failed: $e');
    }
    // Offline or the provider is down: use the last rates we had.
    return _memory ?? await _load();
  }

  Future<void> _save(ExchangeRates r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, jsonEncode(r.toJson()));
    } catch (e) {
      debugPrint('[ExchangeRateService] could not save rates: $e');
    }
  }

  Future<ExchangeRates?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_storeKey);
      if (text == null) return null;
      final stored = ExchangeRates.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
      if (stored != null) {
        _memory = stored;
        // Stale on purpose: the next call tries the network again.
        _memoryFetchedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      return stored;
    } catch (e) {
      debugPrint('[ExchangeRateService] could not read saved rates: $e');
      return null;
    }
  }
}
