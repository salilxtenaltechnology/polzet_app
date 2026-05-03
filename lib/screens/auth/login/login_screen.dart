// ignore_for_file: deprecated_member_use, unused_local_variable, unused_element, unused_field, library_private_types_in_public_api
part of 'login_import.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with UtilityMixin {
  final TextEditingController _userEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final ApiService apiService = ApiService();

  bool _isLoading = false;
  bool _isChecked = false;
  bool _isPasswordHidden = true;
  bool _isLoginEmail = true;
  bool _isLoginNumber = false;
  String? _countryCode;
  String _errorText = '';

  @override
  void dispose() {
    _userEmailController.dispose();
    _passwordController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  // Method call fron API SERVICE
  void loginUser() async {
    String emailOrUsername = _userEmailController.text.trim();
    String number = _mobileNumberController.text.trim();
    String password = _passwordController.text.trim();
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Manual validation
    if (_isLoginEmail) {
      if (emailOrUsername.isEmpty || password.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Email/Username and password are required.';
          _isLoading = false;
        });
        return;
      }
      // Accept either valid email or valid username
      bool isEmail = RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
      ).hasMatch(emailOrUsername);
      bool isUsername = RegExp(
        r'^[a-zA-Z0-9_]{3,20}$',
      ).hasMatch(emailOrUsername);
      if (!isEmail && !isUsername) {
        if (!mounted) return;
        setState(() {
          _errorText =
              'Enter a valid email or username (3-20 alphanumeric characters).';
          _isLoading = false;
        });
        return;
      }
    } else if (_isLoginNumber) {
      if (number.isEmpty || password.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Mobile number and password are required.';
          _isLoading = false;
        });
        return;
      }
      // Optional: Mobile number validation (10 digits)
      if (!RegExp(r'^\d{10}$').hasMatch(number)) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Enter a valid 10-digit mobile number.';
          _isLoading = false;
        });
        return;
      }
    }
    // Password validation (for all)
    if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(password)) {
      if (!mounted) return;
      setState(() {
        _errorText =
            'Password must be at least 8 characters long and include one uppercase letter and one special character.';
        _isLoading = false;
      });
      return;
    }
    // Clear error if valid
    if (!mounted) return;
    setState(() {
      _errorText = '';
    });
    // Pick the correct value for API
    String loginValue = _isLoginEmail ? emailOrUsername : number;
    await apiService.loginUser(
      email_username: loginValue,
      password: password,
      context: context,
    );

    final savedLang = await SharedPrefService.getLanguage();
    if (mounted && savedLang != null) {
      MyApp.of(context)?.changeLanguage(Locale(savedLang));
    } else if (mounted) {
      MyApp.of(context)?.resetLocale();
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<UserProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        image: DecorationImage(
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
                child: IntrinsicHeight(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.05,
                        vertical: constraints.maxHeight * 0.02,
                      ),
                      child: _buildLoginCard(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
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
            AppStrings.msgLogin,
            style: CustomTextStyles.msgAuthTitleText(context),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoginEmail = true;
                      _isLoginNumber = false;
                    });
                  },
                  child: Container(
                    height: 30.h,
                    margin: EdgeInsets.symmetric(vertical: 20.w),
                    decoration: BoxDecoration(
                      color: _isLoginEmail
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(50.r),
                      ),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 0.7,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Email/Username',
                        style: TextStyle(
                          color: _isLoginEmail
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          fontSize: 11.3.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoginEmail = false;
                      _isLoginNumber = true;
                    });
                  },
                  child: Container(
                    height: 30.h,
                    margin: EdgeInsets.symmetric(vertical: 20.w),
                    decoration: BoxDecoration(
                      color: _isLoginNumber
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(50.r),
                      ),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 0.7,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Mobile Number',
                        style: TextStyle(
                          color: _isLoginNumber
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          fontSize: 11.3.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoginEmail)
            PrimaryTextfield(
              controller: _userEmailController,
              isPassword: false,
              keyboardType: TextInputType.text,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              labelText: 'Email or Username',
              prefixIcon: Icon(
                FeatherIcons.user,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.13),
              ),
            ),
          if (_isLoginNumber)
            _buildPhoneNumber(_mobileNumberController, _countryCode ?? '91'),
          SizedBox(height: 5.h),
          PrimaryTextfield(
            controller: _passwordController,
            isPassword: _isPasswordHidden,
            keyboardType: TextInputType.visiblePassword,
            labelText: AppStrings.lblPassword,
            autofillHints: const [AutofillHints.password],
            prefixIcon: Icon(
              FeatherIcons.lock,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.13),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordHidden ? FeatherIcons.eyeOff : FeatherIcons.eye,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.2),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordHidden = !_isPasswordHidden;
                });
              },
            ),
          ),
          _buildRememberMeAndForgotPassword(),
          _buildSignUpRow(),
          SizedBox(height: 12.h),
          AuthButton(
            title: 'Login',
            onPressed: loginUser,
            isLoading: _isLoading,
          ),
          if (_errorText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 7.h),
              child: Text(
                _errorText,
                style: CustomTextStyles.msgErrorText(context),
              ),
            ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _buildPhoneNumber(
    TextEditingController controller,
    String countryCode,
  ) {
    // Get the country object from the dial code
    Country? initialCountry = getCountryByDialCode(_countryCode ?? '91');

    return Container(
      height: 35.h,
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Country code section
          CustomCountryCode(
            initialCountry: initialCountry,
            onCountrySelected: (country) {
              setState(() {
                _countryCode = country.dialCode.replaceAll('+', '');
              });
            },
          ),
          // Vertical divider
          Container(
            height: 20.h,
            width: 1,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
          ),
          // Phone number input
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: CustomTextStyles.lblPrimaryText(context),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(left: 5.w, bottom: 4.h),
                hintText: 'Enter mobile number',
                hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMeAndForgotPassword() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              width: 22.w,
              child: Checkbox(
                side: const BorderSide(color: Color(0XFFD9D9D9), width: 1.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                value: _isChecked,
                checkColor: Colors.white,
                activeColor: const Color(0xFF9B3046),
                onChanged: (value) {
                  setState(() {
                    _isChecked = value ?? false;
                  });
                },
              ),
            ),
            SizedBox(width: 5.w),
            Text(AppStrings.lblRememberMe, style: TextStyle(fontSize: 11.sp)),
          ],
        ),
        GestureDetector(
          onTap: () {
            navigationPush(context, const ForgotPasswordScreen());
          },
          child: Text(
            AppStrings.lblForgotPassword,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w300,
              fontSize: 11.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          AppStrings.lblDonotHaveAcc,
          style: TextStyle(
            fontSize: 10.sp,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        GestureDetector(
          onTap: () {
            //navigationPush(context, const RegisterEmailVerification(email: ''));
          },
          child: Text(
            AppStrings.lblSignup,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 10.5.sp,
            ),
          ),
        ),
      ],
    );
  }
}

// salsa --  sora -- zcoolXiaoWei  -- yesevaOne --
