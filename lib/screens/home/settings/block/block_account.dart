// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';

class BlockAccounts extends StatefulWidget {
  const BlockAccounts({super.key});

  @override
  State<BlockAccounts> createState() => _BlockUsersState();
}

class _BlockUsersState extends State<BlockAccounts> {
  late Future<Map<String, dynamic>> _blockedUsersFuture;
  final ApiService _apiService = ApiService();
  final Map<dynamic, bool> _isBlockedMap = {};

  @override
  void initState() {
    super.initState();
    _blockedUsersFuture = _apiService.getBlockedUsers();
  }

  Future<void> _toggleBlock(dynamic userId, bool currentlyBlocked) async {
    setState(() => _isBlockedMap[userId] = !currentlyBlocked);

    final result = currentlyBlocked
        ? await _apiService.unblockUser(userId)
        : await _apiService.blockUser(userId);

    if (!mounted) return;

    if (result['success'] != true) {
      // Revert on failure
      setState(() => _isBlockedMap[userId] = currentlyBlocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.blockedaccounts,
        showBackButton: true,
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _blockedUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Loader(color: Theme.of(context).primaryColor));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0XFF999999),
                ),
              ),
            );
          }

          final rawData = snapshot.data?['data'];
          final List<dynamic> users = (rawData is List) ? rawData : [];

          if (users.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noblockedaccount,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0XFF999999),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,

            itemBuilder: (context, index) {
              final user = users[index];
              final dynamic userId = user['id'];
              final profilePic = user['profile_picture_url'];
              final bool isBlocked = _isBlockedMap[userId] ?? true;

              final firstLetter = (user['username'] as String).isNotEmpty
                  ? (user['username'] as String).substring(0, 1).toUpperCase()
                  : '';

              return Padding(
                padding: EdgeInsetsGeometry.symmetric(
                  horizontal: 10.w,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      margin: EdgeInsets.only(right: 5.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 0.7,
                        ),
                        image: profilePic != null
                            ? DecorationImage(
                                image: MemoryImage(
                                  getProfileImage(profilePic)!,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: profilePic == null
                            ? (isDarkMode
                                  ? const Color(0xFF252525)
                                  : Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.08))
                            : null,
                      ),
                      child: profilePic == null
                          ? Center(
                              child: Text(
                                firstLetter,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.8),
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${user['username']}',
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.body,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            (user['first_name'] != null &&
                                    user['last_name'] != null &&
                                    user['first_name'].toString().isNotEmpty &&
                                    user['last_name'].toString().isNotEmpty)
                                ? '${user['first_name']} ${user['last_name']}'
                                : '${user['username']}',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.5,
                              color: txt.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleBlock(userId, isBlocked),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        height: 32,
                        width: 100,
                        margin: EdgeInsets.fromLTRB(3.w, 3.h, 0, 3.h),
                        decoration: BoxDecoration(
                          color: isBlocked
                              ? (isDarkMode
                                    ? Colors.transparent
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer)
                              : AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          border: Border.all(
                            color: isBlocked
                                ? (isDarkMode
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimary.withOpacity(0.3)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.8))
                                : AppColors.primaryColor,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              isBlocked ? 'Unblock' : 'Block',
                              key: ValueKey(isBlocked),
                              style: AppTextStyles.subText.copyWith(
                                color: isBlocked
                                    ? (isDarkMode
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withOpacity(0.7)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
