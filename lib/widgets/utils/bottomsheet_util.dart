import 'package:flutter/material.dart';
import '../bottomsheets/add_member_bottom_sheet.dart';
import '../bottomsheets/comments_bottom_sheet.dart';
import '../bottomsheets/liked_users_bottom_sheet.dart';
import '../bottomsheets/post_voters_bottom_sheet.dart';

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
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LikedUsersBottomSheet(postId: postId),
    );
  }

  static void showPostVotersBottomSheet({
    required BuildContext context,
    required int pollId,
    required int optionId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostVotersBottomSheet(pollId: pollId, optionId: optionId),
    );
  }


  static Future<Map<String, dynamic>?> showAddMembersBottomSheet({
  required BuildContext context,
  Set<int> alreadySelected = const {},
}) async {
  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddMemberBottomSheet(
      alreadySelected: alreadySelected,
    ),
  );
}

}
