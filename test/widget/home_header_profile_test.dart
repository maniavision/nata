import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The photo, "Hello," and the name at the top of Home open Profile; once
/// there's money, the wallet balance sits next to the bell.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester, {FakeAuthService? auth}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: auth ?? FakeAuthService(),
          travelerService: FakeTravelerService(),
          notificationService: FakeNotificationService(),
          paymentService: FakePaymentService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsNothing);
  }

  for (final (what, target) in [
    ('the photo', find.byKey(const ValueKey('home-avatar'))),
    ('"Hello,"', find.text('Hello,')),
    ('the name', find.text('Fortune')),
  ]) {
    testWidgets('tapping $what opens Profile', (tester) async {
      await pumpHome(tester);

      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  }

  testWidgets('back from Profile returns to Home', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Fortune'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('Where are you sending?'), findsOneWidget);
  });

  Finder wallet() => find.byKey(const ValueKey('home-wallet'));

  testWidgets('the available balance shows next to the bell', (tester) async {
    await pumpHome(tester);

    expect(
      find.descendant(of: wallet(), matching: find.text(r'$320.00')),
      findsOneWidget,
    );
    // Escrow isn't counted.
    expect(find.text(r'$470.00'), findsNothing);
    final bell = find.byKey(const ValueKey('home-notifications'));
    expect(tester.getCenter(wallet()).dx, lessThan(tester.getCenter(bell).dx));
  });

  testWidgets('tapping the balance opens the Wallet page', (tester) async {
    await pumpHome(tester);

    await tester.tap(wallet());
    await tester.pumpAndSettle();

    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('no money, no pill', (tester) async {
    await pumpHome(
      tester,
      auth: FakeAuthService(balances: const {'available': 0.0, 'escrow': 0.0}),
    );

    expect(wallet(), findsNothing);
    expect(find.byKey(const ValueKey('home-wallet-eye')), findsNothing);
  });

  testWidgets('money in escrow alone shows the pill', (tester) async {
    await pumpHome(
      tester,
      auth: FakeAuthService(balances: const {'available': 0.0, 'escrow': 45.0}),
    );

    expect(
      find.descendant(of: wallet(), matching: find.text(r'$0.00')),
      findsOneWidget,
    );
  });

  testWidgets('the eye hides the amount, and it stays hidden', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('home-wallet-eye')));
    await tester.pumpAndSettle();

    expect(find.text(r'$320.00'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
    expect(find.byType(WalletScreen), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('home_balance_hidden'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);
    expect(find.text('••••'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-wallet-eye')));
    await tester.pumpAndSettle();
    expect(find.text(r'$320.00'), findsOneWidget);
  });
}
