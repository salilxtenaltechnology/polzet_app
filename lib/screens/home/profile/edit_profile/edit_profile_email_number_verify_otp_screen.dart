// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';

import '../../../../api/api_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/phone_verify_logger.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';

class EditProfilEmailNumberVeifyOTP extends StatefulWidget {
  final String? countryCode;
  final String? mobileNumber;
  final String? verificationId;
  final int? resendToken;
  final String? initialAttemptId;
  final String? email;
  final bool isEmail;

  const EditProfilEmailNumberVeifyOTP({
    super.key,
    this.countryCode,
    this.mobileNumber,
    this.verificationId,
    this.resendToken,
    this.initialAttemptId,
    this.email,
    this.isEmail = false,
  });

  @override
  State<EditProfilEmailNumberVeifyOTP> createState() =>
      _EditProfilEmailNumberVeifyOTPState();
}

// Alias for flexibility in naming conventions
typedef EditProfileNumberVerifyOTPScreen = EditProfilEmailNumberVeifyOTP;

class _EditProfilEmailNumberVeifyOTPState extends State<EditProfilEmailNumberVeifyOTP> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _otpError = '';
  bool _isVerifying = false;
  bool _isConfirmed = false;
  bool _isResending = false;
  String _currentAttemptId = '';

  Timer? _resendTimer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _currentAttemptId = widget.initialAttemptId ??
        PhoneVerifyLogger.generateAttemptId(
            widget.isEmail ? 'email_otp_screen' : 'otp_screen');

    if (!widget.isEmail) {
      PhoneVerifyLogger.log(
        attemptId: _currentAttemptId,
        caller: 'EditProfilEmailNumberVeifyOTP.initState',
        event: 'SCREEN_INITIALIZED',
        phone: '${widget.countryCode ?? ''}${widget.mobileNumber ?? ''}',
      );
    }

    _startTimer();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
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
    if (_isVerifying || _isConfirmed) {
      PhoneVerifyLogger.log(
        attemptId: _currentAttemptId,
        caller: 'EditProfilNumberVeifyOTP._onVerify',
        event: 'BLOCKED_DUPLICATE_CALL',
        details: 'isVerifying=$_isVerifying, isConfirmed=$_isConfirmed',
      );
      return;
    }

    final otp = _otpValue.trim();

    if (otp.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _otpError = '';
      _isVerifying = true;
    });

    if (widget.isEmail) {
      try {
        final result = await ApiService().confirmEmailChangeOtp(
          email: widget.email ?? '',
          otp: otp,
        );

        if (!mounted) return;

        final isSuccess = result['status'] == 'success' ||
            result['success'] == true ||
            (result['data'] != null && result['status'] != 'error');

        if (isSuccess) {
          _isConfirmed = true;
          _resendTimer?.cancel();
          Navigator.of(context).pop(true);
        } else {
          final msg = result['message']?.toString() ??
              result['data']?['message']?.toString() ??
              result['error']?.toString() ??
              'Invalid OTP';
          setState(() {
            _isVerifying = false;
            _otpError = msg;
          });
        }
      } catch (e) {
        if (mounted) {
          final msg = e.toString().contains('Exception:')
              ? e.toString().replaceAll('Exception:', '').trim()
              : e.toString();
          setState(() {
            _isVerifying = false;
            _otpError = msg;
          });
        }
      }
      return;
    }

    final fullPhoneNumber = '${widget.countryCode}${widget.mobileNumber}';

    try {
      PhoneVerifyLogger.log(
        attemptId: _currentAttemptId,
        caller: 'EditProfilNumberVeifyOTP._onVerify',
        event: 'BACKEND_CONFIRM_START',
        phone: fullPhoneNumber,
      );

      final result = await ApiService().phoneVerifyConfirm(
        countryCode: widget.countryCode ?? '',
        mobileNumber: widget.mobileNumber ?? '',
        otp: otp,
      );

      PhoneVerifyLogger.log(
        attemptId: _currentAttemptId,
        caller: 'EditProfilNumberVeifyOTP._onVerify',
        event: 'BACKEND_CONFIRM_RESULT',
        details: 'status=${result['status']}, success=${result['success']}',
      );

      if (!mounted) return;

      final isSuccess = result['status'] == 'success' ||
          result['success'] == true ||
          (result['data'] != null && result['status'] != 'error');

      if (isSuccess) {
        _isConfirmed = true;
        _resendTimer?.cancel();
        Navigator.of(context).pop(true);
      } else {
        final msg = result['message']?.toString() ??
            result['data']?['message']?.toString() ??
            result['error']?.toString() ??
            'OTP verification failed';
        if (msg.contains('expired') || msg.contains('resend')) {
          _resendTimer?.cancel();
          _secondsRemaining = 0;
        }
        setState(() {
          _isVerifying = false;
          _otpError = msg;
        });
      }
    } catch (e) {
      PhoneVerifyLogger.log(
        attemptId: _currentAttemptId,
        caller: 'EditProfilNumberVeifyOTP._onVerify',
        event: 'BACKEND_CONFIRM_ERROR',
        details: e.toString(),
      );

      if (mounted) {
        final msg = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : e.toString();
        if (msg.contains('expired') || msg.contains('resend')) {
          _resendTimer?.cancel();
          _secondsRemaining = 0;
        }
        setState(() {
          _isVerifying = false;
          _otpError = msg;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _isVerifying || _isConfirmed || _secondsRemaining > 0) {
      PhoneVerifyLogger.log(
        attemptId: _currentAttemptId,
        caller: 'EditProfilNumberVeifyOTP._resendOtp',
        event: 'BLOCKED_RESEND_CALL',
        details:
            'isResending=$_isResending, isVerifying=$_isVerifying, isConfirmed=$_isConfirmed, remaining=$_secondsRemaining',
      );
      return;
    }

    final newAttemptId = PhoneVerifyLogger.generateAttemptId('resend');
    _currentAttemptId = newAttemptId;

    setState(() {
      _isResending = true;
      _otpError = '';
    });

    if (widget.isEmail) {
      try {
        final result = await ApiService().requestEmailChangeOtp(
          email: widget.email ?? '',
        );

        if (!mounted) return;

        final isSuccess = result['status'] == 'success' ||
            result['success'] == true;

        if (isSuccess) {
          for (final c in _otpControllers) {
            c.clear();
          }
          if (_focusNodes.isNotEmpty) {
            _focusNodes[0].requestFocus();
          }
          setState(() {
            _isResending = false;
            _secondsRemaining = 60;
          });
          _startTimer();
          showToast(message: 'OTP resent');
        } else {
          final msg = result['message']?.toString() ?? 'Failed to resend OTP';
          setState(() {
            _isResending = false;
            _otpError = msg;
          });
        }
      } catch (e) {
        if (mounted) {
          final msg = e.toString().contains('Exception:')
              ? e.toString().replaceAll('Exception:', '').trim()
              : 'Failed to resend OTP. Please try again.';
          setState(() {
            _isResending = false;
            _otpError = msg;
          });
        }
      }
      return;
    }

    final fullPhoneNumber = '${widget.countryCode}${widget.mobileNumber}';

    PhoneVerifyLogger.log(
      attemptId: newAttemptId,
      caller: 'EditProfilNumberVeifyOTP._resendOtp',
      event: 'RESEND_TAP_ACCEPTED',
      phone: fullPhoneNumber,
    );

    try {
      PhoneVerifyLogger.log(
        attemptId: newAttemptId,
        caller: 'EditProfilNumberVeifyOTP._resendOtp',
        event: 'BACKEND_REQUEST_START',
        phone: fullPhoneNumber,
      );

      final result = await ApiService().phoneVerifyRequest(
        countryCode: widget.countryCode ?? '',
        mobileNumber: widget.mobileNumber ?? '',
      );

      PhoneVerifyLogger.log(
        attemptId: newAttemptId,
        caller: 'EditProfilNumberVeifyOTP._resendOtp',
        event: 'BACKEND_RESEND_RESULT',
        details: 'status=${result['status']}, success=${result['success']}',
      );

      if (!mounted) return;

      final isSuccess = result['status'] == 'success' ||
          result['success'] == true ||
          (result['data'] != null &&
              result['status'] != 'error' &&
              result['success'] != false);

      if (isSuccess) {
        for (final c in _otpControllers) {
          c.clear();
        }
        if (_focusNodes.isNotEmpty) {
          _focusNodes[0].requestFocus();
        }
        setState(() {
          _isResending = false;
          _secondsRemaining = 60;
        });
        _startTimer();
        showToast(message: 'OTP resent');
      } else {
        final msg = result['message']?.toString() ??
            result['data']?['message']?.toString() ??
            'Failed to resend OTP';
        setState(() {
          _isResending = false;
          _otpError = msg;
          if (_secondsRemaining <= 0) {
            _secondsRemaining = 15;
          }
        });
        _startTimer();
      }
    } catch (e) {
      PhoneVerifyLogger.log(
        attemptId: newAttemptId,
        caller: 'EditProfilNumberVeifyOTP._resendOtp',
        event: 'ERROR_CAUGHT',
        details: e.toString(),
      );

      if (mounted) {
        final msg = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : 'Failed to resend OTP. Please try again.';
        setState(() {
          _isResending = false;
          _otpError = msg;
          if (_secondsRemaining <= 0) {
            _secondsRemaining = 15;
          }
        });
        _startTimer();
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
    final mobile = widget.mobileNumber ?? '';
    final code = widget.countryCode ?? '';
    final maskedPhone = mobile.length > 4
        ? '$code ${'*' * (mobile.length - 3)}${mobile.substring(mobile.length - 3)}'
        : '$code $mobile';
    final targetText = widget.isEmail ? (widget.email ?? '') : maskedPhone;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: widget.isEmail ? 'Verify Email' : 'Verify Phone Number',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
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
                      text: targetText,
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
                Text(
                  _otpError,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              SizedBox(height: 25.h),

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
                      :  Text(
                          AppLocalizations.of(context)!.verifycode,
                         style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 15.h),
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
