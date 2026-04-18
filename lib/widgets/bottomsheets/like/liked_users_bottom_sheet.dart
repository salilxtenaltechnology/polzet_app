// ignore_for_file: deprecated_member_use
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/services/api_service.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../models/like/like_uers_model.dart';
import '../../base64/image_convert.dart';
import '../../custom_text_styles.dart';
import '../../loader.dart';

class LikedUsersBottomSheet extends StatefulWidget {
  final int postId;

  const LikedUsersBottomSheet({super.key, required this.postId});

  @override
  State<LikedUsersBottomSheet> createState() => _LikedUsersBottomSheetState();
}

class _LikedUsersBottomSheetState extends State<LikedUsersBottomSheet> {
  late List<LikeUser> _likedUsers;
  late List<LikeUser> _filteredUsers;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likedUsers = [];
    _filteredUsers = [];
    _fetchLikedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch liked users from API
  Future<void> _fetchLikedUsers() async {
    try {
      final users = await ApiService().fetchLikedUsers(widget.postId);

      if (mounted) {
        setState(() {
          _likedUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likedUsers = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load likes: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filter users based on search query
  void _filterUsers(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredUsers = _likedUsers;
      } else {
        _filteredUsers = _likedUsers
            .where(
              (user) =>
                  user.username.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.likes,
                style: CustomTextStyles.bottomsheetTitleTextStyle(context),
              ),
            ),
          ),

          // Search bar
          Container(
            height: 33.h,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1C000000),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(
                  right: 12.w,
                  left: 12.w,
                  top: 10.h,
                ),
                hintText: AppLocalizations.of(context)!.searchusers,
                hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                border: InputBorder.none,
                suffixIcon: Icon(
                  FeatherIcons.search,
                  size: 17.spMax,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: AppColors.primaryColor,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(13.r),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
              onChanged: (value) {
                _filterUsers(value);
              },
            ),
          ),

          // List of users who liked
          Expanded(
            child: _isLoading
                ? Center(
                    child: Loader(color: Theme.of(context).colorScheme.primary),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? AppLocalizations.of(context)!.nolikesthispost
                          : AppLocalizations.of(context)!.nousersfound,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Padding(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 13.r,
                                  backgroundImage:
                                      user.profileImage != null &&
                                          user.profileImage!.isNotEmpty
                                      ? MemoryImage(
                                          getProfileImage(user.profileImage)!,
                                        )
                                      : null,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                  child:
                                      user.profileImage == null ||
                                          user.profileImage!.isEmpty
                                      ? Text(
                                          user.firstLetter,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                                if (user.isOnline)
                                  Positioned(
                                    bottom: 0,
                                    right: -3,
                                    child: Container(
                                      height: 10.h,
                                      width: 10.w,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            SizedBox(width: 7.w),
                            Text(
                              user.username,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
