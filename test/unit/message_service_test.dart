import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/services/message_service.dart';
import 'package:carrywise_app/services/trip_service.dart' show PickedReceipt;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockQuerySchema extends Mock implements SupabaseQuerySchema {}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockStorage extends Mock implements SupabaseStorageClient {}

class MockFileApi extends Mock implements StorageFileApi {}

class FakeFileOptions extends Fake implements FileOptions {}

/// An awaitable query that records the filters applied to it.
class FakeQuery<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeQuery(this.value, {this.error});
  final T value;
  final Object? error;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    calls.add('eq:$column=$value');
    return this;
  }

  @override
  PostgrestTransformBuilder<T> order(String column,
      {bool ascending = false, bool nullsFirst = false, String? referencedTable}) {
    calls.add('order:$column:${ascending ? 'asc' : 'desc'}');
    return this;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) {
    calls.add('limit:$count');
    return this;
  }

  /// insert(...).select(...) : the one inserted row, as a list.
  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    calls.add('select');
    return FakeQuery<PostgrestList>(
      [Map<String, dynamic>.from(value as Map)],
      error: error,
    );
  }

  /// ... .single() : that row on its own.
  @override
  PostgrestTransformBuilder<PostgrestMap> single() {
    calls.add('single');
    final rows = value as List;
    return FakeQuery<PostgrestMap>(
      rows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(rows.first as Map),
      error: error,
    );
  }

  @override
  Future<U> then<U>(FutureOr<U> Function(T value) onValue, {Function? onError}) {
    final f = error != null ? Future<T>.error(error!) : Future<T>.value(value);
    return f.then(onValue, onError: onError);
  }
}

Map<String, dynamic> convRow({
  String id = 'c1',
  String? firstName = 'Amara',
  String? lastName = 'Kalu',
  Object? avatar,
  Object? verified = true,
  Object? iAmTraveler = false,
  Object? lastBody = 'Hi',
  Object? lastAttachment,
  Object? lastAt = '2030-06-15T12:00:00+00:00',
  Object? lastAuthor = 'u2',
  Object? unread = 2,
}) =>
    {
      'conversation_id': id,
      'request_id': 'r1',
      'created_at': '2030-06-10T09:00:00+00:00',
      'updated_at': '2030-06-15T12:00:00+00:00',
      'other_user_id': 'u2',
      'other_first_name': firstName,
      'other_last_name': lastName,
      'other_avatar_path': avatar,
      'other_verified': verified,
      'i_am_traveler': iAmTraveler,
      'departure_city': 'Lagos',
      'arrival_city': 'London',
      'item_description': 'iPhone',
      'request_status': 'accepted',
      'last_body': lastBody,
      'last_attachment_path': lastAttachment,
      'last_message_at': lastAt,
      'last_author_id': lastAuthor,
      'unread_count': unread,
    };

