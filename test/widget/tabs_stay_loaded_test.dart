import 'package:carrywise_app/screens/messages_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/screens/trips_screen.dart';
import 'package:carrywise_app/services/screen_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Switching tabs builds a tab's page again: it shows what it had straight
/// away (no spinner) and refreshes quietly behind it.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Finder spinner() => find.byType(CircularProgressIndicator);

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWrapper(page));
  }

  /// Leaves the page (another tab), as switching tabs does.
  Future<void> leave(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  group('Requests', () {
    late FakeRequestService service;
    setUp(() {
      service = FakeRequestService()
        ..mine = [sampleSentRequest(id: 'req-1')]
        ..incoming = [sampleIncoming(id: 'in-1')];
    });

    Widget page() => RequestsScreen(
      requestService: service,
      exchangeRates: FakeExchangeRateService(),
      initialTab: 1,
    );

    testWidgets('a first visit loads; the next one shows it at once', (
      tester,
    ) async {
      await show(tester, page());
      expect(spinner(), findsWidgets); // first visit: loading
      await tester.pumpAndSettle();
      await leave(tester);

      await show(tester, page());
      // The very first frame already has the requests.
      expect(spinner(), findsNothing);
      expect(find.text('Tap to edit'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(service.listCalls, 2); // and it still refreshed
    });

    testWidgets('a failed refresh keeps what is on screen', (tester) async {
      await show(tester, page());
      await tester.pumpAndSettle();
      await leave(tester);

      service.failList = true;
      await show(tester, page());
      await tester.pumpAndSettle();
      expect(find.text('Tap to edit'), findsOneWidget);
      expect(find.byKey(const ValueKey('outgoing-error')), findsNothing);
    });

    testWidgets('new requests show after the quiet refresh', (tester) async {
      await show(tester, page());
      await tester.pumpAndSettle();
      await leave(tester);

      service.mine = [
        sampleSentRequest(id: 'req-1'),
        sampleSentRequest(id: 'req-2'),
      ];
      await show(tester, page());
      expect(find.text('Tap to edit'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Tap to edit'), findsNWidgets(2));
    });

    testWidgets('preloading from Home makes even a first visit ready', (
      tester,
    ) async {
      await RequestsScreen.preload(service, FakeExchangeRateService());
      await show(tester, page());
      expect(spinner(), findsNothing);
      expect(find.text('Tap to edit'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('Trips', () {
    testWidgets('the next visit shows the trips at once', (tester) async {
      final service = FakeTripService(trips: [sampleMyTrip()]);
      await show(tester, TripsScreen(service: service));
      expect(spinner(), findsWidgets);
      await tester.pumpAndSettle();
      await leave(tester);

      service.failLoad = true; // and a failed refresh keeps them
      await show(tester, TripsScreen(service: service));
      expect(spinner(), findsNothing);
      await tester.pumpAndSettle();
      expect(service.loadCount, 2);
      expect(find.textContaining('Retry'), findsNothing);
    });
  });

  group('Messages', () {
    testWidgets('the next visit shows the conversations at once', (
      tester,
    ) async {
      final service = FakeMessageService(conversations: [sampleConversation()]);
      Widget page() => MessagesScreen(service: service);
      await show(tester, page());
      expect(spinner(), findsWidgets);
      await tester.pumpAndSettle();
      final shown = tester.widgetList(find.byType(Text)).length;
      await leave(tester);

      await show(tester, page());
      expect(spinner(), findsNothing);
      expect(tester.widgetList(find.byType(Text)).length, shown);
      await tester.pumpAndSettle();
      expect(service.conversationCalls, 2);
    });
  });

  group('ScreenCache', () {
    test('keeps values for the signed-in user only', () {
      ScreenCache.userId = () => 'amara';
      ScreenCache.write('k', 1);
      expect(ScreenCache.read<int>('k'), 1);

      ScreenCache.userId = () => 'daniel'; // someone else signs in
      expect(ScreenCache.read<int>('k'), isNull);

      ScreenCache.userId = () => null; // signed out
      ScreenCache.write('k', 2);
      expect(ScreenCache.read<int>('k'), isNull);
    });

    test('signing out clears it', () {
      ScreenCache.write('k', 1);
      ScreenCache.clear();
      expect(ScreenCache.read<int>('k'), isNull);
    });

    test('a value of another type is not returned', () {
      ScreenCache.write('k', 'text');
      expect(ScreenCache.read<int>('k'), isNull);
    });
  });
}
