import 'public_things_options.dart';

class PublicPollsQuestion {
  final int id;
  final String question;
  final int maxOptions;
  final List<PublicPollOption> options;
  final int totalVotes;
  final int? userVote;

  PublicPollsQuestion({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    required this.userVote,
  });

  factory PublicPollsQuestion.fromJson(Map<String, dynamic> json) =>
      PublicPollsQuestion(
        id: json['id'] as int,
        question: json['question'] as String? ?? '-',
        maxOptions: json['max_options'] as int? ?? 1,
        options: (json['options'] as List<dynamic>?)
                ?.map(
                    (e) => PublicPollOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <PublicPollOption>[],
        // Fix: Parse string to int
        totalVotes: int.tryParse(json['total_votes']?.toString() ?? '0') ?? 0,
        userVote: json['user_vote'] as int?,
      );
}