// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../../api/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';
import 'package:polzet_app/api/api_config.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/show_toast.dart';
import '../../profile/public/public_profile_screen.dart';

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

  ImageProvider _getAvatarImageProvider(dynamic profilePic) {
    if (profilePic == null) {
      return AssetImage(Assets.images.icAvatar.path);
    }
    final raw = profilePic.toString().trim();
    if (raw.isEmpty ||
        raw == 'null' ||
        raw == Assets.images.icAvatar.path ||
        raw.endsWith('ic_avatar.png')) {
      return AssetImage(Assets.images.icAvatar.path);
    }
    if (raw.startsWith('assets/')) {
      return AssetImage(raw);
    }
    final profileBytes = getProfileImage(raw);
    if (profileBytes != null) {
      return MemoryImage(profileBytes);
    }
    final resolved = resolveProfileImageUrl(raw);
    if (resolved != null && resolved.isNotEmpty) {
      if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
        return NetworkImage(resolved);
      } else if (resolved.startsWith('assets/')) {
        return AssetImage(resolved);
      }
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return NetworkImage(raw);
    }
    final separator = raw.startsWith('/') ? '' : '/';
    final fullUrl = '${ApiConfig.baseUrlImage}$separator$raw';
    if (fullUrl.startsWith('http')) {
      return NetworkImage(fullUrl);
    }
    return AssetImage(Assets.images.icAvatar.path);
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
      if (result['message'] != null) {
        showToast(message: result['message'].toString());
      }
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _blockedUsersFuture = _apiService.getBlockedUsers();
              });
              await _blockedUsersFuture;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
              final user = users[index];
              final dynamic userId = user['id'];
              final profilePic = user['profile_picture_url'];
              final bool isBlocked = _isBlockedMap[userId] ?? true;

              final String username = (user['username'] ?? '').toString();
              final String currentUsername =
                  username.trim().toLowerCase();

              return Padding(
                padding: EdgeInsetsGeometry.symmetric(
                  horizontal: 10.w,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (username.isNotEmpty) {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) => PublicProfileScreen(
                                    userId: userId?.toString(),
                                    username: username,
                                  ),
                                ),
                              )
                              .then((_) {
                                setState(() {
                                  _blockedUsersFuture =
                                      _apiService.getBlockedUsers();
                                });
                              });
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 42,
                        width: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: (() {
                                if (currentUsername == 'polzet_ai') {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 7,
                                        bottom: 0,
                                        left: 9,
                                        right: 8,
                                      ),
                                      child: Image.asset(
                                        Assets.images.icSplash.path,
                                      ),
                                    ),
                                  );
                                }
                                return CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isDarkMode
                                      ? const Color(0xFF252525)
                                      : Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.08),
                                  backgroundImage:
                                      _getAvatarImageProvider(profilePic),
                                  onBackgroundImageError: (_, __) {},
                                );
                              })(),
                            ),
                            if (currentUsername == 'polzet_ai')
                              Positioned.fill(
                                child: Image.asset(
                                  Assets.images.aiFrame.path,
                                  height: 50,
                                  width: 50,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (username.isNotEmpty) {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) => PublicProfileScreen(
                                      userId: userId?.toString(),
                                      username: username,
                                    ),
                                  ),
                                )
                                .then((_) {
                                  setState(() {
                                    _blockedUsersFuture =
                                        _apiService.getBlockedUsers();
                                  });
                                });
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    username,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: txt.body,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (currentUsername == 'polzet_ai' ||
                                    currentUsername == 'polzet') ...[
                                  SizedBox(width: 4.w),
                                  Image.asset(
                                    Assets.images.icVerify.path,
                                    height: 13,
                                    width: 13,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              (user['first_name'] != null &&
                                      user['last_name'] != null &&
                                      user['first_name'].toString().isNotEmpty &&
                                      user['last_name'].toString().isNotEmpty)
                                  ? '${user['first_name']} ${user['last_name']}'
                                  : username,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12.5,
                                color: txt.muted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showBlockUserDiolog(
                          context,
                          () {
                            Navigator.of(context).pop();
                            _toggleBlock(userId, isBlocked);
                          },
                          isBlocked,
                        );
                      },
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
                              isBlocked
                                  ? AppLocalizations.of(context)!.unblock
                                  : AppLocalizations.of(context)!.block,
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
          ),
        );
      },
      ),
    );
  }
}
