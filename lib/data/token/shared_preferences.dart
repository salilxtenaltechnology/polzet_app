import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefService {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';
  static const String _fcmToken = 'fcm_token';
  static const String _firstLaunchKey = 'first_launch';
  static const String _languageCode = 'languageCode';
  static const String _userId = 'user_id';
  static const String _firstName = 'first_name';
  static const String _email = 'email';
  static const String _onBoarding = 'onboarding_seen';

  static const String _lastName = 'last_name';
  static const String _username = 'username';
  static const String _bio = 'bio';

  // Mirrors TokenStorage class — fast access without async for already-loaded tokens
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  // Set onBoarding key
  static Future<bool> isOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onBoarding) ?? false;
  }

  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onBoarding, true);
  }

  /// Set access token in both memory cache and SharedPreferences
  static Future<void> setToken(String token) async {
    _cachedAccessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, token);
  }

  /// Set refresh token in both memory cache and SharedPreferences
  static Future<void> setRefreshToken(String token) async {
    _cachedRefreshToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshKey, token);
  }

  /// Get access token — returns memory cache instantly, falls back to SharedPreferences
  static Future<String?> getToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedAccessToken = prefs.getString(_accessKey);
    return _cachedAccessToken;
  }

  /// Get refresh token — returns memory cache instantly, falls back to SharedPreferences
  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedRefreshToken = prefs.getString(_refreshKey);
    return _cachedRefreshToken;
  }

  //*----- Clear Tokens (Memory and SharedPreferences) -----*/
  static Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_languageCode);
  }

  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmToken, token);
  }

  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmToken);
  }

  static Future<void> removeFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fcmToken);
  }

  //*-----Language -----*/
  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCode, code);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageCode);
  }

  static Future<void> clearLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageCode);
  }

  //*-----User Details -----*//

  Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userId, id);
  }

  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_email, email);
  }

  Future<void> saveUserFirstName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_firstName, name);
  }

  Future<void> saveUserLastName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastName, name);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_username, username);
  }

  Future<void> saveUserBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bio, bio);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userId);
  }

  static Future<String?> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firstName);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_email);
  }

  static Future<String?> getLastName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastName);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_username);
  }

  static Future<String?> getUserBio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bio);
  }

  //*----- Update User Details -----*//
  Future<void> updateUserFirstname(String firstname) async =>
      saveUserFirstName(firstname);

  Future<void> updateUserLastname(String lastname) async =>
      saveUserLastName(lastname);

  Future<void> updateUsername(String username) async => saveUsername(username);

  Future<void> updateUserBio(String bio) async => saveUserBio(bio);

  //*----- Clear User Details -----*//
  static Future<void> clearFirstname() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstName);
  }

  static Future<void> clearLastname() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastName);
  }

  static Future<void> clearUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_username);
  }

  static Future<void> clearUserBio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bio);
  }

  //*----- Full Logout (clear everything) -----*//
  static Future<void> clearAll() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  //*----- Generic Helpers -----*//
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> removeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clearOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

    if (isFirstLaunch) {
      _cachedAccessToken = null;
      _cachedRefreshToken = null;
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
      await prefs.setBool(_firstLaunchKey, false);
    }
  }

  //*----- AI Daily Limit Persistence -----*//
  static const String _aiRemainingGenerationsKey = 'ai_remaining_generations';
  static const String _aiDailyLimitKey = 'ai_daily_limit';
  static const String _aiLastResetDateKey = 'ai_last_reset_date';

  static String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, int>> getAiLimitData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayDateString();
    final lastResetDate = prefs.getString(_aiLastResetDateKey);
    final savedLimit = prefs.getInt(_aiDailyLimitKey) ?? 5;

    if (lastResetDate != today) {
      // New day -> Reset to daily limit
      await prefs.setString(_aiLastResetDateKey, today);
      await prefs.setInt(_aiRemainingGenerationsKey, savedLimit);
      return {'remaining': savedLimit, 'daily_limit': savedLimit};
    }

    final remaining = prefs.getInt(_aiRemainingGenerationsKey) ?? savedLimit;
    return {'remaining': remaining, 'daily_limit': savedLimit};
  }

  static Future<void> saveAiLimitData({
    required int remaining,
    int? dailyLimit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayDateString();
    await prefs.setString(_aiLastResetDateKey, today);
    await prefs.setInt(_aiRemainingGenerationsKey, remaining);
    if (dailyLimit != null) {
      await prefs.setInt(_aiDailyLimitKey, dailyLimit);
    }
  }
}
