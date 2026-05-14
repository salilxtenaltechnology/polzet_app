import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:page_transition/page_transition.dart';

import '../../../data/token/shared_preferences.dart';
import '../../../screens/home/home_imports.dart';
import '../../../screens/terms_acceptance/terms_acceptance.dart';
import '../api_service.dart';
import '../fcm/fcm_service.dart';
import '../notification/notification_services.dart';

class GoogleAuthService {
  static const String _serverClientId =
      '53424915324-6jgqsatmm1o2uslhl1hd326ss483fb8n.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  // ── Initialize once ──────────────────────────────────────────
  static Future<void> initialize({
    required Function(GoogleSignInAccount) onSignIn,
  }) async {
    await _googleSignIn.initialize(serverClientId: _serverClientId);
    _authSub?.cancel();
    _authSub = _googleSignIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        debugPrint('📌 Signed in as ${event.user.email}');
        onSignIn(event.user);
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        debugPrint('📌 Signed out');
      }
    }, onError: (e) => debugPrint('❌ Auth stream error: $e'));
  }

  // ── Trigger sign in ──────────────────────────────────────────
  static Future<void> authenticate() async {
    await _googleSignIn.authenticate();
  }

  // ── Get token and call API ────────────────────────────────────
  static Future<void> fetchTokenAndLogin({
    required GoogleSignInAccount user,
    required BuildContext context,
    required Function(String) onError,
    required Function() onLoadingDone,
  }) async {
    try {
      final GoogleSignInAuthentication auth = user.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        onError('Google login failed (no token received)');
        return;
      }

      await SharedPrefService.setString('jwt_google_token', idToken);
      debugPrint('✅ Google idToken saved');

      await _socialLoginAPI(
        idToken: idToken,
        context: context,
        onError: onError,
        onLoadingDone: onLoadingDone,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // ── Call backend ──────────────────────────────────────────────
  static Future<void> _socialLoginAPI({
    required String idToken,
    required BuildContext context,
    required Function(String) onError,
    required Function() onLoadingDone,
  }) async {
    try {
      final response = await ApiService().socialLogin(idToken);

      if (response == null) {
        onError('Server not responding');
        return;
      }

      final String? status = response['status'];
      if (status != 'success') {
        onError(response['message'] ?? 'Login failed');
        return;
      }

      final data = response['data'] as Map<String, dynamic>;
      final String accessToken = data['access_token'];
      final String refreshToken = data['refresh_token'];
      final Map<String, dynamic> user = data['user'];
      
      final dynamic isNewUserRaw = data['is_new_user'] ?? user['is_new_user'];
      final bool isNewUser = isNewUserRaw == true || isNewUserRaw == 'true';

      await SharedPrefService.setToken(accessToken);
      await SharedPrefService.setRefreshToken(refreshToken);
      await SharedPrefService.setString('username', user['username'] ?? '');
      await SharedPrefService.setString('email', user['email'] ?? '');

      await NotificationService().initialize();
      await NotificationService().connectToWebSocket(accessToken);

      final fcmToken = await NotificationService().getFCMToken();
      if (fcmToken != null) {
        final platform = Platform.isAndroid ? 'android' : 'ios';
        await FcmApiService.registerFcmToken(fcmToken, platform);
      }

      onLoadingDone();

      if (context.mounted) {
        final Widget destination = isNewUser
            ? const TermsAcceptance(isNewUser: true)
            : const HomeScreen(initialIndex: 0);

        Navigator.pushAndRemoveUntil(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            duration: const Duration(milliseconds: 200),
            child: destination,
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) print('socialLoginAPI exception: $e');
      onError('Login error: $e');
    }
  }

  // ── Dispose ───────────────────────────────────────────────────
  static void dispose() {
    _authSub?.cancel();
  }
}
