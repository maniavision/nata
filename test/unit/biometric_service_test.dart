import 'package:carrywise_app/services/biometric_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  late MockLocalAuth auth;
  late BiometricService service;

  setUp(() {
    auth = MockLocalAuth();
    service = BiometricService(auth: auth);
  });

  void device({
    bool supported = true,
    bool canCheck = true,
    List<BiometricType> enrolled = const [BiometricType.face],
  }) {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => supported);
    when(() => auth.canCheckBiometrics).thenAnswer((_) async => canCheck);
    when(() => auth.getAvailableBiometrics()).thenAnswer((_) async => enrolled);
  }

  void authenticateReturns(bool value) {
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenAnswer((_) async => value);
  }

  void authenticateThrows(Object error) {
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenThrow(error);
  }

  group('availability', () {
    test('available when supported and a face is set up', () async {
      device();

      expect(await service.availability(), BiometricAvailability.available);
      expect(await service.isAvailable(), isTrue);
    });

    test('a fingerprint counts as available too', () async {
      device(enrolled: [BiometricType.fingerprint]);

      expect(await service.availability(), BiometricAvailability.available);
    });

    test('unsupported when the device cannot do biometrics', () async {
      device(supported: false);

      expect(await service.availability(), BiometricAvailability.unsupported);
      expect(await service.isAvailable(), isFalse);
    });

    test('unsupported when there is no biometric hardware', () async {
      device(canCheck: false);

      expect(await service.availability(), BiometricAvailability.unsupported);
    });

    test(
      'not enrolled when nothing is set up in the device settings',
      () async {
        device(enrolled: []);

        expect(await service.availability(), BiometricAvailability.notEnrolled);
        expect(await service.isAvailable(), isFalse);
      },
    );

    test('a plugin error is treated as unsupported, never thrown', () async {
      when(
        () => auth.isDeviceSupported(),
      ).thenThrow(PlatformException(code: 'x'));

      expect(await service.availability(), BiometricAvailability.unsupported);
    });
  });

  group('authenticate', () {
    test('success when the face is recognised', () async {
      authenticateReturns(true);

      expect(await service.authenticate('Why'), BiometricResult.success);
    });

    test('failed when it is not recognised', () async {
      authenticateReturns(false);

      expect(await service.authenticate('Why'), BiometricResult.failed);
    });

    test(
      'shows the reason it was given, and allows Face / fingerprint only',
      () async {
        authenticateReturns(true);

        await service.authenticate('Confirm it is you');

        final captured = verify(
          () => auth.authenticate(
            localizedReason: captureAny(named: 'localizedReason'),
            biometricOnly: captureAny(named: 'biometricOnly'),
            persistAcrossBackgrounding: captureAny(
              named: 'persistAcrossBackgrounding',
            ),
          ),
        ).captured;
        expect(captured[0], 'Confirm it is you');
        expect(captured[1], isTrue); // no falling back to the passcode
      },
    );

    test('a plugin exception becomes a result, never an error', () async {
      authenticateThrows(
        const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
      );

      expect(await service.authenticate('Why'), BiometricResult.cancelled);
    });

    test('an unexpected error is a failure', () async {
      authenticateThrows(StateError('boom'));

      expect(await service.authenticate('Why'), BiometricResult.failed);
    });
  });

  group('how each plugin failure is described', () {
    BiometricResult of(LocalAuthExceptionCode c) =>
        BiometricService.resultForCode(c);

    test('closing the prompt is a cancel', () {
      expect(
        of(LocalAuthExceptionCode.userCanceled),
        BiometricResult.cancelled,
      );
      expect(
        of(LocalAuthExceptionCode.systemCanceled),
        BiometricResult.cancelled,
      );
      expect(of(LocalAuthExceptionCode.timeout), BiometricResult.cancelled);
    });

    test('nothing set up', () {
      expect(
        of(LocalAuthExceptionCode.noBiometricsEnrolled),
        BiometricResult.notEnrolled,
      );
      expect(
        of(LocalAuthExceptionCode.noCredentialsSet),
        BiometricResult.notEnrolled,
      );
    });

    test('no hardware or not reachable', () {
      expect(
        of(LocalAuthExceptionCode.noBiometricHardware),
        BiometricResult.notAvailable,
      );
      expect(
        of(LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable),
        BiometricResult.notAvailable,
      );
      expect(
        of(LocalAuthExceptionCode.uiUnavailable),
        BiometricResult.notAvailable,
      );
    });

    test('too many attempts', () {
      expect(
        of(LocalAuthExceptionCode.temporaryLockout),
        BiometricResult.lockedOut,
      );
      expect(
        of(LocalAuthExceptionCode.biometricLockout),
        BiometricResult.lockedOut,
      );
    });

    test('every code maps to something', () {
      for (final code in LocalAuthExceptionCode.values) {
        expect(of(code), isA<BiometricResult>(), reason: code.name);
      }
    });

    test('anything else is a plain failure', () {
      expect(of(LocalAuthExceptionCode.authInProgress), BiometricResult.failed);
    });
  });
}
