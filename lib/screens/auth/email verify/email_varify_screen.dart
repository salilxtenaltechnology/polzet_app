// ignore_for_file: deprecated_member_use, unused_element, curly_braces_in_flow_control_structures
part of 'email_verify_import.dart';

class RegisterEmailVerification extends StatefulWidget {
  final String email;

  const RegisterEmailVerification({super.key, required this.email});

  @override
  _EmailVerificationScreenState createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<RegisterEmailVerification>
    with UtilityMixin {
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isShowButton = false; // To OTP text box and Verify Button
  String _errorMessage = '';
  String _successMessage = '';
  bool _isValidEmail(String email) {
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = '';
      _successMessage = '';
    });

    var body = {'email': _emailController.text};

    try {
      final response =
          await http.post(Uri.parse(ApiConstants.emailVerify), body: body);

      if (response.statusCode == 200) {
        setState(() {
          _isShowButton = true;
          _successMessage = 'OTP sent successfully!';
        });
      } else {
        final errorData = json.decode(response.body);
        setState(
            () => _errorMessage = errorData['message'] ?? 'Failed to send OTP');
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
      final response =
          await http.post(Uri.parse(ApiConstants.validateOtp), body: body);

      if (response.statusCode == 200) {
        navigationPushReplacement(
            // ignore: use_build_context_synchronously
            context, SignupScreen(email: _emailController.text));
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

  bool _validateEmail(String email) {
    return RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          image: DecorationImage(
              image: AssetImage(Assets.assetsImagesBg), fit: BoxFit.cover)),
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
          AppStrings.msgSignUp,
          textAlign: TextAlign.center,
          style: CustomTextStyles.msgAuthTitleText(context),
        ),
        SizedBox(height: 20.h),
        PrimaryTextfield(
          controller: _emailController,
          isPassword: false,
          labelText: AppStrings.lblEmail,
          prefixIcon: Icon(FeatherIcons.mail,size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.13)),
        ),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: Text(_errorMessage, style: CustomTextStyles.msgErrorText),
          ),
        if (_successMessage.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child:
                Text(_successMessage, style: CustomTextStyles.msgSuccessText),
          ),
        SizedBox(height: 10.h),
        AuthButton(
            onPressed: () {
              String email = _emailController.text.trim();
              if (email.isEmpty) {
                setState(() => _errorMessage = 'Please enter email');
              } else if (!_isValidEmail(_emailController.text)) {
                setState(() =>
                    _errorMessage = 'Please enter a valid email address.');
              } else {
                _sendOtp();
              }
            },
            title: 'Get OTP',
            isLoading: _isSendingOtp),
        SizedBox(height: 10.h),
        if (_isShowButton)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onBackground
                                    .withOpacity(0.1),
                                width: 1),
                            borderRadius: BorderRadius.circular(100)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.primaryColor.withOpacity(0.8),
                                width: 1),
                            borderRadius: BorderRadius.circular(100)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: 16.sp,
                      ),
                      onChanged: (value) {
                        setState(() => _errorMessage = '');
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            FocusScope.of(context)
                                .requestFocus(_otpFocusNodes[index + 1]);
                          } else {
                            FocusScope.of(context).unfocus();
                          }
                        } else {
                          if (index > 0) {
                            FocusScope.of(context)
                                .requestFocus(_otpFocusNodes[index - 1]);
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
              isLoading: _isLoading),
        if (_isShowButton) SizedBox(height: 10.h),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppStrings.lblHaveAcc,
                style: TextStyle(
                  fontSize: 11.sp,
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
                      fontSize: 12.sp),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          'Or continue with',
          style: TextStyle(
            fontSize: 11.sp,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _authSocialMedia(() {}, Image.asset(Assets.assetsImagesIcGoogle),
                EdgeInsets.all(4).w),
            SizedBox(width: 7.w),
            _authSocialMedia(
                () {},
                Image.asset(Assets.assetsImagesIcX,
                    color: Theme.of(context).colorScheme.onBackground),
                EdgeInsets.all(5).w),
            SizedBox(width: 7.w),
            _authSocialMedia(() {}, Image.asset(Assets.assetsImagesIcFacebook),
                EdgeInsets.all(3).w),
          ],
        ),
      ],
    ));
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) controller.dispose();
    for (var node in _otpFocusNodes) node.dispose();
    super.dispose();
  }

  Widget _authSocialMedia(
      VoidCallback onTap, Widget image, EdgeInsets padding) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35.h,
        width: 35.w,
        padding: padding,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
                width: 1)),
        child: image,
      ),
    );
  }
}
