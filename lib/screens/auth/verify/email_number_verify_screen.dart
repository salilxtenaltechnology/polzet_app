// ignore_for_file: deprecated_member_use
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../main.dart';
import '../../../models/country/country_model.dart';
import '../../../widgets/country_code/code_bottomsheet.dart';
import 'otp_verify_screen.dart';

class EmailNumberVerifyScreen extends StatefulWidget {
  const EmailNumberVerifyScreen({super.key});

  @override
  State<EmailNumberVerifyScreen> createState() =>
      _EmailNumberVerifyScreenState();
}

class _EmailNumberVerifyScreenState extends State<EmailNumberVerifyScreen> {
  bool _isMobileSelected = false;
  bool _isSendingOtp = false;
  bool _isLoginMode = false;
  bool _obscurePassword = true;
  String _emailOrMobileError = '';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Country _selectedCountry = Country(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
  );

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '${name[0]}***@$domain';
    return '${name.substring(0, 3)}${'*' * (name.length - 3)}@$domain';
  }

  bool _validate() {
    setState(() => _emailOrMobileError = '');

    if (_isMobileSelected) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        setState(() => _emailOrMobileError = 'Please enter your mobile number');
        return false;
      }
      if (phone.length < 7) {
        setState(
          () => _emailOrMobileError = 'Please enter a valid mobile number',
        );
        return false;
      }
    } else {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        setState(() => _emailOrMobileError = 'Please enter your email address');
        return false;
      }
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.(com|net|org|edu|gov|io|in|co\.in|uk|us|info|biz)$',
      );
      if (!emailRegex.hasMatch(email)) {
        setState(
          () => _emailOrMobileError = 'Please enter a valid email address',
        );
        return false;
      }
    }

    if (_isLoginMode) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) {
        setState(() => _emailOrMobileError = 'Please enter your password');
        return false;
      }
    }

    return true;
  }

  Future<void> _loginUser() async {
    if (!_validate()) return;

    setState(() {
      _isSendingOtp = true;
      _emailOrMobileError = '';
    });

    try {
      final loginValue = _isMobileSelected
          ? _phoneController.text.trim()
          : _emailController.text.trim();

      await ApiService().loginUser(
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
      if (mounted) {
        setState(() => _emailOrMobileError = 'Login failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _emailSendOtp() async {
    if (!_validate()) return;

    setState(() {
      _isSendingOtp = true;
      _emailOrMobileError = '';
    });

    try {
      final result = await ApiService().sendEmailOtp(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      if (result['status'] == 'success') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              isMobile: false,
              maskedContact: _maskEmail(_emailController.text.trim()),
              email: _emailController.text.trim(),
            ),
          ),
        );
      } else {
        setState(() {
          _isLoginMode = true;
          _emailOrMobileError = result['message'] ?? 'Failed to send OTP';
        });
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final isClientError = statusCode != null && statusCode >= 400 && statusCode < 500;
      setState(() {
        if (isClientError) {
          _isLoginMode = true;
        }
        _emailOrMobileError = ApiService().handleDioError(e, defaultMessage: 'Failed to send OTP');
      });
    } catch (e) {
      setState(() => _emailOrMobileError = 'Connection error: ${e.toString()}');
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _mobileSendOtp() async {
    if (!_validate()) return;

    setState(() {
      _isSendingOtp = true;
      _emailOrMobileError = '';
    });

    try {
      final result = await ApiService().sendMobileOtp(
        phoneNumber: _phoneController.text.trim(),
        countryCode: _selectedCountry.dialCode,
      );

      if (!mounted) return;

      if (result['status'] == 'success') {
        final phone = _phoneController.text.trim();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              isMobile: true,
              maskedContact:
                  '${_selectedCountry.dialCode} '
                  '${'*' * (phone.length - 3)}'
                  '${phone.substring(phone.length - 3)}',
              phoneNumber: result['data']['phone_number'],
              countryCode: result['data']['country_code'],
            ),
          ),
        );
      } else {
        setState(() {
          _isLoginMode = true;
          _emailOrMobileError = result['message'] ?? 'Failed to send OTP';
        });
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final isClientError = statusCode != null && statusCode >= 400 && statusCode < 500;
      setState(() {
        if (isClientError) {
          _isLoginMode = true;
        }
        _emailOrMobileError = ApiService().handleDioError(e, defaultMessage: 'Failed to send OTP');
      });
    } catch (e) {
      setState(() => _emailOrMobileError = 'Connection error: ${e.toString()}');
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) {
          if (_emailOrMobileError.isNotEmpty) {
            setState(() => _emailOrMobileError = '');
          }
          if (_isLoginMode) {
            setState(() {
              _isLoginMode = false;
              _passwordController.clear();
            });
          }
        },
        cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        cursorWidth: 1.5,
        style: AppTextStyles.subText.copyWith(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            color: isDarkMode
                ? const Color(0XFFB3B3B3)
                : const Color(0XFF898989),
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              width: 0.7,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        onChanged: (_) {
          if (_emailOrMobileError.isNotEmpty) {
            setState(() => _emailOrMobileError = '');
          }
        },
        cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        cursorWidth: 1.5,
        style: AppTextStyles.subText.copyWith(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Enter password',
         hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
           color: isDarkMode
                ? const Color(0XFFB3B3B3)
                : const Color(0XFF898989),
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
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF8E8E8E),
              size: 22,
            ),
          ),
           enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              width: 0.7,
            ),
          ),
         
        ),
      ),
    );
  }

  Widget _buildErrorText() {
    if (_emailOrMobileError.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        _emailOrMobileError,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerBottomSheet(
        selectedCountry: _selectedCountry,
        onCountrySelected: (country) {
          setState(() => _selectedCountry = country);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildCountryCodeButton() {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDarkMode
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              _selectedCountry.dialCode,
               style: AppTextStyles.subText.copyWith(
                fontSize: 14.5,
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF8A8A8A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Email Login Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isMobileSelected = false;
                _isLoginMode = false;
                _emailOrMobileError = '';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isMobileSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Email',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: !_isMobileSelected
                        ? Colors.white
                        : const Color(0xFFB3B3B3),
                  ),
                ),
              ),
            ),
          ),
          // Mobile Login Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isMobileSelected = true;
                _isLoginMode = false;
                _emailOrMobileError = '';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isMobileSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mobile',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: _isMobileSelected
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

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _isSendingOtp
            ? null
            : () {
                if (_isLoginMode) {
                  _loginUser();
                } else {
                  if (_isMobileSelected) {
                    _mobileSendOtp();
                  } else {
                    _emailSendOtp();
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSendingOtp
            ? Loader(color: Colors.white)
            : Text(
                _isLoginMode ? 'Login' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final txt = AppTextColors.of(context);
    return Text(
      label,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: txt.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Text(
                _isMobileSelected
                    ? 'Sign up with mobile number'
                    : 'Sign up with Email',
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              _buildTabSwitcher(),
              const SizedBox(height: 30),

              if (_isMobileSelected) ...[
                _buildFieldLabel('Mobile Number'),

                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCountryCodeButton(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _phoneController,
                        hint: 'Enter your phone number',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                if (!_isLoginMode) _buildErrorText(),
              ] else ...[
                _buildFieldLabel('Email Address'),

                const SizedBox(height: 10),
                _buildTextField(
                  controller: _emailController,
                  hint: 'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                ),
                if (!_isLoginMode) _buildErrorText(),
              ],

              if (_isLoginMode) ...[
                const SizedBox(height: 20),
                _buildFieldLabel('Password'),
                const SizedBox(height: 10),
                _buildPasswordField(),
                _buildErrorText(),
              ],
              const SizedBox(height: 30),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
