import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/services/app_badge.dart';
import 'package:carrywise_app/services/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The number on the app icon follows the unread notifications.
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
}
