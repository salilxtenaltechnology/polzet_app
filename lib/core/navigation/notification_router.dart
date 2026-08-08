import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:polzet_app/screens/home/search/posts/single_post_details.dart';
import 'package:provider/provider.dart';

import '../../provider/user_provider.dart';
import '../../screens/home/home_imports.dart';
import '../../screens/home/profile/public/public_profile_screen.dart';
import '../../screens/home/profile/chase/user_chase.dart';
import '../../screens/home/message/chat/private/private_chat_screen.dart';
import '../../screens/home/message/chat/group/group_chat_screen.dart';
import '../../screens/home/message/chat/group/group_members.dart';
import '../../screens/home/new poll/type/new_text_poll.dart';
import '../../provider/private_chat_provider.dart';
import '../../provider/group_chat_provider.dart';
import '../../data/token/shared_preferences.dart';

// PROFESSIONAL: Centralized notification routing service
class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  static bool isHomeScreenVisible = false;

  RemoteMessage? _pendingNotification;
  String? _pendingActionId;
  bool _bypassDuplicateCheck = false;
  bool _hasNavigated = false;

  /// Store notification from main() when app starts from killed state
  void setPendingNotification(
    RemoteMessage? message, {
    String? actionId,
    bool bypassDuplicateCheck = false,
  }) {
    _pendingNotification = message;
    _pendingActionId = actionId;
    _bypassDuplicateCheck = bypassDuplicateCheck;
    _hasNavigated = false;

    if (message != null) {
      debugPrint('📬 NotificationRouter: Stored pending notification');
      debugPrint('   Type: ${message.data['type']}');
      debugPrint('   post_id: ${message.data['post_id']}');
      debugPrint('   sender_id: ${message.data['sender_id']}');
      debugPrint('   actionId: $actionId');
      debugPrint('   bypassDuplicateCheck: $bypassDuplicateCheck');
      debugPrint('   All data: ${message.data}');
    }
  }

  bool hasPendingNotification() {
    return _pendingNotification != null && !_hasNavigated;
  }

  String? _getNotificationUniqueId(RemoteMessage message) {
    if (message.messageId != null && message.messageId!.isNotEmpty) {
      return message.messageId;
    }

    final data = message.data;
    Map<String, dynamic> payloadMap = Map<String, dynamic>.from(data);
    if (payloadMap.containsKey('data') && payloadMap['data'] is Map) {
      payloadMap.addAll(Map<String, dynamic>.from(payloadMap['data'] as Map));
    }

    String? getValue(String key) {
      final val = payloadMap[key]?.toString().trim();
      if (val == null || val == 'null' || val == '0' || val.isEmpty) {
        return null;
      }
      return val;
    }

    final postId = getValue('post_id');
    if (postId != null) return 'post_$postId';

    final senderId = getValue('sender_id');
    if (senderId != null) return 'sender_$senderId';

    return null;
  }

  Future<bool> _isNotificationAlreadyProcessed(String msgId) async {
    try {
      final String? jsonStr = await SharedPrefService.getString(
        'processed_notification_ids',
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> processedIds = jsonDecode(jsonStr);
        if (processedIds.contains(msgId)) {
          return true;
        }
      }

      final lastProcessedId = await SharedPrefService.getString(
        'last_processed_notification_id',
      );
      if (lastProcessedId == msgId) {
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error checking processed notification in Router: $e');
    }
    return false;
  }

  Future<void> _markNotificationAsProcessed(String msgId) async {
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
      if (!processedIds.contains(msgId)) {
        processedIds.add(msgId);
        if (processedIds.length > 100) {
          processedIds.removeAt(0);
        }
        await SharedPrefService.setString(
          'processed_notification_ids',
          jsonEncode(processedIds),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as processed in Router: $e');
    }
    await SharedPrefService.setString('last_processed_notification_id', msgId);
  }

  /// ✅ ENHANCED: Resolve the destination widget DIRECTLY
  Future<Widget?> resolveDestination(BuildContext context) async {
    if (_pendingNotification == null || _hasNavigated) {
      debugPrint(
        '📬 NotificationRouter: No pending notification or already handled',
      );
      return null;
    }

    final message = _pendingNotification!;
    final String? msgId = _getNotificationUniqueId(message);

    if (msgId != null && !_bypassDuplicateCheck) {
      final isProcessed = await _isNotificationAlreadyProcessed(msgId);
      if (isProcessed) {
        debugPrint(
          '📬 NotificationRouter: Notification $msgId was already processed. Skipping resolving.',
        );
        _pendingNotification = null;
        _hasNavigated = false;
        return null;
      }
    }

    // _hasNavigated = true;
    // REMOVED: Allow multiple checks until cleared by consumer (HomeScreen)

    final rawData = message.data;
    Map<String, dynamic> payloadMap = Map<String, dynamic>.from(rawData);
    if (payloadMap.containsKey('data') && payloadMap['data'] is Map) {
      payloadMap.addAll(Map<String, dynamic>.from(payloadMap['data'] as Map));
    }

    Map<String, dynamic> notificationData = {};
    if (payloadMap['notification'] is Map) {
      notificationData = Map<String, dynamic>.from(payloadMap['notification']);
    } else if (payloadMap['notification'] is String) {
      try {
        notificationData =
            jsonDecode(payloadMap['notification'] as String)
                as Map<String, dynamic>;
      } catch (_) {}
    } else {
      notificationData = payloadMap;
    }

    // Merge them to be safe (prefer specific notification data)
    final Map<String, dynamic> data = {...payloadMap, ...notificationData};

    final rawType = (data['type'] ?? '').toString().trim();
    final type = rawType.toLowerCase();
    final pollType = (data['poll_type'] ?? '').toString().toLowerCase().trim();

    final bool needsUserData =
        (type == 'like' ||
        type == 'like_group' ||
        type == 'comment' ||
        type == 'commetnt' ||
        type == 'vote' ||
        type == 'reply' ||
        type == 'follow_group' ||
        type == 'new_post');

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (needsUserData && !userProvider.isUserDataValid()) {
      debugPrint('⏳ NotificationRouter: Waiting for UserProvider data...');
      userProvider.loadUserDataSilently();
      await userProvider.waitForUserData(timeout: const Duration(seconds: 3));
    }
    final String username = userProvider.username ?? '';

    debugPrint('🚀 NotificationRouter.resolveDestination()');
    debugPrint('   Type: "$type", PollType: "$pollType"');
    debugPrint('   Data keys: ${data.keys.toList()}');
    debugPrint('   Full data: $data');
    debugPrint('   Username: "$username"');

    try {
      if (_pendingActionId == 'create_poll_action' ||
          (rawType.toUpperCase() == 'AI_NEW_POST' && pollType == 'text')) {
        final String title = data['title']?.toString() ?? '';
        final String body =
            data['body']?.toString() ??
            data['post_description']?.toString() ??
            '';
        debugPrint(
          '   🤖 AI_NEW_POST text poll resolved - Title: $title, Body: $body',
        );
        return NewTextPoll(
          initialQuestion: title,
          initialDescription: body,
        );
      }

      // ✅ Handle post-related notifications (like, comment, vote, new_post)
      if (_pendingActionId == 'view_post_action' ||
          _pendingActionId == 'vote_now_action' ||
          _pendingActionId == 'pick_side_action' ||
          _pendingActionId == 'vote_privately_action' ||
          type == 'like' ||
          type == 'like_group' ||
          type == 'comment' ||
          type == 'commetnt' || // backend type
          type == 'vote' ||
          type == 'reply' ||
          type == 'new_post' ||
          type == 'poll') {
        final String? postId = data['post_id']?.toString();
        debugPrint('   📝 Post notification - postId: $postId');

        if (postId != null && postId.isNotEmpty && postId != '0') {
          final String postSender = (type == 'new_post' || type == 'poll')
              ? (data['sender']?.toString() ?? '')
              : '';
          final String postUsername = postSender.isNotEmpty
              ? postSender
              : username;
          if (postUsername.isEmpty) {
            debugPrint(
              '⚠️ NotificationRouter: username is empty, fallback to notifications tab',
            );
            return const HomeScreen(initialIndex: 3);
          }
          return SinglePostDetails(postId: postId, username: postUsername);
        } else {
          debugPrint('❌ Invalid post_id: ${data['post_id']}');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
      } else if (_pendingActionId == 'view_profile_action' ||
          _pendingActionId == 'follow_back_action' ||
          type == 'follow' ||
          type == 'friend_request' ||
          type == 'friend_requests') {
        dynamic actorData = data['actor'];
        if (actorData is String && actorData.isNotEmpty) {
          try {
            actorData = jsonDecode(actorData);
          } catch (_) {}
        }

        dynamic metaData = data['meta'];
        if (metaData is String && metaData.isNotEmpty) {
          try {
            metaData = jsonDecode(metaData);
          } catch (_) {}
        }

        final String? userId =
            data['sender_id']?.toString() ??
            data['sender_uuid']?.toString() ??
            (actorData is Map
                ? actorData['user_id']?.toString() ??
                      actorData['id']?.toString() ??
                      actorData['user_uuid']?.toString()
                : null) ??
            (metaData is Map ? metaData['sender_id']?.toString() : null) ??
            data['user_id']?.toString() ??
            data['userId']?.toString();
        debugPrint('   👤 Follow/Request notification - userId: $userId');

        final String? senderUsername =
            data['sender_username']?.toString() ??
            (actorData is Map
                ? actorData['username']?.toString() ??
                      actorData['sender']?.toString() ??
                      actorData['sender_username']?.toString() ??
                      actorData['sender_name']?.toString()
                : null) ??
            (metaData is Map
                ? metaData['sender_username']?.toString() ??
                      metaData['username']?.toString() ??
                      metaData['sender']?.toString()
                : null) ??
            data['username']?.toString() ??
            data['sender']?.toString() ??
            data['sender_name']?.toString();

        if ((userId != null && userId.isNotEmpty) ||
            (senderUsername != null && senderUsername.isNotEmpty)) {
          return PublicProfileScreen(userId: userId, username: senderUsername);
        } else {
          debugPrint('❌ Invalid sender_id/username for type: $type');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
      } else if (type == 'follow_group') {
        return UserChase(
          username: username,
          initialIndex: 0,
          followerCount: userProvider.followers_count ?? '0',
          followingCount: userProvider.following_count ?? '0',
        );
      } else if (type == 'group_join_request') {
        final meta = data['meta'] is Map
            ? data['meta'] as Map<String, dynamic>
            : null;
        final chatId = data['chat_id'] ?? meta?['chat_id'];
        if (chatId != null && chatId.toString().isNotEmpty) {
          return ChangeNotifierProvider(
            create: (_) {
              final provider = GroupChatProvider();
              provider.init(
                groupName:
                    (data['group_name'] ?? meta?['group_name'])?.toString() ??
                    'Group',
                groupImageUrl: null,
                chatId: chatId.toString(),
              );
              return provider;
            },
            child: GroupMembers(
              members: const [],
              chatId: chatId,
              initialTabIndex: 1,
            ),
          );
        }
      } else if (type == 'new_message' ||
          type == 'new_group_added' ||
          type == 'group_admin_promote') {
        final meta = data['meta'] is Map
            ? data['meta'] as Map<String, dynamic>
            : null;
        final chatId = _parseToInt(data['chat_id'] ?? meta?['chat_id']);
        final groupName =
            (data['group_name'] ?? meta?['group_name'])?.toString() ?? '';
        final senderId = _parseToInt(data['sender_id'] ?? meta?['sender_id']);
        final memberName = (data['sender'] ?? meta?['sender'] ?? 'Chat')
            .toString();
        final username =
            (data['sender_username'] ??
                    data['username'] ??
                    meta?['sender_username'] ??
                    meta?['username'])
                ?.toString();
        final rawProfileUrl =
            (data['sender_profile_image'] ?? data['profile_image'])?.toString();
        final profileUrl = (rawProfileUrl == 'null' || rawProfileUrl == '')
            ? null
            : rawProfileUrl;

        if (chatId > 0) {
          if (groupName.isNotEmpty) {
            return ChangeNotifierProvider(
              create: (_) => GroupChatProvider(),
              child: GroupChatScreen(groupName: groupName, chatId: chatId),
            );
          } else {
            return ChangeNotifierProvider(
              create: (_) => PrivateChatProvider(),
              child: PrivateChatScreen(
                userId: senderId,
                memberName: memberName,
                username: username,
                profileUrl: profileUrl,
                chatId: chatId,
              ),
            );
          }
        }
      } else {
        debugPrint('   Available keys: ${data.keys.toList()}');
      }
    } catch (e) {
      debugPrint('❌ Error resolving notification destination: $e');
    }
    return const HomeScreen(initialIndex: 3);
  }

  // ENHANCED: Handle navigation imperatively (background / foreground taps)
  Future<void> handlePendingNotification(BuildContext context) async {
    if (_pendingNotification == null || _hasNavigated) {
      debugPrint(
        '📬 NotificationRouter: No pending notification or already handled',
      );
      return;
    }

    _hasNavigated = true;
    final message = _pendingNotification!;
    final String? msgId = _getNotificationUniqueId(message);

    if (msgId != null) {
      if (!_bypassDuplicateCheck) {
        final isProcessed = await _isNotificationAlreadyProcessed(msgId);
        if (isProcessed) {
          debugPrint(
            '📬 NotificationRouter: Notification $msgId was already processed. Skipping handling.',
          );
          _pendingNotification = null;
          _hasNavigated = false;
          return;
        }
      }
      await _markNotificationAsProcessed(msgId);
      debugPrint(
        '📬 NotificationRouter: Persisted processed notification ID: $msgId',
      );
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (!context.mounted) {
      return;
    }

    _navigateBasedOnType(context, message);
  }

  void _navigateBasedOnType(BuildContext context, RemoteMessage message) {
    final rawData = message.data;
    Map<String, dynamic> payloadMap = Map<String, dynamic>.from(rawData);
    if (payloadMap.containsKey('data') && payloadMap['data'] is Map) {
      payloadMap.addAll(Map<String, dynamic>.from(payloadMap['data'] as Map));
    }

    Map<String, dynamic> notificationData = {};
    if (payloadMap['notification'] is Map) {
      notificationData = Map<String, dynamic>.from(payloadMap['notification']);
    } else if (payloadMap['notification'] is String) {
      try {
        notificationData =
            jsonDecode(payloadMap['notification'] as String)
                as Map<String, dynamic>;
      } catch (_) {}
    } else {
      notificationData = payloadMap;
    }

    final Map<String, dynamic> data = {...payloadMap, ...notificationData};

    final rawType = (data['type'] ?? '').toString().trim();
    final type = rawType.toLowerCase();
    final pollType = (data['poll_type'] ?? '').toString().toLowerCase().trim();
    debugPrint('🧭 Routing notification type: "$type", poll_type: "$pollType"');
    debugPrint('📋 Full data: $data');

    try {
      if (_pendingActionId == 'create_poll_action' ||
          (rawType.toUpperCase() == 'AI_NEW_POST' && pollType == 'text')) {
        final String title = data['title']?.toString() ?? '';
        final String body =
            data['body']?.toString() ??
            data['post_description']?.toString() ??
            '';
        debugPrint(
          '   🤖 Navigating to NewTextPoll from AI_NEW_POST notification',
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewTextPoll(
              initialQuestion: title,
              initialDescription: body,
            ),
          ),
        );
        return;
      }

      if (_pendingActionId == 'view_post_action' ||
          _pendingActionId == 'vote_now_action' ||
          _pendingActionId == 'pick_side_action' ||
          _pendingActionId == 'vote_privately_action' ||
          type == 'like' ||
          type == 'like_group' ||
          type == 'comment' ||
          type == 'commetnt' ||
          type == 'vote' ||
          type == 'reply' ||
          type == 'new_post' ||
          type == 'poll') {
        _navigateToPost(context, data);
      } else if (_pendingActionId == 'view_profile_action' ||
          _pendingActionId == 'follow_back_action' ||
          type == 'follow' ||
          type == 'friend_request' ||
          type == 'friend_requests') {
        _navigateToProfile(context, data);
      } else if (type == 'follow_group') {
        _navigateToUserChase(context);
      } else if (_pendingActionId == 'message_action' ||
          _pendingActionId == 'view_group_action' ||
          type == 'new_message' ||
          type == 'new_group_added' ||
          type == 'group_admin_promote') {
        _navigateToChat(context, data);
      } else {
        debugPrint('   Available keys: ${data.keys.toList()}');
        _navigateToNotificationsTab(context);
      }
    } catch (e) {
      debugPrint('❌ Error during notification navigation: $e');
      _navigateToNotificationsTab(context);
    }
  }

  void _navigateToUserChase(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserChase(
          username: userProvider.username ?? '',
          initialIndex: 0,
          followerCount: userProvider.followers_count ?? '0',
          followingCount: userProvider.following_count ?? '0',
        ),
      ),
    );
  }

  Future<void> _navigateToChat(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final type = data['type']?.toString().toLowerCase();
    final meta = data['meta'] is Map
        ? data['meta'] as Map<String, dynamic>
        : null;

    if (type == 'group_join_request') {
      final chatId = data['chat_id'] ?? meta?['chat_id'];
      if (chatId != null && chatId.toString().isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) {
                final provider = GroupChatProvider();
                provider.init(
                  groupName:
                      (data['group_name'] ?? meta?['group_name'])?.toString() ??
                      'Group',
                  groupImageUrl: null,
                  chatId: chatId.toString(),
                );
                return provider;
              },
              child: GroupMembers(
                members: const [],
                chatId: chatId,
                initialTabIndex: 1,
              ),
            ),
          ),
        );
        return;
      }
    }
    final chatId = _parseToInt(data['chat_id'] ?? meta?['chat_id']);
    final groupName =
        (data['group_name'] ?? meta?['group_name'])?.toString() ?? '';
    final senderId = _parseToInt(data['sender_id'] ?? meta?['sender_id']);
    final memberName = (data['sender'] ?? meta?['sender'] ?? 'Chat').toString();
    final username =
        (data['sender_username'] ??
                data['username'] ??
                meta?['sender_username'] ??
                meta?['username'])
            ?.toString();
    final rawProfileUrl =
        (data['sender_profile_image'] ?? data['profile_image'])?.toString();
    final profileUrl = (rawProfileUrl == 'null' || rawProfileUrl == '')
        ? null
        : rawProfileUrl;

    if (chatId > 0) {
      if (groupName.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => GroupChatProvider(),
              child: GroupChatScreen(groupName: groupName, chatId: chatId),
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => PrivateChatProvider(),
              child: PrivateChatScreen(
                userId: senderId,
                memberName: memberName,
                username: username,
                profileUrl: profileUrl,
                chatId: chatId,
              ),
            ),
          ),
        );
      }
    } else {
      _navigateToNotificationsTab(context);
    }
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Navigate to post details screen
  void _navigateToPost(BuildContext context, Map<String, dynamic> data) {
    final String? postId = data['post_id']?.toString();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String username = userProvider.username ?? '';

    debugPrint('📝 Attempting to navigate to post');
    debugPrint('   Raw post_id: ${data['post_id']}');
    debugPrint('   Parsed postId: $postId');
    debugPrint('   Data keys: ${data.keys.toList()}');

    if (postId != null && postId.isNotEmpty && postId != '0') {
      final String type = (data['type'] ?? '').toString().toLowerCase().trim();
      final String postSender = (type == 'new_post')
          ? (data['sender']?.toString() ?? '')
          : '';
      final String postUsername = postSender.isNotEmpty ? postSender : username;
      if (postUsername.isEmpty) {
        debugPrint(
          '⚠️ NotificationRouter: username is empty, falling back to notifications tab',
        );
        _navigateToNotificationsTab(context);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              SinglePostDetails(postId: postId, username: postUsername),
        ),
      );
    } else {
      _navigateToNotificationsTab(context);
    }
  }

  void _navigateToProfile(BuildContext context, Map<String, dynamic> data) {
    dynamic actorData = data['actor'];
    if (actorData is String && actorData.isNotEmpty) {
      try {
        actorData = jsonDecode(actorData);
      } catch (_) {}
    }

    dynamic metaData = data['meta'];
    if (metaData is String && metaData.isNotEmpty) {
      try {
        metaData = jsonDecode(metaData);
      } catch (_) {}
    }

    final String? userId =
        data['sender_id']?.toString() ??
        data['sender_uuid']?.toString() ??
        (actorData is Map
            ? actorData['user_id']?.toString() ??
                  actorData['id']?.toString() ??
                  actorData['user_uuid']?.toString()
            : null) ??
        (metaData is Map ? metaData['sender_id']?.toString() : null) ??
        data['user_id']?.toString() ??
        data['userId']?.toString();

    final String? senderUsername =
        data['sender_username']?.toString() ??
        (actorData is Map
            ? actorData['username']?.toString() ??
                  actorData['sender']?.toString() ??
                  actorData['sender_username']?.toString() ??
                  actorData['sender_name']?.toString()
            : null) ??
        (metaData is Map
            ? metaData['sender_username']?.toString() ??
                  metaData['username']?.toString() ??
                  metaData['sender']?.toString()
            : null) ??
        data['username']?.toString() ??
        data['sender']?.toString() ??
        data['sender_name']?.toString();

    if ((userId != null && userId.isNotEmpty) ||
        (senderUsername != null && senderUsername.isNotEmpty)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PublicProfileScreen(userId: userId, username: senderUsername),
        ),
      );
    } else {
      _navigateToNotificationsTab(context);
    }
  }

  void _navigateToNotificationsTab(BuildContext context) {
    debugPrint('🔔 Navigating to notifications tab (fallback)');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 3)),
      (route) => false,
    );
  }

  void clear() {
    if (_pendingNotification != null) {
      final String? msgId = _getNotificationUniqueId(_pendingNotification!);
      if (msgId != null) {
        _markNotificationAsProcessed(msgId);
        debugPrint(
          '📬 NotificationRouter: Marked $msgId as processed in clear()',
        );
      }
    }
    _pendingNotification = null;
    _pendingActionId = null;
    _bypassDuplicateCheck = false;
    _hasNavigated = false;
    debugPrint('📬 NotificationRouter: Cleared');
  }

  Map<String, dynamic>? getPendingNotificationData() {
    return _pendingNotification?.data;
  }

  bool isPendingNotificationType(String type) {
    if (_pendingNotification == null) return false;
    final notificationType = (_pendingNotification!.data['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return notificationType == type.toLowerCase();
  }
}
