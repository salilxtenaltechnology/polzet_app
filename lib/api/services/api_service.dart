// ignore_for_file: unused_field, unused_element, non_constant_identifier_names, use_build_context_synchronously
import 'dart:async';
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
import '../../models/global search/global_search_model.dart';
import '../../models/hashtags/enhanced_trending_hashtags_model.dart';
import '../../models/insights/insights_model.dart';
import '../../models/like/like_uers_model.dart';
import '../../models/message/message_model.dart';
import '../../models/posts/homefeed_posts_model.dart';
import '../../models/posts/single_post_model.dart';
import '../../models/posts/user_post_model.dart';
import '../../models/public/public_profile_model.dart';
import '../../models/search/hashtag/hashtag_posts_list_model.dart';
import '../../models/search/search_user_model.dart';
import '../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../models/voters/top_voters_model.dart';
import '../../provider/connection_provider.dart';
import '../../provider/user_provider.dart';
import '../../screens/home/home_imports.dart';
import '../../widgets/show_toast.dart';
import '../api_config.dart';
import '../app_api.dart';
import 'fcm/fcm_service.dart';
import 'notification/notification_services.dart';

class ApiService with UtilityMixin {
  final SharedPrefService _prefService = SharedPrefService();
  final NotificationService _notificationService = NotificationService();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    // Intercept API responses globally to detect 500 level errors for the ServerDown BottomSheet
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          final ignore500 = e.requestOptions.headers['Ignore-500'] == 'true';
          if (!ignore500 &&
              e.response?.statusCode != null &&
              e.response!.statusCode! >= 500) {
            ServerMonitor.reportServerDown();
          }
          return handler.next(e);
        },
      ),
    );
  }

  static bool simulateError = false;
  static String simulateErrorType = 'none';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (status) => status != null && status < 500,
      responseType: ResponseType.json,
    ),
  );

  static const int _maxFileSizeMB = 10;
  static const String _errorMessageGeneric = 'An unexpected error occurred';
  static const String _errorMessageNetwork = 'Network error. Please try again.';
  static const String _errorMessageAuth = 'Unauthorized. Please login again.';

  /// Get authorization headers with access token
  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await SharedPrefService.getToken();
    return {
      'Authorization': 'Bearer ${accessToken ?? ''}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  String _handleDioError(
    DioException e, {
    String defaultMessage = _errorMessageGeneric,
  }) {
    if (kDebugMode) {
      debugPrint('DioException: ${e.message}');
      debugPrint('Response: ${e.response?.data}');
    }

    final statusCode = e.response?.statusCode;

    if (statusCode == 401) return _errorMessageAuth;
    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (statusCode == 404) return 'The requested resource was not found.';

    // Server errors (500+)
    if (statusCode != null && statusCode >= 500) {
      return 'We encountered a temporary issue with our servers. Please try again.';
    }

    // Network & Timeout Errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection available.';
    }

    // Only passthrough backend error string if it is a 4xx validation/client error.
    // Otherwise, mask it behind the generic message to prevent leaking system errors.
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      if (e.response?.data != null && e.response?.data is Map) {
        return e.response?.data['message']?.toString() ??
            e.response?.data['detail']?.toString() ??
            defaultMessage;
      }
    }

    return defaultMessage;
  }

  /// Validate file size
  Future<bool> _validateFileSize(
    File file, {
    int maxSizeMB = _maxFileSizeMB,
  }) async {
    final fileSizeInBytes = await file.length();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    return fileSizeInMB <= maxSizeMB;
  }

  // ==================== AUTHENTICATION ====================

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
        final accessToken = response.data['access_token'] ?? '';
        final refreshToken = response.data['refresh_token'] ?? '';

        await SharedPrefService.setToken(accessToken);
        await SharedPrefService.setRefreshToken(refreshToken);
        await _notificationService.initialize();
        await _notificationService.connectToWebSocket(accessToken);

        // Register FCM Token immediately
        final fcmToken = await _notificationService.getFCMToken();
        if (fcmToken != null) {
          final platform = Platform.isAndroid ? 'android' : 'ios';
          await FcmApiService.registerFcmToken(fcmToken, platform);
        }

        if (context.mounted) {
          Provider.of<UserProvider>(context, listen: false);
          Navigator.pushReplacement(
            context,
            PageTransition(
              type: PageTransitionType.fade,
              duration: const Duration(milliseconds: 200),
              child: const HomeScreen(),
            ),
          );
        }

        showToast(message: 'Login successful!');
      } else if (response.statusCode == 400) {
        showToast(message: 'Error: ${response.data['message']}');
      }
    } on DioException catch (e) {
      showToast(message: _handleDioError(e, defaultMessage: 'Login failed'));
    }
  }

  Future socialLogin(String googleToken) async {
    try {
      // debugPrint('📤 socialLogin token: $googleToken');

      final response = await _dio.post(
        ApiConstants.socialAuth,
        data: {'provider': 'google', 'id_token': googleToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }

      throw Exception('Unexpected status code: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Social login failed');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acceptPrivacyStatus({
    required String status,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.privacyPolicy,
        data: FormData.fromMap({'status': status}),
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'message': 'Failed to update privacy status'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(
          e,
          defaultMessage: 'Failed to update privacy status',
        ),
      };
    }
  }
  // ==================== USER PROFILE ====================

  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      final accessToken = await SharedPrefService.getToken();
      if (accessToken == null || accessToken.isEmpty) return null;

      final response = await _dio.get(
        ApiConstants.userProfile,
        options: Options(headers: await _getAuthHeaders()),
      );

      final String userId = response.data['id'].toString();
      await _prefService.saveUserId(userId);

      return response.statusCode == 200 ? response.data : null;
    } on DioException catch (e) {
      debugPrint('Error fetching user data: ${e.message}');
      return null;
    }
  }

  // Note: Implemented POST Method User Update Profile
  Future<String> updateProfile({
    required String firstName,
    required String lastName,
    required String bio,
    required String dob,
    String? gender,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'bio': bio,
          'dob': dob,
          if (gender != null) 'gender': gender,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Profile updated successfully!');
        return '';
      }

      final message = response.data['message'] ?? 'Failed to update profile';
      showToast(message: message);
      return message;
    } on DioException catch (e) {
      final message = _handleDioError(
        e,
        defaultMessage: 'Failed to update profile',
      );
      showToast(message: message);
      return message;
    }
  }

  // Note: Implemented POST Method User Update Username
  Future<String> updateUsername({required String newUsername}) async {
    try {
      final response = await _dio.post(
        ApiConstants.updateUsername,
        data: {'new_username': newUsername},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Username updated successfully!');
        return '';
      }
      return 'Failed to update username';
    } on DioException catch (e) {
      return _handleDioError(e, defaultMessage: 'Failed to update username');
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
    try {
      final response = await _dio.post(
        ApiConstants.updatePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_new_password': confirmNewPassword,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Password updated successfully!');
        return '';
      }
      return 'Failed to update password';
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data['errors'];
        onError(
          errors?['current_password']?.first,
          errors?['new_password']?.first,
          errors?['confirm_new_password']?.first,
        );
        return errors.toString();
      }
      return _handleDioError(e, defaultMessage: 'Failed to update password');
    }
  }

  Future<String> setPassword(String password) async {
    // final String? googleToken = await SharedPrefService.getString(
    //   'jwt_google_token',
    // );

    try {
      final response = await _dio.post(
        ApiConstants.setPassword,
        // options: Options(headers: {'Authorization': 'Bearer $googleToken'}),
        options: Options(headers: await _getAuthHeaders()),
        data: {'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ''; // ✅ empty = success
      }

      return response.data['message'] ?? 'Failed to set password';
    } on DioException catch (e) {
      debugPrint('❌ DioException status: ${e.response?.statusCode}');
      debugPrint('❌ DioException data: ${e.response?.data}');

      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ??
            data['detail'] ??
            data['error'] ??
            'Failed to set password';
      }

      return 'Failed to set password';
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return 'Unexpected error occurred';
    }
  }

  // NOTE : Implemented PATCH Method User Update Private Account
  Future<String> updateAccountPrivacy({required bool isPrivate}) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {'is_private': isPrivate.toString()},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final message = isPrivate
            ? 'Account is now private'
            : 'Account is now public';
        showToast(message: message);
        return message;
      }

      final message = response.data['message'] ?? 'Failed to update privacy';
      showToast(message: message);
      return message;
    } on DioException catch (e) {
      final message = _handleDioError(
        e,
        defaultMessage: 'Failed to update privacy',
      );
      showToast(message: message);
      return message;
    }
  }

  Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final response = await _dio.delete(
        ApiConstants.deleteAccount,
        data: {'password': password},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message']};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to delete account',
        };
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to delete account';
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  //*==================== IMAGE UPLOADS ====================*//

  // Upload profile picture
  Future<String> uploadProfileImage(File file) async {
    try {
      if (!await _validateFileSize(file)) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }

      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(
          file.path,
          filename: path.basename(file.path),
        ),
      });

      final response = await _dio.put(
        ApiConstants.profileImage,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Profile picture updated!');
        return '';
      }
      return 'Failed to upload profile photo';
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }
      return _handleDioError(e, defaultMessage: 'Image upload failed');
    }
  }

  // Note: Implemented PUT Method User Cover Image
  Future<String> uploadCoverPhoto(File file) async {
    try {
      if (!await _validateFileSize(file)) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }

      final formData = FormData.fromMap({
        'cover_photo': await MultipartFile.fromFile(
          file.path,
          filename: path.basename(file.path),
        ),
      });

      final response = await _dio.put(
        ApiConstants.coverImage,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Cover photo updated!');
        return '';
      }
      return 'Failed to upload cover photo';
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }
      return _handleDioError(e, defaultMessage: 'Image upload failed');
    }
  }

  // ==================== POSTS ====================

  // Suggestion users
  Future<UserSuggestionsModel> fetchUserSuggestions() async {
    try {
      final response = await _dio.get(
        ApiConstants.suggestionUsers,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;

        return UserSuggestionsModel.fromJson(jsonData);
      }
      throw Exception('Failed to load suggestions: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching user suggestions: $e');
      throw Exception('Error fetching user suggestions: $e');
    }
  }

  static Future<HomeFeedResponse> fetchHomeFeedPosts({
    String? url,
    bool isPagination = false,
  }) async {
    // // ✅ Test simulation — auto-removed in release builds
    // assert(() {
    //   if (simulateError) {
    //     switch (simulateErrorType) {
    //       case 'no_internet':
    //         throw const SocketException('Simulated no internet');
    //       case 'server':
    //         throw DioException(
    //           requestOptions: RequestOptions(path: ''),
    //           response: Response(
    //             requestOptions: RequestOptions(path: ''),
    //             statusCode: 500,
    //           ),
    //           type: DioExceptionType.badResponse,
    //         );
    //       case 'timeout':
    //         throw TimeoutException('Simulated timeout');
    //     }
    //   }
    //   return true;
    // }());

    try {
      final accessToken = await SharedPrefService.getToken();
      final response = await _dio.get(
        url ?? ApiConstants.homeFeed,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            if (isPagination) 'Ignore-500': 'true',
          },
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        return HomeFeedResponse.fromJson(jsonData);
      }
      throw Exception('Failed to load posts: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching home feed: $e');
      throw Exception('Error fetching posts: $e');
    }
  }

  Future<SinglePostModel> getSinglePost(String username, int postId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.singlePost}/$username/$postId/',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        return SinglePostModel.fromJson(jsonData);
      }
      throw Exception('Failed to load post: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching single post: $e');
      throw Exception('Error fetching single post: $e');
    }
  }

  /// Fetch user posts with polls things
  Future<List<UserPostModel>> fetchPostsPolls(String username) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.userPosts}/$username',
        options: Options(headers: await _getAuthHeaders()),
      );
      final data = response.data['results'] as List<dynamic>;
      return data.map((e) => UserPostModel.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('Error fetching posts: $e');
      rethrow;
    }
  }

  /// Fetch only poll things posts
  Future<List<UserPostModel>> fetchOnlyPollPosts(String username) async {
    final allPosts = await fetchPostsPolls(username);
    return allPosts.where((post) => post.polls.isNotEmpty).toList();
  }

  // Fetch user posts with images
  Future<List<UserPostModel>> fetchPostsImages(String username) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.userPosts}/$username',
        options: Options(headers: await _getAuthHeaders()),
      );
      final data = response.data['results'] as List<dynamic>;
      return data.map((e) => UserPostModel.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('Error fetching image posts: $e');
      rethrow;
    }
  }

  /// Fetch only posts that have images in polls
  Future<List<UserPostModel>> fetchImagePosts(String username) async {
    final allPosts = await fetchPostsImages(username);

    final filteredPosts = allPosts.where((post) => post.hasPollImages).toList();

    return filteredPosts;
  }

  Future<UserPostModel?> fetchSinglePost(int postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
      final url = '${ApiConstants.userPosts}/$postId';
      debugPrint('🔍 Fetching single post from: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle "success" wrapper unique to this API if present
        if (data is Map &&
            data.containsKey('status') &&
            data['status'] == 'success') {
          final postData = data['data'] ?? data;
          return UserPostModel.fromJson(postData);
        }

        // Check if data is wrapped or direct
        final postData = data['data'] ?? data;

        // If results list is returned (sometimes single resource endpoints return a list of 1)
        if (postData is List && postData.isNotEmpty) {
          return UserPostModel.fromJson(postData.first);
        } else if (postData is Map<String, dynamic>) {
          return UserPostModel.fromJson(postData);
        }

        debugPrint('⚠️ Unexpected JSON structure for single post: $data');
        return null;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Error fetching single post $postId: ${e.message}');
      debugPrint('❌ Response Status: ${e.response?.statusCode}');
      debugPrint('❌ Response Data: ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        // Return null instead of throwing, let UI handle it
        return null;
      }
      rethrow;
    }
  }

  /// Upload image poll
  static Future<Map<String, dynamic>?> uploadImagePoll({
    required String description,
    required String question,
    required List<File> pollOptions,
    required int maxOptions,
    String? authToken,
    Function(double)? onProgress,
    int maxFileSizeMB = _maxFileSizeMB,
  }) async {
    try {
      // Validation
      if (pollOptions.isEmpty) {
        throw Exception('At least one image is required');
      }
      if (pollOptions.length > maxOptions) {
        throw Exception('Maximum $maxOptions images allowed');
      }

      // Validate file sizes
      for (final image in pollOptions) {
        final fileSizeInBytes = await image.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        if (fileSizeInMB > maxFileSizeMB) {
          throw Exception(
            'Image too large. Maximum size allowed is ${maxFileSizeMB}MB per image',
          );
        }
      }

      // Create FormData
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('description', description),
        MapEntry('question', question),
        MapEntry('max_options', maxOptions.toString()),
      ]);

      // Add images
      for (int i = 0; i < pollOptions.length; i++) {
        final imageFile = pollOptions[i];
        final multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
          contentType: MediaType('image', 'jpeg'),
        );
        formData.files.add(MapEntry('poll_options', multipartFile));
      }

      // Headers
      final headers = <String, dynamic>{'Content-Type': 'multipart/form-data'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      // Make request
      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          if (onProgress != null && total != -1) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 413) {
        throw Exception(
          'Image too large. Maximum size allowed is ${maxFileSizeMB}MB',
        );
      } else if (response.statusCode == 400) {
        final errorMsg = response.data?['message'] ?? 'Bad request';
        throw Exception(errorMsg);
      }
      throw Exception('Failed to upload poll. Status: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DioException: ${e.message}');

      if (e.response?.statusCode == 413) {
        throw Exception(
          'Image too large. Maximum size allowed is ${maxFileSizeMB}MB',
        );
      } else if (e.response?.statusCode == 400) {
        final errorMsg = e.response?.data?['message'] ?? 'Bad request';
        throw Exception(errorMsg);
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Please check your internet connection',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Upload timeout. Please try again');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  Future<List<LikeUser>> fetchLikedUsers(int postId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.likePost}/$postId/likes',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        // Dio automatically parses JSON, no need for json.decode
        final data = response.data;
        final List<dynamic> results = data['results'] ?? [];

        return results.map((user) => LikeUser.fromJson(user)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else {
        throw Exception('Failed to load likes. Status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server timeout. Please try again.');
      } else if (e.type == DioExceptionType.badResponse) {
        throw Exception(
          'Failed to load likes. Status: ${e.response?.statusCode}',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error loading likes: $e');
    }
  }

  // Fetch post top-voters users
  static Future<TopVotersModel> getTopVoters({
    required int pollId,
    required int optionId,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      final response = await _dio.get(
        '${ApiConstants.topVoters}/$pollId/options/$optionId/top_voters',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return TopVotersModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to fetch top voters: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('DioException getTopVoters: ${e.message}');
      debugPrint('Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('Error getTopVoters: $e');
      rethrow;
    }
  }

  /// Delete user post
  Future<bool> userDeletePost(int postId) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.deletePost}/$postId/delete',
        options: Options(headers: await _getAuthHeaders()),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error deleting post: $e');
      throw Exception('Error deleting post: $e');
    }
  }

  // ==================== SOCIAL ====================

  /// Get followers list
  Future<List<Map<String, dynamic>>> getFollowersList() async {
    try {
      final response = await _dio.get(
        ApiConstants.chaseList,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // If data is directly a list
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        // If data is a map, try to extract the list
        if (data is Map<String, dynamic>) {
          // Try different possible keys
          final list = data['data'] ?? data['followers'] ?? data['results'];

          // Ensure it's actually a list before converting
          if (list is List) {
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching followers: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching followers: $e');
      return [];
    }
  }

  /// Get following list
  Future<List<Map<String, dynamic>>> getFollowingList() async {
    try {
      final response = await _dio.get(
        ApiConstants.reChaseList,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // If data is directly a list
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        // If data is a map, try to extract the list
        if (data is Map<String, dynamic>) {
          // Try different possible keys
          final list = data['data'] ?? data['following'] ?? data['results'];

          // Ensure it's actually a list before converting
          if (list is List) {
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching following: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching following: $e');
      return [];
    }
  }

  /// Get connections list
  Future<Map<String, dynamic>> getConnectionsList({
    required int userId,
    String? type,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users/$userId/connections',
        queryParameters: type != null ? {'type': type} : null,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map<String, dynamic>) {
          return {
            'count': data['count'] ?? 0,
            'next': data['next'],
            'previous': data['previous'],
            'results': data['results'] is List
                ? List<Map<String, dynamic>>.from(data['results'])
                : [],
          };
        }
      }

      return {'count': 0, 'next': null, 'previous': null, 'results': []};
    } on DioException catch (e) {
      debugPrint('Error fetching connections: $e');
      return {'count': 0, 'next': null, 'previous': null, 'results': []};
    } catch (e) {
      debugPrint('Unexpected error fetching connections: $e');
      return {'count': 0, 'next': null, 'previous': null, 'results': []};
    }
  }

  // Unfriend users
  Future<Map<String, dynamic>> unfriend(int userId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users/unfriend');

      final response = await http.post(
        url,
        headers: await _getAuthHeaders(),
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to unfriend user',
          'data': null,
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString(), 'data': null};
    }
  }

  /// Search users
  Future<List<SearchUserModel>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        ApiConstants.searchUsers,
        queryParameters: {'q': query},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data?['results'] != null) {
          final results = data['results'] as List;
          return results.map((e) => SearchUserModel.fromJson(e)).toList();
        }
        return [];
      } else if (response.statusCode == 400) {
        final errorMsg =
            response.data['message'] ?? 'Please enter at least 2 characters';
        throw Exception(errorMsg);
      }
      throw Exception('Failed to fetch users');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errorMsg =
            e.response?.data['message'] ?? 'Please enter at least 2 characters';
        throw Exception(errorMsg);
      }
      throw Exception(
        _handleDioError(e, defaultMessage: 'Failed to search users'),
      );
    }
  }

  Future<GlobalSearchModel?> globalSearch(String query) async {
    try {
      final response = await _dio.get(
        ApiConstants.globalSearch,
        queryParameters: {'q': query},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return GlobalSearchModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      return null;
    } on DioException catch (e) {
      _handleDioError(e, defaultMessage: 'Failed to perform search');
      return null;
    }
  }

  Future<HashtagPostsListModel> searchHashtagPosts(String tag) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/posts/search/hashtag',
        queryParameters: {'tag': tag},
        options: Options(headers: await _getAuthHeaders()),
      );

      return HashtagPostsListModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<EnhancedTrendingHashtagsModel> fetchEnhancedTrendingHashtags() async {
    try {
      final response = await _dio.get(
        ApiConstants.enhancedTrendingHashtags,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;

        return EnhancedTrendingHashtagsModel.fromJson(jsonData);
      }
      throw Exception(
        'Failed to load enhanced trending hashtags: ${response.statusCode}',
      );
    } on DioException catch (e) {
      debugPrint('Error fetching enhanced trending hashtags: $e');
      throw Exception('Error fetching enhanced trending hashtags: $e');
    }
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String username) async {
    try {
      final response = await _dio.post(
        ApiConstants.sendRequest,
        data: {'receiver_username': username},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        // showToast(message: 'Friend request sent!');
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Error sending friend request: $e');
      return false;
    }
  }

  /// Check friend request status
  Future<bool> checkFriendRequestStatus(String username) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/friend_requests',
        data: {'receiver_username': username},
        options: Options(
          headers: await _getAuthHeaders(),
          validateStatus: (status) => status == 200 || status == 400,
        ),
      );

      if (response.statusCode == 400) {
        final message = response.data['message'] as String?;
        return message != null &&
            (message.toLowerCase().contains('already following') ||
                message.toLowerCase().contains('already sent'));
      }
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error checking friend request status: ${e.message}');
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        return message != null &&
            (message.toLowerCase().contains('already following') ||
                message.toLowerCase().contains('already sent'));
      }
      return false;
    }
  }

  // Block users
  Future<Map<String, dynamic>> blockUser(int userId) async {
    try {
      final response = await _dio.post(
        ApiConstants.blockUser,
        data: {'user_id': userId},
        options: Options(headers: await _getAuthHeaders()),
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to block user'),
      };
    }
  }

  // Unblock users
  Future<Map<String, dynamic>> unblockUser(int userId) async {
    try {
      final response = await _dio.post(
        ApiConstants.unBlockUser,
        data: {'user_id': userId},
        options: Options(headers: await _getAuthHeaders()),
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to unblock user'),
      };
    }
  }

  // Get blocked users list
  Future<Map<String, dynamic>> getBlockedUsers() async {
    try {
      final response = await _dio.get(
        ApiConstants.blockedUsrsList,
        options: Options(headers: await _getAuthHeaders()),
      );
      return {'success': true, 'data': response.data['data'] as List<dynamic>};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(
          e,
          defaultMessage: 'Failed to get blocked users',
        ),
      };
    }
  }

  // ==================== MESSAGES & GROUP ====================

  Future<Map<String, dynamic>> createGroup({
    required String title,
    required String profileImage,
    required List<int> members,
  }) async {
    try {
      final body = {
        'title': title,
        'profile_image': 'data:image/jpeg;base64,$profileImage',
        'members': members,
      };

      debugPrint('=== CREATE GROUP REQUEST ===');
      debugPrint('title: $title');
      debugPrint('profile_image length: ${profileImage.length}');
      debugPrint('profile_image preview: ${profileImage.substring(0, 50)}...');
      debugPrint('members: $members');
      debugPrint('============================');

      final response = await _dio.post(
        ApiConstants.createGroup,
        data: body,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {'success': true, 'chat_id': data['chat_id']};
      }
      return {'success': false, 'message': 'Failed to create group'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to create group'),
      };
    }
  }

  // Note: Implemented GET Method Chat List
  Future<List<Map<String, dynamic>>> getChatList() async {
    try {
      final response = await _dio.get(
        ApiConstants.chatList,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final list = data['results'];
          if (list is List) {
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching chat list: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching chat list: $e');
      return [];
    }
  }

  Future<bool> markChatAsRead({required int chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.markAsRead}/$chatId/read',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>> renameGroup({
    required int chatId,
    required String newTitle,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.renameGroup}/$chatId/rename',
        data: {'title': newTitle},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {'success': true, 'new_title': data['new_title']};
      }
      return {'success': false, 'message': 'Failed to rename group'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to rename group'),
      };
    }
  }

  // upload group profile image
  Future<Map<String, dynamic>> uploadGroupProfile({
    required int chatId,
    required File imageFile,
  }) async {
    final accessToken = await SharedPrefService.getToken();
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final base64WithPrefix = 'data:image/jpeg;base64,$base64String';

      final response = await _dio.post(
        '${ApiConstants.uploadGroupProfile}/$chatId/update_picture',
        data: {'group_picture': base64WithPrefix},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // add member
  Future<Map<String, dynamic>> addGroupChatMembers({
    required int groupChatId,
    required List<int> members,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.addGroupMembers}/$groupChatId/add_members',
        data: {'members': members},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'],
          'added': data['added'],
        };
      }
      return {'success': false, 'message': 'Failed to add members'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to add members'),
      };
    }
  }

  // remove group member
  Future<Map<String, dynamic>> removeMember({
    required int chatId,
    required int userId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.removeMember}/$chatId/remove_member',
        data: {'user_id': userId},
        options: Options(headers: await _getAuthHeaders()),
      );
      return {'success': true, 'message': response.data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Failed to remove member'};
    }
  }

  // delete group
  Future<Map<String, dynamic>> deleteGroup({required int chatId}) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.deleteGroup}/$chatId/delete',
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.statusCode == 200) {
        return {'message': response.data['message']};
      }
      return {'message': response.data['message'] ?? 'Failed to delete group'};
    } catch (e) {
      return {'message': 'Failed to delete group'};
    }
  }

  // leave group
  Future<Map<String, dynamic>> leaveGroup({required int chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.leaveGroup}/$chatId/leave',
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.statusCode == 200) {
        return {'message': response.data['message']};
      }
      return {'message': response.data['message'] ?? 'Failed to leave group'};
    } catch (e) {
      return {'message': 'Failed to leave group'};
    }
  }

  // Make admin group member
  Future<Map<String, dynamic>> makeAdmin({
    required int chatId,
    required int userId,
  }) async {
    try {
      final response = await _dio.post(
        '/chats/group/$chatId/make_admin',
        data: {'user_id': userId},
        options: Options(headers: await _getAuthHeaders()),
      );

      debugPrint(
        'Make admin response: ${response.statusCode} ${response.data}',
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to make admin'};
    }
  }

  Future<Map<String, dynamic>> getGroupChatInfo({required int chatId}) async {
    try {
      final response = await _dio.get(
        '/chats/group/$chatId/info',
        options: Options(headers: await _getAuthHeaders()),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // get messages list of private chat
  Future<MessageListModel> getMessageList({
    required int chatId,
    String? nextPageUrl,
  }) async {
    try {
      final response = await _dio.get(
        nextPageUrl ?? '${ApiConstants.messageList}/$chatId/messages/list',
        options: Options(headers: await _getAuthHeaders()),
      );

      return MessageListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        '❌ getMessageList error: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw Exception(
        'Failed to load messages (${e.response?.statusCode}): ${e.response?.data}',
      );
    } catch (e) {
      debugPrint('❌ getMessageList unexpected error: $e');
      throw Exception('Unexpected error while loading messages: $e');
    }
  }

  Future<void> sendMessage({required int chatId, required String text}) async {
    try {
      debugPrint('📤 Sending message to server — chatId: $chatId, text: $text');

      await _dio.post(
        '${ApiConstants.sendMessage}/$chatId/messages',
        data: {'text': text},
        options: Options(headers: await _getAuthHeaders()),
      );

      // debugPrint(
      //   'sendMessage response [${response.statusCode}]: ${response.data}',
      // );
    } on DioException catch (e) {
      debugPrint(
        '❌ sendMessage DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow; // Let provider handle / log the failure
    } catch (e) {
      debugPrint('❌ sendMessage unexpected error: $e');
      rethrow;
    }
  }

  // ==================== PUBLIC PROFILES ====================

  /// Get user public profile
  static Future<PublicProfileModel> getUserPublicProfile(int userId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
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
        final data = response.data;
        // debugPrint('Public profile data: $data');
        if (data['status'] == 'success') {
          return PublicProfileModel.fromJson(data);
        }
        throw Exception('API returned error: ${data['message']}');
      }
      throw Exception('Failed to load user profile: ${response.statusCode}');
    } on DioException catch (e) {
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
        debugPrint('API Error: ${response.data['message'] ?? 'Unknown error'}');
        return null;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        debugPrint('DioException: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      return null;
    }
  }

  /// Fetch posts with images
  Future<List<PublicPost>> fetchPostsWithImages(int userId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.publicProfile}/$userId/profile',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          final postsData = jsonData['data']['posts']['results'] as List;
          final allPosts = postsData
              .map((json) => PublicPost.fromJson(json))
              .toList();
          return allPosts.where((post) => post.images.isNotEmpty).toList();
        }
        throw Exception('API Error: ${jsonData['message']}');
      }
      throw Exception('Failed to load posts: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching posts with images: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Fetch public posts with polls
  Future<List<PublicPost>> fetchPublicPostsPolls(int userId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.publicProfile}/$userId/profile',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          final postsData = jsonData['data']['posts']['results'] as List;
          final allPosts = postsData
              .map((json) => PublicPost.fromJson(json))
              .toList();
          // Filter to only return posts that have at least one poll
          return allPosts.where((post) => post.polls.isNotEmpty).toList();
        }
        throw Exception('API Error: ${jsonData['message']}');
      }
      throw Exception('Failed to load polls: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching posts with polls: $e');
      throw Exception('Network error: $e');
    }
  }

  // ==================== INTERACTIONS ====================

  /// Toggle post like
  static Future<Map<String, dynamic>> togglePostLike(int postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/posts/$postId/like');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Success',
          'data': data,
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': _errorMessageAuth};
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update like',
      };
    } catch (e) {
      debugPrint('API Error: $e');
      return {'success': false, 'message': _errorMessageNetwork};
    }
  }

  /// Get post likes
  static Future<Map<String, dynamic>> getPostLikes(int postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
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
      }
      return {'success': false, 'message': 'Failed to fetch likes'};
    } catch (e) {
      debugPrint('API Error: $e');
      return {'success': false, 'message': _errorMessageNetwork};
    }
  }

  // ==================== COMMENTS ====================

  // Note: Implemented GET Method - Get Post Comments
  static Future<Map<String, dynamic>> getPostComments(int postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();

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
      final accessToken = await SharedPrefService.getToken();

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
      final accessToken = await SharedPrefService.getToken();

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
      final accessToken = await SharedPrefService.getToken();

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

  static Future<Map<String, dynamic>> voteOnPollMultiple({
    required int postId,
    required List<Map<String, int>> votes,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

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
      final accessToken = await SharedPrefService.getToken();

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/posts/$postId/poll_results'),
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

  // ==================== INSIGHTS ====================

  Future<InsightsModel> getInsightsData() async {
    try {
      final response = await _dio.get(
        ApiConstants.insights,
        options: Options(headers: await _getAuthHeaders()),
      );
      return InsightsModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to load insights data: ${e.message}');
    }
  }

  // ==================== PRIVACY POLICY ====================

  Future<Map<String, dynamic>> updatePrivacyStatus({
    required String status,
  }) async {
    try {
      final FormData formData = FormData.fromMap({'status': status});

      final Response response = await _dio.post(
        ApiConstants.privacyPolicy,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== FEEDBACK ====================

  //   Future<Map<String, dynamic>> submitFeedback({
  //     required String email,
  //     required String subject,
  //     required String category,
  //     required String message,
  //     required int rating,
  //   }) async {
  //     try {
  //       final FormData formData = FormData.fromMap({
  //         'email': email,
  //         'subject': subject,
  //         'category': category,
  //         'message': message,
  //         'rating': rating.toString(),
  //       });

  //       final Response response = await _dio.post(
  //         ApiConstants.feedback,
  //         data: formData,
  //         options: Options(headers: await _getAuthHeaders()),
  //       );

  //       return response.data as Map<String, dynamic>;
  //     } on DioException catch (e) {
  //       throw _handleDioError(e);
  //     }
  //   }
  // }

  Future<Map<String, dynamic>> submitFeedback({
    required String email,
    required String subject,
    required String category,
    required String message,
    required int rating,
    required String reaction,
    File? screenshotFile,
    Map<String, String>? deviceInfo,
  }) async {
    try {
      final deviceData =
          deviceInfo ??
          {
            'browser': 'Flutter App',
            'os': Platform.operatingSystem,
            'screen_resolution':
                '${WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width.toInt()}'
                'x${WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.height.toInt()}',
            'user_agent': 'Polzet Flutter/${Platform.operatingSystemVersion}',
          };

      String? screenshotBase64;
      if (screenshotFile != null) {
        final bytes = await screenshotFile.readAsBytes();
        final base64Str = base64Encode(bytes);
        screenshotBase64 = 'data:image/jpeg;base64,$base64Str';
      }

      final Map<String, dynamic> body = {
        'email': email,
        'subject': subject,
        'category': category,
        'message': message,
        'rating': rating,
        'reaction': reaction,
        'device_info': deviceData,
        if (screenshotBase64 != null) 'screenshot': screenshotBase64,
      };

      final Response response = await _dio.post(
        ApiConstants.feedback,
        data: body,
        options: Options(
          headers: await _getAuthHeaders(),
          contentType: 'application/json',
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      } else if (data is String) {
        if (data.trimLeft().startsWith('<!')) {
          throw Exception('Server returned HTML — check endpoint URL.');
        }
        return jsonDecode(data) as Map<String, dynamic>;
      } else {
        throw Exception('Unexpected response format: ${data.runtimeType}');
      }
    } on DioException catch (e) {
      debugPrint('❌ Status: ${e.response?.statusCode}');
      debugPrint('❌ Error body: ${e.response?.data}');
      throw _handleDioError(e);
    }
  }
}
