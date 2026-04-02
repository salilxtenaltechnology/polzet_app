import 'package:flutter/material.dart';

class HomeFeedResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<HomeFeedPost> results;

  HomeFeedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory HomeFeedResponse.fromJson(Map<String, dynamic> json) {
    return HomeFeedResponse(
      count: json['count'] ?? 0,
      next: json['next']?.toString(),
      previous: json['previous']?.toString(),
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (item) => HomeFeedPost.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'next': next,
      'previous': previous,
      'results': results.map((post) => post.toJson()).toList(),
    };
  }
}
class HomeFeedPost {
  final int id;
  final HomeFeedUser user;
  final String description;
  final String createdAt;
  final List<HomeFeedPoll> polls;
  final int likesCount;
  final bool isLikedByCurrentUser;
  final int commentsCount;
  final String followingStatus;

  final List<HomeFeedLikeUser> viewLikes;

  HomeFeedPost({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.polls,
    required this.likesCount,
    required this.isLikedByCurrentUser,
    required this.commentsCount,
    required this.viewLikes,
    required this.followingStatus,
  });

  factory HomeFeedPost.fromJson(Map<String, dynamic> json) {
    try {
      return HomeFeedPost(
        id: _parseToInt(json['id']),
        user: HomeFeedUser.fromJson(json['user'] ?? {}),
        description: _parseToString(json['description']),
        createdAt: _parseToString(json['created_at']),
        polls: _parseList<HomeFeedPoll>(
          json['polls'],
          (item) => HomeFeedPoll.fromJson(item),
        ),
        likesCount: _parseToInt(json['likes_count']),
        isLikedByCurrentUser: json['is_liked_by_current_user'] == true,
        commentsCount: _parseToInt(json['comments_count']),
        viewLikes: _parseList<HomeFeedLikeUser>(
          json['view_likes'] ?? json['likes'],
          (item) => HomeFeedLikeUser.fromJson(item),
        ),
        followingStatus:_parseToString(json['following_status'])
      );
    } catch (e) {
      debugPrint('Error parsing HomeFeedPost: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'description': description,
      'created_at': createdAt,
      'polls': polls.map((poll) => poll.toJson()).toList(),
      'likes_count': likesCount,
      'is_liked_by_current_user': isLikedByCurrentUser,
      'comments_count': commentsCount,
      'view_likes': viewLikes.map((like) => like.toJson()).toList(),
      'following_status': followingStatus,
    };
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _parseToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        debugPrint('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}

class HomeFeedLikeUser {
  final int id;
  final String username;
  final String? profileImage;

  HomeFeedLikeUser({
    required this.id,
    required this.username,
    this.profileImage,
  });

  String get firstLetter {
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  factory HomeFeedLikeUser.fromJson(Map<String, dynamic> json) {
    return HomeFeedLikeUser(
      id: _parseToInt(json['id'] ?? json['user_id']),
      username: _parseToString(json['username'] ?? json['name']),
      profileImage: json['profile_image']?.toString() ?? 
                    json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'profile_image': profileImage,
    };
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _parseToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
}

class HomeFeedUser {
  final int userid;
  final String username;
  final String? profileImage;
  final String? location;

  HomeFeedUser({
    required this.userid,
    required this.username,
    this.profileImage,
    this.location,
  });

  String get firstLetter {
    if (username.isEmpty) return 'U';
    return username[0].toUpperCase();
  }

  factory HomeFeedUser.fromJson(Map<String, dynamic> json) {
    return HomeFeedUser(
      userid: _parseToInt(json['userid']),
      username: _parseToString(json['username']),
      profileImage: json['profile_image']?.toString(),
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userid': userid,
      'username': username,
      'profile_image': profileImage,
      'location': location,
    };
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _parseToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
}

class HomeFeedPoll {
  final int id;
  final String question;
  final int maxOptions;
  final List<HomeFeedPollOption> options;
  int totalVotes;
  final int? userVote;
  bool isPolledByCurrentUser;

  HomeFeedPoll({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
    required this.isPolledByCurrentUser,
  });

  factory HomeFeedPoll.fromJson(Map<String, dynamic> json) {
    return HomeFeedPoll(
      id: _parseToInt(json['id']),
      question: _parseToString(json['question']),
      maxOptions: _parseToInt(json['max_options']),
      options: _parseList<HomeFeedPollOption>(
        json['options'],
        (item) => HomeFeedPollOption.fromJson(item),
      ),
      totalVotes: _parseToInt(json['total_votes']),
      userVote: json['user_vote'] != null
          ? _parseToInt(json['user_vote'])
          : null,
      isPolledByCurrentUser: json['is_polled_by_current_user'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'max_options': maxOptions,
      'options': options.map((option) => option.toJson()).toList(),
      'total_votes': totalVotes,
      'user_vote': userVote,
      'is_polled_by_current_user': isPolledByCurrentUser,
    };
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _parseToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        debugPrint('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}

class HomeFeedPollOption {
  final int id;
  final String? text;
  final PollOptionImage? image;
  final int voteCount;
  final int score;
  double percentage;
  int rank1Count; 
  int? rankPosition;    
  final List<HomeFeedLikeUser> userList;

  HomeFeedPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.score,
    required this.percentage,
     this.rank1Count = 0, 
     this.rankPosition, 
    required this.userList,
  });

  factory HomeFeedPollOption.fromJson(Map<String, dynamic> json) {
    return HomeFeedPollOption(
      id: _parseToInt(json['id']),
      text: json['text']?.toString(),
      image: json['image'] != null
          ? PollOptionImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: _parseToInt(json['vote_count']),
      score: _parseToInt(json['score']),
      percentage: _parseToDouble(json['percentage']),
      userList: _parseList<HomeFeedLikeUser>(
        json['user_list'],
        (item) => HomeFeedLikeUser.fromJson(item),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'image': image?.toJson(),
      'vote_count': voteCount,
      'score': score,
      'percentage': percentage,
      'user_list': userList.map((user) => user.toJson()).toList(),
    };
  }

  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        debugPrint('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}

class PollOptionImage {
  final int id;
  final String url;
  final String thumbnailUrl;
  final int order;
  final int voteCount;
  final List<HomeFeedLikeUser> userList;

  PollOptionImage({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.order,
    required this.voteCount,
    required this.userList,
  });

  factory PollOptionImage.fromJson(Map<String, dynamic> json) {
    return PollOptionImage(
      id: _parseToInt(json['id']),
      url: _parseToString(json['url']),
      thumbnailUrl: _parseToString(json['thumbnail_url']),
      order: _parseToInt(json['order']),
      voteCount: _parseToInt(json['vote_count']),
      userList: _parseList<HomeFeedLikeUser>(
        json['user_list'],
        (item) => HomeFeedLikeUser.fromJson(item),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'order': order,
      'vote_count': voteCount,
      'user_list': userList.map((user) => user.toJson()).toList(),
    };
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _parseToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        debugPrint('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}