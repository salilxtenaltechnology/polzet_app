// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../api/services/api_service.dart';
import '../models/user/user_model.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService = ApiService();
  int? userId;
  String? username;
  String? firstName;
  String? lastName;
  String? email;
  String? bio;
  String? dob;
  bool? has_google_auth;
  bool? has_local_password;
  int? profile_completion;
  bool? onboarding_completed;
  String? gender;
  String? country_code;
  String? mobile_number;
  String? profile_picture;
  String? cover_photo;
  String? followers_count;
  String? following_count;
  int? image_post_count;
  int? text_post_count;
  bool isLoading = true;

  // ✅ NEW: Track if initial load is complete
  bool _isInitialLoadComplete = false;
  bool get isInitialLoadComplete => _isInitialLoadComplete;

  UserProvider() {
    // Don't call loadUserData here - we'll call it explicitly from main.dart
    // This prevents automatic loading before we're ready
  }

  /// ✅ ENHANCED: Load user data from API with completion tracking
  Future<void> loadUserData() async {
    isLoading = true;
    notifyListeners();

    try {
      var data = await apiService.fetchUserData();
      await apiService.getFollowersList();

      userId = data?['id'];
      username = data?['username'];
      firstName = data?['first_name'];
      lastName = data?['last_name'];
      email = data?['email'];
      bio = data?['bio'];
      dob = data?['dob'];
      has_google_auth = data?['has_google_auth'];
      has_local_password = data?['has_local_password'];
      profile_completion = data?['profile_completion'];
      onboarding_completed = data?['onboarding_completed'];
      gender = data?['gender'];
      country_code = data?['country_code'];
      mobile_number = data?['mobile_number'];
      profile_picture = data?['profile_picture_url'];
      cover_photo = data?['cover_photo_url'];
      followers_count = data?['followers_count'];
      following_count = data?['following_count'];
      image_post_count = data?['image_post_count'];
      text_post_count = data?['text_post_count'];
      _isInitialLoadComplete = true;
      isLoading = false;

      notifyListeners();
    } catch (e) {
      debugPrint('❌ UserProvider: Error loading user data: $e');
      _clearUserFields();
      _isInitialLoadComplete = false;
      isLoading = false;
      notifyListeners();
      rethrow; // ✅ Rethrow so main.dart knows there was an error
    }
  }

  /// ✅ NEW: Check if user data is valid and ready
  bool isUserDataValid() {
    final isValid =
        _isInitialLoadComplete &&
        userId != null &&
        username != null &&
        username!.isNotEmpty;

    if (!isValid) {
      debugPrint('⚠️ UserProvider: Data not valid');
      debugPrint('   isInitialLoadComplete: $_isInitialLoadComplete');
      debugPrint('   userId: $userId');
      debugPrint('   username: $username');
    }

    return isValid;
  }

  /// ✅ NEW: Wait for user data to be ready (with timeout)
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

  // Method to load user data silently without showing loading state
  Future<void> loadUserDataSilently() async {
    // Don't change isLoading state to avoid showing loading indicators
    try {
      // debugPrint('🔄 UserProvider: Silently refreshing user data...');

      var data = await apiService.fetchUserData();

      // Update all fields with fresh data
      userId = data?['id'];
      username = data?['username'];
      firstName = data?['first_name'];
      lastName = data?['last_name'];
      email = data?['email'];
      bio = data?['bio'];
      dob = data?['dob'];
      profile_completion = data?['profile_completion'];    
      onboarding_completed = data?['onboarding_completed'];
      gender = data?['gender'];
      country_code = data?['country_code'];
      mobile_number = data?['mobile_number'];
      followers_count = data?['followers_count'];
      following_count = data?['following_count'];
      image_post_count = data?['image_post_count'];
      text_post_count = data?['text_post_count'];

      _isInitialLoadComplete = true;

      // ✅ Ensure isLoading is false so UI switches to using provider data
      if (isLoading) {
        isLoading = false;
      }

      //debugPrint('✅ UserProvider: Data refreshed silently');

      // Only notify listeners to update UI with fresh data
      notifyListeners();
    } catch (e) {
      // On error, don't clear fields or change loading state
      // Just log the error and keep current data
      debugPrint("❌ UserProvider: Error loading user data silently: $e");
    }
  }

  Future<void> loadUserImages() async {
    try {
      var data = await apiService.fetchUserData();

      // Update image fields with fresh data
      profile_picture = data?['profile_picture_url'];
      cover_photo = data?['cover_photo_url'];

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading user images: $e");
    }
  }

  /// ✅ NEW: Clear all user data (for logout)
  void clearUserData() {
    debugPrint('🗑️ UserProvider: Clearing all user data');
    _clearUserFields();
    _isInitialLoadComplete = false;
    isLoading = false;
    notifyListeners();
  }

  // Helper method to clear user fields
  void _clearUserFields() {
    userId = null;
    username = null;
    firstName = null;
    lastName = null;
    email = null;
    bio = null;
    dob = null;
    has_google_auth = null;
    has_local_password = null;
    profile_completion = null;
    onboarding_completed = null;
    gender = null;
    country_code = null;
    mobile_number = null;
    profile_picture = null;
    cover_photo = null;
    followers_count = null;
    following_count = null;
    image_post_count = 0;
    text_post_count = 0;
  }

  // Method to update specific fields and notify listeners immediately
  void updateUserField(String field, dynamic value) {
    switch (field) {
      case 'userId':
        userId = value;
        break;
      case 'username':
        username = value;
        break;
      case 'firstName':
        firstName = value;
        break;
      case 'lastName':
        lastName = value;
        break;
      case 'email':
        email = value;
        break;
      case 'bio':
        bio = value;
        break;
      case 'profile_picture':
        profile_picture = value;
        break;
      case 'cover_photo':
        cover_photo = value;
        break;
      case 'has_google_auth':
        has_google_auth = value;
        break;
      case 'has_local_password':
        has_local_password = value;
        break;
      case 'profile_completion':
        profile_completion = value;
        break;
      case 'onboarding_completed':
        onboarding_completed = value;
        break;
      case 'followers_count':
        followers_count = value;
        break;
      case 'following_count':
        following_count = value;
        break;
      case 'image_post_count':
        image_post_count = value;
        break;
      case 'text_post_count':
        text_post_count = value;
        break;
    }
    notifyListeners();
  }

  // Method to update multiple fields at once
  void updateUserFields(Map<String, dynamic> updates) {
    updates.forEach((key, value) {
      updateUserField(key, value);
    });
  }

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
