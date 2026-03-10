// ignore_for_file: deprecated_member_use, unused_element, unused_field, use_build_context_synchronously
part of 'settings_import.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<StatefulWidget> createState() {
    return SettingsState();
  }
}

class SettingsState extends State<Settings>
    with UtilityMixin, WidgetsBindingObserver {
  final ApiService apiService = ApiService();
  String _errorText = '';

  Future<void> _clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // List of all cache keys used in your app
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

      // Remove each cache key
      for (String key in cacheKeys) {
        await prefs.remove(key);
      }

      // Alternative: Clear ALL SharedPreferences (be careful with this)
      // await prefs.clear(); // This removes EVERYTHING including tokens

      if (kDebugMode) {
        print('✅ All caches cleared successfully');
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

        clearStackAndAddScreen(context, const LoginScreen());
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

        // Clear provider state
        if (mounted) {
          context.read<UserProvider>().clearUserData();
        }

        Navigator.pop(context); // close confirm dialog
        showToast(
          message: 'Account ${userProvider.username} deleted permanently',
        );
        clearStackAndAddScreen(context, const LoginScreen());
      } else {
        showToast(message: result['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      Navigator.pop(context); // close loading dialog
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: const PrimaryBackButton(),
        title: Text(
          'Settings',
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 5.h),
            Text(
              AppLocalizations.of(context)!.account,
              style: CustomTextStyles.lblContentText(context),
            ),
            _contentModel(
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.dark_mode_outlined, size: 20.spMax),
                      SizedBox(width: 10.w),
                      Text(
                        AppLocalizations.of(context)!.darkmode,
                        style: CustomTextStyles.lblPrimaryText(context),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 17.h,
                        child: CupertinoSwitch(
                          activeTrackColor: AppColors.primaryColor,
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    FeatherIcons.user,
                    AppLocalizations.of(context)!.editprofile,
                    onTap: () {
                      navigationPush(context, const EditProfile());
                    },
                  ),

                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    FeatherIcons.bell,
                    AppLocalizations.of(context)!.notifications,
                    onTap: () {
                      navigationPush(context, const NotificationsSettings());
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    FeatherIcons.lock,
                    AppLocalizations.of(context)!.privacypolicy,
                    onTap: () {
                      navigationPush(context, const PrivacyPolicy());
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    Icons.translate,
                    AppLocalizations.of(context)!.language,
                    onTap: () {
                      navigationPush(context, const Languages());
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    Icons.security,
                    AppLocalizations.of(context)!.security,
                    onTap: () {
                      navigationPush(context, const Security());
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    Icons.privacy_tip_outlined,
                    'Account Privacy',
                    onTap: () {
                      navigationPush(context, const PrivateAccount());
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    Icons.block,
                    'Blocked Accounts',
                    onTap: () {
                      navigationPush(context, const BlockAccounts());
                    },
                  ),
                ],
              ),
            ),
            Text(
              AppLocalizations.of(context)!.supportandabout,
              style: CustomTextStyles.lblContentText(context),
            ),
            _contentModel(
              Column(
                children: [
                  _lalbelModel(
                    FeatherIcons.helpCircle,
                    AppLocalizations.of(context)!.helpandsupport,
                    onTap: () {
                      navigationPush(context, const HelpSupport());
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    Icons.description_outlined,
                    AppLocalizations.of(context)!.termsandconditions,
                    onTap: () {
                      navigationPush(context, const TermsAndConditions());
                    },
                  ),
                ],
              ),
            ),
            Text(
              AppLocalizations.of(context)!.actions,
              style: CustomTextStyles.lblContentText(context),
            ),
            _contentModel(
              Column(
                children: [
                  _lalbelModel(
                    FeatherIcons.delete,
                    'Delete Account',
                    onTap: () {
                      showDeleteAccountDiolog(context, () {
                        Navigator.pop(context); // close info dialog
                        showConfirmDeletionAccountDiolog(context, (
                          password,
                        ) async {
                          await _deleteAccount(password);
                        });
                      });
                    },
                  ),
                  SizedBox(height: 5.h),
                  Divider(
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  SizedBox(height: 5.h),
                  _lalbelModel(
                    FeatherIcons.logOut,
                    AppLocalizations.of(context)!.logout,
                    onTap: () {
                      showLogoutDiolog(context, () {
                        Navigator.pop(context);
                        _logout();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentModel(Column column) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 7.h, bottom: 12.h),
      padding: const EdgeInsets.all(12).w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: column,
    );
  }

  Widget _lalbelModel(
    IconData icon,
    String labelName, {
    required Null Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppIcons(icon: icon),
            SizedBox(width: 10.w),
            Text(labelName, style: CustomTextStyles.lblPrimaryText(context)),
            const Spacer(),
            Icon(
              FeatherIcons.chevronRight,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.3),
              size: 20.spMax,
            ),
          ],
        ),
      ),
    );
  }
}
