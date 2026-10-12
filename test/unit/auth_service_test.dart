import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:carrywise_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  // Note: AuthService is a singleton and hardcoded to use Supabase.instance.client.
  // Testing it properly without dependency injection is hard in Flutter.
  // For now, we can only test logic that doesn't hit the network or
  // provide a way to inject a mock client.

  group('AuthService', () {
    test('can be instantiated with a mock client', () {
      final mockClient = MockSupabaseClient();
      final authService = AuthService(client: mockClient);
      expect(authService, isNotNull);
    });
  });

  sendOtpTests();
}

class _AuthApi extends Mock implements GoTrueClient {}

void sendOtpTests() {
  group('AuthService.sendOtp', () {
    late MockSupabaseClient client;
    late _AuthApi auth;
    late AuthService service;

    setUp(() {
      client = MockSupabaseClient();
      auth = _AuthApi();
      when(() => client.auth).thenReturn(auth);
      service = AuthService(client: client);
    });

    void answerWith(Object? error) {
      when(
        () => auth.signInWithOtp(
          phone: any(named: 'phone'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenAnswer((_) async {
        if (error != null) throw error;
      });
    }

    bool? asked() =>
        verify(
              () => auth.signInWithOtp(
                phone: '+242061234567',
                shouldCreateUser: captureAny(named: 'shouldCreateUser'),
              ),
            ).captured.single
            as bool?;

    test('signing up may create the account (the default)', () async {
      answerWith(null);

      await service.sendOtp('+242061234567');

      expect(asked(), isTrue);
    });

    test('logging in never creates an account', () async {
      answerWith(null);

      await service.sendOtp('+242061234567', createUser: false);

      expect(asked(), isFalse);
    });

    test('an unknown number is reported as "no account"', () async {
      answerWith(
        const AuthApiException(
          'Signups not allowed for otp',
          statusCode: '422',
          code: 'otp_disabled',
        ),
      );

      expect(
        service.sendOtp('+242061234567', createUser: false),
        throwsA(isA<AccountNotFoundException>()),
      );
    });

    test('recognised from the message alone as well', () async {
      answerWith(const AuthException('Signups not allowed for otp'));

      expect(
        service.sendOtp('+242061234567', createUser: false),
        throwsA(isA<AccountNotFoundException>()),
      );
    });

    test('other failures are passed on unchanged when logging in', () async {
      answerWith(
        const AuthApiException(
          'SMS rate limit exceeded',
          statusCode: '429',
          code: 'over_sms_send_rate_limit',
        ),
      );

      expect(
        service.sendOtp('+242061234567', createUser: false),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'over_sms_send_rate_limit',
          ),
        ),
      );
    });

    test('signing up never says "no account"', () async {
      answerWith(const AuthException('Signups not allowed for otp'));

      expect(service.sendOtp('+242061234567'), throwsA(isA<AuthException>()));
    });

    test('isAccountNotFound', () {
      bool f(String m, [String? c]) => AuthService.isAccountNotFound(
        AuthException(m, statusCode: '422', code: c),
      );
      expect(f('Signups not allowed for otp'), isTrue);
      expect(f('x', 'otp_disabled'), isTrue);
      expect(f('x', 'user_not_found'), isTrue);
      expect(f('Invalid phone'), isFalse);
      expect(f('rate limit', 'over_sms_send_rate_limit'), isFalse);
    });
  });
}
