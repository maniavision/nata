import 'package:intl/intl.dart';

import 'exchange_rate_service.dart';

/// The wallet card's figures: payouts and payments are in many currencies
/// (NGN, XOF, USD...), so each is turned into US dollars before they are
/// added up, and the total is shown in the member's currency.
class WalletMoney {
  /// The total of [rows] (each with `amount` and `currency`) in US dollars.
  /// An amount in a currency with no known rate is left out rather than
  /// counted as dollars; without [rates], only dollar amounts count.
  static double sumInUsd(Iterable<dynamic> rows, ExchangeRates? rates) {
    var total = 0.0;
    for (final row in rows) {
      if (row is! Map) continue;
      final amount = row['amount'];
      if (amount is! num) continue;
      final currency = '${row['currency'] ?? 'USD'}'.trim().toUpperCase();
      final rate = currency == 'USD' ? 1.0 : rates?.rateFor(currency);
      if (rate == null || rate <= 0) continue;
      total += amount.toDouble() / rate;
    }
    return total;
  }

  static const _symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£'};

  /// The currency [format] shows: [currency], or USD while its rate isn't
  /// known.
  static String shown(String currency, ExchangeRates? rates) {
    final code = currency.trim().toUpperCase();
    if (code == 'USD') return code;
    final rate = rates?.rateFor(code);
    return rate != null && rate > 0 ? code : 'USD';
  }

  /// Whether [format] writes [code] with a symbol ("\$320.00"), so a screen
  /// can add the code after it; otherwise the code is already in front.
  static bool hasSymbol(String code) => _symbols.containsKey(code);

  /// [usd] dollars in [currency] ("\$320.00", "€275.10", "XOF 181,234"), or
  /// in dollars while its rate isn't known.
  static String format(double usd, String currency, ExchangeRates? rates) {
    final code = shown(currency, rates);
    final amount = usd * (code == 'USD' ? 1.0 : rates!.rateFor(code)!);
    final symbol = _symbols[code];
    if (symbol != null) {
      return NumberFormat.currency(
        symbol: symbol,
        decimalDigits: 2,
      ).format(amount);
    }
    return '$code ${NumberFormat('#,##0', 'en_US').format(amount.round())}';
  }
}
