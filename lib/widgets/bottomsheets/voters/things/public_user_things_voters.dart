import 'package:flutter/material.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../models/voters/things_voters_models.dart';
import 'things_voters_bottom_sheet.dart';

class PublicUserThingsVoters extends StatelessWidget {
  final PublicPoll poll;
  final int postId;

  const PublicUserThingsVoters({
    super.key,
    required this.poll,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final options = poll.options
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
