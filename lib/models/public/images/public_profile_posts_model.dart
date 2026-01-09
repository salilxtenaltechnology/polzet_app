import '../things/public_post_things_model.dart';
import 'public_user_posts.dart';

class UserPublicProfile {
  final List<PublicPost> posts;
  final List<PublicPostPolls> postsPolls;

  UserPublicProfile({required this.posts, required this.postsPolls});

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) {
    return UserPublicProfile(
      posts: (json['posts'] as List)
          .map((postJson) => PublicPost.fromJson(postJson))
          .toList(),
      postsPolls: (json['polls'] as List<dynamic>?)
              ?.map((e) => PublicPostPolls.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <PublicPostPolls>[],
    );
  }
}
