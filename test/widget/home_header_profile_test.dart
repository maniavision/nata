import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The photo, "Hello," and the name at the top of Home open Profile; there
/// is no wallet balance any more (senders pay travelers directly).
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

  testWidgets('no wallet next to the bell', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const ValueKey('home-wallet')), findsNothing);
    expect(find.text(r'$320.00'), findsNothing);
  });
}
