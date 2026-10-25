import 'package:carrywise_app/screens/wallet_history_screen.dart';
import 'package:carrywise_app/screens/payment_settings_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => PreferencesService().setCurrency(AppCurrency.usd));

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  late FakePaymentService payments;
  setUp(
    () => payments = FakePaymentService(
      methods: samplePaymentMethods(),
      accounts: [samplePayoutAccount()],
    ),
  );

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    bigScreen(tester);
    await tester.pumpWidget(
      appWrapper(
        PaymentSettingsScreen(
          availableBalance: 320,
          escrowBalance: 180,
          holderName: 'Fortune Niama',
          service: payments,
        ),
        locale: locale ?? const Locale('en'),
      ),
    );
    await tester.pump();
  }

  group('PaymentSettingsScreen', () {
    testWidgets('shows the wallet balances it is given', (tester) async {
      await pump(tester);

      expect(find.text('Payment Settings'), findsOneWidget);
      expect(find.text('\$320.00'), findsOneWidget);
      expect(find.text('\$180.00 held in Escrow'), findsOneWidget);
    });

    testWidgets('shows every section of the design', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      for (final t in [
        'PAYMENT METHODS',
        'PAYOUT ACCOUNT',
        'PREFERENCES',
        'TRANSACTIONS',
        'Apple Pay',
        "Fortune's iPhone",
        'Visa •••• 4242',
        'Barclays Bank',
        'GB •••• 2093 · Fortune Niama',
        'Add payout account',
        'Default Currency',
        'Payout Schedule',
        'Automatic',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // No sample transactions: nothing yet.
      expect(
        find.byKey(const ValueKey('payment-transactions-empty')),
        findsOneWidget,
      );
    });

    testWidgets('the latest transactions, and View all', (tester) async {
      payments.history = [
        for (var i = 0; i < 5; i++)
          WalletEntry(
            kind: WalletEntryKind.payout,
            id: 'p$i',
            amount: 45,
            currency: 'USD',
            status: WalletEntryStatus.paid,
            date: DateTime(2030, 6, 24 - i),
            item: 'Item $i',
          ),
      ];
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Payout · Item 0'), findsOneWidget);
      expect(find.text('Payout · Item 2'), findsOneWidget);
      expect(find.text('Payout · Item 3'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('payment-transactions-all')),
      );
      await tester.tap(find.byKey(const ValueKey('payment-transactions-all')));
      await tester.pumpAndSettle();
      expect(find.byType(WalletHistoryScreen), findsOneWidget);
      expect(find.text('Payout · Item 4'), findsOneWidget);
    });

    testWidgets("the default currency is the user's", (tester) async {
      PreferencesService().setCurrency(AppCurrency.eur);
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('EUR (€)'), findsOneWidget);
    });

    testWidgets('Remove deletes the card after confirming', (tester) async {
      await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-visa-4242')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove this payment method?'), findsOneWidget);
      expect(
        find.text('Visa •••• 4242 will be removed from your payment methods.'),
        findsOneWidget,
      );

      // Cancel keeps it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(payments.saved, hasLength(2));

      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-visa-4242')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(payments.saved.map((m) => m.id), ['apple-pay']);
      expect(find.text('Visa •••• 4242'), findsNothing);
      expect(find.text('Apple Pay'), findsOneWidget);
    });

    testWidgets('the default can be removed too; another takes its place', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-apple-pay')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Apple Pay is your default payment method.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(payments.saved.map((m) => m.id), ['visa-4242']);
      expect(payments.saved.single.isDefault, isTrue);
      expect(find.text('Apple Pay'), findsNothing);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('a payout account is removed after confirming', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      final id = payments.accounts.single.id;

      await tester.ensureVisible(
        find.byKey(ValueKey('payout-account-remove-$id')),
      );
      await tester.tap(find.byKey(ValueKey('payout-account-remove-$id')));
      await tester.pumpAndSettle();
      expect(find.text('Remove this payout account?'), findsOneWidget);

      // Cancel keeps it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(payments.removedAccounts, isEmpty);

      await tester.tap(find.byKey(ValueKey('payout-account-remove-$id')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('payout-account-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(payments.removedAccounts, [id]);
      expect(find.text('No payout account yet.'), findsOneWidget);
    });

    testWidgets('no methods or payout account yet', (tester) async {
      payments = FakePaymentService();
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('No payment method yet'), findsOneWidget);
      expect(find.text('No payout account yet.'), findsOneWidget);
    });

    testWidgets('a load failure says so', (tester) async {
      payments.failLoad = true;
      await pump(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load your payment settings. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed removal keeps the card and says so', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      payments.failSave = true;

      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-visa-4242')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('payment-method-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visa •••• 4242'), findsOneWidget);
      expect(
        find.text('Could not save the change. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the saved payout schedule', (tester) async {
      payments.schedule = PayoutSchedule.weekly;
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Weekly'), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Paramètres de paiement'), findsOneWidget);
      expect(find.text('MOYENS DE PAIEMENT'), findsOneWidget);
    });
  });

  group('from Profile', () {
    testWidgets('the Payment Settings row opens it with the balances', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(ProfileScreen(authService: FakeAuthService())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Settings'), findsOneWidget);
      expect(find.text('Payment methods & payout account'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-payment-settings')));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentSettingsScreen), findsOneWidget);
      // FakeAuthService: 320 available, 150 in escrow.
      expect(
        find.descendant(
          of: find.byType(PaymentSettingsScreen),
          matching: find.text('\$320.00'),
        ),
        findsOneWidget,
      );
      expect(find.text('\$150.00 held in Escrow'), findsWidgets);
    });
  });
}
