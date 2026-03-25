import '../../posts/public_post_model.dart';

class UserPublicProfile {
  final List<PublicPostItem> posts;
  final List<PublicPostPoll> postsPolls;

  UserPublicProfile({required this.posts, required this.postsPolls});

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) {
    return UserPublicProfile(
      posts: (json['posts'] as List)
          .map((postJson) => PublicPostItem.fromJson(postJson))
          .toList(),
      postsPolls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => PublicPostPoll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <PublicPostPoll>[],
    );
  }
}
