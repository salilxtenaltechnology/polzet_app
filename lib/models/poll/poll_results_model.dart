class PollResultsModel {
  final int pollId;
  final int totalVotes;
  final List<PollResultOption> results;

  PollResultsModel({
    required this.pollId,
    required this.totalVotes,
    required this.results,
  });

  factory PollResultsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PollResultsModel(
      pollId: data['poll_id'] as int,
      totalVotes: data['total_votes'] as int,
      results: (data['results'] as List<dynamic>)
          .map((e) => PollResultOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PollResultOption {
  final int optionId;
  final String? text;
  final String? imageUrl;
  final int rank1Count;
  final double percentage;

  PollResultOption({
    required this.optionId,
    this.text,
    this.imageUrl,
    required this.rank1Count,
    required this.percentage,
  });

  factory PollResultOption.fromJson(Map<String, dynamic> json) {
    return PollResultOption(
      optionId: json['option_id'] as int,
      text: json['text']?.toString(),
      imageUrl: json['image_url']?.toString(),
      rank1Count: json['rank_1_count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}