// ignore_for_file: unused_field, deprecated_member_use, unused_local_variable, use_build_context_synchronously
part of 'forgot_password_import.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with UtilityMixin {
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isEmailSent = false; // To track if OTP has been sent
  bool _isLoading = false; // To show loading state
  bool _isSendingOtp = false; // To show loading state for OTP sending
  bool _isShowButton = false; // To OTP text box and Verify Button
  String _errorMessage = ''; // To display error messages
  String _successMessage = ''; // To display success messages
  bool _isValidEmail(String email) {
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  final SharedPrefService _prefService = SharedPrefService();

  // Send OTP to the user's email
  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = '';
      _successMessage = '';
    });

    var body = {'email': _emailController.text};

    try {
      final response = await http
          .post(Uri.parse(ApiConstants.forgotPasswordEmail), body: body)
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          _isEmailSent = true;
          _isShowButton = true;
          _successMessage = 'OTP sent successfully!';
        });
      } else if (response.statusCode == 400) {
        setState(() => _errorMessage = 'User with this email does not exist.');
      } else {
        setState(
          () => _errorMessage = responseData['message'] ?? 'Failed to send OTP',
        );
      }
    } on SocketException {
      setState(
        () => _errorMessage = 'Network error: Check internet connection.',
      );
    } on TimeoutException {
      setState(() => _errorMessage = 'Connection timeout. Please try again.');
    } catch (e) {
      setState(
        () => _errorMessage =
            'Error: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  // Verify OTP entered by the user
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
      final response = await http
          .post(Uri.parse(ApiConstants.forgotPasswordVerify), body: body)
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        // ignore: non_constant_identifier_names
        final JWT_TOKEN = responseData['data']['access_token'];
        print('JWT_TOKEN :  $JWT_TOKEN');
        // _prefService.saveAccessToken(JWT_TOKEN);

        navigationPushReplacement(
          context,
          ChangePasswordScreen(
            email: _emailController.text,
            JWT_TOKEN: JWT_TOKEN,
          ),
        );
      } else {
        setState(
          () => _errorMessage = responseData['message'] ?? 'Invalid OTP',
        );
      }
    } on SocketException {
      setState(
        () => _errorMessage = 'Network error: Check internet connection.',
      );
    } on TimeoutException {
      setState(() => _errorMessage = 'Connection timeout. Please try again.');
    } catch (e) {
      setState(
        () => _errorMessage =
            'Error: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        image: DecorationImage(
          image: AssetImage(Assets.assetsImagesBg),
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
                    child: _buildForgotCard(),
                  ),
                ),
              ),
            );
          },
        ),
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
    super.dispose();
  }

  Widget _buildForgotCard() {
    return CustomCard(
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.appName.toUpperCase(),
            style: CustomTextStyles.appTitleText(context),
          ),
          SizedBox(height: 12.h),
          Text(
            AppStrings.msgForgotPassword,
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
              child: Text(_errorMessage, style: CustomTextStyles.msgErrorText),
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
              } else if (!_isValidEmail(_emailController.text)) {
                setState(
                  () => _errorMessage = 'Please enter a valid email address.',
                );
              } else {
                _sendOtp();
              }
            },
            title: 'Get OTP',
            isLoading: _isSendingOtp,
          ),
          SizedBox(height: 10.h),
          if (_isShowButton)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Container(
                    width: 40.w,
                    height: 42.h,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      cursorColor: Color(0xFF9B3046),
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
          if (_isShowButton) SizedBox(height: 15.h),
          if (_isShowButton)
            AuthButton(
              onPressed: _isLoading ? null : _verifyOtp,
              title: AppStrings.lblVerify,
              isLoading: _isLoading,
            ),
          if (_isShowButton) SizedBox(height: 10.h),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.lblRememberPassword,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    AppStrings.lblLogin,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
