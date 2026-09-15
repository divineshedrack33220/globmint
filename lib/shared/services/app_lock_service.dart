import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps the platform biometric APIs (fingerprint / Face ID) plus the OS
/// device-PIN fallback that `local_auth` exposes.
///
/// Deliberately thin and dependency-light so the unlock flow can be tested by
/// subclassing and stubbing [isBiometricAvailable] / [authenticate].
class AppLockService {
  AppLockService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  /// True when the device supports biometric auth (hardware + a way to enroll)
  /// at all. Always false on web, where there is no native biometric prompt.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck && supported;
    } on Exception {
      // Plugin unavailable (e.g. unsupported host): no biometrics to offer.
      return false;
    }
  }

  /// Prompts for biometrics; when the OS allows, the user may fall back to
  /// their device PIN/passcode instead. Returns true only after the OS
  /// authenticated the user. Never throws for a declined attempt.
  Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        // Allow the OS device-PIN/passcode fallback so a user with a failing
        // sensor is never locked out of their own device.
        biometricOnly: false,
        // Keep the prompt alive if the app is backgrounded mid-dialog.
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}