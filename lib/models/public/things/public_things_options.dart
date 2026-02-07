class PublicPollOption {
  final int id;
  final String text;
  final int voteCount;

  PublicPollOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });

  factory PublicPollOption.fromJson(Map<String, dynamic> json) =>
      PublicPollOption(
        id: json['id'] as int,
        text: json['text'] as String? ?? '',
        // Fix: Parse string to int
        voteCount: int.tryParse(json['vote_count']?.toString() ?? '0') ?? 0,
      );
}
