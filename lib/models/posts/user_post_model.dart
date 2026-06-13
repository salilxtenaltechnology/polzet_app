// ignore_for_file: non_constant_identifier_names
class UserPostResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<UserPostModel> results;

  UserPostResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory UserPostResponse.fromJson(Map<String, dynamic> json) {
    return UserPostResponse(
      count: json['count'] as int,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: (json['results'] as List<dynamic>)
          .map((e) => UserPostModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Filter only posts with images in polls
  List<UserPostModel> get postsWithImages {
    return results.where((post) => post.hasPollImages).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'next': next,
      'previous': previous,
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

class UserPostModel {
  final String id;
  final String user;
  final String description;
  final DateTime createdAt;
  final List<PostImage> images;
  final List<UserPollQuestion> polls;
  final List<Comment> comments;
  final int likesCount;
  final bool isLiked;
  final int commentCount;
  final int sharesCount;
  final String locationName;
  bool is_polled_by_current_user;

  UserPostModel({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.images,
    required this.polls,
    required this.comments,
    required this.likesCount,
    required this.isLiked,
    required this.commentCount, 
    required this.sharesCount,
    required this.locationName,
    required this.is_polled_by_current_user,
  });

  factory UserPostModel.fromJson(Map<String, dynamic> json) {
    return UserPostModel(
      id: (json['uuid'] ?? json['id'] ?? '').toString(),
      user: (json['user'] is Map)
          ? (json['user']['username'] ?? '').toString()
          : (json['user'] ?? '').toString(),
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => PostImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      polls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => UserPollQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      likesCount: _toInt(json['likes_count']),
      isLiked: _parseBool(json['is_liked']),
      commentCount: _toInt(json['comments_count']),
      sharesCount: _toInt(json['shares_count']),
      is_polled_by_current_user: _parseBool(json['is_polled_by_current_user']),
      locationName: json['location_name']?.toString() ?? ''
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  int get commentsCount => comments.length;

  bool get hasPollImages {
    return polls.any(
      (poll) => poll.options?.any((option) => option.image != null) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'images': images.map((e) => e.toJson()).toList(),
      'polls': polls.map((e) => e.toJson()).toList(),
      'comments': comments.map((e) => e.toJson()).toList(),
      'likes_count': likesCount,
      'comments_count' : commentCount, 
      'shares_count' : sharesCount,
      'is_liked': isLiked,
      'location_name' : locationName
    };
  }

  UserPostModel copyWith({
    String? id,
    String? user,
    String? description,
    DateTime? createdAt,
    List<PostImage>? images,
    List<UserPollQuestion>? polls,
    List<Comment>? comments,
    int? likesCount,
    int? commentCount, 
    int? sharesCount,
    bool? isLiked,
    bool? is_polled_by_current_user,
    String? locationName,
  }) {
    return UserPostModel(
      id: id ?? this.id,
      user: user ?? this.user,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      images: images ?? this.images,
      polls: polls ?? this.polls,
      comments: comments ?? this.comments,
      likesCount: likesCount ?? this.likesCount,
      commentCount: commentCount ?? this.commentCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      is_polled_by_current_user:
          is_polled_by_current_user ?? this.is_polled_by_current_user,
      locationName: locationName ?? this.locationName
    );
  }
}

class PostImage {
  final int id;
  final String url;
  final String thumbnailUrl;
  final int order;
  final int voteCount;

  PostImage({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.order,
    required this.voteCount,
  });

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      id: _toInt(json['id']),
      url: (json['url'] ?? '').toString(),
      thumbnailUrl: (json['thumbnail_url'] ?? '').toString(),
      order: _toInt(json['order']),
      voteCount: _toInt(json['vote_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'order': order,
      'vote_count': voteCount,
    };
  }
}

class UserPollQuestion {
  final String id;
  final String question;
  final int maxOptions;
  final List<UserPollOption>? options;
  final String totalVotes;
  final int? userVote;

  UserPollQuestion({
    required this.id,
    required this.question,
    required this.maxOptions,
    this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory UserPollQuestion.fromJson(Map<String, dynamic> json) {
    return UserPollQuestion(
      id: (json['id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      maxOptions: _toInt(json['max_options']),
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => UserPollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalVotes: json['total_votes']?.toString() ?? '0',
      userVote: _toIntNullable(json['user_vote']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'max_options': maxOptions,
      'options': options?.map((e) => e.toJson()).toList(),
      'total_votes': totalVotes,
      'user_vote': userVote,
    };
  }
}

class UserPollOption {
  final int id;
  final String? text;
  final PollOptionImage? image;
  final String voteCount;
  double percentage;
  final List<dynamic> voters;

  UserPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.voters,
  });

  factory UserPollOption.fromJson(Map<String, dynamic> json) {
    return UserPollOption(
      id: _toInt(json['id']),
      text: json['text']?.toString(),
      image: json['image'] != null
          ? PollOptionImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] ?? 0).toDouble(),
      voters: json['voters'] as List<dynamic>? ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'image': image?.toJson(),
      'vote_count': voteCount,
      'percentage': percentage,
      'voters': voters,
    };
  }
}

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

  String resolvedUrl(String baseUrl) {
    if (url.isEmpty) return '';
    if (url.startsWith('http') || url.startsWith('data:image')) return url;
    if (url.startsWith('/')) return '$baseUrl$url';
    return '$baseUrl/$url';
  }

  String resolvedThumbnailUrl(String baseUrl) {
    if (thumbnailUrl.isEmpty) return '';
    if (thumbnailUrl.startsWith('http') || thumbnailUrl.startsWith('data:image')) return thumbnailUrl;
    if (thumbnailUrl.startsWith('/')) return '$baseUrl$thumbnailUrl';
    return '$baseUrl/$thumbnailUrl';
  }

  factory PollOptionImage.fromJson(Map<String, dynamic> json) {
    return PollOptionImage(
      id: _toInt(json['id']),
      order: _toInt(json['order']),
      url: (json['url'] ?? '').toString(),
      thumbnailUrl: (json['thumbnail_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'url': url,
      'thumbnail_url': thumbnailUrl,
    };
  }
}

class Comment {
  final int? id;
  final String? user;
  final String? text;
  final DateTime? createdAt;

  Comment({this.id, this.user, this.text, this.createdAt});

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: _toIntNullable(json['id']),
      user: json['user'] as String?,
      text: json['text'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'text': text,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

int? _toIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return int.tryParse(value.toString());
}

int _toInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return int.tryParse(value.toString()) ?? defaultValue;
}
