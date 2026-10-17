import 'package:flutter/foundation.dart';

/// Debug-only logger for phone authentication and OTP verification flows.
///
/// Ensures compliance with security requirements:
/// - Generates unique attempt IDs
/// - Never logs full phone numbers, OTP codes, or auth tokens
/// - Logs timestamps, attempt IDs, sources, and event names
class PhoneVerifyLogger {
  PhoneVerifyLogger._();

  static int _attemptSequence = 0;

  /// Generates a unique attempt ID for correlating actions across callbacks.
  static String generateAttemptId([String prefix = 'att']) {
    _attemptSequence++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_${timestamp}_$_attemptSequence';
  }

  /// Masks phone numbers so only the dial prefix and last 3 digits are visible.
  /// Never returns or logs full phone numbers.
  static String maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'EMPTY';
    final clean = phone.trim();
    if (clean.length <= 4) return '***';
    final prefixLength = clean.startsWith('+') ? 3 : 2;
    final prefix = clean.substring(0, prefixLength.clamp(0, clean.length));
    final suffix = clean.substring(clean.length - 3);
    final middleLength = clean.length - prefix.length - suffix.length;
    final maskedMiddle = '*' * (middleLength > 0 ? middleLength : 3);
    return '$prefix$maskedMiddle$suffix';
  }

  /// Logs a phone verification event with structured formatting.
  static void log({
    required String attemptId,
    required String caller,
    required String event,
    String? phone,
    String? details,
  }) {
    if (kReleaseMode) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';

    final buffer = StringBuffer();
    buffer.write('[PHONE_VERIFY][$timeStr][$attemptId][$caller] $event');

    if (phone != null && phone.isNotEmpty) {
      buffer.write(' | phone: ${maskPhone(phone)}');
    }
    if (details != null && details.isNotEmpty) {
      buffer.write(' | $details');
    }

    debugPrint(buffer.toString());
  }
}
