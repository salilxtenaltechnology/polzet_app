import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../../../data/token/shared_preferences.dart';
import '../fcm/fcm_service.dart';

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  // Firebase & Local Notifications
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isConnecting = false;
  bool _shouldStayConnected = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  // Deduplication
  final Set<String> _processedNotificationIds = {};
  Timer? _cleanupTimer;

  // Callbacks
  Function(NotificationPayload)? onNotificationReceived;
  Function(NotificationPayload)? onFCMMessageTap;

  bool _isInitialized = false;

  // ========== INITIALIZATION ==========
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ NotificationService already initialized');
      return;
    }

    await _initializeLocalNotifications();
    await _initializeFCM();
    _startCleanupTimer();
    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    debugPrint('📲 Initializing local notifications...');

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
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Android notification channel created');
    }
  }

  Future<void> _initializeFCM() async {
    try {
      debugPrint('🚀 Initializing FCM...');

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('📱 FCM Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('❌ FCM: User declined permission');
        return;
      }

      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint("📱 FCM Token: ${token.substring(0, 30)}...");
        await SharedPrefService.saveFcmToken(token);
      }

      // Token refresh listener
      _fcm.onTokenRefresh.listen((newToken) async {
        debugPrint("🔄 FCM Token refreshed: ${newToken.substring(0, 30)}...");
        final oldToken = await SharedPrefService.getFcmToken();
        String platform = Platform.isAndroid ? 'android' : 'ios';

        if (oldToken != null && oldToken != newToken) {
          await FcmApiService.updateFcmToken(oldToken, newToken, platform);
        } else {
          await SharedPrefService.saveFcmToken(newToken);
        }
      });

      await _setupMessageHandlers();

      debugPrint("✅ FCM initialized");
    } catch (e) {
      debugPrint("❌ FCM initialization error: $e");
    }
  }

  Future<void> _setupMessageHandlers() async {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 FOREGROUND MESSAGE');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      _handleForegroundMessage(message);
    });

    // Background tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 NOTIFICATION OPENED APP (from background)');
      debugPrint('Data: ${message.data}');

      _handleMessageTap(message);
    });

    // Terminated tap (app killed)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 APP OPENED FROM NOTIFICATION (from terminated)');
      debugPrint('Data: ${initialMessage.data}');

      _handleMessageTap(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notificationId = message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_processedNotificationIds.contains(notificationId)) {
      debugPrint('⚠️ Duplicate FCM notification ignored: $notificationId');
      return;
    }

    _processedNotificationIds.add(notificationId);

    // Show local notification
    _showLocalNotification(message);

    // Trigger in-app popup
    if (onNotificationReceived != null) {
      final payload = NotificationPayload.fromFCM(message);
      onNotificationReceived!(payload);
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint("👆 Notification tapped");

    if (onFCMMessageTap != null) {
      final payload = NotificationPayload.fromFCM(message);
      onFCMMessageTap!(payload);
    }
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint("👆 Local notification tapped");

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final payload = NotificationPayload(
          id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          type: data['type'] ?? 'general',
          data: data,
          source: NotificationSource.fcm,
        );

        if (NotificationService().onFCMMessageTap != null) {
          NotificationService().onFCMMessageTap!(payload);
        }
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      String title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
      String body = message.notification?.body ?? message.data['body'] ?? 'You have a new notification';

      debugPrint('📲 Showing notification: $title - $body');

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF2196F3),
        ledColor: Color(0xFF2196F3),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'New Notification',
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );

      debugPrint('✅ Local notification shown');
    } catch (e) {
      debugPrint("❌ Error showing local notification: $e");
    }
  }

  // ========== WEBSOCKET ==========
  Future<void> connectToWebSocket(String accessToken) async {
    if (_isConnecting || _channel != null) {
      debugPrint('⚠️ WebSocket: Already connected');
      return;
    }

    if (accessToken.isEmpty) {
      debugPrint('❌ WebSocket: No access token');
      return;
    }

    try {
      _isConnecting = true;
      _shouldStayConnected = true;

      final wsUrl = 'wss://testbackend.polzet.in/ws/notifications/?token=$accessToken';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _streamSubscription = _channel!.stream.listen(
        (message) {
          debugPrint('📨 WebSocket message: $message');
          _handleWebSocketNotification(message);
          _reconnectAttempts = 0;
        },
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _handleWebSocketDisconnection();
        },
        onDone: () {
          debugPrint('🔌 WebSocket closed');
          _handleWebSocketDisconnection();
        },
        cancelOnError: false,
      );

      debugPrint('✅ WebSocket connected');
      _isConnecting = false;
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      _isConnecting = false;
      _handleWebSocketDisconnection();
    }
  }

  void _handleWebSocketNotification(dynamic body) {
    try {
      final data = jsonDecode(body);
      final notificationId = _generateNotificationId(data);

      if (_processedNotificationIds.contains(notificationId)) {
        debugPrint('⚠️ Duplicate WebSocket notification ignored');
        return;
      }

      _processedNotificationIds.add(notificationId);

      final payload = NotificationPayload.fromWebSocket(data);

      if (onNotificationReceived != null) {
        onNotificationReceived!(payload);
      }
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket notification: $e');
    }
  }

  void _handleWebSocketDisconnection() {
    _cleanupWebSocket();

    if (_shouldStayConnected && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleWebSocketReconnect();
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ WebSocket: Max reconnection attempts reached');
    }
  }

  void _scheduleWebSocketReconnect() {
    _reconnectTimer?.cancel();
    final delay = _initialReconnectDelay * (1 << _reconnectAttempts);
    _reconnectAttempts++;

    debugPrint('🔄 WebSocket: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      if (_shouldStayConnected) {
        final token = await SharedPrefService.getAccessToken();
        if (token != null) {
          connectToWebSocket(token);
        }
      }
    });
  }

  void _cleanupWebSocket() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel = null;
    _isConnecting = false;
  }

  void disconnectWebSocket() {
    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      _channel?.sink.close(status.goingAway);
    } catch (e) {
      debugPrint('❌ WebSocket close error: $e');
    }

    _cleanupWebSocket();
    debugPrint('🔌 WebSocket disconnected');
  }

  // ========== HELPERS ==========
  String _generateNotificationId(Map<String, dynamic> data) {
    return data['id']?.toString() ??
        data['notification_id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _processedNotificationIds.clear();
      debugPrint('🧹 Cleared notification IDs');
    });
  }

  // ========== PUBLIC API ==========
  Future<String?> getFCMToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("❌ Error getting FCM token: $e");
      return null;
    }
  }

  bool get isWebSocketConnected => _channel != null;

  Future<void> cleanup() async {
    disconnectWebSocket();
    _cleanupTimer?.cancel();
    _processedNotificationIds.clear();
    await FcmApiService.unregisterFcmToken();
    await _fcm.deleteToken();
    debugPrint("🧹 NotificationService cleaned up");
  }

  void dispose() {
    disconnectWebSocket();
    _cleanupTimer?.cancel();
  }
}

// ========== MODELS ==========
enum NotificationSource { fcm, webSocket, unknown }

class NotificationPayload {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final NotificationSource source;
  final DateTime timestamp;

  NotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NotificationPayload.fromFCM(RemoteMessage message) {
    return NotificationPayload(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? message.data['title'] ?? 'New Notification',
      body: message.notification?.body ?? message.data['body'] ?? 'You have a new notification',
      type: message.data['type']?.toString() ?? 'general',
      data: message.data,
      source: NotificationSource.fcm,
    );
  }

  factory NotificationPayload.fromWebSocket(Map<String, dynamic> data) {
    final notificationData = data['data'] ?? data;
    return NotificationPayload(
      id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notificationData['title'] ?? 'Polzet',
      body: notificationData['body'] ?? notificationData['message'] ?? 'New notification',
      type: notificationData['type']?.toString() ?? 'general',
      data: notificationData,
      source: NotificationSource.webSocket,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'source': source.toString(),
        'timestamp': timestamp.toIso8601String(),
      };
}