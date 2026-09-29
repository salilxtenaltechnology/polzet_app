// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/api_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';

class EditProfilNumberVeifyOTP extends StatefulWidget {
  final String countryCode;
  final String mobileNumber;
  final String verificationId;
  final int? resendToken;

  const EditProfilNumberVeifyOTP({
    super.key,
    required this.countryCode,
    required this.mobileNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<EditProfilNumberVeifyOTP> createState() =>
      _EditProfilNumberVeifyOTPState();
}

// Alias for flexibility in naming conventions
typedef EditProfileNumberVerifyOTPScreen = EditProfilNumberVeifyOTP;

class _EditProfilNumberVeifyOTPState extends State<EditProfilNumberVeifyOTP> {
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

  Timer? _resendTimer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _startTimer();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    _secondsRemaining = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      }
    });
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
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
      if (errorMsg == 'OTP session has expired. Please resend code.' ||
          e.code == 'session-expired') {
        _resendTimer?.cancel();
        _secondsRemaining = 0;
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
        _resendTimer?.cancel();
        Navigator.of(context).pop(true);
      } else {
        final msg = result['message']?.toString() ??
            result['data']?['message']?.toString() ??
            'OTP verification failed';
        if (msg == 'OTP session has expired. Please resend code.') {
          _resendTimer?.cancel();
          _secondsRemaining = 0;
        }
        setState(() => _otpError = msg);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : e.toString();
        if (msg == 'OTP session has expired. Please resend code.') {
          _resendTimer?.cancel();
          _secondsRemaining = 0;
        }
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
        for (final c in _otpControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isResending = false;
        });
        _startTimer();
        showToast(message: 'OTP resent successfully');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        String errorMessage;
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage = 'Invalid phone number format.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many attempts. Please try again later.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection.';
            break;
          default:
            errorMessage = e.message ?? 'Failed to resend OTP. Try again.';
        }
        setState(() {
          _isResending = false;
          _otpError = errorMessage;
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

  Widget _buildResendWidget() {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 14.5,
          color: const Color(0xFF8A8A8A),
        ),
        children: [
          const TextSpan(text: "Didn't receive code? "),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: _isResending ? null : _resendOtp,
              child: _isResending
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 14.w,
                        height: 14.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : Text(
                      'Resend Code',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13.2,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final maskedPhone = widget.mobileNumber.length > 4
        ? '${widget.countryCode} ${'*' * (widget.mobileNumber.length - 3)}${widget.mobileNumber.substring(widget.mobileNumber.length - 3)}'
        : '${widget.countryCode} ${widget.mobileNumber}';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(
        title: 'Verify Phone Number',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             
              SizedBox(height: 12.h),
              RichText(
                text: TextSpan(
                 style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.5,
                    color: txt.body,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code sent to '),
                    TextSpan(
                      text: maskedPhone,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.8,
                        color: txt.body,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),

              // ── OTP input boxes ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, _buildOTPBox),
              ),
              if (_otpError.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  _otpError,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              SizedBox(height: 30.h),

              // ── Verify Button ─────────────────────────────────────────────
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
                          'Verify Code',
                         style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 24.h),

              // ── Resend / Timer Section ────────────────────────────────────
              Center(
                child: _secondsRemaining > 0
                    ? RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14,
                            color: const Color(0xFF8A8A8A),
                          ),
                          children: [
                            const TextSpan(text: 'OTP will expire in '),
                            TextSpan(
                              text: _formattedTime,
                              style: AppTextStyles.subText.copyWith(
                                fontSize: 14.5,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildResendWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
