// ignore_for_file: deprecated_member_use
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';
import 'package:polzet_app/screens/home/home_imports.dart';
import 'package:polzet_app/screens/home/settings/privacy/privacy_policy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/services/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../provider/user_provider.dart';

class TermsAcceptance extends StatefulWidget {
  const TermsAcceptance({super.key});

  @override
  State<TermsAcceptance> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptance>
    with TickerProviderStateMixin, UtilityMixin {
  bool _privacyAccepted = false;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late AnimationController _checkController;
  late AnimationController _buttonController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
  }

  Future<void> onAcceptPrivacy() async {
    if (!_canProceed || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService().acceptPrivacyStatus(status: 'accept');

      debugPrint('Privacy result: $result');

      final isAccepted =
          result['is_accepted'] == true || result['success'] == true;

      if (isAccepted) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        await prefs.setBool('privacy_accepted', true);

        Provider.of<UserProvider>(
          context,
          listen: false,
        ).setPrivacyStatus(true);
        navigationPushReplacement(context, const HomeScreen(initialIndex: 0));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Something went wrong')),
        );
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Something went wrong';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update privacy status')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _checkController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  // ✅ Only depends on _privacyAccepted now
  bool get _canProceed => _privacyAccepted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            );
          },
          // ✅ Center wraps everything to vertically center on screen
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*──── Header ────*/
                  _buildHeader(isDark),

                  /*──── Summary ────*/
                  _buildPolicyCard(isDark),

                  /*──── Checkbox ────*/
                  SizedBox(height: 10.h),
                  _buildCheckRow(
                    value: _privacyAccepted,
                    onChanged: (val) {
                      setState(() => _privacyAccepted = val ?? false);
                      if (val == true) _checkController.forward(from: 0);
                    },
                    richText: TextSpan(
                      children: [
                        TextSpan(
                          text: 'I have read and accept the ',
                          style: GoogleFonts.inter(
                            fontSize: 12.5.sp,
                            color: isDark
                                ? const Color(0xFFB0B0C8)
                                : const Color(0xFF374151),
                          ),
                        ),
                        TextSpan(
                          text: 'Privacy Policy.',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              navigationPush(context, const PrivacyPolicy());
                            },
                        ),
                      ],
                    ),
                    isDark: isDark,
                  ),

                  SizedBox(height: 12.h),

                  /*──── Accept & Continue Button ────*/
                  _buildAcceptButton(isDark),

                  SizedBox(height: 10.h),

                  /*──── Footer note ────*/
                  Text(
                    'By continuing, you acknowledge that you have read and understood our policies.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10.8.sp,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF8A8AA0)
                          : const Color(0xFF6B7280).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /*───── Accept Button ─────*/
  Widget _buildAcceptButton(bool isDark) {
    return GestureDetector(
      onTap: _canProceed ? onAcceptPrivacy : null,
      child: Container(
        width: double.infinity,
        height: 32.h,
        decoration: BoxDecoration(
          color: _canProceed
              ? AppColors.primaryColor
              : (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(25.r),
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Accept & Continue',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _canProceed
                        ? Colors.white
                        : (isDark
                              ? const Color(0xFF3A3A55)
                              : const Color(0xFF9CA3AF)),
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }

  /*───── Header ─────*/

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 45.w,
            height: 45.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryColor, Color(0xFFE93A5D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE93A5D).withOpacity(0.35),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.shield_rounded, color: Colors.white, size: 25.sp),
          ),
        ),
        SizedBox(height: 14.h),
        Center(
          child: Text(
            'Privacy Policy',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0D0D1A),
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(height: 5.h),
        Center(
          child: Text(
            'Please review and accept our policies\nto continue using the app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: isDark ? const Color(0xFF8A8AA0) : const Color(0xFF6B7280),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  // ── Policy Card ──────────────────────────────────────────────────────────────

  Widget _buildPolicyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0).w,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A27) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A3D) : const Color(0xFFE5E7EB),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicySectionTitle('Privacy Policy Summary', isDark),
          SizedBox(height: 5.h),
          _buildPolicyText(
            'We collect only the information necessary to provide you with a '
            'personalised and secure experience. Your data is never sold to '
            'third parties, and you retain full ownership of any content you '
            'create on our platform.',
            isDark,
          ),
          SizedBox(height: 7.h),
          _buildPolicyText(
            'You may request deletion of your account and associated data at '
            'any time, processed within 30 days in compliance with applicable '
            'data protection regulations.',
            isDark,
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  // ── Custom Checkbox Row ──────────────────────────────────────────────────────

  Widget _buildCheckRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required InlineSpan richText,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17.w,
            height: 17.w,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primaryColor
                  : (isDark
                        ? const Color(0xFF1E1E2E)
                        : const Color(0xFFF0F0F5)),
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: value
                    ? Colors.transparent
                    : (isDark
                          ? const Color(0xFF3A3A55)
                          : const Color(0xFFD1D5DB)),
                width: 1.5,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded, size: 14.sp, color: Colors.white)
                : null,
          ),
          SizedBox(width: 5.w),
          Expanded(child: RichText(text: richText)),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildPolicySectionTitle(String title, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3.w,
          height: 12.h,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryColor, Color(0xFFE93A5D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyText(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11.5.sp,
        height: 1.5,
        color: isDark ? const Color(0xFF8A8AA0) : const Color(0xFF6B7280),
      ),
    );
  }
}
