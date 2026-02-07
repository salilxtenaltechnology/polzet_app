import 'package:flutter/material.dart';

import '../api/services/api_service.dart';
import '../models/public/public_profile_model.dart';

class PublicProfileProvider extends ChangeNotifier {
  PublicProfileModel? _profileResponse;
  ProfileData? _userProfile;
  bool _isLoading = false;
  String? _error;

  // Getters
  PublicProfileModel? get profileResponse => _profileResponse;
  ProfileData? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches public user profile by userId
  Future<void> fetchPublicUserProfile(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call the static API service method
      final response = await ApiService.getUserPublicProfile(userId);

      if (response.status == 'success') {
        _profileResponse = response;
        _userProfile = response.data;
        _error = null;
      } else {
        _error = response.message;
        _profileResponse = null;
        _userProfile = null;
      }
    } catch (e) {
      debugPrint('Error fetching public profile: $e');
      _error = _parseErrorMessage(e.toString());
      _profileResponse = null;
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Parse error message to show user-friendly text
  String _parseErrorMessage(String error) {
    if (error.contains('Network error')) {
      return 'Network error. Please check your connection.';
    } else if (error.contains('API returned error')) {
      return error.replaceAll('Exception: API returned error: ', '');
    } else if (error.contains('Failed to load user profile')) {
      return 'Failed to load profile. Please try again.';
    }
    return 'An unexpected error occurred.';
  }

  /// Sends a friend request to a user
  /// Note: This uses instance method from ApiService
  Future<bool> sendFriendRequest(String username) async {
    try {
      // Create instance of ApiService for instance methods
      final apiService = ApiService();
      bool result = await apiService.sendFriendRequest(username);

      if (result && _userProfile != null) {
        // Optionally update local state after successful friend request
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      notifyListeners();
      return false;
    }
  }

  /// Unfriend a user
  /// Note: This uses instance method from ApiService
  Future<Map<String, dynamic>> unfriend(int userId) async {
    try {
      // Create instance of ApiService for instance methods
      final apiService = ApiService();
      final response = await apiService.unfriend(userId);

      if (response['status'] == 'success' && _userProfile != null) {
        // Optionally update local state after successful unfriend
        notifyListeners();
      }

      return response;
    } catch (e) {
      debugPrint('Error unfriending user: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Updates the follow status locally (optimistic update)
  /// This allows immediate UI feedback while API request is processing
  void updateFollowStatus(String newStatus) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(followStatus: newStatus);
      notifyListeners();
    }
  }

  /// Updates isFriend status locally
  void updateFriendStatus(bool isFriend) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(isFriend: isFriend);
      notifyListeners();
    }
  }

  /// Updates follower count (e.g., after follow/unfollow)
  void updateFollowerCount(int delta) {
    if (_userProfile != null) {
      final newCount = _userProfile!.followersCount + delta;
      _userProfile = _userProfile!.copyWith(
        followersCount: newCount >= 0 ? newCount : 0,
      );
      notifyListeners();
    }
  }

  /// Clears the current profile data
  void clearProfile() {
    _profileResponse = null;
    _userProfile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Resets only the error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
