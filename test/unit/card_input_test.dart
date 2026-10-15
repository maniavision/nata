import 'package:carrywise_app/screens/add_payment_method_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardInput.isValidNumber', () {
    test('accepts test card numbers (Luhn)', () {
      expect(CardInput.isValidNumber('4242 4242 4242 4242'), isTrue);
      expect(CardInput.isValidNumber('5555555555554444'), isTrue);
      expect(CardInput.isValidNumber('378282246310005'), isTrue);
    });

    test('rejects a wrong checksum or length', () {
      expect(CardInput.isValidNumber('4242 4242 4242 4241'), isFalse);
      expect(CardInput.isValidNumber('4242'), isFalse);
      expect(CardInput.isValidNumber(''), isFalse);
    });
  });

  group('CardInput.isValidExpiry', () {
    final now = DateTime(2026, 10, 13);

    test('this month and later are valid', () {
      expect(CardInput.isValidExpiry('10/26', now: now), isTrue);
      expect(CardInput.isValidExpiry('08/27', now: now), isTrue);
    });

    test('past months, bad months and bad formats are not', () {
      expect(CardInput.isValidExpiry('09/26', now: now), isFalse);
      expect(CardInput.isValidExpiry('13/27', now: now), isFalse);
      expect(CardInput.isValidExpiry('00/27', now: now), isFalse);
      expect(CardInput.isValidExpiry('0827', now: now), isFalse);
    });
  });

  test('CVV is 3 or 4 digits', () {
    expect(CardInput.isValidCvv('123'), isTrue);
    expect(CardInput.isValidCvv('1234'), isTrue);
    expect(CardInput.isValidCvv('12'), isFalse);
    expect(CardInput.isValidCvv('12a'), isFalse);
  });

  test('brand from the first digits', () {
    expect(CardInput.brand('4242'), 'Visa');
    expect(CardInput.brand('5555'), 'Mastercard');
    expect(CardInput.brand('2223'), 'Mastercard');
    expect(CardInput.brand('3782'), 'American Express');
    expect(CardInput.brand('6011'), 'Card');
  });
}
