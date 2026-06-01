// registration_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../api/app_api.dart';
import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
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

  final _passwordFocusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

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

  // ── Init & Dispose ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(_onFocusChange);
    _passwordCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    _passwordFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.dispose();
    _passwordCtrl.removeListener(_onTextChanged);
    _usernameDebounce?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  // ── Real-time Password Validator ─────────────────────────────────────────────
  void _onFocusChange() {
    if (_passwordFocusNode.hasFocus) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: MediaQuery.of(context).size.width - 48.w,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, 48.h + 4.h),
            child: Material(
              color: Colors.transparent,
              child: _buildValidatorPopup(context),
            ),
          ),
        );
      },
    );
  }

  bool _hasLength(String val) => val.length >= 8;
  bool _hasUppercase(String val) => val.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String val) => val.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String val) => val.contains(RegExp(r'[0-9]'));
  bool _hasSpecialChar(String val) => val.contains(RegExp(r'[^A-Za-z0-9]'));

  int _getStrengthScore(String val) {
    int score = 0;
    if (_hasLength(val)) score++;
    if (_hasUppercase(val)) score++;
    if (_hasLowercase(val)) score++;
    if (_hasNumber(val)) score++;
    if (_hasSpecialChar(val)) score++;
    return score;
  }

  Widget _buildValidatorPopup(BuildContext context) {
    final text = _passwordCtrl.text;
    final score = _getStrengthScore(text);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color strengthColor;
    String strengthLabel;
    int segmentsFilled;

    if (text.isEmpty) {
      strengthColor = isDark ? Colors.white38 : Colors.black38;
      strengthLabel = 'Weak password';
      segmentsFilled = 0;
    } else if (score <= 2) {
      strengthColor = const Color(0xFFE53935); // Red
      strengthLabel = 'Weak password';
      segmentsFilled = score == 0 ? 1 : score;
    } else if (score <= 3) {
      strengthColor = const Color(0xFFE0A900); // Yellow/Orange
      strengthLabel = 'Good password';
      segmentsFilled = 3;
    } else {
      strengthColor = const Color(0xFF2E7D32); // Green
      strengthLabel = 'Strong password';
      segmentsFilled = score;
    }

    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final neutralColor = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 32.w),
          child: CustomPaint(
            size: Size(16.w, 8.h),
            painter: TrianglePainter(color: cardBgColor),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    strengthLabel,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: strengthColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: List.generate(5, (index) {
                  final isFilled = index < segmentsFilled;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 5,
                      margin: EdgeInsets.only(right: index < 4 ? 6.w : 0),
                      decoration: BoxDecoration(
                        color: isFilled ? strengthColor : neutralColor,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 18.h),
              _buildRequirementRow('8 - 10 characters', _hasLength(text), isDark),
              SizedBox(height: 10.h),
              _buildRequirementRow('At least 1 uppercase letter', _hasUppercase(text), isDark),
              SizedBox(height: 10.h),
              _buildRequirementRow('At least 1 lowercase letter', _hasLowercase(text), isDark),
              SizedBox(height: 10.h),
              _buildRequirementRow('At least 1 number', _hasNumber(text), isDark),
              SizedBox(height: 10.h),
              _buildRequirementRow('At least 1 special character', _hasSpecialChar(text), isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String requirement, bool isMet, bool isDark) {
    final txt = AppTextColors.of(context);
    const activeGreen = Color(0xFF16A34A);
    final inactiveColor = txt.body;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isMet
                ? activeGreen
                : (isDark ? txt.muted : inactiveColor.withOpacity(0.3)),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 13, color: Colors.white),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isMet ? activeGreen : (isDark ? txt.muted : inactiveColor),
            ),
            child: Text(requirement),
          ),
        ),
      ],
    );
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

      if (pw.isEmpty) {
        _passwordError = 'Please create a password';
        ok = false;
      } else if (!_hasLength(pw) ||
          !_hasUppercase(pw) ||
          !_hasLowercase(pw) ||
          !_hasNumber(pw) ||
          !_hasSpecialChar(pw)) {
        _passwordError = AppLocalizations.of(context)!
            .mustbeeightpluscharacterswithaletternumberandspecialcharacter;
        ok = false;
      }

      if (_confirmPwCtrl.text.isEmpty) {
        _confirmPwError = 'Please confirm your password';
        ok = false;
      } else if (_confirmPwCtrl.text != pw) {
        _confirmPwError = AppLocalizations.of(context)!.passworddonotmatch;
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
  Widget _buildLabel(String text) {
    final txt = AppTextColors.of(context);
    return Text(
      text,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: txt.title,
      ),
    );
  }

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

  InputDecoration _fieldDecoration(String hint) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.subText.copyWith(
        fontSize: 14.5,
        color: isDarkMode ? const Color(0XFFB3B3B3) : const Color(0XFF898989),
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode
              ? Theme.of(context).colorScheme.outline
              : const Color(0xFFDDDDDD),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          width: 0.7,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 0.7,
        ),
      ),
    );
  }

  // ── Step 0: Personal Info ────────────────────────────────────────────────────
  Widget _buildStep0() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            cursorColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.8),
            cursorWidth: 1.5,
            style: AppTextStyles.subText.copyWith(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.w400,
            ),
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
            style: AppTextStyles.subText.copyWith(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.w400,
            ),
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
              color: Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Theme.of(context).colorScheme.outline
                    : const Color(0xFFDDDDDD),
                width: 0.7,
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
                          ? (isDarkMode
                                ? Colors.white
                                : const Color(0xFF404040))
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        cursorWidth: 1.5,
        style: AppTextStyles.subText.copyWith(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w400,
        ),
            decoration: InputDecoration(
              hintText: 'Enter a valid username',
              hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            color: isDarkMode
                ? const Color(0XFFB3B3B3)
                : const Color(0XFF898989),
            fontWeight: FontWeight.w400,
          ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: suffixIcon,
              enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD),
              width: 0.7,
            ),
          ),
              focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              width: 0.7,
            ),
          ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 0.7,
                ),
              ),
            
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
        CompositedTransformTarget(
          link: _layerLink,
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              onChanged: (_) {
                setState(() => _passwordError = '');
                _overlayEntry?.markNeedsBuild();
              },
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
    final txt = AppTextColors.of(context);
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
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Theme.of(context).colorScheme.onBackground,
                    size: 20,
                  ),
                ),

              const SizedBox(height: 60),

              Text(
                _title,
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
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
                        fontSize: 14,
                        color: txt.muted,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
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

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
