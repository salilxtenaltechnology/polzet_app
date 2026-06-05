 // ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';

import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/loader.dart';
import '../signup/registration_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String maskedContact;
  final bool isMobile;
  final String? email;
  final String? phoneNumber;
  final String? countryCode;

  const OtpVerifyScreen({
    super.key,
    required this.isMobile,
    required this.maskedContact,
    this.email,
    this.phoneNumber,
    this.countryCode,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> with UtilityMixin {
  bool _isResending = false;
  static const int _otpLength = 6;
  Timer? _resendTimer;
  int _secondsRemaining = 0;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  String _otpError = '';
  bool _isVerifying = false;

  String get _otp => _controllers.map((c) => c.text).join();

  // ── OTP box ──────────────────────────────────────────────────────────────────
  Widget _buildOtpBox(int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 55,
      height: 65,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        cursorWidth: 1.5,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onBackground,
        ),
        onChanged: (value) {
          if (_otpError.isNotEmpty) setState(() => _otpError = '');

          if (value.isNotEmpty && index < _otpLength - 1) {
            _focusNodes[index + 1].requestFocus();
          }
          setState(() {});
        },
        onTap: () {
          _controllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _controllers[index].text.length),
          );
        },
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide(
              color: _otpError.isNotEmpty
                  ? Theme.of(context).colorScheme.error
                  : _controllers[index].text.isNotEmpty
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                  : (isDarkMode ? Theme.of(context).colorScheme.outline :  const Color(0xFFDDDDDD)),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _otpError.isNotEmpty
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      final Map<String, dynamic> result;

      if (widget.isMobile) {
        result = await ApiService().sendMobileOtp(
          phoneNumber: widget.phoneNumber!,
          countryCode: widget.countryCode!,
        );
      } else {
        result = await ApiService().sendEmailOtp(email: widget.email!);
      }

      if (!mounted) return;

      if (result['status'] == 'success') {
        _secondsRemaining = widget.isMobile ? 600 : 120;
        _startTimer();
      } else {
        setState(() => _otpError = result['message'] ?? 'Failed to resend OTP');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response?.data['message']
          : e.message;
      setState(() => _otpError = msg ?? 'Failed to resend OTP');
    } catch (e) {
      setState(() => _otpError = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _isResending = false);
    }
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
                  ? const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      ),
                    )
                  : Text(
                      'Resend OTP',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13.2,
                        color: _isResending
                            ? const Color(0xFFB3B3B3)
                            : Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Backspace handling ───────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _otpLength; i++) {
      final idx = i;
      _focusNodes[idx].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[idx].text.isEmpty &&
            idx > 0) {
          _focusNodes[idx - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
    if (!widget.isMobile) {
      _secondsRemaining = 120;
    } else {
      _secondsRemaining = 600;
    }
    _startTimer();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── Verify ───────────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otp.length < _otpLength) {
      setState(() => _otpError = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _otpError = '';
    });

    try {
      final Map<String, dynamic> result;

      if (widget.isMobile) {
        result = await ApiService().verifyMobileOtp(
          phoneNumber: widget.phoneNumber!,
          countryCode: widget.countryCode!,
          otp: _otp,
        );
      } else {
        result = await ApiService().verifyEmailOtp(
          email: widget.email!,
          otp: _otp,
        );
      }

      if (!mounted) return;

      if (result['status'] == 'success') {
        _resendTimer?.cancel();

        if (widget.isMobile) {
          // Mobile: data is empty {}, just redirect on success status
          navigationPush(
            context,
            RegistrationScreen(
              verifiedEmail: null,
              verifiedPhone: widget.phoneNumber,
              verifiedCountryCode: widget.countryCode,
            ),
          );
        } else {
          // Email: check data > verified == true
          final data = result['data'];
          final isVerified = data is Map && data['verified'] == true;

          if (isVerified) {
            navigationPush(
              context,
              RegistrationScreen(
                verifiedEmail: widget.email,
                verifiedPhone: null,
                verifiedCountryCode: null,
              ),
            );
          } else {
            setState(
              () => _otpError = 'Email verification failed. Please try again.',
            );
          }
        }
      } else {
        final errors = result['errors'];
        final errorMsg = (errors is String && errors.isNotEmpty)
            ? errors
            : result['message'] ?? 'Invalid OTP';
        setState(() => _otpError = errorMsg);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final errors = data is Map ? data['errors'] : null;
      final msg = (errors is String && errors.isNotEmpty)
          ? errors
          : (data is Map ? data['message'] : e.message) ?? 'Invalid OTP';
      setState(() => _otpError = msg);
    } catch (e) {
      setState(() => _otpError = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
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
                widget.isMobile ? 'Verify your number' : 'Verify your email',
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // ── Sub text ──────────────────────────────────────────────────────
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
                      text: widget.maskedContact,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.5,
                        color: txt.body,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // ── OTP boxes ─────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_otpLength, (i) => _buildOtpBox(i)),
              ),

              // ── Error ─────────────────────────────────────────────────────────
              if (_otpError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _otpError,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // ── Verify button ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
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
              const SizedBox(height: 20),

              // ── Resend ────────────────────────────────────────────────────────
              Center(
                child: widget.isMobile
                    // ── Mobile: countdown, resend when expired ────────────────────────
                    ? _secondsRemaining > 0
                          ? RichText(
                              text: TextSpan(
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.5,
                                  color: const Color(0xFF8A8A8A),
                                ),
                                children: [
                                  const TextSpan(text: 'OTP will expire in '),
                                  TextSpan(
                                    text: _formattedTime,
                                    style: AppTextStyles.subText.copyWith(
                                      fontSize: 14.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildResendWidget()
                    // ── Email: countdown → resend ─────────────────────────────────────
                    : _secondsRemaining > 0
                    ? RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.5,
                            color: const Color(0xFF8A8A8A),
                          ),
                          children: [
                            const TextSpan(text: 'Resend code in '),
                            TextSpan(
                              text: _formattedTime,
                              style: AppTextStyles.subText.copyWith(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
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

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
