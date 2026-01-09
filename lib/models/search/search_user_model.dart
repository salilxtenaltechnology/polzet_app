class SearchUserModel {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePicture;

  SearchUserModel({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
  });

  factory SearchUserModel.fromJson(Map<String, dynamic> json) {
    return SearchUserModel(
      id: json['id'],
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePicture: json['profile_picture'],
    );
  }
}
