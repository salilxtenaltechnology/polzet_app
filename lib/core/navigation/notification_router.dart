import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:polzet_app/screens/home/search/posts/single_post_details.dart';
import 'package:provider/provider.dart';

import '../../provider/user_provider.dart';
import '../../screens/home/home_imports.dart';
import '../../screens/home/profile/public/public_profile_screen.dart';

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

  /// ✅ ENHANCED: Resolve the destination widget DIRECTLY
  Future<Widget?> resolveDestination(BuildContext context) async {
    if (_pendingNotification == null || _hasNavigated) {
      debugPrint(
        '📬 NotificationRouter: No pending notification or already handled',
      );
      return null;
    }

    // _hasNavigated = true;
    // REMOVED: Allow multiple checks until cleared by consumer (HomeScreen)
    final message = _pendingNotification!;

    final rawData = message.data;
    final notificationData = rawData['notification'] is Map
        ? rawData['notification'] as Map<String, dynamic>
        : rawData;

    // Merge them to be safe (prefer specific notification data)
    final Map<String, dynamic> data = {...rawData, ...notificationData};

    final type = (data['type'] ?? '').toString().toLowerCase().trim();

     final userProvider = Provider.of<UserProvider>(context, listen: false);
  final String username = userProvider.username ?? '';

    debugPrint('🚀 NotificationRouter.resolveDestination()');
    debugPrint('   Type: "$type"');
    debugPrint('   Data keys: ${data.keys.toList()}');
    debugPrint('   Full data: $data');

    try {
      // ✅ Handle post-related notifications (like, comment, vote)
      if (type == 'like' ||
          type == 'comment' ||
          type == 'commetnt' || // backend type
          type == 'vote' ||
          type == 'reply') {
        final String? postId = data['post_id']?.toString();
        debugPrint('   📝 Post notification - postId: $postId');

        if (postId != null && postId.isNotEmpty && postId != '0') {
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
          type == 'comment' ||
          type == 'commetnt' ||
          type == 'vote' ||
          type == 'reply') {
        _navigateToPost(context, data);
      } else if (type == 'follow') {
        _navigateToProfile(context, data);
      } else {
        debugPrint('   Available keys: ${data.keys.toList()}');
        _navigateToNotificationsTab(context);
      }
    } catch (e) {
      debugPrint('❌ Error during notification navigation: $e');
      _navigateToNotificationsTab(context);
    }
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
