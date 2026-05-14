// registration_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../api/app_api.dart';
import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/loader.dart';
import '../account/account_success_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String? verifiedEmail;
  final String? verifiedPhone;
  final String? verifiedCountryCode;

  const RegistrationScreen({
    super.key,
    this.verifiedEmail,
    this.verifiedPhone,
    this.verifiedCountryCode,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with UtilityMixin {
  // ── Step ────────────────────────────────────────────────────────────────────
  int _step = 0;

  // ── Controllers ─────────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  // ── State ───────────────────────────────────────────────────────────────────
  DateTime? _dob;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // per-step errors
  String _firstNameError = '';
  String _lastNameError = '';
  String _dobError = '';
  String _usernameError = '';
  String _passwordError = '';
  String _confirmPwError = '';
  String _generalError = '';

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool?
  _isUsernameAvailable; // null = not checked, true = available, false = taken
  String _usernameStatusMessage = '';

  // ── Dispose ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────────
  bool _validateStep0() {
    bool ok = true;
    setState(() {
      _firstNameError = _lastNameError = _dobError = '';
      if (_firstNameCtrl.text.trim().isEmpty) {
        _firstNameError = 'Please enter your first name';
        ok = false;
      }
      if (_lastNameCtrl.text.trim().isEmpty) {
        _lastNameError = 'Please enter your last name';
        ok = false;
      }
      if (_dob == null) {
        _dobError = 'Please select your date of birth';
        ok = false;
      }
    });
    return ok;
  }

  bool _validateStep1() {
    bool ok = true;
    setState(() {
      _usernameError = '';
      if (_usernameCtrl.text.trim().isEmpty) {
        _usernameError = 'Please enter a username';
        ok = false;
      } else if (_isUsernameAvailable == false) {
        _usernameError = _usernameStatusMessage.isNotEmpty
            ? _usernameStatusMessage
            : 'Username is already taken';
        ok = false;
      } else if (_isUsernameAvailable == null) {
        _usernameError = 'Please wait for username availability check';
        ok = false;
      }
    });
    return ok;
  }

  // ── Username availability check (debounced 600ms) ────────────────────────────
  void _onUsernameChanged(String value) {
    setState(() {
      _usernameError = '';
      _isUsernameAvailable = null;
      _usernameStatusMessage = '';
    });

    _usernameDebounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length < 3) return;

    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isCheckingUsername = true);

      final result = await ApiService().checkUsername(username: trimmed);

      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = result['available'] as bool;
        _usernameStatusMessage = result['message'] as String;

        // Also surface taken error inline
        if (_isUsernameAvailable == false) {
          _usernameError = _usernameStatusMessage;
        }
      });
    });
  }

  bool _validateStep2() {
    bool ok = true;
    setState(() {
      _passwordError = _confirmPwError = '';
      final pw = _passwordCtrl.text;

      final passwordRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
      );

      if (pw.isEmpty) {
        _passwordError = 'Please create a password';
        ok = false;
      } else if (!passwordRegex.hasMatch(pw)) {
        _passwordError =
            'Password must be 8+ characters with uppercase, lowercase, number & special character';
        ok = false;
      }

      if (_confirmPwCtrl.text.isEmpty) {
        _confirmPwError = 'Please confirm your password';
        ok = false;
      } else if (_confirmPwCtrl.text != pw) {
        _confirmPwError = 'Passwords do not match';
        ok = false;
      }
    });
    return ok;
  }

  // ── Date Picker ──────────────────────────────────────────────────────────────
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
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobError = '';
      });
    }
  }

  // ── Registration API ─────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_validateStep2()) return;

    setState(() {
      _isLoading = true;
      _generalError = '';
    });

    try {
      final dio = Dio();
      final body = {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': widget.verifiedEmail ?? '',
        'password': _passwordCtrl.text,
        'mobile_number': widget.verifiedPhone ?? '',
        'country_code': widget.verifiedCountryCode ?? '',
        'dob': DateFormat('yyyy-MM-dd').format(_dob!),
      };

      final response = await dio.post(ApiConstants.registration, data: body);

      if (!mounted) return;

      debugPrint('REGISTER : $response');

      if (response.statusCode == 201) {
        // showToast(message: 'Account created successfully');
        navigationPushReplacement(
          context,
          AccountSuccessScreen(
            email: widget.verifiedEmail ?? '',
            password: _passwordCtrl.text,
          ),
        );
      } else {
        setState(
          () =>
              _generalError = response.data['message'] ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      setState(
        () => _generalError =
            e.response?.data['message'] ?? 'Something went wrong',
      );
    } catch (e) {
      setState(() => _generalError = 'Connection error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Next / Back ──────────────────────────────────────────────────────────────
  void _onContinue() {
    if (_step == 0 && _validateStep0()) {
      setState(() => _step = 1);
    } else if (_step == 1 && _validateStep1()) {
      setState(() => _step = 2);
    }
  }

  void _onBack() {
    if (_step > 0) setState(() => _step--);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _buildLabel(String text) => Text(
    text,
    style: AppTextStyles.cardTitle.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w400,
      color: const Color(0xFF2C2C2C),
    ),
  );

  Widget _buildError(String error) {
    if (error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        error,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.subText.copyWith(
      fontSize: 14.5,
      color: const Color(0xFFB3B3B3),
      fontWeight: FontWeight.w400,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.error,
        width: 1,
      ),
    ),
    filled: true,
    fillColor: Colors.white,
  );

  // ── Step 0: Personal Info ────────────────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('First Name'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _firstNameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _firstNameError = ''),
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
            decoration: _fieldDecoration('Enter your first name'),
          ),
        ),
        _buildError(_firstNameError),
        const SizedBox(height: 18),

        _buildLabel('Last Name'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _lastNameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _lastNameError = ''),
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
            decoration: _fieldDecoration('Enter your last name'),
          ),
        ),
        _buildError(_lastNameError),
        const SizedBox(height: 18),

        _buildLabel('Date of Birth'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _dobError.isNotEmpty
                    ? Theme.of(context).colorScheme.error
                    : const Color(0xFFDDDDDD),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dob != null
                        ? DateFormat('dd MMM yyyy').format(_dob!)
                        : 'Select your date of birth',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: _dob != null
                          ? const Color(0xFF404040)
                          : const Color(0xFFB3B3B3),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: _dob != null
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFB3B3B3),
                ),
              ],
            ),
          ),
        ),
        _buildError(_dobError),
      ],
    );
  }

  // ── Step 1: Username ─────────────────────────────────────────────────────────
  Widget _buildStep1() {
    // Suffix icon: loader → tick → cross
    Widget? suffixIcon;
    if (_isCheckingUsername) {
      suffixIcon = const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 1.8),
        ),
      );
    } else if (_isUsernameAvailable == true) {
      suffixIcon = const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF16A34A),
        size: 20,
      );
    } else if (_isUsernameAvailable == false) {
      suffixIcon = Icon(
        Icons.cancel_rounded,
        color: Theme.of(context).colorScheme.error,
        size: 20,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Username'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _usernameCtrl,
            onChanged: _onUsernameChanged,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
            decoration: InputDecoration(
              hintText: 'Enter a valid username',
              hintStyle: AppTextStyles.subText.copyWith(
                fontSize: 14.5,
                color: const Color(0xFFB3B3B3),
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: suffixIcon,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // Status message below field
        if (_usernameStatusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              _usernameStatusMessage,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12,
                color: _isUsernameAvailable == true
                    ? const Color(0xFF16A34A)
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),

        _buildError(_usernameError.isEmpty ? '' : ''),
      ],
    );
  }

  // ── Step 2: Password ─────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Create Password'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() => _passwordError = ''),
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
            decoration: _fieldDecoration('Create your password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF8A8A8A),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ),
        _buildError(_passwordError),
        const SizedBox(height: 18),

        _buildLabel('Confirm Password'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _confirmPwCtrl,
            obscureText: _obscureConfirm,
            onChanged: (_) => setState(() => _confirmPwError = ''),
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
            decoration: _fieldDecoration('Confirm your password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF8A8A8A),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ),
        _buildError(_confirmPwError),

        if (_generalError.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildError(_generalError),
        ],
      ],
    );
  }

  // ── Primary Button ───────────────────────────────────────────────────────────
  Widget _buildPrimaryButton() {
    final isLastStep = _step == 2;
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                if (isLastStep) {
                  _register();
                } else {
                  _onContinue();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? Loader(color: Colors.white)
            : Text(
                isLastStep ? 'Sign Up' : 'Continue',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  // color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ── Titles ───────────────────────────────────────────────────────────────────
  String get _title {
    switch (_step) {
      case 0:
        return 'Create your account';
      case 1:
        return 'Choose a username';
      default:
        return 'Set your password';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step > 0)
                GestureDetector(
                  onTap: _onBack,
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),

              const SizedBox(height: 60),

              Text(
                _title,
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 32),

              // Step content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _step == 0
                      ? _buildStep0()
                      : _step == 1
                      ? _buildStep1()
                      : _buildStep2(),
                ),
              ),

              const SizedBox(height: 30),
              _buildPrimaryButton(),
              const SizedBox(height: 16),

              // Already have an account
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13.5,
                        color: const Color(0xFF8A8A8A),
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
