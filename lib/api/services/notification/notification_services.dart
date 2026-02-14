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
  // Firebase & Local Notifications
  // ✅ FIXED: Use getter to lazy load instance. Prevents crash in background isolates
  // where Firebase is not initialized yet.
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  RemoteMessage? _pendingInitialMessage;
  RemoteMessage? get pendingInitialMessage => _pendingInitialMessage;

  // ✅ App lifecycle state tracking
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

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
  Function(NotificationPayload)? _onFCMMessageTap;
  NotificationPayload? _pendingTapPayload;

  Function(NotificationPayload)? get onFCMMessageTap => _onFCMMessageTap;

  set onFCMMessageTap(Function(NotificationPayload)? callback) {
    _onFCMMessageTap = callback;
    if (callback != null && _pendingTapPayload != null) {
      debugPrint('🚀 Processing pending notification tap');
      callback(_pendingTapPayload!);
      _pendingTapPayload = null;
    }
  }

  bool _isInitialized = false;

  // ✅ Update app lifecycle state
  void updateAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    debugPrint('📱 NotificationService: App state updated to $state');
  }

  // ✅ Check if app is in foreground (active)
  bool get _isAppInForeground =>
      _appLifecycleState == AppLifecycleState.resumed;

  // ========== INITIALIZATION ==========
  Future<void> initialize() async {
    if (_isInitialized) {
      // Even if initialized, we should check if token needs syncing (e.g. app came to foreground)
      await _checkAndSyncToken();
      return;
    }

    await _initializeLocalNotifications();
    await _initializeFCM();
    _startCleanupTimer();
    _isInitialized = true;

    // Sync token after initialization
    await _checkAndSyncToken();
  }

  /// ✅ NEW: Sync FCM token with backend if user is logged in
  Future<void> _checkAndSyncToken() async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        String? token = await _fcm.getToken();
        if (token != null) {
          debugPrint("🔄 Syncing FCM Token with backend...");
          final platform = Platform.isAndroid ? 'android' : 'ios';
          await FcmApiService.registerFcmToken(token, platform);
        }
      }
    } catch (e) {
      debugPrint("❌ Error syncing FCM token: $e");
    }
  }

  // ✅ Helper method to generate consistent notification content
  static NotificationContent _getNotificationContent(
    Map<String, dynamic> data,
    RemoteMessage? message,
  ) {
    // Try to extract data from nested 'notification' key or root data
    final notificationData = data['notification'] is Map
        ? data['notification'] as Map<String, dynamic>
        : (data['notification'] != null
              ? jsonDecode(data['notification'])
              : data);

    final String type =
        notificationData['type']?.toString().toUpperCase() ??
        data['type']?.toString().toUpperCase() ??
        'GENERAL';

    String title = 'Polzet';
    String body = 'New notification';

    // Customize based on type
    switch (type) {
      case 'FOLLOW':
        final sender =
            notificationData['sender'] ?? data['sender'] ?? 'Someone';
        title = 'New Chase';
        body = '$sender started chasing you';
        break;
      case 'VOTE':
        title = notificationData['title'] ?? data['title'] ?? 'New Vote';
        body =
            notificationData['message_preview'] ??
            notificationData['body'] ??
            data['message_preview'] ??
            'Someone voted on your poll';
        break;
      case 'LIKE':
        title = notificationData['title'] ?? data['title'] ?? 'New Like';
        body =
            notificationData['body'] ??
            data['body'] ??
            'Someone liked your post';
        break;
      case 'COMMENT':
        title = 'New Comment';
        body =
            notificationData['body'] ??
            data['body'] ??
            'Someone commented on your post';
        break;
      default:
        title =
            message?.notification?.title ??
            notificationData['title'] ??
            data['title'] ??
            'Polzet';
        body =
            message?.notification?.body ??
            notificationData['body'] ??
            data['body'] ??
            'You have a new notification';
    }

    return NotificationContent(title, body, type);
  }

  // ✅ NEW: Static method to show notification from background isolate
  @pragma('vm:entry-point')
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    debugPrint('🌙 Background Notification Service Triggered');
    debugPrint('   Data: ${message.data}');

    // ✅ CHECK: If notification payload exists, OS already showed it. No need to show another one.
    // NOTE: To show custom text ("started chasing you"), the backend MUST send data-only messages.
    // If it sends a 'notification' block, the OS shows the default text and we skip this logic to avoid duplicates.
    if (message.notification != null) {
      debugPrint(
        '🌙 Background message has notification payload - OS handles it. Skipping local display to prevent duplicates.',
      );
      return;
    }
 
    // 1. Initialize FlutterLocalNotificationsPlugin (fresh instance for background isolate)
    final FlutterLocalNotificationsPlugin localNotif =
        FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotif.initialize(initSettings);

    // 2. Extract content using shared helper
    try {
      final content = _getNotificationContent(message.data, message);

      if (content.body.isEmpty) return;

      // 3. Show notification
      debugPrint(
        '🌙 Showing background notification: ${content.title} - ${content.body}',
      );

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFE91E63),
        ledOnMs: 1000,
        ledOffMs: 500,
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await localNotif.show(
        id,
        content.title,
        content.body,
        details,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('❌ Error showing background notification: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _initializeFCM() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('❌ FCM: User declined permission');
        return;
      }

      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint("📱 FCM Token: $token");
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
    // ✅ FOREGROUND - Show local notification ONLY if app is active
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 ===== FOREGROUND FCM MESSAGE =====');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
      debugPrint('App State: $_appLifecycleState');
      debugPrint('Is App In Foreground: $_isAppInForeground');
      debugPrint('====================================');

      _handleForegroundMessage(message);
    });

    // ✅ BACKGROUND tap (app in background) - CRITICAL for navigation
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 ===== NOTIFICATION TAPPED (BACKGROUND) =====');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Data: ${message.data}');
      debugPrint('===============================================');
      _handleMessageTap(message);
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notificationId =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // ✅ Prevent duplicate notifications
    if (_processedNotificationIds.contains(notificationId)) {
      debugPrint('⚠️ Duplicate FCM notification blocked: $notificationId');
      return;
    }

    _processedNotificationIds.add(notificationId);

    // ✅ CRITICAL: Only show local notification popup if app is ACTIVE (foreground)
    if (_isAppInForeground) {
      debugPrint(
        '✅ App is ACTIVE - Showing local notification popup (NO FILTERING)',
      );
      _showNativeNotification(message);
    } else {
      debugPrint(
        '⏭️ App is NOT active (state: $_appLifecycleState) - Skipping local notification',
      );
      debugPrint('   FCM will handle this notification in background');
    }
  }

  // ✅ FIXED: Extract and customize notification data based on type using helper
  Future<void> _showNativeNotification(RemoteMessage message) async {
    try {
      final content = _getNotificationContent(message.data, message);

      // ✅ Skip if no meaningful content
      if (content.body.isEmpty) {
        debugPrint('⚠️ Skipping notification - no body content');
        return;
      }

      debugPrint('📢 ===== SHOWING LOCAL NOTIFICATION POPUP =====');
      debugPrint('Type: ${content.type}');
      debugPrint('Title: ${content.title}');
      debugPrint('Body: ${content.body}');
      debugPrint('Full data: ${message.data}');
      debugPrint('==============================================');

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
        ledColor: Color(0xFFE91E63),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'New Notification',
        autoCancel: true,
        fullScreenIntent: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId =
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      debugPrint(
        '🔄 Calling _localNotifications.show() with ID: $notificationId',
      );

      await _localNotifications.show(
        notificationId,
        content.title,
        content.body,
        details,
        payload: jsonEncode(message.data),
      );

      debugPrint(
        '✅ Local notification popup shown successfully: ID=$notificationId',
      );
    } catch (e, stackTrace) {
      debugPrint("❌ Error showing notification: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint("👆 ===== _handleMessageTap called =====");
    debugPrint("Message ID: ${message.messageId}");
    debugPrint("Data: ${message.data}");

    final payload = NotificationPayload.fromFCM(message);

    debugPrint("Payload type: ${payload.type}");
    debugPrint("Payload title: ${payload.title}");
    debugPrint("Callback set: ${_onFCMMessageTap != null}");

    if (_onFCMMessageTap != null) {
      debugPrint("✅ Triggering onFCMMessageTap callback");
      _onFCMMessageTap!(payload);
    } else {
      debugPrint("⚠️ Callback not ready, queuing tap payload");
      _pendingTapPayload = payload;
    }

    debugPrint("=====================================");
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint("👆 ===== LOCAL NOTIFICATION TAPPED =====");
    debugPrint("Notification ID: ${response.id}");
    debugPrint("Action ID: ${response.actionId}");
    debugPrint("Has payload: ${response.payload != null}");

    if (response.payload != null) {
      try {
        debugPrint("Payload: ${response.payload}");
        final data = jsonDecode(response.payload!);
        final payload = NotificationPayload(
          id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          type: data['type'] ?? 'general',
          data: data,
          source: NotificationSource.fcm,
        );

        debugPrint("Parsed payload type: ${payload.type}");
        debugPrint(
          "Callback available: ${NotificationService()._onFCMMessageTap != null}",
        );

        if (NotificationService()._onFCMMessageTap != null) {
          debugPrint("✅ Triggering callback from local notification tap");
          NotificationService()._onFCMMessageTap!(payload);
        } else {
          debugPrint("⚠️ Callback not ready, queuing local tap payload");
          NotificationService()._pendingTapPayload = payload;
        }
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    } else {
      debugPrint("⚠️ No payload in tapped notification");
    }

    debugPrint("=======================================");
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

      final wsUrl =
          'wss://testbackend.polzet.in/ws/notifications/?token=$accessToken';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _streamSubscription = _channel!.stream.listen(
        (message) {
          debugPrint('📨 WebSocket message received');
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

      // ✅ Prevent WebSocket duplicates
      if (_processedNotificationIds.contains(notificationId)) {
        debugPrint(
          '⚠️ Duplicate WebSocket notification blocked: $notificationId',
        );
        return;
      }

      _processedNotificationIds.add(notificationId);

      debugPrint('📨 WebSocket notification: ${data['title'] ?? 'No title'}');
      debugPrint('App State: $_appLifecycleState');

      // ✅ CRITICAL: Only show if app is ACTIVE
      if (_isAppInForeground) {
        debugPrint(
          '✅ App is ACTIVE - Showing WebSocket notification (NO FILTERING)',
        );
        _showWebSocketNotification(data);
      } else {
        debugPrint('⏭️ App is NOT active - Skipping WebSocket notification');
      }
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket notification: $e');
    }
  }

  // ✅ FIXED: Extract and customize WebSocket notification data based on type
  Future<void> _showWebSocketNotification(Map<String, dynamic> data) async {
    try {
      final content = _getNotificationContent(data, null);

      // ✅ Skip if no meaningful content
      if (content.body.isEmpty) {
        debugPrint('⚠️ Skipping WebSocket notification - no body content');
        return;
      }

      debugPrint('📢 Showing WebSocket notification:');
      debugPrint('Type: ${content.type}');
      debugPrint('Title: ${content.title}');
      debugPrint('Body: ${content.body}');
      debugPrint('Full data: $data');

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
        ledColor: Color(0xFFE91E63),
        ledOnMs: 1000,
        ledOffMs: 500,
        autoCancel: true,
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

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        notificationId,
        content.title,
        content.body,
        details,
        payload: jsonEncode(data),
      );

      debugPrint('✅ WebSocket notification shown');
    } catch (e) {
      debugPrint('❌ Error showing WebSocket notification: $e');
    }
  }

  void _handleWebSocketDisconnection() {
    _cleanupWebSocket();

    if (_shouldStayConnected && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = _initialReconnectDelay * _reconnectAttempts;
      debugPrint(
        '⏳ WebSocket disconnected. Reconnecting in ${delay.inSeconds}s '
        '(Attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
      );

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        final accessToken = await SharedPrefService.getAccessToken();
        if (accessToken != null) {
          connectToWebSocket(accessToken);
        }
      });
    }
  }

  void _cleanupWebSocket() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel?.sink.close(status.goingAway);
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
    final notification = data['notification'] ?? data;
    final type = notification['type'] ?? 'general';
    final id =
        notification['post_id'] ??
        notification['sender_id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    return '${type}_$id';
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _processedNotificationIds.clear();
      debugPrint('🧹 Cleared processed notification IDs cache');
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

  // ✅ FIXED: Extract data properly from FCM message with type-based customization
 factory NotificationPayload.fromFCM(RemoteMessage message) {
    // Handle notification data with dynamic type
    dynamic notificationData;
    
    if (message.data.containsKey('notification')) {
      final notifValue = message.data['notification'];
      if (notifValue is Map) {
        notificationData = Map<String, dynamic>.from(notifValue);
      } else if (notifValue is String) {
        try {
          notificationData = jsonDecode(notifValue) as Map<String, dynamic>;
        } catch (e) {
          notificationData = message.data;
        }
      } else {
        notificationData = message.data;
      }
    } else {
      notificationData = message.data;
    }

    // Extract type dynamically
    final dynamic typeValue = notificationData['type'] ?? message.data['type'];
    final String type = (typeValue?.toString() ?? 'GENERAL').toUpperCase();

    String title;
    String body;

    // If backend sent notification block, use it
    if (message.notification != null) {
      title = message.notification!.title ?? 'Polzet';
      body = message.notification!.body ?? 'New notification';
    } else {
      // Customize for data-only messages
      switch (type) {
        case 'FOLLOW':
          final dynamic senderValue = notificationData['sender'] ?? message.data['sender'];
          final String sender = senderValue?.toString() ?? 'Someone';
          title = 'New Chase';
          body = '$sender started chasing you';
          break;

        case 'VOTE':
          final dynamic titleValue = notificationData['title'] ?? message.data['title'];
          title = titleValue?.toString() ?? 'New Vote';
          
          final dynamic bodyValue = notificationData['message_preview'] ??
              notificationData['body'] ??
              message.data['message_preview'] ??
              message.data['body'];
          body = bodyValue?.toString() ?? 'Someone voted on your poll';
          break;

        case 'LIKE':
          final dynamic titleValue = notificationData['title'] ?? message.data['title'];
          title = titleValue?.toString() ?? 'New Like';
          
          final dynamic bodyValue = notificationData['body'] ?? message.data['body'];
          body = bodyValue?.toString() ?? 'Someone liked your post';
          break;

        case 'COMMENT':
          title = 'New Comment';
          final dynamic bodyValue = notificationData['body'] ?? message.data['body'];
          body = bodyValue?.toString() ?? 'Someone commented on your post';
          break;

        case 'NEW_MESSAGE':
          final dynamic titleValue = notificationData['title'] ?? message.data['title'];
          title = titleValue?.toString() ?? 'New Message';
          
          final dynamic bodyValue = notificationData['body'] ?? message.data['body'];
          body = bodyValue?.toString() ?? 'You have a new message';
          break;

        default:
          final dynamic titleValue = notificationData['title'] ?? message.data['title'];
          title = titleValue?.toString() ?? 'Polzet';
          
          final dynamic bodyValue = notificationData['body'] ??
              notificationData['message'] ??
              message.data['body'] ??
              message.data['message'];
          body = bodyValue?.toString() ?? '';
      }
    }

    return NotificationPayload(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      data: Map<String, dynamic>.from(message.data),
      source: NotificationSource.fcm,
    );
  }

  // ✅ FIXED: Extract data properly from WebSocket message with type-based customization
  factory NotificationPayload.fromWebSocket(Map<String, dynamic> data) {
    final notificationData = data['data'] ?? data;
    final notification = notificationData['notification'] ?? notificationData;

    final String type =
        notification['type']?.toString().toUpperCase() ??
        notificationData['type']?.toString().toUpperCase() ??
        'GENERAL';

    String title;
    String body;

    // Customize based on type
    switch (type) {
      case 'FOLLOW':
        final sender =
            notification['sender'] ??
            notificationData['sender'] ??
            data['sender'] ??
            'Someone';
        title = 'New Chase';
        body = '$sender started chasing you';
        break;

      case 'VOTE':
        title =
            notification['title'] ??
            notificationData['title'] ??
            data['title'] ??
            'New Vote';
        body =
            notification['message_preview'] ??
            notificationData['message_preview'] ??
            data['message_preview'] ??
            'Someone voted on your poll';
        break;

      case 'LIKE':
        title =
            notification['title'] ??
            notificationData['title'] ??
            data['title'] ??
            'New Like';
        body =
            notification['body'] ??
            notificationData['body'] ??
            data['body'] ??
            'Someone liked your post';
        break;

      case 'COMMENT':
        title = 'New Comment';
        body =
            notification['body'] ??
            notificationData['body'] ??
            data['body'] ??
            'Someone commented on your post';
        break;

      default:
        title =
            notification['title'] ??
            notificationData['title'] ??
            data['title'] ??
            'Polzet';
        body =
            notification['body'] ??
            notification['message'] ??
            notificationData['body'] ??
            notificationData['message'] ??
            data['body'] ??
            data['message'] ??
            '';
    }

    return NotificationPayload(
      id:
          data['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
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

// ✅ Helper class for consistent content
class NotificationContent {
  final String title;
  final String body;
  final String type;

  NotificationContent(this.title, this.body, this.type);
}
