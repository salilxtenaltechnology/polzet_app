class PollOptionImage {
  final int id;
  final int order;
  final String url;
  final String thumbnailUrl;

  PollOptionImage({
    required this.id,
    required this.order,
    required this.url,
    required this.thumbnailUrl,
  });

  factory PollOptionImage.fromJson(Map<String, dynamic> json) => PollOptionImage(
        id: json['id'] as int,
        order: json['order'] as int? ?? 0,
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      );
}

class PollOption {
  final int id;
  final String? text;
  final PollOptionImage? image;
  final String voteCount;
  final List<String> voters;

  PollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.voters,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        id: json['id'] as int,
        text: json['text'] as String?,
        image: json['image'] != null 
            ? PollOptionImage.fromJson(json['image'] as Map<String, dynamic>)
            : null,
        voteCount: json['vote_count']?.toString() ?? '0',
        voters: (json['voters'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[],
      );

  // Helper method to get vote count as integer
  int get voteCountInt => int.tryParse(voteCount) ?? 0;
  
  // Helper to check percentage (useful for displaying poll results)
  double getPercentage(int totalVotes) {
    if (totalVotes == 0) return 0.0;
    return (voteCountInt / totalVotes) * 100;
  }
  
  // Helper to check if user voted for this option
  bool hasVoted(String username) => voters.contains(username);
  
  // Helper to get display text or image identifier
  String get displayText => text ?? 'Image Option';
}