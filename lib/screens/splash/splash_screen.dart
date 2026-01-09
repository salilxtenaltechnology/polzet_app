// ignore_for_file: deprecated_member_use, must_be_immutable, unused_local_variable, unused_element, unused_field
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_strings.dart';
import '../../mixin/utility_mixins.dart';
import '../auth/login/login_import.dart';
import '../home/home_imports.dart';

class SplashScreen extends StatefulWidget {
  bool? isLogged;
  
  SplashScreen({
    super.key, 
    required this.isLogged,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, UtilityMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<Offset> _textAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Logo animation: small to big
    _logoAnimation = Tween<double>(begin: 0.02, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );

    // Text animation: right to left
    _textAnimation = Tween<Offset>(
      begin: const Offset(2.2, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.7, 1.0, curve: Curves.decelerate),
      ),
    );

    // Start animation
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (widget.isLogged == true) {
        redirectToHomeScreen();
      } else {
        redirectToLoginScreen();
      }
    });
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

  void redirectToLoginScreen() {
    clearStackAndAddScreen(context, LoginScreen());
  }

  void redirectToHomeScreen() {
    clearStackAndAddScreen(context, HomeScreen());
  }
}