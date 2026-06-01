import 'package:flutter/material.dart';
import '../../widgets/bottomsheets/add_members/add_member_bottom_sheet.dart';
import '../../widgets/bottomsheets/comment/comments_bottom_sheet.dart';
import '../../widgets/bottomsheets/like/liked_users_bottom_sheet.dart';
import '../../widgets/bottomsheets/share/share_bottom_sheet.dart';
import '../../widgets/bottomsheets/voters/poll_voters_bottomsheet.dart';
import '../../widgets/poll/new_poll_bottomsheet.dart';

class BottomSheetUtils {


 static void showNewPollBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewPollBottomsheet(),
    );
  }

  static void showCommentsBottomSheet({
    required BuildContext context,
    required dynamic postId,
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
    required dynamic postId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LikedUsersBottomSheet(postId: postId),
    );
  }

  static void showPollVotersBottomSheet({
    required BuildContext context,
    required dynamic postId,
    required String question,
    String? pollImageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PollVotersBottomsheet(
        postId: postId,
        question: question,
        pollImageUrl: pollImageUrl,
      ),
    );
  }

  static Future<Map<String, dynamic>?> showAddMembersBottomSheet({
    required BuildContext context,
    Set<String> alreadySelected = const {},
  }) async {
    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemberBottomSheet(alreadySelected: alreadySelected),
    );
  }

  static void showShareBottomSheet({
    required BuildContext context,
    required String shareLink,
    required String username,
    required String postId,
    Function(int)? onShareSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareBottomSheet(
        shareLink: shareLink,
        username: username,
        postId: postId,
        onShareSuccess: onShareSuccess,
      ),
    );
  }
}
