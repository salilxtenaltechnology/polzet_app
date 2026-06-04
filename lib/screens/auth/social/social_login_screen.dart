// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../api/services/google/google_auth_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/button/google/google_button.dart';
import '../../home/settings/privacy/privacy_policy.dart';
import '../../home/settings/terms and conditions/terms_and_conditions.dart';
import '../login/email_login.dart';

class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen>
    with UtilityMixin {
  bool _isGoogleLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    GoogleAuthService.initialize(
      onSignIn: (user) => GoogleAuthService.fetchTokenAndLogin(
        user: user,
        context: context,
        onError: (msg) {
          if (mounted) {
            String friendlyMsg = msg;
            final lower = msg.toLowerCase();
            if (lower.contains('connection timeout') ||
                lower.contains('timeout') ||
                lower.contains('socketexception') ||
                lower.contains('connection error') ||
                lower.contains('server not responding') ||
                lower.contains('connection failed') ||
                lower.contains('connection refused') ||
                lower.contains('failed to connect')) {
              friendlyMsg = 'Internal server is down. Please try again later.';
            } else {
              friendlyMsg = friendlyMsg
                  .replaceAll(RegExp(r'^Login error:\s*'), '')
                  .replaceAll(RegExp(r'^Exception:\s*'), '');
            }
            setState(() {
              _errorMessage = friendlyMsg;
              _isGoogleLoading = false;
            });
          }
        },
        onLoadingDone: () {
          if (mounted) setState(() => _isGoogleLoading = false);
        },
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await GoogleAuthService.authenticate();
    } catch (e) {
      if (kDebugMode) print('Google sign in error: $e');
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    GoogleAuthService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    Assets.images.icSplash.path,
                    width: 42,
                    height: 42,
                  ),
                  const SizedBox(width: 15),
                  Text(
                    'POLZET',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to Polzet',
                textAlign: TextAlign.center,
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Join the community and start sharing your opinion.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.5,
                  color: txt.body,
                ),
              ),
              const Spacer(flex: 1),
              GoogleButton(
                isLoading: _isGoogleLoading,
                onTap: _handleGoogleSignIn,
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      thickness: 1,
                      indent: 40,
                      endIndent: 5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 13,
                        color: txt.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      thickness: 1,
                      indent: 5,
                      endIndent: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _EmailPhoneButton(),
              const SizedBox(height: 16),
              // GestureDetector(
              //   onTap: () {},
              //   child: Text(
              //     'Continue as Guest',
              //     style: AppTextStyles.bodyText.copyWith(
              //       color: Theme.of(context).colorScheme.primary,
              //       fontSize: 13,
              //       fontWeight: FontWeight.w500,
              //     ),
              //   ),
              // ),
              const Spacer(flex: 3),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14,
                    color: txt.muted,
                  ),
                  children: [
                    const TextSpan(text: 'By continuing, you agree to our '),
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            navigationPush(context, const TermsAndConditions()),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            navigationPush(context, const PrivacyPolicy()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailPhoneButton extends StatelessWidget with UtilityMixin {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => navigationPush(context, const EmailLoginScreen()),
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          side: BorderSide(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline
                : const Color(0xFFE5E7EB),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          'Continue With Email or Phone',
          style: AppTextStyles.cardTitle.copyWith(
            fontSize: 15,
            color: isDarkMode
                ? Theme.of(context).colorScheme.onBackground.withOpacity(0.9)
                : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}
