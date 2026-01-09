import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../provider/user_provider.dart';
import '../api_service.dart';

class LikeService {
  // Singleton pattern
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  // Cache to track ongoing like operations
  final Map<int, bool> _ongoingOperations = {};

  /// Toggle like for a post with optimistic UI update
  /// Returns updated like state and count
  Future<LikeResult> togglePostLike({
    required BuildContext context,
    required int postId,
    required bool currentLikeState,
    required int currentLikesCount,
  }) async {
    // Prevent multiple simultaneous requests for same post
    if (_ongoingOperations[postId] == true) {
      return LikeResult(
        success: false,
        isLiked: currentLikeState,
        likesCount: currentLikesCount,
        message: 'Request already in progress',
      );
    }

    _ongoingOperations[postId] = true;

    // Calculate optimistic values
    final optimisticLikeState = !currentLikeState;
    final optimisticLikesCount = currentLikeState
        ? currentLikesCount - 1
        : currentLikesCount + 1;

    try {
      final response = await ApiService.togglePostLike(postId);

      if (response['success'] == true) {
        // Extract server data
        final data = response['data'];
        final serverLikesCount = data?['likes_count'] ?? optimisticLikesCount;
        final serverLikeState = data?['is_liked'] ?? optimisticLikeState;

        return LikeResult(
          success: true,
          isLiked: serverLikeState,
          likesCount: serverLikesCount,
          message: 'Success',
        );
      } else {
        // Revert to original state on failure
        return LikeResult(
          success: false,
          isLiked: currentLikeState,
          likesCount: currentLikesCount,
          message: response['message'] ?? 'Failed to update like',
        );
      }
    } catch (e) {
      // Revert to original state on error
      return LikeResult(
        success: false,
        isLiked: currentLikeState,
        likesCount: currentLikesCount,
        message: 'Unable to update like',
      );
    } finally {
      _ongoingOperations.remove(postId);
    }
  }

  /// Check if current user has liked the post
  static bool hasUserLikedPost(List<dynamic> viewLikes, String? currentUsername) {
    if (currentUsername == null || currentUsername.isEmpty) return false;
    return viewLikes.any(
      (user) => user.username?.toLowerCase() == currentUsername.toLowerCase(),
    );
  }

  /// Get formatted like count text
  static String getLikesCountText(int likesCount) {
    if (likesCount <= 0) return '';
    if (likesCount >= 1000000) {
      return '${(likesCount / 1000000).toStringAsFixed(1)}M';
    }
    if (likesCount >= 1000) {
      return '${(likesCount / 1000).toStringAsFixed(1)}k';
    }
    return likesCount.toString();
  }

  /// Get current username from UserProvider
  static String? getCurrentUsername(BuildContext context) {
    try {
      return Provider.of<UserProvider>(context, listen: false).username;
    } catch (e) {
      return null;
    }
  }

  /// Clear cache (call when needed, e.g., on logout)
  void clearCache() {
    _ongoingOperations.clear();
  }
}

/// Result class for like operations
class LikeResult {
  final bool success;
  final bool isLiked;
  final int likesCount;
  final String message;

  LikeResult({
    required this.success,
    required this.isLiked,
    required this.likesCount,
    required this.message,
  });
}