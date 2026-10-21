import 'package:carrywise_app/services/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? e164(String code, String input, [String? iso]) =>
      internationalPhoneNumber(dialCode: code, input: input, isoCode: iso);

  group('the 0 is part of the number: kept', () {
    test('Congo-Brazzaville', () {
      expect(e164('+242', '06 877 7804', 'CG'), '+242068777804');
      expect(e164('+242', '068777804', 'CG'), '+242068777804');
    });
    test("Côte d'Ivoire", () {
      expect(e164('+225', '07 07 12 34 56', 'CI'), '+2250707123456');
    });
    test(
      'Benin',
      () => expect(e164('+229', '0196123456', 'BJ'), '+2290196123456'),
    );
    test('Italy (landline)', () {
      expect(e164('+39', '06 1234 5678', 'IT'), '+390612345678');
    });
  });

  group('the 0 is only dialled at home: dropped', () {
    test('Nigeria', () {
      expect(e164('+234', '0803 456 7890', 'NG'), '+2348034567890');
      expect(e164('+234', '8034567890', 'NG'), '+2348034567890');
    });
    test('United Kingdom', () {
      expect(e164('+44', '07911 123456', 'GB'), '+447911123456');
    });
    test(
      'France',
      () => expect(e164('+33', '06 12 34 56 78', 'FR'), '+33612345678'),
    );
    test(
      'Ghana',
      () => expect(e164('+233', '024 412 3456', 'GH'), '+233244123456'),
    );
  });

  test('no 0 to think about', () {
    expect(e164('+1', '(202) 555-0143', 'US'), '+12025550143');
    expect(e164('+237', '677 12 34 56', 'CM'), '+237677123456');
  });

  test('typed with its own + code: kept as typed', () {
    expect(e164('+234', '+242 06 877 7804'), '+242068777804');
  });

  test('typed with 00 and the country code', () {
    expect(e164('+242', '00242068777804', 'CG'), '+242068777804');
  });

  test('without the country letters it still works for Congo', () {
    expect(e164('242', '068777804'), '+242068777804');
  });

  test('nothing typed', () => expect(e164('+242', '  '), isNull));
}
