import 'package:flutter/material.dart';
import '../../models/posts/homefeed_posts_model.dart';
import '../bottomsheets/comments_bottom_sheet.dart';
import '../bottomsheets/liked_users_bottom_sheet.dart';

class BottomSheetUtils {
  static void showCommentsBottomSheet({
    required BuildContext context,
    required int postId,
    String? currentUsername,
    ValueChanged<int>? onCommentsCountChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        currentUsername: currentUsername,
        onCommentsCountChanged: onCommentsCountChanged,
      ),
    );
  }

  static void showLikedUsersBottomSheet({
    required BuildContext context,
    required int postId,
    required List<LikeUser> initialLikedUsers,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          LikedUsersBottomSheet(likedUsers: initialLikedUsers, postId: postId),
    );
  }
}
