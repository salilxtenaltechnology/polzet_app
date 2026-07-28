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
  final String userId;
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
  final bool isPrivate;
  final bool isFriend;
  final String followStatus;
  final dynamic chatId;

  ProfileData({
    required this.id,
    required this.userId,
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
    required this.isPrivate,
    required this.isFriend,
    required this.followStatus,
    required this.chatId,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: (json['uuid'] ?? json['id'] ?? '').toString(),
      userId: (json['id'] ?? json['userid'] ?? json['user_id'] ?? '').toString(),
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
      isPrivate: json['is_private'] ?? false,
      isFriend: json['is_friend'] ?? false,
      followStatus: json['follow_status'] ?? '',
      chatId: json['chat_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
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
      'is_private': isPrivate,
      'is_friend': isFriend,
      'follow_status': followStatus,
      'chat_id': chatId,
    };
  }

  ProfileData copyWith({
    String? id,
    String? userId,
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
    bool? isPrivate,
    bool? isFriend,
    String? followStatus,
    dynamic chatId,
  }) {
    return ProfileData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
      isPrivate: isPrivate ?? this.isPrivate,
      isFriend: isFriend ?? this.isFriend,
      followStatus: followStatus ?? this.followStatus,
      chatId: chatId ?? this.chatId,
    );
  }
}



int _toInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return int.tryParse(value.toString()) ?? defaultValue;
}
