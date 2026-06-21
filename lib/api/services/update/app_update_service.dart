import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../../../widgets/dialog/app_update_dialog.dart';
import '../../../widgets/dialog/diolog_animation.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Set to true to test the custom App Side update dialog during development.
  static const bool forceTestingUpdateDialog = false;

  static const String versionCheckUrl = '';

  /// Check for update. Queries custom App Side check.
  Future<void> checkForUpdate(BuildContext context) async {
    if (kDebugMode && forceTestingUpdateDialog) {
      debugPrint(
        '🚨 AppUpdateService: Testing flag active. Triggering custom dialog.',
      );
      PackageInfo.fromPlatform().then((packageInfo) {
        if (!context.mounted) return;
        _showAppSideUpdateDialog(
          context,
          playStoreUrl:
              'https://play.google.com/store/apps/details?id=com.polzet_app',
          version: packageInfo.version,
          releaseNotes: const [
            'Drag & drop options before submitting polls',
            'Instant & easy poll results at a glance',
            'Real-time poll result notifications',
          ],
        );
      });
      return;
    }

    // App Side Update check (runs on both Android and iOS)
    await _checkAppSideUpdate(context);
  }

  /// App Side Check - Queries backend/custom config to compare versions and show dialog
  Future<void> _checkAppSideUpdate(BuildContext context) async {
    if (versionCheckUrl.isEmpty) {
      debugPrint(
        'ℹ️ AppUpdateService: versionCheckUrl is empty. Skipping App Side version check.',
      );
      return;
    }

    try {
      debugPrint(
        '🔄 AppUpdateService: Checking App Side updates via static JSON...',
      );
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String localVersion = packageInfo.version;

      // Make HTTP request to get version info from static JSON
      final dio = Dio();
      final response = await dio.get(
        versionCheckUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        final String latestVersion = data['latest_version'] ?? '';
        final String playStoreUrl =
            data['play_store_url'] ??
            'https://play.google.com/store/apps/details?id=com.polzet_app';
        final String appStoreUrl =
            data['app_store_url'] ?? 'https://apps.apple.com';
        final List<String> releaseNotes = List<String>.from(
          data['release_notes'] ?? [],
        );

        final String targetUrl = Platform.isAndroid
            ? playStoreUrl
            : appStoreUrl;

        if (latestVersion.isNotEmpty) {
          final isUpdateAvailable = _isVersionNewer(
            localVersion,
            latestVersion,
          );
          if (isUpdateAvailable) {
            _showAppSideUpdateDialog(
              context,
              playStoreUrl: targetUrl,
              version: latestVersion,
              releaseNotes: releaseNotes,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ AppUpdateService: App Side check error: $e');
    }
  }

  /// Helper to compare semantic versions (e.g. "1.1.0" vs "1.2.0")
  bool _isVersionNewer(String current, String target) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final targetParts = target.split('.').map(int.parse).toList();

      final length = currentParts.length > targetParts.length
          ? currentParts.length
          : targetParts.length;
      for (var i = 0; i < length; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final targetPart = i < targetParts.length ? targetParts[i] : 0;

        if (targetPart > currentPart) return true;
        if (targetPart < currentPart) return false;
      }
    } catch (_) {
      // Return true if strings don't match and target is not empty
      return current != target && target.isNotEmpty;
    }
    return false;
  }

  /// Shows the custom AlertDialog
  void _showAppSideUpdateDialog(
    BuildContext context, {
    required String playStoreUrl,
    String version = '1.1.0',
    List<String> releaseNotes = const [],
  }) {
    if (!context.mounted) return;

    diologanimation(
      context,
      AppUpdateDialog(
        version: version,
        releaseNotes: releaseNotes,
        onUpdatePressed: () async {
          final uri = Uri.parse(playStoreUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            debugPrint('❌ AppUpdateService: Could not launch $playStoreUrl');
          }
        },
      ),
    );
  }
}
