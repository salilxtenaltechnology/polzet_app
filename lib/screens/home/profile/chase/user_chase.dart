// ignore_for_file: deprecated_member_use

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/chase/toggle_chase_button.dart';
import '../../../../widgets/tabbar/indicatore_animation.dart';
import '../public/public_profile_screen.dart';

class UserChase extends StatefulWidget {
  final String username;
  final int initialIndex;
  final String followerCount;
  final String followingCount;
  final List<Map<String, dynamic>> chaseList;
  final List<Map<String, dynamic>> rechaseList;

  const UserChase({
    super.key,
    required this.username,
    required this.initialIndex,
    required this.followerCount,
    required this.followingCount,
    required this.chaseList,
    required this.rechaseList,
  });

  @override
  State<UserChase> createState() => _UserChaseState();
}

class _UserChaseState extends State<UserChase>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final ApiService apiService = ApiService();
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _allFollowers = [];
  List<Map<String, dynamic>> _allFollowing = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  List<Map<String, dynamic>> _filteredFollowing = [];

  // int _followerCount = 0;
  // int _followingCount = 0;

  @override
  void initState() {
    super.initState();

    // _followerCount = int.tryParse(widget.followerCount) ?? 0;
    // _followingCount = int.tryParse(widget.followingCount) ?? 0;

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    _allFollowers = widget.chaseList;
    _allFollowing = widget.rechaseList;
    _filteredFollowers = widget.chaseList;
    _filteredFollowing = widget.rechaseList;

    // _followerCount = _allFollowers.length;
    // _followingCount = _allFollowing.length;
  }

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
          final lastName = (user['last_name'] as String?)?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();

          return username.contains(_searchQuery) ||
              firstName.contains(_searchQuery) ||
              lastName.contains(_searchQuery) ||
              fullName.contains(_searchQuery);
        }).toList();

        _filteredFollowing = _allFollowing.where((user) {
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final firstName =
              (user['first_name'] as String?)?.toLowerCase() ?? '';
          final lastName = (user['last_name'] as String?)?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();

          return username.contains(_searchQuery) ||
              firstName.contains(_searchQuery) ||
              lastName.contains(_searchQuery) ||
              fullName.contains(_searchQuery);
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

 

  Widget _buildEmptyState({
    required String image,
    required String title,
    required String message,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, -60),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isDarkMode
                        ? const SizedBox()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Image.asset(
                              image,
                              height: 0.22.sh,
                              width: 0.22.sh,
                              fit: BoxFit.contain,
                            ),
                          ),

                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sectionHeading.copyWith(
                        fontSize: 18.5,
                        color: txt.title,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13,
                          color: txt.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserListItem({required Map<String, dynamic> user}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    final profilePic = user['avatar_url'] as String?;
    final firstName = user['first_name'] ?? 'Polzet';
    final lastName = user['last_name'] ?? 'User';
    final username = user['username'] as String? ?? '';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final userId = user['uuid'] as String;
    final followStatus = user['follow_status'] as String? ?? '';
    final isPrivate = user['is_private'] == true;

    return GestureDetector(
      onTap: () => navigationPush(context, PublicProfileScreen(userId: userId)),
      child: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 10.w, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 35.h,
              width: 35.w,
              margin: EdgeInsets.only(right: 5.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.7,
                ),
                image: profilePic != null
                    ? DecorationImage(
                        image: MemoryImage(getProfileImage(profilePic)!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: profilePic == null
                    ? (isDarkMode
                          ? const Color(0xFF252525)
                          : Theme.of(context).primaryColor.withOpacity(0.08))
                    : null,
              ),
              child: profilePic == null
                  ? Center(
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 5),
            // Username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if ('$firstName $lastName'.trim().isNotEmpty) ...[
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.body,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$firstName $lastName'.trim(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.5,
                        color: txt.muted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      username,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.body,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      username,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.5,
                        color: txt.muted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            ToggleChaseButton(
              username: username,
              userId: userId,
              followStatus: followStatus,
              apiService: apiService,
              isPrivate: isPrivate,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: widget.username),
      body: Column(
        children: [
          // TabBar
          SizedBox(
            height: 33.h,
            child: TabBar(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              controller: _tabController,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: FadeUnderlineTabIndicator(),
              labelColor: Theme.of(context).colorScheme.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
              tabs: [
                Tab(
                  text:
                      // '$_followerCount  ${AppLocalizations.of(context)!.vibe}',
                      AppLocalizations.of(context)!.vibe,
                ),
                Tab(
                  text:
                      // '$_followingCount ${AppLocalizations.of(context)!.revibe}',
                      AppLocalizations.of(context)!.revibe,
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            height: 43,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: TextField(
              controller: _searchController,
              cursorColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(0.8),
              cursorWidth: 1.5,
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
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              onChanged: _filterUsers,
            ),
          ),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Followers (Chase) tab ──
                _filteredFollowers.isEmpty
                    ? _buildEmptyState(
                        image: Assets.images.noChase.path,
                        title: _searchQuery.isEmpty
                            ? AppLocalizations.of(context)!.nochaseyet
                            : AppLocalizations.of(context)!.nousersfound,
                        message: _searchQuery.isEmpty
                            ? AppLocalizations.of(
                                context,
                              )!.whenpeoplechasechaseyoutheywillappearhere
                            : AppLocalizations.of(
                                context,
                              )!.trysearchingwithadifferent,
                      )
                    : ListView.builder(
                        itemCount: _filteredFollowers.length,
                        itemBuilder: (context, index) =>
                            _buildUserListItem(user: _filteredFollowers[index]),
                      ),

                // ── Following (Rechase) tab ──
                _filteredFollowing.isEmpty
                    ? _buildEmptyState(
                        image: Assets.images.noRechase.path,
                        title: _searchQuery.isEmpty
                            ? AppLocalizations.of(context)!.norechaseyet
                            : AppLocalizations.of(context)!.nousersfound,
                        message: _searchQuery.isEmpty
                            ? AppLocalizations.of(
                                context,
                              )!.stayactiveandsharepollstobuildyourcommunity
                            : AppLocalizations.of(
                                context,
                              )!.trysearchingwithadifferent,
                      )
                    : ListView.builder(
                        itemCount: _filteredFollowing.length,
                        itemBuilder: (context, index) =>
                            _buildUserListItem(user: _filteredFollowing[index]),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
