// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
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
  final Map<int, bool> _isBlockedMap = {};

  @override
  void initState() {
    super.initState();
    _blockedUsersFuture = _apiService.getBlockedUsers();
  }

  Future<void> _toggleBlock(int userId, bool currentlyBlocked) async {
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

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(height: 1.h),
            itemBuilder: (context, index) {
              final user = users[index];
              final int userId = user['id'];
              final profilePic = user['profile_picture_url'];
              final bool isBlocked = _isBlockedMap[userId] ?? true;

              final firstLetter = (user['first_name'] as String).isNotEmpty
                  ? (user['first_name'] as String).substring(0, 1).toUpperCase()
                  : '';

              return Container(
                height: 42.h,
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                margin: EdgeInsets.only(
                  bottom: 7.h,
                  right: 10.w,
                  left: 10.w,
                  top: 5.h,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1C000000),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 29.5.h,
                      width: 29.5.w,
                      margin: EdgeInsets.only(right: 5.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD1D1D1).withOpacity(0.7),
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
                            ? Theme.of(context).primaryColor.withOpacity(0.08)
                            : null,
                      ),
                      child: profilePic == null
                          ? Center(
                              child: Text(
                                firstLetter,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).primaryColor,
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
                            '${user['first_name']} ${user['last_name']}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: 11.2.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            '@${user['username']}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey,
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
                        width: 72.w,
                        margin: EdgeInsets.fromLTRB(3.w, 3.h, 0, 3.h),
                        decoration: BoxDecoration(
                          color: isBlocked
                              ? Theme.of(context).colorScheme.primaryContainer
                              : AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isBlocked
                                ? const Color(0XFFD9D9D9)
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
                              style: TextStyle(
                                color: isBlocked
                                    ? Theme.of(context).colorScheme.onBackground
                                    : Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
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
