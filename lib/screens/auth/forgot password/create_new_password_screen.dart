// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/loader.dart';
import 'success_password_screen.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  final String resetToken;

  const CreateNewPasswordScreen({super.key, required this.resetToken});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen>
    with UtilityMixin {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  final _newPwFocusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  String _passwordError = '';
  String _confirmPwError = '';
  String _generalError = '';

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

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

  bool _validation() {
    bool ok = true;
    setState(() {
      _passwordError = _confirmPwError = _generalError = '';
      final pw = _newPwCtrl.text;

      if (pw.isEmpty) {
        _passwordError = AppLocalizations.of(context)!.newpasswordisrequired;
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
        _confirmPwError = AppLocalizations.of(context)!.pleaseconfirmyournewpassword;
        ok = false;
      } else if (_confirmPwCtrl.text != pw) {
        _confirmPwError = AppLocalizations.of(context)!.passworddonotmatch;
        ok = false;
      }
    });
    return ok;
  }

  // ── Reset Password API ────────────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    if (_isLoading || !_validation()) return;

    setState(() {
      _isLoading = true;
      _generalError = '';
    });

    try {
      final result = await ApiService().forgotNewPassword(
        resetToken: widget.resetToken,
        newPassword: _newPwCtrl.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        navigationPushReplacement(context, const SuccessPasswordScreen());
      } else {
        // Handles: "Invalid or expired token" or any other API error
        setState(
          () => _generalError = result['message'] ?? 'Failed to reset password',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _generalError = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _buildError(String error) {
    if (error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        error,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final txt = AppTextColors.of(context);
    return Text(
      label,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: txt.title,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {bool hasError = false}) {
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
    );
  }

  Widget _buildResetPasswordButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
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
            : const Text(
                'Reset password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Text(
                'Create new password',
                style: AppTextStyles.subSectionHeading.copyWith(
                  fontSize: 23,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 30),

              // ── New Password ──────────────────────────────────────────────────
              _buildFieldLabel('New Password'),
              const SizedBox(height: 10),
              CompositedTransformTarget(
                link: _layerLink,
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _newPwCtrl,
                    focusNode: _newPwFocusNode,
                    obscureText: _obscurePassword,
                    onChanged: (_) {
                      setState(() => _passwordError = '');
                      _overlayEntry?.markNeedsBuild();
                    },
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration:
                        _fieldDecoration(
                          'Enter new password',
                          hasError: _passwordError.isNotEmpty,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: const Color(0xFF8A8A8A),
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              _buildError(_passwordError),

              const SizedBox(height: 20),

              // ── Confirm Password ──────────────────────────────────────────────
              _buildFieldLabel('Confirm Password'),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _confirmPwCtrl,
                  obscureText: _obscureConfirm,
                  onChanged: (_) => setState(() => _confirmPwError = ''),
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration:
                      _fieldDecoration(
                        'Confirm your password',
                        hasError: _confirmPwError.isNotEmpty,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF8A8A8A),
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                ),
              ),
              _buildError(_confirmPwError),

              // ── General / API error ───────────────────────────────────────────
              if (_generalError.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildError(_generalError),
              ],

              const SizedBox(height: 30),
              _buildResetPasswordButton(),
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
