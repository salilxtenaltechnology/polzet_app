import 'package:flutter/material.dart';

import '../api/services/api_service.dart';
import '../models/public/public_profile_model.dart';

class PublicProfileProvider extends ChangeNotifier {
  PublicProfileModel? _userProfile;
  bool _isLoading = false;
  String? _error;

  PublicProfileModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPublicUserProfile(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await ApiService.getUserPublicProfile(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
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

  void clearProfile() {
    _userProfile = null;
    _error = null;
    notifyListeners();
  }
}
