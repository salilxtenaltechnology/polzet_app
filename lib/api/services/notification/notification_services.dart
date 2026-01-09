import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background message: ${message.messageId}");
  debugPrint("Title: ${message.notification?.title}");
  debugPrint("Body: ${message.notification?.body}");
  debugPrint("Data: ${message.data}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  // Callbacks for navigation
  Function(RemoteMessage)? onMessageTap;
  Function(RemoteMessage)? onBackgroundMessageTap;

  Future<void> initialize() async {
    try {
      // Request permission for iOS and Android 13+
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted provisional permission');
      } else {
        debugPrint('User declined or has not accepted permission');
      }

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // Get and print FCM token
      String? token = await _fcm.getToken();
      debugPrint("FCM Token: $token");
      
      // Save token to your backend here
      if (token != null) {
        await _saveTokenToBackend(token);
      }
      
      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint("FCM Token refreshed: $newToken");
        _saveTokenToBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a notification (terminated state)
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("App opened from notification: ${initialMessage.messageId}");
        _handleMessageOpenedApp(initialMessage);
      }

      debugPrint("NotificationService initialized successfully");
    } catch (e) {
      debugPrint("Error initializing NotificationService: $e");
    }
  }

  // Save token to your backend
  Future<void> _saveTokenToBackend(String token) async {
    try {
      // TODO: Send token to your backend API
      // Example:
      // final response = await http.post(
      //   Uri.parse('YOUR_API_URL/save-fcm-token'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json.encode({'fcm_token': token}),
      // );
      
      debugPrint("Token saved: $token");
    } catch (e) {
      debugPrint("Error saving token: $e");
    }
  }

  // Get current FCM token
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("Error getting token: $e");
      return null;
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint("Foreground message received");
    debugPrint("Title: ${message.notification?.title}");
    debugPrint("Body: ${message.notification?.body}");
    debugPrint("Data: ${message.data}");
    
    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  // Handle when user taps on notification (background/terminated state)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint("Notification opened: ${message.messageId}");
    debugPrint("Data: ${message.data}");
    
    // Call the callback if set
    if (onBackgroundMessageTap != null) {
      onBackgroundMessageTap!(message);
    }
    
    // Handle navigation based on notification data
    _handleNotificationNavigation(message);
  }

  // Handle when user taps on local notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint("Local notification tapped: ${response.payload}");
    
    // You can parse the payload and navigate accordingly
    // Example: navigatorKey.currentState?.pushNamed('/notification-detail');
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        details,
        payload: message.data.toString(),
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  // Handle navigation based on notification data
  void _handleNotificationNavigation(RemoteMessage message) {
    final data = message.data;
    
    // Example navigation logic based on notification type
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'chat':
          // Navigate to chat screen
          debugPrint("Navigate to chat: ${data['chat_id']}");
          break;
        case 'profile':
          // Navigate to profile screen
          debugPrint("Navigate to profile: ${data['user_id']}");
          break;
        case 'post':
          // Navigate to post detail
          debugPrint("Navigate to post: ${data['post_id']}");
          break;
        default:
          debugPrint("Unknown notification type: ${data['type']}");
      }
    }
  }

  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint("Subscribed to topic: $topic");
    } catch (e) {
      debugPrint("Error subscribing to topic: $e");
    }
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint("Unsubscribed from topic: $topic");
    } catch (e) {
      debugPrint("Error unsubscribing from topic: $e");
    }
  }

  // Delete FCM token (useful for logout)
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      debugPrint("FCM token deleted");
    } catch (e) {
      debugPrint("Error deleting token: $e");
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Request notification permissions again (useful for settings)
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}