import 'package:carrywise_app/screens/messages_screen.dart';
import 'package:carrywise_app/screens/recipient_chat_screen.dart';
import 'package:carrywise_app/services/chat_presence.dart';
import 'package:carrywise_app/services/deep_links.dart';
import 'package:carrywise_app/services/push_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// A recipient on Nata opens their link in the app and chats with the
/// traveler from Messages; a message for the chat on screen shows no banner.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('the recipient\'s side of the chat', () {
    Future<FakeRequestService> pump(WidgetTester tester) async {
      bigScreen(tester);
      final service = FakeRequestService();
      service.recipientChatData['r1'] = RecipientChat(
        asRecipient: true,
        recipientName: 'Amara',
        senderName: 'Sarah',
        item: 'iPad Mini',
        travelerName: 'Daniel O.',
        status: 'handed_off',
        code: '4821',
        fromCity: 'Lagos',
        toCity: 'London',
        arrivalDate: DateTime(2030, 6, 22),
        open: true,
        messages: [
          RecipientMessage(
            id: 'a',
            fromRecipient: false,
            body: 'I land at 6pm',
            at: DateTime(2030, 6, 15, 10),
          ),
          RecipientMessage(
            id: 'b',
            fromRecipient: true,
            body: 'See you at arrivals',
            at: DateTime(2030, 6, 15, 10, 5),
          ),
        ],
      );
      await tester.pumpWidget(
        appWrapper(
          RecipientChatScreen(
            requestId: 'r1',
            asRecipient: true,
            service: service,
            now: () => DateTime(2030, 6, 15, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('shows the traveler, the parcel and the code', (tester) async {
      await pump(tester);

      expect(find.text('Daniel O.'), findsOneWidget);
      expect(find.text('Bringing your parcel from Sarah'), findsOneWidget);
      expect(
        find.textContaining('On the way · Lagos → London · Arrives Jun 22'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('recipient-chat-code')), findsOneWidget);
      // Not the traveler's banner about the link.
      expect(find.byKey(const ValueKey('recipient-chat-banner')), findsNothing);
    });

    testWidgets('their own messages sit on the right', (tester) async {
      await pump(tester);

      final mine = tester.getCenter(find.text('See you at arrivals')).dx;
      final theirs = tester.getCenter(find.text('I land at 6pm')).dx;
      expect(mine, greaterThan(theirs));
    });

    testWidgets('sending goes out as the recipient', (tester) async {
      final service = await pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey('recipient-chat-input')),
        'Thank you!',
      );
      await tester.tap(find.byKey(const ValueKey('recipient-chat-send')));
      await tester.pumpAndSettle();

      expect(service.sentAsRecipient.single.body, 'Thank you!');
      expect(service.recipientSent, isEmpty);
    });

    testWidgets('while it is open, it is the chat on screen', (tester) async {
      await pump(tester);
      expect(ChatPresence.current, ChatPresence.recipient('r1'));

      await tester.pumpWidget(const SizedBox());
      expect(ChatPresence.current, isNull);
    });
  });

  testWidgets('Messages lists parcel chats and opens them', (tester) async {
    bigScreen(tester);
    final requests = FakeRequestService()
      ..parcelChats = [
        RecipientChatSummary(
          requestId: 'r1',
          asRecipient: true,
          otherName: 'Daniel O.',
          senderName: 'Sarah',
          item: 'iPad Mini',
          lastBody: 'I land at 6pm',
          lastAt: DateTime(2030, 6, 15, 10),
          unread: 1,
        ),
        const RecipientChatSummary(
          requestId: 'r2',
          asRecipient: false,
          otherName: 'Amara',
          senderName: 'Kofi',
          item: 'Shoes',
          lastBody: 'Thanks',
          lastMine: true,
        ),
      ];
    await tester.pumpWidget(
      appWrapper(
        MessagesScreen(
          service: FakeMessageService(conversations: []),
          requestService: requests,
          now: () => DateTime(2030, 6, 15, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('messages-parcel-chats')), findsOneWidget);
    expect(find.text('Your parcel'), findsOneWidget);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('You: Thanks'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('parcel-chat-r1')));
    await tester.pumpAndSettle();
    final screen = tester.widget<RecipientChatScreen>(
      find.byType(RecipientChatScreen),
    );
    expect(screen.asRecipient, isTrue);
    expect(screen.requestId, 'r1');
  });

  group('links', () {
    test('a recipient link gives its token', () {
      expect(
        DeepLinks.recipientToken(
          Uri.parse('https://nata-app-a03de.web.app/r/K-zKRwIxzChsGt88'),
        ),
        'K-zKRwIxzChsGt88',
      );
      expect(
        DeepLinks.recipientToken(
          Uri.parse('https://nata-app-a03de.web.app/app'),
        ),
        isNull,
      );
      expect(
        DeepLinks.recipientToken(Uri.parse('https://evil.example/r/abc')),
        isNull,
      );
    });

    testWidgets('signed in, the link opens the recipient\'s chat', (
      tester,
    ) async {
      bigScreen(tester);
      final requests = FakeRequestService()..recipientLinks['tok'] = 'r1';
      DeepLinks.instance.requests = () => requests;
      addTearDown(() => DeepLinks.instance.requests = RequestService.new);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        appWrapper(const Scaffold(body: Text('home')), navigatorKey: navigator),
      );
      await DeepLinks.instance.start(navigator);

      final opening = DeepLinks.instance.open(
        Uri.parse('https://nata-app-a03de.web.app/r/tok'),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(requests.claimed, ['tok']);
      final screen = tester.widget<RecipientChatScreen>(
        find.byType(RecipientChatScreen),
      );
      expect(screen.asRecipient, isTrue);
      expect(screen.requestId, 'r1');
      Navigator.of(tester.element(find.byType(RecipientChatScreen))).pop();
      await tester.pumpAndSettle();
      await opening;
    });

    testWidgets('the traveler opening it is told it is for the recipient', (
      tester,
    ) async {
      bigScreen(tester);
      final requests = FakeRequestService()
        ..recipientLinks['tok'] = RecipientLinkProblem.notRecipient;
      DeepLinks.instance.requests = () => requests;
      addTearDown(() => DeepLinks.instance.requests = RequestService.new);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        appWrapper(const Scaffold(body: Text('home')), navigatorKey: navigator),
      );
      await DeepLinks.instance.start(navigator);

      final opening = DeepLinks.instance.open(
        Uri.parse('https://nata-app-a03de.web.app/r/tok'),
      );
      await tester.pump(const Duration(seconds: 1));
      await opening;
      await tester.pump();

      expect(
        find.text('This link is for the person receiving the parcel.'),
        findsOneWidget,
      );
      expect(find.byType(RecipientChatScreen), findsNothing);
    });
  });

  group('banners', () {
    test('which chat a push is about', () {
      expect(
        PushService.chatOf({'event': 'message_new', 'conversation_id': 'c1'}),
        ChatPresence.conversation('c1'),
      );
      expect(
        PushService.chatOf({'event': 'recipient_message', 'related_id': 'r1'}),
        ChatPresence.recipient('r1'),
      );
      expect(
        PushService.chatOf({
          'event': 'recipient_message_in',
          'related_id': 'r1',
        }),
        ChatPresence.recipient('r1'),
      );
      expect(PushService.chatOf({'event': 'request_paid'}), isNull);
    });
  });
}
