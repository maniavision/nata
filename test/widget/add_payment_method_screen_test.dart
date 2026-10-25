import 'package:carrywise_app/screens/add_payment_method_screen.dart';
import 'package:carrywise_app/screens/payment_settings_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Opens the Add screen on top of a host page; [result] gets what it pops.
  Future<List<PaymentMethod?>> pumpAdd(
    WidgetTester tester, {
    PaymentOptions options = PaymentOptions.cards,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final results = <PaymentMethod?>[];
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<PaymentMethod>(
                  MaterialPageRoute(
                    builder: (_) => AddPaymentMethodScreen(
                      holderFirstName: 'Fortune',
                      loadOptions: () async => options,
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    await t.enterText(find.byKey(ValueKey(key)), text);
    await t.pump();
  }

  Future<void> save(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('add-payment-save')));
    await t.pumpAndSettle();
  }

  String? error(WidgetTester t) {
    final f = find.byKey(const ValueKey('add-payment-error'));
    return f.evaluate().isEmpty ? null : t.widget<Text>(f).data;
  }

  Future<void> fillCard(WidgetTester t) async {
    await enter(t, 'add-payment-card-name', 'Fortune Niama');
    await enter(t, 'add-payment-card-number', '5555555555554444');
    await enter(t, 'add-payment-card-expiry', '0830');
    await enter(t, 'add-payment-card-cvv', '123');
  }

  group('AddPaymentMethodScreen', () {
    testWidgets('opens on the card form', (tester) async {
      await pumpAdd(tester);

      expect(find.text('Add Payment Method'), findsOneWidget);
      expect(find.text('Card Details'), findsOneWidget);
      expect(find.text('NAME ON CARD'), findsOneWidget);
      expect(find.text('Save Payment Method'), findsOneWidget);
    });

    testWidgets('formats the card number and expiry as typed', (tester) async {
      await pumpAdd(tester);

      await enter(tester, 'add-payment-card-number', '4242424242424242');
      await enter(tester, 'add-payment-card-expiry', '0827');

      String text(String key) =>
          tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
      expect(text('add-payment-card-number'), '4242 4242 4242 4242');
      expect(text('add-payment-card-expiry'), '08/27');
    });

    testWidgets('checks each card field in turn', (tester) async {
      await pumpAdd(tester);

      await save(tester);
      expect(error(tester), 'Enter the name as it appears on the card.');

      await enter(tester, 'add-payment-card-name', 'Fortune Niama');
      await enter(tester, 'add-payment-card-number', '4242424242424241');
      await save(tester);
      expect(error(tester), 'Enter a valid card number.');

      await enter(tester, 'add-payment-card-number', '4242424242424242');
      await enter(tester, 'add-payment-card-expiry', '0120');
      await save(tester);
      expect(error(tester), 'Enter a valid expiry date (MM/YY).');

      await enter(tester, 'add-payment-card-expiry', '0830');
      await save(tester);
      expect(error(tester), 'Enter the 3 or 4 digit security code.');
    });

    testWidgets('a valid card comes back masked', (tester) async {
      final results = await pumpAdd(tester);
      await fillCard(tester);

      await save(tester);

      final m = results.single!;
      expect(m.kind, PaymentMethodKind.card);
      expect(m.title, 'Mastercard •••• 4444');
      expect(m.expiry, '08/30');
      expect(m.cardHolderName, 'Fortune Niama');
      expect(m.isDefault, isFalse);
      // Nothing secret leaves the screen.
      final row = m.toInsertJson('u').values.join(' ');
      expect(row, isNot(contains('5555555555554444')));
      expect(row, isNot(contains('123')));
    });

    const congo = PaymentOptions(
      countryCode: 'CG',
      countryName: 'Republic of the Congo',
      dialCode: '+242',
      mobileMoney: true,
      networks: [
        (code: 'MTN_MOMO_COG', name: 'MTN Mobile Money'),
        (code: 'AIRTEL_COG', name: 'Airtel Money'),
      ],
    );

    testWidgets('living where pawaPay takes it: mobile money only', (
      tester,
    ) async {
      final results = await pumpAdd(tester, options: congo);

      expect(
        find.text(
          'You live in Republic of the Congo, so you pay by mobile money.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('add-payment-kind-card')), findsNothing);
      expect(
        find.byKey(const ValueKey('add-payment-kind-applePay')),
        findsNothing,
      );
      expect(find.text('Airtel Money'), findsOneWidget);
      expect(find.text('+242  '), findsOneWidget);

      // The network first, then a whole number, then the name.
      await enter(tester, 'add-payment-mobile-number', '05 512 3456');
      await enter(tester, 'add-payment-mobile-name', 'Fortune Niama');
      await save(tester);
      expect(error(tester), 'Choose your network.');

      await tester.tap(
        find.byKey(const ValueKey('add-payment-network-AIRTEL_COG')),
      );
      await enter(tester, 'add-payment-mobile-number', '05');
      await save(tester);
      expect(error(tester), 'Enter the whole mobile number.');

      await enter(tester, 'add-payment-mobile-number', '05 512 3456');
      await save(tester);
      final m = results.single!;
      expect(m.kind, PaymentMethodKind.mobileMoney);
      expect(m.mobileNetwork, 'AIRTEL_COG');
      expect(m.mobileProvider, 'Airtel Money');
      expect(m.mobileNumber, '+242055123456');
      expect(m.title, 'Airtel Money •••• 3456');
    });

    testWidgets('living elsewhere: card and Apple Pay only', (tester) async {
      await pumpAdd(tester);
      expect(
        find.byKey(const ValueKey('add-payment-kind-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-payment-kind-applePay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-payment-kind-mobileMoney')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('add-payment-mobile-only')),
        findsNothing,
      );
    });

    test('a saved wallet keeps its pawaPay network', () {
      const m = PaymentMethod(
        kind: PaymentMethodKind.mobileMoney,
        mobileProvider: 'Airtel Money',
        mobileNetwork: 'AIRTEL_COG',
        mobileNumber: '+242055123456',
        mobileRegisteredName: 'Fortune Niama',
      );
      expect(m.toInsertJson('u1')['mobile_network'], 'AIRTEL_COG');
      final back = PaymentMethod.fromJson({
        'id': 'pm1',
        'kind': 'mobile_money',
        'mobile_provider': 'Airtel Money',
        'mobile_network': 'AIRTEL_COG',
        'mobile_number': '+242055123456',
      });
      expect(back.mobileNetwork, 'AIRTEL_COG');
    });

    testWidgets('Apple Pay needs nothing to fill', (tester) async {
      final results = await pumpAdd(tester);
      await tester.tap(find.byKey(const ValueKey('add-payment-kind-applePay')));
      await tester.pump();
      expect(find.textContaining('Face ID'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-payment-default')));
      await save(tester);

      final m = results.single!;
      expect(m.title, 'Apple Pay');
      expect(m.walletDeviceLabel, "Fortune's iPhone");
      expect(m.isDefault, isTrue);
    });

    testWidgets('back adds nothing', (tester) async {
      final results = await pumpAdd(tester);

      await tester.tap(find.byKey(const ValueKey('add-payment-back')));
      await tester.pumpAndSettle();

      expect(results.single, isNull);
    });

    testWidgets('is translated', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          const AddPaymentMethodScreen(holderFirstName: 'Fortune'),
          locale: const Locale('fr'),
        ),
      );
      await tester.pump();

      expect(find.text('Ajouter un moyen de paiement'), findsOneWidget);
    });
  });

  group('from Payment Settings', () {
    late FakePaymentService payments;
    setUp(() => payments = FakePaymentService(methods: samplePaymentMethods()));

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          PaymentSettingsScreen(
            availableBalance: 320,
            escrowBalance: 180,
            holderName: 'Fortune Niama',
            service: payments,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-methods-add')));
      await tester.pumpAndSettle();
    }

    testWidgets('Add opens the screen; a saved card joins the list', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(find.byType(AddPaymentMethodScreen), findsOneWidget);

      await fillCard(tester);
      await save(tester);

      expect(find.byType(AddPaymentMethodScreen), findsNothing);
      expect(payments.saved.last.title, 'Mastercard •••• 4444');
      expect(find.text('Mastercard •••• 4444'), findsOneWidget);
      expect(find.text('Expires 08/30'), findsOneWidget);
      // Apple Pay keeps the Default chip.
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('a new default takes over the Default chip', (tester) async {
      await pumpSettings(tester);
      await fillCard(tester);
      await tester.tap(find.byKey(const ValueKey('add-payment-default')));

      await save(tester);

      expect(find.text('Default'), findsOneWidget);
      // Apple Pay lost it, so it can be removed now.
      expect(
        find.byKey(const ValueKey('payment-method-remove-apple-pay')),
        findsOneWidget,
      );
    });
  });
}
