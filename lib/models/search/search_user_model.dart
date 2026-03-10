class SearchUserModel {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final bool isFriend;
  final String followStatus;

  SearchUserModel({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    required this.isFriend,
    required this.followStatus,
  });

  factory SearchUserModel.fromJson(Map<String, dynamic> json) {
    return SearchUserModel(
      id: json['id'],
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePicture: json['profile_picture'],
      isFriend: json['is_friend'] ?? false,
      followStatus: json['follow_status'] ?? 'none',
    );
  }
}