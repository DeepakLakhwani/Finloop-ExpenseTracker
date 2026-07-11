import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _passcodeKey = 'app_passcode';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTimeoutKey = 'biometric_timeout_seconds';
  static const String _lastBiometricAuthKey = 'last_biometric_auth_ms';
  static const String _lastAppClosedKey = 'last_app_closed_ms';

  String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    return sha256.convert(bytes).toString();
  }

  // Check if passcode is set
  Future<bool> hasPasscode() async {
    final code = await _storage.read(key: _passcodeKey);
    return code != null && (code.length == 4 || code.length == 64);
  }

  // Save/Set passcode
  Future<void> setPasscode(String passcode) async {
    final hashed = _hashPasscode(passcode);
    await _storage.write(key: _passcodeKey, value: hashed);
  }

  // Verify passcode
  Future<bool> verifyPasscode(String passcode) async {
    final savedCode = await _storage.read(key: _passcodeKey);
    if (savedCode == null) return false;

    // Check if saved passcode is legacy (length of 4, pure digits)
    if (savedCode.length == 4) {
      if (savedCode == passcode) {
        // Automatically migrate to hashed passcode
        await setPasscode(passcode);
        return true;
      }
      return false;
    }

    return savedCode == _hashPasscode(passcode);
  }

  // Clear/Turn off passcode
  Future<void> clearPasscode() async {
    await _storage.delete(key: _passcodeKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _biometricTimeoutKey);
    await _storage.delete(key: _lastBiometricAuthKey);
    await _storage.delete(key: _lastAppClosedKey);
  }

  // Check if biometrics enabled
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // Set biometric toggle
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  // ---------------------------------------------------------------------------
  // Biometric timeout / request interval
  // ---------------------------------------------------------------------------

  /// Get the biometric timeout in seconds.
  /// 0 = Immediately (every time), 60, 300, 3600.
  /// Defaults to 0 (immediately) if not set.
  Future<int> getBiometricTimeout() async {
    final value = await _storage.read(key: _biometricTimeoutKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  /// Set the biometric timeout in seconds.
  Future<void> setBiometricTimeout(int seconds) async {
    await _storage.write(key: _biometricTimeoutKey, value: seconds.toString());
  }

  /// Record a successful biometric authentication timestamp.
  Future<void> recordBiometricAuth() async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _lastBiometricAuthKey, value: now);
  }

  /// Check whether biometric authentication should be requested.
  /// Returns true if timeout has expired (or no previous auth recorded).
  Future<bool> shouldRequestBiometric() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return false;

    final timeoutSeconds = await getBiometricTimeout();
    // 0 means "Immediately" — always request
    if (timeoutSeconds == 0) return true;

    final lastAuthStr = await _storage.read(key: _lastBiometricAuthKey);
    if (lastAuthStr == null) return true; // Never authenticated before

    final lastAuthMs = int.tryParse(lastAuthStr) ?? 0;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastAuthMs;
    final timeoutMs = timeoutSeconds * 1000;

    return elapsedMs >= timeoutMs;
  }

  // ---------------------------------------------------------------------------
  // App Closing / Grace Period Timeouts (Passcode Bypass)
  // ---------------------------------------------------------------------------

  /// Record when the app is minimized / closed.
  Future<void> recordAppClosedTime() async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _lastAppClosedKey, value: now);
  }

  /// Clear the app closed timestamp on successful unlock.
  Future<void> clearAppClosedTime() async {
    await _storage.delete(key: _lastAppClosedKey);
  }

  /// Checks if the app should request passcode/biometric authentication
  /// based on the elapsed time since the app was closed.
  Future<bool> shouldShowLockScreen() async {
    final hasCode = await hasPasscode();
    if (!hasCode) return false;

    final lastClosedStr = await _storage.read(key: _lastAppClosedKey);
    if (lastClosedStr == null) return true; // Cold start / first launch

    final lastClosedMs = int.tryParse(lastClosedStr) ?? 0;
    final timeoutSeconds = await getBiometricTimeout();
    if (timeoutSeconds == 0) return true; // Immediately

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastClosedMs;
    final timeoutMs = timeoutSeconds * 1000;

    return elapsedMs >= timeoutMs;
  }
}
