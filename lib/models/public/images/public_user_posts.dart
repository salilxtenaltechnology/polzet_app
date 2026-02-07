// import 'public_posts_image.dart';

// class PublicPost {
//   final int id;
//   final String user;
//   final String description;
//   final String createdAt;
//   final List<PublicPostImage> images;

//   PublicPost({
//     required this.id,
//     required this.user,
//     required this.description,
//     required this.createdAt,
//     required this.images,
//   });

//   factory PublicPost.fromJson(Map<String, dynamic> json) {
//     return PublicPost(
//       id: json['id'],
//       user: json['user'],
//       description: json['description'],
//       createdAt: json['created_at'],
//       images: (json['images'] as List)
//           .map((imageJson) => PublicPostImage.fromJson(imageJson))
//           .toList(),
//     );
//   }
// }
