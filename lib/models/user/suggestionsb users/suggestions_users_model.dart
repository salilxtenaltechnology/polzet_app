class UserSuggestionsModel {
  final String status;
  final SuggestionsData data;

  UserSuggestionsModel({required this.status, required this.data});

  factory UserSuggestionsModel.fromJson(Map<String, dynamic> json) {
    return UserSuggestionsModel(
      status: json['status'] ?? '',
      data: SuggestionsData.fromJson(json['data']),
    );
  }
}

class SuggestionsData {
  final List<SuggestedUser> peopleYouMayKnow;
  final List<dynamic> suggestedCreators;

  SuggestionsData({
    required this.peopleYouMayKnow,
    required this.suggestedCreators,
  });

  factory SuggestionsData.fromJson(Map<String, dynamic> json) {
    return SuggestionsData(
      peopleYouMayKnow:
          (json['suggestions'] as List<dynamic>?)
              ?.map((e) => SuggestedUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      suggestedCreators: json['suggested_creators'] ?? [],
    );
  }
}

class SuggestedUser {
  final int id;
  final String username;
  final String name;
  final String role;
  final String avatar;
  final int mutualFriends;
  final List<String> tags;
  final bool isNew;

  SuggestedUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.avatar,
    required this.mutualFriends,
    required this.tags,
    required this.isNew,
  });

  factory SuggestedUser.fromJson(Map<String, dynamic> json) {
    return SuggestedUser(
      id: json['id'] ?? 0,
      username: json['username'],
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      avatar: json['avatar'] ?? '',
      mutualFriends: json['mutualFriends'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      isNew: json['isNew'] ?? false,
    );
  }
}
