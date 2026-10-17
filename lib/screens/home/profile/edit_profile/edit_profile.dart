// ignore_for_file: unused_element, deprecated_member_use, unused_field

import 'dart:io';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../models/country/country_model.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/country_code/code_bottomsheet.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../widgets/base64/image_convert.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../api/api_config.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../core/utils/phone_verify_logger.dart';
import 'edit_profile_email_number_verify_otp_screen.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isUploadingProfile = false;
  bool _obscurePassword = true;
  bool _isSaving = false;
  DateTime? _dob;
  bool _hasChanges = false;
  String _originalEmail = '';
  bool _isVerifyingEmail = false;

  String _originalPhone = '';
  bool _isVerifyingPhone = false;
  bool _isSendingPhoneOtp = false;
  DateTime? _lastPhoneOtpSentAt;
  int? _lastPhoneResendToken;
  String? _lastAttemptPhoneNumber;
  static const int _phoneOtpCooldownSeconds = 30;

  String _selectedGender = 'Prefer not to say';
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalUsername = '';
  String _originalBio = '';
  String _originalDob = '';
  String _originalGender = '';

  String _firstNameErrorText = '';
  String _lastNameErrorText = '';
  String _usernameErrorText = '';
  String _emailErrorText = '';

  final List<String> _genderOptions = ['Male', 'Female', 'Prefer not to say'];

  Country _selectedCountry = Country(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupListeners();
  }

  void _setupListeners() {
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_usernameErrorText.isNotEmpty) {
      _usernameErrorText = '';
    }
    if (_firstNameErrorText.isNotEmpty) {
      _firstNameErrorText = '';
    }
    if (_lastNameErrorText.isNotEmpty) {
      _lastNameErrorText = '';
    }
    if (_emailErrorText.isNotEmpty) {
      _emailErrorText = '';
    }

    // Always rebuild so the Verify button's visual state updates dynamically
    setState(() {});

    _checkChanges();
  }

  void _checkChanges() {
    final dobStr = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '';
    final hasChanges =
        _firstNameController.text != _originalFirstName ||
        _lastNameController.text != _originalLastName ||
        _usernameController.text != _originalUsername ||
        _bioController.text != _originalBio ||
        dobStr != _originalDob ||
        _selectedGender != _originalGender;

    if (_hasChanges != hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _firstNameController.text = userProvider.firstName ?? '';
    _lastNameController.text = userProvider.lastName ?? '';
    _usernameController.text = userProvider.username ?? '';
    _bioController.text = userProvider.bio ?? '';
    _emailController.text = userProvider.email ?? '';
    _originalEmail = _emailController.text.trim();
    final String mobileNumber = (userProvider.mobile_number ?? '').trim();
    _phoneController.text = mobileNumber;
    _originalPhone = mobileNumber;

    if (mobileNumber.isEmpty) {
      _selectedCountry = Country(
        name: 'India',
        code: 'IN',
        dialCode: '+91',
        flag: '🇮🇳',
      );
    } else if (userProvider.country_code != null &&
        userProvider.country_code!.trim().isNotEmpty) {
      final code = userProvider.country_code!.replaceAll('+', '').trim();
      final country = getCountryByDialCode(code);
      if (country != null) {
        _selectedCountry = country;
      } else {
        _selectedCountry = Country(
          name: 'India',
          code: 'IN',
          dialCode: '+91',
          flag: '🇮🇳',
        );
      }
    } else {
      _selectedCountry = Country(
        name: 'India',
        code: 'IN',
        dialCode: '+91',
        flag: '🇮🇳',
      );
    }

    _dob = userProvider.dob != null ? DateTime.parse(userProvider.dob!) : null;
    final rawGender = (userProvider.gender ?? 'Prefer not to say').replaceAll(
      '_',
      ' ',
    );
    _selectedGender = _genderOptions.firstWhere(
      (g) => g.toLowerCase() == rawGender.toLowerCase(),
      orElse: () => 'Prefer not to say',
    );

    _originalFirstName = _firstNameController.text;
    _originalLastName = _lastNameController.text;
    _originalUsername = _usernameController.text;
    _originalBio = _bioController.text;
    _originalDob = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '';
    _originalGender = _selectedGender;
    _originalEmail = _emailController.text.trim();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Profile photo ──────────────────────────────────────────────────────────
  Future<void> _pickProfilePhoto() async {
    try {
      final file = await ImagePickerService.pickImage(context: context);
      if (file == null || !mounted) return;

      final shouldCrop = await cropImageDiolog(context);
      if (!mounted) return;

      File finalFile = file;
      if (shouldCrop == true) {
        final croppedFile = await ImagePickerService.cropImage(file);
        if (croppedFile != null) finalFile = croppedFile;
      }

      if (!mounted) return;
      setState(() => _isUploadingProfile = true);

      final result = await ApiService().uploadProfileImage(finalFile);

      if (!mounted) return;
      if (result.isEmpty) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
      }

      setState(() => _isUploadingProfile = false);
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking profile photo: $e');
      if (mounted) setState(() => _isUploadingProfile = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    bool hasError = false;
    setState(() {
      _firstNameErrorText = '';
      _lastNameErrorText = '';
      _usernameErrorText = '';
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim();

    if (firstName.isEmpty) {
      setState(() => _firstNameErrorText = 'First name is required');
      hasError = true;
    }
    if (lastName.isEmpty) {
      setState(() => _lastNameErrorText = 'Last name is required');
      hasError = true;
    }
    if (username.isEmpty) {
      setState(() => _usernameErrorText = 'Username is required');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isSaving = true);

    bool profileUpdated = false;
    bool usernameUpdated = false;

    final bioStr = _bioController.text.trim();
    final dobStr = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '';

    if (firstName != _originalFirstName ||
        lastName != _originalLastName ||
        bioStr != _originalBio ||
        dobStr != _originalDob ||
        _selectedGender != _originalGender) {
      final profileError = await ApiService().updateProfile(
        firstName: firstName,
        lastName: lastName,
        bio: bioStr,
        dob: dobStr.isNotEmpty ? dobStr : null,
        gender: _selectedGender.toLowerCase().replaceAll(' ', '_'),
      );

      if (profileError.isEmpty) {
        profileUpdated = true;
        _originalFirstName = firstName;
        _originalLastName = lastName;
        _originalBio = bioStr;
        _originalDob = dobStr;
        _originalGender = _selectedGender;
      }
    }

    if (username != _originalUsername) {
      final usernameError = await ApiService().updateUsername(
        newUsername: username,
      );

      if (usernameError.isNotEmpty) {
        // ← must be isNotEmpty, not isEmpty
        if (mounted) {
          setState(() => _usernameErrorText = usernameError);
        }
        setState(() => _isSaving = false);
        return;
      } else {
        if (mounted) {
          setState(() {
            usernameUpdated = true;
            _originalUsername = username;
            _usernameErrorText = usernameError;
          });
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    _checkChanges();

    if (profileUpdated || usernameUpdated) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserData();
    }
  }

  Future<void> _verifyEmail() async {
    setState(() {
      _emailErrorText = '';
    });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailErrorText = 'Email address cannot be empty');
      showToast(message: 'Email address cannot be empty');
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailErrorText = 'Please enter a valid email address');
      showToast(message: 'Please enter a valid email address');
      return;
    }

    setState(() => _isVerifyingEmail = true);

    try {
      final result = await ApiService().requestEmailChangeOtp(email: email);
      if (!mounted) return;

      if (result['status'] == 'success' || result['success'] == true) {
        const successMsg = 'OTP sent';
        showToast(message: successMsg);

        setState(() => _isVerifyingEmail = false);

        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfilEmailNumberVeifyOTP(
              email: email,
              isEmail: true,
            ),
          ),
        );

        if (verified == true && mounted) {
          setState(() {
            _originalEmail = email;
            _emailErrorText = '';
          });
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          await userProvider.loadUserData();
          showToast(message: 'Email updated successfully');
        }
      } else {
        String errorMsg = 'Failed to send OTP';
        if (result['errors'] is Map) {
          final errors = result['errors'] as Map;
          if (errors['email'] is List && (errors['email'] as List).isNotEmpty) {
            errorMsg = (errors['email'] as List).first.toString();
          } else if (errors['email'] is String) {
            errorMsg = errors['email'];
          } else if (errors.values.isNotEmpty) {
            final firstVal = errors.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              errorMsg = firstVal.first.toString();
            } else if (firstVal is String) {
              errorMsg = firstVal;
            }
          }
        } else {
          errorMsg =
              result['data']?['message']?.toString() ??
              result['message']?.toString() ??
              'Failed to send OTP';
        }
        setState(() => _emailErrorText = errorMsg);
       // showToast(message: errorMsg);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : e.toString();
        setState(() => _emailErrorText = errorMsg);
        // showToast(message: errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingEmail = false);
      }
    }
  }

  Future<void> _verifyPhone() async {
    // 1. Atomic concurrency guard against double-taps
    if (_isSendingPhoneOtp || _isVerifyingPhone) {
      PhoneVerifyLogger.log(
        attemptId: 'none',
        caller: 'EditProfile._verifyPhone',
        event: 'BLOCKED_DUPLICATE_CALL',
        details:
            'isSendingPhoneOtp=$_isSendingPhoneOtp, isVerifyingPhone=$_isVerifyingPhone',
      );
      return;
    }

    final cleanPhone = _phoneController.text.trim().replaceAll(
      RegExp(r'[\s\-().+]'),
      '',
    );

    if (cleanPhone.isEmpty) {
      showToast(message: 'Please enter mobile number');
      return;
    }

    if (cleanPhone.length < 7 || cleanPhone.length > 15) {
      showToast(message: 'Please enter a valid mobile number');
      return;
    }

    final countryCode = _selectedCountry.dialCode;
    final fullPhoneNumber = '$countryCode$cleanPhone';

    // 2. Cooldown guard to prevent rapid repeated OTP dispatches to same number
    if (_lastPhoneOtpSentAt != null &&
        _lastAttemptPhoneNumber == fullPhoneNumber) {
      final elapsed = DateTime.now().difference(_lastPhoneOtpSentAt!).inSeconds;
      if (elapsed < _phoneOtpCooldownSeconds) {
        final remaining = _phoneOtpCooldownSeconds - elapsed;
        PhoneVerifyLogger.log(
          attemptId: 'cooldown',
          caller: 'EditProfile._verifyPhone',
          event: 'BLOCKED_COOLDOWN_ACTIVE',
          phone: fullPhoneNumber,
          details: 'remainingSeconds=$remaining',
        );
        showToast(
          message:
              'Please wait $remaining seconds before requesting another OTP',
        );
        return;
      }
    }

    final attemptId = PhoneVerifyLogger.generateAttemptId('edit_profile');
    _isSendingPhoneOtp = true;
    setState(() => _isVerifyingPhone = true);

    PhoneVerifyLogger.log(
      attemptId: attemptId,
      caller: 'EditProfile._verifyPhone',
      event: 'VERIFY_TAP_ACCEPTED',
      phone: fullPhoneNumber,
    );

    try {
      // 3. Call ApiService phoneVerifyRequest
      PhoneVerifyLogger.log(
        attemptId: attemptId,
        caller: 'EditProfile._verifyPhone',
        event: 'BACKEND_REQUEST_START',
        phone: fullPhoneNumber,
      );

      final result = await ApiService().phoneVerifyRequest(
        countryCode: countryCode,
        mobileNumber: cleanPhone,
      );

      PhoneVerifyLogger.log(
        attemptId: attemptId,
        caller: 'EditProfile._verifyPhone',
        event: 'BACKEND_REQUEST_RESULT',
        details: 'status=${result['status']}, success=${result['success']}',
      );

      if (!mounted) return;

      final bool isSuccess =
          (result['status'] == 'success' || result['success'] == true) ||
          (result['data'] != null &&
              result['status'] != 'error' &&
              result['success'] != false);

      if (!isSuccess) {
        String errorMsg = 'Failed to send OTP';
        if (result['errors'] != null) {
          final errors = result['errors'];
          if (errors is Map && errors.isNotEmpty) {
            if (errors['non_field_errors'] is List &&
                (errors['non_field_errors'] as List).isNotEmpty) {
              errorMsg = (errors['non_field_errors'] as List).first.toString();
            } else {
              final firstKey = errors.keys.firstOrNull;
              if (firstKey != null) {
                final val = errors[firstKey];
                if (val is List && val.isNotEmpty) {
                  errorMsg = val.first.toString();
                } else if (val != null && val.toString().isNotEmpty) {
                  errorMsg = val.toString();
                }
              }
            }
          } else if (errors is List && errors.isNotEmpty) {
            errorMsg = errors.first.toString();
          } else if (errors is String && errors.isNotEmpty) {
            errorMsg = errors;
          }
        } else if (result['message'] != null &&
            result['message'].toString().isNotEmpty) {
          errorMsg = result['message'].toString();
        } else if (result['data']?['message'] != null) {
          errorMsg = result['data']['message'].toString();
        }

        showToast(message: errorMsg);
        _isSendingPhoneOtp = false;
        setState(() => _isVerifyingPhone = false);
        return;
      }

      // 4. Trigger Firebase Auth SMS OTP request
      final int? forceToken = (_lastAttemptPhoneNumber == fullPhoneNumber)
          ? _lastPhoneResendToken
          : null;

      PhoneVerifyLogger.log(
        attemptId: attemptId,
        caller: 'EditProfile._verifyPhone',
        event: 'FIREBASE_VERIFY_PHONE_INVOKED',
        phone: fullPhoneNumber,
        details: 'forceResendingToken=$forceToken',
      );

      bool hasHandledCodeSent = false;

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        forceResendingToken: forceToken,
        timeout: const Duration(seconds: 60),
        codeSent: (String verificationId, int? resendToken) async {
          PhoneVerifyLogger.log(
            attemptId: attemptId,
            caller: 'EditProfile.codeSent',
            event: 'FIREBASE_CALLBACK_CODE_SENT',
            details:
                'hasHandled=$hasHandledCodeSent, hasResendToken=${resendToken != null}',
          );

          if (!mounted) return;
          if (hasHandledCodeSent) return;
          hasHandledCodeSent = true;

          _lastPhoneOtpSentAt = DateTime.now();
          _lastPhoneResendToken = resendToken;
          _lastAttemptPhoneNumber = fullPhoneNumber;
          _isSendingPhoneOtp = false;
          setState(() => _isVerifyingPhone = false);

          // 5. Navigate to screen to enter OTP
          final verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfilEmailNumberVeifyOTP(
                countryCode: countryCode,
                mobileNumber: cleanPhone,
                verificationId: verificationId,
                resendToken: resendToken,
                initialAttemptId: attemptId,
              ),
            ),
          );

          if (verified == true && mounted) {
            setState(() {
              _originalPhone = cleanPhone;
            });
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            await userProvider.loadUserData();
            showToast(message: 'Mobile number verified successfully');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          PhoneVerifyLogger.log(
            attemptId: attemptId,
            caller: 'EditProfile.verificationFailed',
            event: 'FIREBASE_CALLBACK_VERIFICATION_FAILED',
            details: 'code=${e.code}, message=${e.message}',
          );

          if (!mounted) return;
          _isSendingPhoneOtp = false;
          setState(() => _isVerifyingPhone = false);
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
              errorMessage = e.message ?? 'Failed to send OTP. Try again.';
          }
          showToast(message: errorMessage);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          PhoneVerifyLogger.log(
            attemptId: attemptId,
            caller: 'EditProfile.codeAutoRetrievalTimeout',
            event: 'FIREBASE_CALLBACK_CODE_AUTO_RETRIEVAL_TIMEOUT',
          );
        },
        verificationCompleted: (PhoneAuthCredential credential) {
          PhoneVerifyLogger.log(
            attemptId: attemptId,
            caller: 'EditProfile.verificationCompleted',
            event: 'FIREBASE_CALLBACK_VERIFICATION_COMPLETED',
          );
        },
      );
    } catch (e) {
      PhoneVerifyLogger.log(
        attemptId: attemptId,
        caller: 'EditProfile._verifyPhone',
        event: 'ERROR_CAUGHT',
        details: e.toString(),
      );

      if (mounted) {
        _isSendingPhoneOtp = false;
        setState(() => _isVerifyingPhone = false);
        final errorMsg = e.toString().contains('Exception:')
            ? e.toString().replaceAll('Exception:', '').trim()
            : e.toString();
        showToast(message: errorMsg);
      }
    }
  }

  // ── Country picker ─────────────────────────────────────────────────────────
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerBottomSheet(
        selectedCountry: _selectedCountry,
        onCountrySelected: (country) {
          setState(() => _selectedCountry = country);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      helpText: 'Select date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
      });
      _checkChanges();
    }
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF898989),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isReadOnly,
    TextInputType keyboardType = TextInputType.text,
    String errorText = '',
    int? maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool showFocusBorder = true,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectiveShowFocusBorder =
        showFocusBorder && (!isReadOnly || controller.text.trim().isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: maxLines == 1 ? 48 : null,
          child: TextField(
            readOnly: isReadOnly,
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: AppTextStyles.subText.copyWith(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.w400,
            ),
            buildCounter: maxLength != null
                ? (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currentLength/$maxLength',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 12,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }
                : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.subText.copyWith(
                fontSize: 14.5,
                color: const Color(0XFF898989),
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: BorderSide(
                  color: errorText.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  effectiveShowFocusBorder ? 12 : AppRadius.card,
                ),
                borderSide: BorderSide(
                  color: errorText.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : (!effectiveShowFocusBorder
                            ? Theme.of(context).colorScheme.outline
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.3)
                                : Theme.of(context).colorScheme.primary)),
                  width: !effectiveShowFocusBorder ? 1.5 : 1,
                ),
              ),
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: AppTextStyles.subText.copyWith(
          fontSize: 15.3,
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            color: const Color(0xFFB3B3B3),
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.remove_red_eye_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF8E8E8E),
              size: 22,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCountryCodeButton() {
    return GestureDetector(
      onTap: _originalPhone.isNotEmpty
          ? null
          : _showCountryPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              _selectedCountry.dialCode,
              style: AppTextStyles.subText.copyWith(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF8A8A8A),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    final userProvider = Provider.of<UserProvider>(context);
    final profileUrl = userProvider.profile_picture;
    final imageBytes = profileUrl != null ? getProfileImage(profileUrl) : null;

    final ImageProvider avatarImage;
    if (imageBytes != null) {
      avatarImage = MemoryImage(imageBytes);
    } else if (profileUrl != null &&
        (profileUrl.startsWith('http') ||
            profileUrl.startsWith('/') ||
            profileUrl.contains('/'))) {
      final imageUrl = profileUrl.startsWith('http')
          ? profileUrl
          : (profileUrl.startsWith('/')
                ? '${ApiConfig.baseUrlImage}$profileUrl'
                : '${ApiConfig.baseUrlImage}/$profileUrl');
      avatarImage = NetworkImage(imageUrl);
    } else {
      avatarImage = AssetImage(Assets.images.icAvatar.path);
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: avatarImage,
            child: _isUploadingProfile
                ? Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.35),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingProfile ? null : _pickProfilePhoto,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.background,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  FeatherIcons.camera,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          dropdownColor: Theme.of(context).colorScheme.tertiaryContainer,
          isExpanded: true,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.5,
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xFF8A8A8A),
          ),
          items: _genderOptions.map((gender) {
            return DropdownMenuItem<String>(
              value: gender,
              child: Text(
                gender,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedGender = newValue);
              _checkChanges();
            }
          },
          iconEnabledColor: const Color(0XFF898989),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.editprofile,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _hasChanges
              ? IconButton(onPressed: _save, icon: const Icon(Icons.check))
              : const SizedBox(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          _buildAvatar(),
          const SizedBox(height: 28),

          // ── First Name ──────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.firstname),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _firstNameController,
            hint: AppLocalizations.of(context)!.enterfirstname,
            errorText: _firstNameErrorText,
            isReadOnly: false,
          ),
          const SizedBox(height: 16),

          // ── Last Name ───────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.lastname),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _lastNameController,
            hint: AppLocalizations.of(context)!.enterlastname,
            errorText: _lastNameErrorText,
            isReadOnly: false,
          ),
          const SizedBox(height: 16),

          // ── Username ────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.username),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _usernameController,
            hint: AppLocalizations.of(context)!.enterusername,
            errorText: _usernameErrorText,
            isReadOnly: false,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
          ),
          const SizedBox(height: 16),

          // ── Bio ─────────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.bio),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _bioController,
            hint: AppLocalizations.of(context)!.enterbio,
            maxLines: 3,
            maxLength: 150,
            keyboardType: TextInputType.multiline,
            isReadOnly: false,
          ),

          // ── Email ───────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.email),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _emailController,
            hint: AppLocalizations.of(context)!.enteryouremail,
            keyboardType: TextInputType.emailAddress,
            isReadOnly: _originalEmail.isNotEmpty,
            errorText: _emailErrorText,
            showFocusBorder: _originalEmail.isEmpty,
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isVerifyingEmail)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              GestureDetector(
                onTap: _isVerifyingEmail
                    ? null
                    : ((_emailController.text.trim() != _originalEmail &&
                              _emailController.text.trim().isNotEmpty)
                          ? _verifyEmail
                          : null),
                child: Text(
                  _isVerifyingEmail
                      ? AppLocalizations.of(context)!.verifying
                      : AppLocalizations.of(context)!.verify,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 14,
                    color:
                        (_isVerifyingEmail ||
                            (_emailController.text.trim() != _originalEmail &&
                                _emailController.text.trim().isNotEmpty))
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Phone ───────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.phonenumber),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildCountryCodeButton(),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: _phoneController,
                  hint: AppLocalizations.of(context)!.enteryourphonenumber,
                  keyboardType: TextInputType.phone,
                  isReadOnly: _originalPhone.isNotEmpty,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  showFocusBorder: _originalPhone.isEmpty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _isVerifyingPhone
                    ? null
                    : ((_phoneController.text.trim() != _originalPhone &&
                              _phoneController.text.trim().isNotEmpty)
                          ? _verifyPhone
                          : null),
                child: Text(
                  _isVerifyingPhone
                      ? AppLocalizations.of(context)!.verifying
                      : AppLocalizations.of(context)!.verify,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 14,
                    color:
                        (_isVerifyingPhone ||
                            (_phoneController.text.trim() != _originalPhone &&
                                _phoneController.text.trim().isNotEmpty))
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(AppLocalizations.of(context)!.dateofbirth),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dob != null
                          ? DateFormat('dd MMM yyyy').format(_dob!)
                          : AppLocalizations.of(context)!.selectyourdateofbirth,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: _dob != null
                            ? Theme.of(context).colorScheme.onBackground
                            : const Color(0xFFB3B3B3),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Color(0xFFB3B3B3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(AppLocalizations.of(context)!.gender),
          const SizedBox(height: 6),
          _buildGenderField(),
        ],
      ),
    );
  }
}
