// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/show_toast.dart';
import '../../loader.dart';

class ProfilePhoneVerifyBottomSheet extends StatefulWidget {
  final String countryCode;
  final String mobileNumber;
  final String verificationId;
  final int? resendToken;

  const ProfilePhoneVerifyBottomSheet({
    super.key,
    required this.countryCode,
    required this.mobileNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<ProfilePhoneVerifyBottomSheet> createState() =>
      _ProfilePhoneVerifyBottomSheetState();
}

class _ProfilePhoneVerifyBottomSheetState
    extends State<ProfilePhoneVerifyBottomSheet> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _verificationId;
  int? _resendToken;
  String _otpError = '';
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

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

  Future<void> _onVerify() async {
    if (_isVerifying) return;
    final otp = _otpValue.trim();

    if (otp.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _otpError = '';
      _isVerifying = true;
    });

    String? firebaseToken;

    // 1. Authenticate with Firebase Auth using verificationId & OTP
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      firebaseToken = await userCredential.user?.getIdToken();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = 'Invalid OTP code. Please try again.';
      if (e.code == 'invalid-verification-code') {
        errorMsg = 'Invalid OTP code. Please check and try again.';
      } else if (e.code == 'session-expired') {
        errorMsg = 'OTP session has expired. Please resend code.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMsg = e.message!;
      }
      setState(() {
        _isVerifying = false;
        _otpError = errorMsg;
      });
      return;
    } catch (e) {
      debugPrint('Firebase signInWithCredential error: $e');
    }

    // 2. Pass OTP and firebaseToken to ApiService numberOtpVerify
    try {
      final result = await ApiService().numberOtpVerify(
        countryCode: widget.countryCode,
        mobileNumber: widget.mobileNumber,
        otp: otp,
        firebaseToken: firebaseToken,
      );

      if (!mounted) return;

      final isSuccess = result['status'] == 'success' ||
          result['success'] == true ||
          result['data'] != null;

      if (isSuccess) {
        Navigator.of(context).pop(true);
      } else {
        final msg = result['message']?.toString() ??
            result['data']?['message']?.toString() ??
            'OTP verification failed';
        setState(() => _otpError = msg);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : e.toString();
        setState(() => _otpError = msg);
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
      _otpError = '';
    });

    final fullPhoneNumber = '${widget.countryCode}${widget.mobileNumber}';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isResending = false;
        });
        showToast(message: 'OTP resent successfully');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isResending = false;
          _otpError = e.message ?? 'Failed to resend OTP';
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) {
          _verificationId = verificationId;
        }
      },
      verificationCompleted: (PhoneAuthCredential credential) {},
    );
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
    final maskedPhone = widget.mobileNumber.length > 4
        ? '${widget.countryCode} ${'*' * (widget.mobileNumber.length - 3)}${widget.mobileNumber.substring(widget.mobileNumber.length - 3)}'
        : '${widget.countryCode} ${widget.mobileNumber}';

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
                  'Verify Phone Number',
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
                          text: maskedPhone,
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
                    const SizedBox(height: 6),
                    Text(
                      _otpError,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _isResending
                          ? SizedBox(
                              width: 14.w,
                              height: 14.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            )
                          : GestureDetector(
                              onTap: _resendOtp,
                              child: Text(
                                'Resend Code',
                                style: AppTextStyles.subText.copyWith(
                                  fontSize: 13.sp,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ],
                  ),
                  SizedBox(height: 24.h),
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
                              'Confirm',
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
