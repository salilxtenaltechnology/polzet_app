// ignore_for_file: deprecated_member_use, unused_element, curly_braces_in_flow_control_statements, library_private_types_in_public_api
import 'dart:convert';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import '../../../../../../api/app_api.dart';
import '../../../../../../api/services/api_service.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/constants/app_strings.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../widgets/button/auth_button.dart';
import '../../../../../../widgets/custom_card.dart';
import '../../../../../../widgets/custom_text_styles.dart';
import '../../../../../../widgets/text_field/primary_textfield.dart';
import 'forget_pin_set.dart';

class EmailVerifyPin extends StatefulWidget {
 

  const EmailVerifyPin({super.key});

  @override
  _EmailVerificationScreenState createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerifyPin>
    with UtilityMixin {
  final ApiService apiService = ApiService();
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isShowButton = false;
  String _errorMessage = '';
  String _successMessage = '';

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  
  // ─── OTP Methods ──────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = '';
      _successMessage = '';
    });

    var body = {'email': _emailController.text};

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.emailVerify), // Change API for email verify
        body: body,
      );

      if (response.statusCode == 200) {
        setState(() {
          _isShowButton = true;
          _successMessage = 'OTP sent successfully!';
        });
      } else {
        final errorData = json.decode(response.body);
        setState(
          () => _errorMessage = errorData['message'] ?? 'Failed to send OTP',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error: ${e.toString()}');
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    var body = {'email': _emailController.text, 'otp': otp};

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.validateOtp),
        body: body,
      );

      if (response.statusCode == 200) {
        navigationPushReplacement(
          context,
          const ForgetPinSet(isSettingNewPin: true),
        );
      } else {
        final errorData = json.decode(response.body);
        setState(() => _errorMessage = errorData['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        image:  DecorationImage(
          image: AssetImage(Assets.images.bg.path),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.05,
                      vertical: constraints.maxHeight * 0.02,
                    ),
                    child: _buildEmailVerifyCard(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmailVerifyCard() {
    return CustomCard(
      widget: Column(
        children: [
          Text(
            AppStrings.appName.toUpperCase(),
            style: CustomTextStyles.appTitleText(context),
          ),
          SizedBox(height: 12.h),
          Text(
            'Verify your email then forget your PIN',
            textAlign: TextAlign.center,
            style: CustomTextStyles.msgAuthTitleText(context),
          ),
          SizedBox(height: 20.h),
          PrimaryTextfield(
            controller: _emailController,
            isPassword: false,
            labelText: AppStrings.lblEmail,
            prefixIcon: Icon(
              FeatherIcons.mail,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.13),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: Text(_errorMessage, style: CustomTextStyles.msgErrorText(context)),
            ),
          if (_successMessage.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: Text(
                _successMessage,
                style: CustomTextStyles.msgSuccessText,
              ),
            ),
          SizedBox(height: 10.h),
          AuthButton(
            onPressed: () {
              String email = _emailController.text.trim();
              if (email.isEmpty) {
                setState(() => _errorMessage = 'Please enter email');
              } else if (!_isValidEmail(email)) {
                setState(
                  () => _errorMessage = 'Please enter a valid email address.',
                );
              } else {
               // _sendOtp();
               navigationPush(context, const ForgetPinSet(isSettingNewPin: true));
              }
            },
            title: 'Get OTP',
            isLoading: _isSendingOtp,
          ),
          SizedBox(height: 10.h),
          if (_isShowButton)
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      width: 40.w,
                      height: 42.h,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        cursorColor: const Color(0xFF9B3046),
                        cursorHeight: 16.sp,
                        cursorWidth: 1.5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.1),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryColor.withOpacity(0.8),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(fontSize: 16.sp),
                        onChanged: (value) {
                          setState(() => _errorMessage = '');
                          if (value.isNotEmpty) {
                            if (index < 5) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_otpFocusNodes[index + 1]);
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          } else {
                            if (index > 0) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_otpFocusNodes[index - 1]);
                            }
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          if (_isShowButton) SizedBox(height: 15.h),
          if (_isShowButton)
            AuthButton(
              onPressed: _isLoading ? null : _verifyOtp,
              title: AppStrings.lblVerify,
              isLoading: _isLoading,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _emailController.dispose();
    super.dispose();
  }
}
