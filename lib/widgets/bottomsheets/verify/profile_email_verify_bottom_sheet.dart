// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../loader.dart';

class ProfileEmailVerifyBottomSheet extends StatefulWidget {
  final String email;
  const ProfileEmailVerifyBottomSheet({super.key, required this.email});

  @override
  State<ProfileEmailVerifyBottomSheet> createState() =>
      _ProfileEmailVerifyBottomSheetState();
}

class _ProfileEmailVerifyBottomSheetState
    extends State<ProfileEmailVerifyBottomSheet> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _otpError = '';
  bool _isVerifying = false;

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  void _onVerify() async {
    if (_isVerifying) return;
    final otp = _otpValue;

    if (otp.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _otpError = '';
      _isVerifying = true;
    });

    try {
      final result = await ApiService().confirmEmailChangeOtp(
        email: widget.email,
        otp: otp,
      );

      if (!mounted) return;

      if (result['status'] == 'success' || result['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _otpError = result['data']?['message'] ?? result['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _otpError = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Widget _buildOTPBox(int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 48.w,
      height: 56.h,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: Theme.of(context).colorScheme.primary,
        cursorWidth: 1.5,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onBackground,
        ),
        onChanged: (val) {
          setState(() => _otpError = '');
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide(
              color: _otpError.isNotEmpty
                  ? Theme.of(context).colorScheme.error
                  : _otpControllers[index].text.isNotEmpty
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                      : (isDarkMode
                          ? Theme.of(context).colorScheme.outline
                          : const Color(0xFFDDDDDD)),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _otpError.isNotEmpty
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 10.h),
              height: 4.h,
              width: 40.w,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'Verify Email',
                  style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: txt.body,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Enter the 6-digit code sent to '),
                        TextSpan(
                          text: widget.email,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            color: txt.title,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _buildOTPBox),
                  ),
                  if (_otpError.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      _otpError,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  SizedBox(height: 28.h),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _onVerify,
                      style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                      child: _isVerifying
                          ? Loader(color: Colors.white)
                          : const Text(
                              'OTP Verify',
                               style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
