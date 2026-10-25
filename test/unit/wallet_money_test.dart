import 'package:carrywise_app/services/exchange_rate_service.dart';
import 'package:carrywise_app/services/wallet_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rates = ExchangeRates(
    perUsd: const {'NGN': 1500, 'XOF': 584, 'GHS': 15.16, 'EUR': 0.9},
    updatedAt: DateTime.utc(2026, 10, 25),
  );

  group('sumInUsd', () {
    // The held payments that showed as "$208,255": NGN 197,189 + XOF 9,344
    // + GHS 1,516 + USD 206, added up as if all were dollars.
    const held = [
      {'amount': 197189, 'currency': 'NGN'},
      {'amount': 9344, 'currency': 'XOF'},
      {'amount': 1516, 'currency': 'GHS'},
      {'amount': 127, 'currency': 'USD'},
      {'amount': 79, 'currency': 'USD'},
    ];

    test('turns each amount into dollars before adding', () {
      // 131.46 + 16 + 100 + 206
      expect(WalletMoney.sumInUsd(held, rates), closeTo(453.46, 0.01));
    });

    test(
      'leaves out a currency with no rate instead of counting it as dollars',
      () {
        expect(
          WalletMoney.sumInUsd(const [
            {'amount': 50, 'currency': 'USD'},
            {'amount': 9000, 'currency': 'ZZZ'},
          ], rates),
          50,
        );
        // No rates at all: only dollars.
        expect(WalletMoney.sumInUsd(held, null), 206);
      },
    );

    test('decimals count; an amount that is not a number is skipped', () {
      expect(
        WalletMoney.sumInUsd(const [
          {'amount': 68.5, 'currency': 'USD'},
          {'amount': '12', 'currency': 'USD'},
        ], rates),
        68.5,
      );
    });
  });

  group('format', () {
    test("in the member's currency", () {
      expect(WalletMoney.format(320, 'USD', rates), r'$320.00');
      expect(WalletMoney.format(100, 'EUR', rates), '€90.00');
      expect(WalletMoney.format(100, 'XOF', rates), 'XOF 58,400');
    });

    test('in dollars while the rate is not known', () {
      expect(WalletMoney.format(68, 'XOF', null), r'$68.00');
      expect(WalletMoney.shown('XOF', null), 'USD');
      expect(WalletMoney.shown('EUR', rates), 'EUR');
      expect(WalletMoney.hasSymbol('XOF'), isFalse);
    });
  });
}
