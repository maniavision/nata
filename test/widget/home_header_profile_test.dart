import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The photo, "Hello," and the name at the top of Home open Profile.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(),
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
}
