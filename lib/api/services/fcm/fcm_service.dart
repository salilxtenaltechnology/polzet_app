import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../data/token/shared_preferences.dart';
import '../../api_config.dart';

class FcmApiService {
  static String fcm = '${ApiConfig.baseUrl}/fcm';

  /*---- Register FCM token ----*/
  static Future<bool> registerFcmToken(String fcmToken, String platform) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('❌ FCM API: No access token available');
        return false;
      }

      final url = Uri.parse('$fcm/register-token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': fcmToken, 'platform': 'android'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint(
          '✅ FCM token registered successfully: ${responseData['data']}',
        );
        await SharedPrefService.saveFcmToken(fcmToken);

        return true;
      } else {
        debugPrint('❌ Failed to register FCM token: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      return false;
    }
  }

  /*---- Unregister FCM token (call on logout) ----*/
  static Future<bool> unregisterFcmToken() async {
    try {
      final accessToken = await SharedPrefService.getToken();
      final fcmToken = await SharedPrefService.getFcmToken();

      if (accessToken == null || fcmToken == null) {
        debugPrint('⚠️ FCM API: No token available to unregister');
        return false;
      }

      final url = Uri.parse('$fcm/unregister-token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token unregistered successfully');

        // Remove token from local storage
        await SharedPrefService.removeFcmToken();

        return true;
      } else {
        debugPrint('❌ Failed to unregister FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error unregistering FCM token: $e');
      return false;
    }
  }

  /*---- Update FCM token ----*/
  static Future<bool> updateFcmToken(
    String oldToken,
    String newToken,
    String platform,
  ) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null) {
        debugPrint('❌ FCM API: No access token available');
        return false;
      }

      final url = Uri.parse('$fcm/update-token');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'old_token': oldToken,
          'new_token': newToken,
          'platform': platform,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token updated successfully');

        // Update token in local storage
        await SharedPrefService.saveFcmToken(newToken);

        return true;
      } else {
        debugPrint('❌ Failed to update FCM token: ${response.statusCode}');
        return await registerFcmToken(newToken, platform);
      }
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
      return false;
    }
  }
}
