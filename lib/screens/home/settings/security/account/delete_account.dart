// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../api/api_service.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../data/token/shared_preferences.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/loader.dart';
import '../../../../../widgets/show_toast.dart';
import '../../../../auth/social/social_login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with UtilityMixin {
  final _curPwCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;

  String? _currentPwError;

  @override
  void dispose() {
    _curPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      const cacheKeys = [
        'home_feed_cache',
        'home_feed_cache_time',
        'cached_notifications',
        'cached_friend_requests',
        'cached_user_profile',
        'cached_posts',
        'cached_followers',
        'cached_following',
      ];

      for (String key in cacheKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing caches: $e');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final password = _curPwCtrl.text.trim();
    if (password.isEmpty) {
      setState(() {
        _currentPwError = AppLocalizations.of(context)!.entercurrentpassword;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _currentPwError = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final apiService = ApiService();
      final result = await apiService.deleteAccount(password);

      if (result['success'] == true) {
        // Clear all session data (same as logout)
        await _clearAllCaches();
        await SharedPrefService.clearTokens();
        await SharedPrefService.clearFirstname();
        await SharedPrefService.clearLastname();
        await SharedPrefService.clearUsername();
        await SharedPrefService.clearUserBio();
        await SharedPrefService.removeFcmToken();
        await SharedPrefService.clearLanguage();

        if (mounted) {
          context.read<UserProvider>().clearUserData();
        }

        showToast(
          message: 'Account ${userProvider.username} deleted permanently',
        );
        if (mounted) {
          clearStackAndAddScreen(context, const SocialLoginScreen());
        }
      } else {
        setState(() {
          _currentPwError = result['message'] ?? 'Failed to delete account';
        });
      }
    } catch (e) {
      showToast(message: 'An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = context.watch<UserProvider>().username ?? '';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.deleteaccount),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(AppLocalizations.of(context)!.username),
            SizedBox(height: 8.h),
            _buildUsernameTextField(username),
            SizedBox(height: 16.h),
            _buildFieldLabel(AppLocalizations.of(context)!.currentpassword),
            SizedBox(height: 8.h),
            _buildPasswordTextField(
              controller: _curPwCtrl,
              hint: AppLocalizations.of(context)!.entercurrentpassword,
              obscure: _obscureCurrent,
              hasError: _currentPwError != null,
              onChanged: (_) => setState(() => _currentPwError = null),
              onToggleObscure: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            _buildError(_currentPwError),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  disabledBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: _isLoading
                    ? Loader(color: Colors.white)
                    : Text(
                        AppLocalizations.of(context)!.delete,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
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

  Widget _buildUsernameTextField(String username) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: TextEditingController(text: username),
        readOnly: true,
        enabled: false,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: isDark
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD),
              width: 1,
            ),
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

  Widget _buildPasswordTextField({
    required TextEditingController controller,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : isDark
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFDDDDDD),
              width: 0.7,
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
}
