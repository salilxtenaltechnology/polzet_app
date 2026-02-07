import '../public_profile_model.dart';

class UserPublicProfile {
  final List<PublicPost> posts;
  final List<PublicPoll> postsPolls;

  UserPublicProfile({required this.posts, required this.postsPolls});

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) {
    return UserPublicProfile(
      posts: (json['posts'] as List)
          .map((postJson) => PublicPost.fromJson(postJson))
          .toList(),
      postsPolls:
          (json['polls'] as List<dynamic>?)
              ?.map((e) => PublicPoll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <PublicPoll>[],
    );
  }
}
