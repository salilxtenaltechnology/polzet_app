import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/google/google_auth_service.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../main.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/button/google/google_button.dart';
import '../forgot password/new_forgot_password_screen.dart';
import '../verify/email_number_verify_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> with UtilityMixin {
  final ApiService _apiService = ApiService();

  bool _isEmailTab = true;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  final bool _agreeTerms = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String _emailOrMobileError = '';
  String _passwordError = '';
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

  /* ─── Google Auth  ───── */
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await GoogleAuthService.authenticate();
    } catch (e) {
      if (kDebugMode) print('Google sign in error: $e');
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  bool _validateInputs() {
    bool isValid = true;
    setState(() {
      _emailOrMobileError = '';
      _passwordError = '';
    });

    if (_isEmailTab) {
      final input = _emailController.text.trim();
      if (input.isEmpty) {
        setState(() => _emailOrMobileError = 'Please enter your email');
        isValid = false;
      } else {
        final isEmail = RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
        ).hasMatch(input);
        final isUsername = RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(input);
        if (!isEmail && !isUsername) {
          setState(
            () => _emailOrMobileError = 'Enter a valid email or username',
          );
          isValid = false;
        }
      }
    } else {
      final mobile = _mobileController.text.trim();
      if (mobile.isEmpty) {
        setState(() => _emailOrMobileError = 'Please enter your mobile number');
        isValid = false;
      } else if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
        setState(
          () => _emailOrMobileError = 'Enter a valid 10-digit mobile number',
        );
        isValid = false;
      }
    }

    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      isValid = false;
    } else if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(password)) {
      setState(
        () => _passwordError =
            'Min 8 chars with a letter, number & special character',
      );
      isValid = false;
    }

    return isValid;
  }

  Future<void> _loginUser() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final loginValue = _isEmailTab
          ? _emailController.text.trim()
          : _mobileController.text.trim();

      await _apiService.loginUser(
        email_username: loginValue,
        password: _passwordController.text.trim(),
        context: context,
      );

      final savedLang = await SharedPrefService.getLanguage();
      if (mounted && savedLang != null) {
        MyApp.of(context)?.changeLanguage(Locale(savedLang));
      } else if (mounted) {
        MyApp.of(context)?.resetLocale();
      }
    } catch (e) {
      if (kDebugMode) print('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    GoogleAuthService.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),

              // Title
              Text(
                'Continue with Email',
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: const Color(0xFF111111),
                ),
              ),

              const SizedBox(height: 28),

              // Tab Switcher
              _buildTabSwitcher(),

              const SizedBox(height: 28),

              // Dynamic fields based on tab
              if (_isEmailTab) ...[
                _buildFieldLabel('Email or Username'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hint: 'Email or Username here',
                  keyboardType: TextInputType.emailAddress,
                ),
                if (_emailOrMobileError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      _emailOrMobileError,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ] else ...[
                _buildFieldLabel('Mobile Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _mobileController,
                  hint: 'Mobile number here',
                  keyboardType: TextInputType.phone,
                ),
              ],

              const SizedBox(height: 20),

              _buildFieldLabel('Password'),
              const SizedBox(height: 8),
              _buildPasswordField(),
              if (_passwordError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    _passwordError,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              // Remember me + Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFDDDDDD),
                            width: 1.5,
                          ),
                          activeColor: Theme.of(context).colorScheme.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF404040),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      navigationPush(context, const NewForgotPasswordScreen());
                    },
                    child: Text(
                      'Forgot Password?',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Log In Button
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 18),

              // Sign Up Row
              Center(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.5,
                      color: const Color(0xFF8A8A8A),
                    ),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            navigationPush(
                              context,
                              const EmailNumberVerifyScreen(),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // OR Divider
              const Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Color(0xFFE5E7EB),
                      thickness: 1,
                      indent: 50,
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
                      endIndent: 50,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Continue With Google
              GoogleButton(
                isLoading: _isGoogleLoading,
                onTap: () => _handleGoogleSignIn(),
              ),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

              // const SizedBox(height: 16),

              // // Terms & Conditions checkbox
              // Row(
              //   crossAxisAlignment: CrossAxisAlignment.center,
              //   children: [
              //     SizedBox(
              //       width: 22,
              //       height: 22,
              //       child: Checkbox(
              //         value: _agreeTerms,
              //         onChanged: (v) => setState(() => _agreeTerms = v!),
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(4),
              //         ),
              //         side: const BorderSide(
              //           color: Color(0xFFDDDDDD),
              //           width: 1.5,
              //         ),
              //         activeColor: Theme.of(context).colorScheme.primary,
              //         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              //       ),
              //     ),
              //     const SizedBox(width: 10),
              //     Expanded(
              //       child: RichText(
              //         text: TextSpan(
              //           style: AppTextStyles.bodyText.copyWith(
              //             fontSize: 14,
              //             color: const Color(0xFF8A8A8A),
              //           ),
              //           children: [
              //             const TextSpan(text: 'I agree to the '),
              //             TextSpan(
              //               text: 'Terms & Conditions',
              //               style: TextStyle(
              //                 color: Theme.of(context).colorScheme.primary,
              //                 fontWeight: FontWeight.w500,
              //               ),
              //               recognizer: TapGestureRecognizer()
              //                 ..onTap = () {
              //                   navigationPush(
              //                     context,
              //                     const TermsAndConditions(),
              //                   );
              //                 },
              //             ),
              //             const TextSpan(text: ' and '),
              //             TextSpan(
              //               text: 'Privacy Policy',
              //               style: TextStyle(
              //                 color: Theme.of(context).colorScheme.primary,
              //                 fontWeight: FontWeight.w500,
              //               ),
              //               recognizer: TapGestureRecognizer()
              //                 ..onTap = () {
              //                   navigationPush(context, const PrivacyPolicy());
              //                 },
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ],
              // ),

              // const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDDDDDD), width: 1.2),
      ),
      child: Row(
        children: [
          // Email Login Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isEmailTab = true;
                _emailOrMobileError = '';
                _passwordError = '';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),

                decoration: BoxDecoration(
                  color: _isEmailTab
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Email Login',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: _isEmailTab ? Colors.white : const Color(0xFFB3B3B3),
                  ),
                ),
              ),
            ),
          ),
          // Mobile Login Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isEmailTab = false;
                _emailOrMobileError = '';
                _passwordError = '';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isEmailTab
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mobile Login',

                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: !_isEmailTab
                        ? Colors.white
                        : const Color(0xFFB3B3B3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF2C2C2C),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            color: const Color(0xFFB3B3B3),
            fontWeight: FontWeight.w400,
          ),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            color: const Color(0xFFB3B3B3),
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.remove_red_eye_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF8E8E8E),
              size: 22,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
