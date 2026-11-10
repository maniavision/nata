import 'package:carrywise_app/services/number_text.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/wallet_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nbsp = ' ';
  const thin = ' '; // French thousands separator

  group('English', () {
    setUp(() => NumberText.locale = 'en');

    test('decimals use a point', () {
      expect(NumberText.fixed(3), '3.0');
      expect(NumberText.fixed(4.75, 2), '4.75');
    });

    test('prices put the symbol first', () {
      expect(PriceFormatter.write(2.36, 'USD'), r'$2.36');
      expect(PriceFormatter.write(26, 'EUR'), '€26');
      expect(PriceFormatter.write(16400, 'XOF'), 'XOF 16,400');
      expect(WalletMoney.inCurrency(320, 'USD'), r'$320.00');
      expect(WalletMoney.inCurrency(60000, 'NGN'), 'NGN 60,000');
    });
  });

  group('French', () {
    setUp(() => NumberText.locale = 'fr');
    tearDown(() => NumberText.locale = 'en');

    test('decimals use a comma', () {
      expect(NumberText.fixed(3), '3,0');
      expect(NumberText.fixed(4.75, 2), '4,75');
    });

    test('prices put the currency after the amount', () {
      expect(PriceFormatter.write(2.36, 'USD'), '2,36$nbsp\$');
      expect(PriceFormatter.write(26, 'EUR'), '26$nbsp€');
      expect(PriceFormatter.write(22, 'GBP'), '22$nbsp£');
      expect(PriceFormatter.write(16400, 'XOF'), '16${thin}400${nbsp}XOF');
      expect(WalletMoney.inCurrency(320, 'USD'), '320,00$nbsp\$');
    });

    test('a regional French locale counts too', () {
      NumberText.locale = 'fr_CA';
      expect(NumberText.fixed(2.5), '2,5');
    });
  });

  test('Spanish keeps the English style', () {
    NumberText.locale = 'es';
    addTearDown(() => NumberText.locale = 'en');
    expect(PriceFormatter.write(2.36, 'USD'), r'$2.36');
  });
}
