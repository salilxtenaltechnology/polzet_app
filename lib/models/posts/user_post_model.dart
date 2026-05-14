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
  final int id;
  final String user;
  final String description;
  final DateTime createdAt;
  final List<PostImage> images;
  final List<UserPollQuestion> polls;
  final List<Comment> comments;
  final int likesCount;
  final bool isLiked;
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
    required this.is_polled_by_current_user,
  });

  factory UserPostModel.fromJson(Map<String, dynamic> json) {
    return UserPostModel(
      id: json['id'] as int,
      user: json['user'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
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
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: _parseBool(json['is_liked']),
      is_polled_by_current_user: _parseBool(json['is_polled_by_current_user']),
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
      'is_liked': isLiked,
    };
  }

  UserPostModel copyWith({
    int? id,
    String? user,
    String? description,
    DateTime? createdAt,
    List<PostImage>? images,
    List<UserPollQuestion>? polls,
    List<Comment>? comments,
    int? likesCount,
    bool? isLiked,
    bool? is_polled_by_current_user,
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
      isLiked: isLiked ?? this.isLiked,
      is_polled_by_current_user:
          is_polled_by_current_user ?? this.is_polled_by_current_user,
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
      id: json['id'] as int,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      order: json['order'] as int,
      voteCount: json['vote_count'] as int? ?? 0,
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
  final int id;
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
      id: json['id'] as int,
      question: json['question'] as String,
      maxOptions: json['max_options'] as int,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => UserPollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalVotes: json['total_votes'] as String? ?? '0',
      userVote: json['user_vote'] as int?,
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
      id: json['id'] as int,
      text: json['text'] as String?,
      image: json['image'] != null
          ? PollOptionImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count'] as String? ?? '0',
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

  factory PollOptionImage.fromJson(Map<String, dynamic> json) {
    return PollOptionImage(
      id: json['id'] as int,
      order: json['order'] as int,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
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
      id: json['id'] as int?,
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
