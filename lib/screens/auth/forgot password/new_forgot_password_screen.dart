// ignore_for_file: prefer_const_constructors, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';

import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../models/country/country_model.dart';
import '../../../widgets/country_code/code_bottomsheet.dart';
import '../../../widgets/loader.dart';
import 'forgot_password_verify_screen.dart';

class NewForgotPasswordScreen extends StatefulWidget {
  const NewForgotPasswordScreen({super.key});

  @override
  State<NewForgotPasswordScreen> createState() =>
      _NewForgotPasswordSceenState();
}

class _NewForgotPasswordSceenState extends State<NewForgotPasswordScreen>
    with UtilityMixin {
  bool _isMobileSelected = false;
  bool _isSendingOtp = false;
  String _emailOrMobileError = '';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  Country _selectedCountry = Country(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
  );

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
      final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        setState(
          () => _emailOrMobileError = 'Please enter a valid email address',
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _emailSendOtp() async {
    if (_isSendingOtp || !_validate()) return;
    setState(() => _isSendingOtp = true);

    try {
      final result = await ApiService().forgotPasswordSendOtp(
        identifier: _emailController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        navigationPushReplacement(
          context,
          ForgotPasswordVerifyScreen(
            isMobile: false,
            maskedContact: _maskEmail(_emailController.text.trim()),
            email: _emailController.text.trim(),
          ),
        );
      } else {
        setState(
          () => _emailOrMobileError = result['message'] ?? 'Failed to send OTP',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _emailOrMobileError = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _mobileSendOtp() async {
    if (_isSendingOtp || !_validate()) return;
    setState(() => _isSendingOtp = true);

    try {
      final phone = _phoneController.text.trim();

      final result = await ApiService().forgotPasswordSendOtp(
        identifier: phone,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        navigationPushReplacement(
          context,
          ForgotPasswordVerifyScreen(
            isMobile: true,
            maskedContact:
                '${_selectedCountry.dialCode} '
                '${'*' * (phone.length - 3)}'
                '${phone.substring(phone.length - 3)}',
            phoneNumber: phone,
            countryCode: _selectedCountry.dialCode,
          ),
        );
      } else {
        setState(
          () => _emailOrMobileError = result['message'] ?? 'Failed to send OTP',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _emailOrMobileError = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '${name[0]}***@$domain';
    return '${name.substring(0, 3)}${'*' * (name.length - 3)}@$domain';
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
                _isMobileSelected = false;
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

  Widget _buildCountryCodeButton() {
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              _selectedCountry.dialCode,
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF404040),
                fontWeight: FontWeight.w500,
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
        onChanged: (_) {
          if (_emailOrMobileError.isNotEmpty) {
            setState(() => _emailOrMobileError = '');
          }
        },
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

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: () {
          if (_isMobileSelected) {
            _mobileSendOtp();
          } else {
            _emailSendOtp();
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
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
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
        style: AppTextStyles.bodyText.copyWith(fontSize: 12, color: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Text(
                'Forgot password?',
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your email or mobile number to receive a verification code',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5,
                  color: const Color(0xFF595959),
                  height: 1.4,
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
                _buildErrorText(),
              ] else ...[
                _buildFieldLabel('Email Address'),

                const SizedBox(height: 10),
                _buildTextField(
                  controller: _emailController,
                  hint: 'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                ),
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
}
