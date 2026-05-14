// ignore_for_file: deprecated_member_use
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/services/api_service.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../models/like/like_uers_model.dart';
import '../../../provider/user_provider.dart';
import '../../base64/image_convert.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../loader.dart';
import '../../../screens/home/home_imports.dart';
import '../../../screens/home/profile/public/public_profile_screen.dart';

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

  // Track per-user follow status locally for optimistic UI updates
  // Key: user.id, Value: "following" | "followers" | "none"
  final Map<int, String> _followStatusMap = {};
  final Map<int, String> _originalServerStatusMap = {};

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

  Future<void> _fetchLikedUsers() async {
    try {
      final users = await ApiService().fetchLikedUsers(widget.postId);

      if (mounted) {
        setState(() {
          _likedUsers = users;
          _filteredUsers = users;
          _isLoading = false;

          // Seed the local follow status map from the API response
          for (final user in users) {
            final status = user.followStatus ?? 'none';
            _followStatusMap[user.id] = status;
            _originalServerStatusMap[user.id] = status;
          }
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

  void _filterUsers(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredUsers = _likedUsers;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredUsers = _likedUsers
            .where(
              (user) =>
                  user.username.toLowerCase().contains(lowerQuery) ||
                  (user.fullName ?? '').toLowerCase().contains(lowerQuery),
            )
            .toList();
      }
    });
  }

  /// Returns button label based on current follow status
  String _chaseLabel(String status) {
    switch (status) {
      case 'following':
      case 'both':
        return 'Chasing';
      case 'followers':
      case 'follower':
        return 'Chase Back';
      case 'requested':
      case 'pending':
        return 'Requested';
      default:
        return 'Chase';
    }
  }

  /// Returns true when the user is already following (button appears outlined/inactive)
  bool _isFollowing(String status) =>
      status == 'following' ||
      status == 'both' ||
      status == 'requested' ||
      status == 'pending';

  Future<void> _handleChaseToggle(LikeUser user) async {
    final currentStatus = _followStatusMap[user.id] ?? 'none';
    final originalServerStatus = _originalServerStatusMap[user.id] ?? 'none';

    if (currentStatus == 'requested' || currentStatus == 'pending') {
      final revertStatus =
          originalServerStatus == 'requested' ||
              originalServerStatus == 'pending'
          ? 'none'
          : originalServerStatus;

      setState(() => _followStatusMap[user.id] = revertStatus);

      try {
        final success = await ApiService().cancelFriendRequest(user.id);
        if (!success && mounted) {
          setState(() => _followStatusMap[user.id] = currentStatus);
        }
      } catch (e) {
        if (mounted) setState(() => _followStatusMap[user.id] = currentStatus);
      }
    } else if (_isFollowing(currentStatus)) {
      // Unfriend
      final nextStatus =
          (originalServerStatus == 'both' ||
              originalServerStatus == 'followers' ||
              originalServerStatus == 'follower')
          ? 'followers'
          : 'none';

      setState(() => _followStatusMap[user.id] = nextStatus);

      try {
        final response = await ApiService().unfriend(user.id);
        if (response['status'] == 'success') {
          _originalServerStatusMap[user.id] = nextStatus;
        } else if (mounted) {
          setState(() => _followStatusMap[user.id] = currentStatus);
        }
      } catch (e) {
        if (mounted) setState(() => _followStatusMap[user.id] = currentStatus);
      }
    } else {
      // Send friend request
      setState(() => _followStatusMap[user.id] = 'requested');

      try {
        final success = await ApiService().sendFriendRequest(user.username);
        if (!success && mounted) {
          setState(() => _followStatusMap[user.id] = currentStatus);
        }
      } catch (e) {
        if (mounted) setState(() => _followStatusMap[user.id] = currentStatus);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
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
                style: AppTextStyles.sectionHeading.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ),
          ),

          // Search bar
          const SizedBox(height: 10),
          Container(
            height: 43,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.button),
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
                hintStyle: AppTextStyles.bodyText.copyWith(
                  color: const Color(0XFF898989),
                  fontWeight: FontWeight.w400,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  FeatherIcons.search,
                  size: 17.spMax,
                  color: const Color(0XFF898989),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0XFFDCDCDC),
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: AppColors.primaryColor,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
              ),
              onChanged: _filterUsers,
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
                    child: _searchController.text.trim().isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                Assets.images.noLike.path,
                                height: 0.18.sh,
                                width: 0.18.sh,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppLocalizations.of(context)!.nolikesthispost,
                                style: AppTextStyles.sectionHeading.copyWith(
                                  fontSize: 18.5,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                Assets.images.noUsersFound.path,
                                height: 0.18.sh,
                                width: 0.18.sh,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppLocalizations.of(context)!.nousersfound,
                                style: AppTextStyles.sectionHeading.copyWith(
                                  fontSize: 18.5,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final followStatus = _followStatusMap[user.id] ?? 'none';
                      final isFollowing = _isFollowing(followStatus);

                      return Container(
                        height: 60,
                        margin: EdgeInsetsGeometry.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: const Color(0XFFEFEFEF),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x06000000), blurRadius: 2),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar with online indicator
                            GestureDetector(
                              onTap: () {
                                //  Navigator.pop(context); // Close bottom sheet
                                if (userProvider.userId == user.id) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const HomeScreen(initialIndex: 4),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PublicProfileScreen(userId: user.id),
                                    ),
                                  );
                                }
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 15.5.r,
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
                                            style: AppTextStyles.cardTitle
                                                .copyWith(
                                                  fontSize: 17,
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
                            ),

                            SizedBox(width: 7.w),

                            // Name + username
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user.username,
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: const Color(0XFF595959),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  user.fullName!,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12.5,
                                    color: const Color(0XFF8E8E8E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Chase button — hidden for current user
                            if (userProvider.userId != user.id)
                              GestureDetector(
                                onTap: () => _handleChaseToggle(user),
                                child: Container(
                                  height: 32,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: isFollowing
                                        ? Colors.transparent
                                        : Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.button,
                                    ),
                                    border: isFollowing
                                        ? Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.8),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _chaseLabel(followStatus),
                                      style: AppTextStyles.subText.copyWith(
                                        fontSize: 13,
                                        color: isFollowing
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.white,
                                        fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }
}
