import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/screens/recipient_chat_screen.dart';
import 'package:carrywise_app/services/notification_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The traveler's chat with the recipient, who replies from a texted link.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final now = DateTime(2030, 6, 15, 12);

  RecipientChat chat({
    List<RecipientMessage> messages = const [],
    DateTime? seenAt,
    bool open = true,
  }) => RecipientChat(
    recipientName: 'Amara',
    senderName: 'Sarah',
    item: 'iPad Mini',
    seenAt: seenAt,
    open: open,
    messages: messages,
  );

  Future<FakeRequestService> pump(
    WidgetTester tester, {
    RecipientChat? data,
    Locale locale = const Locale('en'),
    FakeRequestService? service,
  }) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final s = service ?? FakeRequestService();
    if (data != null) s.recipientChatData['r1'] = data;
    await tester.pumpWidget(
      appWrapper(
        RecipientChatScreen(requestId: 'r1', service: s, now: () => now),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  testWidgets('says the recipient answers from a link, and who it is', (
    tester,
  ) async {
    await pump(tester, data: chat());

    expect(find.text('Amara (recipient)'), findsOneWidget);
    expect(find.text('Parcel from Sarah · iPad Mini'), findsOneWidget);
    expect(
      find.text(
        "Amara isn't on Nata. They read and reply from a private link we "
        'texted them.',
      ),
      findsOneWidget,
    );
    expect(find.text("Hasn't opened the link yet"), findsOneWidget);
    expect(
      find.text('Say hello to Amara to arrange the handover.'),
      findsOneWidget,
    );
  });

  testWidgets('shows when the recipient last opened the link', (tester) async {
    await pump(tester, data: chat(seenAt: DateTime(2030, 6, 15, 9, 30)));

    expect(find.text('Opened the link 09:30'), findsOneWidget);
  });

  testWidgets('lists the messages of both sides', (tester) async {
    await pump(
      tester,
      data: chat(
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
      ),
    );

    expect(find.text('I land at 6pm'), findsOneWidget);
    expect(find.text('See you at arrivals'), findsOneWidget);
    // The traveler's own message sits on the right.
    final mine = tester.getCenter(find.text('I land at 6pm')).dx;
    final theirs = tester.getCenter(find.text('See you at arrivals')).dx;
    expect(mine, greaterThan(theirs));
  });

  testWidgets('sending adds the message', (tester) async {
    final service = await pump(tester, data: chat());

    await tester.enterText(
      find.byKey(const ValueKey('recipient-chat-input')),
      '  Meeting at Costa, Terminal 5  ',
    );
    await tester.tap(find.byKey(const ValueKey('recipient-chat-send')));
    await tester.pumpAndSettle();

    expect(service.recipientSent.single.body, 'Meeting at Costa, Terminal 5');
    expect(find.text('Meeting at Costa, Terminal 5'), findsOneWidget);
  });

  testWidgets('an empty message is not sent', (tester) async {
    final service = await pump(tester, data: chat());

    await tester.tap(find.byKey(const ValueKey('recipient-chat-send')));
    await tester.pumpAndSettle();

    expect(service.recipientSent, isEmpty);
  });

  testWidgets('a failed send says so and keeps the text', (tester) async {
    final service = FakeRequestService()..failRecipientSend = true;
    await pump(tester, data: chat(), service: service);

    await tester.enterText(
      find.byKey(const ValueKey('recipient-chat-input')),
      'Hello',
    );
    await tester.tap(find.byKey(const ValueKey('recipient-chat-send')));
    await tester.pumpAndSettle();

    expect(
      find.text("Your message wasn't sent. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('after the delivery the chat is closed', (tester) async {
    await pump(tester, data: chat(open: false));

    expect(find.byKey(const ValueKey('recipient-chat-input')), findsNothing);
    expect(find.text('The chat closed after the delivery.'), findsOneWidget);
  });

  testWidgets('a chat that cannot load offers to retry', (tester) async {
    final service = FakeRequestService()..failRecipientChat = true;
    await pump(tester, service: service);

    expect(find.byKey(const ValueKey('recipient-chat-error')), findsOneWidget);
  });

  testWidgets('in French', (tester) async {
    await pump(tester, data: chat(), locale: const Locale('fr'));

    expect(find.text('Amara (destinataire)'), findsOneWidget);
    expect(find.text("N'a pas encore ouvert le lien"), findsOneWidget);
  });

  testWidgets('a notification about the recipient\'s message opens the chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        NotificationsScreen(
          service: FakeNotificationService(
            items: [
              AppNotification(
                id: 'n1',
                type: 'message',
                title: 'Amara',
                body: 'See you at arrivals',
                imageUrl: null,
                isRead: false,
                createdAt: DateTime(2030, 6, 15, 11, 58),
                payload: const {
                  'event': 'recipient_message',
                  'recipient': 'Amara',
                  'message': 'See you at arrivals',
                  'request_id': 'r1',
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New message from Amara'), findsOneWidget);

    await tester.tap(find.text('New message from Amara'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RecipientChatScreen), findsOneWidget);
  });
}
