import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../api/services/google/google_auth_service.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/button/google/google_button.dart';
import '../../home/settings/privacy/privacy_policy.dart';
import '../../home/settings/terms and policy/terms_and_conditions.dart';
import 'email_login.dart';

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
          if (mounted) setState(() => _errorMessage = msg);
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
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
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
                  const Text(
                    'polzet',
                    style: TextStyle(
                      fontFamily: 'Flexing',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
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
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Join the community and start sharing your opinion.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.5,
                  color: const Color(0xFF595959),
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
                      color: Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Color(0xFFE5E7EB),
                      thickness: 1,
                      indent: 40,
                      endIndent: 5,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Color(0xFFE5E7EB),
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
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Continue as Guest',
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF8A8A8A),
                  ),
                  children: [
                    const TextSpan(text: 'By continuing, you agree to our '),
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).colorScheme.primary,
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => navigationPush(context, const EmailLoginScreen()),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          'Continue With Email or Phone',
          style: AppTextStyles.cardTitle.copyWith(
            fontSize: 15,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}
