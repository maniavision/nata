import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// What happened when the user was asked for Face ID / a fingerprint.
enum BiometricResult {
  /// The user was recognised.
  success,

  /// The user closed the prompt.
  cancelled,

  /// The face / fingerprint was not recognised.
  failed,

  /// The device has no biometric hardware, or the app cannot use it.
  notAvailable,

  /// The device supports it but nothing is set up in the device settings.
  notEnrolled,

  /// Too many wrong attempts; the device has locked biometrics for a while.
  lockedOut,
}

/// Whether this device can be unlocked with a face / fingerprint right now.
enum BiometricAvailability {
  /// Hardware present and at least one face / fingerprint set up.
  available,

  /// No biometric hardware (or the plugin cannot reach it).
  unsupported,

  /// Hardware present, but nothing is set up in the device settings.
  notEnrolled,
}

/// Face ID / Touch ID / fingerprint, through the `local_auth` plugin.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Can this device use a face / fingerprint right now, and if not, why?
  Future<BiometricAvailability> availability() async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return BiometricAvailability.unsupported;
      }
      if (!await _auth.canCheckBiometrics) {
        return BiometricAvailability.unsupported;
      }
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricAvailability.notEnrolled
          : BiometricAvailability.available;
    } catch (e) {
      debugPrint('[BiometricService] availability error: $e');
      return BiometricAvailability.unsupported;
    }
  }

  /// True if the device can check biometrics and the user has set one up.
  Future<bool> isAvailable() async =>
      await availability() == BiometricAvailability.available;

  /// Asks the user to prove who they are. [reason] is shown in the system
  /// prompt. Never throws: every outcome is a [BiometricResult].
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Face / fingerprint only: no falling back to the device passcode, so
        // this really is "Face ID".
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      debugPrint('[BiometricService] ${e.code.name}');
      return resultForCode(e.code);
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return BiometricResult.failed;
    }
  }

  /// How a failure reported by the plugin is described to the user.
  @visibleForTesting
  static BiometricResult resultForCode(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return BiometricResult.cancelled;
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricResult.notEnrolled;
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.uiUnavailable:
        return BiometricResult.notAvailable;
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricResult.lockedOut;
      default:
        return BiometricResult.failed;
    }
  }
}
