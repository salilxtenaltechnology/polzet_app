// ignore_for_file: unused_field, unused_element, non_constant_identifier_names, use_build_context_synchronously
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' hide MultipartFile, Response;
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import '../../data/token/shared_preferences.dart';
import '../../mixin/utility_mixins.dart';
import '../../models/home feed/home_feed_items_model.dart';
import '../../models/posts/image/post_image_model.dart';
import '../../models/posts/post_polls_model.dart';
import '../../models/public/images/public_profile_posts_model.dart';
import '../../models/public/images/public_user_posts.dart';
import '../../models/public/public_profile_model.dart';
import '../../models/public/things/public_post_things_model.dart';
import '../../models/search/search_user_model.dart';
import '../../provider/user_provider.dart';
import '../../screens/home/home_imports.dart';
import '../../widgets/show_toast.dart';
import '../api_config.dart';
import '../app_api.dart';

class ApiService with UtilityMixin {
  final SharedPrefService _prefService = SharedPrefService();
  static final Dio _dio = Dio();

  // Note: Implemented POST Method User Login
  Future<void> loginUser({
    required String email_username,
    required String password,
    required BuildContext context,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'username_or_email': email_username, 'password': password},
      );

      if (response.statusCode == 200) {
        showToast(message: 'Login successful!');
        final String accessToken = response.data['access_token'] ?? '';
        final String refreshToken = response.data['refresh_token'] ?? '';
        _prefService.saveAccessToken(accessToken);
        _prefService.saveRefreshToken(refreshToken);
        Provider.of<UserProvider>(context, listen: false);
        //await userProvider.loadUserData();
        Navigator.pushReplacement(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            duration: const Duration(microseconds: 200),
            child: HomeScreen(),
          ),
        );
      } else if (response.statusCode == 400) {
        showToast(message: 'Error : ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (kDebugMode) {
          showToast(message: 'Internal Server Error');
        }
      } else {
        if (kDebugMode) {
          print('Error : ${e.response?.data}');
        }
        showToast(
          message:
              'An error occurred. Please try again later : ${e.response?.data}',
        );
      }
    }
  }

  // Note: Implemented GET Userdata Method
  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      final accessToken = await SharedPrefService.getAccessToken(); // ac_token
      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }
      final response = await _dio.get(
        ApiConstants.userProfile,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        // print('API call failed with status: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      // print('DioException in fetchUserData: ${e.message}');
      if (e.response != null) {
        // print('Server error: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      // print('Unexpected error in fetchUserData: $e');
      return null;
    }
  }

  // Note: Implemented POST Method User Update Profile
  Future<String> updateProfile({
    required String firstNmame,
    required String lastName,
    required String bio,
    required String dob,
    String? gender,
  }) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {
          'first_name': firstNmame,
          'last_name': lastName,
          'bio': bio,
          'dob': dob,
          if (gender != null) 'gender': gender,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (kDebugMode) {
        print(response);
      }
      if (response.statusCode == 200) {
        showToast(message: 'Profile updated successfully!');

        return 'Profile updated successfully!';
      } else if (response.statusCode == 400) {
        showToast(message: '${response.data['message']}');
        return response.data['message'] ?? 'Failed to update profile';
      } else {
        showToast(message: 'Failed to update profile');
        return 'Failed to update profile';
      }
    } catch (e) {
      showToast(message: 'Failed to update profile');
      return 'An unexpected error occurred';
    }
  }

  // Note: Implemented POST Method User Update Username
  Future<String> updateUsername({required String newUsername}) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.post(
        ApiConstants.updateUsername,
        data: {'new_username': newUsername},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (response.statusCode == 200) {
        showToast(message: 'Username updated successfully!');

        return ''; // Return empty string for success
      } else {
        return 'Failed to update username';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        String errorMessage = '${e.response?.data['message']}.';
        if (kDebugMode) {
          print('Error Status: ${e.response?.statusCode}');
        }

        return errorMessage;
      } else {
        if (kDebugMode) {
          print('Dio error: ${e.message}');
        }
        return 'Network error occurred';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error: $e');
      }
      return 'An unexpected error occurred';
    }
  }

  // Note: Implemented PUT Method User Profile Image
  Future<String> uploadProfileImage(File file) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });
      final response = await _dio.put(
        ApiConstants.profileImage,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      if (response.statusCode == 200) {
        return '';
      } else if (response.statusCode == 413) {
        return 'Image too large maximum size allowed is 10MB.';
      } else {
        return 'Failed to upload profile photo!';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return 'Image too large maximum size allowed is 10MB.';
      }
      return 'Image Upload failed';
    } catch (e) {
      return 'Unexpected error';
    }
  }

  // Note: Implemented PUT Method User Cover Image
  Future<String> uploadCoverPhoto(File file) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'cover_photo': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });
      final response = await _dio.put(
        ApiConstants.coverImage,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      if (response.statusCode == 200) {
        return '';
      } else if (response.statusCode == 413) {
        return 'Image too large maximum size allowed is 10MB.';
      } else {
        return 'Failed to upload cover photo!';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return 'Image too large maximum size allowed is 10MB.';
      }
      return 'Image Upload failed';
    } catch (e) {
      return 'Unexpected error';
    }
  }

  // Note: Implemented POST Method User Update Password
  Future<String> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
    required void Function(
      String? currentPasswordError,
      String? newPasswordError,
      String? confirmPasswordError,
    )
    onError,
  }) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.post(
        ApiConstants.updatePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_new_password': confirmNewPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (response.statusCode == 200) {
        showToast(message: 'Password updated successfully!');
        return '';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response?.statusCode == 400) {
          final errors = e.response?.data['errors'];
          final currentPasswordError = errors?['current_password']?.first;
          final newPasswordError = errors?['new_password']?.first;
          final confirmPasswordError = errors?['confirm_new_password']?.first;
          onError(currentPasswordError, newPasswordError, confirmPasswordError);
          return errors.toString();
        } else {
          if (kDebugMode) {
            print("⚠️ Server Error: ${e.response?.statusCode}");
          }
          return 'Failed to update password!';
        }
      } else {
        if (kDebugMode) {
          print("⚠️ Request failed: ${e.message}");
        }
        return 'An unexpected error occurred!';
      }
    }
    return 'Failed to update password!'; // Ensure all code paths return a String
  }

  static Future<List<HomeFeedPost>> fetchHomeFeedPosts() async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.get(
        ApiConstants.homeFeed,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // ✅ CORRECT: Parse as Map first
        final Map<String, dynamic> jsonData =
            response.data as Map<String, dynamic>;

        // Parse the full response
        final homeFeedResponse = HomeFeedResponse.fromJson(jsonData);

        // Return the posts array
        return homeFeedResponse.results;
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Detailed error: $e');
      }
      throw Exception('Error fetching posts: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFollowersList() async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.get(
        ApiConstants.chaseList,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      ); // adjust endpoint as needed

      if (response.statusCode == 200) {
        final data = response.data;

        // If data is already a list
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        // If data is wrapped in an object (most common case)
        if (data is Map<String, dynamic>) {
          // Adjust the key based on your API response structure
          // Common keys: 'data', 'results', 'followers', 'users'
          final List<dynamic> list =
              data['data'] ?? data['followers'] ?? data['results'] ?? [];
          return List<Map<String, dynamic>>.from(list);
        }

        return [];
      }
      return [];
    } catch (e) {
      print('Error fetching followers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowingList() async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.get(
        ApiConstants.reChaseList,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      ); // adjust endpoint as needed

      if (response.statusCode == 200) {
        final data = response.data;

        // If data is already a list
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        // If data is wrapped in an object (most common case)
        if (data is Map<String, dynamic>) {
          // Adjust the key based on your API response structure
          final List<dynamic> list =
              data['data'] ?? data['following'] ?? data['results'] ?? [];
          return List<Map<String, dynamic>>.from(list);
        }

        return [];
      }
      return [];
    } catch (e) {
      print('Error fetching following: $e');
      return [];
    }
  }

  // Note: Implemented GET Method User Post Feed
  Future<List<PostPolls>> fetchPostsPolls(String username) async {
    try {
      final response = await _dio.get("${ApiConstants.userPosts}/$username");

      // Extract the 'results' array from the paginated response
      final List<dynamic> data = response.data['results'] as List<dynamic>;
      if (kDebugMode) {
        // print('POSTS : $data');
      }
      return data.map((e) => PostPolls.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching posts: $e');
      }
      rethrow;
    }
  }

  // Add this method to get only posts with polls
  Future<List<PostPolls>> fetchOnlyPollPosts(String username) async {
    final allPosts = await fetchPostsPolls(username);
    // Filter out posts that have empty polls array
    return allPosts.where((post) => post.polls.isNotEmpty).toList();
  }

  // Note: Implemented GET Method User Post Images
  Future<List<PostImagesModel>> fetchPostsImages(String username) async {
    try {
      final response = await _dio.get("${ApiConstants.userPosts}/$username");
      final List<dynamic> data = response.data['results'] as List<dynamic>;
      return data.map((e) => PostImagesModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PostImagesModel>> fetchImagePosts(String username) async {
    final allPosts = await fetchPostsImages(username);
    return allPosts.where((p) => p.images.isNotEmpty).toList();
  }

  // Method to upload post with loading states
  static Future<Map<String, dynamic>?> uploadImagePoll({
    required String description,
    required String question,
    required List<File> pollOptions,
    required int maxOptions,
    String? authToken,
    Function(double)? onProgress,
    int maxFileSizeMB = 10, // 10MB per file
  }) async {
    try {
      // Validate number of images
      if (pollOptions.isEmpty) {
        throw Exception('At least one image is required');
      }

      if (pollOptions.length > maxOptions) {
        throw Exception('Maximum $maxOptions images allowed');
      }

      // Validate file sizes
      for (var image in pollOptions) {
        int fileSizeInBytes = await image.length();
        double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (fileSizeInMB > maxFileSizeMB) {
          throw Exception(
            'Image too large. Maximum size allowed is ${maxFileSizeMB}MB per image',
          );
        }
      }

      // Create FormData
      FormData formData = FormData();

      // Add text fields
      formData.fields.add(MapEntry('description', description));
      formData.fields.add(MapEntry('question', question));
      formData.fields.add(MapEntry('max_options', maxOptions.toString()));

      // Add images as poll_options
      for (int i = 0; i < pollOptions.length; i++) {
        File imageFile = pollOptions[i];
        String fileName = path.basename(imageFile.path);

        MultipartFile multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: MediaType(
            'image',
            'jpeg',
          ), // Adjust based on your image type
        );

        // Add each image as 'poll_options' (matching your Postman structure)
        formData.files.add(MapEntry('poll_options', multipartFile));
      }

      // Set headers
      Map<String, dynamic> headers = {'Content-Type': 'multipart/form-data'};

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      if (kDebugMode) {
        print('Uploading ${pollOptions.length} images for poll');
        print('Description: $description');
        print('Question: $question');
      }

      // Make request with progress tracking
      Response response = await ApiService._dio.post(
        ApiConstants.userPosts, // Update this to your correct endpoint
        data: formData,
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total != -1) {
            double progress = sent / total;
            onProgress(progress);
            if (kDebugMode) {
              print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
            }
          }
        },
      );

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response data: ${response.data}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 413) {
        throw Exception(
          'Image too large. Maximum size allowed is ${maxFileSizeMB}MB',
        );
      } else if (response.statusCode == 400) {
        String errorMsg = 'Bad request';
        if (response.data != null && response.data is Map) {
          errorMsg = response.data['message'] ?? errorMsg;
        }
        throw Exception(errorMsg);
      } else {
        throw Exception(
          'Failed to upload poll. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 413) {
        throw Exception(
          'Image too large. Maximum size allowed is ${maxFileSizeMB}MB',
        );
      } else if (e.response?.statusCode == 400) {
        String errorMsg = 'Bad request';
        if (e.response?.data != null && e.response?.data is Map) {
          errorMsg = e.response?.data['message'] ?? errorMsg;
        }
        throw Exception(errorMsg);
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Please check your internet connection',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Upload timeout. Please try again');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading poll: $e');
      }
      rethrow;
    }
  }

  // Note: Implemented DELETE Method User Delete Post
  Future<bool> userDeletePost(int postId) async {
    final accessToken = await SharedPrefService.getAccessToken();

    try {
      final response = await _dio.delete(
        "${ApiConstants.deletePost}/$postId/delete",
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete post: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error deleting post: $error');
    }
  }

  // Updated searchUsers method based on Postman response
  Future<List<SearchUserModel>> searchUsers(String query) async {
    final accessToken = await SharedPrefService.getAccessToken();

    try {
      final response = await _dio.get(
        ApiConstants.searchUsers,
        queryParameters: {'q': query},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Check if results exist and is not null
        if (data != null && data['results'] != null) {
          final results = data['results'] as List;
          return results.map((e) => SearchUserModel.fromJson(e)).toList();
        } else {
          // Return empty list if no results
          return [];
        }
      } else if (response.statusCode == 400) {
        final errorMsg =
            response.data['message'] ?? 'Please enter at least 2 characters';
        throw Exception(errorMsg);
      } else {
        throw Exception('Failed to fetch users');
      }
    } on DioException catch (e) {
      // Handle Dio specific errors
      if (e.response?.statusCode == 400) {
        final errorMsg =
            e.response?.data['message'] ?? 'Please enter at least 2 characters';
        throw Exception(errorMsg);
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Please check your internet connection',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server is taking too long to respond');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> checkFriendRequestStatus(String username) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/friend_requests',
        data: {'receiver_username': username},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${accessToken}',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            // Accept both 200 and 400 status codes
            return status != null && (status == 200 || status == 400);
          },
        ),
      );

      if (response.statusCode == 400) {
        // Check if the error message indicates already following
        final message = response.data['message'] as String?;
        if (message != null &&
            (message.toLowerCase().contains('already following') ||
                message.toLowerCase().contains('already sent'))) {
          return true; // Request already sent or already following
        }
      }

      if (response.statusCode == 200) {
        // Request was successfully sent (first time)
        return false;
      }

      return false;
    } on DioException catch (e) {
      debugPrint('Error checking friend request status: ${e.message}');

      // Handle 400 error specifically
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        if (message != null &&
            (message.toLowerCase().contains('already following') ||
                message.toLowerCase().contains('already sent'))) {
          return true; // Already sent or following
        }
      }

      // For other errors, assume not sent
      return false;
    } catch (e) {
      debugPrint('Unexpected error checking friend request status: $e');
      return false;
    }
  }

  // Note: Implemented POST Method User Send Friend Request
  Future<bool> sendFriendRequest(String username) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.post(
        ApiConstants.sendRequest,
        data: {'receiver_username': username},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      print(response);
      if (response.statusCode == 201 && response.data['status'] == 'success') {
        showToast(message: 'Friend request sent!');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // print('Error sending friend request: $e');
      return false;
    }
  }

  // Note: Implemented GET Method User Public Profile
  static Future<PublicProfileModel> getUserPublicProfile(int userId) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.get(
        "${ApiConstants.publicProfile}/$userId/profile",
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200) {
        final publicData = response.data;

        if (publicData['status'] == 'success') {
          return PublicProfileModel.fromJson(publicData);
        } else {
          throw Exception('API returned error: ${publicData['message']}');
        }
      } else {
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Note: Implemented GET Method User Public Profile Posts
  Future<PublicProfileModel?> getPublicProfilePosts(int userId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.userPosts}/users/$userId/profile',
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return PublicProfileModel.fromJson(response.data['data']);
      } else {
        print('API Error: ${response.data['message'] ?? 'Unknown error'}');
        return null;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print('DioException: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      print('Unexpected Error: $e');
      return null;
    }
  }

  Future<UserPublicProfile> getPublicPosts(int userId) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.get(
        '${ApiConstants.publicProfile}/$userId/profile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          return UserPublicProfile.fromJson(jsonData['data']);
        } else {
          throw Exception('API Error: ${jsonData['message']}');
        }
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<PublicPost>> fetchPostsWithImages(int userId) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();
      final response = await _dio.get(
        '${ApiConstants.publicProfile}/$userId/profile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          // Access posts.results array from the nested structure
          final postsData = jsonData['data']['posts']['results'] as List;

          // Parse all posts
          final allPosts = postsData
              .map((postJson) => PublicPost.fromJson(postJson))
              .toList();

          // Filter posts that have images
          return allPosts.where((post) => post.images.isNotEmpty).toList();
        } else {
          throw Exception('API Error: ${jsonData['message']}');
        }
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching posts with images: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<List<PublicPostPolls>> fetchPublicPostsPolls(int userId) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();
      final response = await _dio.get(
        '${ApiConstants.publicProfile}/$userId/profile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          // FIXED: Access posts.results array instead of posts directly
          final postsData = jsonData['data']['posts']['results'] as List;

          // Parse all posts with polls
          final allPosts = postsData
              .map((postJson) => PublicPostPolls.fromJson(postJson))
              .toList();

          // Filter posts that have polls
          return allPosts
              .where((post) => post.publicPollQuestion.isNotEmpty)
              .toList();
        } else {
          throw Exception('API Error: ${jsonData['message']}');
        }
      } else {
        throw Exception('Failed to load polls: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching posts with polls: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> togglePostLike(int postId) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      // Construct the API endpoint
      final url = Uri.parse('${ApiConfig.baseUrl}/posts/$postId/like');

      // Make the POST request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      // Parse the response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Success',
          'data': data,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update like',
        };
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  // Optional: Get post likes count
  static Future<Map<String, dynamic>> getPostLikes(int postId) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/posts/$postId/likes');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch likes'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  // Note: Implemented GET Method - Get Post Comments
  static Future<Map<String, dynamic>> getPostComments(int postId) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/posts/$postId/comments',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      // Remove the status code check - Dio only returns response for successful status codes
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in getPostComments: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      // Handle 401 Unauthorized
      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      }

      // Handle 404 Not Found (post doesn't exist)
      if (e.response?.statusCode == 404) {
        return {'success': false, 'message': 'Post not found'};
      }

      // Handle connection timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      }

      // Handle no internet connection
      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'message': 'No internet connection'};
      }

      // Generic error with server response
      return {
        'success': false,
        'message':
            e.response?.data['message'] ??
            e.response?.data['detail'] ??
            'Failed to fetch comments',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getPostComments: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // Note: Implemented POST Method - Create Comment
  static Future<Map<String, dynamic>> createComment({
    required int postId,
    required String text,
  }) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      // Validate comment text
      if (text.trim().isEmpty) {
        return {'success': false, 'message': 'Comment cannot be empty'};
      }

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/comments',
        data: {'text': text.trim()},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Comment posted successfully',
          'data': response.data,
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to post comment',
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in createComment: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      } else if (e.response?.statusCode == 400) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Invalid comment data',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      } else {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Network error',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in createComment: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  static Future<Map<String, dynamic>> editComment({
    required int commentId,
    required String text,
  }) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.patch(
        '${ApiConstants.baseUrl}/comments/$commentId/edit',
        data: {'text': text},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in editComment: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      }

      if (e.response?.statusCode == 404) {
        return {'success': false, 'message': 'Comment not found'};
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      }

      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'message': 'No internet connection'};
      }

      return {
        'success': false,
        'message':
            e.response?.data['message'] ??
            e.response?.data['detail'] ??
            'Failed to edit comment',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in editComment: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // Delete Comment API
  static Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.delete(
        '${ApiConstants.baseUrl}/comments/$commentId/delete',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in deleteComment: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      }

      if (e.response?.statusCode == 404) {
        return {'success': false, 'message': 'Comment not found'};
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      }

      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'message': 'No internet connection'};
      }

      return {
        'success': false,
        'message':
            e.response?.data['message'] ??
            e.response?.data['detail'] ??
            'Failed to delete comment',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in deleteComment: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // static Future<Map<String, dynamic>> voteOnPoll({
  //   required int postId,
  //   required int optionId,
  // }) async {
  //   try {
  //     final accessToken = await SharedPrefService.getAccessToken();

  //     if (accessToken == null || accessToken.isEmpty) {
  //       return {
  //         'success': false,
  //         'message': 'Authentication token not found',
  //         'option_id': optionId,
  //       };
  //     }

  //     final response = await _dio.post(
  //       '${ApiConstants.baseUrl}/posts/$postId/vote/$optionId',
  //       data: {'option': optionId},
  //       options: Options(
  //         headers: {
  //           'Authorization': 'Bearer $accessToken',
  //           'Content-Type': 'application/json',
  //           'Accept': 'application/json',
  //         },
  //       ),
  //     );

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       return {
  //         'success': true,
  //         'message': 'Vote added successfully',
  //         'data': response.data,
  //         'option_id': optionId,
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'message': response.data['message'] ?? 'Failed to vote',
  //         'status_code': response.statusCode,
  //         'option_id': optionId,
  //       };
  //     }
  //   } on DioException catch (e) {
  //     if (kDebugMode) {
  //       print('DioException voting for option $optionId: ${e.message}');
  //       print('Response: ${e.response?.data}');
  //     }

  //     if (e.response?.statusCode == 401) {
  //       return {
  //         'success': false,
  //         'message': 'Unauthorized. Please login again.',
  //         'option_id': optionId,
  //       };
  //     } else if (e.response?.statusCode == 400) {
  //       return {
  //         'success': false,
  //         'message': e.response?.data['message'] ?? 'Invalid vote data',
  //         'option_id': optionId,
  //       };
  //     } else if (e.type == DioExceptionType.connectionTimeout) {
  //       return {
  //         'success': false,
  //         'message':
  //             'Connection timeout. Please check your internet connection',
  //         'option_id': optionId,
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'message': e.response?.data['message'] ?? 'Network error',
  //         'option_id': optionId,
  //       };
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error voting for option $optionId: $e');
  //     }
  //     return {
  //       'success': false,
  //       'message': 'An unexpected error occurred',
  //       'option_id': optionId,
  //     };
  //   }
  // }

  static Future<Map<String, dynamic>> voteOnPollMultiple({
    required int postId,
    required List<Map<String, int>> votes,
  }) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/vote',
        data: {"votes": votes},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Votes saved successfully',
          'data': response.data['data'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to submit votes',
          'status_code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException submitting votes: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      } else if (e.response?.statusCode == 400) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Invalid vote data',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      } else {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Network error',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting votes: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> getPollResults(int postId) async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/posts/$postId/poll_results'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load poll results: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching poll results: $e');
    }
  }

  static Future<Map<String, dynamic>?> addGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/api/chats/group/create', // adjust based on your API
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {'title': title, 'members': memberIds},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }
}
