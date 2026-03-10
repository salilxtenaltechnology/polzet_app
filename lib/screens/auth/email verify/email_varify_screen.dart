// ignore_for_file: deprecated_member_use, unused_element, curly_braces_in_flow_control_statements, library_private_types_in_public_api
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

  // ─── Google Sign-In ──────────────────────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  bool _isGoogleLoading = false;

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

  final String googleAndroidClientId =
      '53424915324-sft947h1dvjlo5se6h2i2vqprbakils6.apps.googleusercontent.com';
  final String googleWebClientId =
      '53424915324-6jgqsatmm1o2uslhl1hd326ss483fb8n.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _initGoogleSignIn();
  }

  // ─── Google Auth Init ──────────────────────────────────────────────────────
  void _initGoogleSignIn() {
    unawaited(
      _googleSignIn
          .initialize(
            serverClientId: googleWebClientId, // ✅ only this is needed
            // No clientId needed — android client comes from google-services.json
          )
          .then((_) {
            _authSub = _googleSignIn.authenticationEvents.listen(
              _onAuthEvent,
              onError: (e) => debugPrint('❌ Auth stream error: $e'),
            );
            //  _googleSignIn.attemptLightweightAuthentication();
          }),
    );
  }

  void _onAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      debugPrint('📌 Signed in as ${event.user.email}');
      _fetchTokenAndLogin(event.user);
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      debugPrint('📌 Signed out');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _googleSignIn.authenticate();
    } catch (e) {
      // _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _fetchTokenAndLogin(GoogleSignInAccount user) async {
    try {
      final GoogleSignInAuthentication auth = user.authentication;
      final String? idToken = auth.idToken;

      // debugPrint('🔑 Google idToken: $idToken');

      if (idToken == null) {
        _showError('Google login failed (no token received)');
        return;
      }

      await SharedPrefService.setString('jwt_google_token', idToken);
      debugPrint('✅ Google idToken saved');

      await _socialLoginAPI(idToken);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _socialLoginAPI(String idToken) async {
    if (mounted) setState(() => _isGoogleLoading = true);

    try {
      final response = await apiService.socialLogin(idToken);

      debugPrint('📥 Response: $response');

      if (response == null) {
        if (mounted) setState(() => _errorMessage = 'Server not responding');
        return;
      }
      final String? status = response['status'];

      if (status != 'success') {
        if (mounted) {
          setState(() => _errorMessage = response['message'] ?? 'Login failed');
        }
        return;
      }

      final data = response['data'] as Map<String, dynamic>;
      final String accessToken = data['access_token'];
      final String refreshToken = data['refresh_token'];
      final Map<String, dynamic> user = data['user'];

      debugPrint('✅ accessToken: $accessToken');
      debugPrint('✅ user: $user');

      // ✅ Save tokens
      await SharedPrefService.setToken(accessToken);
      await SharedPrefService.setRefreshToken(refreshToken);

      // ✅ Save user details
      await SharedPrefService.setString('username', user['username'] ?? '');
      await SharedPrefService.setString('email', user['email'] ?? '');

      // ✅ Initialize notifications — same as loginUser()
      await NotificationService().initialize();
      await NotificationService().connectToWebSocket(accessToken);

      // ✅ Register FCM token — same as loginUser()
      final fcmToken = await NotificationService().getFCMToken();
      if (fcmToken != null) {
        final platform = Platform.isAndroid ? 'android' : 'ios';
        await FcmApiService.registerFcmToken(fcmToken, platform);
      }

      showToast(message: 'Login Successful!');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            duration: const Duration(milliseconds: 200),
            child: const HomeScreen(initialIndex: 0),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ socialLoginAPI exception: $e');
      if (mounted) setState(() => _errorMessage = 'Login error: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      return jsonDecode(utf8.decode(base64Decode(normalized)))
          as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Failed to parse JWT: $e');
      return null;
    }
  }

  void _showError(String msg) {
    if (mounted) setState(() => _errorMessage = msg);
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
        Uri.parse(ApiConstants.emailVerify),
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
          // ignore: use_build_context_synchronously
          context,
          SignupScreen(email: _emailController.text),
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
        image: const DecorationImage(
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
              } else if (!_isValidEmail(email)) {
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
                      fontSize: 12.sp,
                    ),
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
              // ✅ Google button wired to _handleGoogleSignIn
              _authSocialMedia(
                _handleGoogleSignIn,
                _isGoogleLoading
                    ? SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.primaryColor,
                        ),
                      )
                    : Image.asset(Assets.assetsImagesIcGoogle),
                const EdgeInsets.all(4).w,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _emailController.dispose();
    super.dispose();
  }

  Widget _authSocialMedia(
    VoidCallback onTap,
    Widget image,
    EdgeInsets padding,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35.h,
        width: 35.w,
        padding: padding,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: image,
      ),
    );
  }
}
