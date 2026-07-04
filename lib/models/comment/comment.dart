class CommentsModel {
  final int count;
  final String? next;
  final String? previous;
  final List<Comments> results;

  CommentsModel({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory CommentsModel.fromJson(Map<String, dynamic> json) {
    return CommentsModel(
      count: _toInt(json['count']),
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List)
          .map((e) => Comments.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'next': next,
        'previous': previous,
        'results': results.map((e) => e.toJson()).toList(),
      };
}

class Comments {
  final int id;
  final String user;
  final String userId;
  final String? profileImage;
  final String text;
  final DateTime createdAt;

  Comments({
    required this.id,
    required this.user,
    required this.userId,
    this.profileImage,
    required this.text,
    required this.createdAt,
  });

  factory Comments.fromJson(Map<String, dynamic> json) {
    String parsedUser = '';
    String parsedUserId = '';
    String? parsedProfileImage;

    final userVal = json['user'];
    if (userVal is Map) {
      final userMap = Map<String, dynamic>.from(userVal);
      parsedUser = userMap['username']?.toString() ?? userMap['name']?.toString() ?? '';
      parsedUserId = userMap['uuid']?.toString() ?? userMap['id']?.toString() ?? '';
      parsedProfileImage = userMap['avatar_url']?.toString() ?? userMap['profile_image']?.toString();
    } else {
      parsedUser = userVal?.toString() ?? '';
      parsedUserId = json['user_id']?.toString() ?? '';
      parsedProfileImage = json['profile_image']?.toString();
    }

    return Comments(
      id: _toInt(json['id']),
      user: parsedUser,
      userId: parsedUserId,
      profileImage: parsedProfileImage,
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': user,
        'user_id' : userId,
        'profile_image': profileImage,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };
}

int _toInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return int.tryParse(value.toString()) ?? defaultValue;
}