import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/screens/trips_screen.dart';
import 'package:carrywise_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Switching tabs with the bottom bar shows the tab straight away, without
/// the sliding page animation.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(),
          travelerService: FakeTravelerService(trips: []),
          capitalLookup: fakeCapitalLookup,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav).last,
        matching: find.text(label),
      ),
    );
    // One frame only: no time passes for an animation.
    await tester.pump();
  }

  /// The route showing [finder] has finished appearing.
  bool fullyShown(WidgetTester tester, Finder finder) =>
      ModalRoute.of(tester.element(finder))!.animation!.status ==
      AnimationStatus.completed;

  testWidgets('Home -> Requests appears at once', (tester) async {
    await pumpHome(tester);

    await tapTab(tester, 'Requests');

    expect(find.byType(RequestsScreen), findsOneWidget);
    expect(fullyShown(tester, find.byType(RequestsScreen)), isTrue);
    // Nothing is sliding: the screen sits at the left edge.
    expect(tester.getTopLeft(find.byType(RequestsScreen)).dx, 0);
  });

  testWidgets('Requests -> Trips appears at once', (tester) async {
    await pumpHome(tester);
    await tapTab(tester, 'Requests');
    await tester.pump(const Duration(milliseconds: 50));

    await tapTab(tester, 'Trips');

    expect(find.byType(TripsScreen), findsOneWidget);
    expect(fullyShown(tester, find.byType(TripsScreen)), isTrue);
    expect(find.byType(RequestsScreen), findsNothing);
  });

  test('every tab switch, Home included, uses a route with no animation', () {
    final route =
        AppBottomNav.tabRoute<void>(const SizedBox()) as PageRouteBuilder<void>;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });
}
