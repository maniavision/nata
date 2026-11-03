import 'package:carrywise_app/services/contact_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool has(String text) => ContactCheck.hasContactDetails(text);

  group('digit runs', () {
    test('phone numbers are caught however they are written', () {
      expect(has('+242 06 123 4567'), isTrue);
      expect(has('Call 0612345678 when you land'), isTrue);
      expect(has('06.12.34.56.78'), isTrue);
      expect(has('(+234) 803-123-4567'), isTrue);
      expect(has('Nike shoes ０６１２３４５６７８'), isTrue);
    });

    test('short numbers pass', () {
      expect(has('iPhone 15 Pro, 256 GB'), isFalse);
      expect(has('2 kg of dried fish, size 42'), isFalse);
      expect(has('Born 12/05/2024'), isFalse);
      expect(has('Order 1234567'), isFalse);
    });
  });

  group('spelled-out numbers', () {
    test('number words in a row are caught, in any of the languages', () {
      expect(has('zero six one two three four five six'), isTrue);
      expect(
        has('zéro six douze trente-quatre cinquante-six soixante'),
        isTrue,
      );
      expect(has('cero seis uno dos tres cuatro cinco'), isTrue);
      expect(has('06 / 12 / 34 / 56'), isTrue);
    });

    test('ordinary counts pass', () {
      expect(has('Two pairs of shoes and three shirts'), isFalse);
      expect(has('Deux robes et un sac'), isFalse);
      expect(has('Sizes 38 and 40, 2 pairs'), isFalse);
    });
  });

  group('contact handles', () {
    test('apps, phrases, emails, handles and links are caught', () {
      expect(has('Message me on WhatsApp'), isTrue);
      expect(has('whats app me'), isTrue);
      expect(has('Find me on Telegram'), isTrue);
      expect(has('Appelle-moi à l’arrivée'), isTrue);
      expect(has('Voici mon numéro'), isTrue);
      expect(has('Llámame cuando llegues'), isTrue);
      expect(has('jane.doe@gmail.com'), isTrue);
      expect(has('Follow @janedoe'), isTrue);
      expect(has('See www.example.com'), isTrue);
    });

    test('ordinary item text passes', () {
      expect(has('Samsung phone in its box'), isFalse);
      expect(has('Téléphone neuf, fragile'), isFalse);
      expect(has('Kalu Okonkwo'), isFalse);
      expect(has(''), isFalse);
    });
  });

  test('anyHasContactDetails looks at every text', () {
    expect(
      ContactCheck.anyHasContactDetails(['Shoes', null, 'whatsapp me']),
      isTrue,
    );
    expect(ContactCheck.anyHasContactDetails(['Shoes', null, 'Bag']), isFalse);
  });
}
