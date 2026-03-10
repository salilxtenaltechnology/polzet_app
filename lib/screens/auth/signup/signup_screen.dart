// ignore_for_file: deprecated_member_use, avoid_print, library_private_types_in_public_api

part of 'signup_imports.dart';

class SignupScreen extends StatefulWidget {
  final String email;
  const SignupScreen({super.key, required this.email});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with UtilityMixin {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // State variables
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isLoading = false;
  String _errorText = '';
  String? _countryCode = '91'; // Initialize with default value
  String? _selectedGender;

  List<String> genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _countryCode = '91'; // Ensure country code is initialized
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _registrationAcc() async {
    setState(() => _errorText = '');

    // Get form data and trim whitespace
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String dob = _dobController.text.trim();
    String phone = _phoneController.text.trim();
    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    // Enhanced validation checks
    if (firstName.isEmpty) {
      setState(() => _errorText = "First name is required.");
      return;
    }

    if (lastName.isEmpty) {
      setState(() => _errorText = "Last name is required.");
      return;
    }

    if (username.isEmpty) {
      setState(() => _errorText = "Username is required.");
      return;
    }

    // Username validation (alphanumeric and underscore only)
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    if (!usernameRegex.hasMatch(username)) {
      setState(
        () => _errorText =
            "Username must be 3-20 characters (letters, numbers, underscore only).",
      );
      return;
    }

    if (dob.isEmpty) {
      setState(() => _errorText = "Date of birth is required.");
      return;
    }

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      setState(() => _errorText = "Please select gender.");
      return;
    }

    if (phone.isEmpty) {
      setState(() => _errorText = "Phone number is required.");
      return;
    }

    if (email.isEmpty) {
      setState(() => _errorText = "Email is required.");
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorText = "Password is required.");
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _errorText = "Please confirm your password.");
      return;
    }

    // Password validation
    if (password != confirmPassword) {
      setState(() => _errorText = "Passwords do not match!");
      return;
    }

    // Strong password validation
    final passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );
    if (!passwordRegex.hasMatch(password)) {
      setState(
        () => _errorText =
            "Password must be 8+ characters with uppercase, lowercase, number & special character",
      );
      return;
    }

    // Phone validation - more flexible for international numbers
    final phoneRegex = RegExp(r'^[0-9]{7,15}$');
    if (!phoneRegex.hasMatch(phone)) {
      setState(
        () => _errorText = "Invalid phone number format (7-15 digits required)",
      );
      return;
    }

    // Email validation
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorText = "Please enter a valid email address");
      return;
    }

    // Date of birth validation (must be at least 13 years old)
    try {
      DateTime birthDate = DateTime.parse(dob);
      DateTime now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      if (age < 13) {
        setState(
          () => _errorText = "You must be at least 13 years old to register",
        );
        return;
      }
    } catch (e) {
      setState(() => _errorText = "Invalid date of birth format");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get access token from shared preferences
      final accessToken = await SharedPrefService.getToken();

      // Prepare request body matching your Postman structure
      final body = {
        "first_name": firstName,
        "last_name": lastName,
        "dob": dob, // Format: YYYY-MM-DD
        "gender": _selectedGender?.toLowerCase(),
        "username": username,
        "email": email,
        "mobile_number": phone,
        "password": password,
        "country_code": "+${_countryCode ?? '91'}", // Ensure + prefix
      };

      // Create Dio instance with proper configuration
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'YourAppName/1.0',
          },
        ),
      );

      // Add authorization header if access token exists
      if (accessToken != null && accessToken.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $accessToken';
        print('Authorization header added: Bearer $accessToken');
      }

      // Add interceptor for detailed logging (only in debug mode)
      if (kDebugMode) {
        dio.interceptors.add(
          LogInterceptor(
            request: true,
            requestBody: true,
            requestHeader: true,
            responseBody: true,
            responseHeader: false,
            error: true,
            logPrint: (obj) => print(obj),
          ),
        );
      }

      // Make the API call
      final response = await dio.post(ApiConstants.registration, data: body);

      // print('Response Status: ${response.statusCode}');
      // print('Response Headers: ${response.headers}');
      // print('Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        // Clear form data
        _clearFormData();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registration successful!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to login screen after a short delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          navigationPushReplacement(context, const LoginScreen());
        }
      } else {
        // Handle non-success status codes
        _handleErrorResponse(response);
      }
    } on DioException catch (e) {
      // print('DioException occurred: ${e.toString()}');
      // print('DioException Type: ${e.type}');
      print('Response Data: ${e.response?.data}');
      // print('Response Status: ${e.response?.statusCode}');
      // print('Response Headers: ${e.response?.headers}');

      _handleDioException(e);
    } on SocketException catch (e) {
      print('SocketException: $e');
      setState(
        () =>
            _errorText = 'Network error: Please check your internet connection',
      );
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      setState(() => _errorText = 'Connection timeout: Please try again');
    } on FormatException catch (e) {
      print('FormatException: $e');
      setState(() => _errorText = 'Invalid response format from server');
    } catch (e) {
      print('Unexpected error: $e');
      setState(
        () => _errorText = 'An unexpected error occurred. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleErrorResponse(Response response) {
    String errorMessage = 'Registration failed';

    try {
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        // Try different possible error message fields
        errorMessage =
            data['message'] ??
            data['error'] ??
            data['detail'] ??
            data['errors']?.toString() ??
            'Registration failed with status ${response.statusCode}';

        // Handle validation errors
        if (data['errors'] is Map) {
          final errors = data['errors'] as Map;
          List<String> errorMessages = [];
          errors.forEach((key, value) {
            if (value is List) {
              errorMessages.addAll(value.map((e) => e.toString()));
            } else {
              errorMessages.add(value.toString());
            }
          });
          if (errorMessages.isNotEmpty) {
            errorMessage = errorMessages.join('\n');
          }
        }
      } else if (response.data is String) {
        errorMessage = response.data;
      }
    } catch (e) {
      print('Error parsing error response: $e');
      errorMessage = 'Registration failed with status ${response.statusCode}';
    }

    setState(() => _errorText = errorMessage);
  }

  void _handleDioException(DioException e) {
    String errorMessage;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage =
            'Connection timeout. Please check your internet connection and try again.';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Server response timeout. Please try again later.';
        break;
      case DioExceptionType.sendTimeout:
        errorMessage =
            'Request timeout. Please check your connection and try again.';
        break;
      case DioExceptionType.badResponse:
        if (e.response != null) {
          switch (e.response!.statusCode) {
            case 400:
              errorMessage =
                  'Invalid registration data. Please check your information.';
              break;
            case 401:
              errorMessage = 'Authentication failed. Please try again.';
              break;
            case 403:
              errorMessage =
                  'Registration not allowed. Please contact support.';
              break;
            case 409:
              errorMessage = 'User already exists with this email or username.';
              break;
            case 422:
              errorMessage =
                  'Invalid data provided. Please check your information.';
              break;
            case 500:
              errorMessage = 'Server error. Please try again later.';
              break;
            default:
              errorMessage = 'Registration failed. Please try again.';
          }

          // Try to extract more specific error message from response
          try {
            if (e.response?.data is Map<String, dynamic>) {
              final data = e.response!.data as Map<String, dynamic>;
              String specificError =
                  data['message'] ?? data['error'] ?? errorMessage;
              errorMessage = specificError;
            }
          } catch (parseError) {
            print('Error parsing error response: $parseError');
          }
        } else {
          errorMessage = 'Registration failed. Please try again.';
        }
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request was cancelled. Please try again.';
        break;
      case DioExceptionType.unknown:
        if (e.message?.contains('SocketException') == true) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else {
          errorMessage = 'Network error. Please try again.';
        }
        break;
      default:
        errorMessage = e.message ?? 'An unexpected error occurred';
    }

    setState(() => _errorText = errorMessage);
  }

  void _clearFormData() {
    _firstNameController.clear();
    _lastNameController.clear();
    _dobController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _usernameController.clear();
    setState(() {
      _selectedGender = null;
      _countryCode = '91';
    });
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime eighteenYearsAgo = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );
    final DateTime thirteenYearsAgo = DateTime(
      now.year - 13,
      now.month,
      now.day,
    );

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: thirteenYearsAgo, // Minimum age of 13
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
            ),
            dialogBackgroundColor: AppColors.primaryColor.withOpacity(0.1),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dobController.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(Assets.assetsImagesBg),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 10.h,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(15).w,
            child: CustomCard(
              widget: ListView(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // App Title
                      Text(
                        AppStrings.appName.toUpperCase(),
                        style: CustomTextStyles.appTitleText(context),
                      ),
                      SizedBox(height: 12.h),

                      // Signup Message
                      Text(
                        AppStrings.msgSignUp,
                        style: CustomTextStyles.msgAuthTitleText(context),
                      ),
                      SizedBox(height: 15.h),

                      // First Name
                      PrimaryTextfield(
                        isPassword: false,
                        controller: _firstNameController,
                        labelText: AppStrings.lblFirstName,
                        prefixIcon: Icon(
                          FeatherIcons.user,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.13),
                        ),
                      ),
                      SizedBox(height: 5.h),

                      // Last Name
                      PrimaryTextfield(
                        isPassword: false,
                        controller: _lastNameController,
                        labelText: AppStrings.lblLastName,
                        prefixIcon: Icon(
                          FeatherIcons.user,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.13),
                        ),
                      ),
                      SizedBox(height: 5.h),

                      // Username
                      PrimaryTextfield(
                        isPassword: false,
                        controller: _usernameController,
                        labelText: AppStrings.lblUsername,
                        prefixIcon: Icon(
                          FeatherIcons.atSign,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.13),
                        ),
                      ),
                      SizedBox(height: 5.h),

                      // Date of Birth
                      buildDateOfBirthField(),
                      SizedBox(height: 12.h),

                      // Gender
                      buildGenderField(),
                      SizedBox(height: 12.h),

                      // Phone Number with Country Code
                      _buildPhoneNumber(_phoneController, _countryCode ?? '91'),
                      SizedBox(height: 12.h),

                      // Email (Read-only)
                      PrimaryTextfield(
                        isPassword: false,
                        isRead: true,
                        controller: _emailController,
                        labelText: AppStrings.lblEmail,
                        prefixIcon: Icon(
                          Icons.alternate_email,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.13),
                        ),
                      ),
                      SizedBox(height: 5.h),

                      // Password
                      PrimaryTextfield(
                        controller: _passwordController,
                        isPassword: _isPasswordHidden,
                        labelText: AppStrings.lblPassword,
                        prefixIcon: Icon(
                          FeatherIcons.lock,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.13),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordHidden
                                ? FeatherIcons.eyeOff
                                : FeatherIcons.eye,
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.13),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordHidden = !_isPasswordHidden;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 5.h),

                      // Confirm Password
                      PrimaryTextfield(
                        controller: _confirmPasswordController,
                        isPassword: _isConfirmPasswordHidden,
                        labelText: AppStrings.lblConfirmPassword,
                        prefixIcon: Icon(
                          FeatherIcons.lock,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.13),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordHidden
                                ? FeatherIcons.eyeOff
                                : FeatherIcons.eye,
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.13),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _isConfirmPasswordHidden =
                                  !_isConfirmPasswordHidden,
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 10.h),

                      // Error Message
                      if (_errorText.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _errorText,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Register Button
                      AuthButton(
                        onPressed: _isLoading ? null : _registrationAcc,
                        title: AppStrings.lblSignup,
                        isLoading: _isLoading,
                      ),
                      SizedBox(height: 12.h),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: CustomTextStyles.lblSecondryText(context),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              "Login",
                              style: CustomTextStyles.lblPrimaryText(context)
                                  .copyWith(
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDateOfBirthField() {
    return Container(
      height: 37.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: _dobController,
        readOnly: true,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(top: 8.h),
          hintText: AppStrings.lblDateOfBirth,
          hintStyle: CustomTextStyles.lblPrimaryHintText(context),
          prefixIcon: Icon(
            FeatherIcons.calendar,
            size: 20,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.13),
          ),
          border: InputBorder.none,
        ),
        style: CustomTextStyles.lblPrimaryText(context),
        onTap: _selectDate,
      ),
    );
  }

  Widget buildGenderField() {
    return Container(
      height: 37.h,
      width: double.infinity,
      padding: EdgeInsets.only(right: 12.w),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 8.w),
          Icon(
            Icons.female,
            size: 28,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.13),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                hintText: "Gender",
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 12.8.sp,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: genderOptions.map((gender) {
                return DropdownMenuItem<String>(
                  value: gender,
                  child: Text(
                    gender,
                    style: CustomTextStyles.lblPrimaryText(context),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => _selectedGender = newValue);
              },
              iconEnabledColor: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.7),
              dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumber(
    TextEditingController controller,
    String countryCode,
  ) {
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
          // Country Code Picker
          CustomCountryCode(
            initialCountry: initialCountry,
            onCountrySelected: (country) {
              setState(() {
                _countryCode = country.dialCode.replaceAll('+', '');
                print('Selected country code: $_countryCode');
              });
            },
          ),

          // Separator
          Container(
            height: 20.h,
            width: 1,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
          ),

          // Phone Number Input
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: CustomTextStyles.lblPrimaryText(context),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(left: 8.w, bottom: 4.h),
                hintText: 'Enter mobile number',
                hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
