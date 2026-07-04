// ignore_for_file: deprecated_member_use, must_be_immutable, unused_local_variable, unused_element, unused_field, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/notification_router.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../provider/user_provider.dart';
import '../../gen/assets.gen.dart';
import '../../mixin/utility_mixins.dart';
import '../auth/onboarding/onboarding_screen.dart';
import '../auth/social/social_login_screen.dart';
import '../home/home_imports.dart';
import '../home/settings/security/biometric/biometric_service.dart';
import '../home/settings/security/security_gate_screen.dart';
import '../home/settings/security/pin/pin_status.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, UtilityMixin {
  // Future that resolves to the next screen widget
  late Future<Widget> _initializationFuture;

  // Logo animation
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Text animation
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Start initialization logic immediately
    _initializationFuture = _initializeApp();

    // ── Logo Animations ──
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.05, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    // ── Text Animations ──
    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _playAnimations();
  }

  Future<void> _playAnimations() async {
    try {
      await Future.wait([
        _logoController.forward().orCancel,
        _textController.forward().orCancel,
      ]);
    } catch (e) {
      debugPrint('Animation interrupted: $e');
    } finally {
      _handleAnimationComplete();
    }
  }

  Future<Widget> _initializeApp() async {
    final bool isUserLoggedIn = await _isLoggedIn();

    // ── Already logged in → skip onboarding & login
    if (isUserLoggedIn) {
      try {
        if (mounted) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          await userProvider.loadUserData().timeout(const Duration(seconds: 3));
        }
      } catch (e) {
        debugPrint('Error or timeout loading user data during splash: $e');
      }

      final notificationRouter = NotificationRouter();
      Widget? notificationDestination;
      int initialIndex = 0;
      if (notificationRouter.hasPendingNotification()) {
        notificationDestination = await notificationRouter.resolveDestination(
          context,
        );
        if (notificationDestination is HomeScreen) {
          initialIndex = notificationDestination.initialIndex;
          notificationDestination = null;
        }
      }

      final bool isPinSecurityEnabled = await PinService.isPinSecurityEnabled();
      final bool isFingerprintEnabled =
          await BiometricService.isFingerprintEnabled();
      final bool isBiometricAvailable =
          await BiometricService.isBiometricAvailable();

      final homeScreen = HomeScreen(
        initialIndex: initialIndex,
        pendingDestination: notificationDestination,
      );

      if (isPinSecurityEnabled || (isFingerprintEnabled && isBiometricAvailable)) {
        return SecurityGateScreen(destination: homeScreen);
      }

      return homeScreen;
    }

    // ── Not logged in → check onboarding
    final bool onboardingSeen = await SharedPrefService.isOnboardingSeen();
    if (!onboardingSeen) {
      return const OnboardingScreen();
    }

    return const SocialLoginScreen();
  }

  Future<bool> _isLoggedIn() async {
    final accessToken = await SharedPrefService.getToken();
    return accessToken != null;
  }

  Future<void> _handleAnimationComplete() async {
    // Wait for minimum time AND initialization
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    Widget nextScreen;
    try {
      nextScreen = await _initializationFuture;
    } catch (e) {
      debugPrint('Initialization error: $e');
      nextScreen = const SocialLoginScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => nextScreen),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02000E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                Assets.images.bgSpalsh.path,
                fit: BoxFit.scaleDown,
              ),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo ──
              AnimatedBuilder(
                animation: _logoController,
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Image.asset(
                      Assets.images.icSplash.path,
                      width: 130,
                      height: 130,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ── POLZET gradient text ──
              AnimatedBuilder(
                animation: _textController,
                builder: (_, __) => FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFB7A44), // #FB7A44
                          Color(0xFFFD555A), // #FD555A
                          Color(0xFFC004A3), // #C004A3
                          Color(0xFF5909B5), // #5909B5
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'POLZET',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}