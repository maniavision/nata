import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/screens/chat_thread_screen.dart';
import 'package:carrywise_app/services/message_service.dart';
import 'package:carrywise_app/services/trip_service.dart' show PickedReceipt;
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

final now = DateTime(2030, 6, 15, 12, 0);

PickedReceipt photo({String name = 'IMG_1.jpg', int bytes = 2000}) =>
    PickedReceipt(bytes: Uint8List(bytes), name: name, extension: 'jpg');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeMessageService service;
  late ConversationSummary conv;
  PickedReceipt? nextPhoto;
  Object? pickerError;
  final pickerCalls = <bool>[];

  List<ChatMessage> sample() => [
    sampleMessage(
      id: 'm1',
      author: 'other-1',
      body: 'Hi! Can you carry my parcel?',
      createdAt: DateTime(2030, 6, 14, 18, 5),
    ),
    sampleMessage(
      id: 'm2',
      author: meId,
      body: 'Yes, I have space.',
      readAt: DateTime(2030, 6, 14, 18, 10),
      createdAt: DateTime(2030, 6, 14, 18, 8),
    ),
    sampleMessage(
      id: 'm3',
      author: 'other-1',
      body: 'Great, see you tomorrow.',
      createdAt: DateTime(2030, 6, 15, 10, 30),
    ),
    sampleMessage(
      id: 'm4',
      author: meId,
      body: 'On my way!',
      createdAt: DateTime(2030, 6, 15, 11, 45),
    ),
  ];

  setUp(() {
    conv = sampleConversation(id: 'conv-1');
    service = FakeMessageService(
      conversations: [conv],
      messages: {'conv-1': sample()},
    );
    nextPhoto = photo();
    pickerError = null;
    pickerCalls.clear();
  });

  Future<PickedReceipt?> fakePicker({required bool camera}) async {
    pickerCalls.add(camera);
    if (pickerError != null) throw pickerError!;
    return nextPhoto;
  }

  Future<void> pump(
    WidgetTester tester, {
    bool settle = true,
    Locale locale = const Locale('en'),
    ConversationSummary? conversation,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      appWrapper(
        ChatThreadScreen(
          conversation: conversation ?? conv,
          service: service,
          photoPicker: fakePicker,
          now: () => now,
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

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('chat-input')), text);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await type(tester, text);
    await tapKey(tester, 'chat-send');
  }

  Finder msg(String id) => find.byKey(ValueKey('msg-$id'));

  group('Live chat', () {
    late FakeChatLive live;
    setUp(() => service.liveConnection = live = FakeChatLive());

    testWidgets('a message from them shows at once, without waiting', (
      tester,
    ) async {
      await pump(tester);
      final before = service.messageCalls;
      service.thread['conv-1'] = [
        ...service.thread['conv-1']!,
        ChatMessage(
          id: 'live-1',
          conversationId: 'conv-1',
          authorId: 'other',
          body: 'Just landed!',
          attachmentPath: null,
          readAt: null,
          createdAt: now,
        ),
      ];

      service.liveOnChange!();
      await tester.pump();
      await tester.pump();

      expect(service.messageCalls, before + 1);
      expect(find.text('Just landed!'), findsOneWidget);
    });

    testWidgets('their typing shows dots and "typing…", then goes away', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('chat-typing')), findsNothing);

      service.liveOnTyping!();
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-typing')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('chat-subtitle'))).data,
        'typing…',
      );

      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('chat-typing')), findsNothing);
      expect(find.text('typing…'), findsNothing);
    });

    testWidgets('typing in the box tells the other person', (tester) async {
      await pump(tester);
      await type(tester, 'On my way');
      expect(live.typingSent, greaterThan(0));
    });

    testWidgets('leaving the chat closes the connection', (tester) async {
      await pump(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(live.closed, isTrue);
    });

    testWidgets('typing is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));
      service.liveOnTyping!();
      await tester.pump();
      expect(find.text('écrit…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
  double top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

  group('header', () {
    testWidgets('shows who you are talking to', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('chat-title')), findsOneWidget);
      expect(find.text('Amara K.'), findsWidgets);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('shows the route and the item', (tester) async {
      await pump(tester);

      expect(
        find.text('Lagos → London · iPhone 15 Pro (sealed)'),
        findsOneWidget,
      );
    });

    testWidgets('no verified badge for an unverified person', (tester) async {
      await pump(tester, conversation: sampleConversation(verified: false));

      expect(find.byIcon(Icons.verified_rounded), findsNothing);
    });

    testWidgets('back leaves the chat', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      conversation: conv,
                      service: service,
                      now: () => now,
                    ),
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
      expect(find.byType(ChatThreadScreen), findsOneWidget);

      await tapKey(tester, 'chat-back');

      expect(find.byType(ChatThreadScreen), findsNothing);
    });

    testWidgets('has none of the old made-up content', (tester) async {
      await pump(tester);

      expect(find.textContaining('Escrow Funded'), findsNothing);
      expect(find.textContaining('7 4 2 1'), findsNothing);
      expect(find.textContaining('Flight BA075'), findsNothing);
      expect(find.text('View Code'), findsNothing);
    });
  });

  group('loading, empty and error', () {
    testWidgets('spinner first', (tester) async {
      await pump(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an empty chat invites you to say hello', (tester) async {
      service.thread['conv-1'] = [];
      await pump(tester);

      expect(find.byKey(const ValueKey('chat-empty')), findsOneWidget);
      expect(find.text('No messages yet. Say hello!'), findsOneWidget);
      // ... and you can still write.
      expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    });

    testWidgets('error with a working Retry', (tester) async {
      service.failMessages = true;
      await pump(tester);

      expect(find.byKey(const ValueKey('chat-error')), findsOneWidget);
      expect(find.text('Could not load this chat.'), findsOneWidget);

      service.failMessages = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chat-error')), findsNothing);
      expect(find.text('On my way!'), findsOneWidget);
    });
  });

  group('messages', () {
    testWidgets('are all shown', (tester) async {
      await pump(tester);

      for (final t in [
        'Hi! Can you carry my parcel?',
        'Yes, I have space.',
        'Great, see you tomorrow.',
        'On my way!',
      ]) {
        expect(find.text(t), findsOneWidget);
      }
    });

    testWidgets('oldest at the top, newest at the bottom', (tester) async {
      await pump(tester);

      expect(top(tester, msg('m1')), lessThan(top(tester, msg('m2'))));
      expect(top(tester, msg('m2')), lessThan(top(tester, msg('m3'))));
      expect(top(tester, msg('m3')), lessThan(top(tester, msg('m4'))));
    });

    testWidgets('mine on the right, theirs on the left', (tester) async {
      await pump(tester);

      final screenMid = tester.view.physicalSize.width / 2;
      expect(
        tester.getCenter(find.text('On my way!')).dx,
        greaterThan(screenMid),
      );
      expect(
        tester.getCenter(find.text('Great, see you tomorrow.')).dx,
        lessThan(screenMid),
      );
    });

    testWidgets('start at the newest message with no scrolling', (
      tester,
    ) async {
      service.thread['conv-1'] = [
        for (var i = 0; i < 60; i++)
          sampleMessage(
            id: 'x$i',
            author: i.isEven ? 'other-1' : meId,
            body: 'Message number $i',
            createdAt: DateTime(2030, 6, 15, 8).add(Duration(minutes: i)),
          ),
      ];
      await pump(tester);

      expect(find.text('Message number 59'), findsOneWidget);
      expect(find.text('Message number 0'), findsNothing);
    });

    testWidgets('each shows its time', (tester) async {
      await pump(tester);

      expect(find.textContaining('6:05 PM'), findsOneWidget);
      expect(find.textContaining('10:30 AM'), findsOneWidget);
    });

    testWidgets('my messages say Sent, or Read once they were seen', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('6:08 PM · Read ✓✓'), findsOneWidget);
      expect(find.text('11:45 AM · Sent ✓'), findsOneWidget);
    });

    testWidgets('their messages show only the time, no status', (tester) async {
      await pump(tester);

      expect(find.text('10:30 AM'), findsOneWidget);
    });

    testWidgets('are grouped by day with date chips', (tester) async {
      await pump(tester);

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(
        top(tester, find.text('Yesterday')),
        lessThan(top(tester, msg('m1'))),
      );
      expect(top(tester, msg('m2')), lessThan(top(tester, find.text('Today'))));
      expect(top(tester, find.text('Today')), lessThan(top(tester, msg('m3'))));
    });

    testWidgets('older days show the date, and other years the year', (
      tester,
    ) async {
      service.thread['conv-1'] = [
        sampleMessage(id: 'a', createdAt: DateTime(2030, 6, 3, 9)),
        sampleMessage(id: 'b', createdAt: DateTime(2029, 12, 24, 9)),
      ];
      await pump(tester);

      expect(find.text('Jun 3'), findsOneWidget);
      expect(find.text('Dec 24, 2029'), findsOneWidget);
    });

    testWidgets('one chip per day, not per message', (tester) async {
      await pump(tester);

      expect(find.text('Today'), findsOneWidget); // m3 and m4 share a day
    });

    testWidgets('a photo-only message has no empty text bubble', (
      tester,
    ) async {
      service.thread['conv-1'] = [
        sampleMessage(id: 'p', body: null, attachment: 'conv-1/1.jpg'),
      ];
      await pump(tester);

      expect(find.byKey(const ValueKey('photo-p')), findsOneWidget);
    });
  });

  group('reading', () {
    testWidgets('opening a chat marks the other person\'s messages as read', (
      tester,
    ) async {
      await pump(tester);

      expect(service.markedRead, ['conv-1']);
    });

    testWidgets('nothing to mark when they are all already read', (
      tester,
    ) async {
      service.thread['conv-1'] = [
        sampleMessage(
          id: 'a',
          author: 'other-1',
          readAt: DateTime(2030, 6, 15, 9),
        ),
        sampleMessage(id: 'b', author: meId),
      ];
      await pump(tester);

      expect(service.markedRead, isEmpty);
    });

    testWidgets('my own unread messages do not count', (tester) async {
      service.thread['conv-1'] = [sampleMessage(author: meId, readAt: null)];
      await pump(tester);

      expect(service.markedRead, isEmpty);
    });

    testWidgets('a new message from them is marked read on the next refresh', (
      tester,
    ) async {
      service.thread['conv-1'] = [
        sampleMessage(
          id: 'a',
          author: 'other-1',
          readAt: DateTime(2030, 6, 15, 9),
        ),
      ];
      await pump(tester);
      expect(service.markedRead, isEmpty);

      service.thread['conv-1'] = [
        ...service.thread['conv-1']!,
        sampleMessage(
          id: 'b',
          author: 'other-1',
          createdAt: DateTime(2030, 6, 15, 11),
        ),
      ];
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(service.markedRead, ['conv-1']);
    });
  });

  group('sending text', () {
    testWidgets('has an input, a send button and the camera / attach buttons', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
      expect(find.text('Type a message…'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-send')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-camera')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-gallery')), findsOneWidget);
    });

    testWidgets('sends the text and shows it at the bottom', (tester) async {
      await pump(tester);

      await send(tester, 'See you at the gate');

      expect(service.sent.single.body, 'See you at the gate');
      expect(service.sent.single.conversationId, 'conv-1');
      expect(find.text('See you at the gate'), findsOneWidget);
      final newest = find.text('See you at the gate');
      expect(top(tester, newest), greaterThan(top(tester, msg('m4'))));
    });

    testWidgets('clears the input straight away', (tester) async {
      await pump(tester);

      await send(tester, 'Hello');

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-input')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('trims the text', (tester) async {
      await pump(tester);

      await send(tester, '   padded   ');

      expect(service.sent.single.body, 'padded');
    });

    testWidgets('an empty or blank message is not sent', (tester) async {
      await pump(tester);

      await tapKey(tester, 'chat-send');
      await send(tester, '    ');

      expect(service.sent, isEmpty);
    });

    testWidgets('shows "Sending…" until it is confirmed, then "Sent"', (
      tester,
    ) async {
      service.sendGate = Completer<void>();
      await pump(tester);

      await type(tester, 'Slow one');
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pump();

      expect(find.text('Slow one'), findsOneWidget);
      expect(find.textContaining('Sending…'), findsOneWidget);

      service.sendGate!.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('Sending…'), findsNothing);
      expect(find.textContaining('· Sent ✓'), findsWidgets);
    });

    testWidgets('a confirmed message is shown once, not twice', (tester) async {
      await pump(tester);

      await send(tester, 'Only once');
      await tester.pump(const Duration(seconds: 4)); // a refresh picks it up
      await tester.pump();

      expect(find.text('Only once'), findsOneWidget);
    });

    testWidgets('several messages keep their order', (tester) async {
      await pump(tester);

      await send(tester, 'first new');
      await send(tester, 'second new');
      await send(tester, 'third new');

      expect(
        top(tester, find.text('first new')),
        lessThan(top(tester, find.text('second new'))),
      );
      expect(
        top(tester, find.text('second new')),
        lessThan(top(tester, find.text('third new'))),
      );
    });
  });

  group('when sending fails', () {
    testWidgets('the message stays, marked "Not sent · tap to retry"', (
      tester,
    ) async {
      service.failSend = true;
      await pump(tester);

      await send(tester, 'Did this go?');

      expect(find.text('Did this go?'), findsOneWidget);
      expect(find.text('Not sent · tap to retry'), findsOneWidget);
      expect(service.sent, isEmpty);
    });

    testWidgets('tapping it tries again, and it then goes through', (
      tester,
    ) async {
      service.failSend = true;
      await pump(tester);
      await send(tester, 'Retry me');

      service.failSend = false;
      await tester.tap(find.text('Retry me'));
      await tester.pumpAndSettle();

      expect(service.sent.single.body, 'Retry me');
      expect(find.text('Not sent · tap to retry'), findsNothing);
      expect(find.text('Retry me'), findsOneWidget);
    });

    testWidgets('a refresh does not wipe a failed message', (tester) async {
      service.failSend = true;
      await pump(tester);
      await send(tester, 'Still here');

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Still here'), findsOneWidget);
      expect(find.text('Not sent · tap to retry'), findsOneWidget);
    });

    testWidgets('retrying twice never duplicates it', (tester) async {
      service.failSend = true;
      await pump(tester);
      await send(tester, 'Once please');

      await tester.tap(find.text('Once please')); // fails again
      await tester.pumpAndSettle();
      service.failSend = false;
      await tester.tap(find.text('Once please'));
      await tester.pumpAndSettle();

      expect(find.text('Once please'), findsOneWidget);
      expect(service.sent.length, 1);
    });

    testWidgets('the chat keeps working after a failure', (tester) async {
      service.failSend = true;
      await pump(tester);
      await send(tester, 'lost');
      service.failSend = false;

      await send(tester, 'works');

      expect(service.sent.single.body, 'works');
    });
  });

  group('refreshing by itself', () {
    testWidgets('new messages appear every 4 seconds without leaving', (
      tester,
    ) async {
      await pump(tester);
      final before = service.messageCalls;

      service.thread['conv-1'] = [
        ...service.thread['conv-1']!,
        sampleMessage(
          id: 'new',
          author: 'other-1',
          body: 'Just landed!',
          createdAt: DateTime(2030, 6, 15, 11, 59),
        ),
      ];
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Just landed!'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(service.messageCalls, before + 1);
      expect(find.text('Just landed!'), findsOneWidget);
    });

    testWidgets('read receipts update', (tester) async {
      await pump(tester);
      expect(find.text('11:45 AM · Sent ✓'), findsOneWidget);

      service.thread['conv-1'] = [
        for (final m in service.thread['conv-1']!)
          m.id == 'm4'
              ? sampleMessage(
                  id: 'm4',
                  author: meId,
                  body: 'On my way!',
                  readAt: DateTime(2030, 6, 15, 11, 50),
                  createdAt: DateTime(2030, 6, 15, 11, 45),
                )
              : m,
      ];
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('11:45 AM · Read ✓✓'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the chat on screen', (tester) async {
      await pump(tester);
      service.failMessages = true;

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-error')), findsNothing);
      expect(find.text('On my way!'), findsOneWidget);
    });

    testWidgets('stops once the chat is closed', (tester) async {
      await pump(tester);
      final calls = service.messageCalls;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));

      expect(service.messageCalls, calls);
    });

    testWidgets('pauses in the background and catches up on return', (
      tester,
    ) async {
      await pump(tester);
      final calls = service.messageCalls;

      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(const Duration(seconds: 60));
      expect(service.messageCalls, calls);

      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(service.messageCalls, calls + 1);
    });
  });

  group('photos', () {
    testWidgets('the camera button takes a photo and sends it', (tester) async {
      await pump(tester);

      await tapKey(tester, 'chat-camera');

      expect(pickerCalls, [true]);
      expect(service.uploads.single.name, 'IMG_1.jpg');
      expect(service.sent.single.attachment, 'conv-1/1.jpg');
      expect(service.sent.single.body, isNull);
    });

    testWidgets('the attach button chooses one from the library', (
      tester,
    ) async {
      await pump(tester);

      await tapKey(tester, 'chat-gallery');

      expect(pickerCalls, [false]);
      expect(service.sent.single.attachment, isNotNull);
    });

    testWidgets('the photo shows in the chat straight away', (tester) async {
      service.sendGate = Completer<void>();
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('chat-camera')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(Image), findsWidgets);
      expect(find.textContaining('Sending…'), findsOneWidget);

      service.sendGate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Sending…'), findsNothing);
    });

    testWidgets('cancelling the picker sends nothing', (tester) async {
      nextPhoto = null;
      await pump(tester);

      await tapKey(tester, 'chat-camera');

      expect(service.uploads, isEmpty);
      expect(service.sent, isEmpty);
      expect(find.byKey(const ValueKey('chat-notice')), findsNothing);
    });

    testWidgets('a camera or library problem shows a message', (tester) async {
      pickerError = Exception('no camera');
      await pump(tester);

      await tapKey(tester, 'chat-camera');

      expect(find.byKey(const ValueKey('chat-notice')), findsOneWidget);
      expect(find.text('Could not open the camera or photos.'), findsOneWidget);
      expect(service.sent, isEmpty);
    });

    testWidgets('camera access turned off explains how to turn it on', (
      tester,
    ) async {
      pickerError = PlatformException(
        code: 'camera_access_denied',
        message: 'The user did not allow camera access.',
      );
      await pump(tester);

      await tapKey(tester, 'chat-camera');

      expect(find.byKey(const ValueKey('camera-denied')), findsOneWidget);
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('camera-denied-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('camera-denied')), findsNothing);
    });

    testWidgets('a photo over 10 MB is refused', (tester) async {
      nextPhoto = photo(bytes: 10 * 1024 * 1024 + 1);
      await pump(tester);

      await tapKey(tester, 'chat-gallery');

      expect(find.text('Could not send the photo.'), findsOneWidget);
      expect(service.uploads, isEmpty);
    });

    testWidgets('a failed upload leaves a retryable message', (tester) async {
      service.failUpload = true;
      await pump(tester);

      await tapKey(tester, 'chat-camera');

      expect(find.text('Not sent · tap to retry'), findsOneWidget);
      expect(service.sent, isEmpty);
    });

    testWidgets('retrying a failed photo uploads it again and sends it', (
      tester,
    ) async {
      service.failUpload = true;
      await pump(tester);
      await tapKey(tester, 'chat-camera');

      service.failUpload = false;
      await tester.tap(find.text('Not sent · tap to retry'));
      await tester.pumpAndSettle();

      expect(service.uploads.length, 1);
      expect(service.sent.single.attachment, isNotNull);
      expect(find.text('Not sent · tap to retry'), findsNothing);
    });

    testWidgets('a notice clears once a photo goes through', (tester) async {
      pickerError = Exception('x');
      await pump(tester);
      await tapKey(tester, 'chat-camera');
      expect(find.byKey(const ValueKey('chat-notice')), findsOneWidget);

      pickerError = null;
      await tapKey(tester, 'chat-camera');

      expect(find.byKey(const ValueKey('chat-notice')), findsNothing);
    });

    testWidgets('photos from the other person load through a signed link', (
      tester,
    ) async {
      service.thread['conv-1'] = [
        sampleMessage(
          id: 'p1',
          author: 'other-1',
          body: 'Here it is',
          attachment: 'conv-1/9.jpg',
        ),
      ];
      await pump(tester);

      expect(find.byKey(const ValueKey('photo-p1')), findsOneWidget);
      expect(find.text('Here it is'), findsOneWidget);
    });

    testWidgets('a photo that cannot be loaded shows a placeholder', (
      tester,
    ) async {
      service.failAttachmentUrl = true;
      service.thread['conv-1'] = [
        sampleMessage(id: 'p1', body: null, attachment: 'conv-1/9.jpg'),
      ];
      await pump(tester);

      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets(
      'tapping a photo opens it full screen, tapping again closes it',
      (tester) async {
        service.thread['conv-1'] = [
          sampleMessage(id: 'p1', body: null, attachment: 'conv-1/9.jpg'),
        ];
        await pump(tester);

        await tester.tap(find.byKey(const ValueKey('photo-p1')));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);

        await tester.tap(find.byType(InteractiveViewer));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
      },
    );
  });

  group('translations', () {
    testWidgets('Spanish', (tester) async {
      await pump(tester, locale: const Locale('es'));

      expect(find.text('Escribe un mensaje…'), findsOneWidget);
      expect(find.text('Ayer'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('11:45 AM · Enviado ✓'), findsOneWidget);
    });

    testWidgets('French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Écrivez un message…'), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('11:45 AM · Envoyé ✓'), findsOneWidget);
    });

    testWidgets('empty chat and failures are translated', (tester) async {
      service.thread['conv-1'] = [];
      service.failSend = true;
      await pump(tester, locale: const Locale('es'));
      expect(find.text('Aún no hay mensajes. ¡Saluda!'), findsOneWidget);

      await send(tester, 'hola');
      expect(find.text('No enviado · toca para reintentar'), findsOneWidget);
    });
  });

  group('Locked until payment', () {
    for (final status in ['pending', 'accepted']) {
      testWidgets('$status: no input, and it says why', (tester) async {
        service = FakeMessageService(
          conversations: [sampleConversation(status: status)],
        );
        await tester.pumpWidget(
          appWrapper(
            ChatThreadScreen(
              conversation: sampleConversation(status: status),
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('chat-locked')), findsOneWidget);
        expect(find.byKey(const ValueKey('chat-input')), findsNothing);
        expect(
          find.textContaining('Chat unlocks once the delivery is paid'),
          findsOneWidget,
        );
      });
    }

    for (final status in ['paid', 'handed_off', 'delivered']) {
      testWidgets('$status: open', (tester) async {
        service = FakeMessageService(
          conversations: [sampleConversation(status: status)],
        );
        await tester.pumpWidget(
          appWrapper(
            ChatThreadScreen(
              conversation: sampleConversation(status: status),
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
        expect(find.byKey(const ValueKey('chat-locked')), findsNothing);
      });
    }
  });

  group('delivery card', () {
    Future<FakeRequestService> pumpCard(
      WidgetTester tester, {
      required String status,
      bool iAmTraveler = false,
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final requests = FakeRequestService()
        ..codes = {'req-conv-1': const DeliveryCode('4827')};
      await tester.pumpWidget(
        appWrapper(
          ChatThreadScreen(
            conversation: sampleConversation(
              status: status,
              iAmTraveler: iAmTraveler,
            ),
            service: service,
            requestService: requests,
            photoPicker: fakePicker,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return requests;
    }

    testWidgets('paid: the steps, and the sender can see the code', (
      tester,
    ) async {
      await pumpCard(tester, status: 'paid');

      final card = find.byKey(const ValueKey('chat-delivery-card'));
      expect(card, findsOneWidget);
      for (final step in ['Paid', 'Picked up', 'Delivered']) {
        expect(
          find.descendant(of: card, matching: find.text(step)),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const ValueKey('chat-view-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-code-dialog')), findsOneWidget);
      expect(find.text('4 8 2 7'), findsOneWidget);
    });

    testWidgets('the traveler never sees the code', (tester) async {
      await pumpCard(tester, status: 'handed_off', iAmTraveler: true);

      expect(find.byKey(const ValueKey('chat-delivery-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-view-code')), findsNothing);
    });

    testWidgets('delivered: no code any more', (tester) async {
      await pumpCard(tester, status: 'delivered');

      expect(find.byKey(const ValueKey('chat-view-code')), findsNothing);
    });

    testWidgets('not paid yet: no card', (tester) async {
      await pumpCard(tester, status: 'accepted');

      expect(find.byKey(const ValueKey('chat-delivery-card')), findsNothing);
    });
  });
}
