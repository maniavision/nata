/// Finds a phone number or other contact details in text a sender types into
/// a delivery request (item names, notes, the recipient's name), so the
/// sender and traveler can't swap contacts before the traveler accepts.
///
/// Three checks, the same as the database's nata.has_contact_details
/// (20240199), which enforces them:
///  * digit runs: 8 or more digits, with at most one space, dot, dash,
///    slash or bracket between each ("+242 06 123 4567", "06.12.34.56.78"),
///    dates aside ("12/05/2024");
///  * spelled-out numbers: 7 or more number words in a row, in English,
///    French or Spanish ("zero six one two three four five"), digit groups
///    counting their digits ("06 / 12 / 34 / 56");
///  * contact handles: messaging apps, "call me" phrases, emails, @handles
///    and links.
///
/// Short numbers ("2 kg", "size 42", "iPhone 15") pass.
class ContactCheck {
  ContactCheck._();

  /// The digits a run must reach.
  static const minDigits = 8;

  /// The number words in a row that count as a number.
  static const minNumberWords = 7;

  /// Whether [text] holds a phone number or contact details.
  static bool hasContactDetails(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final t = _fold(text).replaceAll(_date, ' ');
    return _hasDigitRun(t) || _hasSpelledNumber(t) || _hasHandle(t);
  }

  /// Whether any of [texts] holds contact details.
  static bool anyHasContactDetails(Iterable<String?> texts) =>
      texts.any(hasContactDetails);

  static final _digitRun = RegExp(r'\d(?:[\s.\-()/]?\d)+');

  static bool _hasDigitRun(String t) => _digitRun
      .allMatches(t)
      .any(
        (m) => m.group(0)!.replaceAll(RegExp(r'\D'), '').length >= minDigits,
      );

  /// A date ("12/05/2024", "12.05.2024") is not a phone number.
  static final _date = RegExp(
    r'(?<![\d./\-])\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}(?![./\-]?\d)',
  );

  /// Number words in English, French and Spanish, without accents.
  static const _numberWords = {
    // English
    'zero', 'oh', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
    'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
    'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
    'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
    'hundred', 'double', 'triple',
    // French
    'un', 'une', 'deux', 'trois', 'quatre', 'cinq', 'sept', 'huit',
    'neuf', 'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
    'vingt', 'vingts', 'trente', 'quarante', 'cinquante', 'soixante', 'cent',
    'et',
    // Spanish
    'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho',
    'nueve', 'diez', 'doce', 'trece', 'catorce', 'quince', 'dieciseis',
    'veinte', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta',
    'ochenta', 'noventa', 'cien', 'y',
  };

  /// Small words that never start or end a number on their own.
  static const _joiners = {'et', 'y', 'oh'};

  /// Each number word counts 1 and each digit group its digits, so
  /// "06 / 12 / 34 / 56" counts too; [_joiners] count 0. A run needs 3
  /// pieces or more.
  static bool _hasSpelledNumber(String t) {
    final words = t.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);
    var pieces = 0;
    var score = 0;
    for (final w in words) {
      final digits = RegExp(r'^\d+$').hasMatch(w);
      if (digits || _numberWords.contains(w)) {
        pieces++;
        if (digits) {
          score += w.length;
        } else if (!_joiners.contains(w)) {
          score++;
        }
        if (pieces >= 3 && score >= minNumberWords) return true;
      } else {
        pieces = 0;
        score = 0;
      }
    }
    return false;
  }

  static final _handles = RegExp(
    r'\b(whats\s?app|watsapp|watsap|whatsap|wa\.me|telegram|t\.me|viber|'
    r'snapchat|instagram|facebook|messenger|tiktok|'
    r'call me|text me|ring me|contact me|my number|my phone|phone me|dm me|'
    r'appelle[\s-]?moi|appelez[\s-]?moi|contacte[\s-]?moi|contactez[\s-]?moi|'
    r'mon numero|mon tel|mon telephone|joignable|'
    r'llamame|llameme|contactame|escribeme|mi numero|mi telefono)\b',
  );
  static final _email = RegExp(r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}');
  static final _atHandle = RegExp(r'(^|[\s(])@[a-z0-9_.]{3,}');
  static final _link = RegExp(r'(https?://|www\.)');

  static bool _hasHandle(String t) =>
      _handles.hasMatch(t) ||
      _email.hasMatch(t) ||
      _atHandle.hasMatch(t) ||
      _link.hasMatch(t);

  static const _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    '’': "'",
  };

  /// Lower case, without accents, with full-width digits as plain ones.
  static String _fold(String text) {
    final b = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        b.writeCharCode(rune - 0xFF10 + 0x30);
      } else {
        b.write(_accents[c] ?? c);
      }
    }
    return b.toString();
  }
}
