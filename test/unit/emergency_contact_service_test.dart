import 'dart:async';

import 'package:carrywise_app/services/emergency_contact_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSchema extends Mock implements SupabaseQuerySchema {}

class MockTable extends Mock implements SupabaseQueryBuilder {}

/// What `upsert` returns: awaiting it completes (or fails).
class FakeWrite extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeWrite(this.error);
  final Object? error;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    final f = error != null
        ? Future<dynamic>.error(error!)
        : Future<dynamic>.value(null);
    return f.then(onValue, onError: onError);
  }
}

/// What `select().eq().maybeSingle()` returns.
class FakeRead extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  FakeRead(this.row);
  final Map<String, dynamic>? row;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    calls.add('eq:$column=$value');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() => _Single(row);
}

class _Single extends Fake implements PostgrestTransformBuilder<PostgrestMap?> {
  _Single(this.row);
  final Map<String, dynamic>? row;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) => Future<PostgrestMap?>.value(row).then(onValue, onError: onError);
}

void main() {
  late MockClient client;
  late MockAuth auth;
  late MockTable table;
  late EmergencyContactService service;

  const contact = EmergencyContact(
    fullName: '  Jane Doe ',
    phone: '+447700900123',
    relationship: EmergencyRelationship.partner,
  );

  setUp(() {
    client = MockClient();
    auth = MockAuth();
    table = MockTable();
    final schema = MockSchema();
    final user = MockUser();
    when(() => user.id).thenReturn('user-1');
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.auth).thenReturn(auth);
    when(() => client.schema('nata')).thenReturn(schema);
    when(() => schema.from('emergency_contacts')).thenAnswer((_) => table);
    service = EmergencyContactService(client: client);
  });

  group('EmergencyRelationship', () {
    test('is stored as a lower-case word', () {
      expect(EmergencyRelationship.values.map((r) => r.dbValue), [
        'friend',
        'relative',
        'partner',
        'colleague',
      ]);
    });

    test('is read back from the stored word', () {
      expect(
        EmergencyRelationship.fromDb('partner'),
        EmergencyRelationship.partner,
      );
      expect(EmergencyRelationship.fromDb('boss'), isNull);
      expect(EmergencyRelationship.fromDb(null), isNull);
    });
  });

  group('save', () {
    void upsertOk([Object? error]) {
      when(
        () => table.upsert(any(), onConflict: any(named: 'onConflict')),
      ).thenAnswer((_) => FakeWrite(error));
    }

    test('stores the contact for the signed-in user, one per user', () async {
      upsertOk();

      await service.save(contact);

      final v = verify(
        () => table.upsert(
          captureAny(),
          onConflict: captureAny(named: 'onConflict'),
        ),
      ).captured;
      expect(v[0], {
        'user_id': 'user-1',
        'full_name': 'Jane Doe',
        'phone': '+447700900123',
        'relationship': 'partner',
      });
      expect(v[1], 'user_id');
    });

    test('a database failure is passed on', () async {
      upsertOk(Exception('network'));

      expect(service.save(contact), throwsException);
    });

    test('needs a signed-in user', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(service.save(contact), throwsException);
      verifyNever(
        () => table.upsert(any(), onConflict: any(named: 'onConflict')),
      );
    });
  });

  group('get', () {
    test('reads the saved contact', () async {
      final q = FakeRead({
        'full_name': 'Jane Doe',
        'phone': '+447700900123',
        'relationship': 'relative',
      });
      when(() => table.select(any())).thenAnswer((_) => q);

      final c = await service.get();

      expect(c?.fullName, 'Jane Doe');
      expect(c?.phone, '+447700900123');
      expect(c?.relationship, EmergencyRelationship.relative);
      expect(q.calls, ['eq:user_id=user-1']);
    });

    test('none saved is null', () async {
      when(() => table.select(any())).thenAnswer((_) => FakeRead(null));

      expect(await service.get(), isNull);
    });

    test('a row with an unknown relationship is not trusted', () async {
      when(() => table.select(any())).thenAnswer(
        (_) => FakeRead({
          'full_name': 'A B',
          'phone': '+447700900123',
          'relationship': 'boss',
        }),
      );

      expect(await service.get(), isNull);
    });
  });
}
