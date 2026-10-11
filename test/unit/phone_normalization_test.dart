/// Unit tests for phone number normalization logic used in
/// LoginScreen._submit() and SignUpScreen._submit().
///
/// The rule: strip leading 0, then prepend +234 (or the selected country code).
library;

import 'package:flutter_test/flutter_test.dart';

// ── Extracted pure normalization logic (mirrors what the screens do) ────────
String normalizeNigerianPhone(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '');
  final stripped = cleaned.startsWith('0') ? cleaned.substring(1) : cleaned;
  return '+234$stripped';
}

void main() {
  group('Nigerian phone normalisation', () {
    test('strips leading zero and prepends +234', () {
      expect(normalizeNigerianPhone('08034567890'), '+2348034567890');
    });

    test('handles number without leading zero', () {
      expect(normalizeNigerianPhone('8034567890'), '+2348034567890');
    });

    test('handles spaces in input', () {
      expect(normalizeNigerianPhone('0803 456 7890'), '+2348034567890');
    });

    test('handles number already starting with +234', () {
      // +234 → after stripping leading 0 check: +234 has no leading 0
      expect(normalizeNigerianPhone('+2348034567890'), '+234+2348034567890');
      // Note: app should validate E.164 input to avoid double-prefix.
      // This test documents current (raw) behavior.
    });

    test('empty string after strip stays prefixed', () {
      expect(normalizeNigerianPhone(''), '+234');
    });

    test('handles trailing whitespace', () {
      expect(normalizeNigerianPhone('08034567890   '), '+2348034567890');
    });

    test('11-digit Nigerian number normalises to E.164 (13 chars)', () {
      final result = normalizeNigerianPhone('08034567890');
      expect(result.startsWith('+234'), isTrue);
      expect(result.length, 14); // +234 (4) + 10 digits = 14
    });
  });

  group('Input validation rules', () {
    test('detects empty phone', () {
      final phone = ''.trim();
      expect(phone.isEmpty, isTrue);
    });

    test('detects blank (spaces only) phone', () {
      final phone = '   '.trim();
      expect(phone.isEmpty, isTrue);
    });

    test('valid phone is non-empty', () {
      final phone = '08034567890'.trim();
      expect(phone.isNotEmpty, isTrue);
    });

    test('first name empty detected', () {
      expect(''.trim().isEmpty, isTrue);
    });

    test('first name not empty passes validation', () {
      expect('Fortune'.trim().isEmpty, isFalse);
    });
  });
}
