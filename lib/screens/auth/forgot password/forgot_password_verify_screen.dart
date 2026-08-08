// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/loader.dart';
import 'create_new_password_screen.dart';

class ForgotPasswordVerifyScreen extends StatefulWidget {
  final String maskedContact;
  final bool isMobile;
  final String? email;
  final String? phoneNumber;
  final String? countryCode;
  final String? verificationId;
  final int? resendToken;

  const ForgotPasswordVerifyScreen({
    super.key,
    required this.maskedContact,
    required this.isMobile,
    this.email,
    this.phoneNumber,
    this.countryCode,
    this.verificationId,
    this.resendToken,
  });

  @override
  State<ForgotPasswordVerifyScreen> createState() =>
      _ForgotPasswordVerifyScreenState();
}

class _ForgotPasswordVerifyScreenState
    extends State<ForgotPasswordVerifyScreen> {
  String? _verificationId;
  int? _resendToken;

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _otpError = '';
  bool _isVerifying = false;
  bool _isResending = false;

  // ── Timer ────────────────────────────────────────────────────────────────────
  Timer? _resendTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    // Email → 2 min, Mobile → 10 min (same as OtpVerifyScreen)
    _secondsRemaining = widget.isMobile
        ? (widget.verificationId != null ? 60 : 600)
        : 120;
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

  // ── Verify OTP ───────────────────────────────────────────────────────────────
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
      final String resCountryCode = widget.countryCode ?? '';
      final String identifier = widget.isMobile
          ? (widget.phoneNumber!.startsWith('+')
              ? widget.phoneNumber!
              : '$resCountryCode${widget.phoneNumber!}')
          : widget.email!;
      final Map<String, dynamic> result;

      if (widget.isMobile && _verificationId != null) {
        debugPrint(
          'Signing in to Firebase with verification ID: $_verificationId and SMS code: $otp',
        );
        final AuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        final UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);
        debugPrint('Firebase sign in success: ${userCredential.user?.uid}');
        final String? idToken = await userCredential.user?.getIdToken();
        debugPrint(
          'Firebase ID token fetched: ${idToken != null ? "Success" : "Failed"}',
        );
        if (idToken == null) {
          throw Exception('Failed to retrieve Firebase ID token');
        }
        result = await ApiService().forgotPasswordVerifyOtp(
          identifier: identifier,
          idToken: idToken,
          otp: otp,
        );
      } else {
        result = await ApiService().forgotPasswordVerifyOtp(
          identifier: identifier,
          otp: otp,
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        _resendTimer?.cancel();
        final resetToken = result['reset_token'] as String;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreateNewPasswordScreen(resetToken: resetToken),
          ),
        );
      } else {
        setState(() => _otpError = result['message'] ?? 'Invalid OTP');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid verification code. Please check and try again.';
          break;
        case 'session-expired':
          errorMessage = 'Verification code has expired. Please request a new one.';
          break;
        case 'invalid-phone-number':
          errorMessage = 'Invalid phone number. Please check and try again.';
          break;
        default:
          errorMessage = e.message ?? 'Firebase verification failed';
      }
      if (mounted) {
        setState(() => _otpError = errorMessage);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final errors = data is Map ? data['errors'] : null;
      final msg = (errors is String && errors.isNotEmpty)
          ? errors
          : (data is Map ? data['message'] : e.message) ?? 'Invalid OTP';
      setState(() => _otpError = msg);
    } catch (e) {
      if (mounted) {
        setState(
          () => _otpError = e.toString().contains('Exception:')
              ? e.toString().replaceAll('Exception:', '').trim()
              : 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────────────────
  Future<void> _onResendOtp() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
      _otpError = '';
    });

    bool startedFirebase = false;

    try {
      final identifier = widget.isMobile ? widget.phoneNumber! : widget.email!;

      if (widget.isMobile) {
        final String resCountryCode = widget.countryCode ?? '';
        final String fullPhoneNumber = '$resCountryCode$identifier';

        if (_resendToken != null) {
          debugPrint(
            '📱 Resending via Firebase forceResendingToken: $_resendToken',
          );
          startedFirebase = true;
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: fullPhoneNumber,
            forceResendingToken: _resendToken,
            verificationCompleted: (PhoneAuthCredential credential) {
              debugPrint('📱 verificationCompleted');
            },
            verificationFailed: (FirebaseAuthException e) {
              debugPrint('📱 verificationFailed: ${e.code} - ${e.message}');
              if (!mounted) return;
              String errorMessage;
              switch (e.code) {
                case 'invalid-phone-number':
                  errorMessage =
                      'Invalid phone number. Please check and try again.';
                  break;
                case 'too-many-requests':
                  errorMessage =
                      'Too many attempts. Please try again later.';
                  break;
                case 'network-request-failed':
                  errorMessage =
                      'Network error. Please check your connection.';
                  break;
                case 'quota-exceeded':
                  errorMessage =
                      'SMS quota exceeded. Please try again later.';
                  break;
                case 'app-not-authorized':
                  errorMessage =
                      'App not authorized for Firebase Authentication.';
                  break;
                default:
                  errorMessage =
                      e.message ?? 'Failed to resend OTP. Try again.';
              }
              setState(() {
                _isResending = false;
                _otpError = errorMessage;
              });
            },
            codeSent: (String verificationId, int? resendToken) {
              debugPrint('📱 codeSent: id=$verificationId, token=$resendToken');
              if (mounted) {
                for (final c in _otpControllers) {
                  c.clear();
                }
                _focusNodes[0].requestFocus();
                setState(() {
                  _isResending = false;
                  _verificationId = verificationId;
                  _resendToken = resendToken;
                  _secondsRemaining = 60;
                });
                _startTimer();
              }
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              debugPrint('📱 codeAutoRetrievalTimeout: $verificationId');
              if (mounted && _isResending) {
                setState(() => _isResending = false);
              }
            },
          );
          return;
        }
      }

      final result = await ApiService().forgotPasswordSendOtp(
        identifier: identifier,
      );

      if (!mounted) return;

      final success = result['success'] == true;
      if (success) {
        final data = result['data'] ?? {};
        final String resMessage = (result['message'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final bool requiresFirebase =
            data['requires_firebase'] == true ||
            resMessage.contains('firebase') ||
            resMessage.contains('use firebase client sdk to send otp');

        if (widget.isMobile && requiresFirebase) {
          startedFirebase = true;
          String resPhone = (data['phone_number'] ?? identifier)
              .toString()
              .trim();
          final String resCountryCode =
              (data['country_code'] ?? widget.countryCode ?? '').toString();

          final dialCodeDigits = resCountryCode.replaceAll('+', '');
          if (resPhone.startsWith(dialCodeDigits)) {
            resPhone = resPhone.substring(dialCodeDigits.length);
          } else if (resPhone.startsWith(resCountryCode)) {
            resPhone = resPhone.substring(resCountryCode.length);
          }
          final String fullPhone = '$resCountryCode$resPhone';

          debugPrint('📱 First resend via Firebase for $fullPhone');
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: fullPhone,
            forceResendingToken: null,
            verificationCompleted: (PhoneAuthCredential credential) {},
            verificationFailed: (FirebaseAuthException e) {
              debugPrint('📱 verificationFailed: ${e.code} - ${e.message}');
              if (!mounted) return;
              String errorMessage;
              switch (e.code) {
                case 'invalid-phone-number':
                  errorMessage =
                      'Invalid phone number. Please check and try again.';
                  break;
                case 'too-many-requests':
                  errorMessage =
                      'Too many attempts. Please try again later.';
                  break;
                case 'network-request-failed':
                  errorMessage =
                      'Network error. Please check your connection.';
                  break;
                case 'quota-exceeded':
                  errorMessage =
                      'SMS quota exceeded. Please try again later.';
                  break;
                case 'app-not-authorized':
                  errorMessage =
                      'App not authorized for Firebase Authentication.';
                  break;
                default:
                  errorMessage =
                      e.message ?? 'Failed to resend OTP. Try again.';
              }
              setState(() {
                _isResending = false;
                _otpError = errorMessage;
              });
            },
            codeSent: (String verificationId, int? resendToken) {
              debugPrint('📱 codeSent: id=$verificationId, token=$resendToken');
              if (mounted) {
                for (final c in _otpControllers) {
                  c.clear();
                }
                _focusNodes[0].requestFocus();
                setState(() {
                  _isResending = false;
                  _verificationId = verificationId;
                  _resendToken = resendToken;
                  _secondsRemaining = 60;
                });
                _startTimer();
              }
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              debugPrint('📱 codeAutoRetrievalTimeout: $verificationId');
              if (mounted && _isResending) {
                setState(() => _isResending = false);
              }
            },
          );
        } else {
          for (final c in _otpControllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
          setState(() {
            _otpError = '';
            _secondsRemaining = widget.isMobile ? 600 : 120;
          });
          _startTimer();
        }
      } else {
        setState(() => _otpError = result['message'] ?? 'Failed to resend OTP');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => _otpError =
              e.response?.data?['message'] ?? 'Failed to resend OTP',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _otpError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (!startedFirebase && mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  // ── Resend widget ─────────────────────────────────────────────────────────────
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
              onTap: _isResending ? null : _onResendOtp,
              child: _isResending
                  ? Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: Loader(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
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

  // ── OTP box ───────────────────────────────────────────────────────────────────
  Widget _buildOTPBox(int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 55,
      height: 65,
      child: TextField(
        controller: _otpControllers[index],
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
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
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
                  : Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Text(
                widget.isMobile ? 'Verify your number' : 'Verify your email',
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
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

              // ── OTP boxes ───────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, _buildOTPBox),
              ),
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

              const SizedBox(height: 28),

              // ── Verify button ───────────────────────────────────────────────
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

              const SizedBox(height: 20),

              // ── Timer / Resend ──────────────────────────────────────────────
              Center(
                child: widget.isMobile
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
}
