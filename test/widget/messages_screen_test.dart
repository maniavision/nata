import 'package:carrywise_app/screens/chat_thread_screen.dart';
import 'package:carrywise_app/screens/messages_screen.dart';
import 'package:carrywise_app/services/message_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

final now = DateTime(2030, 6, 15, 12, 0);

List<ConversationSummary> mixed() => [
  sampleConversation(
    id: 'amara',
    firstName: 'Amara',
    lastName: 'Kalu',
    status: 'accepted',
    lastBody: 'I received your sealed iPhone box!',
    lastAt: now.subtract(const Duration(minutes: 2)),
    unread: 2,
  ),
  sampleConversation(
    id: 'daniel',
    firstName: 'Daniel',
    lastName: 'Okafor',
    from: 'Accra',
    to: 'Paris',
    item: 'Sony headphones',
    status: 'paid',
    lastBody: 'See you at Terminal 2E.',
    lastAt: now.subtract(const Duration(hours: 1)),
  ),
  sampleConversation(
    id: 'maya',
    firstName: 'Maya',
    lastName: 'Tariq',
    from: 'Nairobi',
    to: 'Dubai',
    item: 'Documents',
    status: 'delivered',
    lastBody: 'Handed over. Payout released!',
    lastAt: DateTime(2030, 6, 14, 10),
  ),
  sampleConversation(
    id: 'chidi',
    firstName: 'Chidi',
    lastName: 'Eze',
    from: 'Abuja',
    to: 'Berlin',
    item: 'Laptop sleeve',
    status: 'declined',
    lastBody: null,
  ),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeMessageService service;
  setUp(() => service = FakeMessageService(conversations: mixed()));

  Future<void> pump(
    WidgetTester tester, {
    bool settle = true,
    Locale locale = const Locale('en'),
    Duration refreshEvery = const Duration(seconds: 15),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        MessagesScreen(
          service: service,
          now: () => now,
          refreshEvery: refreshEvery,
        ),
        locale: locale,
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Finder tile(String id) => find.byKey(ValueKey('conversation-$id'));

  group('header', () {
    testWidgets('shows the title, search box and filters', (tester) async {
      await pump(tester);

      expect(find.text('Messages'), findsWidgets);
      expect(find.byKey(const ValueKey('messages-search')), findsOneWidget);
      expect(find.text('Search by name, route or item'), findsOneWidget);
      expect(find.text('All (4)'), findsOneWidget);
    });

    testWidgets('subtitle counts the unread messages', (tester) async {
      await pump(tester);

      expect(find.text('2 unread messages'), findsOneWidget);
    });

    testWidgets('subtitle is singular for one', (tester) async {
      service.convs = [sampleConversation(unread: 1)];
      await pump(tester);

      expect(find.text('1 unread message'), findsOneWidget);
    });

    testWidgets('subtitle adds up unread across conversations', (tester) async {
      service.convs = [
        sampleConversation(id: 'a', unread: 2),
        sampleConversation(id: 'b', unread: 3),
      ];
      await pump(tester);

      expect(find.text('5 unread messages'), findsOneWidget);
    });

    testWidgets('subtitle says all caught up when nothing is unread', (
      tester,
    ) async {
      service.convs = [sampleConversation(unread: 0)];
      await pump(tester);

      expect(find.text('All caught up'), findsOneWidget);
    });

    testWidgets('has no made-up threads', (tester) async {
      service.convs = [];
      await pump(tester);

      expect(find.text('Nata Verification'), findsNothing);
      expect(find.text('Amara K.'), findsNothing);
    });

    testWidgets('shows the same bottom navigation, Messages highlighted', (
      tester,
    ) async {
      await pump(tester);

      for (final label in ['Home', 'Requests', 'Trips', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
      final messagesTab = tester.widgetList<Text>(find.text('Messages')).last;
      expect(messagesTab.style?.fontWeight, FontWeight.w700);
    });
  });

  group('loading, empty and error states', () {
    testWidgets('spinner first', (tester) async {
      await pump(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no conversations at all', (tester) async {
      service.convs = [];
      await pump(tester);

      expect(find.byKey(const ValueKey('messages-empty')), findsOneWidget);
      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.textContaining('delivery request'), findsOneWidget);
    });

    testWidgets('error with a working Retry', (tester) async {
      service.failConversations = true;
      await pump(tester);

      expect(find.byKey(const ValueKey('messages-error')), findsOneWidget);
      expect(find.text('Could not load your messages.'), findsOneWidget);

      service.failConversations = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('messages-error')), findsNothing);
      expect(tile('amara'), findsOneWidget);
    });

    testWidgets('pull to refresh loads again', (tester) async {
      await pump(tester);
      tester.view.physicalSize = const Size(402, 800);
      await tester.pumpAndSettle();
      expect(service.conversationCalls, 1);

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

      expect(service.conversationCalls, 2);
    });
  });

  group('conversation tiles', () {
    testWidgets('one per conversation, in the order given', (tester) async {
      await pump(tester);

      for (final id in ['amara', 'daniel', 'maya', 'chidi']) {
        expect(tile(id), findsOneWidget);
      }
      double top(String id) => tester.getTopLeft(tile(id)).dy;
      expect(top('amara'), lessThan(top('daniel')));
      expect(top('daniel'), lessThan(top('maya')));
    });

    testWidgets('show the other person\'s name, route and item', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Amara K.'), findsOneWidget);
      expect(find.text('Lagos → London'), findsOneWidget);
      expect(find.text('iPhone 15 Pro (sealed)'), findsOneWidget);
    });

    testWidgets('show the last message and a readable time', (tester) async {
      await pump(tester);

      expect(find.text('I received your sealed iPhone box!'), findsOneWidget);
      expect(find.text('2 min ago'), findsOneWidget);
      expect(find.text('1 hr ago'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('a verified person has a badge, others do not', (tester) async {
      service.convs = [
        sampleConversation(id: 'v', verified: true),
        sampleConversation(
          id: 'u',
          verified: false,
          firstName: 'Nia',
          lastName: 'Jones',
        ),
      ];
      await pump(tester);

      expect(
        find.descendant(
          of: tile('v'),
          matching: find.byIcon(Icons.verified_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile('u'),
          matching: find.byIcon(Icons.verified_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('unread conversations show a count badge', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('unread-amara')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('unread-amara')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('unread-daniel')), findsNothing);
    });

    testWidgets('I wrote the last message: it is prefixed with "You:"', (
      tester,
    ) async {
      service.convs = [
        sampleConversation(lastBody: 'On my way', lastAuthor: meId),
      ];
      await pump(tester);

      expect(find.text('You: On my way'), findsOneWidget);
    });

    testWidgets('the other person wrote it: no prefix', (tester) async {
      service.convs = [sampleConversation(lastBody: 'On my way')];
      await pump(tester);

      expect(find.text('On my way'), findsOneWidget);
    });

    testWidgets('a photo-only last message shows "Photo"', (tester) async {
      service.convs = [
        sampleConversation(lastBody: null, lastAttachment: 'c/1.jpg'),
      ];
      await pump(tester);

      expect(find.text('📷 Photo'), findsOneWidget);
    });

    testWidgets('my own photo is prefixed too', (tester) async {
      service.convs = [
        sampleConversation(
          lastBody: null,
          lastAttachment: 'c/1.jpg',
          lastAuthor: meId,
        ),
      ];
      await pump(tester);

      expect(find.text('You: 📷 Photo'), findsOneWidget);
    });

    testWidgets('no messages yet: an invitation to say hello', (tester) async {
      await pump(tester);

      expect(
        find.descendant(
          of: tile('chidi'),
          matching: find.text('No messages yet. Say hello!'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a completed delivery is marked Completed ✓', (tester) async {
      await pump(tester);

      expect(
        find.descendant(of: tile('maya'), matching: find.text('Completed ✓')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile('maya'), matching: find.text('Documents')),
        findsNothing,
      );
    });

    testWidgets('a person with no name still shows something', (tester) async {
      service.convs = [sampleConversation(firstName: '', lastName: '')];
      await pump(tester);

      expect(find.text('—'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets('the chips carry real counts', (tester) async {
      await pump(tester);

      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Active (2)'), findsOneWidget); // accepted + paid
      expect(find.text('Completed (1)'), findsOneWidget); // delivered
    });

    testWidgets('filter labels sit in the middle of their chips', (
      tester,
    ) async {
      await pump(tester);

      for (final (key, label) in [
        ('messages-filter-0', 'All (4)'),
        ('messages-filter-2', 'Completed (1)'),
      ]) {
        final chip = tester.getRect(find.byKey(ValueKey(key)));
        final text = tester.getRect(find.text(label));
        // The label's box is only as tall as its text (not stretched to the
        // chip, which would draw the text at the top), and centered.
        final lines = tester
            .renderObject<RenderParagraph>(find.text(label))
            .textSize
            .height;
        expect(text.height, closeTo(lines, 0.5), reason: label);
        expect(text.center.dy, closeTo(chip.center.dy, 0.5), reason: label);
      }
    });

    testWidgets('Active shows accepted and paid, not delivered or declined', (
      tester,
    ) async {
      await pump(tester);

      await tapKey(tester, 'messages-filter-1');

      expect(tile('amara'), findsOneWidget);
      expect(tile('daniel'), findsOneWidget);
      expect(tile('maya'), findsNothing);
      expect(tile('chidi'), findsNothing);
    });

    testWidgets('Completed shows only delivered ones', (tester) async {
      await pump(tester);

      await tapKey(tester, 'messages-filter-2');

      expect(tile('maya'), findsOneWidget);
      expect(tile('amara'), findsNothing);
    });

    testWidgets('declined ones only appear under All', (tester) async {
      await pump(tester);
      expect(tile('chidi'), findsOneWidget);

      await tapKey(tester, 'messages-filter-1');
      expect(tile('chidi'), findsNothing);
      await tapKey(tester, 'messages-filter-2');
      expect(tile('chidi'), findsNothing);
    });

    testWidgets('All shows everything again', (tester) async {
      await pump(tester);
      await tapKey(tester, 'messages-filter-2');

      await tapKey(tester, 'messages-filter-0');

      expect(tile('amara'), findsOneWidget);
      expect(tile('chidi'), findsOneWidget);
    });

    testWidgets('a filter with nothing in it says so', (tester) async {
      service.convs = [sampleConversation(status: 'accepted')];
      await pump(tester);

      await tapKey(tester, 'messages-filter-2');

      expect(find.byKey(const ValueKey('messages-no-match')), findsOneWidget);
      expect(find.text('No conversations match your search'), findsOneWidget);
    });

    testWidgets('has no Support filter (there are no support threads)', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Support'), findsNothing);
    });
  });

  group('search', () {
    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(
        find.byKey(const ValueKey('messages-search')),
        text,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('by name', (tester) async {
      await pump(tester);

      await search(tester, 'daniel');

      expect(tile('daniel'), findsOneWidget);
      expect(tile('amara'), findsNothing);
    });

    testWidgets('by the other person\'s last name', (tester) async {
      await pump(tester);

      await search(tester, 'okafor');

      expect(tile('daniel'), findsOneWidget);
    });

    testWidgets('by a city on the route', (tester) async {
      await pump(tester);

      await search(tester, 'paris');

      expect(tile('daniel'), findsOneWidget);
      expect(tile('amara'), findsNothing);
    });

    testWidgets('by the item', (tester) async {
      await pump(tester);

      await search(tester, 'headphones');

      expect(tile('daniel'), findsOneWidget);
    });

    testWidgets('by something in the last message', (tester) async {
      await pump(tester);

      await search(tester, 'payout');

      expect(tile('maya'), findsOneWidget);
    });

    testWidgets('ignores capitals and surrounding spaces', (tester) async {
      await pump(tester);

      await search(tester, '  AMARA ');

      expect(tile('amara'), findsOneWidget);
      expect(tile('daniel'), findsNothing);
    });

    testWidgets('no match shows a message, not a blank page', (tester) async {
      await pump(tester);

      await search(tester, 'zzzzzz');

      expect(find.byKey(const ValueKey('messages-no-match')), findsOneWidget);
      expect(find.byKey(const ValueKey('messages-empty')), findsNothing);
    });

    testWidgets('clearing the search brings everything back', (tester) async {
      await pump(tester);
      await search(tester, 'daniel');

      await tapKey(tester, 'messages-search-clear');

      expect(tile('amara'), findsOneWidget);
      expect(tile('daniel'), findsOneWidget);
    });

    testWidgets('works together with a filter', (tester) async {
      await pump(tester);
      await tapKey(tester, 'messages-filter-1'); // active: amara, daniel

      await search(tester, 'maya'); // maya is completed

      expect(find.byKey(const ValueKey('messages-no-match')), findsOneWidget);
    });

    testWidgets('does not change the filter counts', (tester) async {
      await pump(tester);

      await search(tester, 'daniel');

      expect(find.text('All (4)'), findsOneWidget);
    });
  });

  group('opening a chat', () {
    testWidgets('tapping a conversation opens that chat', (tester) async {
      service.thread['daniel'] = [sampleMessage(conversationId: 'daniel')];
      await pump(tester);

      await tester.tap(tile('daniel'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatThreadScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-title')), findsOneWidget);
      expect(find.text('Daniel O.'), findsWidgets);
    });

    testWidgets('the list reloads when coming back', (tester) async {
      await pump(tester);
      expect(service.conversationCalls, 1);
      await tester.tap(tile('amara'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('chat-back')));
      await tester.pumpAndSettle();

      expect(service.conversationCalls, greaterThan(1));
    });

    testWidgets('reading a chat clears its unread badge on return', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('unread-amara')), findsOneWidget);
      await tester.tap(tile('amara'));
      await tester.pumpAndSettle();

      // Meanwhile the server has marked it read.
      service.convs = [
        for (final c in mixed())
          c.id == 'amara' ? sampleConversation(id: 'amara', unread: 0) : c,
      ];
      await tester.tap(find.byKey(const ValueKey('chat-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('unread-amara')), findsNothing);
      expect(find.text('All caught up'), findsOneWidget);
    });
  });

  group('refreshing by itself', () {
    testWidgets('every 15 seconds, quietly', (tester) async {
      await pump(tester);
      expect(service.conversationCalls, 1);

      await tester.pump(const Duration(seconds: 14));
      expect(service.conversationCalls, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(service.conversationCalls, 2);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('new messages appear without leaving the page', (tester) async {
      await pump(tester);
      expect(find.text('All caught up'), findsNothing);

      service.convs = [
        sampleConversation(
          id: 'new',
          firstName: 'Zoe',
          lastName: 'Park',
          unread: 4,
        ),
      ];
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(tile('new'), findsOneWidget);
      expect(find.text('4 unread messages'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the list on screen', (tester) async {
      await pump(tester);
      service.failConversations = true;

      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(find.byKey(const ValueKey('messages-error')), findsNothing);
      expect(tile('amara'), findsOneWidget);
    });

    testWidgets('does not refresh while a chat is open on top', (tester) async {
      await pump(tester);
      await tester.tap(tile('amara'));
      await tester.pumpAndSettle();
      final before = service.conversationCalls;

      await tester.pump(const Duration(seconds: 60));

      expect(service.conversationCalls, before);
    });

    testWidgets('stops once the page is gone', (tester) async {
      await pump(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));

      expect(service.conversationCalls, 1);
    });

    testWidgets('pauses in the background and catches up on return', (
      tester,
    ) async {
      await pump(tester);

      // The real order the OS reports when the app goes to the background...
      for (final st in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await tester.pump(const Duration(seconds: 90));
      expect(service.conversationCalls, 1);

      // ... and when it comes back.
      for (final st in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await tester.pump();
      expect(service.conversationCalls, 2);
    });
  });

  group('translations', () {
    testWidgets('Spanish', (tester) async {
      await pump(tester, locale: const Locale('es'));

      expect(find.text('2 mensajes sin leer'), findsOneWidget);
      expect(find.text('Activas (2)'), findsOneWidget);
      expect(find.text('Completadas (1)'), findsOneWidget);
      expect(find.text('hace 2 min'), findsOneWidget);
    });

    testWidgets('French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('2 messages non lus'), findsOneWidget);
      expect(find.text('En cours (2)'), findsOneWidget);
      expect(find.text('Terminées (1)'), findsOneWidget);
    });

    testWidgets('"You:" is translated', (tester) async {
      service.convs = [sampleConversation(lastBody: 'Hola', lastAuthor: meId)];
      await pump(tester, locale: const Locale('es'));

      expect(find.text('Tú: Hola'), findsOneWidget);
    });
  });

  testWidgets('a paid delivery shows that the escrow is funded', (
    tester,
  ) async {
    service = FakeMessageService(conversations: mixed());
    await tester.pumpWidget(
      appWrapper(MessagesScreen(service: service, now: () => now)),
    );
    await tester.pumpAndSettle();

    // Daniel's delivery is paid; Amara's is only accepted.
    expect(find.text('Escrow funded'), findsOneWidget);
    expect(find.text('Sony headphones'), findsNothing);
    expect(find.text('iPhone 15 Pro (sealed)'), findsOneWidget);
  });
}
