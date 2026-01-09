import 'api_config.dart';

class ApiConstants {
  static String baseUrl = ApiConfig.baseUrl;

  static String login = "$baseUrl/login";
  static String registration = "$baseUrl/registration";
  static String changePassword = "$baseUrl/update_password";
  static String emailVerify = "$baseUrl/email_verification";
  static String validateOtp = "$baseUrl/validate_otp";
  static String forgotPasswordEmail = "$baseUrl/forgot_password_email";
  static String forgotPasswordVerify = "$baseUrl/forgot_password_verify";
  static String userProfile = "$baseUrl/profile";
  static String updateProfile = "$baseUrl/profile";
  static String updatePassword = "$baseUrl/profile/change_password";
  static String updateUsername = "$baseUrl/profile/change_username";
  static String profileImage = "$baseUrl/profile/picture";
  static String coverImage = "$baseUrl/profile/cover";
  static String sendRequest = "$baseUrl/friend_requests";
  static String friendRequest = "$baseUrl/friend_requests";
  static String acceptRequest = "$baseUrl/friend_requests";
  static String deleteRequest = "$baseUrl/friend_requests";
  static String searchUsers = "$baseUrl/users";
  static String blockUser = "$baseUrl/block_user";
  static String userPosts = "$baseUrl/posts";
  static String deletePost = "$baseUrl/posts";
  static String chaseList = "$baseUrl/friends/followers";
  static String reChaseList = "$baseUrl/friends/following";
  static String publicProfile = "$baseUrl/users";
  static String homeFeed = "$baseUrl/home_feed";
  static String pollOnThings = "$baseUrl/posts";
  static String likePost = "$baseUrl/posts";
  static String logout = "$baseUrl/logout";
}
