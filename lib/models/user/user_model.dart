class UserModel {
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String dob;
  final String? gender;
  final String countryCode;
  final String mobileNumber;
  final String? profilePicture;
  final String? coverPhoto;
  final String? bio;
  final List<dynamic>? interests;
  final String? country;
  final DateTime nextUsernameChange;
  final String? profilePictureUrl;
  final String? coverPhotoUrl;

  UserModel({
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dob,
    this.gender,
    required this.countryCode,
    required this.mobileNumber,
    this.profilePicture,
    this.coverPhoto,
    this.bio,
    this.interests,
    this.country,
    required this.nextUsernameChange,
    this.profilePictureUrl,
    this.coverPhotoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      dob: json['dob'] ?? '',
      gender: json['gender'],
      countryCode: json['country_code'] ?? json['country'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      profilePicture: json['profile_picture'],
      coverPhoto: json['cover_photo'],
      bio: json['bio'],
      interests: json['interests'] != null ? List<dynamic>.from(json['interests']) : null,
      country: json['country'] ?? json['country_code'],
      nextUsernameChange: DateTime.parse(json['next_username_change'] ?? DateTime.now().toIso8601String()),
      profilePictureUrl: json['profile_picture_url'],
      coverPhotoUrl: json['cover_photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'dob': dob,
      'gender': gender,
      'country_code': countryCode,
      'mobile_number': mobileNumber,
      'profile_picture': profilePicture,
      'cover_photo': coverPhoto,
      'bio': bio,
      'interests': interests,
      'country': country,
      'next_username_change': nextUsernameChange.toIso8601String(),
      'profile_picture_url': profilePictureUrl,
      'cover_photo_url': coverPhotoUrl,
    };
  }
}
