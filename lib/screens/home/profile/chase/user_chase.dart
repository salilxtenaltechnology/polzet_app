// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  late Future<List<Map<String, dynamic>>> getFollowers;
  late Future<List<Map<String, dynamic>>> getFollowing;
  late TabController _tabController;

  bool isFollowing = true;

  // Search controller and filtered lists
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allFollowers = [];
  List<Map<String, dynamic>> _allFollowing = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  List<Map<String, dynamic>> _filteredFollowing = [];

  @override
  void initState() {
    super.initState();
    getFollowers = apiService.getFollowersList();
    getFollowing = apiService.getFollowingList();
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
      final followers = await apiService.getFollowersList();
      final following = await apiService.getFollowingList();

      setState(() {
        _allFollowers = followers;
        _allFollowing = following;
        _filteredFollowers = followers;
        _filteredFollowing = following;
      });
    } catch (e) {
      // Handle error if needed
      print('Error loading data: $e');
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
        children: [
          SizedBox(height: 150.h),
          Icon(
            icon,
            size: 50.sp,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
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

  // Build error state widget
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: Colors.red.withOpacity(0.6),
          ),
          SizedBox(height: 16.h),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextButton(
            onPressed: () {
              setState(() {
                getFollowers = apiService.getFollowersList();
                getFollowing = apiService.getFollowingList();
                _loadData();
              });
            },
            child: Text('Retry'),
          ),
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

    return Container(
      height: 40.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Color(0x1C000000), blurRadius: 5, spreadRadius: 1),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          navigationPush(context, PublicProfile(userId: user['id']));
        },
        child: Row(
          children: [
            // Profile Picture
            Container(
              height: 35.h,
              width: 35.w,
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
                          fontSize: 20.sp,
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
                '${user['username']}',
                style: CustomTextStyles.lblSecondryText(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Action Button
            if (isFollowersTab)
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 95.w,
                  margin: EdgeInsets.fromLTRB(3.w, 3.h, 0, 3.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Color(0XFFD9D9D9), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'Remove Chase',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isFollowing = !isFollowing;
                      });
                    },
                    child: Container(
                      width: 72.w,
                      margin: EdgeInsets.fromLTRB(3.w, 3.h, 0, 3.h),
                      decoration: BoxDecoration(
                        color: isFollowing
                            ? Theme.of(context).colorScheme.background
                            : AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isFollowing
                              ? Color(0XFFD9D9D9)
                              : AppColors.primaryColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isFollowing ? 'Chasing' : 'Chase',
                          style: TextStyle(
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
                  SizedBox(width: 3.w),
                  Icon(
                    Icons.more_vert,
                    size: 20.spMax,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ],
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
        leading: PrimaryBackButton(),
        title: Text(
          widget.username,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: FadeUnderlineTabIndicator(),
              labelColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
              tabs: [
                Tab(
                  text:
                      '${widget.followerCount}  ${AppLocalizations.of(context)!.vibe}',
                ),
                Tab(
                  text:
                      '${widget.followingCount} ${AppLocalizations.of(context)!.revibe}',
                ),
              ],
            ),
            Container(
              height: 33.h,
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 7.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
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
                    borderSide: BorderSide(
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
                    padding: EdgeInsets.only(
                      top: 5.h,
                      left: 2.5.w,
                      right: 2.5.w,
                    ),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: getFollowers,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ChaseSimmer();
                        }

                        if (snapshot.hasError) {
                          return _buildErrorState(snapshot.error.toString());
                        }

                        // Use filtered list if search is active
                        final users = _searchQuery.isEmpty
                            ? (snapshot.data ?? [])
                            : _filteredFollowers;

                        if (users.isEmpty) {
                          return _buildEmptyState(
                            icon: FeatherIcons.users,
                            message: _searchQuery.isEmpty
                                ? 'No chase yet'
                                : 'No users found',
                            subtitle: _searchQuery.isEmpty
                                ? 'When people chase you, they\'ll appear here'
                                : 'Try searching with a different keyword',
                          );
                        }

                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            return _buildUserListItem(
                              user: users[index],
                              isFollowersTab: true,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Following Tab (Re-chase)
                  Padding(
                    padding: EdgeInsets.only(
                      top: 5.h,
                      left: 2.5.w,
                      right: 2.5.w,
                    ),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: getFollowing,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ChaseSimmer();
                        }

                        if (snapshot.hasError) {
                          return _buildErrorState(snapshot.error.toString());
                        }

                        // Use filtered list if search is active
                        final users = _searchQuery.isEmpty
                            ? (snapshot.data ?? [])
                            : _filteredFollowing;

                        if (users.isEmpty) {
                          return _buildEmptyState(
                            icon: FeatherIcons.userPlus,
                            message: _searchQuery.isEmpty
                                ? 'Not re-chase anyone yet'
                                : 'No users found',
                            subtitle: _searchQuery.isEmpty
                                ? 'Start re-chase people to see them here'
                                : 'Try searching with a different keyword',
                          );
                        }

                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            return _buildUserListItem(
                              user: users[index],
                              isFollowersTab: false,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
