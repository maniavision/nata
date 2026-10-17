import 'package:carrywise_app/screens/add_payout_account_screen.dart';
import 'package:carrywise_app/screens/payment_settings_screen.dart';
import 'package:carrywise_app/services/country_service.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Adding where a traveler is paid: a bank or mobile money that Flutterwave
/// pays out to in their country.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const nigeria = Country(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234');
  const kenya = Country(isoCode: 'KE', name: 'Kenya', phoneCode: '+254');
  const france = Country(isoCode: 'FR', name: 'France', phoneCode: '+33');

  late FakePaymentService payments;
  PayoutAccount? popped;
  Country pickNext = kenya;

  setUp(() {
    payments = FakePaymentService();
    popped = null;
    pickNext = kenya;
  });

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
                      countryPicker: (_, _) async => pickNext,
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

  testWidgets('another country loads its own options', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('payout-country')));
    await tester.pumpAndSettle();

    expect(find.text('Kenya'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('payout-kind-mobileMoney')),
      findsOneWidget,
    );
  });

  testWidgets('a country Flutterwave can\'t pay out to says so', (
    tester,
  ) async {
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
}
