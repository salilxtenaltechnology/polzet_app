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
import '../../provider/private_chat_provider.dart';
import '../../provider/group_chat_provider.dart';
import '../../data/token/shared_preferences.dart';

// PROFESSIONAL: Centralized notification routing service
class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  RemoteMessage? _pendingNotification;
  bool _hasNavigated = false;

  /// Store notification from main() when app starts from killed state
  void setPendingNotification(RemoteMessage? message) {
    _pendingNotification = message;
    _hasNavigated = false;

    if (message != null) {
      debugPrint('📬 NotificationRouter: Stored pending notification');
      debugPrint('   Type: ${message.data['type']}');
      debugPrint('   post_id: ${message.data['post_id']}');
      debugPrint('   sender_id: ${message.data['sender_id']}');
      debugPrint('   All data: ${message.data}');
    }
  }

  bool hasPendingNotification() {
    return _pendingNotification != null && !_hasNavigated;
  }

  String? _getNotificationUniqueId(RemoteMessage message) {
    return message.messageId ?? 
           (message.data['post_id'] != null ? 'post_${message.data['post_id']}' : null) ?? 
           (message.data['sender_id'] != null ? 'sender_${message.data['sender_id']}' : null);
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

    if (msgId != null) {
      final lastProcessedId = await SharedPrefService.getString('last_processed_notification_id');
      if (lastProcessedId == msgId) {
        debugPrint('📬 NotificationRouter: Notification $msgId was already processed. Skipping resolving.');
        _pendingNotification = null;
        _hasNavigated = false;
        return null;
      }
    }

    // _hasNavigated = true;
    // REMOVED: Allow multiple checks until cleared by consumer (HomeScreen)

    final rawData = message.data;
    final notificationData = rawData['notification'] is Map
        ? rawData['notification'] as Map<String, dynamic>
        : rawData;

    // Merge them to be safe (prefer specific notification data)
    final Map<String, dynamic> data = {...rawData, ...notificationData};

    final type = (data['type'] ?? '').toString().toLowerCase().trim();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isUserDataValid()) {
      debugPrint('⏳ NotificationRouter: Waiting for UserProvider data...');
      userProvider.loadUserDataSilently();
      await userProvider.waitForUserData(timeout: const Duration(seconds: 3));
    }
    final String username = userProvider.username ?? '';

    debugPrint('🚀 NotificationRouter.resolveDestination()');
    debugPrint('   Type: "$type"');
    debugPrint('   Data keys: ${data.keys.toList()}');
    debugPrint('   Full data: $data');
    debugPrint('   Username: "$username"');

    try {
      // ✅ Handle post-related notifications (like, comment, vote)
      if (type == 'like' ||
          type == 'like_group' ||
          type == 'comment' ||
          type == 'commetnt' || // backend type
          type == 'vote' ||
          type == 'reply') {
        final String? postId = data['post_id']?.toString();
        debugPrint('   📝 Post notification - postId: $postId');

        if (postId != null && postId.isNotEmpty && postId != '0') {
          if (username.isEmpty) {
            debugPrint('⚠️ NotificationRouter: username is empty, fallback to notifications tab');
            return const HomeScreen(initialIndex: 3);
          }
          return SinglePostDetails(postId: postId,  username: username,);
        } else {
          debugPrint('❌ Invalid post_id: ${data['post_id']}');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
      } else if (type == 'follow') {
        final String? userId = data['sender_id']?.toString();
        debugPrint('   👤 Follow notification - userId: $userId');

        if (userId != null && userId.isNotEmpty) {
          return PublicProfileScreen(userId: userId);
        } else {
          debugPrint('❌ Invalid sender_id: ${data['sender_id']}');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
      } else if (type == 'follow_group') {
        return UserChase(
          username: username,
          initialIndex: 0,
          followerCount: userProvider.followers_count ?? '0',
          followingCount: userProvider.following_count ?? '0',
          chaseList: userProvider.chase_list,
          rechaseList: userProvider.rechase_list,
        );
      } else if (type == 'new_message' ||
          type == 'new_group_added' ||
          type == 'group_admin_promote') {
        final meta = data['meta'] is Map ? data['meta'] as Map<String, dynamic> : null;
        final chatId = _parseToInt(data['chat_id'] ?? meta?['chat_id']);
        final groupName = (data['group_name'] ?? meta?['group_name'])?.toString() ?? '';
        final senderId = _parseToInt(data['sender_id'] ?? meta?['sender_id']);
        final memberName = (data['sender'] ?? meta?['sender'] ?? 'Chat').toString();
        final profileUrl = (data['sender_profile_image'] ?? data['profile_image'])?.toString();

        if (chatId > 0) {
          if (groupName.isNotEmpty) {
            return ChangeNotifierProvider(
              create: (_) => GroupChatProvider(),
              child: GroupChatScreen(
                groupName: groupName,
                chatId: chatId,
              ),
            );
          } else {
            return ChangeNotifierProvider(
              create: (_) => PrivateChatProvider(),
              child: PrivateChatScreen(
                userId: senderId,
                memberName: memberName,
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
      final lastProcessedId = await SharedPrefService.getString('last_processed_notification_id');
      if (lastProcessedId == msgId) {
        debugPrint('📬 NotificationRouter: Notification $msgId was already processed. Skipping handling.');
        _pendingNotification = null;
        _hasNavigated = false;
        return;
      }
      await SharedPrefService.setString('last_processed_notification_id', msgId);
      debugPrint('📬 NotificationRouter: Persisted processed notification ID: $msgId');
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (!context.mounted) {
      return;
    }

    _navigateBasedOnType(context, message);
  }

  void _navigateBasedOnType(BuildContext context, RemoteMessage message) {
    final rawData = message.data;
    final notificationData = rawData['notification'] is Map
        ? rawData['notification'] as Map<String, dynamic>
        : rawData;

    final Map<String, dynamic> data = {...rawData, ...notificationData};

    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    debugPrint('🧭 Routing notification type: "$type"');
    debugPrint('📋 Full data: $data');

    try {
      if (type == 'like' ||
          type == 'like_group' ||
          type == 'comment' ||
          type == 'commetnt' ||
          type == 'vote' ||
          type == 'reply') {
        _navigateToPost(context, data);
      } else if (type == 'follow') {
        _navigateToProfile(context, data);
      } else if (type == 'follow_group') {
        _navigateToUserChase(context);
      } else if (type == 'new_message' ||
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
          chaseList: userProvider.chase_list,
          rechaseList: userProvider.rechase_list,
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, Map<String, dynamic> data) {
    final meta = data['meta'] is Map ? data['meta'] as Map<String, dynamic> : null;
    final chatId = _parseToInt(data['chat_id'] ?? meta?['chat_id']);
    final groupName = (data['group_name'] ?? meta?['group_name'])?.toString() ?? '';
    final senderId = _parseToInt(data['sender_id'] ?? meta?['sender_id']);
    final memberName = (data['sender'] ?? meta?['sender'] ?? 'Chat').toString();
    final profileUrl = (data['sender_profile_image'] ?? data['profile_image'])?.toString();

    if (chatId > 0) {
      if (groupName.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => GroupChatProvider(),
              child: GroupChatScreen(
                groupName: groupName,
                chatId: chatId,
              ),
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
      if (username.isEmpty) {
        debugPrint('⚠️ NotificationRouter: username is empty, falling back to notifications tab');
        _navigateToNotificationsTab(context);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SinglePostDetails(postId: postId,  username: username,)),
      );
    } else {
      _navigateToNotificationsTab(context);
    }
  }

  void _navigateToProfile(BuildContext context, Map<String, dynamic> data) {
    final String? userId = data['sender_id']?.toString();

    if (userId != null && userId.isNotEmpty) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)));
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
        SharedPrefService.setString('last_processed_notification_id', msgId);
        debugPrint('📬 NotificationRouter: Marked $msgId as processed in clear()');
      }
    }
    _pendingNotification = null;
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
