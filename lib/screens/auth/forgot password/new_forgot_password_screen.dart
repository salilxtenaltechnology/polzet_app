import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';

import '../../../api/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
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
        setState(() => _emailOrMobileError = AppLocalizations.of(context)!.pleaseenteryourphonenumber);
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
        setState(() => _emailOrMobileError = AppLocalizations.of(context)!.pleaseenteryouremail);
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
      final result = await ApiService()
          .forgotPasswordSendOtp(
            identifier: _emailController.text.trim(),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => {
              'success': false,
              'message': 'Request timed out. Please try again.',
            },
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

    setState(() {
      _isSendingOtp = true;
      _emailOrMobileError = '';
    });

    try {
      // ─── 1. Clean phone number ───────────────────────────────────────
      final String cleanPhone = _phoneController.text
          .trim()
          .replaceAll(RegExp(r'[\s\-().+]'), '');

      final String countryCode = _selectedCountry.dialCode;
      final String fullPhoneNumber = '$countryCode$cleanPhone';

      debugPrint('📱 Sending Forgot Password OTP to: $fullPhoneNumber');

      // ─── 2. Call backend to send OTP ─────────────────────────────────
      final result = await ApiService()
          .forgotPasswordSendOtp(
            identifier: fullPhoneNumber,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => {
              'success': false,
              'message': 'Request timed out. Please try again.',
            },
          );

      if (!mounted) return;

      final bool success =
          result['success'] == true || result['status'] == 'success';

      if (!success) {
        setState(() {
          _emailOrMobileError = result['message'] ?? 'Failed to send OTP';
        });
        return;
      }

      // ─── 3. Parse backend response ───────────────────────────────────
      final Map<String, dynamic> data = result['data'] ?? {};

      // Resolve phone from response or fallback to user input
      String resPhone = (data['phone_number'] ?? cleanPhone).toString().trim();
      final String resCountryCode =
          (data['country_code'] ?? countryCode).toString();

      // Strip country code prefix if already included in phone
      final String dialCodeDigits = resCountryCode.replaceAll('+', '');
      if (resPhone.startsWith(dialCodeDigits)) {
        resPhone = resPhone.substring(dialCodeDigits.length);
      } else if (resPhone.startsWith(resCountryCode)) {
        resPhone = resPhone.substring(resCountryCode.length);
      }

      final String resolvedMasked =
          '$resCountryCode '
          '${'*' * (resPhone.length - 3)}'
          '${resPhone.substring(resPhone.length - 3)}';

      navigationPushReplacement(
        context,
        ForgotPasswordVerifyScreen(
          isMobile: true,
          maskedContact: resolvedMasked,
          phoneNumber: resPhone,
          countryCode: resCountryCode,
        ),
      );
    } on DioException catch (e) {
      setState(() {
        _emailOrMobileError = ApiService().handleDioError(
          e,
          defaultMessage: 'Failed to send OTP',
        );
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _emailOrMobileError = 'Connection error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
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
                  AppLocalizations.of(context)!.email,
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
              AppLocalizations.of(context)!.mobile,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline
                : const Color(0xFFDDDDDD),
            width: 1,
          ),
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
                color: Theme.of(context).colorScheme.onSurface,
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
        },
        cursorColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
        cursorWidth: 1.5,
        style: AppTextStyles.subText.copyWith(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              width: 0.7,
            ),
          ),
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
            :  Text(
                AppLocalizations.of(context)!.continueButton,
                style: const TextStyle(
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
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Text(
                AppLocalizations.of(context)!.forgotpassword,
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                 AppLocalizations.of(context)!.enteryouremailormobilenumbertoreceiveaverificationcode,
        
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5,
                  color: txt.body,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              _buildTabSwitcher(),
              const SizedBox(height: 30),
              if (_isMobileSelected) ...[
                _buildFieldLabel(AppLocalizations.of(context)!.phonenumber),

                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCountryCodeButton(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _phoneController,
                        hint: AppLocalizations.of(context)!.enteryourphonenumber,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                _buildErrorText(),
              ] else ...[
                _buildFieldLabel(AppLocalizations.of(context)!.email),

                const SizedBox(height: 10),
                _buildTextField(
                  controller: _emailController,
                  hint: AppLocalizations.of(context)!.enteryouremail,
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
