// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/simmer/chase/chase_simmer.dart';
import '../../../../widgets/tabbar/indicatore_animation.dart';
import '../public/public_profile.dart';

// ignore: must_be_immutable
class UserChase extends StatefulWidget {
  final String username;
  final int initialIndex;
  final String followerCount;
  final String followingCount;
  const UserChase({
    super.key,
    required this.username,
    required this.initialIndex,
    required this.followerCount,
    required this.followingCount,
  });
  @override
  State<UserChase> createState() => _UserChaseState();
}

class _UserChaseState extends State<UserChase>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final ApiService apiService = ApiService();
  late TabController _tabController;

  // Track following status for each user
  Map<String, bool> followingStatus = {};

  // Search controller and filtered lists
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allFollowers = [];
  List<Map<String, dynamic>> _allFollowing = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  List<Map<String, dynamic>> _filteredFollowing = [];

  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  // Dynamic counts
  int _followerCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize counts from widget parameters
    _followerCount = int.tryParse(widget.followerCount) ?? 0;
    _followingCount = int.tryParse(widget.followingCount) ?? 0;

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    // Load initial data
    _loadData();
  }

  // Load data from API
  void _loadData() async {
    try {
      setState(() {
        _isLoadingFollowers = true;
        _isLoadingFollowing = true;
      });

      final followers = await apiService.getFollowersList();
      final following = await apiService.getFollowingList();

      setState(() {
        _allFollowers = followers;
        _allFollowing = following;
        _filteredFollowers = followers;
        _filteredFollowing = following;
        _isLoadingFollowers = false;
        _isLoadingFollowing = false;

        // Update counts based on actual data
        _followerCount = followers.length;
        _followingCount = following.length;

        // Initialize following status for all users in following list
        for (var user in following) {
          final username = user['username'] as String?;
          if (username != null) {
            followingStatus[username] = true;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingFollowers = false;
        _isLoadingFollowing = false;
      });
      debugPrint('Error loading data: $e');
    }
  }

  // Remove follower (unfriend) - only removes from followers list
  Future<void> _removeFollower(int userId) async {
    try {
      // Find the username before removing
      String? removedUsername;
      final removedUser = _allFollowers.firstWhere(
        (user) => user['id'] == userId,
        orElse: () => {},
      );
      if (removedUser.isNotEmpty) {
        removedUsername = removedUser['username'] as String?;
      }

      // Optimistically remove ONLY from followers list
      setState(() {
        _allFollowers.removeWhere((user) => user['id'] == userId);
        _filteredFollowers.removeWhere((user) => user['id'] == userId);

        // Update ONLY follower count
        _followerCount = _allFollowers.length;
      });

      // Call API to remove follower
      final response = await apiService.unfriend(userId);

      if (response['status'] == 'success') {
        // Show success message
        if (mounted) {
          showToast(
            message: response['data'] ?? 'Follower removed successfully',
          );
        }
      } else {
        // If failed, reload data to restore the user
        _loadData();

        if (mounted) {
          showToast(
            message: response['message'] ?? 'Failed to remove follower',
          );
        }
      }
    } catch (e) {
      // If error, reload data to restore the user
      _loadData();

      if (mounted) {
        showToast(message: 'Error: ${e.toString()}');
      }
      debugPrint('Error removing follower: $e');
    }
  }

  // Toggle follow/unfollow in Following tab
  Future<void> _toggleFollow(String username, int userId) async {
    try {
      final isCurrentlyFollowing = followingStatus[username] ?? false;

      if (isCurrentlyFollowing) {
        // Optimistically update UI - just change button status, DON'T remove from list
        setState(() {
          followingStatus[username] = false;
        });

        // Unfollow: call unfriend API
        final response = await apiService.unfriend(userId);

        if (response['status'] == 'success') {
          // if (mounted) {
          //   showToast(message: 'Unfollowed successfully');
          // }
        } else {
          // If failed, revert the button status
          setState(() {
            followingStatus[username] = true;
          });

          if (mounted) {
            showToast(message: 'Failed to unfollow');
          }
        }
      } else {
        // Optimistically update UI
        setState(() {
          followingStatus[username] = true;
        });

        // Follow: send friend request
        final success = await apiService.sendFriendRequest(username);

        if (success) {
          // Successfully followed
          // if (mounted) {
          //   showToast(message: 'Friend request sent successfully');
          // }
        } else {
          // If failed, revert the change
          setState(() {
            followingStatus[username] = false;
          });

          if (mounted) {
            showToast(message: 'Failed to send friend request');
          }
        }
      }
    } catch (e) {
      // If error, revert the button status
      setState(() {
        followingStatus[username] = !followingStatus[username]!;
      });

      if (mounted) {
        showToast(message: 'Error: ${e.toString()}');
      }
      debugPrint('Error toggling follow: $e');
    }
  }

  // Filter users based on search query
  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _filteredFollowers = _allFollowers;
        _filteredFollowing = _allFollowing;
      } else {
        _filteredFollowers = _allFollowers.where((user) {
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final firstName =
              (user['first_name'] as String?)?.toLowerCase() ?? '';
          final name = (user['name'] as String?)?.toLowerCase() ?? '';

          return username.contains(_searchQuery) ||
              firstName.contains(_searchQuery) ||
              name.contains(_searchQuery);
        }).toList();

        _filteredFollowing = _allFollowing.where((user) {
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final firstName =
              (user['first_name'] as String?)?.toLowerCase() ?? '';
          final name = (user['name'] as String?)?.toLowerCase() ?? '';

          return username.contains(_searchQuery) ||
              firstName.contains(_searchQuery) ||
              name.contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Build empty state widget
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40.sp,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 15.5.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 5.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build user list item
  Widget _buildUserListItem({
    required Map<String, dynamic> user,
    required bool isFollowersTab,
  }) {
    final profilePic = user['profile_picture_url'] as String?;
    final firstName =
        user['first_name'] as String? ?? user['name'] as String? ?? '';
    final firstLetter = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    final userId = user['id'] as int;
    final username = user['username'] as String? ?? '';

    // Check if you're following this user (for both tabs)
    final isFollowing = followingStatus[username] ?? false;

    return Container(
      height: 38.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      margin: EdgeInsets.only(bottom: 7.h, right: 10.w, left: 10.w, top: 5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: const [
          BoxShadow(color: Color(0x1C000000), blurRadius: 5, spreadRadius: 1),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          navigationPush(context, PublicProfile(userId: userId));
        },
        child: Row(
          children: [
            // Profile Picture
            Container(
              height: 32.h,
              width: 32.w,
              margin: EdgeInsets.only(right: 5.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD1D1D1).withOpacity(0.7),
                ),
                image: profilePic != null
                    ? DecorationImage(
                        image: MemoryImage(getProfileImage(profilePic)!),
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
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 8.w),
            // Username
            Expanded(
              child: Text(
                username,
                style: CustomTextStyles.lblSecondryText(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Action Button
            if (isFollowersTab)
              // Remove Chase button for Followers tab
              GestureDetector(onTap: () {}, child: const SizedBox.shrink())
            else
              // Chasing/Chase button for Following tab
              GestureDetector(
                onTap: () {
                  // Call toggle follow when tapped
                  _toggleFollow(username, userId);
                },
                child: Container(
                  width: 72.w,
                  margin: EdgeInsets.fromLTRB(3.w, 3.h, 0, 3.h),
                  decoration: BoxDecoration(
                    // If following: white background, else: primary color
                    color: isFollowing
                        ? Theme.of(context).colorScheme.background
                        : AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      // If following: gray border, else: primary color border
                      color: isFollowing
                          ? const Color(0XFFD9D9D9)
                          : AppColors.primaryColor,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      // If following: show "Chasing", else: show "Chase"
                      isFollowing ? 'Chasing' : 'Chase',
                      style: TextStyle(
                        // If following: dark text, else: white text
                        color: isFollowing
                            ? Theme.of(context).colorScheme.onBackground
                            : Colors.white,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        title: Text(
          widget.username,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: Column(
        children: [
          TabBar(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            controller: _tabController,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: FadeUnderlineTabIndicator(),
            labelColor: Theme.of(context).colorScheme.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            dividerColor: Colors.transparent,
            unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
            tabs: [
              Tab(
                text: '$_followerCount  ${AppLocalizations.of(context)!.vibe}',
              ),
              Tab(
                text:
                    '$_followingCount ${AppLocalizations.of(context)!.revibe}',
              ),
            ],
          ),
          Container(
            height: 33.h,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Followers Tab (Chase)
                Padding(
                  padding: EdgeInsets.only(top: 5.h, left: 2.5.w, right: 2.5.w),
                  child: _isLoadingFollowers
                      ? const ChaseSimmer()
                      : _filteredFollowers.isEmpty
                      ? _buildEmptyState(
                          icon: FeatherIcons.users,
                          message: _searchQuery.isEmpty
                              ? 'No chase yet'
                              : 'No users found',
                          subtitle: _searchQuery.isEmpty
                              ? 'When people chase you, they\'ll appear here'
                              : 'Try searching with a different keyword',
                        )
                      : ListView.builder(
                          itemCount: _filteredFollowers.length,
                          itemBuilder: (context, index) {
                            return _buildUserListItem(
                              user: _filteredFollowers[index],
                              isFollowersTab: true,
                            );
                          },
                        ),
                ),
                // Following Tab (Re-chase)
                Padding(
                  padding: EdgeInsets.only(top: 5.h, left: 2.5.w, right: 2.5.w),
                  child: _isLoadingFollowing
                      ? const ChaseSimmer()
                      : _filteredFollowing.isEmpty
                      ? _buildEmptyState(
                          icon: FeatherIcons.userPlus,
                          message: _searchQuery.isEmpty
                              ? 'Not re-chase anyone yet'
                              : 'No users found',
                          subtitle: _searchQuery.isEmpty
                              ? 'Start re-chase people to see them here'
                              : 'Try searching with a different keyword',
                        )
                      : ListView.builder(
                          itemCount: _filteredFollowing.length,
                          itemBuilder: (context, index) {
                            return _buildUserListItem(
                              user: _filteredFollowing[index],
                              isFollowersTab: false,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
