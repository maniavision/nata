import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carrywise_app/services/auth_service.dart';

/// A mocktail mock of [AuthService].
/// Use in widget/unit tests to avoid hitting real Supabase.
class MockAuthService extends Mock implements AuthService {}

/// Fake [AuthResponse] for successful OTP verification tests.
AuthResponse fakeAuthResponse({bool withSession = true}) {
  // AuthResponse wraps a GoTrueResponse — we build the minimum needed.
  return AuthResponse(
    session: withSession
        ? Session(
            accessToken: 'fake-access-token',
            tokenType: 'bearer',
            user: User(
              id: 'test-user-id',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          )
        : null,
    user: withSession
        ? User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          )
        : null,
  );
}
