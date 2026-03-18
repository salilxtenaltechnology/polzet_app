class Comment {
  final int id;
  final String user;
  final String profileImage;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.user,
    required this.profileImage,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      user: json['user'] ?? 'Unknown',
      profileImage: json['profile_image'] ?? '',
      text: json['text'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
