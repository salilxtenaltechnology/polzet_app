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
  final bool isFriend; 

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
    required this.isFriend, 
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
      isFriend: data['is_friend'] ?? false, 
    );
  }
}
