// lib/core/navigation/notification_router.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../screens/home/home_imports.dart';
import '../../screens/home/notifications/notification_details.dart';
import '../../screens/home/profile/public/public_profile.dart';

/// ✅ PROFESSIONAL: Centralized notification routing service
/// Handles all notification-based navigation (cold start, background, foreground)
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

  /// Check if there's a pending notification that hasn't been handled
  bool hasPendingNotification() {
    return _pendingNotification != null && !_hasNavigated;
  }

  /// ✅ ENHANCED: Resolve the destination widget DIRECTLY
  /// This is called from _getInitialScreen() in main.dart (cold start)
  /// Returns the appropriate screen based on notification type
  Future<Widget?> resolveDestination() async {
    if (_pendingNotification == null || _hasNavigated) {
      debugPrint('📬 NotificationRouter: No pending notification or already handled');
      return null;
    }

    // _hasNavigated = true; // REMOVED: Allow multiple checks until cleared by consumer (HomeScreen)
    final message = _pendingNotification!;
    
    // ✅ Extract data handling nested 'notification' object if present
    final rawData = message.data;
    final notificationData = rawData['notification'] is Map 
        ? rawData['notification'] as Map<String, dynamic> 
        : rawData;
        
    // Merge them to be safe (prefer specific notification data)
    final Map<String, dynamic> data = {
      ...rawData,
      ...notificationData,
    };

    final type = (data['type'] ?? '').toString().toLowerCase().trim();

    debugPrint('🚀 NotificationRouter.resolveDestination()');
    debugPrint('   Type: "$type"');
    debugPrint('   Data keys: ${data.keys.toList()}');
    debugPrint('   Full data: $data');

    try {
      // ✅ Handle post-related notifications (like, comment, vote)
      if (type == 'like' || 
          type == 'comment' || 
          type == 'commetnt' ||  // backend typo
          type == 'vote' ||
          type == 'reply') {
        
        final postId = _parseToInt(data['post_id'], 'post_id');
        debugPrint('   📝 Post notification - postId: $postId');
        
        if (postId > 0) {
          debugPrint('✅ Resolving to NotificationDetails (postId: $postId)');
          return NotificationDetails(postId: postId);
        } else {
          debugPrint('❌ Invalid post_id: ${data['post_id']}');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
      } 
      // ✅ Handle follow notifications
      else if (type == 'follow') {
        final userId = _parseToInt(data['sender_id'], 'sender_id');
        debugPrint('   👤 Follow notification - userId: $userId');
        
        if (userId > 0) {
          debugPrint('✅ Resolving to PublicProfile (userId: $userId)');
          return PublicProfile(userId: userId);
        } else {
          debugPrint('❌ Invalid sender_id: ${data['sender_id']}');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
      } 
      else {
        debugPrint('⚠️ Unknown notification type: "$type"');
        debugPrint('   Available keys: ${data.keys.toList()}');
      }
    } catch (e) {
      debugPrint('❌ Error resolving notification destination: $e');
    }
    return const HomeScreen(initialIndex: 3);
  }

  /// ✅ ENHANCED: Handle navigation imperatively (background / foreground taps)
  /// This is used when the app is already running
  Future<void> handlePendingNotification(BuildContext context) async {
    if (_pendingNotification == null || _hasNavigated) {
      debugPrint('📬 NotificationRouter: No pending notification or already handled');
      return;
    }

    _hasNavigated = true;
    final message = _pendingNotification!;

    debugPrint('⏳ NotificationRouter: Waiting for context to be ready...');
    // Small delay to ensure context is ready
    await Future.delayed(const Duration(milliseconds: 600));

    if (!context.mounted) {
      debugPrint('❌ NotificationRouter: Context not mounted, aborting navigation');
      return;
    }

    debugPrint('✅ NotificationRouter: Context mounted, proceeding with navigation');
    _navigateBasedOnType(context, message);
  }

  /// Navigate to the appropriate screen based on notification type
  void _navigateBasedOnType(BuildContext context, RemoteMessage message) {
    // ✅ Extract data handling nested 'notification' object
    final rawData = message.data;
    final notificationData = rawData['notification'] is Map 
        ? rawData['notification'] as Map<String, dynamic> 
        : rawData;
        
    // Merge them
    final Map<String, dynamic> data = {
      ...rawData,
      ...notificationData,
    };

    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    debugPrint('🧭 Routing notification type: "$type"');
    debugPrint('📋 Full data: $data');

    try {
      // ✅ Handle post-related notifications
      if (type == 'like' || 
          type == 'comment' || 
          type == 'commetnt' ||
          type == 'vote' ||
          type == 'reply') {
        _navigateToPost(context, data);
      } 
      // ✅ Handle follow notifications
      else if (type == 'follow') {
        _navigateToProfile(context, data);
      } 
      else {
        debugPrint('⚠️ Unknown notification type: "$type"');
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
    final postId = _parseToInt(data['post_id'], 'post_id');
    
    debugPrint('📝 Attempting to navigate to post');
    debugPrint('   Raw post_id: ${data['post_id']}');
    debugPrint('   Parsed postId: $postId');
    debugPrint('   Data keys: ${data.keys.toList()}');
    
    if (postId > 0) {
      debugPrint('✅ Navigating to NotificationDetails (postId: $postId)');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotificationDetails(postId: postId),
        ),
      );
    } else {
      debugPrint('❌ Invalid post_id, navigating to notifications tab');
      debugPrint('   Available data: $data');
      _navigateToNotificationsTab(context);
    }
  }

  /// Navigate to user profile screen
  void _navigateToProfile(BuildContext context, Map<String, dynamic> data) {
    final userId = _parseToInt(data['sender_id'], 'sender_id');
    
    debugPrint('👤 Attempting to navigate to profile');
    debugPrint('   Raw sender_id: ${data['sender_id']}');
    debugPrint('   Parsed userId: $userId');
    
    if (userId > 0) {
      debugPrint('✅ Navigating to PublicProfile (userId: $userId)');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicProfile(userId: userId),
        ),
      );
    } else {
      debugPrint('❌ Invalid sender_id, navigating to notifications tab');
      _navigateToNotificationsTab(context);
    }
  }

  /// ✅ ENHANCED: Safe integer parsing with validation and detailed logging
  int _parseToInt(dynamic value, String fieldName) {
    debugPrint('🔍 Parsing $fieldName: $value (type: ${value.runtimeType})');
    
    if (value == null) {
      debugPrint('⚠️ $fieldName is null');
      return 0;
    }

    if (value is int) {
      debugPrint('✅ $fieldName is already int: $value');
      return value;
    }

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed == null) {
        debugPrint('❌ Failed to parse $fieldName: "$value"');
        return 0;
      }
      return parsed;
    }

    debugPrint('⚠️ $fieldName has unexpected type: ${value.runtimeType}');
    return 0;
  }

  /// Navigate to notifications tab as fallback
  void _navigateToNotificationsTab(BuildContext context) {
    debugPrint('🔔 Navigating to notifications tab (fallback)');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 3),
      ),
      (route) => false,
    );
  }

  /// Clear pending notification after handling
  void clear() {
    _pendingNotification = null;
    _hasNavigated = false;
    debugPrint('📬 NotificationRouter: Cleared');
  }

  /// Get current pending notification data (for debugging)
  Map<String, dynamic>? getPendingNotificationData() {
    return _pendingNotification?.data;
  }

  /// Check if a specific notification type is pending
  bool isPendingNotificationType(String type) {
    if (_pendingNotification == null) return false;
    final notificationType = (_pendingNotification!.data['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return notificationType == type.toLowerCase();
  }
}