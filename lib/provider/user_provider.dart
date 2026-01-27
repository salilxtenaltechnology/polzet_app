// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../api/services/api_service.dart';
import '../models/user/user_model.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService = ApiService();
  int? userId; // Add this field
  String? username;
  String? firstName;
  String? lastName;
  String? email;
  String? bio;
  String? dob;
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

  UserProvider() {
    loadUserData();
  }

  Future<void> loadUserData() async {
    isLoading = true;
    notifyListeners();

    try {
      var data = await apiService.fetchUserData();
      await apiService.getFollowersList();
      userId = data?['id']; // Add this line
      username = data?['username'];
      firstName = data?['first_name'];
      lastName = data?['last_name'];
      email = data?['email'];
      bio = data?['bio'];
      dob = data?['dob'];
      gender = data?['gender'];
      country_code = data?['country_code'];
      mobile_number = data?['mobile_number'];
      profile_picture = data?['profile_picture_url'];
      cover_photo = data?['cover_photo_url'];
      followers_count = data?['followers_count'];
      following_count = data?['following_count'];
      image_post_count = data?['image_post_count'];
      text_post_count = data?['text_post_count'];
      isLoading = false;
      notifyListeners();
    } catch (e) {
      _clearUserFields();
      isLoading = false;
      notifyListeners();
    }
  }

  // Method to load user data silently without showing loading state
  Future<void> loadUserDataSilently() async {
    // Don't change isLoading state to avoid showing loading indicators
    try {
      var data = await apiService.fetchUserData();

      // Update all fields with fresh data
      userId = data?['id']; // Add this line
      username = data?['username'];
      firstName = data?['first_name'];
      lastName = data?['last_name'];
      email = data?['email'];
      bio = data?['bio'];
      dob = data?['dob'];
      gender = data?['gender'];
      country_code = data?['country_code'];
      mobile_number = data?['mobile_number'];
      followers_count = data?['followers_count'];
      following_count = data?['following_count'];
      image_post_count = data?['image_post_count'];
      text_post_count = data?['text_post_count'];

      // Only notify listeners to update UI with fresh data
      notifyListeners();
    } catch (e) {
      // On error, don't clear fields or change loading state
      // Just log the error and keep current data
      debugPrint("Error loading user data silently: $e");
    }
  }

  Future<void> loadUserImages() async {
    // Don't change isLoading state to avoid showing loading indicators
    try {
      var data = await apiService.fetchUserData();

      // Update all fields with fresh data

      profile_picture = data?['profile_picture_url'];
      cover_photo = data?['cover_photo_url'];

      notifyListeners();
    } catch (e) {
      // On error, don't clear fields or change loading state
      // Just log the error and keep current data
      debugPrint("Error loading user data silently: $e");
    }
  }

  // Helper method to clear user fields
  void _clearUserFields() {
    userId = null; // Add this line
    username = null;
    firstName = null;
    lastName = null;
    email = null;
    bio = null;
    dob = null;
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
      case 'userId': // Add this case
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
