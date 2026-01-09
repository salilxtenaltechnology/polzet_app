import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefService {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';
  static const String _firstName = 'first_name';
  static const String _lastName = 'last_name';
  static const String _username = 'username';
  static const String _bio = 'bio';

  // Save tokens and userdetails
  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, token);
  }

  Future<void> saveRefreshToken(String token) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_refreshKey, token);
  }

  // Save User firstname and lastname
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

  // Get tokens
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> getRefreshToken() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(_refreshKey);
  }

  // Get User firstname, lastname, username, bio
  static Future<String?> getFirstName() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(_firstName);
  }

  static Future<String?> getLastName() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(_lastName);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_username);
  }

  static Future<String?> getUserBio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bio);
  }

  // Update user details (same as save)
  Future<void> updateUserFirstname(String firstname) async {
    await saveUserFirstName(firstname);
  }

  Future<void> updateUserLastname(String lastname) async {
    await saveUserLastName(lastname);
  }

  Future<void> updateUsername(String username) async {
    await saveUsername(username);
  }

  Future<void> updateUserBio(String firstname) async {
    await saveUserBio(firstname);
  }

  // Delete token and user details
  static Future<void> deleteAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
  }

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

  // Generic string methods for flexible caching
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
}
