import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/wallet_history_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:carrywise_app/widgets/wallet_added_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// "$45.00 added to your wallet" on Home once a traveler is paid, until they
/// open the wallet from it or close it.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime.now();

  WalletEntry payout({
    String id = 'p1',
    double amount = 45,
    String currency = 'USD',
    Duration ago = const Duration(hours: 2),
    WalletEntryKind kind = WalletEntryKind.payout,
    String? name = 'Sarah',
  }) => WalletEntry(
    kind: kind,
    id: id,
    amount: amount,
    currency: currency,
    status: WalletEntryStatus.pending,
    date: now.subtract(ago),
    item: 'iPad Mini',
    fromCity: 'Lagos',
    toCity: 'London',
    otherName: name,
  );

  Future<FakePaymentService> pumpHome(
    WidgetTester tester,
    List<WalletEntry> history, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final payments = FakePaymentService()..history = history;
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(
            profile: const {
              'id': 'me',
              'first_name': 'Fortune',
              'last_name': 'Niama',
              'verification_status': 'verified',
            },
          ),
          travelerService: FakeTravelerService(),
          notificationService: FakeNotificationService(),
          paymentService: payments,
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return payments;
  }

  Finder card() => find.byKey(const ValueKey('wallet-added'));
  String cardText(WidgetTester tester) => tester
      .widgetList<RichText>(
        find.descendant(of: card(), matching: find.byType(RichText)),
      )
      .map((t) => t.text.toPlainText())
      .join(' | ');

  testWidgets('a new payout shows the card with what it was for', (
    tester,
  ) async {
    await pumpHome(tester, [payout()]);

    expect(card(), findsOneWidget);
    final text = cardText(tester);
    expect(text, contains(r'$45.00 added to your wallet'));
    expect(
      text,
      contains('For carrying iPad Mini from Lagos to London for Sarah.'),
    );
  });

  testWidgets('no payouts, payments only, or old payouts: no card', (
    tester,
  ) async {
    await pumpHome(tester, [
      payout(kind: WalletEntryKind.payment),
      payout(id: 'old', ago: const Duration(days: 9)),
    ]);

    expect(card(), findsNothing);
  });

  testWidgets('several payouts add up', (tester) async {
    await pumpHome(tester, [
      payout(),
      payout(id: 'p2', amount: 30, ago: const Duration(days: 1)),
    ]);

    final text = cardText(tester);
    expect(text, contains(r'$75.00 added to your wallet'));
    expect(text, contains('From 2 deliveries.'));
  });

  testWidgets('a payout in naira shows in naira', (tester) async {
    await pumpHome(tester, [payout(amount: 60000, currency: 'NGN')]);

    expect(cardText(tester), contains('NGN 60,000 added to your wallet'));
  });

  testWidgets('View opens the wallet history and the card is gone', (
    tester,
  ) async {
    await pumpHome(tester, [payout()]);

    await tester.tap(find.byKey(const ValueKey('wallet-added-view')));
    await tester.pumpAndSettle();
    expect(find.byType(WalletHistoryScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(WalletHistoryScreen))).pop();
    await tester.pumpAndSettle();
    expect(card(), findsNothing);
  });

  testWidgets('closing it hides it until the next payout', (tester) async {
    await pumpHome(tester, [payout()]);

    await tester.tap(find.byKey(const ValueKey('wallet-added-dismiss')));
    await tester.pumpAndSettle();
    expect(card(), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WalletAddedCard.seenKey('me')), isNotNull);

    // Seen: not shown again.
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester, [payout()]);
    expect(card(), findsNothing);

    // A newer payout brings it back, with only the new one.
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester, [
      payout(id: 'p2', amount: 20, ago: const Duration(minutes: 5)),
      payout(),
    ]);
    expect(cardText(tester), contains(r'$20.00 added to your wallet'));
  });

  testWidgets('in French', (tester) async {
    await pumpHome(tester, [payout()], locale: const Locale('fr'));

    expect(
      cardText(tester),
      contains('Pour avoir transporté iPad Mini de Lagos à London pour Sarah.'),
    );
  });
}
