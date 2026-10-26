import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The photo, "Hello," and the name at the top of Home open Profile; the
/// wallet balance sits next to the bell and opens Profile too.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsNothing);
  }

  for (final (what, target) in [
    ('the photo', find.byKey(const ValueKey('home-avatar'))),
    ('"Hello,"', find.text('Hello,')),
    ('the name', find.text('Fortune Niama')),
    ('the wallet balance', find.byKey(const ValueKey('home-wallet'))),
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
    await tester.tap(find.text('Fortune Niama'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('Where are you sending?'), findsOneWidget);
  });

  testWidgets('the available balance shows next to the bell', (tester) async {
    await pumpHome(tester);

    final wallet = find.byKey(const ValueKey('home-wallet'));
    expect(
      find.descendant(of: wallet, matching: find.text(r'$320.00')),
      findsOneWidget,
    );
    // Escrow isn't counted.
    expect(find.text(r'$470.00'), findsNothing);
    final bell = find.byKey(const ValueKey('home-notifications'));
    expect(tester.getCenter(wallet).dx, lessThan(tester.getCenter(bell).dx));
  });

  testWidgets('an empty wallet shows \$0.00', (tester) async {
    await pumpHome(
      tester,
      auth: FakeAuthService(balances: const {'available': 0.0, 'escrow': 0.0}),
    );

    expect(find.text(r'$0.00'), findsOneWidget);
  });
}
