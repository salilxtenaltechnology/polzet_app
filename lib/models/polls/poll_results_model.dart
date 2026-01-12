class PollOptionResult {
  final int optionId;
  final String text;
  final String? imageUrl;
  final int rank1Count;
  final double percentage;

  PollOptionResult({
    required this.optionId,
    required this.text,
    this.imageUrl,
    required this.rank1Count,
    required this.percentage,
  });

  factory PollOptionResult.fromJson(Map<String, dynamic> json) {
    return PollOptionResult(
      optionId: json['option_id'] as int,
      text: json['text'] as String,
      imageUrl: json['image_url'],
      rank1Count: json['rank_1_count'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'text': text,
      'image_url': imageUrl,
      'rank_1_count': rank1Count,
      'percentage': percentage,
    };
  }
}