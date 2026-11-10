import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Writes numbers the way the app's language does. French puts a comma
/// before the decimals and the currency after the amount ("3,0 kg",
/// "2,36 $", "1 976 XOF"); English and Spanish keep "3.0 kg" and "$2.36".
///
/// [locale] follows the app's language through [NumberTextDelegate], so
/// code with no [BuildContext] (price formatters) writes numbers the same
/// way as the screen around it.
class NumberText {
  const NumberText._();

  /// The language numbers are written in ("en", "fr", "es").
  static String locale = 'en';

  /// Whether amounts use French style: decimal comma, currency after.
  static bool get french => locale.toLowerCase().startsWith('fr');

  static String get _numberLocale => french ? 'fr' : 'en_US';

  /// [value] with exactly [digits] decimals: 3 -> "3.0" or "3,0".
  static String fixed(num value, [int digits = 1]) {
    final pattern = digits <= 0 ? '0' : '0.${'0' * digits}';
    return NumberFormat(pattern, _numberLocale).format(value);
  }

  /// [value] with thousands grouped and [decimals] decimals:
  /// 16400 -> "16,400" or "16 400"; 2.36 -> "2.36" or "2,36".
  static String grouped(num value, {int decimals = 0}) {
    final pattern = decimals <= 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    return NumberFormat(pattern, _numberLocale).format(value);
  }

  /// [number] (already written) with its currency: a symbol in front in
  /// English ("$2.36", "XOF 1,976"), after it in French ("2,36 $",
  /// "1 976 XOF"), with a no-break space so they stay on one line.
  static String withCurrency(String number, String code, String? symbol) {
    if (french) return '$number ${symbol ?? code}';
    return symbol != null ? '$symbol$number' : '$code $number';
  }
}

/// Keeps [NumberText.locale] in step with the app's language. Add it to
/// MaterialApp's localizationsDelegates.
class NumberTextDelegate extends LocalizationsDelegate<NumberText> {
  const NumberTextDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<NumberText> load(Locale locale) {
    NumberText.locale = locale.toString();
    return SynchronousFuture(const NumberText._());
  }

  @override
  bool shouldReload(NumberTextDelegate old) => false;
}
