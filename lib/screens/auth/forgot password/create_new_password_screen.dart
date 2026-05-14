// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_styles.dart';
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
  String _passwordError = '';
  String _confirmPwError = '';
  String _generalError = '';

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  bool _validation() {
    bool ok = true;
    setState(() {
      _passwordError = _confirmPwError = _generalError = '';
      final pw = _newPwCtrl.text;

      final passwordRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
      );

      if (pw.isEmpty) {
        _passwordError = 'Please enter a new password';
        ok = false;
      } else if (!passwordRegex.hasMatch(pw)) {
        _passwordError =
            'Password must be 8+ characters with uppercase, lowercase, number & special character';
        ok = false;
      }

      if (_confirmPwCtrl.text.isEmpty) {
        _confirmPwError = 'Please enter confirm password';
        ok = false;
      } else if (_confirmPwCtrl.text != pw) {
        _confirmPwError = 'Passwords do not match';
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
        setState(() => _generalError = result['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = 'Something went wrong. Please try again.');
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
        style: AppTextStyles.bodyText.copyWith(fontSize: 12, color: Colors.red),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF2C2C2C),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {bool hasError = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.subText.copyWith(
          fontSize: 14.5,
          color: const Color(0xFFB3B3B3),
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? Colors.red : const Color(0xFFDDDDDD),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? Colors.red : Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      );

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
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 30),

              // ── New Password ──────────────────────────────────────────────────
              _buildFieldLabel('New Password'),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _newPwCtrl,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() => _passwordError = ''),
                  style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
                  decoration: _fieldDecoration(
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
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
                  style: const TextStyle(fontSize: 14.5, color: Color(0xFF404040)),
                  decoration: _fieldDecoration(
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
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
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