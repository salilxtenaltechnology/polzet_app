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
import '../../api_service.dart';
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

  static final Set<String> _processedNotificationIds = {};
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
    final String? payloadStr = await SharedPrefService.getString(
      'pending_local_notification_tap',
    );
    if (payloadStr != null && payloadStr.isNotEmpty) {
      debugPrint('🚀 Processing pending stored local notification tap');
      try {
        final data = jsonDecode(payloadStr);
        final String? actionId = await SharedPrefService.getString(
          'pending_local_notification_action',
        );
        final stableId = _generateStableNotificationId(data);
        final String tapKey = '${stableId}_${actionId ?? 'body'}';

        // Double check duplication for tap handling
        final isProcessed = await _checkAndMarkTapProcessed(tapKey);
        if (isProcessed) {
          debugPrint(
            '📬 processPendingTaps: tapKey $tapKey already processed. Skipping.',
          );
          await SharedPrefService.removeKey('pending_local_notification_tap');
          await SharedPrefService.removeKey(
            'pending_local_notification_action',
          );
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
        await SharedPrefService.setString(
          'last_processed_notification_id',
          stableId,
        );

        _onFCMMessageTap!(payload);
      } catch (e) {
        debugPrint('❌ Error parsing stored notification payload: $e');
        await SharedPrefService.removeKey('pending_local_notification_tap');
        await SharedPrefService.removeKey('pending_local_notification_action');
      }
    }
  }

  bool get _isAppInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) {
      return state == AppLifecycleState.resumed;
    }
    return _appLifecycleState == AppLifecycleState.resumed;
  }

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
        debugPrint("🔄 Syncing token & connecting Notification WebSocket...");
        connectToWebSocket(accessToken);
        String? token = await _fcm.getToken();
        if (token != null) {
          debugPrint("🔄 Syncing FCM Token with backend...");
          final platform = Platform.isAndroid ? 'android' : 'ios';
          await FcmApiService.registerFcmToken(token, platform);
        }
      }
    } catch (e) {
      debugPrint("❌ Error syncing FCM token / connecting WS: $e");
    }
  }

  static Map<String, dynamic> _getParsedNotificationData(
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(data);
    try {
      if (data['data'] is Map) {
        result.addAll(Map<String, dynamic>.from(data['data'] as Map));
      } else if (data['data'] != null && data['data'] is String) {
        final decoded = jsonDecode(data['data'].toString());
        if (decoded is Map) {
          result.addAll(Map<String, dynamic>.from(decoded));
        }
      }
      if (data['notification'] is Map) {
        result.addAll(Map<String, dynamic>.from(data['notification'] as Map));
      } else if (data['notification'] != null &&
          data['notification'] is String) {
        final decoded = jsonDecode(data['notification'].toString());
        if (decoded is Map) {
          result.addAll(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error decoding notification data: $e');
    }
    return result;
  }

  static String _resolveNotificationType(
    Map<String, dynamic> data,
    String rawType, {
    String? body,
    String? title,
  }) {
    final notificationData = _getParsedNotificationData(data);
    String type = rawType.trim().toUpperCase();

    if (type == 'GENERAL' || type.isEmpty) {
      final possibleType =
          (notificationData['type'] ??
                  notificationData['notification_type'] ??
                  notificationData['event_type'] ??
                  notificationData['action_type'] ??
                  data['type'] ??
                  data['notification_type'] ??
                  data['event_type'] ??
                  data['action_type'])
              ?.toString()
              .trim()
              .toUpperCase();
      if (possibleType != null &&
          possibleType.isNotEmpty &&
          possibleType != 'GENERAL') {
        type = possibleType;
      }
    }

    if (type == 'AI_NEW_POST' ||
        type == 'AI_POST' ||
        type == 'AI_POLL' ||
        type == 'POLZET_AI') {
      type = 'AI_NEW_POST';
    } else if (type == 'POLL' ||
        type == 'NEW_POLL' ||
        type == 'POST' ||
        type == 'CREATE_POST' ||
        type == 'POLL_CREATED' ||
        type == 'ADD_POST' ||
        type == 'NEW_POST' ||
        type == 'POLL_POST' ||
        type == 'POST_CREATED') {
      type = 'NEW_POST';
    } else if (type == 'VOTE' ||
        type == 'NEW_VOTE' ||
        type == 'POLL_VOTE' ||
        type == 'POLL_VOTED' ||
        type == 'VOTED' ||
        type == 'VOTE_POLL' ||
        type == 'VOTE_CAST' ||
        type == 'CAST_VOTE' ||
        type == 'USER_VOTED' ||
        type == 'NEW_POLL_VOTE') {
      type = 'VOTE';
    } else if (type == 'LIKE' ||
        type == 'NEW_LIKE' ||
        type == 'LIKED' ||
        type == 'POST_LIKED' ||
        type == 'LIKE_POST' ||
        type == 'USER_LIKED') {
      type = 'LIKE';
    } else if (type == 'LIKE_GROUP') {
      type = 'LIKE_GROUP';
    } else if (type == 'COMMENT' ||
        type == 'NEW_COMMENT' ||
        type == 'COMMENTED' ||
        type == 'COMMETNT' ||
        type == 'COMMENT_POST' ||
        type == 'POST_COMMENT' ||
        type == 'USER_COMMENTED' ||
        type == 'REPLY' ||
        type == 'COMMENT_REPLY' ||
        type == 'NEW_REPLY') {
      type = 'COMMENT';
    } else if (type == 'COMMENT_GROUP') {
      type = 'COMMENT_GROUP';
    } else if (type == 'MESSAGE' ||
        type == 'CHAT' ||
        type == 'NEW_CHAT' ||
        type == 'NEW_MESSAGE' ||
        type == 'PRIVATE_CHAT' ||
        type == 'DIRECT_MESSAGE' ||
        type == 'DM' ||
        type == 'CHAT_MESSAGE' ||
        type == 'SEND_MESSAGE') {
      type = 'NEW_MESSAGE';
    } else if (type == 'CHASE' ||
        type == 'NEW_FOLLOWER' ||
        type == 'FOLLOW_USER' ||
        type == 'NEW_CHASE' ||
        type == 'CHASING' ||
        type == 'USER_FOLLOWED' ||
        type == 'FOLLOW') {
      type = 'FOLLOW';
    } else if (type == 'FOLLOW_GROUP') {
      type = 'FOLLOW_GROUP';
    } else if (type == 'CHASE_REQUEST' ||
        type == 'FRIEND_REQ' ||
        type == 'FRIEND_REQUEST' ||
        type == 'NEW_FRIEND_REQUEST' ||
        type == 'NEW_CHASE_REQUEST' ||
        type == 'REQUEST_FOLLOW') {
      type = 'FRIEND_REQUEST';
    } else if (type == 'GROUP_ADD' ||
        type == 'ADD_GROUP' ||
        type == 'NEW_GROUP_ADDED' ||
        type == 'ADDED_TO_GROUP' ||
        type == 'GROUP_ADDED') {
      type = 'NEW_GROUP_ADDED';
    } else if (type == 'GROUP_ADMIN_PROMOTE' ||
        type == 'ADMIN_PROMOTE' ||
        type == 'PROMOTE_ADMIN' ||
        type == 'GROUP_ADMIN') {
      type = 'GROUP_ADMIN_PROMOTE';
    } else if (type == 'GROUP_JOIN_REQUEST' ||
        type == 'JOIN_REQUEST' ||
        type == 'GROUP_REQUEST') {
      type = 'GROUP_JOIN_REQUEST';
    }

    if (type == 'GENERAL' ||
        type.isEmpty ||
        (![
          'NEW_POST',
          'VOTE',
          'LIKE',
          'LIKE_GROUP',
          'COMMENT',
          'COMMENT_GROUP',
          'NEW_MESSAGE',
          'FOLLOW',
          'FOLLOW_GROUP',
          'FRIEND_REQUEST',
          'NEW_GROUP_ADDED',
          'GROUP_ADMIN_PROMOTE',
          'GROUP_JOIN_REQUEST',
          'AI_NEW_POST',
        ].contains(type))) {
      final fullText = '${title ?? ''} ${body ?? ''}'.toLowerCase();
      final hasPostId =
          (notificationData['post_id'] ??
              data['post_id'] ??
              notificationData['postId'] ??
              data['postId']) !=
          null;
      final hasChatId =
          (notificationData['chat_id'] ??
              data['chat_id'] ??
              notificationData['chatId'] ??
              data['chatId']) !=
          null;

      if (fullText.contains('ai') &&
          (fullText.contains('create poll') || fullText.contains('suggest'))) {
        type = 'AI_NEW_POST';
      } else if (fullText.contains('vote') || fullText.contains('voted')) {
        type = 'VOTE';
      } else if (fullText.contains('liked') || fullText.contains('like')) {
        type = 'LIKE';
      } else if (fullText.contains('commented') ||
          fullText.contains('comment') ||
          fullText.contains('replied') ||
          fullText.contains('reply')) {
        type = 'COMMENT';
      } else if (fullText.contains('chase request') ||
          fullText.contains('friend request')) {
        type = 'FRIEND_REQUEST';
      } else if (fullText.contains('started chasing') ||
          fullText.contains('started following') ||
          fullText.contains('chasing') ||
          fullText.contains('following') ||
          fullText.contains('follower')) {
        type = 'FOLLOW';
      } else if (fullText.contains('added you to the group') ||
          fullText.contains('added you to group') ||
          fullText.contains('new group')) {
        type = 'NEW_GROUP_ADDED';
      } else if (fullText.contains('promoted you') ||
          fullText.contains('admin')) {
        type = 'GROUP_ADMIN_PROMOTE';
      } else if (fullText.contains('requested to join') ||
          fullText.contains('join request')) {
        type = 'GROUP_JOIN_REQUEST';
      } else if (fullText.contains('added new poll') ||
          fullText.contains('created a poll') ||
          fullText.contains('new poll') ||
          fullText.contains('poll')) {
        type = 'NEW_POST';
      } else if (fullText.contains('message') || hasChatId) {
        type = 'NEW_MESSAGE';
      } else if (hasPostId) {
        type = 'NEW_POST';
      }
    }

    return type;
  }

  static List<AndroidNotificationAction>? _getAndroidActions(
    Map<String, dynamic> data,
    String type, {
    String? body,
    String? title,
  }) {
    final String resolvedType = _resolveNotificationType(
      data,
      type,
      body: body,
      title: title,
    );

    if (resolvedType == 'AI_NEW_POST') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'create_poll_action',
          'Create Poll',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'NEW_POST' || resolvedType == 'VOTE') {
      final notificationData = _getParsedNotificationData(data);
      final rawPollType = (notificationData['poll_type'] ??
              data['poll_type'] ??
              notificationData['polltype'] ??
              data['polltype'])
          ?.toString()
          .toLowerCase();

      String secondActionText = 'Vote Now';
      String secondActionId = 'vote_now_action';
      if (rawPollType != null) {
        if (rawPollType.startsWith('battle')) {
          secondActionText = 'Pick a Side';
          secondActionId = 'pick_side_action';
        } else if (rawPollType.startsWith('anonymous')) {
          secondActionText = 'Vote Privately';
          secondActionId = 'vote_privately_action';
        }
      }

      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_post_action',
          'View Poll',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          secondActionId,
          secondActionText,
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'like_action',
          'Like',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'LIKE' || resolvedType == 'LIKE_GROUP') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_post_action',
          'View Poll',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'like_action',
          'Like',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'COMMENT' || resolvedType == 'COMMENT_GROUP') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_post_action',
          'View Poll',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Type your reply...')],
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'NEW_MESSAGE') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Type your reply...')],
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'mark_read_action',
          'Mark as read',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'NEW_GROUP_ADDED') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'message_action',
          'Message',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'view_group_action',
          'View Group',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'GROUP_ADMIN_PROMOTE') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_group_action',
          'View Group',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'GROUP_JOIN_REQUEST') {
      return <AndroidNotificationAction>[
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
      ];
    } else if (resolvedType == 'FOLLOW' || resolvedType == 'FOLLOW_GROUP') {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_profile_action',
          'View Profile',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'follow_back_action',
          'Follow Back',
          showsUserInterface: true,
        ),
      ];
    } else if (resolvedType == 'FRIEND_REQUEST') {
      return <AndroidNotificationAction>[
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
      ];
    }

    final notificationData = _getParsedNotificationData(data);
    final hasPostId = (notificationData['post_id'] ??
            data['post_id'] ??
            notificationData['postId'] ??
            data['postId']) !=
        null;
    final hasSenderId = (notificationData['sender_id'] ??
            data['sender_id'] ??
            data['user_id']) !=
        null;

    if (hasPostId) {
      final rawPollType = (notificationData['poll_type'] ??
              data['poll_type'] ??
              notificationData['polltype'] ??
              data['polltype'])
          ?.toString()
          .toLowerCase();

      String secondActionText = 'Vote Now';
      String secondActionId = 'vote_now_action';
      if (rawPollType != null) {
        if (rawPollType.startsWith('battle')) {
          secondActionText = 'Pick a Side';
          secondActionId = 'pick_side_action';
        } else if (rawPollType.startsWith('anonymous')) {
          secondActionText = 'Vote Privately';
          secondActionId = 'vote_privately_action';
        }
      }

      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_post_action',
          'View Poll',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          secondActionId,
          secondActionText,
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'like_action',
          'Like',
          showsUserInterface: true,
        ),
      ];
    } else if (hasSenderId) {
      return <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_profile_action',
          'View Profile',
          showsUserInterface: true,
        ),
      ];
    }

    return null;
  }

  static String? _getIosCategoryIdentifier(
    Map<String, dynamic> data,
    String type, {
    String? body,
    String? title,
  }) {
    final String resolvedType = _resolveNotificationType(
      data,
      type,
      body: body,
      title: title,
    );

    if (resolvedType == 'AI_NEW_POST') {
      return 'AI_NEW_POST_CATEGORY';
    } else if (resolvedType == 'NEW_MESSAGE') {
      return 'NEW_MESSAGE_CATEGORY';
    } else if (resolvedType == 'NEW_GROUP_ADDED' ||
        resolvedType == 'GROUP_ADMIN_PROMOTE') {
      return 'NEW_GROUP_ADDED_CATEGORY';
    } else if (resolvedType == 'FOLLOW' || resolvedType == 'FOLLOW_GROUP') {
      return 'FOLLOW_CATEGORY';
    } else if (resolvedType == 'FRIEND_REQUEST' ||
        resolvedType == 'GROUP_JOIN_REQUEST') {
      return 'FRIEND_REQUEST_CATEGORY';
    } else if (resolvedType == 'NEW_POST' ||
        resolvedType == 'VOTE' ||
        resolvedType == 'LIKE' ||
        resolvedType == 'LIKE_GROUP' ||
        resolvedType == 'COMMENT' ||
        resolvedType == 'COMMENT_GROUP') {
      final notificationData = _getParsedNotificationData(data);
      final rawPollType = (notificationData['poll_type'] ??
              data['poll_type'] ??
              notificationData['polltype'] ??
              data['polltype'])
          ?.toString()
          .toLowerCase();
      if (rawPollType != null) {
        if (rawPollType.startsWith('battle')) {
          return 'BATTLE_POLL_CATEGORY';
        } else if (rawPollType.startsWith('anonymous')) {
          return 'ANONYMOUS_POLL_CATEGORY';
        } else if (rawPollType.startsWith('text')) {
          return 'TEXT_POLL_CATEGORY';
        } else if (rawPollType.startsWith('image')) {
          return 'IMAGE_POLL_CATEGORY';
        } else if (rawPollType.startsWith('this_or_that')) {
          return 'THIS_OR_THAT_CATEGORY';
        }
      }
      return 'TEXT_POLL_CATEGORY';
    }

    final notificationData = _getParsedNotificationData(data);
    final hasPostId = (notificationData['post_id'] ??
            data['post_id'] ??
            notificationData['postId'] ??
            data['postId']) !=
        null;
    final hasSenderId = (notificationData['sender_id'] ??
            data['sender_id'] ??
            data['user_id']) !=
        null;
    if (hasPostId) {
      return 'TEXT_POLL_CATEGORY';
    } else if (hasSenderId) {
      return 'FOLLOW_CATEGORY';
    }

    return null;
  }

  //*---- Helper method to generate consistent notification content ----*//
  static NotificationContent _getNotificationContent(
    Map<String, dynamic> data,
    RemoteMessage? message,
  ) {
    final notificationData = _getParsedNotificationData(data);

    final String rawType =
        notificationData['type']?.toString().trim().toUpperCase() ??
        data['type']?.toString().trim().toUpperCase() ??
        'GENERAL';

    String title =
        message?.notification?.title ??
        notificationData['title']?.toString() ??
        data['title']?.toString() ??
        '';

    String body =
        message?.notification?.body ??
        notificationData['body']?.toString() ??
        notificationData['message_preview']?.toString() ??
        notificationData['message']?.toString() ??
        data['body']?.toString() ??
        data['message_preview']?.toString() ??
        data['message']?.toString() ??
        '';

    final String type = _resolveNotificationType(
      data,
      rawType,
      body: body,
      title: title,
    );

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
        case 'AI_NEW_POST':
          if (!hasCustomTitle) {
            title =
                notificationData['title']?.toString() ??
                data['title']?.toString() ??
                'New AI Poll';
          }
          if (!hasCustomBody) {
            body =
                notificationData['post_description']?.toString() ??
                data['post_description']?.toString() ??
                notificationData['body']?.toString() ??
                data['body']?.toString() ??
                notificationData['message_preview']?.toString() ??
                data['message_preview']?.toString() ??
                '';
          }
          break;
      }
    }

    return NotificationContent(title, body, type);
  }

  @pragma('vm:entry-point')
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    WidgetsFlutterBinding.ensureInitialized();
    final bool hasNotificationPayload = message.notification != null;
    final bool hasDataPayload = message.data.isNotEmpty;
    final String fcmPayloadType = hasNotificationPayload
        ? (hasDataPayload ? 'MIXED (notification + data)' : 'NOTIFICATION ONLY')
        : 'DATA ONLY';

    debugPrint('🌙 Background Notification Service Triggered');
    debugPrint('   - FCM payload type: $fcmPayloadType');
    debugPrint('   - HAS notification payload: $hasNotificationPayload');
    debugPrint('   - HAS data payload: $hasDataPayload');
    debugPrint('   - Data: ${message.data}');
    await _printFcmPayload(message);

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
        DarwinNotificationCategory(
          'AI_NEW_POST_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'create_poll_action',
              'Create Poll',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'TEXT_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_now_action',
              'Vote Now',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'IMAGE_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_now_action',
              'Vote Now',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'BATTLE_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'pick_side_action',
              'Pick a Side',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'THIS_OR_THAT_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_now_action',
              'Vote Now',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'ANONYMOUS_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_privately_action',
              'Vote Privately',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
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

    await localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    // 2. Extract content using shared helper
    try {
      final content = _getNotificationContent(message.data, message);

      if (content.body.isEmpty) return;

      final String resolvedBgType = _resolveNotificationType(
        message.data,
        content.type,
        body: content.body,
        title: content.title,
      );

      final List<AndroidNotificationAction>? actions = _getAndroidActions(
        message.data,
        resolvedBgType,
        body: content.body,
        title: content.title,
      );

      final notificationData = message.data['notification'] is Map
          ? message.data['notification'] as Map<String, dynamic>
          : (message.data['notification'] != null
                ? jsonDecode(message.data['notification'])
                : message.data);

      final bool isAiNewPost =
          resolvedBgType == 'AI_NEW_POST' ||
          content.type.trim().toUpperCase() == 'AI_NEW_POST';

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
          (isAiNewPost || rawSenderProfile == 'null' || rawSenderProfile == '')
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
      final String stableIdStr = _generateStableNotificationId(message.data);
      final isProcessed = await _checkAndMarkNotificationProcessed(
        stableIdStr,
      );
      if (isProcessed) {
        debugPrint(
          '⚠️ [DEBUG_TRACE] Duplicate background notification blocked: $stableIdStr',
        );
        return;
      }
      if (message.messageId != null && message.messageId != stableIdStr) {
        await _checkAndMarkNotificationProcessed(message.messageId!);
      }

      final id = stableIdStr.hashCode & 0x7FFFFFFF;

      StyleInformation? styleInformation;
      List<DarwinNotificationAttachment>? attachments;

      String? profilePath;
      if (!isAiNewPost) {
        if (senderProfile != null && senderProfile.isNotEmpty) {
          profilePath = await _downloadAndSaveFile(
            senderProfile,
            'profile_$id.png',
            cropToCircle: true,
          );
        }

        profilePath ??= await _getDefaultAvatarPath();
      }

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
      final bool isNewMessage =
          resolvedBgType == 'NEW_MESSAGE' ||
          content.type.trim().toUpperCase() == 'NEW_MESSAGE';

      AndroidBitmap<Object>? notificationLargeIcon;

      if (isNewMessage) {
        final String sender =
            notificationData['sender']?.toString() ??
            message.data['sender']?.toString() ??
            'Someone';

        final rawChatId =
            notificationData['chat_id'] ?? message.data['chat_id'];
        shortcutId = rawChatId != null
            ? 'chat_${rawChatId.toString()}'
            : 'chat_${sender.hashCode}';

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
              dataUri: thumbPath != null
                  ? Uri.file(thumbPath).toString()
                  : null,
            ),
          ],
        );

        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }
      } else {
        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        } else if (thumbPath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(thumbPath);
        }

        if (thumbPath != null) {
          styleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(thumbPath),
            largeIcon: notificationLargeIcon,
            contentTitle: content.title,
            summaryText: content.body,
            hideExpandedLargeIcon: profilePath == null,
          );
        } else {
          styleInformation = BigTextStyleInformation(
            content.body,
            contentTitle: content.title,
            summaryText: isAiNewPost ? 'Polzet AI' : null,
          );
        }
      }

      AndroidNotificationCategory? notifCategory;
      switch (resolvedBgType) {
        case 'NEW_MESSAGE':
          notifCategory = AndroidNotificationCategory.message;
          break;
        case 'FOLLOW':
        case 'FRIEND_REQUEST':
        case 'LIKE':
        case 'COMMENT':
        case 'VOTE':
        case 'NEW_GROUP_ADDED':
          notifCategory = AndroidNotificationCategory.social;
          break;
        case 'NEW_POST':
        case 'AI_NEW_POST':
          notifCategory = AndroidNotificationCategory.event;
          break;
        default:
          notifCategory = AndroidNotificationCategory.status;
          break;
      }

      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF9B3046),
        ledColor: const Color(0xFF9B3046),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'New Notification',
        autoCancel: true,
        fullScreenIntent: true,
        actions: actions,
        largeIcon: notificationLargeIcon,
        styleInformation: styleInformation,
        category: notifCategory,
        shortcutId: shortcutId,
      );

      final iosDetails = DarwinNotificationDetails(
        categoryIdentifier: _getIosCategoryIdentifier(
          message.data,
          content.type,
          body: content.body,
          title: content.title,
        ),
        attachments: attachments,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final Map<String, dynamic> payloadData = {
        ...message.data,
        'stable_notification_id': stableIdStr,
        'stable_id': stableIdStr,
        'message_id':
            message.messageId ??
            message.data['message_id'] ??
            stableIdStr,
      };

      final rawPostId = notificationData['post_id'] ?? message.data['post_id'];
      debugPrint('🚨 [DEBUG_TRACE] SHOWING NOTIFICATION FROM SOURCE: FCM_BACKGROUND');
      debugPrint('   - Source: FCM_BACKGROUND');
      debugPrint('   - content.type: ${content.type}');
      debugPrint('   - resolvedBgType: $resolvedBgType');
      debugPrint('   - actions == null: ${actions == null}');
      debugPrint('   - actions.length: ${actions?.length ?? 0}');
      if (actions != null) {
        for (final action in actions) {
          debugPrint('     * action: id=${action.id}, label=${action.title}');
        }
      }
      debugPrint('   - Android Notification ID: $id');
      debugPrint('   - Stable Notification ID: $stableIdStr');
      debugPrint('   - Title: ${content.title}');
      debugPrint('   - Body: ${content.body}');
      debugPrint('   - Post ID: $rawPostId');
      debugPrint('   - Has top-level notification payload: ${message.notification != null}');
      debugPrint('   - Payload data: $payloadData');

      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await localNotif
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      final List<String> actionIds = actions?.map((a) => a.id).toList() ?? [];
      debugPrint('🚨 [POPUP DISPLAY] SHOWING NOTIFICATION:');
      debugPrint('   - SOURCE: FCM_BACKGROUND');
      debugPrint('   - TYPE: $resolvedBgType');
      debugPrint('   - STABLE ID: $stableIdStr');
      debugPrint('   - ANDROID NOTIFICATION ID: $id');
      debugPrint('   - ACTIONS COUNT: ${actions?.length ?? 0}');
      debugPrint('   - ACTION IDS: $actionIds');

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
        DarwinNotificationCategory(
          'AI_NEW_POST_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'create_poll_action',
              'Create Poll',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'TEXT_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_now_action',
              'Vote Now',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'IMAGE_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_now_action',
              'Vote Now',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'BATTLE_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'pick_side_action',
              'Pick a Side',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'THIS_OR_THAT_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Post',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_now_action',
              'Vote Now',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
        DarwinNotificationCategory(
          'ANONYMOUS_POLL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'view_post_action',
              'View Poll',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'vote_privately_action',
              'Vote Privately',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'like_action',
              'Like',
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
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      debugPrint(
        '🚀 App launched via local notification tap (launch details detected)',
      );
      _onNotificationTapped(launchDetails.notificationResponse!);
    }

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
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

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

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
      final bool hasNotificationPayload = message.notification != null;
      final bool hasDataPayload = message.data.isNotEmpty;
      final String fcmPayloadType = hasNotificationPayload
          ? (hasDataPayload ? 'MIXED (notification + data)' : 'NOTIFICATION ONLY')
          : 'DATA ONLY';

      debugPrint('🔔 ===== FOREGROUND FCM MESSAGE =====');
      debugPrint('   - FCM payload type: $fcmPayloadType');
      debugPrint('   - HAS notification payload: $hasNotificationPayload');
      debugPrint('   - HAS data payload: $hasDataPayload');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('Sender ID/From: ${message.from}');
      debugPrint('Sent Time: ${message.sentTime}');
      debugPrint('Collapse Key: ${message.collapseKey}');
      debugPrint('Category: ${message.category}');
      if (hasNotificationPayload) {
        debugPrint('Notification Title: ${message.notification?.title}');
        debugPrint('Notification Body: ${message.notification?.body}');
        debugPrint(
          'Notification Title Loc Key: ${message.notification?.titleLocKey}',
        );
        debugPrint(
          'Notification Body Loc Key: ${message.notification?.bodyLocKey}',
        );
      }
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
      final bool hasNotificationPayload = message.notification != null;
      final bool hasDataPayload = message.data.isNotEmpty;
      final String fcmPayloadType = hasNotificationPayload
          ? (hasDataPayload ? 'MIXED (notification + data)' : 'NOTIFICATION ONLY')
          : 'DATA ONLY';

      debugPrint('📋 FCM PAYLOAD INSPECTION:');
      debugPrint('   - FCM payload type: $fcmPayloadType');
      debugPrint('   - HAS notification payload: $hasNotificationPayload');
      debugPrint('   - HAS data payload: $hasDataPayload');

      if (hasNotificationPayload) {
        debugPrint('   ⚠️ WARNING: message.notification is present in FCM message!');
        debugPrint('      Title: "${message.notification?.title}"');
        debugPrint('      Body: "${message.notification?.body}"');
        debugPrint('   ⚠️ WHY DUPLICATE NOTIFICATION HAPPENS IN BACKGROUND:');
        debugPrint('      When "HAS notification payload: true", Android OS (Google Play Services)');
        debugPrint('      automatically displays an action-less plain system notification in the shade');
        debugPrint('      whenever the app is backgrounded or killed.');
        debugPrint('      Flutter then displays the 2nd rich notification with action buttons.');
        debugPrint('      To prevent this 2nd plain notification from being created, the backend MUST');
        debugPrint('      send a pure DATA-ONLY payload (no top-level "notification" key).');
      }

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

      // 4. Construct fcmPayload in the data-only structure required by backend
      final Map<String, dynamic> fcmPayload = {
        'to': fcmToken,
        'priority': 'high',
        'data': printedData,
      };

      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyJson = encoder.convert(fcmPayload);
      debugPrint('📬 REQUIRED Backend Data-Only Payload format:\n$prettyJson');
    } catch (e) {
      debugPrint('⚠️ Error formatting FCM payload JSON: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final String stableId = _generateStableNotificationId(message.data);

    final isProcessed = await _checkAndMarkNotificationProcessed(
      stableId,
    );
    if (isProcessed) {
      debugPrint(
        '⚠️ Duplicate FCM notification blocked: $stableId',
      );
      return;
    }

    if (message.messageId != null && message.messageId != stableId) {
      await _checkAndMarkNotificationProcessed(message.messageId!);
    }

    if (_isAppInForeground) {
      debugPrint('🔔 [DEBUG_TRACE] Showing FCM foreground notification popup: $stableId');
      await _showNativeNotificationFromData(
        message.data,
        message: message,
        source: 'FCM_FOREGROUND',
      );
    } else {
      debugPrint(
        '⏭️ App is NOT active (state: $_appLifecycleState) - Skipping local notification',
      );
    }
  }

  // ✅ Extract and customize notification data based on type using helper
  Future<void> _showNativeNotificationFromData(
    Map<String, dynamic> rawData, {
    RemoteMessage? message,
    String source = 'WEBSOCKET_FOREGROUND',
  }) async {
    try {
      final content = _getNotificationContent(rawData, message);

      // ✅ Skip if no meaningful content
      if (content.body.isEmpty) {
        debugPrint('⚠️ Skipping notification - no body content');
        return;
      }

      debugPrint('📢 ===== SHOWING LOCAL NOTIFICATION POPUP ($source) =====');
      debugPrint('Message ID: ${message?.messageId}');
      debugPrint('Notification Title: ${message?.notification?.title ?? content.title}');
      debugPrint('Notification Body: ${message?.notification?.body ?? content.body}');
      debugPrint('Parsed Content Type: ${content.type}');
      debugPrint('Parsed Content Title: ${content.title}');
      debugPrint('Parsed Content Body: ${content.body}');
      debugPrint('Full data payload: $rawData');
      if (message != null) {
        await _printFcmPayload(message);
      }
      debugPrint('==============================================');

      final String resolvedFgType = _resolveNotificationType(
        rawData,
        content.type,
        body: content.body,
        title: content.title,
      );

      final List<AndroidNotificationAction>? actions = _getAndroidActions(
        rawData,
        resolvedFgType,
        body: content.body,
        title: content.title,
      );

      final notificationData = rawData['notification'] is Map
          ? rawData['notification'] as Map<String, dynamic>
          : (rawData['notification'] != null &&
                  rawData['notification'] is String
              ? jsonDecode(rawData['notification'])
              : rawData);

      final bool isAiNewPost =
          resolvedFgType == 'AI_NEW_POST' ||
          content.type.trim().toUpperCase() == 'AI_NEW_POST';

      final rawSenderProfile =
          notificationData['sender_profile']?.toString() ??
          rawData['sender_profile']?.toString() ??
          notificationData['sender_profile_picture_url']?.toString() ??
          rawData['sender_profile_picture_url']?.toString() ??
          notificationData['sender_profile_image']?.toString() ??
          rawData['sender_profile_image']?.toString() ??
          notificationData['profile_image']?.toString() ??
          rawData['profile_image']?.toString();
      final senderProfile =
          (isAiNewPost || rawSenderProfile == 'null' || rawSenderProfile == '')
          ? null
          : rawSenderProfile;

      final rawThumbnailUrl =
          notificationData['thumbnail_url']?.toString() ??
          rawData['thumbnail_url']?.toString() ??
          notificationData['post_thumbnail']?.toString() ??
          rawData['post_thumbnail']?.toString() ??
          notificationData['thumbnail']?.toString() ??
          rawData['thumbnail']?.toString();
      final thumbnailUrl = (rawThumbnailUrl == 'null' || rawThumbnailUrl == '')
          ? null
          : rawThumbnailUrl;

      final String stableId = _generateStableNotificationId(rawData);
      final notificationId = stableId.hashCode & 0x7FFFFFFF;

      StyleInformation? styleInformation;
      List<DarwinNotificationAttachment>? attachments;

      String? profilePath;
      if (!isAiNewPost) {
        if (senderProfile != null && senderProfile.isNotEmpty) {
          profilePath = await _downloadAndSaveFile(
            senderProfile,
            'profile_$notificationId.png',
            cropToCircle: true,
          );
        }

        profilePath ??= await _getDefaultAvatarPath();
      }

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
      final bool isNewMessage =
          resolvedFgType == 'NEW_MESSAGE' ||
          content.type.trim().toUpperCase() == 'NEW_MESSAGE';

      AndroidBitmap<Object>? notificationLargeIcon;

      if (isNewMessage) {
        final String sender =
            notificationData['sender']?.toString() ??
            rawData['sender']?.toString() ??
            'Someone';

        final rawChatId =
            notificationData['chat_id'] ?? rawData['chat_id'];
        shortcutId = rawChatId != null
            ? 'chat_${rawChatId.toString()}'
            : 'chat_${sender.hashCode}';

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
              dataUri: thumbPath != null
                  ? Uri.file(thumbPath).toString()
                  : null,
            ),
          ],
        );

        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        }
      } else {
        if (profilePath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(profilePath);
        } else if (thumbPath != null) {
          notificationLargeIcon = FilePathAndroidBitmap(thumbPath);
        }

        if (thumbPath != null) {
          styleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(thumbPath),
            largeIcon: notificationLargeIcon,
            contentTitle: content.title,
            summaryText: content.body,
            hideExpandedLargeIcon: profilePath == null,
          );
        } else {
          styleInformation = BigTextStyleInformation(
            content.body,
            contentTitle: content.title,
            summaryText: isAiNewPost ? 'Polzet AI' : null,
          );
        }
      }

      AndroidNotificationCategory? notifCategory;
      switch (resolvedFgType) {
        case 'NEW_MESSAGE':
          notifCategory = AndroidNotificationCategory.message;
          break;
        case 'FOLLOW':
        case 'FRIEND_REQUEST':
        case 'LIKE':
        case 'COMMENT':
        case 'VOTE':
        case 'NEW_GROUP_ADDED':
          notifCategory = AndroidNotificationCategory.social;
          break;
        case 'NEW_POST':
        case 'AI_NEW_POST':
          notifCategory = AndroidNotificationCategory.event;
          break;
        default:
          notifCategory = AndroidNotificationCategory.status;
          break;
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
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF9B3046),
        ledColor: const Color(0xFF9B3046),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'New Notification',
        autoCancel: true,
        fullScreenIntent: true,
        actions: actions,
        largeIcon: notificationLargeIcon,
        styleInformation: styleInformation,
        category: notifCategory,
        shortcutId: shortcutId,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: _getIosCategoryIdentifier(
          rawData,
          content.type,
          body: content.body,
          title: content.title,
        ),
        attachments: attachments,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final Map<String, dynamic> payloadData = {
        ...rawData,
        'stable_notification_id': stableId,
        'stable_id': stableId,
        'message_id':
            message?.messageId ??
            rawData['message_id'] ??
            stableId,
      };

      final rawPostId = notificationData['post_id'] ?? rawData['post_id'];
      debugPrint('🚨 [DEBUG_TRACE] SHOWING NOTIFICATION FROM SOURCE: $source');
      debugPrint('   - Source: $source');
      debugPrint('   - content.type: ${content.type}');
      debugPrint('   - resolvedFgType: $resolvedFgType');
      debugPrint('   - actions == null: ${actions == null}');
      debugPrint('   - actions.length: ${actions?.length ?? 0}');
      if (actions != null) {
        for (final action in actions) {
          debugPrint('     * action: id=${action.id}, label=${action.title}');
        }
      }
      debugPrint('   - Android Notification ID: $notificationId');
      debugPrint('   - Stable Notification ID: $stableId');
      debugPrint('   - Title: ${content.title}');
      debugPrint('   - Body: ${content.body}');
      debugPrint('   - Post ID: $rawPostId');
      final List<String> actionIds = actions?.map((a) => a.id).toList() ?? [];
      debugPrint('🚨 [POPUP DISPLAY] SHOWING NOTIFICATION:');
      debugPrint('   - SOURCE: $source');
      debugPrint('   - TYPE: $resolvedFgType');
      debugPrint('   - STABLE ID: $stableId');
      debugPrint('   - ANDROID NOTIFICATION ID: $notificationId');
      debugPrint('   - ACTIONS COUNT: ${actions?.length ?? 0}');
      debugPrint('   - ACTION IDS: $actionIds');

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

      if (actionId == 'like_action') {
        final rawPostId =
            data['post_id'] ??
            (data['data'] is Map ? data['data']['post_id'] : null);
        final String? postId = rawPostId?.toString();
        if (postId == null || postId.isEmpty || postId == '0') {
          debugPrint(
            "⚠️ No post_id in notification payload for action: $actionId",
          );
          return;
        }

        debugPrint("📬 Action: Like post $postId");
        final responseApi = await ApiService.togglePostLike(postId);
        debugPrint(
          "📬 Post like success: ${responseApi['success']}, message: ${responseApi['message']}",
        );

        final int? notificationId = response.id;
        if (notificationId != null) {
          try {
            await NotificationService()._localNotifications.cancel(
              notificationId,
            );
          } catch (e) {
            debugPrint("⚠️ Error cancelling notification after like: $e");
          }
        }
        return;
      }

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
      final String? chatId = rawChatId?.toString();
      if (chatId == null || chatId.isEmpty) {
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

            final bool isAiNewPost =
                content.type.trim().toUpperCase() == 'AI_NEW_POST';

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
                (isAiNewPost ||
                    rawSenderProfile == 'null' ||
                    rawSenderProfile == '')
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

            final List<String> actionIds = actions.map((a) => a.id).toList();
            debugPrint('🚨 [POPUP DISPLAY] SHOWING NOTIFICATION:');
            debugPrint('   - SOURCE: INLINE_REPLY_UPDATE');
            debugPrint('   - TYPE: NEW_MESSAGE');
            debugPrint('   - STABLE ID: $notificationId');
            debugPrint('   - ANDROID NOTIFICATION ID: $notificationId');
            debugPrint('   - ACTIONS COUNT: ${actions.length}');
            debugPrint('   - ACTION IDS: $actionIds');

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

  static String generateStableNotificationId(Map<String, dynamic> data) =>
      _generateStableNotificationId(data);

  static String _generateStableNotificationId(Map<String, dynamic> data) {
    final explicitStableId =
        data['stable_notification_id'] ?? data['stable_id'];
    if (explicitStableId != null &&
        explicitStableId.toString().trim().isNotEmpty) {
      return explicitStableId.toString().trim();
    }

    Map<String, dynamic>? notificationData;
    if (data['notification'] is Map) {
      notificationData = Map<String, dynamic>.from(data['notification'] as Map);
    } else if (data['notification'] is String) {
      try {
        final decoded = jsonDecode(data['notification'] as String);
        if (decoded is Map) {
          notificationData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    } else if (data['data'] is Map) {
      notificationData = Map<String, dynamic>.from(data['data'] as Map);
    }

    dynamic getValue(String key) {
      final val =
          data[key] ?? (notificationData != null ? notificationData[key] : null);
      if (val == null) return null;
      final valStr = val.toString().trim();
      if (valStr == 'null' || valStr == '0' || valStr.isEmpty) {
        return null;
      }
      return valStr;
    }

    final id =
        getValue('id') ??
        getValue('notification_id') ??
        getValue('event_id') ??
        getValue('comment_id');

    if (id != null) {
      return id.toString();
    }

    final messageId = getValue('message_id');
    if (messageId != null &&
        !messageId.startsWith('bg_') &&
        !messageId.startsWith('fg_')) {
      return messageId.toString();
    }

    final type =
        (getValue('type') ?? getValue('notification_type') ?? 'general')
            .toString()
            .toUpperCase();
    final title = getValue('title') ?? '';
    final body = getValue('body') ?? getValue('message_preview') ?? '';
    final postId = getValue('post_id') ?? '';
    final chatId = getValue('chat_id') ?? '';
    final senderId = getValue('sender_id') ?? getValue('user_id') ?? '';

    final fingerprint =
        '${type}_${senderId}_${postId}_${chatId}_${title}_$body';
    return fingerprint;
  }

  static Future<bool> _checkAndMarkActionProcessed(
    NotificationResponse response,
  ) async {
    try {
      final String? jsonStr = await SharedPrefService.getString(
        'processed_notification_actions',
      );
      List<String> processedActions = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          processedActions = List<String>.from(jsonDecode(jsonStr));
        } catch (_) {}
      }

      final String payloadStr = response.payload ?? '';
      final String inputStr = response.input ?? '';
      final int responseId = response.id ?? payloadStr.hashCode;
      final String actionKey =
          'action_${responseId}_${response.actionId}_${inputStr.hashCode}_${payloadStr.hashCode}';

      if (processedActions.contains(actionKey)) {
        return true;
      }

      processedActions.add(actionKey);
      if (processedActions.length > 100) {
        processedActions.removeAt(0);
      }

      await SharedPrefService.setString(
        'processed_notification_actions',
        jsonEncode(processedActions),
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error checking/marking notification action: $e');
      return false;
    }
  }

  static final Set<String> _processedTapIds = <String>{};

  static Future<bool> _checkAndMarkTapProcessed(String tapKey) async {
    if (tapKey.isEmpty) return false;

    if (_processedTapIds.contains(tapKey)) {
      return true;
    }
    _processedTapIds.add(tapKey);
    if (_processedTapIds.length > 200) {
      _processedTapIds.remove(_processedTapIds.first);
    }

    try {
      final String? jsonStr = await SharedPrefService.getString(
        'processed_tap_ids',
      );
      List<String> processedIds = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          processedIds = List<String>.from(jsonDecode(jsonStr));
        } catch (_) {}
      }

      if (processedIds.contains(tapKey)) {
        return true;
      }

      processedIds.add(tapKey);
      if (processedIds.length > 100) {
        processedIds.removeAt(0);
      }

      await SharedPrefService.setString(
        'processed_tap_ids',
        jsonEncode(processedIds),
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error checking/marking tap processed: $e');
      return false;
    }
  }

  static Future<bool> _checkAndMarkNotificationProcessed(
    String stableId,
  ) async {
    if (stableId.isEmpty) return false;

    // 1. Synchronously check and mark in-memory to eliminate async race condition
    if (_processedNotificationIds.contains(stableId)) {
      return true;
    }
    _processedNotificationIds.add(stableId);
    if (_processedNotificationIds.length > 200) {
      _processedNotificationIds.remove(_processedNotificationIds.first);
    }

    // 2. Persisted check & sync with SharedPreferences (for background/cold-start deduplication)
    try {
      final String? jsonStr = await SharedPrefService.getString(
        'processed_notification_ids',
      );
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

      await SharedPrefService.setString(
        'processed_notification_ids',
        jsonEncode(processedIds),
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error checking/marking notification: $e');
      return false;
    }
  }

  static Future<void> _savePendingTapToPrefs(
    NotificationResponse response,
  ) async {
    try {
      if (response.payload != null) {
        await SharedPrefService.setString(
          'pending_local_notification_tap',
          response.payload!,
        );
        if (response.actionId != null) {
          await SharedPrefService.setString(
            'pending_local_notification_action',
            response.actionId!,
          );
        } else {
          await SharedPrefService.removeKey(
            'pending_local_notification_action',
          );
        }
        debugPrint(
          '💾 Saved pending local notification tap to SharedPreferences',
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving pending tap to prefs: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationTapped(
    NotificationResponse response,
  ) async {
    if (response.payload != null) {
      try {
        debugPrint("Payload: ${response.payload}");
        final data = jsonDecode(response.payload!);

        if (response.actionId == 'mark_read_action' ||
            response.actionId == 'reply_action' ||
            response.actionId == 'accept_request_action' ||
            response.actionId == 'reject_request_action' ||
            response.actionId == 'like_action') {
          final isAlreadyProcessed = await _checkAndMarkActionProcessed(
            response,
          );
          if (isAlreadyProcessed) {
            debugPrint(
              '📬 _onNotificationTapped: Action already processed. Skipping.',
            );
            return;
          }
          _handleNotificationAction(response);
          return;
        }

        final stableId = _generateStableNotificationId(data);
        final String tapKey = '${stableId}_${response.actionId ?? 'body'}';

        // Prevent duplicate tap processing
        final isProcessed = await _checkAndMarkTapProcessed(tapKey);
        if (isProcessed) {
          debugPrint(
            '📬 _onNotificationTapped: tapKey $tapKey already processed. Skipping.',
          );
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
          await SharedPrefService.setString(
            'last_processed_notification_id',
            stableId,
          );
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
  Future<void> connectToWebSocket(
    String accessToken, {
    bool forceReconnect = false,
  }) async {
    if (_isConnecting) {
      debugPrint('⚠️ WebSocket: Connection in progress...');
      return;
    }

    if (!forceReconnect && _channel != null) {
      debugPrint('⚠️ WebSocket: Already connected');
      return;
    }

    if (forceReconnect && _channel != null) {
      _cleanupWebSocket();
    }

    if (accessToken.isEmpty) {
      debugPrint('❌ WebSocket: No access token');
      return;
    }

    try {
      _isConnecting = true;
      _shouldStayConnected = true;

      final wsUrl =
          '${ApiConfig.wsBaseUrl}/ws/notifications/?token=$accessToken';
      debugPrint('🔌 Connecting Notification WebSocket: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          throw TimeoutException('WebSocket connection timed out');
        },
      );

      _streamSubscription = _channel!.stream.listen(
        (message) {
          debugPrint('📨 WebSocket message received: $message');
          _handleWebSocketNotification(message);
          _reconnectAttempts = 0;
        },
        onError: (error) {
          debugPrint('❌ Notification WebSocket error: $error');
          _handleWebSocketDisconnection();
        },
        onDone: () {
          debugPrint('🔌 Notification WebSocket closed');
          _handleWebSocketDisconnection();
        },
        cancelOnError: false,
      );

      debugPrint('✅ Notification WebSocket connected successfully');
      _isConnecting = false;
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('❌ Notification WebSocket connection failed (offline): $e');
      _isConnecting = false;
      _handleWebSocketDisconnection();
    }
  }

  Future<void> _handleWebSocketNotification(dynamic body) async {
    try {
      final data = jsonDecode(body);
      final rawMap = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final stableId = _generateStableNotificationId(rawMap);
      debugPrint('📨 [DEBUG_TRACE] WEBSOCKET NOTIFICATION RECEIVED');
      debugPrint('   - Source: WEBSOCKET');
      debugPrint('   - Stable Notification ID: $stableId');
      debugPrint('   - Title: ${rawMap['title'] ?? 'No title'}');
      debugPrint('   - Type: ${rawMap['type']}');
      debugPrint('   - Post ID: ${rawMap['post_id']}');

      final isProcessed = await _checkAndMarkNotificationProcessed(
        stableId,
      );
      if (isProcessed) {
        debugPrint(
          '⚠️ Duplicate WebSocket notification blocked: $stableId',
        );
        return;
      }

      if (_isAppInForeground) {
        await _showNativeNotificationFromData(
          rawMap,
          source: 'WEBSOCKET_FOREGROUND',
        );
      } else {
        debugPrint(
          '⏭️ App is not in foreground, WebSocket skipping popup (handled by FCM background)',
        );
      }
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket notification: $e');
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

      final response = await http
          .get(Uri.parse(absoluteUrl))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode == 200) {
        var bytes = response.bodyBytes;
        String extension = 'png';
        final cleanUrl = url.split('?').first.toLowerCase();
        if (cleanUrl.endsWith('.jpg') || cleanUrl.endsWith('.jpeg')) {
          extension = 'jpg';
        } else if (cleanUrl.endsWith('.webp')) {
          extension = 'webp';
        } else if (cleanUrl.endsWith('.gif')) {
          extension = 'gif';
        }

        if (cropToCircle) {
          try {
            var originalImage = img.decodeImage(bytes);
            if (originalImage != null) {
              if (!originalImage.hasAlpha) {
                originalImage = originalImage.convert(numChannels: 4);
              }
              final circleImage = img.copyCropCircle(originalImage);
              bytes = Uint8List.fromList(img.encodePng(circleImage));
              extension = 'png';
            }
          } catch (e) {
            debugPrint('❌ Error cropping image to circle: $e');
          }
        }
        final baseName = fileName.replaceAll(
          RegExp(r'\.(png|jpg|jpeg|webp|gif)$', caseSensitive: false),
          '',
        );
        final filePath = '${Directory.systemTemp.path}/$baseName.$extension';
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
  factory NotificationPayload.fromFCM(
    RemoteMessage message, {
    String? actionId,
  }) {
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
