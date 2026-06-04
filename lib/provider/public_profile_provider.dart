import 'package:flutter/material.dart';

import '../api/services/api_service.dart';
import '../models/public/public_profile_model.dart';
import '../models/global search/global_search_model.dart';

enum ProfileErrorType { noInternet, serverError, unknown, none }

class PublicProfileProvider extends ChangeNotifier {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  PublicProfileModel? _profileResponse;
  ProfileData? _userProfile;
  bool _isLoading = false;
  String? _error;

  ProfileErrorType _errorType = ProfileErrorType.none;

  ProfileErrorType get errorType => _errorType;

  // Getters
  PublicProfileModel? get profileResponse => _profileResponse;
  ProfileData? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches public user profile by userId
  Future<void> fetchPublicUserProfile(
    dynamic userId, {
    bool isRefresh = false,
  }) async {
    if (_userProfile != null && _userProfile!.id != userId) {
      _userProfile = null;
      _profileResponse = null;
    }
    if (!isRefresh) {
      _isLoading = true;
      _error = null;
      _errorType = ProfileErrorType.none;
      notifyListeners();
    }

    try {
      final response = await ApiService.getUserPublicProfile(userId);

      if (response.status == 'success') {
        _profileResponse = response;
        _userProfile = response.data;
        _error = null;
        _errorType = ProfileErrorType.none;
      } else {
        _error = response.message;
        _errorType = ProfileErrorType.unknown;
        _profileResponse = null;
        _userProfile = null;
      }
    } catch (e) {
      debugPrint('Error fetching public profile: $e');
      final msg = e.toString();

      if (msg.contains('Network error') ||
          msg.contains('SocketException') ||
          msg.contains('connection') ||
          msg.contains('NetworkException')) {
        _errorType = ProfileErrorType.noInternet;
        _error = 'No internet connection';
      } else if (msg.contains('500') ||
          msg.contains('503') ||
          msg.contains('502') ||
          msg.contains('server')) {
        _errorType = ProfileErrorType.serverError;
        _error = 'Server error';
      } else {
        _errorType = ProfileErrorType.unknown;
        _error = _parseErrorMessage(msg);
      }

      _profileResponse = null;
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches public user profile by username
  Future<void> fetchPublicUserProfileByUsername(
    String username, {
    bool isRefresh = false,
  }) async {
    if (_userProfile != null && _userProfile!.username != username) {
      _userProfile = null;
      _profileResponse = null;
    }
    if (!isRefresh) {
      _isLoading = true;
      _error = null;
      _errorType = ProfileErrorType.none;
      notifyListeners();
    }

    try {
      final searchResult = await ApiService().globalSearch(username);
      if (searchResult != null &&
          searchResult.success &&
          searchResult.data.accounts.isNotEmpty) {
        SearchAccount? targetAccount;
        for (final acc in searchResult.data.accounts) {
          if (acc.username.toLowerCase() == username.toLowerCase()) {
            targetAccount = acc;
            break;
          }
        }
        final account = targetAccount ?? searchResult.data.accounts.first;
        
        final response = await ApiService.getUserPublicProfile(account.uuid);

        if (response.status == 'success') {
          _profileResponse = response;
          _userProfile = response.data;
          _error = null;
          _errorType = ProfileErrorType.none;
        } else {
          _error = response.message;
          _errorType = ProfileErrorType.unknown;
          _profileResponse = null;
          _userProfile = null;
        }
      } else {
        _error = 'User not found';
        _errorType = ProfileErrorType.unknown;
        _profileResponse = null;
        _userProfile = null;
      }
    } catch (e) {
      debugPrint('Error fetching public profile by username: $e');
      final msg = e.toString();

      if (msg.contains('Network error') ||
          msg.contains('SocketException') ||
          msg.contains('connection') ||
          msg.contains('NetworkException')) {
        _errorType = ProfileErrorType.noInternet;
        _error = 'No internet connection';
      } else if (msg.contains('500') ||
          msg.contains('503') ||
          msg.contains('502') ||
          msg.contains('server')) {
        _errorType = ProfileErrorType.serverError;
        _error = 'Server error';
      } else {
        _errorType = ProfileErrorType.unknown;
        _error = _parseErrorMessage(msg);
      }

      _profileResponse = null;
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

  Future<bool> sendFriendRequest(String username) async {
    try {
      final apiService = ApiService();
      bool result = await apiService.sendFriendRequest(username);

      if (result && _userProfile != null) {
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> unfriend(dynamic userId) async {
    try {
      final apiService = ApiService();
      final response = await apiService.unfriend(userId);

      if (response['status'] == 'success' && _userProfile != null) {
        notifyListeners();
      }

      return response;
    } catch (e) {
      debugPrint('Error unfriending user: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  void updateFollowStatus(String newStatus) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(followStatus: newStatus);
      notifyListeners();
    }
  }

  void updateFriendStatus(bool isFriend) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(isFriend: isFriend);
      notifyListeners();
    }
  }

  void updateFollowerCount(int delta) {
    if (_userProfile != null) {
      final newCount = _userProfile!.followersCount + delta;
      _userProfile = _userProfile!.copyWith(
        followersCount: newCount >= 0 ? newCount : 0,
      );
      notifyListeners();
    }
  }

  void clearProfile() {
    _profileResponse = null;
    _userProfile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
