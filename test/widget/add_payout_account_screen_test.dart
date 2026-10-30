import 'package:carrywise_app/screens/add_payout_account_screen.dart';
import 'package:carrywise_app/screens/payment_settings_screen.dart';
import 'package:carrywise_app/services/country_service.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Adding where a traveler is paid: a bank or mobile money that Nata
/// pays out to in their country.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const nigeria = Country(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234');
  const kenya = Country(isoCode: 'KE', name: 'Kenya', phoneCode: '+254');
  const france = Country(isoCode: 'FR', name: 'France', phoneCode: '+33');

  late FakePaymentService payments;
  PayoutAccount? popped;

  setUp(() {
    payments = FakePaymentService();
    popped = null;
  });

  final opened = <Uri>[];
  setUp(opened.clear);

  Future<void> pump(
    WidgetTester tester, {
    Country country = nigeria,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<PayoutAccount>(
                  MaterialPageRoute(
                    builder: (_) => AddPayoutAccountScreen(
                      service: payments,
                      initialCountry: country,
                      travelerName: () async => (first: 'Amara', last: 'Kalu'),
                      openStripePage: (link) async {
                        opened.add(link);
                        return true;
                      },
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('payout-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String number, String holder) async {
    await tester.enterText(find.byKey(const ValueKey('payout-number')), number);
    await tester.enterText(find.byKey(const ValueKey('payout-holder')), holder);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('payout-save')));
    await tester.tap(find.byKey(const ValueKey('payout-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('a bank account: saved, and waiting payouts go out', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Nigeria'), findsOneWidget);
    // Nigeria has banks only: no bank / mobile money toggle.
    expect(find.byKey(const ValueKey('payout-kind-mobileMoney')), findsNothing);
    await pick(tester, 'GTBank');
    await fill(tester, '0690000031', 'Amara Kalu');
    await save(tester);

    final a = payments.addedAccounts.single;
    expect(a.kind, PayoutAccountKind.bank);
    expect(a.country, 'NG');
    expect(a.code, '058');
    expect(a.number, '0690000031');
    expect(a.holder, 'Amara Kalu');
    expect(payments.payoutsSent, 1);
    expect(popped?.accountLast4, '0031');
    expect(find.text('Payout account saved.'), findsOneWidget);
  });

  testWidgets('mobile money: the number gets its country code', (tester) async {
    await pump(tester, country: kenya);

    await tester.tap(find.byKey(const ValueKey('payout-kind-mobileMoney')));
    await tester.pumpAndSettle();
    expect(find.text('+254 '), findsOneWidget);
    await pick(tester, 'M-Pesa');
    await fill(tester, '0712 345 678', 'Amara Kalu');
    await save(tester);

    final a = payments.addedAccounts.single;
    expect(a.kind, PayoutAccountKind.mobileMoney);
    expect(a.code, 'MPS');
    expect(a.number, '254712345678');
  });

  testWidgets('pawaPay networks only (no banks): straight to mobile money', (
    tester,
  ) async {
    const congo = Country(
      isoCode: 'CG',
      name: 'Republic of the Congo',
      phoneCode: '+242',
    );
    payments.options['CG'] = const PayoutOptions(
      currency: 'XAF',
      mobileMoney: [
        PayoutProvider('MTN_MOMO_COG', 'MTN Mobile Money'),
        PayoutProvider('AIRTEL_COG', 'Airtel Money'),
      ],
    );
    await pump(tester, country: congo);

    // No bank / mobile money toggle: mobile money is the only kind.
    expect(find.byKey(const ValueKey('payout-kind-bank')), findsNothing);
    expect(find.text('+242 '), findsOneWidget);
    await pick(tester, 'Airtel Money');
    await fill(tester, '05 123 4567', 'Amara Kalu');
    await save(tester);

    final a = payments.addedAccounts.single;
    expect(a.kind, PayoutAccountKind.mobileMoney);
    expect(a.code, 'AIRTEL_COG');
    expect(a.number, '242051234567');
  });

  testWidgets('the country is the country of residence: shown, locked', (
    tester,
  ) async {
    await pump(tester, country: kenya);

    expect(find.text('Kenya'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(
      find.text(
        'Your country of residence. Payouts are sent to an account there.',
      ),
      findsOneWidget,
    );
    // Tapping it changes nothing: there is no country to pick.
    await tester.tap(find.byKey(const ValueKey('payout-country')));
    await tester.pumpAndSettle();
    expect(find.text('Kenya'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(payments.payoutOptionCountries, ['KE']);
  });

  testWidgets('a country other than the residence is refused, and said', (
    tester,
  ) async {
    payments.failAddAccount = const PayoutAccountException(
      PayoutAccountFailure.countryMismatch,
    );
    await pump(tester);
    await pick(tester, 'GTBank');
    await fill(tester, '0690000031', 'Amara Kalu');
    await save(tester);

    expect(
      find.text('Payout accounts must be in your country of residence.'),
      findsOneWidget,
    );
    expect(popped, isNull);
  });

  testWidgets('a country Nata can\'t pay out to says so', (tester) async {
    await pump(tester, country: france);

    expect(find.text("Nata can't pay out to France yet."), findsOneWidget);
    expect(find.byKey(const ValueKey('payout-save')), findsNothing);
  });

  testWidgets('Save waits for a bank, and checks the fields', (tester) async {
    await pump(tester);

    ElevatedButton button() =>
        tester.widget(find.byKey(const ValueKey('payout-save')));
    expect(button().onPressed, isNull);

    await pick(tester, 'Access Bank');
    await fill(tester, '123', 'A');
    await save(tester);

    expect(payments.addedAccounts, isEmpty);
    expect(
      find.text('Check the account number and the holder’s name.'),
      findsOneWidget,
    );
  });

  testWidgets('Nigeria: paid by Flutterwave, under the bank\'s name', (
    tester,
  ) async {
    await pump(tester);
    await pick(tester, 'GTBank');

    expect(find.byKey(const ValueKey('payout-nigeria-note')), findsOneWidget);
    expect(find.textContaining('through Flutterwave'), findsOneWidget);
  });

  testWidgets('an account Flutterwave can\'t find is explained', (
    tester,
  ) async {
    payments.failAddAccount = const PayoutAccountException(
      PayoutAccountFailure.accountNotFound,
    );
    await pump(tester);
    await pick(tester, 'GTBank');
    await fill(tester, '0690000031', 'Amara Kalu');
    await save(tester);

    expect(
      find.textContaining("Flutterwave couldn't find this account"),
      findsOneWidget,
    );
    expect(popped, isNull);
  });

  testWidgets('a bank refused by the server is explained', (tester) async {
    payments.failAddAccount = const PayoutAccountException(
      PayoutAccountFailure.notSupported,
    );
    await pump(tester);
    await pick(tester, 'GTBank');
    await fill(tester, '0690000031', 'Amara Kalu');
    await save(tester);

    expect(find.textContaining("can't receive payouts yet"), findsOneWidget);
    expect(popped, isNull);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));

    expect(find.text('Ajouter un compte de versement'), findsWidgets);
    expect(find.text('NUMÉRO DE COMPTE'), findsOneWidget);
  });

  testWidgets('Payment Settings opens it and shows the new account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        PaymentSettingsScreen(
          service: payments,
          availableBalance: 0,
          escrowBalance: 0,
          holderName: 'Amara Kalu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('payout-account-add')),
    );
    await tester.tap(find.byKey(const ValueKey('payout-account-add')));
    await tester.pumpAndSettle();

    expect(find.byType(AddPayoutAccountScreen), findsOneWidget);
  });

  testWidgets('starts on the country of residence from the profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        AddPayoutAccountScreen(
          service: payments,
          residenceCountry: () async => 'KE',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(payments.payoutOptionCountries.last, 'KE');
  });

  group('a bank through Stripe (where Stripe pays out)', () {
    const us = Country(isoCode: 'US', name: 'United States', phoneCode: '+1');
    const uk = Country(isoCode: 'GB', name: 'United Kingdom', phoneCode: '+44');
    setUp(() {
      for (final c in ['US', 'GB']) {
        payments.options[c] = PayoutOptions(
          currency: c == 'US' ? 'USD' : 'GBP',
          banks: const [PayoutProvider('STRIPE', 'Bank account (Stripe)')],
        );
      }
    });

    const saved = PayoutAccount(
      id: 'pa-stripe',
      kind: PayoutAccountKind.bank,
      institutionName: 'STRIPE TEST BANK',
      countryCode: 'US',
      accountLast4: '6789',
      holderName: 'Amara Kalu',
      isDefault: true,
    );

    Future<void> enter(WidgetTester tester, String key, String text) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.enterText(find.byKey(ValueKey(key)), text);
      await tester.pump();
    }

    Future<void> pickDob(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('stripe-dob')));
      await tester.tap(find.byKey(const ValueKey('stripe-dob')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    Future<void> fillUs(WidgetTester tester) async {
      await pickDob(tester);
      await enter(tester, 'stripe-phone', '2025550123');
      await enter(tester, 'stripe-line1', '1 Main St');
      await enter(tester, 'stripe-city', 'Austin');
      await enter(tester, 'stripe-state', 'tx');
      await enter(tester, 'stripe-postal', '78701');
      await enter(tester, 'stripe-ssn', '0000');
      await enter(tester, 'stripe-routing', '110000000');
      await enter(tester, 'stripe-account', '000123456789');
      await tester.ensureVisible(find.byKey(const ValueKey('stripe-agree')));
      await tester.tap(find.byKey(const ValueKey('stripe-agree')));
      await tester.pump();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('stripe-save')));
      await tester.tap(find.byKey(const ValueKey('stripe-save')));
      await tester.pumpAndSettle();
    }

    testWidgets('US: the form in the app, sent to Stripe as given', (
      tester,
    ) async {
      await pump(tester, country: us);

      expect(find.byKey(const ValueKey('stripe-form')), findsOneWidget);
      // The name comes from the profile.
      expect(find.text('Amara'), findsOneWidget);
      expect(find.byKey(const ValueKey('stripe-ssn')), findsOneWidget);
      expect(find.byKey(const ValueKey('payout-save')), findsNothing);

      await fillUs(tester);
      await save(tester);

      final d = payments.stripeSubmitted.single;
      expect(d.firstName, 'Amara');
      expect(d.lastName, 'Kalu');
      expect(d.state, 'TX');
      expect(d.idNumber, '0000');
      expect(d.routingNumber, '110000000');
      expect(d.accountNumber, '000123456789');
      expect(d.email, isNull);
      expect(opened, isEmpty); // no Stripe page
      // Stripe is checking it.
      expect(find.text('Stripe is checking your details'), findsOneWidget);
    });

    testWidgets('a form not filled in says so and sends nothing', (
      tester,
    ) async {
      await pump(tester, country: us);
      await save(tester);
      expect(
        find.text('Fill in every field and accept the agreement.'),
        findsOneWidget,
      );
      expect(payments.stripeSubmitted, isEmpty);
    });

    testWidgets('accepted straight away: saved and closed', (tester) async {
      payments.stripeSubmitResult = (
        status: StripeBankStatus.enabled,
        account: saved,
        bank: null,
      );
      await pump(tester, country: us);
      await fillUs(tester);
      await save(tester);

      expect(popped?.id, 'pa-stripe');
      expect(payments.payoutsSent, 1);
      expect(find.text('Payout account saved.'), findsOneWidget);
    });

    testWidgets('what Stripe refuses is shown in its words', (tester) async {
      payments.failStripeSubmit = const PayoutAccountException(
        PayoutAccountFailure.invalid,
        'Routing number must have 9 digits',
      );
      await pump(tester, country: us);
      await fillUs(tester);
      await save(tester);
      expect(find.text('Routing number must have 9 digits'), findsOneWidget);
      expect(find.byKey(const ValueKey('stripe-form')), findsOneWidget);
    });

    testWidgets('no email known: asked for in the form, then sent', (
      tester,
    ) async {
      payments.failStripeSubmit = const PayoutAccountException(
        PayoutAccountFailure.emailRequired,
      );
      await pump(tester, country: us);
      await fillUs(tester);
      await save(tester);
      expect(find.byKey(const ValueKey('stripe-email')), findsOneWidget);

      await enter(tester, 'stripe-email', 'amara@example.com');
      await save(tester);
      expect(payments.stripeSubmitted.last.email, 'amara@example.com');
    });

    testWidgets('Stripe needs more: finished on Stripe\'s page', (
      tester,
    ) async {
      payments.stripeStatuses = [
        (status: StripeBankStatus.actionNeeded, account: null, bank: null),
        (status: StripeBankStatus.enabled, account: saved, bank: null),
      ];
      await pump(tester, country: us);

      expect(find.text('Stripe needs a little more'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stripe-finish')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://connect.stripe.test/setup/1')]);

      await tester.tap(find.byKey(const ValueKey('stripe-check')));
      await tester.pumpAndSettle();
      expect(popped?.id, 'pa-stripe');
    });

    const StripeConnectedBank testBank = (
      institution: 'Stripe test bank',
      last4: '6789',
    );

    testWidgets('a connected bank removed before is shown, not re-added', (
      tester,
    ) async {
      payments.stripeStatuses = [
        (status: StripeBankStatus.enabled, account: null, bank: testBank),
        (status: StripeBankStatus.enabled, account: saved, bank: testBank),
      ];
      await pump(tester, country: us);

      // Opening only shows it: nothing saved, the screen stays, no form.
      expect(popped, isNull);
      expect(payments.stripeSaves, [false]);
      expect(find.text('Your bank is connected'), findsOneWidget);
      expect(
        find.text('Stripe test bank •••• 6789, connected with Stripe.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('stripe-form')), findsNothing);

      // "Use this bank" saves it.
      await tester.tap(find.byKey(const ValueKey('stripe-use')));
      await tester.pumpAndSettle();
      expect(payments.stripeSaves, [false, true]);
      expect(popped?.id, 'pa-stripe');
      expect(find.text('Payout account saved.'), findsOneWidget);
    });

    testWidgets('another bank: the form opens from the connected card', (
      tester,
    ) async {
      payments.stripeStatuses = [
        (status: StripeBankStatus.enabled, account: null, bank: testBank),
      ];
      await pump(tester, country: us);
      await tester.tap(find.byKey(const ValueKey('stripe-change')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stripe-form')), findsOneWidget);
      expect(popped, isNull);
    });

    testWidgets('a bank already among the payout accounts: Done', (
      tester,
    ) async {
      payments.stripeStatuses = [
        (status: StripeBankStatus.enabled, account: saved, bank: testBank),
      ];
      await pump(tester, country: us);

      expect(popped, isNull);
      expect(
        find.textContaining("It's already one of your payout accounts"),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('stripe-use')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('stripe-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stripe-connected')), findsNothing);
      expect(payments.payoutsSent, 0);
    });

    testWidgets('UK: sort code, no SSN, postcode', (tester) async {
      await pump(tester, country: uk);
      expect(find.byKey(const ValueKey('stripe-ssn')), findsNothing);
      expect(find.byKey(const ValueKey('stripe-state')), findsNothing);
      expect(find.text('Sort code'), findsOneWidget);
      expect(find.text('Postcode'), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, country: us, locale: const Locale('fr'));
      expect(find.text('Enregistrer le compte bancaire'), findsOneWidget);
    });
  });
}
