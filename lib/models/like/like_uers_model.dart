class LikeUser {
  final int id;
  final String? fullName;
  final String username;
  final String? profileImage;
  final bool isOnline;
  final String? followStatus;

  LikeUser({
    required this.id,
    this.fullName,
    required this.username,
    this.profileImage,
    this.isOnline = false,
    this.followStatus,
  });

  String get firstLetter {
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  factory LikeUser.fromJson(Map<String, dynamic> json) {
    return LikeUser(
      id: json['user_id'] ?? 0,
      fullName: json['name'] ?? 'Unknown User',
      username: json['username'] ?? 'Unknown User',
      profileImage: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
      followStatus: json['follow_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'full_name': fullName,
      'name': username,
      'avatar_url': profileImage,
      'is_online': isOnline,
      'follow_status': followStatus,
    };
  }
}
