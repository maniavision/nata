import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/services/app_badge.dart';
import 'package:carrywise_app/services/auth_gate.dart';
import 'package:carrywise_app/services/unread_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The number on the app icon, and on Home's bell, follows the unread
/// notifications.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeNotificationService service;
  late List<int> shown;
  final now = DateTime(2030, 6, 15, 12);

  setUp(() {
    service = FakeNotificationService(
      items: [
        sampleNotification(id: 'a', title: 'First'),
        sampleNotification(id: 'b', title: 'Second'),
        sampleNotification(id: 'c', title: 'Third', isRead: true),
      ],
    );
    shown = [];
    AuthGate.isSignedIn = () => true;
    AppBadge.loadUnread = service.unreadCount;
    AppBadge.show = (n) async => shown.add(n);
  });
  tearDown(() => AuthGate.isSignedIn = () => false);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(NotificationsScreen(service: service, now: () => now)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opening notifications shows the unread count', (tester) async {
    await open(tester);
    expect(shown.last, 2);
  });

  testWidgets('reading one takes the badge down by one', (tester) async {
    await open(tester);
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(shown.last, 1);
  });

  testWidgets('"Mark all read" clears it', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('notif-mark-all')));
    await tester.pumpAndSettle();
    expect(shown.last, 0);
  });

  test('a new unread notification raises it', () async {
    await AppBadge.refresh();
    expect(shown.last, 2);
    service.items = [
      sampleNotification(id: 'd', title: 'New'),
      ...service.items,
    ];
    await AppBadge.refresh();
    expect(shown.last, 3);
  });

  test('signed out: no badge', () async {
    AuthGate.isSignedIn = () => false;
    await AppBadge.refresh();
    expect(shown.last, 0);
  });

  test('a failure to count never breaks anything', () async {
    AppBadge.loadUnread = () async => throw Exception('offline');
    await AppBadge.refresh();
    expect(shown, isEmpty);
  });

  group("Home's bell", () {
    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
            notificationService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder badge() => find.byKey(const ValueKey('home-notifications-unread'));

    testWidgets('shows how many are unread', (tester) async {
      await openHome(tester);
      expect(badge(), findsOneWidget);
      expect(
        find.descendant(of: badge(), matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('nothing unread: no badge', (tester) async {
      service.items = [sampleNotification(id: 'a', isRead: true)];
      await openHome(tester);
      expect(badge(), findsNothing);
    });

    testWidgets('more than 9 shows 9+', (tester) async {
      service.items = [
        for (var i = 0; i < 12; i++) sampleNotification(id: 'n$i'),
      ];
      await openHome(tester);
      expect(
        find.descendant(of: badge(), matching: find.text('9+')),
        findsOneWidget,
      );
    });

    testWidgets('reading them all clears it back on Home', (tester) async {
      await openHome(tester);
      await tester.tap(find.byKey(const ValueKey('home-notifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notif-mark-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notif-back')));
      await tester.pumpAndSettle();

      expect(badge(), findsNothing);
    });

    testWidgets('a push while the app is open raises it', (tester) async {
      await openHome(tester);
      service.items = [sampleNotification(id: 'new'), ...service.items];
      await AppBadge.refresh(); // what a push that arrives does
      await tester.pump();
      expect(
        find.descendant(of: badge(), matching: find.text('3')),
        findsOneWidget,
      );
    });
  });

  group('Messages tab', () {
    Finder tabBadge() => find.byKey(const ValueKey('nav-messages-unread'));

    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
            notificationService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows how many messages are unread', (tester) async {
      UnreadMessages.loadConversations = () async => [
        sampleConversation(id: 'a', unread: 2),
        sampleConversation(id: 'b', unread: 1),
        sampleConversation(id: 'c'),
      ];
      await openHome(tester);
      expect(
        find.descendant(of: tabBadge(), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('nothing unread: no badge', (tester) async {
      UnreadMessages.loadConversations = () async => [
        sampleConversation(id: 'a'),
      ];
      await openHome(tester);
      expect(tabBadge(), findsNothing);
    });

    testWidgets('more than 9 shows 9+', (tester) async {
      UnreadMessages.loadConversations = () async => [
        sampleConversation(id: 'a', unread: 12),
      ];
      await openHome(tester);
      expect(
        find.descendant(of: tabBadge(), matching: find.text('9+')),
        findsOneWidget,
      );
    });

    testWidgets('a new message (push) raises it; reading clears it', (
      tester,
    ) async {
      var unread = 1;
      UnreadMessages.loadConversations = () async => [
        sampleConversation(id: 'a', unread: unread),
      ];
      await openHome(tester);
      expect(
        find.descendant(of: tabBadge(), matching: find.text('1')),
        findsOneWidget,
      );

      unread = 2;
      await AppBadge.refresh(); // what a push that arrives does
      await tester.pump();
      expect(
        find.descendant(of: tabBadge(), matching: find.text('2')),
        findsOneWidget,
      );

      unread = 0;
      await AppBadge.refresh(); // what reading a chat does
      await tester.pump();
      expect(tabBadge(), findsNothing);
    });

    test('signed out: nothing unread', () async {
      UnreadMessages.count.value = 4;
      AuthGate.isSignedIn = () => false;
      await UnreadMessages.refresh();
      expect(UnreadMessages.count.value, 0);
    });

    test('signing out clears it', () async {
      UnreadMessages.count.value = 4;
      await AppBadge.clear();
      expect(UnreadMessages.count.value, 0);
    });
  });
}
