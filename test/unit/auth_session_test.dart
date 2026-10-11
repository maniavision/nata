import 'package:carrywise_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient goTrue;

  setUp(() {
    client = MockSupabaseClient();
    goTrue = MockGoTrueClient();
    when(() => client.auth).thenReturn(goTrue);
  });

  group('AuthService.hasActiveSession', () {
    test('true while a session is kept on the device', () {
      when(() => goTrue.currentSession).thenReturn(MockSession());

      expect(AuthService(client: client).hasActiveSession, isTrue);
    });

    test('false when nobody is signed in', () {
      when(() => goTrue.currentSession).thenReturn(null);

      expect(AuthService(client: client).hasActiveSession, isFalse);
    });

    test('false again after logging out', () {
      final session = MockSession();
      when(() => goTrue.currentSession).thenReturn(session);
      final service = AuthService(client: client);
      expect(service.hasActiveSession, isTrue);

      when(() => goTrue.currentSession).thenReturn(null);

      expect(service.hasActiveSession, isFalse);
    });
  });
}
