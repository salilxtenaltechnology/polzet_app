import 'package:flutter/material.dart';
import '../../../../../../models/posts/homefeed_posts_model.dart';
import '../../../../models/voters/things_voters_models.dart';
import '../things/things_voters_bottom_sheet.dart';

class HomefeedThingsVoters extends StatelessWidget {
  final HomeFeedPoll poll;
  final int postId;

  const HomefeedThingsVoters({
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
