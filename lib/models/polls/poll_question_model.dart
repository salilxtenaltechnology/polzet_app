import 'poll_option_model.dart';

class PollQuestion {
  final int id;
  final String question;
  final int maxOptions;
  final List<PollOption> options;
  final String totalVotes; // Changed from int to String
  final int? userVote;

  PollQuestion({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory PollQuestion.fromJson(Map<String, dynamic> json) => PollQuestion(
        id: json['id'] as int,
        question: json['question'] as String? ?? '-',
        maxOptions: json['max_options'] as int? ?? 1,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => PollOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <PollOption>[],
        totalVotes: json['total_votes'] as String? ?? '0', // Changed to String
        userVote: json['user_vote'] as int?,
      );

  // Helper method to get total votes as int
  int get totalVotesCount => int.tryParse(totalVotes) ?? 0;

  // Helper method to check if user has voted
  bool get hasUserVoted => userVote != null;
}