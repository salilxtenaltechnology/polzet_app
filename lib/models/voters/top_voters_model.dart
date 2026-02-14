class TopVotersModel {
  final String label;
  final List<TopVoterUser> users;

  TopVotersModel({required this.label, required this.users});

  factory TopVotersModel.fromJson(Map<String, dynamic> json) {
    return TopVotersModel(
      label: json['label']?.toString() ?? '',
      users: (json['users'] as List<dynamic>? ?? [])
          .map((e) => TopVoterUser.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TopVoterUser {
  final int id;
  final String username;
  final String? profilePictureUrl;

  TopVoterUser({
    required this.id,
    required this.username,
    this.profilePictureUrl,
  });

  String get firstLetter =>
      username.isNotEmpty ? username[0].toUpperCase() : '?';

  factory TopVoterUser.fromJson(Map<String, dynamic> json) {
    return TopVoterUser(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      username: json['username']?.toString().trim() ?? '',
      profilePictureUrl: json['profile_picture_url']?.toString(),
    );
  }
}
