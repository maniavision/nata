import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

final now = DateTime(2030, 6, 15, 12, 0);

List<AppNotification> mixed() => [
  sampleNotification(
    id: 'n-req',
    type: 'request',
    title: 'Request accepted',
    body: 'Amara K. accepted your delivery request for Lagos → London.',
    createdAt: now.subtract(const Duration(minutes: 2)),
  ),
  sampleNotification(
    id: 'n-msg',
    type: 'message',
    title: 'New message',
    body: 'Daniel O.: Happy to carry the package to Paris on Jun 24.',
    createdAt: now.subtract(const Duration(minutes: 18)),
  ),
  sampleNotification(
    id: 'n-pay',
    type: 'payment',
    title: 'Payment held in escrow',
    body: r'$85.00 is held securely until delivery is confirmed.',
    createdAt: now.subtract(const Duration(hours: 1)),
  ),
  sampleNotification(
    id: 'n-trip',
    type: 'trip',
    title: 'Trip published',
    body: 'Your Lagos → London trip is now visible to senders.',
    isRead: true,
    createdAt: DateTime(2030, 6, 14, 10, 0),
  ),
  sampleNotification(
    id: 'n-ver',
    type: 'verification',
    title: 'Identity verified',
    body: 'Your identity has been verified.',
    isRead: true,
    createdAt: DateTime(2030, 6, 3, 9, 0),
  ),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeNotificationService service;

  setUp(() => service = FakeNotificationService(items: mixed()));

  Future<void> pump(
    WidgetTester tester, {
    bool settle = true,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        NotificationsScreen(service: service, now: () => now),
        locale: locale,
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  int unreadDots() => find
      .byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value.toString().startsWith('notif-unread-'),
      )
      .evaluate()
      .length;

  group('header and filters', () {
    testWidgets('shows the title, Mark all read and the four filters', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      for (final f in ['All', 'Requests', 'Trips', 'Payments']) {
        expect(find.text(f), findsWidgets);
      }
    });

    testWidgets('the back button leaves the page', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(service: service, now: () => now),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);

      await tapKey(tester, 'notif-back');

      expect(find.byType(NotificationsScreen), findsNothing);
    });

    testWidgets('shows the same bottom navigation, with no tab highlighted', (
      tester,
    ) async {
      await pump(tester);

      for (final label in [
        'Home',
        'Requests',
        'Trips',
        'Messages',
        'Profile',
      ]) {
        final text = tester.widget<Text>(find.text(label).last);
        expect(
          text.style?.fontWeight,
          FontWeight.w500,
          reason: '$label should not look selected',
        );
      }
    });
  });

  group('loading, empty and error states', () {
    testWidgets('shows a spinner first', (tester) async {
      await pump(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty state when there is nothing yet', (tester) async {
      service.items = [];
      await pump(tester);

      expect(find.byKey(const ValueKey('notif-empty')), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.textContaining("We'll let you know"), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('error state with a working Retry', (tester) async {
      service.failList = true;
      await pump(tester);

      expect(find.byKey(const ValueKey('notif-error')), findsOneWidget);
      expect(find.text('Could not load your notifications.'), findsOneWidget);

      service.failList = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notif-error')), findsNothing);
      expect(find.text('Request accepted'), findsOneWidget);
      expect(service.listCalls, 2);
    });

    testWidgets('pull to refresh loads again', (tester) async {
      await pump(tester);
      // The pull distance needed depends on the screen height, so use a
      // normal phone-sized screen here rather than the tall test surface.
      tester.view.physicalSize = const Size(402, 800);
      await tester.pumpAndSettle();
      expect(service.listCalls, 1);

      service.items = [sampleNotification(id: 'fresh', title: 'Brand new')];
      await tester.drag(
        find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(ListView),
        ),
        const Offset(0, 400),
      );
      await tester.pump(); // start the refresh
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(service.listCalls, 2);
      expect(find.text('Brand new'), findsOneWidget);
    });
  });

  group('pull to refresh', () {
    Future<void> pullDown(WidgetTester tester) async {
      await tester.drag(
        find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(ListView),
        ),
        const Offset(0, 400),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('works even when the list is much shorter than the screen', (
      tester,
    ) async {
      service.items = [mixed().first]; // a single card: nothing to scroll
      await pump(tester);
      tester.view.physicalSize = const Size(402, 800);
      await tester.pumpAndSettle();
      expect(service.listCalls, 1);

      await pullDown(tester);

      expect(service.listCalls, 2);
    });

    testWidgets('works on the empty state too', (tester) async {
      service.items = [];
      await pump(tester);
      tester.view.physicalSize = const Size(402, 800);
      await tester.pumpAndSettle();

      service.items = [sampleNotification(id: 'late', title: 'Arrived later')];
      await pullDown(tester);

      expect(find.text('Arrived later'), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('groups notifications into Today and Earlier', (tester) async {
      await pump(tester);

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('TODAY'), lessThan(top('Request accepted')));
      expect(top('Payment held in escrow'), lessThan(top('EARLIER')));
      expect(top('EARLIER'), lessThan(top('Trip published')));
    });

    testWidgets('keeps the order it was given', (tester) async {
      await pump(tester);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Request accepted'), lessThan(top('New message')));
      expect(top('New message'), lessThan(top('Payment held in escrow')));
      expect(top('Trip published'), lessThan(top('Identity verified')));
    });

    testWidgets('only shows a section that has items', (tester) async {
      service.items = [mixed().first];
      await pump(tester);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsNothing);

      service.items = [mixed().last];
      await pump(tester);
      await tester.pumpAndSettle();
    });

    testWidgets('only earlier items: no Today heading', (tester) async {
      service.items = [mixed().last];
      await pump(tester);

      expect(find.text('TODAY'), findsNothing);
      expect(find.text('EARLIER'), findsOneWidget);
    });

    testWidgets('each card shows title, message and a readable time', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Request accepted'), findsOneWidget);
      expect(
        find.text(
          'Amara K. accepted your delivery request for Lagos → London.',
        ),
        findsOneWidget,
      );
      expect(find.text('2 min ago'), findsOneWidget);
      expect(find.text('18 min ago'), findsOneWidget);
      expect(find.text('1 hr ago'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Jun 3'), findsOneWidget);
    });

    testWidgets('a notification without a message shows just the title', (
      tester,
    ) async {
      service.items = [
        sampleNotification(id: 'x', title: 'Only a title', body: ''),
      ];
      await pump(tester);

      expect(find.text('Only a title'), findsOneWidget);
    });

    testWidgets('unread notifications have a dot, read ones do not', (
      tester,
    ) async {
      await pump(tester);

      expect(unreadDots(), 3);
      expect(find.byKey(const ValueKey('notif-unread-n-req')), findsOneWidget);
      expect(find.byKey(const ValueKey('notif-unread-n-trip')), findsNothing);
      expect(find.byKey(const ValueKey('notif-unread-n-ver')), findsNothing);
    });

    testWidgets('each type has its own icon', (tester) async {
      await pump(tester);

      expect(
        find.byIcon(Icons.check_circle_rounded),
        findsOneWidget,
      ); // request
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget); // message
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
      expect(find.byIcon(Icons.luggage_rounded), findsOneWidget); // trip
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
    });

    testWidgets('an unknown type still shows a generic icon', (tester) async {
      service.items = [sampleNotification(id: 'x', type: 'something-new')];
      await pump(tester);

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    });
  });

  group('marking as read', () {
    testWidgets('tapping a notification marks it read', (tester) async {
      await pump(tester);

      await tapKey(tester, 'notif-n-req');

      expect(find.byKey(const ValueKey('notif-unread-n-req')), findsNothing);
      expect(unreadDots(), 2);
      expect(service.markedRead, ['n-req']);
    });

    testWidgets('tapping one that is already read does nothing', (
      tester,
    ) async {
      await pump(tester);

      await tapKey(tester, 'notif-n-trip');

      expect(service.markedRead, isEmpty);
    });

    testWidgets('a failed save brings the dot back', (tester) async {
      service.failMarkRead = true;
      await pump(tester);

      await tapKey(tester, 'notif-n-req');

      expect(find.byKey(const ValueKey('notif-unread-n-req')), findsOneWidget);
      expect(unreadDots(), 3);
    });

    testWidgets('Mark all read clears every dot', (tester) async {
      await pump(tester);

      await tapKey(tester, 'notif-mark-all');

      expect(unreadDots(), 0);
      expect(service.markAllCalls, 1);
    });

    testWidgets('Mark all read is dimmed and inert once all are read', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'notif-mark-all');

      await tapKey(tester, 'notif-mark-all');

      expect(service.markAllCalls, 1); // not called again
    });

    testWidgets('Mark all read does nothing when there is nothing unread', (
      tester,
    ) async {
      service.items = [for (final n in mixed()) n.copyWith(isRead: true)];
      await pump(tester);

      await tapKey(tester, 'notif-mark-all');

      expect(service.markAllCalls, 0);
    });

    testWidgets('a failed Mark all read puts the dots back', (tester) async {
      service.failMarkAll = true;
      await pump(tester);

      await tapKey(tester, 'notif-mark-all');

      expect(unreadDots(), 3);
    });

    testWidgets('read state survives switching filters', (tester) async {
      await pump(tester);
      await tapKey(tester, 'notif-n-req');

      await tapKey(tester, 'notif-filter-2'); // Trips
      await tapKey(tester, 'notif-filter-0'); // All

      expect(find.byKey(const ValueKey('notif-unread-n-req')), findsNothing);
    });
  });

  group('filters', () {
    testWidgets('Requests shows only request notifications', (tester) async {
      await pump(tester);

      await tapKey(tester, 'notif-filter-1');

      expect(find.text('Request accepted'), findsOneWidget);
      expect(find.text('New message'), findsNothing);
      expect(find.text('Payment held in escrow'), findsNothing);
      expect(find.text('Trip published'), findsNothing);
    });

    testWidgets('Trips shows only trip notifications', (tester) async {
      await pump(tester);

      await tapKey(tester, 'notif-filter-2');

      expect(find.text('Trip published'), findsOneWidget);
      expect(find.text('Request accepted'), findsNothing);
    });

    testWidgets('Payments shows only payment notifications', (tester) async {
      await pump(tester);

      await tapKey(tester, 'notif-filter-3');

      expect(find.text('Payment held in escrow'), findsOneWidget);
      expect(find.text('Trip published'), findsNothing);
    });

    testWidgets('messages and verification only appear under All', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Identity verified'), findsOneWidget);

      for (final i in [1, 2, 3]) {
        await tapKey(tester, 'notif-filter-$i');
        expect(find.text('New message'), findsNothing);
        expect(find.text('Identity verified'), findsNothing);
      }
    });

    testWidgets('All shows everything again', (tester) async {
      await pump(tester);
      await tapKey(tester, 'notif-filter-1');

      await tapKey(tester, 'notif-filter-0');

      expect(find.text('Request accepted'), findsOneWidget);
      expect(find.text('Identity verified'), findsOneWidget);
    });

    testWidgets('a filter with no matches shows the empty state', (
      tester,
    ) async {
      service.items = [sampleNotification(id: 'x', type: 'system')];
      await pump(tester);

      await tapKey(tester, 'notif-filter-1');

      expect(find.byKey(const ValueKey('notif-empty')), findsOneWidget);
    });

    testWidgets('sections follow the filter', (tester) async {
      await pump(tester);

      await tapKey(tester, 'notif-filter-2'); // only a trip, from "earlier"

      expect(find.text('TODAY'), findsNothing);
      expect(find.text('EARLIER'), findsOneWidget);
    });

    testWidgets('the selected filter is highlighted', (tester) async {
      await pump(tester);

      Color? chipColor(int i) =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: find.byKey(ValueKey('notif-filter-$i')),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;

      final allActive = chipColor(0);
      expect(chipColor(1), isNot(allActive));

      await tapKey(tester, 'notif-filter-1');

      expect(chipColor(1), allActive);
      expect(chipColor(0), isNot(allActive));
    });
  });

  group('translations', () {
    testWidgets('Spanish', (tester) async {
      await pump(tester, locale: const Locale('es'));

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Marcar todo como leído'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('ANTERIORES'), findsOneWidget);
      expect(find.text('hace 2 min'), findsOneWidget);
      expect(find.text('Ayer'), findsOneWidget);
    });

    testWidgets('French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Tout marquer comme lu'), findsOneWidget);
      expect(find.text("AUJOURD'HUI"), findsOneWidget);
      expect(find.text('PLUS TÔT'), findsOneWidget);
      expect(find.text('il y a 2 min'), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
    });

    testWidgets('the empty state is translated', (tester) async {
      service.items = [];
      await pump(tester, locale: const Locale('es'));

      expect(find.text('Aún no hay notificaciones'), findsOneWidget);
    });
  });

  group('opening it from Home', () {
    testWidgets('the bell opens the notifications page', (tester) async {
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
      expect(find.byType(NotificationsScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('home-notifications')));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(service.listCalls, 1);
    });

    testWidgets('back from the page returns to Home', (tester) async {
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
      await tester.tap(find.byKey(const ValueKey('home-notifications')));
      await tester.pumpAndSettle();

      await tapKey(tester, 'notif-back');

      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.text('Where are you sending?'), findsOneWidget);
    });
  });

  group('a traveler on a saved route', () {
    final alert = AppNotification(
      id: 't1',
      type: 'trip',
      title: 'Stored',
      body: 'Stored',
      imageUrl: null,
      isRead: false,
      createdAt: now,
      payload: const {
        'event': 'trip_match',
        'traveler': 'Daniel',
        'route': 'Lagos → London',
        'from_city_id': 10,
        'from_city': 'Lagos',
        'to_city_id': 20,
        'to_city': 'London',
      },
    );

    testWidgets('says who and where', (tester) async {
      service = FakeNotificationService(items: [alert]);
      await pump(tester);
      expect(find.text('A traveler is going your way'), findsOneWidget);
      expect(
        find.text('Daniel is flying Lagos → London. Send your item with them.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping it opens the search for that route', (tester) async {
      service = FakeNotificationService(items: [alert]);
      Map<String, dynamic>? opened;
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          NotificationsScreen(
            service: service,
            now: () => now,
            routeResultsBuilder: (p) {
              opened = p;
              return const Scaffold(body: Text('RESULTS'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A traveler is going your way'));
      await tester.pumpAndSettle();
      expect(opened?['to_city'], 'London');
      expect(find.text('RESULTS'), findsOneWidget);
    });
  });

  group('a new message', () {
    AppNotification message(Map<String, dynamic> details) => AppNotification(
      id: 'm1',
      type: 'message',
      title: 'Stored',
      body: 'Stored',
      imageUrl: null,
      isRead: false,
      createdAt: now,
      payload: {
        'event': 'message_new',
        'conversation_id': 'conv-9',
        ...details,
      },
    );

    testWidgets('shows who wrote and what', (tester) async {
      service = FakeNotificationService(
        items: [
          message({'author': 'Amara', 'message': 'Just landed!'}),
        ],
      );
      await pump(tester);
      expect(find.text('New message from Amara'), findsOneWidget);
      expect(find.text('Just landed!'), findsOneWidget);
    });

    testWidgets('a photo says so', (tester) async {
      service = FakeNotificationService(
        items: [
          message({'author': 'Amara', 'message': '', 'photo': true}),
        ],
      );
      await pump(tester, locale: const Locale('fr'));
      expect(find.text('Nouveau message de Amara'), findsOneWidget);
      expect(find.text('Vous a envoyé une photo'), findsOneWidget);
    });

    testWidgets('tapping it opens the chat', (tester) async {
      service = FakeNotificationService(
        items: [
          message({'author': 'Amara', 'message': 'Hi'}),
        ],
      );
      String? opened;
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          NotificationsScreen(
            service: service,
            now: () => now,
            chatBuilder: (id) {
              opened = id;
              return const Scaffold(body: Text('CHAT'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hi'));
      await tester.pumpAndSettle();
      expect(opened, 'conv-9');
      expect(find.text('CHAT'), findsOneWidget);
    });
  });

  group('written from the event, in the user\'s language', () {
    AppNotification event(String name, Map<String, dynamic> details) =>
        AppNotification(
          id: 'n-$name',
          type: 'request',
          title: 'Stored English title',
          body: 'Stored English body',
          imageUrl: null,
          isRead: false,
          createdAt: now,
          payload: {'event': name, ...details},
        );

    testWidgets('English', (tester) async {
      service = FakeNotificationService(
        items: [
          event('request_accepted', {'traveler': 'Amara'}),
          event('payout_paid', {'amount': 45, 'currency': 'GBP'}),
        ],
      );
      await pump(tester);

      expect(find.text('Request accepted'), findsOneWidget);
      expect(
        find.text(
          'Amara accepted your request. Pay within 24 hours to confirm it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your payout of £45 is on its way.'), findsOneWidget);
      expect(find.text('Stored English body'), findsNothing);
    });

    testWidgets('French', (tester) async {
      service = FakeNotificationService(
        items: [
          event('request_new', {'sender': 'Kofi', 'route': 'Accra → Paris'}),
        ],
      );
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Nouvelle demande de livraison'), findsOneWidget);
      expect(
        find.text(
          'Kofi souhaite que vous transportiez un objet sur Accra → Paris.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unknown event keeps its stored text', (tester) async {
      service = FakeNotificationService(items: [event('something_new', {})]);
      await pump(tester);

      expect(find.text('Stored English title'), findsOneWidget);
      expect(find.text('Stored English body'), findsOneWidget);
    });
  });

  group('opening a notification', () {
    AppNotification about(String event, {String id = 'n-x'}) => AppNotification(
      id: id,
      type: 'request',
      title: 't',
      body: 'b',
      imageUrl: null,
      isRead: false,
      createdAt: now,
      payload: {'event': event, 'traveler': 'Amara', 'sender': 'Kofi'},
    );

    Future<void> pumpOpen(WidgetTester tester, AppNotification n) async {
      service = FakeNotificationService(items: [n]);
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          NotificationsScreen(
            service: service,
            now: () => now,
            requestsBuilder: (tab) => Scaffold(body: Text('REQUESTS-TAB-$tab')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('notif-${n.id}')));
      await tester.pumpAndSettle();
    }

    testWidgets('accepted (sender): Outgoing', (tester) async {
      await pumpOpen(tester, about('request_accepted'));
      expect(find.text('REQUESTS-TAB-1'), findsOneWidget);
    });

    testWidgets('new request (traveler): Incoming', (tester) async {
      await pumpOpen(tester, about('request_new'));
      expect(find.text('REQUESTS-TAB-0'), findsOneWidget);
    });

    testWidgets('not about a request: stays here', (tester) async {
      await pumpOpen(tester, about('identity_verified'));
      expect(find.textContaining('REQUESTS-TAB'), findsNothing);
    });
  });
  group('deleting', () {
    Future<void> swipeLeft(WidgetTester tester, String id) async {
      await tester.drag(
        find.byKey(ValueKey('notif-$id')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('swiping a card left deletes it', (tester) async {
      await pump(tester);

      await swipeLeft(tester, 'n-req');

      expect(find.byKey(const ValueKey('notif-n-req')), findsNothing);
      expect(service.deleted, ['n-req']);
      expect(find.byKey(const ValueKey('notif-n-trip')), findsOneWidget);
    });

    testWidgets('swiping right does nothing', (tester) async {
      await pump(tester);

      await tester.drag(
        find.byKey(const ValueKey('notif-n-req')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notif-n-req')), findsOneWidget);
      expect(service.deleted, isEmpty);
    });

    testWidgets('a failed delete brings the card back and says so', (
      tester,
    ) async {
      service.failDelete = true;
      await pump(tester);

      await swipeLeft(tester, 'n-req');

      expect(find.byKey(const ValueKey('notif-n-req')), findsOneWidget);
      expect(
        find.text('Could not delete the notification. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
