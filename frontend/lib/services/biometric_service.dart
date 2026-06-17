import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  // Singleton pattern
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  bool _isAuthenticating = false;

  // Check if biometrics is supported and available
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  // Check if any biometrics are enrolled
  Future<bool> hasBiometricsEnrolled() async {
    try {
      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking enrolled biometrics: $e');
      return false;
    }
  }

  // Authenticate user
  Future<bool> authenticate() async {
    if (_isAuthenticating) {
      debugPrint('Biometric authentication is already in progress.');
      return false;
    }
    _isAuthenticating = true;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to access Finloop',
        biometricOnly: true,
      );
      return authenticated;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  // Stop active authentication
  Future<bool> stopAuthentication() async {
    try {
      final stopped = await _auth.stopAuthentication();
      if (stopped) {
        _isAuthenticating = false;
      }
      return stopped;
    } catch (e) {
      debugPrint('Error stopping biometric auth: $e');
      _isAuthenticating = false;
      return false;
    }
  }

  // Save biometric preference
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  // Get biometric preference
  Future<bool> isBiometricEnabled() async {
    try {
      String? value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error reading biometric preference: $e');
      return false;
    }
  }

  // Clear biometric preference
  Future<void> clearBiometricPreference() async {
    try {
      await _storage.delete(key: _biometricEnabledKey);
    } catch (e) {
      debugPrint('Error clearing biometric preference: $e');
    }
  }
}
