import 'dart:typed_data';
import '../../../models/posts/user_post_model.dart';

class ProfileCache {
  ProfileCache._();
  static final ProfileCache instance = ProfileCache._();

  // Posts
  List<UserPostModel> imagePosts = [];
  List<UserPostModel> textPosts = [];
  int totalImageCount = 0;
  int totalTextCount = 0;

  // Profile
  Uint8List? profileImageBytes;
  Uint8List? coverImageBytes;
  String? profileImageRaw;
  String? coverImageRaw;

  // Followers
  List<Map<String, dynamic>> followers = [];
  List<Map<String, dynamic>> following = [];

  bool get hasImagePosts => imagePosts.isNotEmpty;
  bool get hasTextPosts => textPosts.isNotEmpty;
  bool get hasProfile => profileImageBytes != null;
  bool get hasCover => coverImageBytes != null;
  bool get hasFollowers => followers.isNotEmpty;
  bool get hasFollowing => following.isNotEmpty;

  void clearAll() {
    imagePosts = [];
    textPosts = [];
    totalImageCount = 0;
    totalTextCount = 0;
    profileImageBytes = null;
    coverImageBytes = null;
    profileImageRaw = null;
    coverImageRaw = null;
    followers = [];
    following = [];
  }
}
