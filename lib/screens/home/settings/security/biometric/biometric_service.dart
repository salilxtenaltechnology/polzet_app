// lib/services/biometric_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // SharedPreferences keys
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _fingerprintKey = 'fingerprint_enabled';

  // Check if device supports biometric authentication
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate with biometrics
  static Future<bool> authenticateWithBiometrics({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'No thanks',
          ),
        ],
        biometricOnly: true,
      );
      return isAuthenticated;
    } on PlatformException catch (e) {
      print('Biometric authentication error: ${e.message}');
      return false;
    }
  }

  // Save security preferences
  static Future<void> saveBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<void> saveFingerprintEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fingerprintKey, enabled);
  }

  // Get security preferences
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<bool> isFingerprintEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fingerprintKey) ?? false;
  }

  // Check if any biometric method is enabled
  static Future<bool> isAnyBiometricMethodEnabled() async {
    final fingerprint = await isFingerprintEnabled();
    return fingerprint;
  }

  // Get appropriate biometric message based on available types
  static Future<String> getBiometricMessage() async {
    final availableBiometrics = await getAvailableBiometrics();

    if (availableBiometrics.contains(BiometricType.face)) {
      return 'Authenticate using Face ID';
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Authenticate using fingerprint';
    } else if (availableBiometrics.contains(BiometricType.iris)) {
      return 'Authenticate using iris';
    } else {
      return 'Authenticate using biometric';
    }
  }
}
