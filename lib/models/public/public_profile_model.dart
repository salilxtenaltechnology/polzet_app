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
  final int id;
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
  final String? profilePictureUrl;
  final String? profileThumbnailUrl;
  final String? coverThumbnailUrl;
  final List<ChaseUser>? chaseList;
  final List<RechaseUser>? rechaseList;
  final bool isPrivate;
  final bool isFriend;
  final PostsData posts;
  final String followStatus;

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
    this.profilePictureUrl,
    this.profileThumbnailUrl,
    this.coverThumbnailUrl,
    this.chaseList,
    this.rechaseList,
    required this.isPrivate,
    required this.isFriend,
    required this.posts,
    required this.followStatus,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'] ?? 0,
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
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      imagePostCount: json['image_post_count'] ?? 0,
      textPostCount: json['text_post_count'] ?? 0,
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
      posts: PostsData.fromJson(json['posts'] ?? {}),
      followStatus: json['follow_status'] ?? '',
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
      'profile_picture_url': profilePictureUrl,
      'profile_thumbnail_url': profileThumbnailUrl,
      'cover_thumbnail_url': coverThumbnailUrl,
      'chase_list': chaseList?.map((e) => e.toJson()).toList(),
      'rechase_list': rechaseList?.map((e) => e.toJson()).toList(),
      'is_private': isPrivate,
      'is_friend': isFriend,
      'posts': posts.toJson(),
      'follow_status': followStatus,
    };
  }

  ProfileData copyWith({
    int? id,
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
    String? profilePictureUrl,
    String? profileThumbnailUrl,
    String? coverThumbnailUrl,
    List<ChaseUser>? chaseList,
    List<RechaseUser>? rechaseList,
    bool? isPrivate,
    bool? isFriend,
    PostsData? posts,
    String? followStatus,
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
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      profileThumbnailUrl: profileThumbnailUrl ?? this.profileThumbnailUrl,
      coverThumbnailUrl: coverThumbnailUrl ?? this.coverThumbnailUrl,
      chaseList: chaseList ?? this.chaseList,
      rechaseList: rechaseList ?? this.rechaseList,
      isPrivate: isPrivate ?? this.isPrivate,
      isFriend: isFriend ?? this.isFriend,
      posts: posts ?? this.posts,
      followStatus: followStatus ?? this.followStatus,
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
  final int userId;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  ChaseUser({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.isOnline,
  });

  factory ChaseUser.fromJson(Map<String, dynamic> json) {
    return ChaseUser(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
    };
  }
}

class RechaseUser {
  final int userId;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  RechaseUser({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.isOnline,
  });

  factory RechaseUser.fromJson(Map<String, dynamic> json) {
    return RechaseUser(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
    };
  }
}

class PublicPost {
  final int id;
  final String user;
  final String description;
  final String createdAt;
  final List<PublicPostImage> images;
  final List<PublicPoll> polls;
  final List<dynamic> comments;
  final int likesCount;
  final bool isLiked;

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
  });

  factory PublicPost.fromJson(Map<String, dynamic> json) {
    return PublicPost(
      id: json['id'] ?? 0,
      user: json['user'] ?? '',
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
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
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
    };
  }
}

class PublicPostImage {
  final int id;
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
      id: json['id'] ?? 0,
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
  final int id;
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
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      maxOptions: json['max_options'] ?? 0,
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => PublicPollOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalVotes: json['total_votes']?.toString() ?? '0',
      userVote: json['user_vote'],
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
  final int id;
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
      id: json['id'] ?? 0,
      text: json['text'],
      image: json['image'] != null
          ? PollOptionImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] ?? 0).toDouble(),
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
