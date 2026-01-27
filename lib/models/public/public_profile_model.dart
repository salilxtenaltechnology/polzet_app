class PublicProfileModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String dob;
  final String gender;
  final String countryCode;
  final String mobileNumber;
  final String bio;
  final String nextUsernameChange;
  final int followersCount;
  final int followingCount;
  final int imagePostCount;
  final int textPostCount;
  final String profilePictureUrl;
  final String coverPictureUrl;
  final bool isPrivate;
  final bool isFriend;
  final String? followStatus; // New field for follow status

  PublicProfileModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.gender,
    required this.countryCode,
    required this.mobileNumber,
    required this.bio,
    required this.nextUsernameChange,
    required this.followersCount,
    required this.followingCount,
    required this.imagePostCount,
    required this.textPostCount,
    required this.profilePictureUrl,
    required this.coverPictureUrl,
    required this.isPrivate,
    required this.isFriend,
    this.followStatus, // Optional field
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return PublicProfileModel(
      id: data['id'] ?? 0,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      dob: data['dob'] ?? '',
      gender: data['gender'] ?? '',
      countryCode: data['country_code'] ?? '',
      mobileNumber: data['mobile_number'] ?? '',
      bio: data['bio'] ?? '',
      nextUsernameChange: data['next_username_change'] ?? '',
      followersCount: data['followers_count'] ?? 0,
      followingCount: data['following_count'] ?? 0,
      imagePostCount: data['image_post_count'] ?? 0,
      textPostCount: data['text_post_count'] ?? 0,
      profilePictureUrl: data['profile_picture_url'] ?? '',
      coverPictureUrl: data['cover_thumbnail_url'] ?? '',
      isPrivate: data['is_private'] ?? false,
      isFriend: data['is_friend'] ?? false,
      followStatus: data['follow_status'], // Parse follow_status from API
    );
  }

  // Optional: Create a copy method for easier state updates
  PublicProfileModel copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? countryCode,
    String? mobileNumber,
    String? bio,
    String? nextUsernameChange,
    int? followersCount,
    int? followingCount,
    int? imagePostCount,
    int? textPostCount,
    String? profilePictureUrl,
    String? coverPictureUrl,
    bool? isPrivate,
    bool? isFriend,
    String? followStatus,
  }) {
    return PublicProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      countryCode: countryCode ?? this.countryCode,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      bio: bio ?? this.bio,
      nextUsernameChange: nextUsernameChange ?? this.nextUsernameChange,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      imagePostCount: imagePostCount ?? this.imagePostCount,
      textPostCount: textPostCount ?? this.textPostCount,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      coverPictureUrl: coverPictureUrl ?? this.coverPictureUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      isFriend: isFriend ?? this.isFriend,
      followStatus: followStatus ?? this.followStatus,
    );
  }
}