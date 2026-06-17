import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _passcodeKey = 'app_passcode';
  static const String _biometricEnabledKey = 'biometric_enabled';

  // Check if passcode is set
  Future<bool> hasPasscode() async {
    final code = await _storage.read(key: _passcodeKey);
    return code != null && code.length == 4;
  }

  // Save/Set passcode
  Future<void> setPasscode(String passcode) async {
    await _storage.write(key: _passcodeKey, value: passcode);
  }

  // Verify passcode
  Future<bool> verifyPasscode(String passcode) async {
    final savedCode = await _storage.read(key: _passcodeKey);
    return savedCode == passcode;
  }

  // Clear/Turn off passcode
  Future<void> clearPasscode() async {
    await _storage.delete(key: _passcodeKey);
    await _storage.delete(key: _biometricEnabledKey);
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
}
