import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The bottom nav must sit at the bottom of the screen, not right under the
/// content, when the content is shorter than the screen.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Much taller than any of these screens' content.
  const screen = Size(900, 2400);

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWrapper(page));
    await tester.pumpAndSettle();
  }

  double navBottom(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(AppBottomNav)).dy;

  testWidgets('Home with no travelers: nav at the bottom', (tester) async {
    await pump(
      tester,
      HomeScreen(
        authService: FakeAuthService(),
        travelerService: FakeTravelerService(trips: []),
        capitalLookup: fakeCapitalLookup,
      ),
    );

    expect(find.text('No travelers on this route yet.'), findsOneWidget);
    expect(navBottom(tester), screen.height);
  });

  testWidgets('Profile: nav at the bottom', (tester) async {
    await pump(tester, ProfileScreen(authService: FakeAuthService()));

    expect(navBottom(tester), screen.height);
  });
}
