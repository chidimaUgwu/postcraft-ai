// lib/services/app_lock_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Result of an App Lock authentication attempt. When [ok] is false, [error]
/// holds a human-readable reason the caller can show in a snackbar.
class AppLockResult {
  final bool ok;
  final String? error;
  const AppLockResult.success()
      : ok = true,
        error = null;
  const AppLockResult.failure(this.error) : ok = false;
}

/// Wraps biometric / device-credential authentication. The user\'s phone
/// already stores their fingerprint / Face ID / PIN — we just ask the OS
/// to verify the person holding the phone is the owner.
class AppLockService {
  static final _auth = LocalAuthentication();

  /// Can the device offer biometrics OR a device credential (PIN/pattern)?
  /// Returns a reason string if NOT available, null if available.
  static Future<String?> unavailableReason() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return 'This device does not support biometric or screen-lock auth. '
            'Set up a screen-lock PIN / pattern / fingerprint in system Settings first.';
      }
      // Device credential fallback (PIN/pattern) covers phones without any
      // enrolled biometric, so having no biometric is NOT a hard block.
      return null;
    } on PlatformException catch (e) {
      return 'App Lock unavailable: ${e.message ?? e.code}';
    }
  }

  /// Prompts the OS-native auth sheet. Returns an [AppLockResult] with a
  /// specific error message when it fails so callers can surface it.
  static Future<AppLockResult> authenticate({
    String reason = 'Unlock PostCraft AI',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok
          ? const AppLockResult.success()
          : const AppLockResult.failure(
              'Authentication cancelled or not recognised.');
    } on PlatformException catch (e) {
      // Map the most common failure codes to friendly messages.
      switch (e.code) {
        case 'NotAvailable':
          return const AppLockResult.failure(
              'No biometric or screen-lock set up on this device.');
        case 'NotEnrolled':
          return const AppLockResult.failure(
              'No fingerprint / Face ID enrolled. Enroll one in system Settings first.');
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return const AppLockResult.failure(
              'Too many failed attempts. Wait a bit and try again.');
        case 'PasscodeNotSet':
          return const AppLockResult.failure(
              'Set up a screen-lock PIN / pattern first.');
        case 'no_fragment_activity':
          return const AppLockResult.failure(
              'App setup error — MainActivity must extend FlutterFragmentActivity.');
        default:
          return AppLockResult.failure(
              e.message ?? 'Biometric auth failed (${e.code}).');
      }
    }
  }
}
