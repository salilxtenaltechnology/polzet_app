class HomeFeedPost {
  final int id;
  final HomeFeedUser user;
  final String description;
  final String createdAt;
  final List<HomeFeedPostImage> images;
  final List<HomeFeedPoll> polls;
  final int likesCount;
  final List<LikeUser> viewLikes; // Changed from List<dynamic>
  final bool isLikedByCurrentUser;
  final int commentsCount;

  HomeFeedPost({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.images,
    required this.polls,
    required this.likesCount,
    required this.viewLikes,
    required this.isLikedByCurrentUser,
    required this.commentsCount,
  });

  factory HomeFeedPost.fromJson(Map<String, dynamic> json) {
    try {
      return HomeFeedPost(
        id: _parseToInt(json['id']),
        user: HomeFeedUser.fromJson(json['user'] ?? {}),
        description: _parseToString(json['description']),
        createdAt: _parseToString(json['created_at']),
        images: _parseList<HomeFeedPostImage>(
            json['images'], (item) => HomeFeedPostImage.fromJson(item)),
        polls: _parseList<HomeFeedPoll>(
            json['polls'], (item) => HomeFeedPoll.fromJson(item)),
        likesCount: _parseToInt(json['likes_count']),
        viewLikes: _parseList<LikeUser>(
            json['view_likes'], (item) => LikeUser.fromJson(item)),
        isLikedByCurrentUser: json['is_liked_by_current_user'] == true,
        commentsCount: _parseToInt(json['comments_count']),
      );
    } catch (e) {
      print('Error parsing HomeFeedPost: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'description': description,
      'created_at': createdAt,
      'images': images.map((image) => image.toJson()).toList(),
      'polls': polls.map((poll) => poll.toJson()).toList(),
      'likes_count': likesCount,
      'view_likes': viewLikes.map((like) => like.toJson()).toList(),
      'is_liked_by_current_user': isLikedByCurrentUser,
      'comments_count': commentsCount,
    };
  }

  // Helper methods for safe parsing
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
      dynamic value, T Function(Map<String, dynamic>) fromJson) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        print('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}

// New class for users in view_likes list
class LikeUser {
  final int id;
  final String username;
  final String? profileImage;

  LikeUser({
    required this.id,
    required this.username,
    this.profileImage,
  });

  // Helper method to get first letter uppercase
  String get firstLetter {
    if (username.isEmpty) return 'U';
    return username[0].toUpperCase();
  }

  factory LikeUser.fromJson(Map<String, dynamic> json) {
    return LikeUser(
      id: _parseToInt(json['id']),
      username: _parseToString(json['username']),
      profileImage: json['profile_image']?.toString(),
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

  // Helper method to get first letter uppercase
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

class HomeFeedPostImage {
  final int id;
  final String? url;
  final String? thumbnailUrl;
  final int order;
  final int voteCount;
  final List<LikeUser> userList; // Changed from List<dynamic>

  HomeFeedPostImage({
    required this.id,
    this.url,
    this.thumbnailUrl,
    required this.order,
    required this.voteCount,
    required this.userList,
  });

  factory HomeFeedPostImage.fromJson(Map<String, dynamic> json) {
    return HomeFeedPostImage(
      id: _parseToInt(json['id']),
      url: json['url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      order: _parseToInt(json['order']),
      voteCount: _parseToInt(json['vote_count']),
      userList: _parseList<LikeUser>(
          json['user_list'], (item) => LikeUser.fromJson(item)),
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

  static List<T> _parseList<T>(
      dynamic value, T Function(Map<String, dynamic>) fromJson) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        print('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}

class HomeFeedPoll {
  final int id;
  final String question;
  final int maxOptions;
  final List<HomeFeedPollOption> options;
  final int totalVotes;
  final String? userVote;

  HomeFeedPoll({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory HomeFeedPoll.fromJson(Map<String, dynamic> json) {
    return HomeFeedPoll(
      id: _parseToInt(json['id']),
      question: _parseToString(json['question']),
      maxOptions: _parseToInt(json['max_options']),
      options: _parseList<HomeFeedPollOption>(
          json['options'], (item) => HomeFeedPollOption.fromJson(item)),
      totalVotes: _parseToInt(json['total_votes']),
      userVote: json['user_vote']?.toString(),
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
      dynamic value, T Function(Map<String, dynamic>) fromJson) {
    if (value == null) return [];
    if (value is! List) return [];

    List<T> result = [];
    for (var item in value) {
      try {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        }
      } catch (e) {
        print('Error parsing list item: $e');
        continue;
      }
    }
    return result;
  }
}

class HomeFeedPollOption {
  final int id;
  final String text;
  final int voteCount;

  HomeFeedPollOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });

  factory HomeFeedPollOption.fromJson(Map<String, dynamic> json) {
    return HomeFeedPollOption(
      id: _parseToInt(json['id']),
      text: _parseToString(json['text']),
      voteCount: _parseToInt(json['vote_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'vote_count': voteCount,
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

// Wrapper class for the API response
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
      results: (json['results'] as List<dynamic>?)
              ?.map(
                  (item) => HomeFeedPost.fromJson(item as Map<String, dynamic>))
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