Map<String, dynamic> msgRow({
  String id = 'm1',
  Object? body = 'Hello',
  Object? attachment,
  Object? readAt,
  String author = 'u2',
}) =>
    {
      'id': id,
      'conversation_id': 'c1',
      'author_id': author,
      'body': body,
      'attachment_path': attachment,
      'read_at': readAt,
      'created_at': '2030-06-15T10:00:00+00:00',
    };

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(FakeFileOptions());
  });

  group('ConversationSummary.fromJson', () {
    test('parses every field', () {
      final c = ConversationSummary.fromJson(convRow(avatar: 'https://x/a.jpg'));

      expect(c.id, 'c1');
      expect(c.requestId, 'r1');
      expect(c.otherUserId, 'u2');
      expect(c.otherFirstName, 'Amara');
      expect(c.otherLastName, 'Kalu');
      expect(c.otherAvatarPath, 'https://x/a.jpg');
      expect(c.otherVerified, isTrue);
      expect(c.iAmTraveler, isFalse);
      expect(c.departureCity, 'Lagos');
      expect(c.arrivalCity, 'London');
      expect(c.itemDescription, 'iPhone');
      expect(c.requestStatus, 'accepted');
      expect(c.lastBody, 'Hi');
      expect(c.lastAuthorId, 'u2');
      expect(c.unreadCount, 2);
      expect(c.lastMessageAt?.toUtc(), DateTime.utc(2030, 6, 15, 12));
      expect(c.createdAt.toUtc(), DateTime.utc(2030, 6, 10, 9));
    });

    test('a conversation with no messages yet', () {
      final c = ConversationSummary.fromJson(convRow(
          lastBody: null, lastAt: null, lastAuthor: null, unread: 0));

      expect(c.hasMessages, isFalse);
      expect(c.lastMessageAt, isNull);
      expect(c.activityAt, c.createdAt);
      expect(c.hasUnread, isFalse);
    });

    test('a photo-only last message counts as a message', () {
      final c = ConversationSummary.fromJson(
          convRow(lastBody: null, lastAttachment: 'c1/1.jpg'));

      expect(c.hasMessages, isTrue);
      expect(c.lastBody, isNull);
      expect(c.lastAttachmentPath, 'c1/1.jpg');
    });

    test('blank values become null, missing flags get defaults', () {
      final c = ConversationSummary.fromJson(convRow(
          avatar: '  ', lastBody: '', verified: null, iAmTraveler: null, unread: null));

      expect(c.otherAvatarPath, isNull);
      expect(c.lastBody, isNull);
      expect(c.otherVerified, isFalse);
      expect(c.iAmTraveler, isFalse);
      expect(c.unreadCount, 0);
    });

    test('activity time is the last message when there is one', () {
      final c = ConversationSummary.fromJson(convRow());

      expect(c.activityAt, c.lastMessageAt);
    });
  });

  group('ConversationSummary helpers', () {
    ConversationSummary of({String? first = 'Amara', String? last = 'Kalu', String status = 'accepted', int unread = 0}) =>
        ConversationSummary.fromJson(convRow(
            firstName: first, lastName: last, unread: unread)
          ..['request_status'] = status);

    test('display name is first name + last initial', () {
      expect(of().displayName, 'Amara K.');
    });

    test('the last initial is upper-cased', () {
      expect(of(last: 'okafor').displayName, 'Amara O.');
    });

    test('without a last name it is just the first name', () {
      expect(of(last: '').displayName, 'Amara');
    });

    test('without any name it is a dash, not blank', () {
      expect(of(first: '', last: '').displayName, '—');
      expect(of(first: null, last: null).displayName, '—');
    });

    test('route label', () {
      expect(of().routeLabel, 'Lagos → London');
    });

    test('active statuses', () {
      for (final s in ['pending', 'accepted', 'paid', 'handed_off']) {
        expect(of(status: s).isActive, isTrue, reason: s);
        expect(of(status: s).isCompleted, isFalse, reason: s);
      }
    });

    test('completed is "delivered"', () {
      expect(of(status: 'delivered').isCompleted, isTrue);
      expect(of(status: 'delivered').isActive, isFalse);
    });

    test('declined, expired and cancelled are neither active nor completed',
        () {
      for (final s in ['declined', 'expired', 'cancelled']) {
        expect(of(status: s).isActive, isFalse, reason: s);
        expect(of(status: s).isCompleted, isFalse, reason: s);
      }
    });

    test('hasUnread follows the count', () {
      expect(of(unread: 0).hasUnread, isFalse);
      expect(of(unread: 3).hasUnread, isTrue);
    });
  });

  group('ChatMessage', () {
    test('parses a text message', () {
      final m = ChatMessage.fromJson(msgRow());

      expect(m.id, 'm1');
      expect(m.conversationId, 'c1');
      expect(m.authorId, 'u2');
      expect(m.body, 'Hello');
      expect(m.hasAttachment, isFalse);
      expect(m.isRead, isFalse);
      expect(m.delivery, MessageDelivery.sent);
    });

    test('parses a photo message without text', () {
      final m = ChatMessage.fromJson(msgRow(body: null, attachment: 'c1/1.jpg'));

      expect(m.body, isNull);
      expect(m.hasAttachment, isTrue);
      expect(m.attachmentPath, 'c1/1.jpg');
    });

    test('blank text counts as no text', () {
      expect(ChatMessage.fromJson(msgRow(body: '   ', attachment: 'x')).body, isNull);
    });

    test('read_at makes it read', () {
      final m = ChatMessage.fromJson(msgRow(readAt: '2030-06-15T10:05:00+00:00'));

      expect(m.isRead, isTrue);
      expect(m.readAt?.toUtc(), DateTime.utc(2030, 6, 15, 10, 5));
    });

    test('copyWith changes only what it is given', () {
      final m = ChatMessage.fromJson(msgRow());
      final failed = m.copyWith(delivery: MessageDelivery.failed);

      expect(failed.delivery, MessageDelivery.failed);
      expect(failed.id, m.id);
      expect(failed.body, m.body);
      expect(m.copyWith(id: 'x').id, 'x');
    });
  });

  group('MessageService', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late MockQuerySchema schema;
    late MockQueryBuilder messages;
    late MockStorage storage;
    late MockFileApi files;
    late MessageService service;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      final user = MockUser();
      schema = MockQuerySchema();
      messages = MockQueryBuilder();
      storage = MockStorage();
      files = MockFileApi();

      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('me-1');
      when(() => client.schema('nata')).thenReturn(schema);
      when(() => schema.from('messages')).thenAnswer((_) => messages);
      when(() => client.storage).thenReturn(storage);
      when(() => storage.from('chat-attachments')).thenReturn(files);

      service = MessageService(client: client);
    });

    test('knows who is signed in', () {
      expect(service.currentUserId, 'me-1');
      when(() => auth.currentUser).thenReturn(null);
      expect(service.currentUserId, isNull);
    });

    group('conversations', () {
      test('calls list_conversations and parses the rows', () async {
        when(() => client.rpc<dynamic>('list_conversations')).thenAnswer(
            (_) => FakeQuery<dynamic>([convRow(id: 'a'), convRow(id: 'b')]));

        final list = await service.conversations();

        expect(list.map((c) => c.id), ['a', 'b']);
      });

      test('an empty list', () async {
        when(() => client.rpc<dynamic>('list_conversations'))
            .thenAnswer((_) => FakeQuery<dynamic>([]));

        expect(await service.conversations(), isEmpty);
      });

      test('errors are passed on', () async {
        when(() => client.rpc<dynamic>('list_conversations')).thenAnswer(
            (_) => FakeQuery<dynamic>([], error: Exception('boom')));

        expect(service.conversations(), throwsException);
      });

      test('fails clearly when nobody is signed in', () async {
        when(() => auth.currentUser).thenReturn(null);

        expect(service.conversations(), throwsA(isA<Exception>()));
      });
    });

    group('messages', () {
      test('asks for one conversation, newest first, limited', () async {
        final q = FakeQuery<List<Map<String, dynamic>>>([]);
        when(() => messages.select(any())).thenAnswer((_) => q);

        await service.messages('c1');

        expect(q.calls, ['eq:conversation_id=c1', 'order:created_at:desc', 'limit:300']);
      });

      test('returns them oldest first', () async {
        when(() => messages.select(any())).thenAnswer((_) =>
            FakeQuery<List<Map<String, dynamic>>>([
              msgRow(id: 'newest'),
              msgRow(id: 'middle'),
              msgRow(id: 'oldest'),
            ]));

        final list = await service.messages('c1');

        expect(list.map((m) => m.id), ['oldest', 'middle', 'newest']);
      });

      test('honours the limit', () async {
        final q = FakeQuery<List<Map<String, dynamic>>>([]);
        when(() => messages.select(any())).thenAnswer((_) => q);

        await service.messages('c1', limit: 50);

        expect(q.calls, contains('limit:50'));
      });

      test('errors are passed on', () async {
        when(() => messages.select(any())).thenAnswer((_) =>
            FakeQuery<List<Map<String, dynamic>>>([], error: Exception('x')));

        expect(service.messages('c1'), throwsException);
      });
    });

    group('send', () {
      FakeQuery<dynamic> insertQuery([Object? error]) => FakeQuery<dynamic>(
          msgRow(id: 'new', body: 'Hi there', author: 'me-1'), error: error);

      test('writes as the signed-in user into that conversation', () async {
        when(() => messages.insert(any())).thenAnswer((_) => insertQuery());

        final m = await service.send('c1', body: 'Hi there');

        final sent = verify(() => messages.insert(captureAny())).captured.single
            as Map<String, dynamic>;
        expect(sent['conversation_id'], 'c1');
        expect(sent['author_id'], 'me-1');
        expect(sent['body'], 'Hi there');
        expect(sent['attachment_path'], isNull);
        expect(m.id, 'new');
      });

      test('trims the text', () async {
        when(() => messages.insert(any())).thenAnswer((_) => insertQuery());

        await service.send('c1', body: '   Hi there   ');

        final sent = verify(() => messages.insert(captureAny())).captured.single
            as Map<String, dynamic>;
        expect(sent['body'], 'Hi there');
      });

      test('a photo-only message has no text', () async {
        when(() => messages.insert(any())).thenAnswer((_) => insertQuery());

        await service.send('c1', attachmentPath: 'c1/1.jpg');

        final sent = verify(() => messages.insert(captureAny())).captured.single
            as Map<String, dynamic>;
        expect(sent['body'], isNull);
        expect(sent['attachment_path'], 'c1/1.jpg');
      });

      test('text with a photo sends both', () async {
        when(() => messages.insert(any())).thenAnswer((_) => insertQuery());

        await service.send('c1', body: 'Look', attachmentPath: 'c1/1.jpg');

        final sent = verify(() => messages.insert(captureAny())).captured.single
            as Map<String, dynamic>;
        expect(sent['body'], 'Look');
        expect(sent['attachment_path'], 'c1/1.jpg');
      });

      test('an empty message is refused before anything is sent', () async {
        expect(service.send('c1'), throwsArgumentError);
        expect(service.send('c1', body: '   '), throwsArgumentError);
        verifyNever(() => messages.insert(any()));
      });

      test('database errors are passed on', () async {
        when(() => messages.insert(any()))
            .thenAnswer((_) => insertQuery(Exception('rls')));

        expect(service.send('c1', body: 'x'), throwsException);
      });

      test('fails clearly when nobody is signed in', () async {
        when(() => auth.currentUser).thenReturn(null);

        expect(service.send('c1', body: 'x'), throwsA(isA<Exception>()));
      });
    });

    group('markRead', () {
      test('calls mark_conversation_read for that conversation', () async {
        when(() => client.rpc<dynamic>('mark_conversation_read',
                params: any(named: 'params')))
            .thenAnswer((_) => FakeQuery<dynamic>(null));

        await service.markRead('c1');

        verify(() => client.rpc<dynamic>('mark_conversation_read',
            params: {'p_conversation_id': 'c1'})).called(1);
      });

      test('never throws: a failure only means it is tried again later',
          () async {
        when(() => client.rpc<dynamic>('mark_conversation_read',
                params: any(named: 'params')))
            .thenAnswer((_) => FakeQuery<dynamic>(null, error: Exception('x')));

        await service.markRead('c1'); // completes normally
      });
    });

    group('photos', () {
      PickedReceipt photo(String ext) =>
          PickedReceipt(bytes: Uint8List.fromList([1, 2, 3]), name: 'p.$ext', extension: ext);

      test('are uploaded to the private chat bucket in the chat\'s folder',
          () async {
        when(() => files.uploadBinary(any(), any(),
                fileOptions: any(named: 'fileOptions')))
            .thenAnswer((_) async => 'ok');

        final path = await service.uploadAttachment('c1', photo('JPG'));

        expect(path, matches(RegExp(r'^c1/\d+\.jpg$')));
        final captured = verify(() => files.uploadBinary(captureAny(), captureAny(),
            fileOptions: captureAny(named: 'fileOptions'))).captured;
        expect(captured[0], path);
        expect((captured[2] as FileOptions).contentType, 'image/jpeg');
      });

      test('a failed upload is reported', () async {
        when(() => files.uploadBinary(any(), any(),
                fileOptions: any(named: 'fileOptions')))
            .thenThrow(Exception('too big'));

        expect(service.uploadAttachment('c1', photo('png')), throwsException);
      });

      test('are shown through a temporary signed link', () async {
        when(() => files.createSignedUrl(any(), any()))
            .thenAnswer((_) async => 'https://signed/1');

        final url = await service.attachmentUrl('c1/1.jpg');

        expect(url, 'https://signed/1');
        verify(() => files.createSignedUrl('c1/1.jpg', 3600)).called(1);
      });

      test('the same photo reuses its link, so images can be cached', () async {
        var n = 0;
        when(() => files.createSignedUrl(any(), any()))
            .thenAnswer((_) async => 'https://signed/${++n}');

        final a = await service.attachmentUrl('c1/1.jpg');
        final b = await service.attachmentUrl('c1/1.jpg');

        expect(a, b);
        verify(() => files.createSignedUrl(any(), any())).called(1);
      });

      test('different photos get their own links', () async {
        var n = 0;
        when(() => files.createSignedUrl(any(), any()))
            .thenAnswer((_) async => 'https://signed/${++n}');

        final a = await service.attachmentUrl('c1/1.jpg');
        final b = await service.attachmentUrl('c1/2.jpg');

        expect(a, isNot(b));
      });
    });
  });
}
