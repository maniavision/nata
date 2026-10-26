import 'package:carrywise_app/screens/payment_settings_screen.dart';
import 'package:carrywise_app/screens/wallet_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The Wallet page: the Nata Wallet card, Payment Settings and the activity.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakePaymentService> pumpWallet(
    WidgetTester tester, {
    FakeAuthService? auth,
    List<WalletEntry> history = const [],
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final payments = FakePaymentService()..history = history;
    await tester.pumpWidget(
      appWrapper(
        WalletScreen(
          authService: auth ?? FakeAuthService(),
          paymentService: payments,
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return payments;
  }

  testWidgets('shows the balance, the escrow and Payment Settings', (
    tester,
  ) async {
    await pumpWallet(
      tester,
      auth: FakeAuthService(
        balances: const {'available': 1234.5, 'escrow': 99},
      ),
    );

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('NATA WALLET'), findsOneWidget);
    expect(find.text(r'$1,234.50'), findsOneWidget);
    expect(find.text(r'$99.00 held in Escrow'), findsOneWidget);
    expect(find.text('Payment Settings'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    // The activity is on the page: no separate history link.
    expect(find.byKey(const ValueKey('wallet-view-history')), findsNothing);
  });

  testWidgets('Withdraw sends the waiting payouts', (tester) async {
    final payments = await pumpWallet(tester);

    await tester.tap(find.byKey(const ValueKey('wallet-withdraw')));
    await tester.pumpAndSettle();

    expect(payments.payoutsSent, 1);
  });

  testWidgets('Payment Settings opens from the page', (tester) async {
    await pumpWallet(tester);

    await tester.tap(find.byKey(const ValueKey('wallet-payment-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentSettingsScreen), findsOneWidget);
  });

  testWidgets('the payouts and payments are listed, with filters', (
    tester,
  ) async {
    WalletEntry entry(String id, WalletEntryKind kind, String item) =>
        WalletEntry(
          kind: kind,
          id: id,
          amount: 45,
          currency: 'USD',
          status: kind == WalletEntryKind.payout
              ? WalletEntryStatus.paid
              : WalletEntryStatus.released,
          date: DateTime(2025, 6, 20),
          item: item,
          fromCity: 'Lagos',
          toCity: 'London',
          otherName: 'Sarah',
        );
    await pumpWallet(
      tester,
      history: [
        entry('a', WalletEntryKind.payout, 'iPad Mini'),
        entry('b', WalletEntryKind.payment, 'Shoes'),
      ],
    );

    expect(find.textContaining('iPad Mini'), findsOneWidget);
    expect(find.textContaining('Shoes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-filter-payouts')));
    await tester.pumpAndSettle();
    expect(find.textContaining('iPad Mini'), findsOneWidget);
    expect(find.textContaining('Shoes'), findsNothing);
  });

  testWidgets('no activity yet shows the empty state', (tester) async {
    await pumpWallet(tester);

    expect(find.byKey(const ValueKey('wallet-history-empty')), findsOneWidget);
  });

  testWidgets('in French', (tester) async {
    await pumpWallet(tester, locale: const Locale('fr'));

    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Activité'), findsOneWidget);
  });
}
