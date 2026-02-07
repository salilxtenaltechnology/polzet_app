class UserProfileModel {
  final String firstName;
  final String lastName;
  final String username;
  final String? dob;
  final String gender;
  final String bio;
  final String email;
  final String mobileNumber;
  final String countryCode;
  final String? profilePictureUrl;
  final String? coverPhotoUrl;

  UserProfileModel({
    required this.firstName,
    required this.lastName,
    required this.username,
    this.dob,
    required this.gender,
    required this.bio,
    required this.email,
    required this.mobileNumber,
    required this.countryCode,
    this.profilePictureUrl,
    this.coverPhotoUrl,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      dob: json['dob'],
      gender: json['gender'] ?? 'Other',
      bio: json['bio'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      countryCode: json['country_code']?.replaceAll('+', '') ?? '91',
      profilePictureUrl: json['profile_picture_url'],
      coverPhotoUrl: json['cover_photo_url'],
    );
  }

  UserProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? dob,
    String? gender,
    String? bio,
    String? email,
    String? mobileNumber,
    String? countryCode,
  }) {
    return UserProfileModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      countryCode: countryCode ?? this.countryCode,
      profilePictureUrl: profilePictureUrl,
      coverPhotoUrl: coverPhotoUrl,
    );
  }
}
