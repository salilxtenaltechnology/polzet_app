// ignore_for_file: deprecated_member_use, must_be_immutable, unused_local_variable, unused_element, unused_field, use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../provider/user_provider.dart';
import '../../mixin/utility_mixins.dart';
import '../auth/login/login_import.dart';
import '../home/home_imports.dart';
import '../home/settings/security/biometric/biometric_screen.dart';
import '../home/settings/security/biometric/biometric_service.dart';
import '../home/settings/security/pin/pin_gate_screen.dart';
import '../home/settings/security/pin/pin_status.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, UtilityMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<Offset> _textAnimation;

  // Future that resolves to the next screen widget
  late Future<Widget> _initializationFuture;

  @override
  void initState() {
    super.initState();

    // Start initialization logic immediately
    _initializationFuture = _initializeApp();

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Logo animation: small to big
    _logoAnimation = Tween<double>(begin: 0.02, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );

    // Text animation: right to left
    _textAnimation =
        Tween<Offset>(begin: const Offset(2.2, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.7, 1.0, curve: Curves.decelerate),
          ),
        );

    // Start animation and listen for completion
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleAnimationComplete();
      }
    });
  }

  /// ✅ Core initialization logic moved from main.dart
  Future<Widget> _initializeApp() async {
    final bool isUserLoggedIn = await _isLoggedIn();

    if (!isUserLoggedIn) {
      return const LoginScreen();
    }

    try {
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
      }
    } catch (e) {
      return const LoginScreen();
    }


    // existing notification + biometric logic...
    final notificationRouter = NotificationRouter();
    Widget? notificationDestination;
    if (notificationRouter.hasPendingNotification()) {
      notificationDestination = await notificationRouter.resolveDestination();
    }

    final bool isBiometricEnabled = await BiometricService.isBiometricEnabled();
    if (!isBiometricEnabled) {
      return HomeScreen(
        initialIndex: 0,
        pendingDestination: notificationDestination,
      );
    }

    final bool isPinSecurityEnabled = await PinService.isPinSecurityEnabled();
    final bool isFingerprintEnabled =
        await BiometricService.isFingerprintEnabled();

    if (isPinSecurityEnabled) {
      final bool isPinSet = await PinService.isPinSet();
      if (isPinSet) {
        return PinGateScreen(
          destination: HomeScreen(
            initialIndex: 0,
            pendingDestination: notificationDestination,
          ),
        );
      }
    }

    if (isFingerprintEnabled) {
      final bool isBiometricAvailable =
          await BiometricService.isBiometricAvailable();
      if (isBiometricAvailable) {
        return BiometricGateScreen(
          destination: HomeScreen(
            initialIndex: 0,
            pendingDestination: notificationDestination,
          ),
        );
      }
    }

    return HomeScreen(
      initialIndex: 0,
      pendingDestination: notificationDestination,
    );
  }

  Future<bool> _isLoggedIn() async {
    final accessToken = await SharedPrefService.getToken();
    return accessToken != null;
  }

  Future<void> _handleAnimationComplete() async {
    // Wait for minimum time AND initialization
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    final nextScreen = await _initializationFuture;

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => nextScreen),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: Image.asset(
                        Assets.assetsImagesIcSplash,
                        width: 38.w,
                        height: 38.h,
                      ),
                    );
                  },
                ),
                SizedBox(width: 7.w),
                SlideTransition(
                  position: _textAnimation,
                  child: Text(
                    AppStrings.appName.toUpperCase(),
                    style: GoogleFonts.yesevaOne(
                      color: AppColors.primaryColor,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
