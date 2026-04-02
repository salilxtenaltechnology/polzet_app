// current_user_things_voters.dart

import 'package:flutter/material.dart';
import 'package:polzet_app/models/posts/user_post_model.dart';

import '../../../../models/voters/things_voters_models.dart';
import 'things_voters_bottom_sheet.dart';

class CurrentUserThingsVoters extends StatelessWidget {
  final UserPollQuestion poll;
  final int postId;

  const CurrentUserThingsVoters({
    super.key,
    required this.poll,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final options = (poll.options ?? [])
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .map((o) => ThingsVoterPollOption(id: o.id, text: o.text!))
        .toList();

    return ThingsVotersBottomSheet(
      pollId: poll.id,
      pollQuestion: poll.question,
      postId: postId,
      options: options,
    );
  }
}
