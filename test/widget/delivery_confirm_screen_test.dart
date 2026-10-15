import 'dart:typed_data';
import 'package:carrywise_app/screens/delivery_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// A 1x1 transparent PNG.
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakePaymentService payments;
  setUp(
    () => payments = FakePaymentService(
      accounts: [samplePayoutAccount(), sampleMobilePayoutAccount()],
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    Uint8List? photo,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        DeliveryConfirmScreen(
          delivery: sampleDelivery(),
          handoverPhoto: photo,
          paymentService: payments,
          photoPicker: (_) async => _png,
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

  testWidgets('shows every section of the design', (tester) async {
    await pump(tester);

    for (final t in [
      'Delivery & Payout Release',
      'STEP 3 OF 4: CONFIRM DELIVERY',
      'Item Arrived at Destination',
      'OPTION 1: 4-DIGIT DELIVERY PIN',
      'Instant Release',
      'OPTION 2: HANDOFF PHOTO PROOF',
      'Alternative',
      'TRAVELER PAYOUT DESTINATION',
      '+\$38.00 Payout',
      'Barclays Bank (•••• 2093)',
      'M-Pesa (•••• 5678)',
      'Dispute Protection Window',
      '3 Days Active',
      'Report an issue or open a dispute',
      'Confirm & Release Payout (\$38.00)',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('nothing to release before the handoff is confirmed', (
    tester,
  ) async {
    await pump(tester);

    expect(releaseEnabled(tester), isFalse);
  });

  testWidgets("the recipient's PIN confirms the handoff", (tester) async {
    await pump(tester);

    await enterPin(tester, '7492');

    expect(find.text('Valid recipient PIN confirmed'), findsOneWidget);
    expect(releaseEnabled(tester), isTrue);
  });

  testWidgets('a wrong PIN does not', (tester) async {
    await pump(tester);

    await enterPin(tester, '1234');

    expect(
      find.text("This PIN doesn't match the recipient's code."),
      findsOneWidget,
    );
    expect(releaseEnabled(tester), isFalse);
  });

  testWidgets('the handoff photo from the task page is enough', (tester) async {
    await pump(tester, photo: _png);

    expect(find.text('Handover photo attached'), findsOneWidget);
    expect(releaseEnabled(tester), isTrue);
  });

  testWidgets('a photo can be added here too', (tester) async {
    await pump(tester);
    expect(find.text('No handoff photo yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delivery-confirm-photo')));
    await tester.pump();

    expect(find.text('Handover photo attached'), findsOneWidget);
    expect(releaseEnabled(tester), isTrue);
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

  testWidgets('releasing goes on to the next screen', (tester) async {
    await pump(tester);
    await enterPin(tester, '7492');

    await tester.tap(find.byKey(const ValueKey('delivery-confirm-release')));
    await tester.pumpAndSettle();

    expect(find.text('REVIEW'), findsOneWidget);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));

    expect(find.text('Livraison et versement'), findsOneWidget);
  });
}
