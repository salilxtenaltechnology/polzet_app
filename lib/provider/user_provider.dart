// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../api/api_service.dart';
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
  List<dynamic>? interests;
  String? dob;
  String? gender;
  String? country;
  String? country_code;
  String? mobile_number;
  String? next_username_change;

  // ─── Auth ─────────────────────────────────────────────────────
  bool? has_google_auth;
  bool? has_local_password;

  // ─── Profile Media ────────────────────────────────────────────
  String? profile_picture;
  String? profile_picture_path;
  String? profile_thumbnail_url;
  String? cover_photo;
  String? cover_thumbnail_url;

  // ─── Profile Completion ───────────────────────────────────────
  int? profile_completion;
  bool? onboarding_completed;
  Map<String, bool>? profile_status;
  bool? is_user_new;

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
  int? cachedChaseCount;
  int? cachedRechaseCount;

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

  // ─── 6-Hour Poll Hide Timer Session ───────────────────────────
  /// Change this duration in the future to customize the poll hide timer (e.g., Duration(hours: 6))
  static const Duration pollHideDuration = Duration(hours: 6);

  DateTime? _pollHideUntil;
  DateTime? get pollHideUntil => _pollHideUntil;
  Timer? _pollHideCountdownTimer;

  /// Timestamp when the current user logged in / active session started
  DateTime? _sessionLoginTime;
  DateTime? get sessionLoginTime => _sessionLoginTime;

  /// Username/userId associated with the active poll timer session
  String? _timerSessionUser;

  bool get isPollHideTimerActive {
    final activeUser = (username ?? _timerSessionUser)?.trim();
    if (activeUser == null || activeUser.isEmpty) return false;
    if (_pollHideUntil == null) return false;
    return DateTime.now().isBefore(_pollHideUntil!);
  }

  Duration? get pollHideRemainingTime {
    if (!isPollHideTimerActive || _pollHideUntil == null) return null;
    final diff = _pollHideUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Restores saved poll hide timer from persistent storage (called on app startup / reopen)
  Future<void> restorePollHideTimer(String userKey) async {
    final cleanKey = userKey.trim();
    if (cleanKey.isEmpty) return;

    try {
      final savedHideUntil = await SharedPrefService.getPollHideUntil(cleanKey);
      final savedLoginTime = await SharedPrefService.getSessionLoginTime(cleanKey);

      if (savedLoginTime != null) {
        _sessionLoginTime = savedLoginTime;
      }

      if (savedHideUntil != null) {
        final now = DateTime.now();
        if (now.isBefore(savedHideUntil)) {
          _timerSessionUser = cleanKey;
          _pollHideUntil = savedHideUntil;
          _scheduleTimerExpiry(savedHideUntil, cleanKey);
          notifyListeners();
          debugPrint('⏳ [PollTimer] Restored active hide timer until $savedHideUntil for $cleanKey');
        } else {
          // Expired while app was closed -> clear
          _pollHideUntil = null;
          _pollHideCountdownTimer?.cancel();
          _pollHideCountdownTimer = null;
          await SharedPrefService.clearPollHideTimer(cleanKey);
          notifyListeners();
          debugPrint('⏰ [PollTimer] Saved timer expired while app was closed for $cleanKey');
        }
      }
    } catch (e) {
      debugPrint('Error restoring poll hide timer: $e');
    }
  }

  /// Starts the poll hide timer immediately upon poll creation (0-second delay)
  Future<void> startPollHideTimer({
    String? userKey,
    DateTime? createdAt,
  }) async {
    final currentKey = (userKey ?? username ?? userId ?? _timerSessionUser ?? '').trim();
    if (currentKey.isEmpty) return;

    final pollTime = (createdAt ?? DateTime.now()).toLocal();
    final hideUntil = pollTime.add(pollHideDuration);

    _timerSessionUser = currentKey;
    _pollHideUntil = hideUntil;
    _scheduleTimerExpiry(hideUntil, currentKey);

    // Immediately notify listeners so Dashboard (index == 0) hides with ZERO delay!
    notifyListeners();

    try {
      await SharedPrefService.savePollHideUntil(currentKey, hideUntil);
      debugPrint('🚀 [PollTimer] Started hide timer until: $hideUntil for $currentKey');
    } catch (e) {
      debugPrint('Error saving poll hide timer: $e');
    }
  }

  Future<void> onUserLoggedIn(String userKey, {bool isFreshLogin = false}) async {
    final cleanKey = userKey.trim();
    if (cleanKey.isEmpty) return;

    if (_timerSessionUser != cleanKey || isFreshLogin) {
      _pollHideCountdownTimer?.cancel();
      _pollHideCountdownTimer = null;
      _timerSessionUser = cleanKey;

      if (isFreshLogin) {
        // Fresh login: start a clean session so (index == 0) is shown
        _pollHideUntil = null;
        _sessionLoginTime = DateTime.now();
        await SharedPrefService.clearPollHideTimer(cleanKey);
        await SharedPrefService.saveSessionLoginTime(cleanKey, _sessionLoginTime!);
        notifyListeners();
      } else {
        // App launch or session recovery: check if active timer exists in SharedPreferences
        await restorePollHideTimer(cleanKey);
        if (_sessionLoginTime == null) {
          final savedLoginTime = await SharedPrefService.getSessionLoginTime(cleanKey);
          _sessionLoginTime = savedLoginTime ?? DateTime.now();
          if (savedLoginTime == null) {
            await SharedPrefService.saveSessionLoginTime(cleanKey, _sessionLoginTime!);
          }
        }
      }
    } else {
      // Same user already active in memory
      if (_sessionLoginTime == null) {
        final savedLoginTime = await SharedPrefService.getSessionLoginTime(cleanKey);
        _sessionLoginTime = savedLoginTime ?? DateTime.now();
      }
      if (_pollHideUntil == null) {
        await restorePollHideTimer(cleanKey);
      }
    }
  }

  void _scheduleTimerExpiry(DateTime expiryTime, String userKey) {
    _pollHideCountdownTimer?.cancel();
    final remaining = expiryTime.difference(DateTime.now());
    if (!remaining.isNegative && remaining.inMilliseconds > 0) {
      _pollHideCountdownTimer = Timer(remaining, () {
        _pollHideUntil = null;
        _pollHideCountdownTimer = null;
        SharedPrefService.clearPollHideTimer(userKey);
        notifyListeners();
        debugPrint('⏰ [PollTimer] Hide timer expired for $userKey -> Dashboard (index == 0) is now visible');
      });
    } else {
      _pollHideUntil = null;
      _pollHideCountdownTimer = null;
      SharedPrefService.clearPollHideTimer(userKey);
      notifyListeners();
    }
  }

  Future<void> updatePollHideTimerFromCreatedPoll({
    required DateTime pollCreatedAt,
    String? userKey,
  }) async {
    final currentKey = (userKey ?? username ?? userId ?? _timerSessionUser ?? '').trim();
    if (currentKey.isEmpty) return;

    try {
      final localCreatedAt = pollCreatedAt.toLocal();
      final hideUntil = localCreatedAt.add(pollHideDuration);
      final now = DateTime.now();

      // Only start 6-hour timer if the poll was created in this session and hideUntil is in the future
      if (now.isBefore(hideUntil)) {
        if (_sessionLoginTime != null && _pollHideUntil == null) {
          final sessionThreshold =
              _sessionLoginTime!.subtract(const Duration(minutes: 5));
          if (localCreatedAt.isBefore(sessionThreshold)) {
            // Poll was created before the current login session -> do not hide
            return;
          }
        }

        if (_pollHideUntil == null || hideUntil.isAfter(_pollHideUntil!)) {
          _timerSessionUser = currentKey;
          _pollHideUntil = hideUntil;
          await SharedPrefService.savePollHideUntil(currentKey, hideUntil);
          _scheduleTimerExpiry(hideUntil, currentKey);
          notifyListeners();
        }
      } else {
        if (_pollHideUntil != null) {
          _pollHideUntil = null;
          _pollHideCountdownTimer?.cancel();
          _pollHideCountdownTimer = null;
          await SharedPrefService.clearPollHideTimer(currentKey);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error updating poll hide timer: $e');
    }
  }

  Future<void> checkOrClearExpiredTimer() async {
    if (_pollHideUntil != null && DateTime.now().isAfter(_pollHideUntil!)) {
      _pollHideUntil = null;
      _pollHideCountdownTimer?.cancel();
      _pollHideCountdownTimer = null;
      final key = username ?? userId ?? _timerSessionUser ?? '';
      await SharedPrefService.clearPollHideTimer(key);
      notifyListeners();
    }
  }

  void endPollTimerSession() {
    debugPrint('🛑 Stopping poll timer session on logout');
    _pollHideCountdownTimer?.cancel();
    _pollHideCountdownTimer = null;
    _pollHideUntil = null;
    _sessionLoginTime = null;
    final userToClear = _timerSessionUser ?? username ?? userId;
    _timerSessionUser = null;
    if (userToClear != null && userToClear.isNotEmpty) {
      SharedPrefService.clearPollHideTimer(userToClear);
    }
    SharedPrefService.clearAllPollHideTimers();
    notifyListeners();
  }

  final List<String> _deletedPostIds = [];
  List<String> get deletedPostIds => _deletedPostIds;

  void notifyPostDeleted(String postId) {
    _deletedPostIds.add(postId);
    notifyListeners();
  }

  Future<void> prefetchUserPosts() async {
    if (username == null || username!.isEmpty) return;
    final token = await SharedPrefService.getToken();
    if (token == null || token.isEmpty) return;

    final currentUsername = username!;

    if (cachedThingsPostsMap.containsKey(currentUsername) &&
        cachedImagesPostsMap.containsKey(currentUsername)) {
      return; // Already cached
    }

    try {
      final response = await apiService.fetchUserPostsResponse(currentUsername, page: 1);
      final results = response.results;
      cachedThingsPostsMap[currentUsername] = results.where((post) {
        if (post.polls.isEmpty) return false;
        return post.polls.every(
          (poll) =>
              poll.options.every(
                (o) => o.text != null && o.text!.isNotEmpty && o.image == null,
              ),
        );
      }).toList();

      cachedImagesPostsMap[currentUsername] = results.where((post) {
        final isPolzetAi = post.user.trim().toLowerCase() == 'polzet_ai';
        return (isPolzetAi && post.images.isNotEmpty) ||
            post.images.isNotEmpty ||
            post.polls.any(
              (poll) => poll.options.any((o) => o.image != null),
            );
      }).toList();

      cachedTotalPollsCountMap[currentUsername] = response.count;
      notifyListeners();
    } catch (e) {
      debugPrint('Error prefetching posts: $e');
    }
  }

  // ─── Insights Cache ───────────────────────────────────────────
  InsightsModel? cachedInsightsData;

  Future<void> prefetchInsightsData() async {
    if (cachedInsightsData != null) return;
    try {
      final token = await SharedPrefService.getToken();
      if (token == null || token.isEmpty) return;
      cachedInsightsData = await apiService.getInsightsData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error prefetching insights: $e');
    }
  }

  UserProvider() {
    _initStorageOnStartup();
  }

  void _initStorageOnStartup() {
    SharedPrefService.getUsername().then((savedUser) {
      if (savedUser != null && savedUser.trim().isNotEmpty) {
        _timerSessionUser = savedUser.trim();
        restorePollHideTimer(savedUser.trim());
      }
    }).catchError((e) {
      debugPrint('Error restoring poll timer on startup: $e');
    });
  }

  Future<void>? _pendingUserDataFuture;
  DateTime? _lastUserDataLoadTime;

  // ─── Load User Data ───────────────────────────────────────────
  Future<void> loadUserData({bool force = false}) async {
    if (_pendingUserDataFuture != null) {
      return _pendingUserDataFuture;
    }

    _pendingUserDataFuture = _performLoadUserData(force: force);
    try {
      await _pendingUserDataFuture;
    } finally {
      _pendingUserDataFuture = null;
    }
  }

  Future<void> _performLoadUserData({bool force = false}) async {
    isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        apiService.fetchUserData(),
        apiService.getFollowersList(),
      ]);
      var data = results[0] as Map<String, dynamic>?;
      if (data != null) {
        _mapDataToFields(data);
        _isInitialLoadComplete = true;
        _lastUserDataLoadTime = DateTime.now();
      }
      isLoading = false;
      notifyListeners();
      prefetchUserPosts();
      prefetchInsightsData();
    } catch (e) {
      debugPrint('❌ UserProvider: Error loading user data: $e');
      if (!_isInitialLoadComplete) {
        _clearUserFields();
      }
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Load Silently ────────────────────────────────────────────
  Future<void> loadUserDataSilently({bool force = false}) async {
    if (_pendingUserDataFuture != null) {
      return _pendingUserDataFuture;
    }
    // Throttle silent loads to at most once every 5 seconds unless forced
    if (!force &&
        _lastUserDataLoadTime != null &&
        DateTime.now().difference(_lastUserDataLoadTime!) <
            const Duration(seconds: 5)) {
      return;
    }

    _pendingUserDataFuture = _performLoadUserDataSilently();
    try {
      await _pendingUserDataFuture;
    } finally {
      _pendingUserDataFuture = null;
    }
  }

  Future<void> _performLoadUserDataSilently() async {
    try {
      var data = await apiService.fetchUserData();
      if (data != null) {
        _mapDataToFields(data);
        _isInitialLoadComplete = true;
        _lastUserDataLoadTime = DateTime.now();
      }
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
    if (username != null && username!.isNotEmpty) {
      SharedPrefService.setString('username', username!);
      onUserLoggedIn(username!);
    }
    firstName = data['first_name'];
    lastName = data['last_name'];
    email = data['email'];
    if (email != null && email!.isNotEmpty) {
      SharedPrefService.saveUserEmail(email!);
    }
    bio = data['bio'];
    if (data['interests'] != null) {
      interests = List<dynamic>.from(data['interests']);
    } else {
      interests = null;
    }
    dob = data['dob'];
    gender = data['gender'];
    country = data['country'];
    country_code = data['country_code'];
    mobile_number = data['mobile_number'];
    next_username_change = data['next_username_change'];

    try {
      _user = UserModel.fromJson(data);
    } catch (e) {
      debugPrint('⚠️ UserProvider: Error building UserModel from json: $e');
    }

    // Auth
    final rawHasGoogleAuth =
        data['has_google_auth'] ?? data['data']?['has_google_auth'];
    if (rawHasGoogleAuth is bool) {
      has_google_auth = rawHasGoogleAuth;
    } else if (rawHasGoogleAuth is num) {
      has_google_auth = rawHasGoogleAuth == 1;
    } else if (rawHasGoogleAuth is String) {
      has_google_auth =
          rawHasGoogleAuth.toLowerCase() == 'true' || rawHasGoogleAuth == '1';
    } else {
      has_google_auth = data['has_google_auth'] as bool?;
    }

    final rawHasLocalPassword =
        data['has_local_password'] ?? data['data']?['has_local_password'];
    if (rawHasLocalPassword is bool) {
      has_local_password = rawHasLocalPassword;
    } else if (rawHasLocalPassword is num) {
      has_local_password = rawHasLocalPassword == 1;
    } else if (rawHasLocalPassword is String) {
      has_local_password =
          rawHasLocalPassword.toLowerCase() == 'true' ||
          rawHasLocalPassword == '1';
    } else {
      has_local_password = data['has_local_password'] as bool?;
    }

    // Profile Media
    profile_picture = data['profile_picture_url'];
    if (profile_picture != null && profile_picture!.isNotEmpty) {
      SharedPrefService.setString('user_profile_pic', profile_picture!);
    }
    profile_picture_path = data['profile_picture'];
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
    final rawIsUserNew = data['is_user_new'] ?? data['data']?['is_user_new'];
    if (rawIsUserNew is bool) {
      is_user_new = rawIsUserNew;
    } else if (rawIsUserNew is num) {
      is_user_new = rawIsUserNew == 1;
    } else if (rawIsUserNew is String) {
      is_user_new = rawIsUserNew.toLowerCase() == 'true' || rawIsUserNew == '1';
    } else {
      is_user_new = false;
    }

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
      profile_picture_path = data?['profile_picture'];
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

  void setIsNewUser(bool status) {
    is_user_new = status;
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
      case 'interests':          interests = value != null ? List<dynamic>.from(value) : null; break;
      case 'dob':                dob = value; break;
      case 'gender':             gender = value; break;
      case 'country':            country = value; break;
      case 'country_code':       country_code = value; break;
      case 'countryCode':        country_code = value; break;
      case 'mobile_number':      mobile_number = value; break;
      case 'next_username_change': next_username_change = value; break;
      case 'has_google_auth':    has_google_auth = value; break;
      case 'has_local_password':
        if (value is bool) {
          has_local_password = value;
        } else if (value is num) {
          has_local_password = value == 1;
        } else if (value is String) {
          has_local_password =
              value.toLowerCase() == 'true' || value == '1';
        } else {
          has_local_password = value as bool?;
        }
        break;
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
      case 'is_user_new':
        if (value is bool) {
          is_user_new = value;
        } else if (value is num) {
          is_user_new = value == 1;
        } else if (value is String) {
          is_user_new = value.toLowerCase() == 'true' || value == '1';
        } else {
          is_user_new = value as bool?;
        }
        break;
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
    endPollTimerSession();
    userId = null;
    username = null;
    firstName = null;
    lastName = null;
    email = null;
    bio = null;
    interests = null;
    dob = null;
    gender = null;
    country = null;
    country_code = null;
    _user = null;
    mobile_number = null;
    next_username_change = null;
    has_google_auth = null;
    has_local_password = null;
    profile_picture = null;
    profile_picture_path = null;
    profile_thumbnail_url = null;
    cover_photo = null;
    cover_thumbnail_url = null;
    profile_completion = null;
    onboarding_completed = null;
    profile_status = null;
    is_private = null;
    is_business_account = null;
    privacy_status = null;
    is_user_new = null;
    followers_count = null;
    following_count = null;
    image_post_count = 0;
    text_post_count = 0;
    counts = null;
    cachedChaseCount = null;
    cachedRechaseCount = null;
    chase_list = [];
    rechase_list = [];
    cachedThingsPostsMap.clear();
    cachedImagesPostsMap.clear();
    cachedTotalPollsCountMap.clear();
    cachedInsightsData = null;
    _deletedPostIds.clear();
  }

  void clearUserPostsCache({bool triggerTimer = true}) {
    final currentKey = (username ?? _timerSessionUser)?.trim();
    if (currentKey != null && currentKey.isNotEmpty) {
      cachedThingsPostsMap.remove(currentKey);
      cachedImagesPostsMap.remove(currentKey);
      cachedTotalPollsCountMap.remove(currentKey);
      if (triggerTimer) {
        startPollHideTimer(userKey: currentKey);
      } else {
        notifyListeners();
      }
    } else {
      if (triggerTimer) {
        startPollHideTimer();
      } else {
        notifyListeners();
      }
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