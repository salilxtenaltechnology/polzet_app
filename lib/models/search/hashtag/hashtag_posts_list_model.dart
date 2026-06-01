class HashtagPostsListModel {
  final int count;
  final String? next;
  final String? previous;
  final List<HashtagPostModel> results;

  HashtagPostsListModel({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory HashtagPostsListModel.fromJson(Map<String, dynamic> json) {
    return HashtagPostsListModel(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List? ?? [])
          .map((e) => HashtagPostModel.fromJson(e))
          .toList(),
    );
  }
}

class HashtagPostModel {
  final int id;
  final String? description;
  final String createdAt;
  final HashtagPostUser user;
  final List<dynamic> images;
  final List<HashtagPollModel> polls;
  final int likesCount;
  final List<HashtagLikeUser> viewLikes;
  final bool isLikedByCurrentUser;
  final bool isPolledByCurrentUser;
  final String? locationName;
  final int commentsCount;
  final int sharesCount;
  final String followingStatus;

  HashtagPostModel({
    required this.id,
    this.description,
    required this.createdAt,
    required this.user,
    required this.images,
    required this.polls,
    required this.likesCount,
    required this.viewLikes,
    required this.isLikedByCurrentUser,
    required this.isPolledByCurrentUser,
    this.locationName,
    required this.commentsCount,
    required this.sharesCount,
    required this.followingStatus,
  });

  factory HashtagPostModel.fromJson(Map<String, dynamic> json) {
    return HashtagPostModel(
      id: json['id'],
      description: json['description'],
      createdAt: json['created_at'] ?? '',
      user: HashtagPostUser.fromJson(json['user'] ?? {}),
      images: json['images'] ?? [],
      polls: (json['polls'] as List? ?? [])
          .map((e) => HashtagPollModel.fromJson(e))
          .toList(),
      likesCount: json['likes_count'] ?? 0,
      viewLikes: (json['view_likes'] as List? ?? [])
          .map((e) => HashtagLikeUser.fromJson(e))
          .toList(),
      isLikedByCurrentUser: json['is_liked_by_current_user'] ?? false,
      isPolledByCurrentUser: json['is_polled_by_current_user'] ?? false,
      locationName: json['location_name'],
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      followingStatus: json['following_status'] ?? 'none',
    );
  }
}

class HashtagPostUser {
  final int userid;
  final String firstName;
  final String lastName;
  final String username;
  final String? profileImage;
  final String? location;

  HashtagPostUser({
    required this.userid,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profileImage,
    this.location,
  });

  factory HashtagPostUser.fromJson(Map<String, dynamic> json) {
    return HashtagPostUser(
      userid: json['userid'] ?? json['id'] ?? json['user_id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      profileImage: json['profile_image'],
      location: json['location'],
    );
  }
}

class HashtagPollModel {
  final int id;
  final String question;
  final List<HashtagPollOption> options;
  final bool isPolledByCurrentUser;

  HashtagPollModel({
    required this.id,
    required this.question,
    required this.options,
    required this.isPolledByCurrentUser,
  });

  factory HashtagPollModel.fromJson(Map<String, dynamic> json) {
    return HashtagPollModel(
      id: json['id'],
      question: json['question'] ?? '',
      options: (json['options'] as List? ?? [])
          .map((e) => HashtagPollOption.fromJson(e))
          .toList(),
      isPolledByCurrentUser: json['is_polled_by_current_user'] ?? false,
    );
  }
}

class HashtagPollOption {
  final int id;
  final String? text;
  final HashtagPollImage? image;
  final String voteCount;
  final double percentage;
  final List<HashtagPollVoter> voters;
  final int score;
  final Map<String, int> rankDistribution;

  HashtagPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.voters,
    required this.score,
    required this.rankDistribution,
  });

  factory HashtagPollOption.fromJson(Map<String, dynamic> json) {
    return HashtagPollOption(
      id: json['id'],
      text: json['text'],
      image: json['image'] != null
          ? HashtagPollImage.fromJson(json['image'])
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] ?? 0).toDouble(),
      voters: (json['voters'] as List? ?? [])
          .map((e) => HashtagPollVoter.fromJson(e))
          .toList(),
      score: json['score'] ?? 0,
      rankDistribution: (json['rank_distribution'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), v as int),
      ),
    );
  }
}

class HashtagPollImage {
  final int id;
  final int order;
  final String url;
  final String thumbnailUrl;

  HashtagPollImage({
    required this.id,
    required this.order,
    required this.url,
    required this.thumbnailUrl,
  });

  factory HashtagPollImage.fromJson(Map<String, dynamic> json) {
    return HashtagPollImage(
      id: json['id'],
      order: json['order'] ?? 0,
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
    );
  }
}

class HashtagPollVoter {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;

  HashtagPollVoter({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
  });

  factory HashtagPollVoter.fromJson(Map<String, dynamic> json) {
    return HashtagPollVoter(
      id: json['id'],
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      profilePictureUrl: json['profile_picture_url'],
    );
  }
}

class HashtagLikeUser {
  final int id;
  final String username;
  final String? profileImage;

  HashtagLikeUser({
    required this.id,
    required this.username,
    this.profileImage,
  });

  factory HashtagLikeUser.fromJson(Map<String, dynamic> json) {
    return HashtagLikeUser(
      id: json['id'],
      username: json['username'] ?? '',
      profileImage: json['profile_image'],
    );
  }
}
