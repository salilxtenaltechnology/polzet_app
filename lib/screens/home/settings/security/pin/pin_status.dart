// lib/screens/home/settings/security/pin/pin_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PinStatus {
  final bool isSet;
  final DateTime? lastChangeDate;
  final int attemptsCount;
  final int remainingAttempts;
  final bool isLocked;
  final DateTime? lockoutEndTime;

  PinStatus({
    required this.isSet,
    this.lastChangeDate,
    this.attemptsCount = 0,
    this.remainingAttempts = 3,
    this.isLocked = false,
    this.lockoutEndTime,
  });

  factory PinStatus.fromJson(Map<String, dynamic> json) {
    return PinStatus(
      isSet: json['isSet'] ?? false,
      lastChangeDate: json['lastChangeDate'] != null
          ? DateTime.parse(json['lastChangeDate'])
          : null,
      attemptsCount: json['attemptsCount'] ?? 0,
      remainingAttempts: json['remainingAttempts'] ?? 3,
      isLocked: json['isLocked'] ?? false,
      lockoutEndTime: json['lockoutEndTime'] != null
          ? DateTime.parse(json['lockoutEndTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSet': isSet,
      'lastChangeDate': lastChangeDate?.toIso8601String(),
      'attemptsCount': attemptsCount,
      'remainingAttempts': remainingAttempts,
      'isLocked': isLocked,
      'lockoutEndTime': lockoutEndTime?.toIso8601String(),
    };
  }
}

class PinAuthResult {
  final bool success;
  final String message;
  final bool isLocked;
  final int remainingAttempts;

  PinAuthResult({
    required this.success,
    required this.message,
    this.isLocked = false,
    this.remainingAttempts = 3,
  });
}

class PinService {
  static const String _pinKey = 'user_pin_hash';
  static const String _pinStatusKey = 'pin_status';
  static const String _pinSecurityEnabledKey = 'pin_security_enabled';
  static const int _maxAttempts = 3;
  static const int _lockoutDurationMinutes = 15;

  // Hash the PIN for secure storage
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Save PIN
  static Future<bool> savePin(String pin) async {
    try {
      if (pin.length != 4) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final hashedPin = _hashPin(pin);

      // Save hashed PIN
      await prefs.setString(_pinKey, hashedPin);

      // Update PIN status
      final status = PinStatus(
        isSet: true,
        lastChangeDate: DateTime.now(),
        attemptsCount: 0,
        remainingAttempts: _maxAttempts,
        isLocked: false,
      );

      await prefs.setString(_pinStatusKey, json.encode(status.toJson()));
      await prefs.setBool(_pinSecurityEnabledKey, true);

      return true;
    } catch (e) {
      debugPrint('Error saving PIN: $e');
      return false;
    }
  }

  // Verify PIN
  static Future<PinAuthResult> authenticateWithPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = await getPinStatus();

      // Check if account is locked
      if (status.isLocked && status.lockoutEndTime != null) {
        if (DateTime.now().isBefore(status.lockoutEndTime!)) {
          final remainingTime = status.lockoutEndTime!.difference(DateTime.now());
          return PinAuthResult(
            success: false,
            message: 'Account locked. Try again in ${remainingTime.inMinutes} minutes.',
            isLocked: true,
            remainingAttempts: 0,
          );
        } else {
          // Lockout period expired, reset attempts
          await _resetAttempts();
        }
      }

      final savedHashedPin = prefs.getString(_pinKey);
      if (savedHashedPin == null) {
        return PinAuthResult(
          success: false,
          message: 'No PIN set',
          remainingAttempts: _maxAttempts,
        );
      }

      final hashedInputPin = _hashPin(pin);

      if (hashedInputPin == savedHashedPin) {
        // Successful authentication - reset attempts
        await _resetAttempts();
        return PinAuthResult(
          success: true,
          message: 'Authentication successful',
          remainingAttempts: _maxAttempts,
        );
      } else {
        // Failed authentication - increment attempts
        final newAttemptsCount = status.attemptsCount + 1;
        final remainingAttempts = _maxAttempts - newAttemptsCount;

        if (newAttemptsCount >= _maxAttempts) {
          // Lock the account
          final lockoutEndTime = DateTime.now().add(
            const Duration(minutes: _lockoutDurationMinutes),
          );

          final updatedStatus = PinStatus(
            isSet: status.isSet,
            lastChangeDate: status.lastChangeDate,
            attemptsCount: newAttemptsCount,
            remainingAttempts: 0,
            isLocked: true,
            lockoutEndTime: lockoutEndTime,
          );

          await prefs.setString(_pinStatusKey, json.encode(updatedStatus.toJson()));

          return PinAuthResult(
            success: false,
            message: 'Too many failed attempts. Account locked for $_lockoutDurationMinutes minutes.',
            isLocked: true,
            remainingAttempts: 0,
          );
        } else {
          // Update attempts count
          final updatedStatus = PinStatus(
            isSet: status.isSet,
            lastChangeDate: status.lastChangeDate,
            attemptsCount: newAttemptsCount,
            remainingAttempts: remainingAttempts,
            isLocked: false,
          );

          await prefs.setString(_pinStatusKey, json.encode(updatedStatus.toJson()));

          return PinAuthResult(
            success: false,
            message: 'Incorrect PIN. $remainingAttempts attempts remaining.',
            remainingAttempts: remainingAttempts,
          );
        }
      }
    } catch (e) {
      debugPrint('Error authenticating PIN: $e');
      return PinAuthResult(
        success: false,
        message: 'Authentication error',
        remainingAttempts: _maxAttempts,
      );
    }
  }

  // Reset failed attempts
  static Future<void> _resetAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = await getPinStatus();

      final updatedStatus = PinStatus(
        isSet: status.isSet,
        lastChangeDate: status.lastChangeDate,
        attemptsCount: 0,
        remainingAttempts: _maxAttempts,
        isLocked: false,
        lockoutEndTime: null,
      );

      await prefs.setString(_pinStatusKey, json.encode(updatedStatus.toJson()));
    } catch (e) {
      debugPrint('Error resetting attempts: $e');
    }
  }

  // Get PIN status
  static Future<PinStatus> getPinStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusJson = prefs.getString(_pinStatusKey);

      if (statusJson != null) {
        final statusMap = json.decode(statusJson) as Map<String, dynamic>;
        return PinStatus.fromJson(statusMap);
      }

      return PinStatus(
        isSet: await isPinSet(),
        remainingAttempts: _maxAttempts,
      );
    } catch (e) {
      debugPrint('Error getting PIN status: $e');
      return PinStatus(
        isSet: false,
        remainingAttempts: _maxAttempts,
      );
    }
  }

  // Check if PIN is set
  static Future<bool> isPinSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pinKey);
    } catch (e) {
      debugPrint('Error checking if PIN is set: $e');
      return false;
    }
  }

  // Check if PIN security is enabled
  static Future<bool> isPinSecurityEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pinSecurityEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error checking PIN security status: $e');
      return false;
    }
  }

  // Set PIN security enabled/disabled
  static Future<void> setPinSecurityEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pinSecurityEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error setting PIN security status: $e');
    }
  }

  // Clear saved PIN
  static Future<void> clearSavedPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.remove(_pinStatusKey);
      await prefs.remove(_pinSecurityEnabledKey);
    } catch (e) {
      debugPrint('Error clearing PIN: $e');
    }
  }

  // Check PIN strength
  static String getPinStrength(String pin) {
    if (pin.length < 4) {
      return 'Too short';
    }

    // Check for sequential numbers (1234, 4321, etc.)
    bool isSequential = true;
    for (int i = 0; i < pin.length - 1; i++) {
      int current = int.parse(pin[i]);
      int next = int.parse(pin[i + 1]);
      if ((next - current).abs() != 1) {
        isSequential = false;
        break;
      }
    }

    if (isSequential) {
      return 'Avoid sequential numbers';
    }

    // Check for repeated numbers (1111, 2222, etc.)
    if (pin.split('').toSet().length == 1) {
      return 'Avoid repeated numbers';
    }

    // Check for common weak PINs
    final weakPins = ['1234', '4321', '0000', '1111', '2222', '3333', '4444', 
                      '5555', '6666', '7777', '8888', '9999', '1212', '2323'];
    if (weakPins.contains(pin)) {
      return 'Too weak';
    }

    return 'Strong';
  }

  // Change PIN (requires old PIN verification first)
  static Future<bool> changePin(String oldPin, String newPin) async {
    try {
      // Verify old PIN
      final authResult = await authenticateWithPin(oldPin);
      if (!authResult.success) {
        return false;
      }

      // Save new PIN
      return await savePin(newPin);
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      return false;
    }
  }
}