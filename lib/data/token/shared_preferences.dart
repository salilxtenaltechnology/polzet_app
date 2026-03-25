import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefService {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';
  static const String _fcmToken = 'fcm_token';
  static const String _firstLaunchKey = 'first_launch';
  static const String _languageCode = 'languageCode';
  static const String _firstName = 'first_name';
  static const String _lastName = 'last_name';
  static const String _username = 'username';
  static const String _bio = 'bio';

  // ─── TokenStorage (in-memory cache) ────────────────────────────────────────
  // Mirrors TokenStorage class — fast access without async for already-loaded tokens
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

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

  /// Clear both tokens from memory and SharedPreferences (use on logout)
  static Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_languageCode);
  }

  // ─── FCM Token ──────────────────────────────────────────────────────────────
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

  // ─── Language ────────────────────────────────────────────────────────────────
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

  // ─── User Details ───────────────────────────────────────────────────────────
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

  static Future<String?> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firstName);
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

  // ─── Update User Details ────────────────────────────────────────────────────
  Future<void> updateUserFirstname(String firstname) async =>
      saveUserFirstName(firstname);

  Future<void> updateUserLastname(String lastname) async =>
      saveUserLastName(lastname);

  Future<void> updateUsername(String username) async => saveUsername(username);

  Future<void> updateUserBio(String bio) async => saveUserBio(bio);

  // ─── Clear User Details ─────────────────────────────────────────────────────
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

  // ─── Full Logout (clear everything) ─────────────────────────────────────────
  static Future<void> clearAll() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── Generic Helpers ────────────────────────────────────────────────────────
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
      // 👇 clear tokens on fresh install
      _cachedAccessToken = null;
      _cachedRefreshToken = null;
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
      await prefs.setBool(_firstLaunchKey, false); // mark as launched
    }
  }
}

/* Valid from: Wed Dec 24 21:26:21 IST 2025 until: Sun May 11 21:26:21 IST 2053
Certificate fingerprints:
         SHA1: 12:9B:DC:4E:F9:D5:93:C7:24:5F:EB:33:56:D6:F0:50:3D:8A:1B:76
         SHA256: 74:4F:D3:83:31:A9:72:EB:7A:57:55:52:52:73:DC:D0:87:8A:0A:0B:0E:C7:5D:F4:E0:D5:2F:C9:0A:7E:0D:89
Signature algorithm name: SHA384withRSA
Subject Public Key Algorithm: 2048-bit RSA key
Version: 3 */
