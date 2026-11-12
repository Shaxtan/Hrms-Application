import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// Result of a fingerprint / face check.
class BiometricResult {
  final bool ok;

  /// Message to show the user. Null when they simply cancelled the prompt.
  final String? error;

  const BiometricResult(this.ok, [this.error]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BIOMETRIC SERVICE — fingerprint / face app lock (Android only)
//
// Uses the phone's own system prompt (Android BiometricPrompt). Fingerprint
// works on every phone with a sensor. Face works only on phones whose face
// unlock Android rates as secure; on others the prompt offers fingerprint.
// The phone's PIN / pattern / password is always offered as a backup.
// ═══════════════════════════════════════════════════════════════════════════════
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  /// Secure-storage key for the Profile on/off switch. Logout calls
  /// deleteAll(), so the lock is switched off again after a sign-out.
  static const _enabledKey = 'app_lock_enabled';

  /// True while the system prompt is on screen. The app briefly goes to the
  /// background when the phone's PIN screen opens — this flag stops that
  /// from triggering a second lock.
  static bool isAuthenticating = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether this phone can lock the app (Android with a screen lock or
  /// biometrics). Always false on web / Chrome.
  static Future<bool> isAvailable() async {
    if (!_isAndroid) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Whether the user turned the lock on in Profile.
  static Future<bool> isEnabled() async =>
      (await _storage.read(key: _enabledKey)) == 'true';

  static Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');

  /// Shows the system fingerprint / face prompt.
  static Future<BiometricResult> authenticate({required String reason}) async {
    if (!_isAndroid) {
      return const BiometricResult(
          false, 'Fingerprint / face unlock works on the Android app only.');
    }
    if (isAuthenticating) return const BiometricResult(false);

    isAuthenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow the phone PIN / pattern as a backup
          stickyAuth: true, // keep the prompt if the app is briefly hidden
          useErrorDialogs: false, // we show our own messages instead
        ),
      );
      return BiometricResult(ok);
    } on PlatformException catch (e) {
      return BiometricResult(false, _message(e.code));
    } catch (_) {
      return const BiometricResult(false, 'Could not verify. Please try again.');
    } finally {
      isAuthenticating = false;
    }
  }

  static String _message(String code) {
    switch (code) {
      case auth_error.notEnrolled:
        return 'No fingerprint or face is set up on this phone. '
            'Add one in phone Settings → Security.';
      case auth_error.passcodeNotSet:
        return 'Set a screen lock (PIN, pattern or password) in phone '
            'Settings first.';
      case auth_error.lockedOut:
        return 'Too many attempts. Wait 30 seconds and try again.';
      case auth_error.permanentlyLockedOut:
        return 'Fingerprint is locked. Unlock your phone with its PIN, '
            'then try again.';
      case auth_error.notAvailable:
        return 'Fingerprint / face unlock is not available on this phone.';
      default:
        return 'Could not verify. Please try again.';
    }
  }
}