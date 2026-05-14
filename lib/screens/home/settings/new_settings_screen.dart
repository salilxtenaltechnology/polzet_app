// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/app_api.dart';
import '../../../api/services/api_service.dart';
import '../../../core/themes/theme_provider.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../main.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/dialog/custom_diolog.dart';
import '../../../widgets/show_toast.dart';
import '../../auth/login/login_import.dart';
import '../../auth/social/social_login_screen.dart';
import 'account/private_account.dart';
import 'block/block_account.dart';
import 'feedback/feedback.dart';
import 'help and support/help_support.dart';
import 'language/language_import.dart';
import 'notifications/notifications.dart';
import 'privacy/privacy_policy.dart';
import 'security/security.dart';
import 'terms and policy/terms_and_conditions.dart';

class NewSettingsScreen extends StatefulWidget {
  const NewSettingsScreen({super.key});

  @override
  State<NewSettingsScreen> createState() => _NewSettingsScreenState();
}

class _NewSettingsScreenState extends State<NewSettingsScreen>
    with UtilityMixin, WidgetsBindingObserver {
  final ApiService apiService = ApiService();
  String _errorText = '';

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

  Future<void> _logout() async {
    final accessToken = await SharedPrefService.getToken(); // ac_token
    final refreshToken = await SharedPrefService.getRefreshToken(); // re_token

    showLoadingDialog(context);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.logout),
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 205) {
        await _clearAllCaches();
        await SharedPrefService.clearTokens();
        await SharedPrefService.clearFirstname();
        await SharedPrefService.clearLastname();
        await SharedPrefService.clearUsername();
        await SharedPrefService.clearUserBio();
        await SharedPrefService.removeFcmToken();
        await SharedPrefService.clearLanguage();
        MyApp.of(context)?.resetLocale();

        if (mounted) {
          context.read<UserProvider>().clearUserData();
        }

        clearStackAndAddScreen(context, const SocialLoginScreen());
        showToast(message: 'Logged out successfully');
      } else {
        showToast(message: 'Token expired');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorText = 'An error occurred. Please try again later.';
      });
    } finally {}
  }

  Future<void> _deleteAccount(String password) async {
    showLoadingDialog(context);
    try {
      final userProvider = context.read<UserProvider>();
      final apiService = ApiService();
      final result = await apiService.deleteAccount(password);

      Navigator.pop(context); // close loading dialog

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

        Navigator.pop(context);
        showToast(
          message: 'Account ${userProvider.username} deleted permanently',
        );
        clearStackAndAddScreen(context, const LoginScreen());
      } else {
        showToast(message: result['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      Navigator.pop(context);
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      resizeToAvoidBottomInset: false,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.settings),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Dark Mode ─────────────────────────────────────
              _buildCard(
                children: [
                  _buildToggleTile(
                    icon: Assets.images.icDarkmode.path,
                    title: AppLocalizations.of(context)!.darkmode,
                    subtitle: 'Ask opinions & get answers',
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ── Account ───────────────────────────────────────
              _buildSectionLabel('Account'),
              const SizedBox(height: 8),
              _buildCard(
                children: [
                  _buildNavTile(
                    icon: Assets.images.icSecurity.path,
                    title: AppLocalizations.of(context)!.security,
                    subtitle: 'Update your password and secure your account.',
                    onTap: () {
                      navigationPush(context, const Security());
                    },
                  ),
                  _buildDivider(),
                  _buildNavTile(
                    icon: Assets.images.icAccountPrivacy.path,
                    title: AppLocalizations.of(context)!.accountprivacy,
                    subtitle: 'Control who can view your activity and polls',
                    onTap: () {
                      navigationPush(context, const PrivateAccount());
                    },
                  ),
                  _buildDivider(),
                  _buildNavTile(
                    icon: Assets.images.icBlockAccount.path,
                    title: AppLocalizations.of(context)!.blockedaccounts,
                    subtitle: "Manage people you've blocked on Polzet",
                    onTap: () {
                      navigationPush(context, const BlockAccounts());
                    },
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ── Preferences ───────────────────────────────────
              _buildSectionLabel('Preferences'),
              const SizedBox(height: 8),
              _buildCard(
                children: [
                  _buildNavTile(
                    icon: Assets.images.icNotifications.path,
                    title: AppLocalizations.of(context)!.notifications,
                    subtitle:
                        'Choose what updates and alerts you want to receive.',
                    onTap: () {
                      navigationPush(context, const NotificationsSettings());
                    },
                  ),
                  _buildDivider(),
                  _buildNavTile(
                    icon: Assets.images.icLanguage.path,
                    title: AppLocalizations.of(context)!.language,
                    subtitle: 'Choose your preferred app language',
                    onTap: () {
                      navigationPush(context, const Languages());
                    },
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ── Support & About ───────────────────────────────
              _buildSectionLabel('Support & About'),
              const SizedBox(height: 8),
              _buildCard(
                children: [
                  _buildNavTile(
                    icon: Assets.images.icHelpSupport.path,
                    title: AppLocalizations.of(context)!.helpandsupport,
                    subtitle: 'Get help with your account',
                    onTap: () {
                      navigationPush(context, const HelpSupport());
                    },
                  ),
                  _buildDivider(),
                  _buildNavTile(
                    icon: Assets.images.icFeedback.path,
                    title: AppLocalizations.of(context)!.feedbackttl,
                    subtitle: 'Share your thoughts and help improve Polzet.',
                    onTap: () {
                      navigationPush(context, const FeedbackScreen());
                    },
                  ),
                  _buildDivider(),
                  _buildNavTile(
                    icon: Assets.images.icTermsConditions.path,
                    title: AppLocalizations.of(context)!.termsandconditions,
                    subtitle: 'Read the rules and guidelines for using Polzet.',
                    onTap: () {
                      navigationPush(context, const TermsAndConditions());
                    },
                  ),
                   _buildDivider(),
                  _buildNavTile(
                    icon: Assets.images.icTermsConditions.path,
                    title: AppLocalizations.of(context)!.privacypolicy,
                    subtitle: 'Read the rules and guidelines for using Polzet.',
                    onTap: () {
                      navigationPush(context, const PrivacyPolicy());
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Add Account ───────────────────────────────────
              _buildCard(
                children: [
                  _buildTextTile(
                    icon: FeatherIcons.delete,
                    label: AppLocalizations.of(context)!.deleteaccount,
                    color: Theme.of(context).colorScheme.error,
                    onTap: () {
                      showDeleteAccountDiolog(context, () {
                        Navigator.pop(context);
                        showConfirmDeletionAccountDiolog(context, (
                          password,
                        ) async {
                          await _deleteAccount(password);
                        });
                      });
                    },
                  ),
                  _buildDivider(),
                  _buildTextTile(
                    icon: Icons.logout_rounded,
                    label: AppLocalizations.of(context)!.logout,
                    color: Theme.of(context).colorScheme.error,
                    onTap: () {
                      showLogoutDiolog(context, () {
                        Navigator.pop(context);
                        _logout();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: AppTextStyles.cardTitle.copyWith(
          color: const Color(0XFF898989),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(thickness: 0.5, height: 1, color: Color(0xFFDCDCDC));
  }

  Widget _buildNavTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildIconBox(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: const Color(0xFF8E8E8E),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15.5,
              color: Color(0XFF595959),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: const Color(0xFF8E8E8E),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTextTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(String image) {
    return Container(
      height: 47,
      width: 47,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0x1A9B3046),
        shape: BoxShape.circle,
      ),
      child: Image.asset(image, color: Theme.of(context).colorScheme.primary),
    );
  }
}
