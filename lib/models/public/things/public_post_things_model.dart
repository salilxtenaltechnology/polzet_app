import 'things_question.dart';

class PublicPostPolls {
  final int id;
  final String user;
  final String description;
  final DateTime createdAt;
  final List<PublicPollsQuestion> publicPollQuestion;

  PublicPostPolls({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.publicPollQuestion,
  });

  factory PublicPostPolls.fromJson(Map<String, dynamic> json) =>
      PublicPostPolls(
        id: json['id'] as int,
        user: json['user'] as String,
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        publicPollQuestion: (json['polls'] as List<dynamic>?)
                ?.map((e) =>
                    PublicPollsQuestion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <PublicPollsQuestion>[],
      );
}
