import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// ─── Config ───────────────────────────────────────────────────────────────────
const String domainUrl = 'testbackend.polzet.in';
const String backendBaseUrl = 'https://$domainUrl';

// ─── AuthService ──────────────────────────────────────────────────────────────
class AuthService {
  Future<Map<String, dynamic>?> socialLogin(Map<String, dynamic> reqData) async {
    final response = await http.post(
      Uri.parse('$backendBaseUrl/auth/social-login'), // adjust endpoint if needed
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reqData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    debugPrint('❌ HTTP ${response.statusCode}: ${response.body}');
    return null;
  }
}

// ─── Token Storage ────────────────────────────────────────────────────────────
// Swap with flutter_secure_storage in production
class TokenStorage {
  static String? _token;
  static String? _refreshToken;
  static void setToken(String t) => _token = t;
  static void setRefreshToken(String t) => _refreshToken = t;
  static String? getToken() => _token;
  static String? getRefreshToken() => _refreshToken;
}

// ─── GoogleAuth Widget ────────────────────────────────────────────────────────
class GoogleAuth extends StatefulWidget {
  const GoogleAuth({super.key});

  @override
  State<GoogleAuth> createState() => _GoogleAuthState();
}

class _GoogleAuthState extends State<GoogleAuth> {
  // ✅ v7+ API: use GoogleSignIn.instance (singleton), no constructor
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isLoading = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  @override
  void initState() {
    super.initState();
    // ✅ v7+ requires async initialize() before any other call
    _googleSignIn.initialize().then((_) {
      _authSub = _googleSignIn.authenticationEvents.listen(
        _onAuthEvent,
        onError: (e) => debugPrint('❌ Auth stream error: $e'),
      );
      // Attempt silent sign-in for returning users
      _googleSignIn.attemptLightweightAuthentication();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // Called automatically when sign-in state changes
  void _onAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      debugPrint('📌 Auth event: signed in as ${event.user.email}');
      _fetchTokenAndLogin(event.user);
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      debugPrint('📌 Auth event: signed out');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // ✅ v7+ uses authenticate() instead of signIn()
      await _googleSignIn.authenticate();
      // Result comes via authenticationEvents stream → _onAuthEvent
    } on GoogleSignInException catch (e) {
      debugPrint('❌ GoogleSignInException: ${e.code} - ${e.description}');
      final msg = e.code == GoogleSignInExceptionCode.canceled
          ? 'Sign in cancelled'
          : 'Google sign-in failed: ${e.description}';
      _showToast(msg, isError: true);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      _showToast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Get idToken from the signed-in user and call backend
  Future<void> _fetchTokenAndLogin(GoogleSignInAccount user) async {
    try {
      // ✅ v7+: get authorization/idToken via authorizationClient
      final auth = await user.authorizationClient.authorizationForScopes([]);
      final String? idToken = auth?.accessToken;

      if (idToken == null) {
        debugPrint('❌ No ID token received from Google');
        _showToast('Google login failed (no token received)', isError: true);
        return;
      }

      debugPrint('📌 Raw Google Token: $idToken');

      final Map<String, dynamic>? userData = _parseJwt(idToken);
      debugPrint('📌 Decoded Google userData: $userData');

      if (userData == null) {
        _showToast('Failed to parse Google token', isError: true);
        return;
      }

      await _socialLoginAPI(userData, idToken);
    } catch (e) {
      debugPrint('❌ Token fetch error: $e');
      _showToast(e.toString(), isError: true);
    }
  }

  Future<void> _socialLoginAPI(Map<String, dynamic> userData, String token) async {
    debugPrint('📤 Requesting Social Login API');

    final reqData = {
      'provider': 'google',
      'token': token,
      'userData': {
        'sub': userData['sub'],
        'given_name': userData['given_name'],
        'family_name': userData['family_name'],
        'email': userData['email'],
        'picture': userData['picture'],
        'email_verified': userData['email_verified'] ?? true,
      },
    };

    try {
      final userDataResponse = await AuthService().socialLogin(reqData);

      if (userDataResponse == null) {
        _showToast('Server not responding', isError: true);
        return;
      }
      if (userDataResponse['error'] != null) {
        _showToast(userDataResponse['error'], isError: true);
        return;
      }
      if (userDataResponse['warning'] != null) {
        _showToast(userDataResponse['warning'], isWarning: true);
        return;
      }

      final String? accessToken = userDataResponse['data']?['access_token'];
      final String? refreshToken = userDataResponse['data']?['refresh_token'];

      if (accessToken != null) {
        TokenStorage.setToken(accessToken);
        if (refreshToken != null) TokenStorage.setRefreshToken(refreshToken);
        debugPrint('✅ Login successful. Navigating to /home');
        _showToast('Login Successfully');
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: {'email': userDataResponse['email']},
          );
        }
      } else {
        _showToast('Login failed', isError: true);
      }
    } catch (e) {
      debugPrint('❌ Login Exception: $e');
      _showToast(e.toString(), isError: true);
    }
  }

  Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      return jsonDecode(utf8.decode(base64Decode(normalized))) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Failed to parse JWT: $e');
      return null;
    }
  }

  void _showToast(String message, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? Colors.red.shade600
          : isWarning
              ? Colors.orange.shade600
              : Colors.green.shade600,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sign in with Google',
      child: _isLoading
          ? const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Colors.grey),
              ),
              onPressed: _handleGoogleSignIn,
              icon: Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                height: 20,
                width: 20,
              ),
              label: const Text(
                'Sign in with Google',
                style: TextStyle(color: Colors.black87),
              ),
            ),
    );
  }
}