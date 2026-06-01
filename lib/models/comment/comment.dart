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
  final String? profileImage;
  final String text;
  final DateTime createdAt;

  Comments({
    required this.id,
    required this.user,
    this.profileImage,
    required this.text,
    required this.createdAt,
  });

  factory Comments.fromJson(Map<String, dynamic> json) {
    return Comments(
      id: _toInt(json['id']),
      user: json['user']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': user,
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