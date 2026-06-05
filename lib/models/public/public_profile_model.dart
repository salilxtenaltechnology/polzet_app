// ignore_for_file: non_constant_identifier_names

class PublicProfileModel {
  final String status;
  final String message;
  final ProfileData data;

  PublicProfileModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    return PublicProfileModel(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: ProfileData.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

class ProfileData {
  final String id;
  final String username;
  final String? email;
  final String? mobileNumber;
  final String firstName;
  final String lastName;
  final String dob;
  final String gender;
  final String countryCode;
  final String? bio;
  final String nextUsernameChange;
  final int followersCount;
  final int followingCount;
  final int imagePostCount;
  final int textPostCount;
  final String? profilePicture;
  final String? profilePictureUrl;
  final String? profileThumbnailUrl;
  final String? coverThumbnailUrl;
  final List<ChaseUser>? chaseList;
  final List<RechaseUser>? rechaseList;
  final bool isPrivate;
  final bool isFriend;
  final PostsData posts;
  final String followStatus;
  final int chatId;

  ProfileData({
    required this.id,
    required this.username,
    this.email,
    this.mobileNumber,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.gender,
    required this.countryCode,
    this.bio,
    required this.nextUsernameChange,
    required this.followersCount,
    required this.followingCount,
    required this.imagePostCount,
    required this.textPostCount,
    this.profilePicture,
    this.profilePictureUrl,
    this.profileThumbnailUrl,
    this.coverThumbnailUrl,
    this.chaseList,
    this.rechaseList,
    required this.isPrivate,
    required this.isFriend,
    required this.posts,
    required this.followStatus,
    required this.chatId,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: (json['uuid'] ?? json['id'] ?? '').toString(),
      username: json['username'] ?? '',
      email: json['email'],
      mobileNumber: json['mobile_number'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      dob: json['dob'] ?? '',
      gender: json['gender'] ?? '',
      countryCode: json['country_code'] ?? '',
      bio: json['bio'],
      nextUsernameChange: json['next_username_change'] ?? '',
      followersCount: _toInt(json['followers_count']),
      followingCount: _toInt(json['following_count']),
      imagePostCount: _toInt(json['image_post_count']),
      textPostCount: _toInt(json['text_post_count']),
      profilePicture: json['profile_picture'],
      profilePictureUrl: json['profile_picture_url'],
      profileThumbnailUrl: json['profile_thumbnail_url'],
      coverThumbnailUrl: json['cover_thumbnail_url'],
      chaseList: (json['chase_list'] as List<dynamic>?)
          ?.map((e) => ChaseUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      rechaseList: (json['rechase_list'] as List<dynamic>?)
          ?.map((e) => RechaseUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      isPrivate: json['is_private'] ?? false,
      isFriend: json['is_friend'] ?? false,
      posts: PostsData.fromJson(
        (json['posts'] is Map) ? json['posts'] as Map<String, dynamic> : {},
      ),
      followStatus: json['follow_status'] ?? '',
      chatId: _toInt(json['chat_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'mobile_number': mobileNumber,
      'first_name': firstName,
      'last_name': lastName,
      'dob': dob,
      'gender': gender,
      'country_code': countryCode,
      'bio': bio,
      'next_username_change': nextUsernameChange,
      'followers_count': followersCount,
      'following_count': followingCount,
      'image_post_count': imagePostCount,
      'text_post_count': textPostCount,
      'profile_picture': profilePicture,
      'profile_picture_url': profilePictureUrl,
      'profile_thumbnail_url': profileThumbnailUrl,
      'cover_thumbnail_url': coverThumbnailUrl,
      'chase_list': chaseList?.map((e) => e.toJson()).toList(),
      'rechase_list': rechaseList?.map((e) => e.toJson()).toList(),
      'is_private': isPrivate,
      'is_friend': isFriend,
      'posts': posts.toJson(),
      'follow_status': followStatus,
      'chat_id': chatId,
    };
  }

  ProfileData copyWith({
    String? id,
    String? username,
    String? email,
    String? mobileNumber,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? countryCode,
    String? bio,
    String? nextUsernameChange,
    int? followersCount,
    int? followingCount,
    int? imagePostCount,
    int? textPostCount,
    String? profilePicture,
    String? profilePictureUrl,
    String? profileThumbnailUrl,
    String? coverThumbnailUrl,
    List<ChaseUser>? chaseList,
    List<RechaseUser>? rechaseList,
    bool? isPrivate,
    bool? isFriend,
    PostsData? posts,
    String? followStatus,
    int? chatId,
  }) {
    return ProfileData(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      countryCode: countryCode ?? this.countryCode,
      bio: bio ?? this.bio,
      nextUsernameChange: nextUsernameChange ?? this.nextUsernameChange,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      imagePostCount: imagePostCount ?? this.imagePostCount,
      textPostCount: textPostCount ?? this.textPostCount,
      profilePicture: profilePicture ?? this.profilePicture,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      profileThumbnailUrl: profileThumbnailUrl ?? this.profileThumbnailUrl,
      coverThumbnailUrl: coverThumbnailUrl ?? this.coverThumbnailUrl,
      chaseList: chaseList ?? this.chaseList,
      rechaseList: rechaseList ?? this.rechaseList,
      isPrivate: isPrivate ?? this.isPrivate,
      isFriend: isFriend ?? this.isFriend,
      posts: posts ?? this.posts,
      followStatus: followStatus ?? this.followStatus,
      chatId: chatId ?? this.chatId,
    );
  }
}

class PostsData {
  final int count;
  final String? next;
  final String? previous;
  final List<PublicPost> results;

  PostsData({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PostsData.fromJson(Map<String, dynamic> json) {
    return PostsData(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => PublicPost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
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

class ChaseUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String username;
  final String? avatarUrl;
  final bool isOnline;
  final String followStatus;
  final bool isPrivate;

  ChaseUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.avatarUrl,
    required this.isOnline,
    required this.followStatus,
    required this.isPrivate,
  });

  factory ChaseUser.fromJson(Map<String, dynamic> json) {
    return ChaseUser(
      userId: (json['uuid'] ?? json['user_id'] ?? json['id'] ?? '').toString(),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
      followStatus: json['follow_status'] ?? '',
      isPrivate: json['is_private'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'follow_status': followStatus,
      'is_private': isPrivate,
    };
  }
}

class RechaseUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String username;
  final String? avatarUrl;
  final bool isOnline;
  final String followStatus;
  final bool isPrivate;

  RechaseUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.avatarUrl,
    required this.isOnline,
    required this.followStatus,
    required this.isPrivate,
  });

  factory RechaseUser.fromJson(Map<String, dynamic> json) {
    return RechaseUser(
      userId: (json['uuid'] ?? json['user_id'] ?? json['id'] ?? '').toString(),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
      followStatus: json['follow_status'] ?? '',
      isPrivate: json['is_private'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'follow_status': followStatus,
      'is_private': isPrivate,
    };
  }
}

class PublicPost {
  final String id;
  final String user;
  final String description;
  final String createdAt;
  final List<PublicPostImage> images;
  final List<PublicPoll> polls;
  final List<dynamic> comments;
  final int likesCount;
  final bool isLiked;
  final int commentCount;
  final int sharesCount;
  final String locationName;
  bool is_polled_by_current_user;

  PublicPost({
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

  factory PublicPost.fromJson(Map<String, dynamic> json) {
    return PublicPost(
      id: (json['uuid'] ?? json['id'] ?? '').toString(),
      user: (json['user'] is Map)
          ? (json['user']['username'] ?? '').toString()
          : (json['user'] ?? '').toString(),
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => PublicPostImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      polls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => PublicPoll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments: json['comments'] ?? [],
      likesCount: _toInt(json['likes_count']),
      isLiked: json['is_liked'] ?? false,
      is_polled_by_current_user: json['is_polled_by_current_user'] ?? false,
      commentCount: _toInt(json['comments_count']),
      sharesCount: _toInt(json['shares_count']),
      locationName: json['location_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'description': description,
      'created_at': createdAt,
      'images': images.map((e) => e.toJson()).toList(),
      'polls': polls.map((e) => e.toJson()).toList(),
      'comments': comments,
      'likes_count': likesCount,
      'is_liked': isLiked,
      'comments_count': commentCount,
      'shares_count': sharesCount,
      'location_name': locationName,
      'is_polled_by_current_user': is_polled_by_current_user,
    };
  }

  bool get isImagePoll =>
      polls.isNotEmpty &&
      polls.any((p) => p.options.any((o) => o.image != null));

  bool get isTextPoll =>
      polls.isNotEmpty &&
      polls.any((p) => p.options.any((o) => o.text != null));
}

class PublicPostImage {
  final dynamic id;
  final String url;
  final String thumbnailUrl;
  final int order;
  final int voteCount;

  PublicPostImage({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.order,
    required this.voteCount,
  });

  factory PublicPostImage.fromJson(Map<String, dynamic> json) {
    return PublicPostImage(
      id: json['id'],
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      order: json['order'] ?? 0,
      voteCount: json['vote_count'] ?? 0,
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

class PublicPoll {
  final String id;
  final String question;
  final int maxOptions;
  final List<PublicPollOption> options;
  final String totalVotes;
  final int? userVote;

  PublicPoll({
    required this.id,
    required this.question,
    required this.maxOptions,
    required this.options,
    required this.totalVotes,
    this.userVote,
  });

  factory PublicPoll.fromJson(Map<String, dynamic> json) {
    return PublicPoll(
      id: (json['id'] ?? '').toString(),
      question: json['question'] ?? '',
      maxOptions: _toInt(json['max_options']),
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => PublicPollOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalVotes: json['total_votes']?.toString() ?? '0',
      userVote: _toIntNullable(json['user_vote']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'max_options': maxOptions,
      'options': options.map((e) => e.toJson()).toList(),
      'total_votes': totalVotes,
      'user_vote': userVote,
    };
  }
}

class PublicPollOption {
  final dynamic id;
  final String? text;
  final PollOptionImage? image;
  final String voteCount;
  final double percentage;
  final List<dynamic> voters;

  PublicPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.voters,
  });

  factory PublicPollOption.fromJson(Map<String, dynamic> json) {
    return PublicPollOption(
      id: json['id'],
      text: json['text'],
      image: json['image'] != null
          ? PollOptionImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: _toDouble(json['percentage']),
      voters: json['voters'] ?? [],
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
      id: json['id'] ?? 0,
      order: json['order'] ?? 0,
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
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

double _toDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return double.tryParse(value.toString()) ?? defaultValue;
}
