// security_gate_screen.dart
// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/dialog/diolog_animation.dart';
import 'biometric/biometric_service.dart';
import 'pin/pin_status.dart';

class SecurityGateScreen extends StatefulWidget {
  final Widget destination;
  const SecurityGateScreen({super.key, required this.destination});

  @override
  _SecurityGateScreenState createState() => _SecurityGateScreenState();
}

class _SecurityGateScreenState extends State<SecurityGateScreen>
    with UtilityMixin {
  String _enteredPin = '';
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isLocked = false;

  bool _isPinEnabled = false;
  bool _isFingerprintEnabled = false;
  bool _isBiometricAvailable = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final pinEnabled = await PinService.isPinSecurityEnabled();
    final fingerprintEnabled = await BiometricService.isFingerprintEnabled();
    final biometricAvailable = await BiometricService.isBiometricAvailable();

    PinStatus? status;
    if (pinEnabled) {
      status = await PinService.getPinStatus();
    }

    setState(() {
      _isPinEnabled = pinEnabled;
      _isFingerprintEnabled = fingerprintEnabled;
      _isBiometricAvailable = biometricAvailable;

      if (status != null) {
        _isLocked = status.isLocked;
        if (status.isLocked && status.lockoutEndTime != null) {
          final remaining = status.lockoutEndTime!.difference(DateTime.now());
          if (remaining.isNegative) {
            _isLocked = false;
          } else {
            _errorMessage =
                'Account locked. Try again in ${remaining.inMinutes} minutes.';
          }
        }
      }
    });

    if (fingerprintEnabled && biometricAvailable && !_isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithFingerprint();
      });
    }
  }

  Future<void> _authenticateWithFingerprint() async {
    try {
      if (mounted) {
        setState(() => _errorMessage = '');
      }
      final isAuthenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'Authenticate to continue',
        useErrorDialogs: true,
        stickyAuth: true,
      );
      if (!mounted) return;
      if (isAuthenticated) {
        _navigateToDestination();
      } else {
        if (!_isPinEnabled && _isFingerprintEnabled && _isBiometricAvailable) {
          _showBiometricRequiredDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        if (!_isPinEnabled && _isFingerprintEnabled && _isBiometricAvailable) {
          _showBiometricRequiredDialog();
        }
      }
    }
  }

  void _showBiometricRequiredDialog() {
    if (_dialogOpen) return;
    _dialogOpen = true;
    diologanimation(
      context,
      BiometricRequiredDialog(
        onUnlock: () {
          _dialogOpen = false;
          Navigator.of(context).pop();
          _authenticateWithFingerprint();
        },
        onCloseApp: () {
          _dialogOpen = false;
          SystemNavigator.pop();
        },
      ),
    ).then((_) {
      _dialogOpen = false;
    });
  }

  void _navigateToDestination() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => widget.destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _isLoading
          ? Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            )
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                // ── Switch layout based on mode ──────────────────────────
                child: _isPinEnabled
                    ? _buildPinLayout(txt)
                    : _buildFingerprintOnlyLayout(txt),
              ),
            ),
    );
  }

  // ── Fingerprint-only: fully centered ──────────────────────────────────────
  Widget _buildFingerprintOnlyLayout(dynamic txt) {
    final txt = AppTextColors.of(context);
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          SizedBox(
            width: 100,
            height: 100,
            child: Image.asset(Assets.images.icSplash.path),
          ),
          const SizedBox(height: 12),
          Text(
            'Verify your identity with fingerprint',
            style: AppTextStyles.bodyText.copyWith(
              color: txt.title,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(flex: 3),
          Text(
            'POLZET',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onBackground,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── PIN layout: original top-aligned with spacer ──────────────────────────
  Widget _buildPinLayout(dynamic txt) {
    return Column(
      children: [
        // Lock icon
        Container(
          width: 75,
          height: 75,
          margin: const EdgeInsets.only(top: 15),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
          ),
          child: Image.asset(
            Assets.images.icSecurity.path,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          ),
        ),

        SizedBox(height: 18.h),

        Text(
          'Enter PIN',
          style: AppTextStyles.subSectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 8.h),

        Text(
          'Enter your 4-digit PIN to continue',
          style: AppTextStyles.subSectionHeading.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: txt.muted,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 32.h),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.transparent,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onPrimary,
                  width: 1.5,
                ),
              ),
              child: index < _enteredPin.length
                  ? Center(
                      child: Container(
                        width: 13.w,
                        height: 13.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : null,
            );
          }),
        ),

        SizedBox(height: 15.h),

        if (_errorMessage.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.only(top: 5.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 10.3.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 10.h),
        ],

        const SizedBox(height: 55),
        _buildNumberPad(),

        if (_isFingerprintEnabled && _isBiometricAvailable) ...[
          const Spacer(),
          GestureDetector(
            onTap: _authenticateWithFingerprint,
            child: Container(
              width: 55.w,
              height: 55.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.08),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.fingerprint,
                  size: 30.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.85),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
        ] else ...[
          const Spacer(),
        ],
      ],
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildPadRow(['1', '2', '3']),
        SizedBox(height: 16.h),
        _buildPadRow(['4', '5', '6']),
        SizedBox(height: 16.h),
        _buildPadRow(['7', '8', '9']),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDeleteButton(),
            _buildNumberButton('0'),
            _buildClearAllNumberButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildPadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map(_buildNumberButton).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isLocked ? null : () => _onNumberPressed(number),
      child: Container(
        width: 65.w,
        height: 65.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: isDarkMode ? const Color(0xFF12141D) : Colors.white,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(_isLocked ? 0.05 : 0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: AppTextStyles.subSectionHeading.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(_isLocked ? 0.3 : 0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isLocked ? null : _onDeletePressed,
      child: Container(
        width: 65.w,
        height: 65.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: isDarkMode ? const Color(0xFF12141D) : Colors.white,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(_isLocked ? 0.05 : 0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(_isLocked ? 0.3 : 1.0),
            size: 22.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllNumberButton() {
    return GestureDetector(
      onTap: _isLocked ? null : () => setState(() => _enteredPin = ''),
      child: Container(
        width: 65.w,
        height: 65.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.09),
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(_isLocked ? 0.3 : 1.0),
            size: 23.sp,
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _errorMessage = '';
      });
      if (_enteredPin.length == 4) _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    try {
      final authResult = await PinService.authenticateWithPin(_enteredPin);
      if (!mounted) return;
      if (authResult.success) {
        _navigateToDestination();
      } else {
        setState(() {
          _errorMessage = authResult.message;
          _isLocked = authResult.isLocked;
          _enteredPin = '';
          _isLoading = false;
        });
        if (authResult.isLocked) await _loadStatus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error verifying PIN. Please try again.';
        _enteredPin = '';
        _isLoading = false;
      });
    }
  }
}

class BiometricRequiredDialog extends StatelessWidget {
  final VoidCallback onUnlock;
  final VoidCallback onCloseApp;

  const BiometricRequiredDialog({
    super.key,
    required this.onUnlock,
    required this.onCloseApp,
  });

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF292a2c)
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 25.h),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 37.sp,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Authentication Required',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Biometric authentication is required to access Polzet. Please authenticate to unlock the app.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.muted,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 0.8,
            thickness: 0.8,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCloseApp,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      color: Colors.transparent,
                      child: Text(
                        'Close',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.sp,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 0.8,
                  thickness: 0.8,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onUnlock,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      color: Colors.transparent,
                      child: Text(
                        'Unlock',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.sp,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
