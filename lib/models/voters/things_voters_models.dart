// common/voters/voters_models.dart

import '../../models/voters/top_voters_model.dart';

class ThingsVoter {
  final int id;
  final String username;
  final String? profileImage;
  final String? votedAt;

  const ThingsVoter({
    required this.id,
    required this.username,
    this.profileImage,
    this.votedAt,
  });

  factory ThingsVoter.fromTopVoterUser(TopVoterUser user) {
    return ThingsVoter(
      id: user.id,
      username: user.username,
      profileImage: user.profilePictureUrl,
      votedAt: 'Just now',
    );
  }
}

class ThingsOptionVoterState {
  final bool isLoading;
  final String? error;
  final List<ThingsVoter> voters;

  ThingsOptionVoterState({
    this.isLoading = true,
    this.error,
    this.voters = const [],
  });
}

/// Lightweight poll option passed into the shared widget
class ThingsVoterPollOption {
  final int id;
  final String text;

  const ThingsVoterPollOption({required this.id, required this.text});
}
