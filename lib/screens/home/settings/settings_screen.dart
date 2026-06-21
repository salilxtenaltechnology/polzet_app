// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/app_api.dart';
import '../../../api/services/validator/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
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
import '../../auth/social/social_login_screen.dart';
import 'account/private_account.dart';
import 'block/block_account.dart';
import 'feedback/feedback.dart';
import 'help and support/help_support.dart';
import 'language/language_import.dart';
import 'notifications/notifications.dart';
import 'privacy/privacy_policy.dart';
import 'security/security.dart';
import 'terms and conditions/terms_and_conditions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with UtilityMixin, WidgetsBindingObserver {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
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
      setState(() {});
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;
    final txt = AppTextColors.of(context);

    final List<SettingsSearchItem> allItems = [
      // Dark Mode
      SettingsSearchItem(
        title: localizations.darkmode,
        subtitle: localizations.askopinionsandgetanswers,
        iconAsset: Assets.images.icDarkmode.path,
        onTap: () {
          themeProvider.toggleTheme();
          setState(() {});
        },
        trailing: CupertinoSwitch(
          value: themeProvider.isDarkMode,
          onChanged: (value) {
            themeProvider.toggleTheme();
            setState(() {});
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        keywords: ['dark', 'mode', 'theme', 'light', 'appearance', 'background'],
      ),
      // Security
      SettingsSearchItem(
        title: localizations.security,
        subtitle: localizations.updateyourpasswordandsecureyouraccount,
        iconAsset: Assets.images.icSecurity.path,
        onTap: () {
          navigationPush(context, const Security());
        },
        keywords: ['security', 'password', 'lock', 'secure', 'account'],
      ),
      // Account Privacy
      SettingsSearchItem(
        title: localizations.accountprivacy,
        subtitle: localizations.controlwhocanviewyouractivityandpolls,
        iconAsset: Assets.images.icAccountPrivacy.path,
        onTap: () {
          navigationPush(context, const PrivateAccount());
        },
        keywords: ['privacy', 'private', 'account', 'activity', 'polls', 'control'],
      ),
      // Blocked Accounts
      SettingsSearchItem(
        title: localizations.blockedaccounts,
        subtitle: localizations.managepeopleyouveblockedonpolzet,
        iconAsset: Assets.images.icBlockAccount.path,
        onTap: () {
          navigationPush(context, const BlockAccounts());
        },
        keywords: ['block', 'blocked', 'accounts', 'manage', 'people', 'unblock'],
      ),
      // Notifications
      SettingsSearchItem(
        title: localizations.notifications,
        subtitle: localizations.choosewhatupdatesandalertsyouwanttoreceive,
        iconAsset: Assets.images.icNotifications.path,
        onTap: () {
          navigationPush(context, const NotificationsSettings());
        },
        keywords: ['notifications', 'alerts', 'updates', 'push', 'sounds'],
      ),
      // Language
      SettingsSearchItem(
        title: localizations.language,
        subtitle: localizations.chooseyourpreferredapplanguage,
        iconAsset: Assets.images.icLanguage.path,
        onTap: () {
          navigationPush(context, const Languages());
        },
        keywords: ['language', 'english', 'spanish', 'indonesian', 'app language', 'preferred'],
      ),
      // Help & Support
      SettingsSearchItem(
        title: localizations.helpandsupport,
        subtitle: localizations.gethelpwithyouraccount,
        iconAsset: Assets.images.icHelpSupport.path,
        onTap: () {
          navigationPush(context, const HelpSupport());
        },
        keywords: ['help', 'support', 'contact', 'faq', 'issue', 'problem'],
      ),
      // Feedback
      SettingsSearchItem(
        title: localizations.feedbackttl,
        subtitle: localizations.shareyourthoughtsandhelpimprovepolzet,
        iconAsset: Assets.images.icFeedback.path,
        onTap: () {
          navigationPush(context, const FeedbackScreen());
        },
        keywords: ['feedback', 'suggest', 'improve', 'thoughts', 'rate'],
      ),
      // Terms and Conditions
      SettingsSearchItem(
        title: localizations.termsandconditions,
        subtitle: localizations.readtherulesandguidelinesforusingpolzet,
        iconAsset: Assets.images.icTermsConditions.path,
        onTap: () {
          navigationPush(context, const TermsAndConditions());
        },
        keywords: ['terms', 'conditions', 'rules', 'guidelines', 'agreement'],
      ),
      // Privacy Policy
      SettingsSearchItem(
        title: localizations.privacypolicy,
        subtitle: localizations.readtherulesandguidelinesforusingpolzet,
        iconAsset: Assets.images.icTermsConditions.path,
        onTap: () {
          navigationPush(context, const PrivacyPolicy());
        },
        keywords: ['privacy', 'policy', 'data', 'legal', 'rules'],
      ),
      // Logout
      SettingsSearchItem(
        title: localizations.logout,
        subtitle: 'Log out of your Polzet account',
        iconData: Icons.logout_rounded,
        color: Theme.of(context).colorScheme.error,
        onTap: () {
          showLogoutDiolog(context, () {
            Navigator.pop(context);
            _logout();
          });
        },
        keywords: ['logout', 'signout', 'exit', 'leave', 'account'],
      ),
    ];

    final filteredItems = allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q) ||
          item.keywords.any((kw) => kw.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      resizeToAvoidBottomInset: false,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.settings),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? (filteredItems.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 60,
                                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No matching settings found',
                                    style: AppTextStyles.cardTitle.copyWith(
                                      color: txt.title,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try searching for other terms like "privacy", "password", or "language".',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: txt.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            _buildCard(
                              children: List.generate(
                                filteredItems.length * 2 - 1,
                                (index) {
                                  if (index.isOdd) return _buildDivider();
                                  final item = filteredItems[index ~/ 2];
                                  if (item.trailing != null) {
                                    return _buildSearchToggleTile(item);
                                  } else if (item.iconData != null) {
                                    return _buildSearchTextTile(item);
                                  } else {
                                    return _buildSearchNavTile(item);
                                  }
                                },
                              ),
                            ),
                          ],
                        ))
                  : SingleChildScrollView(
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
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.askopinionsandgetanswers,
                                value: themeProvider.isDarkMode,
                                onChanged: (value) {
                                  themeProvider.toggleTheme();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // ── Account ───────────────────────────────────────
                          _buildSectionLabel(AppLocalizations.of(context)!.account),
                          const SizedBox(height: 8),
                          _buildCard(
                            children: [
                              _buildNavTile(
                                icon: Assets.images.icSecurity.path,
                                title: AppLocalizations.of(context)!.security,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.updateyourpasswordandsecureyouraccount,
                                onTap: () {
                                  navigationPush(context, const Security());
                                },
                              ),
                              _buildDivider(),
                              _buildNavTile(
                                icon: Assets.images.icAccountPrivacy.path,
                                title: AppLocalizations.of(context)!.accountprivacy,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.controlwhocanviewyouractivityandpolls,
                                onTap: () {
                                  navigationPush(context, const PrivateAccount());
                                },
                              ),
                              _buildDivider(),
                              _buildNavTile(
                                icon: Assets.images.icBlockAccount.path,
                                title: AppLocalizations.of(context)!.blockedaccounts,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.managepeopleyouveblockedonpolzet,
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
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.choosewhatupdatesandalertsyouwanttoreceive,
                                onTap: () {
                                  navigationPush(context, const NotificationsSettings());
                                },
                              ),
                              _buildDivider(),
                              _buildNavTile(
                                icon: Assets.images.icLanguage.path,
                                title: AppLocalizations.of(context)!.language,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.chooseyourpreferredapplanguage,
                                onTap: () {
                                  navigationPush(context, const Languages());
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // ── Support & About ───────────────────────────────
                          _buildSectionLabel(AppLocalizations.of(context)!.supportandabout),
                          const SizedBox(height: 8),
                          _buildCard(
                            children: [
                              _buildNavTile(
                                icon: Assets.images.icHelpSupport.path,
                                title: AppLocalizations.of(context)!.helpandsupport,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.gethelpwithyouraccount,
                                onTap: () {
                                  navigationPush(context, const HelpSupport());
                                },
                              ),
                              _buildDivider(),
                              _buildNavTile(
                                icon: Assets.images.icFeedback.path,
                                title: AppLocalizations.of(context)!.feedbackttl,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.shareyourthoughtsandhelpimprovepolzet,
                                onTap: () {
                                  navigationPush(context, const FeedbackScreen());
                                },
                              ),
                              _buildDivider(),
                              _buildNavTile(
                                icon: Assets.images.icTermsConditions.path,
                                title: AppLocalizations.of(context)!.termsandconditions,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.readtherulesandguidelinesforusingpolzet,
                                onTap: () {
                                  navigationPush(context, const TermsAndConditions());
                                },
                              ),
                              _buildDivider(),
                              _buildNavTile(
                                icon: Assets.images.icTermsConditions.path,
                                title: AppLocalizations.of(context)!.privacypolicy,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.readtherulesandguidelinesforusingpolzet,
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
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
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
    return Divider(
      thickness: 0.5,
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildNavTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final txt = AppTextColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
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
                      color: txt.title,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: txt.muted,
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
    final txt = AppTextColors.of(context);

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
                    color: txt.title,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: txt.muted,
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        image,
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
      ),
    );
  }

  // ── Search Helpers ─────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline
                : const Color(0xFFDCDCDC),
            width: 0.8,
          ),
        ),
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          cursorColor: Theme.of(context).colorScheme.onPrimary,
          cursorWidth: 1.5,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search settings & features...',
            hintStyle: AppTextStyles.bodyText.copyWith(
              color: const Color(0XFF898989),
              fontWeight: FontWeight.w400,
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 22,
              color: Color(0XFF898989),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 46,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0XFF898989),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 46,
            ),
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.only(right: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchNavTile(SettingsSearchItem item) {
    return _buildNavTile(
      icon: item.iconAsset!,
      title: item.title,
      subtitle: item.subtitle,
      onTap: item.onTap,
    );
  }

  Widget _buildSearchToggleTile(SettingsSearchItem item) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return _buildToggleTile(
      icon: item.iconAsset!,
      title: item.title,
      subtitle: item.subtitle,
      value: themeProvider.isDarkMode,
      onChanged: (value) {
        themeProvider.toggleTheme();
        setState(() {});
      },
    );
  }

  Widget _buildSearchTextTile(SettingsSearchItem item) {
    return _buildTextTile(
      icon: item.iconData!,
      label: item.title,
      color: item.color ?? Theme.of(context).colorScheme.error,
      onTap: item.onTap,
    );
  }
}

class SettingsSearchItem {
  final String title;
  final String subtitle;
  final String? iconAsset;
  final IconData? iconData;
  final Color? color;
  final VoidCallback onTap;
  final Widget? trailing;
  final List<String> keywords;

  SettingsSearchItem({
    required this.title,
    required this.subtitle,
    this.iconAsset,
    this.iconData,
    this.color,
    required this.onTap,
    this.trailing,
    this.keywords = const [],
  });
}
