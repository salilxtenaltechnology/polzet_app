// lib/api/services/fcm/fcm_registration_helper.dart

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../data/token/shared_preferences.dart';
import '../notification/notification_services.dart';
import 'fcm_service.dart';

/// Helper class to manage FCM token registration after login
class FCMRegistrationHelper {
  
  /// Call this ONLY after successful login
  static Future<void> registerFCMTokenAfterLogin() async {
    try {
      // Get current FCM token
      final fcmToken = await NotificationService().getFCMToken();
      
      if (fcmToken == null) {
        debugPrint('⚠️ FCM token not available');
        return;
      }

      // Check if already registered
      final savedToken = await SharedPrefService.getFcmToken();
      
      // Determine platform
      String platform = 'unknown';
      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      }

      // Register or update token
      if (savedToken == null) {
        // First time registration
        debugPrint('🔄 Registering FCM token for first time...');
        final success = await FcmApiService.registerFcmToken(fcmToken, platform);
        
        if (success) {
          debugPrint('✅ FCM token registered successfully');
        } else {
          debugPrint('❌ FCM token registration failed');
        }
      } else if (savedToken != fcmToken) {
        // Token changed - update it
        debugPrint('🔄 FCM token changed, updating...');
        await FcmApiService.updateFcmToken(savedToken, fcmToken, platform);
      } else {
        debugPrint('ℹ️ FCM token already registered and up to date');
      }
    } catch (e) {
      debugPrint('❌ Error in FCM token registration: $e');
    }
  }

  /// Setup token refresh listener (call once in main.dart)
  static void setupTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint("🔄 FCM Token refreshed: $newToken");
      
      try {
        // Check if user is logged in
        final accessToken = await SharedPrefService.getAccessToken();
        if (accessToken == null) {
          // Not logged in - just save locally
          debugPrint('ℹ️ User not logged in, saving token locally only');
          await SharedPrefService.saveFcmToken(newToken);
          return;
        }

        // User is logged in - update backend
        final oldToken = await SharedPrefService.getFcmToken();
        String platform = 'unknown';
        if (Platform.isAndroid) {
          platform = 'android';
        } else if (Platform.isIOS) {
          platform = 'ios';
        }

        if (oldToken != null && oldToken != newToken) {
          final success = await FcmApiService.updateFcmToken(
            oldToken, 
            newToken, 
            platform,
          );
          
          if (!success) {
            // Fallback: try to register as new token
            await FcmApiService.registerFcmToken(newToken, platform);
          }
        } else {
          // No old token found - register new
          await FcmApiService.registerFcmToken(newToken, platform);
        }
      } catch (e) {
        debugPrint('❌ Error handling token refresh: $e');
        // At minimum, save locally
        await SharedPrefService.saveFcmToken(newToken);
      }
    });
  }
}