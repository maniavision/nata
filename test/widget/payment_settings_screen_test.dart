import 'package:carrywise_app/screens/payment_settings_screen.dart';
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
        PaymentSettingsScreen(holderName: 'Fortune Niama', service: payments),
        locale: locale ?? const Locale('en'),
      ),
    );
    await tester.pump();
  }

  group('PaymentSettingsScreen', () {
    testWidgets('no wallet, payout account or transactions', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Payment methods'), findsOneWidget);
      for (final t in [
        '\$320.00',
        'PAYOUT ACCOUNT',
        'TRANSACTIONS',
        'Payout Schedule',
      ]) {
        expect(find.text(t), findsNothing, reason: t);
      }
    });

    testWidgets('shows every section of the design', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      for (final t in [
        'PAYMENT METHODS',
        'PREFERENCES',
        'Apple Pay',
        "Fortune's iPhone",
        'Visa •••• 4242',
        'Default Currency',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
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
        find.byKey(const ValueKey('stripe-card-remove-visa-4242')),
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
      expect(payments.cards, hasLength(1));

      await tester.tap(
        find.byKey(const ValueKey('stripe-card-remove-visa-4242')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('stripe-card-remove-confirm')),
      );
      await tester.pumpAndSettle();

      // Removed from Stripe.
      expect(payments.cards, isEmpty);
      expect(find.text('Visa •••• 4242'), findsNothing);
      expect(find.text('Apple Pay'), findsOneWidget);
    });

    testWidgets('the default can be removed too; another takes its place', (
      tester,
    ) async {
      payments = FakePaymentService(
        methods: const [
          PaymentMethod(
            id: 'apple-pay',
            kind: PaymentMethodKind.applePay,
            isDefault: true,
            walletDeviceLabel: "Fortune's iPhone",
          ),
          PaymentMethod(
            id: 'mpesa',
            kind: PaymentMethodKind.mobileMoney,
            mobileProvider: 'M-Pesa',
            mobileNetwork: 'MPESA_KEN',
            mobileNumber: '+254712345678',
          ),
        ],
      );
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

      expect(payments.saved.map((m) => m.id), ['mpesa']);
      expect(payments.saved.single.isDefault, isTrue);
      expect(find.text('Apple Pay'), findsNothing);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('no methods yet', (tester) async {
      payments = FakePaymentService();
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('No payment method yet'), findsOneWidget);
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
        find.byKey(const ValueKey('stripe-card-remove-visa-4242')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('stripe-card-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visa •••• 4242'), findsOneWidget);
      expect(
        find.text('Could not save the change. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Moyens de paiement'), findsOneWidget);
      expect(find.text('MOYENS DE PAIEMENT'), findsOneWidget);
    });
  });

  group('Stripe cards', () {
    testWidgets('several cards: the default is marked, another made default', (
      tester,
    ) async {
      payments.cards = [
        ...payments.cards,
        const StripeCard(
          id: 'pm_mc',
          brand: 'mastercard',
          last4: '5555',
          expMonth: 11,
          expYear: 2028,
        ),
      ];
      payments.cards = [
        for (final c in payments.cards)
          StripeCard(
            id: c.id,
            brand: c.brand,
            last4: c.last4,
            expMonth: c.expMonth,
            expYear: c.expYear,
            isDefault: c.id == 'visa-4242',
          ),
      ];
      await pump(tester);

      expect(find.text('Mastercard •••• 5555'), findsOneWidget);
      expect(find.byKey(const ValueKey('stripe-cards-note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stripe-card-default-pm_mc')));
      await tester.pumpAndSettle();

      expect(
        payments.cards.firstWhere((c) => c.id == 'pm_mc').isDefault,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('stripe-card-default-visa-4242')),
        findsOneWidget,
      );
    });

    testWidgets('cards that can\'t be loaded leave the rest', (tester) async {
      payments.failCards = true;
      await pump(tester);

      expect(find.text('Apple Pay'), findsOneWidget);
      expect(find.text('Visa •••• 4242'), findsNothing);
    });
  });
}
