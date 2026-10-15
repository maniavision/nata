import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'id_document_check_service.dart';

/// Outcome of the automatic checks on an uploaded flight ticket.
enum TicketCheckResult {
  /// The traveler's name and the departure date are on the ticket.
  passed,

  /// The profile's first or last name is not on the ticket.
  nameMismatch,

  /// The trip's departure date is not on the ticket (or the arrival date,
  /// when the ticket shows it and it differs).
  dateMismatch,

  /// No text could be read (blurry photo, image-only PDF that OCR could not
  /// read), so nothing can be checked.
  unreadable,

  /// Nothing failed, but the name could not be checked (the profile has no
  /// name yet). The ticket is accepted.
  unverifiable,
}

/// Checks a flight ticket (boarding pass, e-ticket, itinerary) on the device
/// before a trip is saved, like [IdDocumentCheckService] does for IDs:
/// - the traveler's nata.profiles first_name and last_name are on it,
/// - the trip's departure date is on it, in any of the usual ticket formats.
///
/// Text: pdfrx for PDFs, native OCR for photos (shared with the ID check).
class TicketCheckService {
  TicketCheckService({
    Future<String?> Function(Uint8List bytes, String fileName)? readText,
    Future<Map<String, dynamic>?> Function()? loadProfile,
  }) : _readText = readText ?? IdDocumentCheckService.readDocumentText,
       _loadProfile = loadProfile ?? AuthService().getProfile;

  final Future<String?> Function(Uint8List bytes, String fileName) _readText;
  final Future<Map<String, dynamic>?> Function() _loadProfile;

  Future<TicketCheckResult> check({
    required Uint8List bytes,
    required String fileName,
    required DateTime departure,
    required DateTime arrival,
  }) async {
    final text = await _readText(
      bytes,
      fileName,
    ).timeout(IdDocumentCheckService.stepTimeout, onTimeout: () => null);
    if (text == null || text.trim().isEmpty)
      return TicketCheckResult.unreadable;

    var nameChecked = false;
    final profile = await _loadProfile();
    final first = (profile?['first_name'] as String?)?.trim() ?? '';
    final last = (profile?['last_name'] as String?)?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      if (!nameOnTicket(text, first) || !nameOnTicket(text, last)) {
        return TicketCheckResult.nameMismatch;
      }
      nameChecked = true;
    }

    if (!dateOnTicket(text, departure)) return TicketCheckResult.dateMismatch;
    // Boarding passes only show the departure day, so the arrival date only
    // counts when it is a different day and the ticket shows several dates.
    if (!_sameDay(departure, arrival) &&
        datesOnTicket(text) > 1 &&
        !dateOnTicket(text, arrival)) {
      return TicketCheckResult.dateMismatch;
    }

    return nameChecked
        ? TicketCheckResult.passed
        : TicketCheckResult.unverifiable;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Names ──────────────────────────────────────────────────────────────────

  /// Titles airlines glue onto the first name ("AMARAMS", "JOHNMR").
  static const _titles = ['MSTR', 'MISS', 'MRS', 'MR', 'MS', 'DR'];

  /// True when every word of [name] is on the ticket: as whole words, ignoring
  /// case and accents ("KALU/AMARA MS"), or with a title glued on the end
  /// ("KALU/AMARAMS").
  @visibleForTesting
  static bool nameOnTicket(String text, String name) {
    if (IdDocumentCheckService.nameAppearsIn(text, name)) return true;
    final words = IdDocumentCheckService.normalize(
      name,
    ).split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return false;
    final tokens = IdDocumentCheckService.normalize(text).split(' ').toSet();
    return words.every(
      (w) => tokens.contains(w) || _titles.any((t) => tokens.contains('$w$t')),
    );
  }

  // ── Dates ──────────────────────────────────────────────────────────────────

  /// Month names and abbreviations, without accents, in the languages
  /// tickets are commonly printed in (English, French, Spanish, Portuguese,
  /// German).
  static const _months = <int, List<String>>{
    1: [
      'JAN',
      'JANUARY',
      'JANV',
      'JANVIER',
      'ENE',
      'ENERO',
      'JANEIRO',
      'JANUAR',
    ],
    2: [
      'FEB',
      'FEBRUARY',
      'FEV',
      'FEVR',
      'FEVRIER',
      'FEBRERO',
      'FEVEREIRO',
      'FEBRUAR',
    ],
    3: ['MAR', 'MARCH', 'MARS', 'MARZO', 'MARCO', 'MRZ', 'MAERZ', 'MARZ'],
    4: ['APR', 'APRIL', 'AVR', 'AVRIL', 'ABR', 'ABRIL'],
    5: ['MAY', 'MAI', 'MAYO', 'MAIO'],
    6: ['JUN', 'JUNE', 'JUIN', 'JUNIO', 'JUNHO', 'JUNI'],
    7: ['JUL', 'JULY', 'JUIL', 'JUILLET', 'JULIO', 'JULHO', 'JULI'],
    8: ['AUG', 'AUGUST', 'AOUT', 'AGO', 'AGOSTO'],
    9: [
      'SEP',
      'SEPT',
      'SEPTEMBER',
      'SEPTEMBRE',
      'SEPTIEMBRE',
      'SET',
      'SETEMBRO',
    ],
    10: [
      'OCT',
      'OCTOBER',
      'OCTOBRE',
      'OCTUBRE',
      'OUT',
      'OUTUBRO',
      'OKT',
      'OKTOBER',
    ],
    11: ['NOV', 'NOVEMBER', 'NOVEMBRE', 'NOVIEMBRE', 'NOVEMBRO'],
    12: [
      'DEC',
      'DECEMBER',
      'DECEMBRE',
      'DIC',
      'DICIEMBRE',
      'DEZ',
      'DEZEMBRO',
      'DEZEMBER',
    ],
  };

