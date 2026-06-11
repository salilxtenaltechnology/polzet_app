// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../api/services/api_service.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/loader.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with UtilityMixin {
  final _curPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  final _newPwFocusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _currentPwError;
  String? _newPwError;
  String? _confirmPwError;

  @override
  void initState() {
    super.initState();
    _newPwFocusNode.addListener(_onFocusChange);
    _newPwCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    _newPwFocusNode.removeListener(_onFocusChange);
    _newPwFocusNode.dispose();
    _newPwCtrl.removeListener(_onTextChanged);
    _curPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_newPwFocusNode.hasFocus && _newPwCtrl.text.isNotEmpty) {
      final score = _getStrengthScore(_newPwCtrl.text);
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
    if (_newPwFocusNode.hasFocus && _newPwCtrl.text.isNotEmpty) {
      final score = _getStrengthScore(_newPwCtrl.text);
      if (score < 5) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    } else {
      _hideOverlay();
    }
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
          width: MediaQuery.of(context).size.width - 32.w,
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
    final text = _newPwCtrl.text;
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
    // final inactiveColor = isDark ? const Color(0xFF666666) : const Color(0xFF555555);
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

  bool _validate() {
    String? curErr, newErr, conErr;

    if (_curPwCtrl.text.trim().isEmpty) {
      curErr = AppLocalizations.of(context)!.currentpasswordisrequired;
    }

    if (_newPwCtrl.text.trim().isEmpty) {
      newErr = AppLocalizations.of(context)!.newpasswordisrequired;
    } else if (!_hasLength(_newPwCtrl.text) ||
        !_hasUppercase(_newPwCtrl.text) ||
        !_hasLowercase(_newPwCtrl.text) ||
        !_hasNumber(_newPwCtrl.text) ||
        !_hasSpecialChar(_newPwCtrl.text)) {
      newErr = AppLocalizations.of(context)!
          .mustbeeightpluscharacterswithaletternumberandspecialcharacter;
    }

    if (_confirmPwCtrl.text.trim().isEmpty) {
      conErr = AppLocalizations.of(context)!.pleaseconfirmyournewpassword;
    } else if (_newPwCtrl.text.trim() != _confirmPwCtrl.text.trim()) {
      conErr = AppLocalizations.of(context)!.passworddonotmatch;
    }

    setState(() {
      _currentPwError = curErr;
      _newPwError = newErr;
      _confirmPwError = conErr;
    });

    return curErr == null && newErr == null && conErr == null;
  }

  Future<void> _changePassword() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    final result = await ApiService().changePassword(
      currentPassword: _curPwCtrl.text.trim(),
      newPassword: _newPwCtrl.text.trim(),
      confirmNewPassword: _confirmPwCtrl.text.trim(),
      onError: (curErr, newErr, conErr) {
        if (mounted) {
          setState(() {
            _currentPwError = curErr;
            _newPwError = newErr;
            _confirmPwError = conErr;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isEmpty) {
      // Success — clear fields and pop
      _curPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      Navigator.of(context).pop();
    } else {
      // showToast(message: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.changepassword),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(AppLocalizations.of(context)!.currentpassword),
            SizedBox(height: 8.h),
            _buildTextField(
              controller: _curPwCtrl,
              hint: AppLocalizations.of(context)!.entercurrentpassword,
              obscure: _obscureCurrent,
              hasError: _currentPwError != null,
              onChanged: (_) => setState(() => _currentPwError = null),
              onToggleObscure: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            _buildError(_currentPwError),
            SizedBox(height: 16.h),
            _buildFieldLabel(AppLocalizations.of(context)!.newpassword),
            SizedBox(height: 8.h),
            CompositedTransformTarget(
              link: _layerLink,
              child: _buildTextField(
                controller: _newPwCtrl,
                focusNode: _newPwFocusNode,
                hint: AppLocalizations.of(context)!.enternewpassword,
                obscure: _obscureNew,
                hasError: _newPwError != null,
                onChanged: (_) => setState(() => _newPwError = null),
                onToggleObscure: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            _buildError(_newPwError),
            SizedBox(height: 16.h),
            _buildFieldLabel(AppLocalizations.of(context)!.confirmpassword),
            SizedBox(height: 8.h),
            _buildTextField(
              controller: _confirmPwCtrl,
              hint: AppLocalizations.of(context)!.enterconfirmpassword,
              obscure: _obscureConfirm,
              hasError: _confirmPwError != null,
              onChanged: (_) => setState(() => _confirmPwError = null),
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            _buildError(_confirmPwError),
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () {},
              child: Text(
                AppLocalizations.of(context)!.forgotyourpassword,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  disabledBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: _isLoading
                    ? Loader(color: Colors.white)
                    : Text(
                        'Continue',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final txt = AppTextColors.of(context);
    return Text(
      label,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: txt.title,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hint,
    required bool obscure,
    required bool hasError,
    required ValueChanged<String> onChanged,
    required VoidCallback onToggleObscure,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        onChanged: onChanged,
        cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        cursorWidth: 1.5,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).colorScheme.onBackground,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: isDark ? const Color(0xFFB3B3B3) : const Color(0xFF898989),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : isDark
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD),
              width: hasError ? 1.2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              width: 0.7,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF8A8A8A),
            ),
            onPressed: onToggleObscure,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String? error) {
    if (error == null || error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 6.h, left: 4.w),
      child: Text(
        error,
        style: AppTextStyles.subText.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
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
