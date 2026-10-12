import 'dart:async';

import 'package:carrywise_app/l10n/app_localizations_en.dart';
import 'package:carrywise_app/l10n/app_localizations_es.dart';
import 'package:carrywise_app/l10n/app_localizations_fr.dart';
import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/services/notification_service.dart';
import 'package:carrywise_app/widgets/avatar_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockQuerySchema extends Mock implements SupabaseQuerySchema {}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

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
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    calls.add('order:$column:${ascending ? 'asc' : 'desc'}');
    return this;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) {
    calls.add('limit:$count');
    return this;
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    final future = error != null
        ? Future<T>.error(error!)
        : Future<T>.value(value);
    return future.then(onValue, onError: onError);
  }
}

Map<String, dynamic> row({
  String id = 'n1',
  String type = 'request',
  String title = 'Request accepted',
  String? body = 'Amara K. accepted your request.',
  String? imageUrl,
  bool? isRead = false,
  String createdAt = '2030-06-15T12:00:00+00:00',
}) => {
  'id': id,
  'type': type,
  'title': title,
  'body': body,
  'image_url': imageUrl,
  'is_read': isRead,
  'created_at': createdAt,
};

void main() {
  group('AppNotification.fromJson', () {
    test('parses every field', () {
      final n = AppNotification.fromJson(
        row(
          type: 'message',
          imageUrl: 'https://example.com/a.jpg',
          isRead: true,
        ),
      );

      expect(n.id, 'n1');
      expect(n.type, 'message');
      expect(n.title, 'Request accepted');
      expect(n.body, 'Amara K. accepted your request.');
      expect(n.imageUrl, 'https://example.com/a.jpg');
      expect(n.isRead, isTrue);
      expect(n.createdAt.toUtc(), DateTime.utc(2030, 6, 15, 12));
    });

    test('the time is converted to the device time zone', () {
      final n = AppNotification.fromJson(row());

      expect(n.createdAt.isUtc, isFalse);
    });

    test('missing values get safe defaults', () {
      final n = AppNotification.fromJson({
        'id': 'x',
        'created_at': '2030-06-15T12:00:00+00:00',
      });

      expect(n.type, 'system');
      expect(n.title, '');
      expect(n.body, '');
      expect(n.imageUrl, isNull);
      expect(n.isRead, isFalse);
    });

    test('a blank image becomes null', () {
      expect(AppNotification.fromJson(row(imageUrl: '')).imageUrl, isNull);
      expect(AppNotification.fromJson(row(imageUrl: '   ')).imageUrl, isNull);
    });

    test('null body and null is_read are tolerated', () {
      final n = AppNotification.fromJson(row(body: null, isRead: null));

      expect(n.body, '');
      expect(n.isRead, isFalse);
    });

    test('copyWith changes only the read flag', () {
      final n = AppNotification.fromJson(row());
      final read = n.copyWith(isRead: true);

      expect(read.isRead, isTrue);
      expect(read.id, n.id);
      expect(read.title, n.title);
      expect(read.createdAt, n.createdAt);
      expect(n.isRead, isFalse); // original untouched
    });

    group('category', () {
      NotificationCategory cat(String type) =>
          AppNotification.fromJson(row(type: type)).category;

      test('request / trip / payment have their own tab', () {
        expect(cat('request'), NotificationCategory.requests);
        expect(cat('trip'), NotificationCategory.trips);
        expect(cat('payment'), NotificationCategory.payments);
      });

      test('everything else only appears under All', () {
        expect(cat('message'), NotificationCategory.other);
        expect(cat('verification'), NotificationCategory.other);
        expect(cat('system'), NotificationCategory.other);
        expect(cat('something-new'), NotificationCategory.other);
      });
    });
  });

  group('NotificationService', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late MockQuerySchema schema;
    late MockQueryBuilder table;
    late NotificationService service;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      final user = MockUser();
      schema = MockQuerySchema();
      table = MockQueryBuilder();

      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('user-1');
      when(() => client.schema('nata')).thenReturn(schema);
      when(() => schema.from('notifications')).thenAnswer((_) => table);

      service = NotificationService(client: client);
    });

    group('list', () {
      test('loads only this user\'s notifications, newest first', () async {
        final query = FakeQuery<List<Map<String, dynamic>>>([]);
        when(() => table.select(any())).thenAnswer((_) => query);

        await service.list();

        expect(query.calls, [
          'eq:user_id=user-1',
          'order:created_at:desc',
          'limit:100',
        ]);
      });

      test('honours the limit', () async {
        final query = FakeQuery<List<Map<String, dynamic>>>([]);
        when(() => table.select(any())).thenAnswer((_) => query);

        await service.list(limit: 20);

        expect(query.calls, contains('limit:20'));
      });

      test('parses the rows in order', () async {
        when(() => table.select(any())).thenAnswer(
          (_) => FakeQuery<List<Map<String, dynamic>>>([
            row(id: 'a', type: 'request'),
            row(id: 'b', type: 'payment'),
          ]),
        );

        final list = await service.list();

        expect(list.map((n) => n.id), ['a', 'b']);
        expect(list.last.category, NotificationCategory.payments);
      });

      test('an empty table is an empty list', () async {
        when(
          () => table.select(any()),
        ).thenAnswer((_) => FakeQuery<List<Map<String, dynamic>>>([]));

        expect(await service.list(), isEmpty);
      });

      test('asks only for the columns it needs', () async {
        when(
          () => table.select(any()),
        ).thenAnswer((_) => FakeQuery<List<Map<String, dynamic>>>([]));

        await service.list();

        final cols =
            verify(() => table.select(captureAny())).captured.single as String;
        for (final c in [
          'id',
          'type',
          'title',
          'body',
          'image_url',
          'is_read',
          'created_at',
        ]) {
          expect(cols, contains(c));
        }
        expect(cols, isNot(contains('user_id')));
      });

      test('errors are passed on so the screen can show them', () async {
        when(() => table.select(any())).thenAnswer(
          (_) => FakeQuery<List<Map<String, dynamic>>>(
            [],
            error: Exception('relation does not exist'),
          ),
        );

        expect(service.list(), throwsException);
      });

      test('fails clearly when nobody is signed in', () async {
        when(() => auth.currentUser).thenReturn(null);

        expect(service.list(), throwsA(isA<Exception>()));
      });
    });

    group('markRead', () {
      test('marks just that notification, for this user', () async {
        final query = FakeQuery<dynamic>(null);
        when(() => table.update(any())).thenAnswer((_) => query);

        await service.markRead('n-9');

        expect(query.calls, ['eq:id=n-9', 'eq:user_id=user-1']);
        expect(verify(() => table.update(captureAny())).captured.single, {
          'is_read': true,
        });
      });

      test('failures are rethrown', () async {
        when(() => table.update(any())).thenAnswer(
          (_) => FakeQuery<dynamic>(null, error: Exception('denied')),
        );

        expect(service.markRead('n-9'), throwsException);
      });
    });

    group('markAllRead', () {
      test('marks only this user\'s unread notifications', () async {
        final query = FakeQuery<dynamic>(null);
        when(() => table.update(any())).thenAnswer((_) => query);

        await service.markAllRead();

        expect(query.calls, ['eq:user_id=user-1', 'eq:is_read=false']);
        expect(verify(() => table.update(captureAny())).captured.single, {
          'is_read': true,
        });
      });

      test('failures are rethrown', () async {
        when(() => table.update(any())).thenAnswer(
          (_) => FakeQuery<dynamic>(null, error: Exception('denied')),
        );

        expect(service.markAllRead(), throwsException);
      });
    });
  });

  group('notificationTimeLabel', () {
    final now = DateTime(2030, 6, 15, 12, 0);
    final en = AppLocalizationsEn();

    String label(DateTime then, [dynamic l]) =>
        notificationTimeLabel(l ?? en, now, then);

    test('under a minute is "Just now"', () {
      expect(label(now), 'Just now');
      expect(label(now.subtract(const Duration(seconds: 59))), 'Just now');
    });

    test('a time in the future is "Just now" too', () {
      expect(label(now.add(const Duration(minutes: 5))), 'Just now');
    });

    test('minutes', () {
      expect(label(now.subtract(const Duration(minutes: 1))), '1 min ago');
      expect(label(now.subtract(const Duration(minutes: 2))), '2 min ago');
      expect(label(now.subtract(const Duration(minutes: 59))), '59 min ago');
    });

    test('hours later the same day', () {
      expect(label(DateTime(2030, 6, 15, 11, 0)), '1 hr ago');
      expect(label(DateTime(2030, 6, 15, 7, 30)), '4 hr ago');
      expect(label(DateTime(2030, 6, 15, 0, 5)), '11 hr ago');
    });

    test('exactly an hour is "1 hr ago"', () {
      expect(label(now.subtract(const Duration(minutes: 60))), '1 hr ago');
    });

    test('the previous calendar day is "Yesterday"', () {
      expect(label(DateTime(2030, 6, 14, 10, 0)), 'Yesterday');
      expect(label(DateTime(2030, 6, 14, 0, 1)), 'Yesterday');
    });

    test('earlier this year shows the date', () {
      expect(label(DateTime(2030, 6, 12, 9, 0)), 'Jun 12');
      expect(label(DateTime(2030, 1, 3)), 'Jan 3');
    });

    test('a previous year includes the year', () {
      expect(label(DateTime(2029, 12, 31)), 'Dec 31, 2029');
    });

    test('is translated to Spanish', () {
      final es = AppLocalizationsEs();
      expect(label(now, es), 'Ahora mismo');
      expect(label(now.subtract(const Duration(minutes: 5)), es), 'hace 5 min');
      expect(label(DateTime(2030, 6, 15, 8), es), 'hace 4 h');
      expect(label(DateTime(2030, 6, 14, 10), es), 'Ayer');
    });

    test('is translated to French', () {
      final fr = AppLocalizationsFr();
      expect(label(now, fr), "À l'instant");
      expect(
        label(now.subtract(const Duration(minutes: 5)), fr),
        'il y a 5 min',
      );
      expect(label(DateTime(2030, 6, 15, 8), fr), 'il y a 4 h');
      expect(label(DateTime(2030, 6, 14, 10), fr), 'Hier');
    });
  });

  group('AvatarImage.resolveUrl', () {
    test('a full URL is used as it is', () {
      expect(
        AvatarImage.resolveUrl('https://example.com/a.jpg'),
        'https://example.com/a.jpg',
      );
    });

    test('a cache-busting ?t= is removed', () {
      expect(
        AvatarImage.resolveUrl('https://example.com/a.jpg?t=123'),
        'https://example.com/a.jpg',
      );
    });

    test('a cache-busting &t= is removed but other parameters stay', () {
      expect(
        AvatarImage.resolveUrl('https://example.com/a.jpg?w=40&t=123'),
        'https://example.com/a.jpg?w=40',
      );
    });

    test('surrounding spaces are ignored', () {
      expect(
        AvatarImage.resolveUrl('  https://example.com/a.jpg  '),
        'https://example.com/a.jpg',
      );
    });
  });
}
