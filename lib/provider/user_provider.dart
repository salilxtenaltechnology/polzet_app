// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../api/services/api_service.dart';
import '../data/token/shared_preferences.dart';
import '../models/insights/insights_model.dart';
import '../models/posts/user_post_model.dart';
import '../models/user/user_model.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService = ApiService();

  // ─── Basic Info ───────────────────────────────────────────────
  String? userId;
  String? username;
  String? firstName;
  String? lastName;
  String? email;
  String? bio;
  String? dob;
  String? gender;
  String? country_code;
  String? mobile_number;
  String? next_username_change;

  // ─── Auth ─────────────────────────────────────────────────────
  bool? has_google_auth;
  bool? has_local_password;

  // ─── Profile Media ────────────────────────────────────────────
  String? profile_picture;
  String? profile_thumbnail_url;
  String? cover_photo;
  String? cover_thumbnail_url;

  // ─── Profile Completion ───────────────────────────────────────
  int? profile_completion;
  bool? onboarding_completed;
  Map<String, bool>? profile_status;

  // ─── Account Settings ─────────────────────────────────────────
  bool? is_private;
  bool? is_business_account;
  bool? privacy_status;

  // ─── Counts ───────────────────────────────────────────────────
  String? followers_count;
  String? following_count;
  int? image_post_count;
  int? text_post_count;
  Map<String, int>? counts;

  // ─── Chase / Rechase Lists ────────────────────────────────────
  List<Map<String, dynamic>> chase_list = [];
  List<Map<String, dynamic>> rechase_list = [];

  // ─── Loading State ────────────────────────────────────────────
  bool isLoading = true;
  bool _isInitialLoadComplete = false;
  bool get isInitialLoadComplete => _isInitialLoadComplete;

  // ─── Profile Posts Cache ──────────────────────────────────────
  Map<String, List<UserPostModel>> cachedThingsPostsMap = {};
  Map<String, List<UserPostModel>> cachedImagesPostsMap = {};
  Map<String, int> cachedTotalPollsCountMap = {};

  final List<String> _deletedPostIds = [];
  List<String> get deletedPostIds => _deletedPostIds;

  void notifyPostDeleted(String postId) {
    _deletedPostIds.add(postId);
    notifyListeners();
  }

  Future<void> prefetchUserPosts() async {
    if (username == null || username!.isEmpty) return;
    final currentUsername = username!;

    if (cachedThingsPostsMap.containsKey(currentUsername) &&
        cachedImagesPostsMap.containsKey(currentUsername)) {
      return; // Already cached
    }

    try {
      final things = await apiService.fetchOnlyPollPosts(currentUsername);
      cachedThingsPostsMap[currentUsername] = things.where((post) {
        if (post.polls.isEmpty) return false;
        return post.polls.every(
          (poll) =>
              poll.options != null &&
              poll.options!.every(
                (o) => o.text != null && o.text!.isNotEmpty,
              ),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error prefetching things posts: $e');
    }

    try {
      final images = await apiService.fetchPostsImages(currentUsername);
      cachedImagesPostsMap[currentUsername] = images.where((post) {
        return post.polls.any(
          (poll) => poll.options?.any((o) => o.image != null) ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error prefetching image posts: $e');
    }

    cachedTotalPollsCountMap[currentUsername] =
        (cachedThingsPostsMap[currentUsername]?.length ?? 0) +
        (cachedImagesPostsMap[currentUsername]?.length ?? 0);

    notifyListeners();
  }

  // ─── Insights Cache ───────────────────────────────────────────
  InsightsModel? cachedInsightsData;

  Future<void> prefetchInsightsData() async {
    if (cachedInsightsData != null) return;
    try {
      final token = await SharedPrefService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('ℹ️ UserProvider: Skipping insights prefetch because there is no active token.');
        return;
      }
      cachedInsightsData = await apiService.getInsightsData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error prefetching insights: $e');
    }
  }

  UserProvider();

  // ─── Load User Data ───────────────────────────────────────────
  Future<void> loadUserData() async {
    isLoading = true;
    notifyListeners();

    try {
      var data = await apiService.fetchUserData();
      await apiService.getFollowersList();
      _mapDataToFields(data);
      _isInitialLoadComplete = true;
      isLoading = false;
      notifyListeners();
      prefetchUserPosts();
      prefetchInsightsData();
    } catch (e) {
      debugPrint('❌ UserProvider: Error loading user data: $e');
      _clearUserFields();
      _isInitialLoadComplete = false;
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Load Silently ────────────────────────────────────────────
  Future<void> loadUserDataSilently() async {
    try {
      var data = await apiService.fetchUserData();
      _mapDataToFields(data);
      _isInitialLoadComplete = true;
      if (isLoading) isLoading = false;
      notifyListeners();
      prefetchUserPosts();
      prefetchInsightsData();
    } catch (e) {
      debugPrint("❌ UserProvider: Error loading user data silently: $e");
    }
  }

  // ─── Central Mapper ───────────────────────────────────────────
  void _mapDataToFields(Map<String, dynamic>? data) {
    if (data == null) return;

    // Basic Info
    userId = data['id']?.toString();
    username = data['username'];
    firstName = data['first_name'];
    lastName = data['last_name'];
    email = data['email'];
    if (email != null && email!.isNotEmpty) {
    SharedPrefService.saveUserEmail(email!);
  }
    bio = data['bio'];
    dob = data['dob'];
    gender = data['gender'];
    country_code = data['country_code'];
    mobile_number = data['mobile_number'];
    next_username_change = data['next_username_change'];

    // Auth
    has_google_auth = data['has_google_auth'];
    has_local_password = data['has_local_password'];

    // Profile Media
    profile_picture = data['profile_picture_url'];
    profile_thumbnail_url = data['profile_thumbnail_url'];
    cover_photo = data['cover_photo_url'];
    cover_thumbnail_url = data['cover_thumbnail_url'];

    // Profile Completion
    final rawCompletion = data['profile_completion'];
    if (rawCompletion is num) {
      profile_completion = rawCompletion.toInt();
    } else if (rawCompletion is String) {
      profile_completion = int.tryParse(rawCompletion) ?? double.tryParse(rawCompletion)?.toInt();
    } else {
      profile_completion = null;
    }
    onboarding_completed = data['onboarding_completed'];
    if (data['profile_status'] != null) {
      profile_status = Map<String, bool>.from(data['profile_status']);
    }

    // Account Settings
    is_private = data['is_private'];
    is_business_account = data['is_business_account'];
    privacy_status = data['privacy_status'];

    // Counts
    followers_count = data['followers_count'];
    following_count = data['following_count'];
    image_post_count = data['image_post_count'];
    text_post_count = data['text_post_count'];
    if (data['counts'] != null) {
      counts = Map<String, int>.from(data['counts']);
    }

    // Chase / Rechase Lists
    if (data['chase_list'] != null) {
      chase_list = List<Map<String, dynamic>>.from(data['chase_list']);
    }
    if (data['rechase_list'] != null) {
      rechase_list = List<Map<String, dynamic>>.from(data['rechase_list']);
    }
  }

  // ─── Load Only Images ─────────────────────────────────────────
  Future<void> loadUserImages() async {
    try {
      var data = await apiService.fetchUserData();
      profile_picture = data?['profile_picture_url'];
      profile_thumbnail_url = data?['profile_thumbnail_url'];
      cover_photo = data?['cover_photo_url'];
      cover_thumbnail_url = data?['cover_thumbnail_url'];
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading user images: $e");
    }
  }

  // ─── Validity Checks ──────────────────────────────────────────
  bool isUserDataValid() {
    return _isInitialLoadComplete &&
        userId != null &&
        username != null &&
        username!.isNotEmpty;
  }

  Future<bool> waitForUserData({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (isUserDataValid()) {
      debugPrint('✅ UserProvider: Data already valid');
      return true;
    }

    debugPrint('⏳ UserProvider: Waiting for user data...');
    final startTime = DateTime.now();
    while (!isUserDataValid()) {
      if (DateTime.now().difference(startTime) > timeout) {
        debugPrint('❌ UserProvider: Timeout waiting for user data');
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('✅ UserProvider: User data ready');
    return true;
  }

  // ─── Setters ──────────────────────────────────────────────────
  void setPrivacyStatus(bool status) {
    privacy_status = status;
    notifyListeners();
  }

  void setIsPrivate(bool status) {
    is_private = status;
    notifyListeners();
  }

  // ─── Update Single Field ──────────────────────────────────────
  void updateUserField(String field, dynamic value) {
    switch (field) {
      case 'userId':             userId = value?.toString(); break;
      case 'username':           username = value; break;
      case 'firstName':          firstName = value; break;
      case 'lastName':           lastName = value; break;
      case 'email':              email = value; break;
      case 'bio':                bio = value; break;
      case 'dob':                dob = value; break;
      case 'gender':             gender = value; break;
      case 'country_code':       country_code = value; break;
      case 'mobile_number':      mobile_number = value; break;
      case 'next_username_change': next_username_change = value; break;
      case 'has_google_auth':    has_google_auth = value; break;
      case 'has_local_password': has_local_password = value; break;
      case 'profile_picture':    profile_picture = value; break;
      case 'profile_thumbnail_url': profile_thumbnail_url = value; break;
      case 'cover_photo':        cover_photo = value; break;
      case 'cover_thumbnail_url': cover_thumbnail_url = value; break;
      case 'profile_completion':
        if (value is num) {
          profile_completion = value.toInt();
        } else if (value is String) {
          profile_completion = int.tryParse(value) ?? double.tryParse(value)?.toInt();
        } else {
          profile_completion = null;
        }
        break;
      case 'onboarding_completed': onboarding_completed = value; break;
      case 'profile_status':     profile_status = value; break;
      case 'is_private':         is_private = value; break;
      case 'is_business_account': is_business_account = value; break;
      case 'privacy_status':     privacy_status = value; break;
      case 'followers_count':    followers_count = value; break;
      case 'following_count':    following_count = value; break;
      case 'image_post_count':   image_post_count = value; break;
      case 'text_post_count':    text_post_count = value; break;
      case 'counts':             counts = value; break;
      case 'chase_list':         chase_list = value; break;
      case 'rechase_list':       rechase_list = value; break;
    }
    notifyListeners();
  }

  void updateUserFields(Map<String, dynamic> updates) {
    updates.forEach((key, value) => updateUserField(key, value));
  }

  // ─── Clear Data ───────────────────────────────────────────────
  void clearUserData() {
    debugPrint('🗑️ UserProvider: Clearing all user data');
    _clearUserFields();
    _isInitialLoadComplete = false;
    isLoading = false;
    notifyListeners();
  }

  void _clearUserFields() {
    userId = null;
    username = null;
    firstName = null;
    lastName = null;
    email = null;
    bio = null;
    dob = null;
    gender = null;
    country_code = null;
    mobile_number = null;
    next_username_change = null;
    has_google_auth = null;
    has_local_password = null;
    profile_picture = null;
    profile_thumbnail_url = null;
    cover_photo = null;
    cover_thumbnail_url = null;
    profile_completion = null;
    onboarding_completed = null;
    profile_status = null;
    is_private = null;
    is_business_account = null;
    privacy_status = null;
    followers_count = null;
    following_count = null;
    image_post_count = 0;
    text_post_count = 0;
    counts = null;
    chase_list = [];
    rechase_list = [];
    cachedThingsPostsMap.clear();
    cachedImagesPostsMap.clear();
    cachedTotalPollsCountMap.clear();
    cachedInsightsData = null;
    _deletedPostIds.clear();
  }

  void clearUserPostsCache() {
    if (username != null) {
      cachedThingsPostsMap.remove(username);
      cachedImagesPostsMap.remove(username);
      cachedTotalPollsCountMap.remove(username);
      notifyListeners();
    }
  }

  // ─── Image Decoders ───────────────────────────────────────────
  UserModel? _user;
  UserModel? get user => _user;

  Uint8List? getProfileImage(profilePicture) {
    if (profilePicture == null || profilePicture.isEmpty) return null;
    try {
      String base64Data = profilePicture.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  Uint8List? getCoverImage(coverPhoto) {
    if (coverPhoto == null || coverPhoto.isEmpty) return null;
    try {
      String base64Data = coverPhoto.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  // ─── Friend Request ───────────────────────────────────────────
  Future<bool> sendFriendRequest(String username) async {
    try {
      bool result = await ApiService().sendFriendRequest(username);
      return result;
    } catch (e) {
      notifyListeners();
      return false;
    }
  }
}