import 'package:carrywise_app/screens/chat_thread_screen.dart';
import 'package:carrywise_app/screens/checkout_escrow_screen.dart';
import 'package:carrywise_app/screens/payment_settings_screen.dart';
import 'package:carrywise_app/screens/wallet_history_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The Nata balance: earnings and refunds kept in Nata, spent at checkout.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('checkout', () {
    final now = DateTime(2030, 6, 21, 12);
    late FakeRequestService service;
    setUp(() => service = FakeRequestService()..kind = CheckoutKind.card);

    Future<void> pump(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(
          CheckoutEscrowScreen(
            request: sampleSentRequest(
              status: 'accepted',
              displayCurrency: 'USD',
              displayCost: 40,
              displayFee: 5,
              displayTotal: 45,
              expiresAt: now.add(const Duration(hours: 20)),
              ticketCheckedAt: DateTime(2030, 6, 21, 9),
              travelerVerified: true,
              ticketReceiptPath: 'traveler-1/ticket.pdf',
              hasBookingReference: true,
            ),
            service: service,
            paymentService: FakePaymentService(),
            now: () => now,
            messageService: FakeMessageService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('enough balance: offered first, and pays it all', (
      tester,
    ) async {
      service.balance = const BalanceCheckout(
        total: 45,
        currency: 'USD',
        available: 320,
        covers: true,
      );
      await pump(tester);

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('checkout-balance-available')),
            )
            .data,
        allOf(contains('320'), contains('available')),
      );
      final pay = find.byKey(const ValueKey('checkout-pay-balance'));
      expect(pay, findsOneWidget);
      expect(find.textContaining('from balance'), findsOneWidget);

      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      expect(service.paidWithBalance, isNotEmpty);
      expect(find.byType(ChatForRequest), findsOneWidget);
    });

    testWidgets('choosing a card instead goes back to the card button', (
      tester,
    ) async {
      service.balance = const BalanceCheckout(
        total: 45,
        currency: 'USD',
        available: 320,
        covers: true,
      );
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('checkout-method-1')));
      await tester.pump();

      expect(find.byKey(const ValueKey('checkout-pay-balance')), findsNothing);
      expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
    });

    testWidgets('not enough: shown, but can\'t be chosen', (tester) async {
      service.balance = const BalanceCheckout(
        total: 45,
        currency: 'USD',
        available: 20,
        covers: false,
      );
      await pump(tester);

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('checkout-balance-available')),
            )
            .data,
        allOf(startsWith('Not enough balance'), contains('20')),
      );
      await tester.tap(find.byKey(const ValueKey('checkout-method-balance')));
      await tester.pump();
      expect(find.byKey(const ValueKey('checkout-pay-balance')), findsNothing);
    });

    testWidgets('an empty balance isn\'t offered', (tester) async {
      service.balance = const BalanceCheckout(
        total: 45,
        currency: 'USD',
        available: 0,
        covers: false,
      );
      await pump(tester);

      expect(
        find.byKey(const ValueKey('checkout-method-balance')),
        findsNothing,
      );
    });

    testWidgets('spent elsewhere meanwhile: says so, stays on checkout', (
      tester,
    ) async {
      service.balance = const BalanceCheckout(
        total: 45,
        currency: 'USD',
        available: 320,
        covers: true,
      );
      service.failBalancePay = const RequestException(
        RequestFailure.balanceTooLow,
      );
      await pump(tester);

      final pay = find.byKey(const ValueKey('checkout-pay-balance'));
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your Nata balance no longer covers this. Choose another way to pay.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ChatForRequest), findsNothing);
    });
  });

  group('Payment Settings', () {
    Future<FakePaymentService> pump(
      WidgetTester tester, {
      FakePaymentService? payments,
    }) async {
      bigScreen(tester);
      final p = payments ?? FakePaymentService();
      await tester.pumpWidget(
        appWrapper(
          PaymentSettingsScreen(
            availableBalance: 320,
            escrowBalance: 0,
            holderName: 'Fortune Niama',
            service: p,
            exchangeRates: FakeExchangeRateService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return p;
    }

    Switch toggle(WidgetTester tester, String key) =>
        tester.widget<Switch>(find.byKey(ValueKey(key)));

    testWidgets('shows the balance and both switches, off by default', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('payment-settings-balance')),
        findsOneWidget,
      );
      expect(find.textContaining(r'$320.00 available'), findsOneWidget);
      expect(toggle(tester, 'payment-settings-keep-earnings').value, isFalse);
      expect(
        toggle(tester, 'payment-settings-refunds-to-balance').value,
        isFalse,
      );
    });

    testWidgets('turning a switch on saves it', (tester) async {
      final payments = await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('payment-settings-keep-earnings')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('payment-settings-refunds-to-balance')),
      );
      await tester.pumpAndSettle();

      expect(payments.balancePreferences.last, (keep: true, refunds: true));
      expect(toggle(tester, 'payment-settings-keep-earnings').value, isTrue);
      // Keeping earnings is the manual payout schedule.
      expect(find.text('Manual'), findsOneWidget);
    });

    testWidgets('a switch that can\'t be saved goes back', (tester) async {
      final payments = FakePaymentService()..failBalancePreferences = true;
      await pump(tester, payments: payments);

      await tester.tap(
        find.byKey(const ValueKey('payment-settings-keep-earnings')),
      );
      await tester.pumpAndSettle();

      expect(toggle(tester, 'payment-settings-keep-earnings').value, isFalse);
    });
  });

  group('wallet history', () {
    WalletEntry entry(Map<String, dynamic> j) => WalletEntry.fromJson({
      'id': 'e1',
      'amount': 45,
      'currency': 'USD',
      'created_at': '2030-06-20T10:00:00Z',
      'item': 'iPad Mini',
      ...j,
    });

    test('reads refunds to the balance, spent earnings, balance payments', () {
      final refund = entry({'kind': 'refund', 'status': 'pending'});
      expect(refund.kind, WalletEntryKind.refund);
      expect(refund.status, WalletEntryStatus.pending);

      final spent = entry({'kind': 'payout', 'status': 'spent'});
      expect(spent.status, WalletEntryStatus.spent);

      final paid = entry({
        'kind': 'payment',
        'status': 'held',
        'method': 'balance',
      });
      expect(paid.fromBalance, isTrue);
    });

    testWidgets('shows them so', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(
          Scaffold(
            body: ListView(
              children: [
                WalletEntryRow(
                  entry: entry({'kind': 'refund', 'status': 'pending'}),
                  locale: 'en',
                ),
                WalletEntryRow(
                  entry: entry({'kind': 'payout', 'status': 'spent'}),
                  locale: 'en',
                ),
                WalletEntryRow(
                  entry: entry({
                    'kind': 'payment',
                    'status': 'held',
                    'method': 'balance',
                  }),
                  locale: 'en',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Refund to balance · iPad Mini'), findsOneWidget);
      expect(find.text('Used for a delivery'), findsOneWidget);
      expect(find.text('Paid from balance · iPad Mini'), findsOneWidget);
    });
  });
}
