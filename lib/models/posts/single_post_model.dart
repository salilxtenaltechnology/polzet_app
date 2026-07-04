// models/single_post/single_post_model.dart

import 'package:polzet_app/api/api_config.dart';

class SinglePostModel {
  final String id;
  final String firstName;
  final String lastName;
  final SinglePostUser user;
  final String profileImage;
  final String description;
  final String createdAt;
  final List<SinglePostPoll> polls;
  final List<SinglePostImage> images;
  final List<SinglePostLike> viewLikes;
  final bool isLiked;
  final bool isPolledByCurrentUser;
  final String? locationName;
  final int commentsCount;
  final int likesCount;
  final String followingStatus;
  final int sharesCount;

  const SinglePostModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.user,
    required this.profileImage,
    required this.description,
    required this.createdAt,
    required this.polls,
    required this.images,
    required this.viewLikes,
    required this.isLiked,
    required this.isPolledByCurrentUser,
    this.locationName,
    required this.commentsCount,
    required this.likesCount,
    required this.followingStatus,
    required this.sharesCount,
  });

  factory SinglePostModel.fromJson(Map<String, dynamic> json) {
    return SinglePostModel(
      id: (json['uuid'] ?? json['id'] ?? '').toString(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      user: json['user'] is Map
          ? SinglePostUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : SinglePostUser(
              uuid: (json['uuid'] ?? json['userid'] ?? json['user_id'] ?? json['id'] ?? '').toString(),
              username: (json['user'] ?? '').toString(),
              profileImage: '',
            ),
      profileImage: json['profile_image'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      polls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => SinglePostPoll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => SinglePostImage.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      viewLikes:
          (json['view_likes'] as List<dynamic>?)
              ?.map((e) => SinglePostLike.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      isLiked: json['is_liked'] as bool? ?? false,
      isPolledByCurrentUser: json['is_polled_by_current_user'] as bool? ?? false,
      locationName: json['location_name'] as String?,
      commentsCount: json['comments_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      followingStatus: json['following_status'] as String? ?? 'none',
      sharesCount: json['shares_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'user': user.toJson(),
    'profile_image': profileImage,
    'description': description,
    'created_at': createdAt,
    'polls': polls.map((e) => e.toJson()).toList(),
    'images': images.map((e) => e.toJson()).toList(),
    'view_likes': viewLikes.map((e) => e.toJson()).toList(),
    'is_liked': isLiked,
    'is_polled_by_current_user': isPolledByCurrentUser,
    'location_name': locationName,
    'comments_count': commentsCount,
    'likes_count': likesCount,
    'following_status': followingStatus,
    'shares_count': sharesCount,
  };

  bool get isImagePoll =>
      polls.isNotEmpty &&
      polls.every((p) => p.options.every((o) => o.image != null));

  bool get isTextPoll =>
      polls.isNotEmpty &&
      polls.every((p) => p.options.every((o) => o.text != null && o.image == null));
}


class SinglePostPoll {
  final String id;
  final String type;
  final String pollType;
  final String votingType;
  final bool isAnonymous;
  final Map<String, dynamic> settings;
  final String question;
  final int maxOptions;
  final List<SinglePostPollOption> options;
  final String totalVotes;
  final int? userVote;

  SinglePostPoll({
    required this.id,
    required this.type,
    required this.pollType,
    required this.votingType,
    required this.isAnonymous,
    required this.settings,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory SinglePostPoll.fromJson(Map<String, dynamic> json) {
    final String totalVotesVal = json['total_votes']?.toString() ?? '0';
    final List<SinglePostPollOption> optionsVal =
        (json['options'] as List<dynamic>?)
            ?.map(
              (e) => SinglePostPollOption.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];
    return SinglePostPoll(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'text',
      pollType: json['poll_type'] as String? ?? '',
      votingType: json['voting_type'] as String? ?? 'single_choice',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      settings: json['settings'] is Map
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : {},
      question: json['question'] as String? ?? '',
      maxOptions: json['max_options'] as int? ?? 1,
      options: optionsVal,
      totalVotes: totalVotesVal,
      userVote: json['user_vote'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'poll_type': pollType,
    'voting_type': votingType,
    'is_anonymous': isAnonymous,
    'settings': settings,
    'question': question,
    'max_options': maxOptions,
    'options': options.map((e) => e.toJson()).toList(),
    'total_votes': totalVotes,
    'user_vote': userVote,
  };

  bool get hasVoted => userVote != null;
}


class SinglePostPollOption {
  final dynamic id;
  final String? text;
  final SinglePostPollImage? image;
  String voteCount;
  final double percentage;
  final double score;
  final Map<String, dynamic> rankDistribution;
  final List<SinglePostVoter> voters;

  SinglePostPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.score,
    required this.rankDistribution,
    required this.voters,
  });

  factory SinglePostPollOption.fromJson(Map<String, dynamic> json) {
    return SinglePostPollOption(
      id: json['id'],
      text: json['text'] as String?,
      image: json['image'] != null
          ? SinglePostPollImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rankDistribution: json['rank_distribution'] is Map
          ? Map<String, dynamic>.from(json['rank_distribution'] as Map)
          : {},
      voters:
          (json['voters'] as List<dynamic>?)
              ?.map((e) => SinglePostVoter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'image': image?.toJson(),
    'vote_count': voteCount,
    'percentage': percentage,
    'score': score,
    'rank_distribution': rankDistribution,
    'voters': voters.map((e) => e.toJson()).toList(),
  };
}


class SinglePostPollImage {
  final dynamic id;
  final int order;
  final String url;
  final String thumbnailUrl;

  const SinglePostPollImage({
    required this.id,
    required this.order,
    required this.url,
    required this.thumbnailUrl,
  });

  factory SinglePostPollImage.fromJson(Map<String, dynamic> json) {
    return SinglePostPollImage(
      id: json['id'],
      order: json['order'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'url': url,
    'thumbnail_url': thumbnailUrl,
  };

  String resolvedUrl(String baseUrl) {
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  String resolvedThumbnailUrl(String baseUrl) {
    if (thumbnailUrl.startsWith('http')) return thumbnailUrl;
    return '$baseUrl$thumbnailUrl';
  }
}


class SinglePostImage {
  final dynamic id;
  final int order;
  final String url;
  final String thumbnailUrl;

  const SinglePostImage({
    required this.id,
    required this.order,
    required this.url,
    required this.thumbnailUrl,
  });

  factory SinglePostImage.fromJson(Map<String, dynamic> json) {
    return SinglePostImage(
      id: json['id'],
      order: json['order'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'url': url,
    'thumbnail_url': thumbnailUrl,
  };

  String resolvedUrl(String baseUrl) {
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  String resolvedThumbnailUrl(String baseUrl) {
    if (thumbnailUrl.startsWith('http')) return thumbnailUrl;
    return '$baseUrl$thumbnailUrl';
  }
}


class SinglePostVoter {
  final dynamic id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;

  const SinglePostVoter({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
  });

  factory SinglePostVoter.fromJson(Map<String, dynamic> json) {
    return SinglePostVoter(
      id: json['id'],
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': firstName,
    'last_name': lastName,
    'profile_picture_url': profilePictureUrl,
  };

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }
}


class SinglePostLike {
  final dynamic id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;

  const SinglePostLike({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
  });

  factory SinglePostLike.fromJson(Map<String, dynamic> json) {
    return SinglePostLike(
      id: json['id'],
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': firstName,
    'last_name': lastName,
    'profile_picture_url': profilePictureUrl,
  };

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }
}


class SinglePostUser {
  final String uuid;
  final String username;
  final String profileImage;

  const SinglePostUser({
    required this.uuid,
    required this.username,
    required this.profileImage,
  });

  factory SinglePostUser.fromJson(Map<String, dynamic> json) {
    String profileImg = json['profile_image']?.toString() ?? '';
    if (profileImg.isNotEmpty) {
      if (!profileImg.startsWith('http') && !profileImg.startsWith('data:image')) {
        if (profileImg.startsWith('/')) {
          profileImg = '${ApiConfig.baseUrlImage}$profileImg';
        } else {
          profileImg = '${ApiConfig.baseUrlImage}/$profileImg';
        }
      }
    }
    return SinglePostUser(
      uuid: (json['uuid'] ?? json['userid'] ?? json['user_id'] ?? json['id'] ?? '').toString(),
      username: json['username']?.toString() ?? '',
      profileImage: profileImg,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'username': username,
    'profile_image': profileImage,
  };
}