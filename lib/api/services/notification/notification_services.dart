// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:image/image.dart' as img;

import '../../../data/token/shared_preferences.dart';
import '../fcm/fcm_service.dart';
import '../validator/api_service.dart';
import 'package:http/http.dart' as http;
import '../../api_config.dart';

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  static const MethodChannel _shortcutChannel = MethodChannel(
    'com.polzet_app/shortcuts',
  );

  //*---- Firebase & Local Notifications ----*//
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  RemoteMessage? _pendingInitialMessage;
  RemoteMessage? get pendingInitialMessage => _pendingInitialMessage;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  //*---- WebSocket ----*//
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isConnecting = false;
  bool _shouldStayConnected = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  final Set<String> _processedNotificationIds = {};
  Timer? _cleanupTimer;

  Function(NotificationPayload)? _onFCMMessageTap;
  NotificationPayload? _pendingTapPayload;

  Function(NotificationPayload)? get onFCMMessageTap => _onFCMMessageTap;

  set onFCMMessageTap(Function(NotificationPayload)? callback) {
    _onFCMMessageTap = callback;
    if (callback != null) {
      if (_pendingTapPayload != null) {
        debugPrint('🚀 Processing pending notification tap');
        callback(_pendingTapPayload!);
        _pendingTapPayload = null;
      }
      processPendingTaps();
    }
  }

  bool _isInitialized = false;

  void updateAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    debugPrint('📱 NotificationService: App state updated to $state');
    if (state == AppLifecycleState.resumed) {
      processPendingTaps();
    }
  }

  Future<void> processPendingTaps() async {
    if (_onFCMMessageTap == null) {
      debugPrint('⏳ processPendingTaps: Callback not registered yet');
      return;
    }
    
    // Process local notification taps stored in SharedPreferences
    final String? payloadStr = await SharedPrefService.getString('pending_local_notification_tap');
    if (payloadStr != null && payloadStr.isNotEmpty) {
      debugPrint('🚀 Processing pending stored local notification tap');
      try {
        final data = jsonDecode(payloadStr);
        final String? actionId = await SharedPrefService.getString('pending_local_notification_action');
        final stableId = _generateStableNotificationId(data);

        // Double check duplication
        final isProcessed = await _checkAndMarkNotificationProcessed(stableId);
        if (isProcessed) {
          debugPrint('📬 processPendingTaps: stableId $stableId already processed. Skipping.');
          await SharedPrefService.removeKey('pending_local_notification_tap');
          await SharedPrefService.removeKey('pending_local_notification_action');
          return;
        }
        
        final payload = NotificationPayload(
          id: stableId,
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          type: data['type'] ?? 'general',
          data: data,
          source: NotificationSource.fcm,
          actionId: actionId,
        );
        
        // Remove from SharedPreferences BEFORE calling callback to prevent loops/duplicate navigation
        await SharedPrefService.removeKey('pending_local_notification_tap');
        await SharedPrefService.removeKey('pending_local_notification_action');
        await SharedPrefService.setString('last_processed_notification_id', stableId);
        
        _onFCMMessageTap!(payload);
      } catch (e) {
        debugPrint('❌ Error parsing stored notification payload: $e');
        await SharedPrefService.removeKey('pending_local_notification_tap');
        await SharedPrefService.removeKey('pending_local_notification_action');
      }
    }
  }

  bool get _isAppInForeground =>
      _appLifecycleState == AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_isInitialized) {
      await _checkAndSyncToken();
      processPendingTaps();
      return;
    }

    await _initializeLocalNotifications();
    await _initializeFCM();
    _startCleanupTimer();
    _isInitialized = true;

    await _checkAndSyncToken();
    processPendingTaps();
  }

  //*---- Sync FCM token when logged in ----*//
  Future<void> _checkAndSyncToken() async {
    try {
      final accessToken = await SharedPrefService.getToken();
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

  //*---- Helper method to generate consistent notification content ----*//
  static NotificationContent _getNotificationContent(
    Map<String, dynamic> data,
    RemoteMessage? message,
  ) {
    final notificationData = data['notification'] is Map
        ? data['notification'] as Map<String, dynamic>
        : (data['notification'] != null
              ? jsonDecode(data['notification'])
              : data);

    final String type =
        notificationData['type']?.toString().trim().toUpperCase() ??
        data['type']?.toString().trim().toUpperCase() ??
        'GENERAL';

    String title =
        message?.notification?.title ??
        data['title']?.toString() ??
        notificationData['title']?.toString() ??
        '';

    String body =
        message?.notification?.body ??
        data['body']?.toString() ??
        data['message_preview']?.toString() ??
        notificationData['body']?.toString() ??
        notificationData['message_preview']?.toString() ??
        '';

    if (title.isEmpty) title = 'Polzet';
    final bool hasCustomBody =
        body.isNotEmpty &&
        body.toLowerCase() != 'like' &&
        body.toLowerCase() != 'comment';
    final bool hasCustomTitle = title.isNotEmpty && title != 'Polzet';

    if (!hasCustomBody || !hasCustomTitle) {
      switch (type) {
        case 'FOLLOW':
          String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';

          if (body.contains('started following you')) {
            sender = body.replaceAll(' started following you', '').trim();
          }

          if (!hasCustomTitle) title = 'New Chase';
          if (!hasCustomBody) body = '$sender started chasing you';
          break;
        case 'FOLLOW_GROUP':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'Followers';
          }
          break;
        case 'VOTE':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Vote';
          }
          if (!hasCustomBody) body = '$sender voted on your poll.';
          break;
        case 'GROUP_ADMIN_PROMOTE':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'Group Promotion';
          }
          break;
        case 'LIKE':
        case 'LIKE_GROUP':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Like';
          }
          if (!hasCustomBody) {
            body = '$sender liked your post.';
          }
          break;
        case 'COMMENT':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) title = 'New Comment';
          if (!hasCustomBody) {
            body = '$sender commented on your post.';
          }
          break;
        case 'NEW_MESSAGE':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Message';
          }
          break;
        case 'NEW_GROUP_ADDED':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              (notificationData['actor'] is Map
                  ? notificationData['actor']['name']?.toString()
                  : null) ??
              (data['actor'] is Map
                  ? data['actor']['name']?.toString()
                  : null) ??
              'Someone';
          final String groupName =
              notificationData['group_name']?.toString() ??
              data['group_name']?.toString() ??
              (notificationData['meta'] is Map
                  ? notificationData['meta']['group_name']?.toString()
                  : null) ??
              (data['meta'] is Map
                  ? data['meta']['group_name']?.toString()
                  : null) ??
              'the group';
          if (!hasCustomTitle) title = 'New Group';
          if (!hasCustomBody) {
            body = '$sender added you to the group $groupName.';
          }
          break;
        case 'FRIEND_REQUEST':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) title = 'Chase Request';
          if (!hasCustomBody) {
            body = '$sender sent you a chase request.';
          }
          break;
      }
    }

    return NotificationContent(title, body, type);
  }

  //*---- Static method to show notification from background isolate ----*//
  @pragma('vm:entry-point')
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    debugPrint('🌙 Background Notification Service Triggered');
    debugPrint('   Data: ${message.data}');
    await _printFcmPayload(message);

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
    final iosSettings = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'NEW_MESSAGE_CATEGORY',
          actions: [
            DarwinNotificationAction.text(
              'reply_action',
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Type your reply...',
            ),
            DarwinNotificationAction.plain('mark_read_action', 'Mark as read'),
          ],
        ),
        DarwinNotificationCategory(
          'NEW_GROUP_ADDED_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'message_action',
              'Message',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'FOLLOW_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_profile_action',
              'View Profile',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'FRIEND_REQUEST_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'accept_request_action',
              'Accept',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'reject_request_action',
              'Reject',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'view_profile_action',
              'View Profile',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotif.initialize(initSettings);

    // 2. Extract content using shared helper
    try {
      final content = _getNotificationContent(message.data, message);

      if (content.body.isEmpty) return;

      final List<AndroidNotificationAction>? actions =
          content.type.trim().toUpperCase() == 'NEW_MESSAGE'
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'reply_action',
                'Reply',
                inputs: [
                  AndroidNotificationActionInput(label: 'Type your reply...'),
                ],
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'mark_read_action',
                'Mark as read',
                showsUserInterface: true,
              ),
            ]
          : (content.type.trim().toUpperCase() == 'NEW_GROUP_ADDED'
                ? <AndroidNotificationAction>[
                    const AndroidNotificationAction(
                      'message_action',
                      'Message',
                      showsUserInterface: true,
                    ),
                  ]
                : (content.type.trim().toUpperCase() == 'FOLLOW'
                      ? <AndroidNotificationAction>[
                          const AndroidNotificationAction(
                            'view_profile_action',
                            'View Profile',
                            showsUserInterface: true,
                          ),
                        ]
                      : (content.type.trim().toUpperCase() == 'FRIEND_REQUEST'
                            ? <AndroidNotificationAction>[
                                const AndroidNotificationAction(
                                  'accept_request_action',
                                  'Accept',
                                  showsUserInterface: true,
                                ),
                                const AndroidNotificationAction(
                                  'reject_request_action',
                                  'Reject',
                                  showsUserInterface: true,
                                ),
                                const AndroidNotificationAction(
                                  'view_profile_action',
                                  'View Profile',
                                  showsUserInterface: true,
                                ),
                              ]
                            : null)));

      final notificationData = message.data['notification'] is Map
          ? message.data['notification'] as Map<String, dynamic>
          : (message.data['notification'] != null
                ? jsonDecode(message.data['notification'])
                : message.data);

      final rawSenderProfile =
          notificationData['sender_profile']?.toString() ??
          message.data['sender_profile']?.toString() ??
          notificationData['sender_profile_picture_url']?.toString() ??
          message.data['sender_profile_picture_url']?.toString() ??
          notificationData['sender_profile_image']?.toString() ??
          message.data['sender_profile_image']?.toString() ??
          notificationData['profile_image']?.toString() ??
          message.data['profile_image']?.toString();
      final senderProfile =
          (rawSenderProfile == 'null' || rawSenderProfile == '')
          ? null
          : rawSenderProfile;

      final rawThumbnailUrl =
          notificationData['thumbnail_url']?.toString() ??
          message.data['thumbnail_url']?.toString() ??
          notificationData['post_thumbnail']?.toString() ??
          message.data['post_thumbnail']?.toString() ??
          notificationData['thumbnail']?.toString() ??
          message.data['thumbnail']?.toString();
      final thumbnailUrl = (rawThumbnailUrl == 'null' || rawThumbnailUrl == '')
          ? null
          : rawThumbnailUrl;

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      StyleInformation? styleInformation;
      List<DarwinNotificationAttachment>? attachments;

      String? profilePath;
      if (senderProfile != null && senderProfile.isNotEmpty) {
        profilePath = await _downloadAndSaveFile(
          senderProfile,
          'profile_$id.png',
          cropToCircle: true,
        );
      }

      profilePath ??= await _getDefaultAvatarPath();

      String? thumbPath;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        thumbPath = await _downloadAndSaveFile(
          thumbnailUrl,
          'thumb_$id.png',
          cropToCircle: false,
        );
      }

      if (thumbPath != null) {
        attachments = [DarwinNotificationAttachment(thumbPath)];
      } else if (profilePath != null) {
        attachments = [DarwinNotificationAttachment(profilePath)];
      }

      String? shortcutId;
      final bool isNewMessage = content.type.trim().toUpperCase() == 'NEW_MESSAGE';

      AndroidBitmap<Object>? notificationLargeIcon;

      if (isNewMessage) {
        final String sender =
            notificationData['sender']?.toString() ??
            message.data['sender']?.toString() ??
            'Someone';

        final rawChatId = notificationData['chat_id'] ?? message.data['chat_id'];
        shortcutId = rawChatId != null ? 'chat_${rawChatId.toString()}' : 'chat_${sender.hashCode}';

        final String? currentUserProfilePicUrl =
            await SharedPrefService.getString('user_profile_pic');
        String? currentUserProfilePath = await SharedPrefService.getString(
          'current_user_profile_path',
        );
        if (currentUserProfilePath == null ||
            !File(currentUserProfilePath).existsSync()) {
          if (currentUserProfilePicUrl != null &&
              currentUserProfilePicUrl.isNotEmpty) {
            currentUserProfilePath = await _downloadAndSaveFile(
              currentUserProfilePicUrl,
              'current_user_profile_circle.png',
              cropToCircle: true,
            );
            if (currentUserProfilePath != null) {
              await SharedPrefService.setString(
                'current_user_profile_path',
                currentUserProfilePath,
              );
            }
          }
        }

        final currentUser = Person(
          name: 'You',
          key: 'current_user',
          icon: currentUserProfilePath != null
              ? BitmapFilePathAndroidIcon(currentUserProfilePath)
              : null,
        );

        final displayName = (profilePath == null && sender.isNotEmpty)
            ? (sender[0].toUpperCase() + sender.substring(1))
            : sender;

        final senderPerson = Person(
          name: displayName,
          key: senderProfile,
          icon: profilePath != null ? BitmapFilePathAndroidIcon(profilePath) : null,
        );

        if (Platform.isAndroid) {
          try {
            await _shortcutChannel.invokeMethod('createConversationShortcut', {
              'shortcutId': shortcutId,
              'displayName': displayName,
              'iconPath': profilePath,
            });
          } catch (e) {
            debugPrint('❌ Error creating shortcut in background: $e');
          }
        }

        styleInformation = MessagingStyleInformation(
          currentUser,
          messages: [
            Message(
              content.body,
              DateTime.now(),
              senderPerson,
              dataMimeType: thumbPath != null ? 'image/png' : null,
              dataUri: thumbPath != null ? Uri.file(thumbPath).toString() : null,
            )
          ],
        );

        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }
      } else {
        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }

        if (thumbPath != null) {
          styleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(thumbPath),
            largeIcon: notificationLargeIcon,
            hideExpandedLargeIcon: false,
          );
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFE91E63),
        ledOnMs: 1000,
        ledOffMs: 500,
        autoCancel: true,
        actions: actions,
        largeIcon: notificationLargeIcon,
        styleInformation: styleInformation,
        category: AndroidNotificationCategory.message,
        shortcutId: shortcutId,
      );

      final iosDetails = DarwinNotificationDetails(
        categoryIdentifier: content.type.trim().toUpperCase() == 'NEW_MESSAGE'
            ? 'NEW_MESSAGE_CATEGORY'
            : (content.type.trim().toUpperCase() == 'NEW_GROUP_ADDED'
                  ? 'NEW_GROUP_ADDED_CATEGORY'
                  : (content.type.trim().toUpperCase() == 'FOLLOW'
                        ? 'FOLLOW_CATEGORY'
                        : (content.type.trim().toUpperCase() == 'FRIEND_REQUEST'
                              ? 'FRIEND_REQUEST_CATEGORY'
                              : null))),
        attachments: attachments,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final Map<String, dynamic> payloadData = {
        ...message.data,
        'message_id': message.messageId ?? message.data['message_id'] ?? 'bg_${DateTime.now().millisecondsSinceEpoch}',
      };

      await localNotif.show(
        id,
        content.title,
        content.body,
        details,
        payload: jsonEncode(payloadData),
      );
    } catch (e) {
      debugPrint('❌ Error showing background notification: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'NEW_MESSAGE_CATEGORY',
          actions: [
            DarwinNotificationAction.text(
              'reply_action',
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Type your reply...',
            ),
            DarwinNotificationAction.plain('mark_read_action', 'Mark as read'),
          ],
        ),
        DarwinNotificationCategory(
          'NEW_GROUP_ADDED_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'message_action',
              'Message',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'FOLLOW_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_profile_action',
              'View Profile',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'FRIEND_REQUEST_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'accept_request_action',
              'Accept',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'reject_request_action',
              'Reject',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'view_profile_action',
              'View Profile',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    // Check if the app was launched by tapping a local notification
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      debugPrint('🚀 App launched via local notification tap (launch details detected)');
      _onNotificationTapped(launchDetails.notificationResponse!);
    }

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
    // FOREGROUND - Show local notification ONLY if app is active
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('🔔 ===== FOREGROUND FCM MESSAGE =====');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('Sender ID/From: ${message.from}');
      debugPrint('Sent Time: ${message.sentTime}');
      debugPrint('Collapse Key: ${message.collapseKey}');
      debugPrint('Category: ${message.category}');
      debugPrint('Notification Title: ${message.notification?.title}');
      debugPrint('Notification Body: ${message.notification?.body}');
      debugPrint(
        'Notification Title Loc Key: ${message.notification?.titleLocKey}',
      );
      debugPrint(
        'Notification Body Loc Key: ${message.notification?.bodyLocKey}',
      );
      debugPrint('Data payload: ${message.data}');
      debugPrint('App State: $_appLifecycleState');
      debugPrint('Is App In Foreground: $_isAppInForeground');
      await _printFcmPayload(message);
      debugPrint('====================================');

      _handleForegroundMessage(message);
    });
  }

  static Future<void> _printFcmPayload(RemoteMessage message) async {
    try {
      String? fcmToken = await SharedPrefService.getFcmToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (_) {}
      }
      fcmToken ??= 'YOUR_FCM_TOKEN';

      final Map<String, dynamic> printedData = {};

      // 1. Extract nested notification if present in message.data
      if (message.data.containsKey('notification')) {
        final notifVal = message.data['notification'];
        Map<String, dynamic>? decodedNotif;
        if (notifVal is Map) {
          decodedNotif = Map<String, dynamic>.from(notifVal);
        } else if (notifVal is String) {
          try {
            decodedNotif = jsonDecode(notifVal) as Map<String, dynamic>;
          } catch (_) {}
        }
        if (decodedNotif != null) {
          decodedNotif.forEach((key, val) {
            printedData[key] = val;
          });
        }
      }

      // 2. Add all other key-value pairs from message.data
      message.data.forEach((key, val) {
        if (key != 'notification') {
          printedData[key] = val;
        }
      });

      // 3. Fallback/override with message.notification fields if not already there
      if (message.notification != null) {
        if (message.notification!.title != null) {
          printedData['title'] = message.notification!.title;
        }
        if (message.notification!.body != null) {
          printedData['body'] = message.notification!.body;
          if (!printedData.containsKey('message_preview')) {
            printedData['message_preview'] = message.notification!.body;
          }
        }
      }

      // 4. Construct fcmPayload in the flat structure requested by user
      final Map<String, dynamic> fcmPayload = {
        'to': fcmToken,
        'priority': 'high',
        'data': printedData,
      };

      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyJson = encoder.convert(fcmPayload);
      debugPrint('📬 FCM Payload request format:\n$prettyJson');
    } catch (e) {
      debugPrint('⚠️ Error formatting FCM payload JSON: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notificationId =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_processedNotificationIds.contains(notificationId)) {
      debugPrint('⚠️ Duplicate FCM notification blocked: $notificationId');
      return;
    }

    _processedNotificationIds.add(notificationId);

    // ✅ CRITICAL: Only show local notification popup if app is ACTIVE (foreground)
    if (_isAppInForeground) {
      _showNativeNotification(message);
    } else {
      debugPrint(
        '⏭️ App is NOT active (state: $_appLifecycleState) - Skipping local notification',
      );
    }
  }

  // ✅ Extract and customize notification data based on type using helper
  Future<void> _showNativeNotification(RemoteMessage message) async {
    try {
      final content = _getNotificationContent(message.data, message);

      // ✅ Skip if no meaningful content
      if (content.body.isEmpty) {
        debugPrint('⚠️ Skipping notification - no body content');
        return;
      }

      debugPrint('📢 ===== SHOWING LOCAL NOTIFICATION POPUP =====');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('Notification Title: ${message.notification?.title}');
      debugPrint('Notification Body: ${message.notification?.body}');
      debugPrint('Parsed Content Type: ${content.type}');
      debugPrint('Parsed Content Title: ${content.title}');
      debugPrint('Parsed Content Body: ${content.body}');
      debugPrint('Full data payload: ${message.data}');
      await _printFcmPayload(message);
      debugPrint('==============================================');

      final List<AndroidNotificationAction>? actions =
          content.type.trim().toUpperCase() == 'NEW_MESSAGE'
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'reply_action',
                'Reply',
                inputs: [
                  AndroidNotificationActionInput(label: 'Type your reply...'),
                ],
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'mark_read_action',
                'Mark as read',
                showsUserInterface: true,
              ),
            ]
          : (content.type.trim().toUpperCase() == 'NEW_GROUP_ADDED'
                ? <AndroidNotificationAction>[
                    const AndroidNotificationAction(
                      'message_action',
                      'Message',
                      showsUserInterface: true,
                    ),
                  ]
                : (content.type.trim().toUpperCase() == 'FOLLOW'
                      ? <AndroidNotificationAction>[
                          const AndroidNotificationAction(
                            'view_profile_action',
                            'View Profile',
                            showsUserInterface: true,
                          ),
                        ]
                      : (content.type.trim().toUpperCase() == 'FRIEND_REQUEST'
                            ? <AndroidNotificationAction>[
                                const AndroidNotificationAction(
                                  'accept_request_action',
                                  'Accept',
                                  showsUserInterface: true,
                                ),
                                const AndroidNotificationAction(
                                  'reject_request_action',
                                  'Reject',
                                  showsUserInterface: true,
                                ),
                                const AndroidNotificationAction(
                                  'view_profile_action',
                                  'View Profile',
                                  showsUserInterface: true,
                                ),
                              ]
                            : null)));

      final notificationData = message.data['notification'] is Map
          ? message.data['notification'] as Map<String, dynamic>
          : (message.data['notification'] != null
                ? jsonDecode(message.data['notification'])
                : message.data);

      final rawSenderProfile =
          notificationData['sender_profile']?.toString() ??
          message.data['sender_profile']?.toString() ??
          notificationData['sender_profile_picture_url']?.toString() ??
          message.data['sender_profile_picture_url']?.toString() ??
          notificationData['sender_profile_image']?.toString() ??
          message.data['sender_profile_image']?.toString() ??
          notificationData['profile_image']?.toString() ??
          message.data['profile_image']?.toString();
      final senderProfile =
          (rawSenderProfile == 'null' || rawSenderProfile == '')
          ? null
          : rawSenderProfile;

      final rawThumbnailUrl =
          notificationData['thumbnail_url']?.toString() ??
          message.data['thumbnail_url']?.toString() ??
          notificationData['post_thumbnail']?.toString() ??
          message.data['post_thumbnail']?.toString() ??
          notificationData['thumbnail']?.toString() ??
          message.data['thumbnail']?.toString();
      final thumbnailUrl = (rawThumbnailUrl == 'null' || rawThumbnailUrl == '')
          ? null
          : rawThumbnailUrl;

      final notificationId =
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      StyleInformation? styleInformation;
      List<DarwinNotificationAttachment>? attachments;

      String? profilePath;
      if (senderProfile != null && senderProfile.isNotEmpty) {
        profilePath = await _downloadAndSaveFile(
          senderProfile,
          'profile_$notificationId.png',
          cropToCircle: true,
        );
      }

      profilePath ??= await _getDefaultAvatarPath();

      String? thumbPath;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        thumbPath = await _downloadAndSaveFile(
          thumbnailUrl,
          'thumb_$notificationId.png',
          cropToCircle: false,
        );
      }

      if (thumbPath != null) {
        attachments = [DarwinNotificationAttachment(thumbPath)];
      } else if (profilePath != null) {
        attachments = [DarwinNotificationAttachment(profilePath)];
      }

      String? shortcutId;
      final bool isNewMessage = content.type.trim().toUpperCase() == 'NEW_MESSAGE';

      AndroidBitmap<Object>? notificationLargeIcon;

      if (isNewMessage) {
        final String sender =
            notificationData['sender']?.toString() ??
            message.data['sender']?.toString() ??
            'Someone';

        final rawChatId = notificationData['chat_id'] ?? message.data['chat_id'];
        shortcutId = rawChatId != null ? 'chat_${rawChatId.toString()}' : 'chat_${sender.hashCode}';

        final String? currentUserProfilePicUrl =
            await SharedPrefService.getString('user_profile_pic');
        String? currentUserProfilePath = await SharedPrefService.getString(
          'current_user_profile_path',
        );
        if (currentUserProfilePath == null ||
            !File(currentUserProfilePath).existsSync()) {
          if (currentUserProfilePicUrl != null &&
              currentUserProfilePicUrl.isNotEmpty) {
            currentUserProfilePath = await _downloadAndSaveFile(
              currentUserProfilePicUrl,
              'current_user_profile_circle.png',
              cropToCircle: true,
            );
            if (currentUserProfilePath != null) {
              await SharedPrefService.setString(
                'current_user_profile_path',
                currentUserProfilePath,
              );
            }
          }
        }

        final currentUser = Person(
          name: 'You',
          key: 'current_user',
          icon: currentUserProfilePath != null
              ? BitmapFilePathAndroidIcon(currentUserProfilePath)
              : null,
        );

        final displayName = (profilePath == null && sender.isNotEmpty)
            ? (sender[0].toUpperCase() + sender.substring(1))
            : sender;

        final senderPerson = Person(
          name: displayName,
          key: senderProfile,
          icon: profilePath != null ? BitmapFilePathAndroidIcon(profilePath) : null,
        );

        if (Platform.isAndroid) {
          try {
            await _shortcutChannel.invokeMethod('createConversationShortcut', {
              'shortcutId': shortcutId,
              'displayName': displayName,
              'iconPath': profilePath,
            });
          } catch (e) {
            debugPrint('❌ Error creating shortcut in foreground: $e');
          }
        }

        styleInformation = MessagingStyleInformation(
          currentUser,
          messages: [
            Message(
              content.body,
              DateTime.now(),
              senderPerson,
              dataMimeType: thumbPath != null ? 'image/png' : null,
              dataUri: thumbPath != null ? Uri.file(thumbPath).toString() : null,
            )
          ],
        );

        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }
      } else {
        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }

        if (thumbPath != null) {
          styleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(thumbPath),
            largeIcon: notificationLargeIcon,
            hideExpandedLargeIcon: false,
          );
        }
      }

      final androidDetails = AndroidNotificationDetails(
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
        ledColor: const Color(0xFFE91E63),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'New Notification',
        autoCancel: true,
        fullScreenIntent: true,
        actions: actions,
        largeIcon: notificationLargeIcon,
        styleInformation: styleInformation,
        category: AndroidNotificationCategory.message,
        shortcutId: shortcutId,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: content.type.trim().toUpperCase() == 'NEW_MESSAGE'
            ? 'NEW_MESSAGE_CATEGORY'
            : (content.type.trim().toUpperCase() == 'NEW_GROUP_ADDED'
                  ? 'NEW_GROUP_ADDED_CATEGORY'
                  : (content.type.trim().toUpperCase() == 'FOLLOW'
                        ? 'FOLLOW_CATEGORY'
                        : (content.type.trim().toUpperCase() == 'FRIEND_REQUEST'
                              ? 'FRIEND_REQUEST_CATEGORY'
                              : null))),
        attachments: attachments,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      debugPrint(
        '🔄 Calling _localNotifications.show() with ID: $notificationId',
      );

      final Map<String, dynamic> payloadData = {
        ...message.data,
        'message_id': message.messageId ?? message.data['message_id'] ?? 'fg_${DateTime.now().millisecondsSinceEpoch}',
      };

      await _localNotifications.show(
        notificationId,
        content.title,
        content.body,
        details,
        payload: jsonEncode(payloadData),
      );
    } catch (e, stackTrace) {
      debugPrint("❌ Error showing notification: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleNotificationAction(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    if (actionId == null || response.payload == null) return;

    try {
      WidgetsFlutterBinding.ensureInitialized();
      final data = jsonDecode(response.payload!);

      if (actionId == 'accept_request_action' ||
          actionId == 'reject_request_action') {
        final action = actionId == 'accept_request_action'
            ? 'accept'
            : 'reject';
        final rawRequestId =
            data['request_id'] ??
            (data['meta'] is Map ? data['meta']['request_id'] : null) ??
            data['requestId'] ??
            (data['data'] is Map ? data['data']['request_id'] : null);
        final int? requestId = rawRequestId != null
            ? int.tryParse(rawRequestId.toString())
            : null;

        if (requestId == null) {
          debugPrint(
            "⚠️ No request_id in notification payload for action: $actionId",
          );
          return;
        }

        debugPrint("📬 Action: $action friend request $requestId");
        final accessToken = await SharedPrefService.getToken();
        final responseApi = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/friend_requests/$requestId'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'action': action}),
        );
        final bool success = responseApi.statusCode == 200;
        debugPrint("📬 Friend request $action success: $success");
        return;
      }

      final rawChatId = data['chat_id'];
      final int? chatId = rawChatId != null
          ? int.tryParse(rawChatId.toString())
          : null;
      if (chatId == null) {
        debugPrint(
          "⚠️ No chat_id in notification payload for action: $actionId",
        );
        return;
      }

      if (actionId == 'mark_read_action') {
        debugPrint("📬 Action: Mark chat $chatId as read");
        final success = await ApiService().markChatAsRead(chatId: chatId);
        debugPrint("📬 Mark as read success: $success");
      } else if (actionId == 'reply_action') {
        final replyText = response.input;
        if (replyText != null && replyText.isNotEmpty) {
          debugPrint("📬 Action: Reply to chat $chatId with: $replyText");
          await ApiService().sendMessage(chatId: chatId, text: replyText);
          debugPrint("📬 Reply sent successfully");

          // Update the notification to show user's reply with "You" and profile picture
          try {
            final notificationData = data['notification'] is Map
                ? data['notification'] as Map<String, dynamic>
                : (data['notification'] != null
                      ? jsonDecode(data['notification'])
                      : data);

            final content = _getNotificationContent(data, null);
            final String sender =
                notificationData['sender']?.toString() ??
                data['sender']?.toString() ??
                'Someone';

            final rawSenderProfile =
                notificationData['sender_profile']?.toString() ??
                data['sender_profile']?.toString() ??
                notificationData['sender_profile_picture_url']?.toString() ??
                data['sender_profile_picture_url']?.toString() ??
                notificationData['sender_profile_image']?.toString() ??
                data['sender_profile_image']?.toString() ??
                notificationData['profile_image']?.toString() ??
                data['profile_image']?.toString();
            final senderProfile =
                (rawSenderProfile == 'null' || rawSenderProfile == '')
                ? null
                : rawSenderProfile;

            final int notificationId =
                response.id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

            String? profilePath;
            if (senderProfile != null && senderProfile.isNotEmpty) {
              profilePath = await _downloadAndSaveFile(
                senderProfile,
                'profile_$notificationId.png',
                cropToCircle: true,
              );
            }

            final String? currentUserProfilePicUrl =
                await SharedPrefService.getString('user_profile_pic');
            String? currentUserProfilePath = await SharedPrefService.getString(
              'current_user_profile_path',
            );
            if (currentUserProfilePath == null ||
                !File(currentUserProfilePath).existsSync()) {
              if (currentUserProfilePicUrl != null &&
                  currentUserProfilePicUrl.isNotEmpty) {
                currentUserProfilePath = await _downloadAndSaveFile(
                  currentUserProfilePicUrl,
                  'current_user_profile_circle.png',
                  cropToCircle: true,
                );
                if (currentUserProfilePath != null) {
                  await SharedPrefService.setString(
                    'current_user_profile_path',
                    currentUserProfilePath,
                  );
                }
              }
            }

            final currentUser = Person(
              name: 'You',
              key: 'current_user',
              icon: currentUserProfilePath != null
                  ? BitmapFilePathAndroidIcon(currentUserProfilePath)
                  : null,
            );

            final displayName = (profilePath == null && sender.isNotEmpty)
                ? (sender[0].toUpperCase() + sender.substring(1))
                : sender;

            final senderPerson = Person(
              name: displayName,
              key: senderProfile,
              icon: profilePath != null
                  ? BitmapFilePathAndroidIcon(profilePath)
                  : null,
            );

            final styleInformation = MessagingStyleInformation(
              currentUser,
              messages: [
                Message(
                  content.body,
                  DateTime.now().subtract(const Duration(seconds: 5)),
                  senderPerson,
                ),
                Message(replyText, DateTime.now(), currentUser),
              ],
            );

            final List<AndroidNotificationAction> actions =
                <AndroidNotificationAction>[
                  const AndroidNotificationAction(
                    'reply_action',
                    'Reply',
                    inputs: [
                      AndroidNotificationActionInput(
                        label: 'Type your reply...',
                      ),
                    ],
                    showsUserInterface: true,
                  ),
                  const AndroidNotificationAction(
                    'mark_read_action',
                    'Mark as read',
                    showsUserInterface: true,
                  ),
                ];

            final androidDetails = AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              icon: '@mipmap/ic_launcher',
              playSound: false, // Don't play sound again on reply update
              enableVibration: false, // Don't vibrate again on reply update
              enableLights: false,
              autoCancel: true,
              actions: actions,
              styleInformation: styleInformation,
              category: AndroidNotificationCategory.message,
            );

            const iosDetails = DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: false,
              categoryIdentifier: 'NEW_MESSAGE_CATEGORY',
            );

            final details = NotificationDetails(
              android: androidDetails,
              iOS: iosDetails,
            );

            final FlutterLocalNotificationsPlugin localNotif =
                FlutterLocalNotificationsPlugin();
            await localNotif.show(
              notificationId,
              content.title,
              content.body,
              details,
              payload: response.payload,
            );
            debugPrint("📬 Notification updated with reply");
          } catch (e) {
            debugPrint("❌ Error updating notification with reply: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error handling notification action: $e");
    }
  }

  static String _generateStableNotificationId(Map<String, dynamic> data) {
    final notificationData = data['notification'] is Map
        ? data['notification'] as Map<String, dynamic>
        : data;
    
    dynamic getValue(String key) {
      final val = data[key] ?? notificationData[key];
      if (val == null) return null;
      final valStr = val.toString().trim();
      if (valStr == 'null' || valStr == '0' || valStr.isEmpty) {
        return null;
      }
      return val;
    }

    final id = getValue('id') ?? 
               getValue('message_id') ?? 
               getValue('post_id') ?? 
               getValue('sender_id') ?? 
               getValue('chat_id') ?? 
               getValue('request_id');
               
    if (id != null) {
      return id.toString();
    }
    
    return data.toString().hashCode.toString();
  }

  static Future<bool> _checkAndMarkActionProcessed(NotificationResponse response) async {
    try {
      final String? jsonStr = await SharedPrefService.getString('processed_notification_actions');
      List<String> processedActions = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          processedActions = List<String>.from(jsonDecode(jsonStr));
        } catch (_) {}
      }

      final String payloadStr = response.payload ?? '';
      final String inputStr = response.input ?? '';
      final int responseId = response.id ?? payloadStr.hashCode;
      final String actionKey = 'action_${responseId}_${response.actionId}_${inputStr.hashCode}_${payloadStr.hashCode}';

      if (processedActions.contains(actionKey)) {
        return true;
      }

      processedActions.add(actionKey);
      if (processedActions.length > 100) {
        processedActions.removeAt(0);
      }

      await SharedPrefService.setString('processed_notification_actions', jsonEncode(processedActions));
      return false;
    } catch (e) {
      debugPrint('❌ Error checking/marking notification action: $e');
      return false;
    }
  }

  static Future<bool> _checkAndMarkNotificationProcessed(String stableId) async {
    try {
      final String? jsonStr = await SharedPrefService.getString('processed_notification_ids');
      List<String> processedIds = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          processedIds = List<String>.from(jsonDecode(jsonStr));
        } catch (_) {}
      }

      if (processedIds.contains(stableId)) {
        return true;
      }

      processedIds.add(stableId);
      if (processedIds.length > 100) {
        processedIds.removeAt(0);
      }

      await SharedPrefService.setString('processed_notification_ids', jsonEncode(processedIds));
      return false;
    } catch (e) {
      debugPrint('❌ Error checking/marking notification: $e');
      return false;
    }
  }

  static Future<void> _savePendingTapToPrefs(NotificationResponse response) async {
    try {
      if (response.payload != null) {
        await SharedPrefService.setString('pending_local_notification_tap', response.payload!);
        if (response.actionId != null) {
          await SharedPrefService.setString('pending_local_notification_action', response.actionId!);
        } else {
          await SharedPrefService.removeKey('pending_local_notification_action');
        }
        debugPrint('💾 Saved pending local notification tap to SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Error saving pending tap to prefs: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationTapped(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        debugPrint("Payload: ${response.payload}");
        final data = jsonDecode(response.payload!);

        // Intercept action taps to handle them inline
        if (response.actionId == 'mark_read_action' ||
            response.actionId == 'reply_action' ||
            response.actionId == 'accept_request_action' ||
            response.actionId == 'reject_request_action') {
          final isAlreadyProcessed = await _checkAndMarkActionProcessed(response);
          if (isAlreadyProcessed) {
            debugPrint('📬 _onNotificationTapped: Action already processed. Skipping.');
            return;
          }
          _handleNotificationAction(response);
          return;
        }

        final stableId = _generateStableNotificationId(data);

        // Prevent duplicate processing
        final isProcessed = await _checkAndMarkNotificationProcessed(stableId);
        if (isProcessed) {
          debugPrint('📬 _onNotificationTapped: stableId $stableId already processed. Skipping.');
          return;
        }

        final payload = NotificationPayload(
          id: stableId,
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          type: data['type'] ?? 'general',
          data: data,
          source: NotificationSource.fcm,
          actionId: response.actionId,
        );

        debugPrint("Parsed payload type: ${payload.type}, stableId: $stableId");
        debugPrint(
          "Callback available: ${NotificationService()._onFCMMessageTap != null}",
        );

        if (NotificationService()._onFCMMessageTap != null) {
          // Processed immediately in the main isolate, record it to avoid repetition
          await SharedPrefService.setString('last_processed_notification_id', stableId);
          NotificationService()._onFCMMessageTap!(payload);
        } else {
          // If no callback, save to SharedPreferences to process later when resume/registered
          await _savePendingTapToPrefs(response);
          NotificationService()._pendingTapPayload = payload;
        }
      } catch (e) {
        debugPrint("❌ Error handling notification tap: $e");
      }
    } else {}
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
          'ws://testbackend.polzet.in/ws/notifications/?token=$accessToken';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _streamSubscription = _channel!.stream.listen(
        (message) {
          debugPrint('📨 WebSocket message received');
          _handleWebSocketNotification(message);
          _reconnectAttempts = 0;
        },
        onError: (error) {
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
        return;
      }

      _processedNotificationIds.add(notificationId);

      debugPrint('📨 WebSocket notification: ${data['title'] ?? 'No title'}');
      debugPrint('App State: $_appLifecycleState');

      if (_isAppInForeground) {
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

      final List<AndroidNotificationAction>? actions =
          content.type.trim().toUpperCase() == 'NEW_MESSAGE'
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'reply_action',
                'Reply',
                inputs: [
                  AndroidNotificationActionInput(label: 'Type your reply...'),
                ],
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'mark_read_action',
                'Mark as read',
                showsUserInterface: true,
              ),
            ]
          : (content.type.trim().toUpperCase() == 'NEW_GROUP_ADDED'
                ? <AndroidNotificationAction>[
                    const AndroidNotificationAction(
                      'message_action',
                      'Message',
                      showsUserInterface: true,
                    ),
                  ]
                : (content.type.trim().toUpperCase() == 'FOLLOW'
                      ? <AndroidNotificationAction>[
                          const AndroidNotificationAction(
                            'view_profile_action',
                            'View Profile',
                            showsUserInterface: true,
                          ),
                        ]
                      : (content.type.trim().toUpperCase() == 'FRIEND_REQUEST'
                            ? <AndroidNotificationAction>[
                                const AndroidNotificationAction(
                                  'accept_request_action',
                                  'Accept',
                                  showsUserInterface: true,
                                ),
                                const AndroidNotificationAction(
                                  'reject_request_action',
                                  'Reject',
                                  showsUserInterface: true,
                                ),
                                const AndroidNotificationAction(
                                  'view_profile_action',
                                  'View Profile',
                                  showsUserInterface: true,
                                ),
                              ]
                            : null)));

      final notificationData = data['notification'] is Map
          ? data['notification'] as Map<String, dynamic>
          : (data['notification'] != null
                ? jsonDecode(data['notification'])
                : data);

      final senderProfile =
          notificationData['sender_profile']?.toString() ??
          data['sender_profile']?.toString() ??
          notificationData['sender_profile_picture_url']?.toString() ??
          data['sender_profile_picture_url']?.toString() ??
          notificationData['sender_profile_image']?.toString() ??
          data['sender_profile_image']?.toString() ??
          notificationData['profile_image']?.toString() ??
          data['profile_image']?.toString();

      final rawThumbnailUrl =
          notificationData['thumbnail_url']?.toString() ??
          data['thumbnail_url']?.toString() ??
          notificationData['post_thumbnail']?.toString() ??
          data['post_thumbnail']?.toString() ??
          notificationData['thumbnail']?.toString() ??
          data['thumbnail']?.toString();
      final thumbnailUrl = (rawThumbnailUrl == 'null' || rawThumbnailUrl == '')
          ? null
          : rawThumbnailUrl;

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      StyleInformation? styleInformation;
      List<DarwinNotificationAttachment>? attachments;

      String? profilePath;
      if (senderProfile != null && senderProfile.isNotEmpty) {
        profilePath = await _downloadAndSaveFile(
          senderProfile,
          'profile_$notificationId.png',
          cropToCircle: true,
        );
      }

      profilePath ??= await _getDefaultAvatarPath();

      String? thumbPath;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        thumbPath = await _downloadAndSaveFile(
          thumbnailUrl,
          'thumb_$notificationId.png',
          cropToCircle: false,
        );
      }

      if (thumbPath != null) {
        attachments = [DarwinNotificationAttachment(thumbPath)];
      } else if (profilePath != null) {
        attachments = [DarwinNotificationAttachment(profilePath)];
      }

      String? shortcutId;
      final bool isNewMessage = content.type.trim().toUpperCase() == 'NEW_MESSAGE';

      AndroidBitmap<Object>? notificationLargeIcon;

      if (isNewMessage) {
        final String sender =
            notificationData['sender']?.toString() ??
            data['sender']?.toString() ??
            'Someone';

        final rawChatId = notificationData['chat_id'] ?? data['chat_id'];
        shortcutId = rawChatId != null ? 'chat_${rawChatId.toString()}' : 'chat_${sender.hashCode}';

        final String? currentUserProfilePicUrl =
            await SharedPrefService.getString('user_profile_pic');
        String? currentUserProfilePath = await SharedPrefService.getString(
          'current_user_profile_path',
        );
        if (currentUserProfilePath == null ||
            !File(currentUserProfilePath).existsSync()) {
          if (currentUserProfilePicUrl != null &&
              currentUserProfilePicUrl.isNotEmpty) {
            currentUserProfilePath = await _downloadAndSaveFile(
              currentUserProfilePicUrl,
              'current_user_profile_circle.png',
              cropToCircle: true,
            );
            if (currentUserProfilePath != null) {
              await SharedPrefService.setString(
                'current_user_profile_path',
                currentUserProfilePath,
              );
            }
          }
        }

        final currentUser = Person(
          name: 'You',
          key: 'current_user',
          icon: currentUserProfilePath != null
              ? BitmapFilePathAndroidIcon(currentUserProfilePath)
              : null,
        );

        final displayName = (profilePath == null && sender.isNotEmpty)
            ? (sender[0].toUpperCase() + sender.substring(1))
            : sender;

        final senderPerson = Person(
          name: displayName,
          key: senderProfile,
          icon: profilePath != null ? BitmapFilePathAndroidIcon(profilePath) : null,
        );

        if (Platform.isAndroid) {
          try {
            await _shortcutChannel.invokeMethod('createConversationShortcut', {
              'shortcutId': shortcutId,
              'displayName': displayName,
              'iconPath': profilePath,
            });
          } catch (e) {
            debugPrint('❌ Error creating shortcut via WebSocket: $e');
          }
        }

        styleInformation = MessagingStyleInformation(
          currentUser,
          messages: [
            Message(
              content.body,
              DateTime.now(),
              senderPerson,
              dataMimeType: thumbPath != null ? 'image/png' : null,
              dataUri: thumbPath != null ? Uri.file(thumbPath).toString() : null,
            )
          ],
        );

        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }
      } else {
        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }

        if (thumbPath != null) {
          styleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(thumbPath),
            largeIcon: notificationLargeIcon,
            hideExpandedLargeIcon: false,
          );
        }
      }

      final androidDetails = AndroidNotificationDetails(
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
        ledColor: const Color(0xFFE91E63),
        ledOnMs: 1000,
        ledOffMs: 500,
        autoCancel: true,
        actions: actions,
        largeIcon: notificationLargeIcon,
        styleInformation: styleInformation,
        category: AndroidNotificationCategory.message,
        shortcutId: shortcutId,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: content.type.trim().toUpperCase() == 'NEW_MESSAGE'
            ? 'NEW_MESSAGE_CATEGORY'
            : (content.type.trim().toUpperCase() == 'NEW_GROUP_ADDED'
                  ? 'NEW_GROUP_ADDED_CATEGORY'
                  : (content.type.trim().toUpperCase() == 'FOLLOW'
                        ? 'FOLLOW_CATEGORY'
                        : (content.type.trim().toUpperCase() == 'FRIEND_REQUEST'
                              ? 'FRIEND_REQUEST_CATEGORY'
                              : null))),
        attachments: attachments,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final Map<String, dynamic> payloadData = {
        ...data,
        'message_id': data['id'] ?? data['message_id'] ?? 'ws_${DateTime.now().millisecondsSinceEpoch}',
      };

      await _localNotifications.show(
        notificationId,
        content.title,
        content.body,
        details,
        payload: jsonEncode(payloadData),
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
        //'⏳ WebSocket disconnected. Reconnecting in ${delay.inSeconds}s '
        '(Attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
      );

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        final accessToken = await SharedPrefService.getToken();
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

  static Future<String?> _downloadAndSaveFile(
    String url,
    String fileName, {
    bool cropToCircle = false,
  }) async {
    if (url.isEmpty) return null;
    try {
      String absoluteUrl = url;
      if (url.startsWith('/')) {
        absoluteUrl = '${ApiConfig.baseUrlImage}$url';
      } else if (!url.startsWith('http')) {
        absoluteUrl = '${ApiConfig.baseUrlImage}/$url';
      }

      final response = await http.get(Uri.parse(absoluteUrl));
      if (response.statusCode == 200) {
        var bytes = response.bodyBytes;
        if (cropToCircle) {
          try {
            var originalImage = img.decodeImage(bytes);
            if (originalImage != null) {
              if (!originalImage.hasAlpha) {
                originalImage = originalImage.convert(numChannels: 4);
              }
              final circleImage = img.copyCropCircle(originalImage);
              bytes = Uint8List.fromList(img.encodePng(circleImage));
            }
          } catch (e) {
            debugPrint('❌ Error cropping image to circle: $e');
          }
        }
        final filePath = '${Directory.systemTemp.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error downloading notification image ($url): $e');
      return null;
    }
  }

  static Future<String?> _getDefaultAvatarPath() async {
    try {
      final filePath = '${Directory.systemTemp.path}/default_avatar_circle.png';
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      // Load asset and save it as circular png
      final byteData = await rootBundle.load('assets/images/ic_avatar.png');
      final bytes = byteData.buffer.asUint8List();
      var originalImage = img.decodeImage(bytes);
      if (originalImage != null) {
        if (!originalImage.hasAlpha) {
          originalImage = originalImage.convert(numChannels: 4);
        }
        final circleImage = img.copyCropCircle(originalImage);
        final circleBytes = img.encodePng(circleImage);
        await file.writeAsBytes(circleBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('❌ Error loading default avatar asset: $e');
    }
    return null;
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
  final String? actionId;

  NotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.source,
    DateTime? timestamp,
    this.actionId,
  }) : timestamp = timestamp ?? DateTime.now();

  // ✅ FIXED: Extract data properly from FCM message with type-based customization
  factory NotificationPayload.fromFCM(RemoteMessage message, {String? actionId}) {
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
    final String type = (typeValue?.toString() ?? 'GENERAL')
        .trim()
        .toUpperCase();

    // Get the title and body from either the custom data or the notification block
    String title =
        message.notification?.title ??
        notificationData['title']?.toString() ??
        message.data['title']?.toString() ??
        '';

    String body =
        message.notification?.body ??
        notificationData['message_preview']?.toString() ??
        notificationData['body']?.toString() ??
        notificationData['message']?.toString() ??
        message.data['message_preview']?.toString() ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    if (title.isEmpty) title = 'Polzet';
    final bool hasCustomBody =
        body.isNotEmpty &&
        body.toLowerCase() != 'like' &&
        body.toLowerCase() != 'comment';
    final bool hasCustomTitle = title.isNotEmpty && title != 'Polzet';

    if (!hasCustomBody || !hasCustomTitle) {
      switch (type) {
        case 'FOLLOW':
          final dynamic senderValue =
              notificationData['sender'] ?? message.data['sender'];
          String sender = senderValue?.toString() ?? 'Someone';

          if (body.contains('started following you')) {
            sender = body.replaceAll(' started following you', '').trim();
          }

          if (!hasCustomTitle) title = 'New Chase';
          if (!hasCustomBody) body = '$sender started chasing you';
          break;
        case 'FOLLOW_GROUP':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'Followers';
          }
          break;
        case 'VOTE':
          final String sender =
              notificationData['sender']?.toString() ??
              message.data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'New Vote';
          }
          if (!hasCustomBody) body = '$sender voted on your poll.';
          break;
        case 'LIKE':
        case 'LIKE_GROUP':
          final String sender =
              notificationData['sender']?.toString() ??
              message.data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'New Like';
          }
          if (!hasCustomBody) {
            body = '$sender liked your post.';
          }
          break;
        case 'COMMENT':
          final String sender =
              notificationData['sender']?.toString() ??
              message.data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) title = 'New Comment';
          if (!hasCustomBody) {
            body = '$sender commented on your post.';
          }
          break;
        case 'GROUP_ADMIN_PROMOTE':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'Group Promotion';
          }
          break;
        case 'NEW_MESSAGE':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'New Message';
          }
          break;
        case 'NEW_GROUP_ADDED':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'New Group';
          }
          break;
        case 'FRIEND_REQUEST':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                message.data['title']?.toString() ??
                'Chase Request';
          }
          break;
      }
    }

    return NotificationPayload(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      data: Map<String, dynamic>.from(message.data),
      source: NotificationSource.fcm,
      actionId: actionId,
    );
  }

  // ✅ FIXED: Extract data properly from WebSocket message with type-based customization
  factory NotificationPayload.fromWebSocket(Map<String, dynamic> data) {
    final notificationData = data['data'] ?? data;
    final notification = notificationData['notification'] ?? notificationData;

    final String type =
        notification['type']?.toString().trim().toUpperCase() ??
        notificationData['type']?.toString().trim().toUpperCase() ??
        'GENERAL';

    // Get the title and body
    String title =
        notification['title']?.toString() ??
        notificationData['title']?.toString() ??
        data['title']?.toString() ??
        '';

    String body =
        notification['message_preview']?.toString() ??
        notification['body']?.toString() ??
        notification['message']?.toString() ??
        notificationData['message_preview']?.toString() ??
        notificationData['body']?.toString() ??
        notificationData['message']?.toString() ??
        data['message_preview']?.toString() ??
        data['body']?.toString() ??
        data['message']?.toString() ??
        '';

    if (title.isEmpty) title = 'Polzet';
    final bool hasCustomBody =
        body.isNotEmpty &&
        body.toLowerCase() != 'like' &&
        body.toLowerCase() != 'comment';
    final bool hasCustomTitle = title.isNotEmpty && title != 'Polzet';

    if (!hasCustomBody || !hasCustomTitle) {
      switch (type) {
        case 'FOLLOW':
          String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';

          if (body.contains('started following you')) {
            sender = body.replaceAll(' started following you', '').trim();
          }

          if (!hasCustomTitle) title = 'New Chase';
          if (!hasCustomBody) body = '$sender started chasing you';
          break;
        case 'FOLLOW_GROUP':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'Chasers';
          }
          break;
        case 'VOTE':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Vote';
          }
          if (!hasCustomBody) body = '$sender voted on your poll.';
          break;
        case 'LIKE':
        case 'LIKE_GROUP':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Like';
          }
          if (!hasCustomBody) {
            body = '$sender liked your post.';
          }
          break;
        case 'COMMENT':
          final String sender =
              notificationData['sender']?.toString() ??
              data['sender']?.toString() ??
              'Someone';
          if (!hasCustomTitle) title = 'New Comment';
          if (!hasCustomBody) {
            body = '$sender commented on your post.';
          }
          break;
        case 'GROUP_ADMIN_PROMOTE':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'Group Promotion';
          }
          break;
        case 'NEW_MESSAGE':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Message';
          }
          break;
        case 'NEW_GROUP_ADDED':
          if (!hasCustomTitle) {
            title =
                notification['title']?.toString() ??
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New Group';
          }
          break;
        case 'FRIEND_REQUEST':
          if (!hasCustomTitle) {
            title =
                notification['title']?.toString() ??
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'Chase Request';
          }
          break;
      }
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
    'actionId': actionId,
  };
}

class NotificationContent {
  final String title;
  final String body;
  final String type;

  NotificationContent(this.title, this.body, this.type);
}
