/// Unit tests for the friendly error message mapping in
/// LoginScreen and SignUpScreen._friendlyError().
library;

import 'package:flutter_test/flutter_test.dart';

// Mirrors _friendlyError() from both screens.
String friendlyError(String raw) {
  if (raw.contains('rate limit') || raw.contains('too many')) {
    return 'Too many requests. Please wait a moment and try again.';
  }
  if (raw.contains('invalid') || raw.contains('phone')) {
    return 'Invalid phone number. Please check and try again.';
  }
  return 'Something went wrong. Please try again.';
}

// Mirrors _friendlyError() from OtpScreen.
String otpFriendlyError(String raw) {
  if (raw.contains('Token has expired') || raw.contains('expired')) {
    return 'Code expired. Please request a new one.';
  }
  if (raw.contains('Invalid token') || raw.contains('invalid')) {
    return 'Incorrect code. Please try again.';
  }
  if (raw.contains('rate limit') || raw.contains('too many')) {
    return 'Too many attempts. Please wait before retrying.';
  }
  return 'Something went wrong. Please try again.';
}

void main() {
  group('SignUp/Login friendly error mapping', () {
    test('rate limit message', () {
      expect(
        friendlyError('AuthApiException: rate limit exceeded'),
        'Too many requests. Please wait a moment and try again.',
      );
    });

    test('too many requests message', () {
      expect(
        friendlyError('too many OTP requests'),
        'Too many requests. Please wait a moment and try again.',
      );
    });

    test('invalid phone message', () {
      expect(
        friendlyError('invalid phone number format'),
        'Invalid phone number. Please check and try again.',
      );
    });

    test('phone keyword triggers invalid message', () {
      expect(
        friendlyError('Error: phone not recognized'),
        'Invalid phone number. Please check and try again.',
      );
    });

    test('unknown error falls back to generic', () {
      expect(
        friendlyError('network timeout'),
        'Something went wrong. Please try again.',
      );
    });

    test('empty error falls back to generic', () {
      expect(
        friendlyError(''),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('OTP screen friendly error mapping', () {
    test('expired token message', () {
      expect(
        otpFriendlyError('Token has expired'),
        'Code expired. Please request a new one.',
      );
    });

    test('expired keyword', () {
      expect(
        otpFriendlyError('OTP expired after 10 minutes'),
        'Code expired. Please request a new one.',
      );
    });

    test('invalid token message', () {
      expect(
        otpFriendlyError('Invalid token provided'),
        'Incorrect code. Please try again.',
      );
    });

    test('invalid keyword', () {
      expect(
        otpFriendlyError('invalid OTP'),
        'Incorrect code. Please try again.',
      );
    });

    test('rate limit in OTP context', () {
      expect(
        otpFriendlyError('rate limit reached'),
        'Too many attempts. Please wait before retrying.',
      );
    });

    test('unknown OTP error', () {
      expect(
        otpFriendlyError('connection refused'),
        'Something went wrong. Please try again.',
      );
    });
  });
}
