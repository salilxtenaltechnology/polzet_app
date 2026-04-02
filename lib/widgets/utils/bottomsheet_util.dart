import 'package:flutter/material.dart';
import 'package:polzet_app/models/posts/homefeed_posts_model.dart';
import '../../models/posts/user_post_model.dart';
import '../../models/public/public_profile_model.dart';
import '../bottomsheets/add_members/add_member_bottom_sheet.dart';
import '../bottomsheets/comment/comments_bottom_sheet.dart';
import '../bottomsheets/like/liked_users_bottom_sheet.dart';
import '../bottomsheets/voters/images/image_post_voters_bottom_sheet.dart';
import '../bottomsheets/voters/homefeed/homefeed_things_voters.dart';
import '../bottomsheets/voters/things/current_user_things_voters.dart';
import '../bottomsheets/voters/things/public_user_things_voters.dart';

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
      builder: (_) =>
          ImagePostVotersBottomSheet(pollId: pollId, optionId: optionId),
    );
  }

 static void showThingsPostVotersBottomSheet({
  required BuildContext context,
  required HomeFeedPoll poll,
  required int postId,     
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HomefeedThingsVoters(
      poll: poll,
      postId: postId,        
    ),
  );
}

  static void showCurrenUserThingsPostBottomSheet({
  required BuildContext context,
  required UserPollQuestion poll,
  required int postId,        // ← add
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CurrentUserThingsVoters(
      poll: poll,
      postId: postId,         // ← pass
    ),
  );
}

  static void showPublicUserThingsPostBottomSheet({
  required BuildContext context,
  required PublicPoll poll,
  required int postId,     
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PublicUserThingsVoters(
      poll: poll,
      postId: postId,      
    ),
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
      builder: (_) => AddMemberBottomSheet(alreadySelected: alreadySelected),
    );
  }
}
