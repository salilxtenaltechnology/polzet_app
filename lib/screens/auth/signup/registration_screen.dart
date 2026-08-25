// registration_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../data/token/shared_preferences.dart';
import '../../../main.dart';
import '../../../api/app_api.dart';
import '../../../api/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/country/country_model.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/show_toast.dart';
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

  final _countryLayerLink = LayerLink();
  OverlayEntry? _countryOverlayEntry;
  bool _isCountryDropdownOpen = false;
  double _countryFieldWidth = 0;
  final _countrySearchController = TextEditingController();

  // ── State ───────────────────────────────────────────────────────────────────
  DateTime? _dob;
  String _selectedCountry = 'India';
  String _selectedLanguage = 'English';

  static const Map<String, String> _languageCodeMap = {
    'Arabic': 'ar',
    'English': 'en',
    'German': 'de',
    'Hindi': 'hi',
    'Indonasian': 'id',
    'Indonesian': 'id',
    'Spanish': 'es',
    'Vietnamese': 'vi',
  };

  static const Map<String, String> _codeToLanguageMap = {
    'ar': 'Arabic',
    'en': 'English',
    'de': 'German',
    'hi': 'Hindi',
    'id': 'Indonasian',
    'es': 'Spanish',
    'vi': 'Vietnamese',
  };



  final List<String> _languages = const [
    'Arabic',
    'English',
    'German',
    'Hindi',
    'Indonasian',
    'Spanish',
    'Vietnamese',
  ];

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
    _initCountry();
    _loadInitialLanguage();
  }

  void _initCountry() {
    if (widget.verifiedCountryCode != null &&
        widget.verifiedCountryCode!.isNotEmpty) {
      final found = allCountries.firstWhere(
        (c) =>
            c.code.toLowerCase() ==
                widget.verifiedCountryCode!.toLowerCase() ||
            c.dialCode == widget.verifiedCountryCode,
        orElse: () => allCountries.firstWhere(
          (c) => c.name == 'India',
          orElse: () => allCountries.first,
        ),
      );
      _selectedCountry = found.name;
    } else {
      _selectedCountry = 'India';
    }
  }

  Future<void> _loadInitialLanguage() async {
    final savedCode = await SharedPrefService.getLanguage();
    if (savedCode != null && _codeToLanguageMap.containsKey(savedCode)) {
      if (mounted) {
        setState(() {
          _selectedLanguage = _codeToLanguageMap[savedCode]!;
        });
      }
    }
  }

  void _applyLanguage(String lang) {
    final code = _languageCodeMap[lang] ?? 'en';
    SharedPrefService.saveLanguage(code);
    if (mounted) {
      MyApp.of(context)?.changeLanguage(Locale(code));
    }
  }

  @override
  void dispose() {
    _closeCountryDropdown();
    _countrySearchController.dispose();
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

  // ── Country Dropdown Overlay Logic ──────────────────────────────────────────
  void _toggleCountryDropdown() {
    if (_isCountryDropdownOpen) {
      _closeCountryDropdown();
    } else {
      _openCountryDropdown();
    }
  }

  void _openCountryDropdown() {
    if (_countryOverlayEntry != null) return;

    _countrySearchController.clear();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    _countryOverlayEntry = OverlayEntry(
      builder: (context) {
        List<Country> currentFiltered = List.from(allCountries);

        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Stack(
              children: [
                // Dismiss on outside tap
                GestureDetector(
                  onTap: _closeCountryDropdown,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // Dropdown overlay menu positioned right below dropdown field
                Positioned(
                  width: _countryFieldWidth > 0
                      ? _countryFieldWidth
                      : (MediaQuery.of(context).size.width - 48.w),
                  child: CompositedTransformFollower(
                    link: _countryLayerLink,
                    showWhenUnlinked: false,
                    offset: Offset(0, 48.h + 6),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? const Color(0xFF1F1F23)
                          : Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1F1F23)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search field inside dropdown menu
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2A2A2E)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _countrySearchController,
                                  
                                  textAlignVertical: TextAlignVertical.center,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 13.5,
                                    color: txt.title,
                                  ),
                                  onChanged: (q) {
                                    setOverlayState(() {
                                      if (q.trim().isEmpty) {
                                        currentFiltered = List.from(allCountries);
                                      } else {
                                        final query = q.toLowerCase().trim();
                                        currentFiltered = allCountries.where((c) {
                                          return c.name
                                                  .toLowerCase()
                                                  .contains(query) ||
                                              c.code
                                                  .toLowerCase()
                                                  .contains(query);
                                        }).toList();
                                      }
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search country...',
                                    hintStyle: AppTextStyles.bodyText.copyWith(
                                      fontSize: 13.5,
                                      color: const Color(0xFF898989),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 19,
                                      color: Color(0xFF898989),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 40,
                                    ),
                                    suffixIcon: _countrySearchController.text.isNotEmpty
                                        ? IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 34,
                                              minHeight: 40,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Color(0xFF898989),
                                            ),
                                            onPressed: () {
                                              _countrySearchController.clear();
                                              setOverlayState(() {
                                                currentFiltered = List.from(allCountries);
                                              });
                                            },
                                          )
                                        : null,
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 40,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(right: 10),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.5),
                            // Filtered country list
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: currentFiltered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Text(
                                        'No country found',
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 13,
                                          color: txt.muted,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: currentFiltered.length,
                                      itemBuilder: (context, index) {
                                        final country = currentFiltered[index];
                                        final isSelected =
                                            country.name.toLowerCase() ==
                                                _selectedCountry.toLowerCase();

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedCountry = country.name;
                                            });
                                            _closeCountryDropdown();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            color: isSelected
                                                ? (isDarkMode
                                                    ? const Color(0xFF2A2A2E)
                                                    : const Color(0xFFF0F0F0))
                                                : Colors.transparent,
                                            child: Row(
                                              children: [
                                                Text(
                                                  country.flag,
                                                  style: const TextStyle(fontSize: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    country.name,
                                                    style: AppTextStyles.bodyText.copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      color: txt.title,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_countryOverlayEntry!);
    setState(() {
      _isCountryDropdownOpen = true;
    });
  }

  void _closeCountryDropdown() {
    _countryOverlayEntry?.remove();
    _countryOverlayEntry = null;
    if (mounted) {
      setState(() {
        _isCountryDropdownOpen = false;
      });
    }
  }

  // ── Real-time Password Validator ─────────────────────────────────────────────
  void _onFocusChange() {
    if (_passwordFocusNode.hasFocus && _passwordCtrl.text.isNotEmpty) {
      final text = _passwordCtrl.text;
      final score = _getStrengthScore(text);
      if (score < 5) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    } else {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    if (_passwordFocusNode.hasFocus && _passwordCtrl.text.isNotEmpty) {
      final text = _passwordCtrl.text;
      final score = _getStrengthScore(text);
      if (score < 5) {
        _showOverlay();
        _overlayEntry?.markNeedsBuild();
      } else {
        _hideOverlay();
      }
    } else {
      _hideOverlay();
    }
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
    final neutralColor = isDark
        ? const Color(0xFF333333)
        : const Color(0xFFE5E5E5);

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
              _buildRequirementRow(
                '8 - 10 characters',
                _hasLength(text),
                isDark,
              ),
              SizedBox(height: 10.h),
              _buildRequirementRow(
                'At least 1 uppercase letter',
                _hasUppercase(text),
                isDark,
              ),
              SizedBox(height: 10.h),
              _buildRequirementRow(
                'At least 1 lowercase letter',
                _hasLowercase(text),
                isDark,
              ),
              SizedBox(height: 10.h),
              _buildRequirementRow(
                'At least 1 number',
                _hasNumber(text),
                isDark,
              ),
              SizedBox(height: 10.h),
              _buildRequirementRow(
                'At least 1 special character',
                _hasSpecialChar(text),
                isDark,
              ),
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
    if (_selectedCountry.isEmpty || _selectedLanguage.isEmpty) {
      showToast(message: 'Please select a country and language');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
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
        _passwordError = AppLocalizations.of(
          context,
        )!.mustbeeightpluscharacterswithaletternumberandspecialcharacter;
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
            onPrimary: Colors.white,
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
    if (!_validateStep3()) return;

    setState(() {
      _isLoading = true;
      _generalError = '';
    });

    try {
      final dio = Dio();
      final countryObj = allCountries.firstWhere(
        (c) =>
            c.name.toLowerCase() == _selectedCountry.toLowerCase() ||
            c.code.toLowerCase() == _selectedCountry.toLowerCase(),
        orElse: () => allCountries.first,
      );
      final body = {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': widget.verifiedEmail ?? '',
        'password': _passwordCtrl.text,
        'mobile_number': widget.verifiedPhone ?? '',
        'country_code': widget.verifiedCountryCode ?? '',
        'country': countryObj.code.toUpperCase(),
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
    _closeCountryDropdown();
    if (_step == 0 && _validateStep0()) {
      setState(() => _step = 1);
    } else if (_step == 1 && _validateStep1()) {
      setState(() => _step = 2);
    } else if (_step == 2 && _validateStep2()) {
      _applyLanguage(_selectedLanguage);
      setState(() => _step = 3);
    }
  }

  void _onBack() {
    _closeCountryDropdown();
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
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
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
            ],
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
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
            ],
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
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            cursorColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.8),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.7),
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

  // ── Step 2: Country & App Language ───────────────────────────────────────────
  Widget _buildStep2() {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Select Country Label
        Text(
          'Select Country',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: txt.title,
          ),
        ),
        const SizedBox(height: 8),

        // ── Country Dropdown Box
        LayoutBuilder(
          builder: (context, constraints) {
            _countryFieldWidth = constraints.maxWidth;
            final selectedCountryObj = allCountries.firstWhere(
              (c) =>
                  c.name.toLowerCase() == _selectedCountry.toLowerCase() ||
                  c.code.toLowerCase() == _selectedCountry.toLowerCase(),
              orElse: () => allCountries.firstWhere(
                (c) => c.name == 'India',
                orElse: () => allCountries.first,
              ),
            );

            return CompositedTransformTarget(
              link: _countryLayerLink,
              child: InkWell(
                onTap: _toggleCountryDropdown,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.background
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(selectedCountryObj.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedCountryObj.name,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isCountryDropdownOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: txt.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Language Label
        Text(
          'App Language',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: txt.title,
          ),
        ),
        const SizedBox(height: 12),

        // ── Language Chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _languages.map((lang) {
            final isSelected = _selectedLanguage == lang;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLanguage = lang;
                });
                _applyLanguage(lang);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDarkMode ? Colors.transparent : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Text(
                  lang,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: isSelected ? Colors.white : txt.title,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Step 3: Password ─────────────────────────────────────────────────────────
  Widget _buildStep3() {
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
    final isLastStep = _step == 3;
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
      case 2:
        return 'Personalize your feed';
      default:
        return 'Set your password';
    }
  }

  String get _subtitle {
    if (_step == 2) {
      return 'Tell us what you like to see on Polzet';
    }
    return '';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: _title,
        showBackButton: _step > 0,
        onBack: _onBack,
        titleSpacing: _step > 0 ? 4.w : 20.w,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_subtitle.isNotEmpty) ...[
                Text(
                  _subtitle,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 14.5,
                    color: isDarkMode
                        ? const Color(0XFFB3B3B3)
                        : const Color(0XFF707070),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                      : _step == 2
                      ? _buildStep2()
                      : _buildStep3(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPrimaryButton(),
              const SizedBox(height: 14),
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