  static int? _monthOf(String token) {
    for (final e in _months.entries) {
      if (e.value.contains(token)) return e.key;
    }
    return null;
  }

  /// The text as tokens: upper case, no accents, letters and digits split
  /// apart ("22JUN25" -> 22 JUN 25), everything else a separator.
  static List<String> _tokens(String text) {
    final s = IdDocumentCheckService.stripAccents(text.toUpperCase())
        // Glued dates with a year (22JUN25) are read separately, with their
        // year; here they would lose it.
        .replaceAll(_gluedDate, ' ')
        .replaceAllMapped(RegExp(r'(\d)([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([A-Z])(\d)'), (m) => '${m[1]} ${m[2]}');
    return s
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((t) => t.isNotEmpty && !_fillers.contains(t))
        .toList();
  }

  /// Airline style, all glued: 22JUN25, 22JUN2025.
  static final _gluedDate = RegExp(
    r'(?<![0-9])(\d{1,2})([A-Z]{3,9})(\d{4}|\d{2})(?![0-9])',
  );

  /// Words between the parts of a date ("22 de junio de 2030", "the 22nd of
  /// June") that are skipped.
  static const _fillers = {
    'DE', 'DEL', 'OF', 'THE', 'LE', 'ST', 'ND', 'RD', 'TH', //
  };

  static int? _int(String t) =>
      RegExp(r'^\d{1,4}$').hasMatch(t) ? int.parse(t) : null;

  /// Looks like a year: 4 digits from 1900 to 2099.
  static bool _looksLikeYear(String t) {
    final v = t.length == 4 ? _int(t) : null;
    return v != null && v >= 1900 && v < 2100;
  }

  /// Every date the ticket shows, as (year or null, month, day).
  static List<(int?, int, int)> _dates(String text) {
    final t = _tokens(text);
    final found = <(int?, int, int)>[];
    int? yearAt(int i) =>
        i < t.length && _looksLikeYear(t[i]) ? _int(t[i]) : null;
    for (var i = 0; i < t.length; i++) {
      final a = _int(t[i]);
      final m = _monthOf(t[i]);
      // 22 JUN [2025]. A 2-digit year only counts glued on (22JUN25, below):
      // a separate 2-digit number is more likely a seat or a time.
      if (a != null && a >= 1 && a <= 31 && i + 1 < t.length) {
        final mon = _monthOf(t[i + 1]);
        if (mon != null) found.add((yearAt(i + 2), mon, a));
      }
      // JUN 22[,] [2025]
      if (m != null && i + 1 < t.length) {
        final d = _int(t[i + 1]);
        if (d != null && d >= 1 && d <= 31 && t[i + 1].length <= 2) {
          found.add((yearAt(i + 2), m, d));
        }
      }
      // Numbers: 22 06 2025, 06 22 2025, 2025 06 22, 22 06 25
      if (a != null && i + 2 < t.length) {
        final b = _int(t[i + 1]);
        final c = _int(t[i + 2]);
        if (b != null && c != null) {
          if (_looksLikeYear(t[i]) && b <= 12 && c <= 31) {
            found.add((a, b, c)); // year month day
          }
          final year = _looksLikeYear(t[i + 2])
              ? c
              : (t[i + 2].length == 2 ? 2000 + c : null);
          if (year != null && t[i].length <= 2 && t[i + 1].length <= 2) {
            if (b <= 12) found.add((year, b, a)); // day month year
            if (a <= 12) found.add((year, a, b)); // month day year
          }
        }
      }
    }
    // Airline style, all glued: 22JUN25, 22JUN2025.
    final upper = IdDocumentCheckService.stripAccents(text.toUpperCase());
    for (final m in _gluedDate.allMatches(upper)) {
      final mon = _monthOf(m[2]!);
      final day = int.parse(m[1]!);
      if (mon == null || day < 1 || day > 31) continue;
      final y = int.parse(m[3]!);
      found.add((m[3]!.length == 2 ? 2000 + y : y, mon, day));
    }
    return found;
  }

  /// True when [date] is printed on the ticket. A date shown without a year
  /// ("22JUN" on a boarding pass) counts.
  @visibleForTesting
  static bool dateOnTicket(String text, DateTime date) => _dates(text).any(
    (d) =>
        d.$2 == date.month &&
        d.$3 == date.day &&
        (d.$1 == null || d.$1 == date.year),
  );

  /// How many different days the ticket shows.
  @visibleForTesting
  static int datesOnTicket(String text) =>
      _dates(text).map((d) => (d.$2, d.$3)).toSet().length;
}
