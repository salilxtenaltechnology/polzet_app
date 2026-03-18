// lib/presentation/screens/biometric/biometric_gate_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../../widgets/button/primary_button.dart';
import '../../../../../widgets/loader.dart';
import 'biometric_service.dart';

class BiometricGateScreen extends StatefulWidget {
  final Widget destination;

  const BiometricGateScreen({super.key, required this.destination});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen>
    with SingleTickerProviderStateMixin {
  bool _isAuthenticating = false;
  bool _authenticationFailed = false;
  String _statusMessage = '';
  List<BiometricType> _availableBiometrics = [];
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkBiometricSupport();
    _startAuthentication();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final availableBiometrics =
          await BiometricService.getAvailableBiometrics();
      setState(() {
        _availableBiometrics = availableBiometrics;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking biometric support';
        _authenticationFailed = true;
      });
    }
  }

  Future<void> _startAuthentication() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _authenticationFailed = false;
      _statusMessage = 'Authenticating...';
    });

    _animationController.repeat(reverse: true);

    // Small delay to let UI render
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final String reason = await BiometricService.getBiometricMessage();
      final bool isAuthenticated =
          await BiometricService.authenticateWithBiometrics(
            reason: reason,
            useErrorDialogs: true,
            stickyAuth: true,
          );

      if (isAuthenticated) {
        setState(() {
          _statusMessage = 'Authentication successful!';
        });
        _animationController.stop();

        // Navigate to main app after successful authentication
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => widget.destination),
            (route) => false,
          );
        }
      } else {
        _handleAuthenticationFailure();
      }
    } catch (e) {
      _handleAuthenticationError(e.toString());
    }
  }

  void _handleAuthenticationFailure() {
    _animationController.stop();
    setState(() {
      _isAuthenticating = false;
      _authenticationFailed = true;
      _statusMessage = 'Authentication failed. Please try again.';
    });
  }

  void _handleAuthenticationError(String error) {
    _animationController.stop();
    setState(() {
      _isAuthenticating = false;
      _authenticationFailed = true;
      _statusMessage = 'Authentication error occurred.';
    });
  }

  Widget _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icon(
        Icons.face,
        size: 60.sp,
        color: Theme.of(context).primaryColor,
      );
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icon(
        Icons.fingerprint,
        size: 60.sp,
        color: Theme.of(context).primaryColor,
      );
    } else {
      return Icon(
        Icons.security,
        size: 60.sp,
        color: Theme.of(context).primaryColor,
      );
    }
  }

  String _getBiometricTitle() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID Required';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint Required';
    } else {
      return 'Biometric Authentication Required';
    }
  }

  String _getBiometricSubtitle() {
    if (_authenticationFailed) {
      return _statusMessage;
    }

    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Look at your device to continue';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Place your finger on the sensor to continue';
    } else {
      return 'Use your biometric to continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Polzet Secure Access',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated Biometric Icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isAuthenticating ? _pulseAnimation.value : 1.0,
                      child: Container(
                        padding: EdgeInsets.all(30.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                            width: 2.5,
                          ),
                        ),
                        child: _getBiometricIcon(),
                      ),
                    );
                  },
                ),

                SizedBox(height: 40.h),

                // Title
                Text(
                  _getBiometricTitle(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 16.h),

                // Subtitle/Status
                Text(
                  _getBiometricSubtitle(),
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: _authenticationFailed
                        ? Colors.red
                        : Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),

                SizedBox(height: 50.h),

                // Action Buttons or Loader
                if (_authenticationFailed) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: PrimaryButton(
                      title: 'Try Again',
                      onPressed: _startAuthentication,
                      isLoading: false,
                    ),
                  ),
                ] else if (_isAuthenticating) ...[
                  Loader(color: Theme.of(context).primaryColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
