import 'package:carrywise_app/screens/delivery_confirm_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// A 1x1 transparent PNG.

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakePaymentService payments;
  late FakeRequestService service;
  setUp(() {
    payments = FakePaymentService(
      accounts: [samplePayoutAccount(), sampleMobilePayoutAccount()],
    );
    service = FakeRequestService();
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        DeliveryConfirmScreen(
          delivery: samplePickedUpDelivery(),
          paymentService: payments,
          requestService: service,
          next: (_) => const Scaffold(body: Text('REVIEW')),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester t, String pin) async {
    for (var i = 0; i < 4; i++) {
      await t.enterText(
        find.byKey(ValueKey('delivery-confirm-pin-$i')),
        pin[i],
      );
    }
    await t.pump();
  }

  bool releaseEnabled(WidgetTester t) => t
      .widget<ElevatedButton>(
        find.byKey(const ValueKey('delivery-confirm-release')),
      )
      .enabled;

  Future<void> release(WidgetTester t) async {
    await t.ensureVisible(
      find.byKey(const ValueKey('delivery-confirm-release')),
    );
    await t.tap(find.byKey(const ValueKey('delivery-confirm-release')));
    await t.pumpAndSettle();
  }

  String status(WidgetTester t) => t
      .widget<Text>(find.byKey(const ValueKey('delivery-confirm-pin-status')))
      .data!;

  testWidgets('shows every section, without the photo option', (tester) async {
    await pump(tester);

    for (final t in [
      'Delivery & Payout Release',
      'STEP 3 OF 4: CONFIRM DELIVERY',
      'Item Arrived at Destination',
      '4-DIGIT DELIVERY CODE',
      'Instant Release',
      'TRAVELER PAYOUT DESTINATION',
      '+\$38.00 Payout',
      'Barclays Bank (•••• 2093)',
      'M-Pesa (•••• 5678)',
      'Confirm & Release Payout (\$38.00)',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('HANDOFF PHOTO'), findsNothing);
    // The agreed rule: paid as soon as the code is confirmed.
    expect(
      find.textContaining('sent as soon as the code is confirmed'),
      findsOneWidget,
    );
  });

  testWidgets('nothing to send before the 4 digits are entered', (
    tester,
  ) async {
    await pump(tester);
    expect(releaseEnabled(tester), isFalse);

    for (var i = 0; i < 3; i++) {
      await tester.enterText(
        find.byKey(ValueKey('delivery-confirm-pin-$i')),
        '749'[i],
      );
    }
    await tester.pump();
    expect(releaseEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('delivery-confirm-pin-3')),
      '2',
    );
    await tester.pump();
    expect(releaseEnabled(tester), isTrue);
  });

  testWidgets('the server checks the code, with the chosen payout account', (
    tester,
  ) async {
    await pump(tester);
    await enterPin(tester, '7492');

    await release(tester);

    expect(service.deliveryAttempts.single.id, 'req-1');
    expect(service.deliveryAttempts.single.code, '7492');
    expect(service.deliveryAttempts.single.account, 'barclays');
    expect(find.text('REVIEW'), findsOneWidget);
    // The payout goes out straight away.
    expect(payments.payoutsSent, 1);
  });

  testWidgets('a wrong code says how many tries are left', (tester) async {
    service.deliveryChecks = [
      (result: DeliveryCheck.wrongCode, attemptsLeft: 3),
    ];
    await pump(tester);
    await enterPin(tester, '1234');

    await release(tester);

    expect(status(tester), "That code isn't right. 3 tries left.");
    expect(payments.payoutsSent, 0);
    expect(find.text('REVIEW'), findsNothing);
    // The boxes are cleared for another try.
    expect(releaseEnabled(tester), isFalse);
  });

  testWidgets('too many wrong codes locks it', (tester) async {
    service.deliveryChecks = [(result: DeliveryCheck.locked, attemptsLeft: 0)];
    await pump(tester);
    await enterPin(tester, '1234');

    await release(tester);

    expect(status(tester), contains('Contact support'));
    await enterPin(tester, '5678');
    expect(releaseEnabled(tester), isFalse);
  });

  testWidgets('no code yet: asks for the one now in the sender\'s app', (
    tester,
  ) async {
    service.deliveryChecks = [(result: DeliveryCheck.noCode, attemptsLeft: 5)];
    await pump(tester);
    await enterPin(tester, '1234');

    await release(tester);

    expect(status(tester), contains("now in their app"));
  });

  testWidgets('starts on the default payout account; another can be picked', (
    tester,
  ) async {
    await pump(tester);

    Icon radio(String id) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(ValueKey('delivery-confirm-account-$id')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.radio_button_checked_rounded ||
                  w.icon == Icons.radio_button_off_rounded),
        ),
      ),
    );
    expect(radio('barclays').icon, Icons.radio_button_checked_rounded);

    await tester.tap(
      find.byKey(const ValueKey('delivery-confirm-account-mpesa')),
    );
    await tester.pump();

    expect(radio('mpesa').icon, Icons.radio_button_checked_rounded);
    expect(radio('barclays').icon, Icons.radio_button_off_rounded);
  });

  testWidgets('without a payout account it says where to add one', (
    tester,
  ) async {
    payments = FakePaymentService();
    await pump(tester);

    expect(
      find.byKey(const ValueKey('delivery-confirm-no-account')),
      findsOneWidget,
    );
    await enterPin(tester, '7492');
    expect(releaseEnabled(tester), isTrue);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));

    expect(find.text('Livraison et versement'), findsOneWidget);
  });
}
