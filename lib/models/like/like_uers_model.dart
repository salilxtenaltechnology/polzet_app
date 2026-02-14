class LikeUser {
  final int id;
  final String username;
  final String? profileImage;
  final bool isOnline;

  LikeUser({
    required this.id,
    required this.username,
    this.profileImage,
    this.isOnline = false,
  });

  // Get first letter for avatar
  String get firstLetter {
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  // Factory constructor from JSON
  factory LikeUser.fromJson(Map<String, dynamic> json) {
    return LikeUser(
      id: json['user_id'] ?? 0,
      username: json['name'] ?? 'Unknown User',
      profileImage: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'name': username,
      'avatar_url': profileImage,
      'is_online': isOnline,
    };
  }
}