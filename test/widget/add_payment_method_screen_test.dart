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
    Future<List<StripeCard>?> Function({required bool makeDefault})? addCard,
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
                      addCard: addCard,
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

  group('AddPaymentMethodScreen', () {
    testWidgets('a card is typed into Stripe\'s form, not here', (
      tester,
    ) async {
      await pumpAdd(tester);

      expect(find.text('Add Payment Method'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-payment-stripe-card')),
        findsOneWidget,
      );
      expect(find.text('Add card securely'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('once Stripe saved the card, it comes back as a card', (
      tester,
    ) async {
      bool? asDefault;
      final results = await pumpAdd(
        tester,
        addCard: ({required bool makeDefault}) async {
          asDefault = makeDefault;
          return const [];
        },
      );
      await tester.tap(find.byKey(const ValueKey('add-payment-default')));
      await save(tester);

      expect(asDefault, isTrue);
      expect(results.single!.kind, PaymentMethodKind.card);
    });

    testWidgets('closing Stripe\'s form stays here', (tester) async {
      final results = await pumpAdd(
        tester,
        addCard: ({required bool makeDefault}) async => null,
      );
      await save(tester);

      expect(results, isEmpty);
      expect(find.byType(AddPaymentMethodScreen), findsOneWidget);
    });

    testWidgets('a card Stripe couldn\'t save says so', (tester) async {
      await pumpAdd(
        tester,
        addCard: ({required bool makeDefault}) async =>
            throw StateError('stripe'),
      );
      await save(tester);

      expect(error(tester), "Couldn't save the card. Try again.");
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

      await save(tester);

      expect(find.byType(AddPaymentMethodScreen), findsNothing);
      expect(payments.cards.last.title, 'Mastercard •••• 4444');
      expect(find.text('Mastercard •••• 4444'), findsOneWidget);
      expect(find.text('Expires 08/30'), findsOneWidget);
      // Apple Pay keeps its Default chip; Visa stays the default card.
      expect(find.text('Default'), findsNWidgets(2));
    });

    testWidgets('a new default takes over the Default chip', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.byKey(const ValueKey('add-payment-default')));

      await save(tester);

      // The new card is the default card now.
      expect(payments.cards.last.isDefault, isTrue);
      expect(
        find.byKey(const ValueKey('stripe-card-default-visa-4242')),
        findsOneWidget,
      );
    });
  });
}
