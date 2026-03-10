// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../mixin/utility_mixins.dart';
import '../auth/login/login_import.dart';
import '../home/home_imports.dart';

class TermsAcceptanceScreen extends StatelessWidget with UtilityMixin {
  const TermsAcceptanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POLZET - Terms & Conditions',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildSection(
                    '1. Acceptance of Terms',
                    'By accessing or using Polzet, you agree to be bound by these Terms and Conditions.',
                  ),
                  _buildSection(
                    '2. User Content',
                    'You are responsible for all content you post. We reserve the right to remove content that violates our policies.',
                  ),
                  _buildSection(
                    '3. Privacy',
                    'Your use of Polzet is also governed by our Privacy Policy, which is incorporated into these Terms.',
                  ),
                  _buildSection(
                    '4. Account Termination',
                    '• You may terminate your account at any time by following the instructions on the Platform. Upon termination, your User Content may remain on the Platform if shared or reposted by others.\n\n• We may suspend or terminate your access to the Platform at any time, with or without cause, and with or without notice.\n\n• Provisions of these Terms that by their nature should survive termination (e.g., intellectual property, limitation of liability, indemnification) will continue to apply.',
                  ),
                  _buildSection(
                    '5. Miscellaneous',
                    '• These Terms, together with our Privacy Policy, constitute the entire agreement between you and Polzet regarding your use of the Platform.\n\n• Our failure to enforce any provision of these Terms does not constitute a waiver of that provision.\n\n• You may not assign these Terms or your rights under them without our prior written consent.\n\n• Polzet will not be liable for any failure to perform due to causes beyond our reasonable control (e.g., natural disasters, cyberattacks).',
                  ),
                  _buildSection(
                    '6. Contact Us',
                    'If you have questions about these Terms, please contact us at:\n\n• Contact@polzet.com\n\nBy using Polzet, you acknowledge that you have read and understood these Terms and agree to be bound by them. Thank you for being part of our community!',
                  ),
                ],
              ),
            ),
          ),
          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(12).w,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // Decline → clear token → back to login
                      await SharedPrefService.clearTokens();
                      clearStackAndAddScreen(context, const LoginScreen());
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      minimumSize: Size(double.infinity, 42.h),
                    ),
                    child: Text(
                      'DECLINE',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Save acceptance → go to home
                      await SharedPrefService.setTermsAccepted();
                      clearStackAndAddScreen(
                        context,
                        const HomeScreen(initialIndex: 0),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      minimumSize: Size(double.infinity, 42.h),
                    ),
                    child: Text(
                      'ACCEPT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.6,
              color: const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}
