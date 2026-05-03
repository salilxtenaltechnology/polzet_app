// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../api/services/api_service.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/custom_text_styles.dart';
import '../../../../../widgets/loader.dart';
import '../../../../../widgets/tabbar/indicatore_animation.dart';
import '../public_profile.dart';

class PublicChaseList extends StatefulWidget {
  final int userId;
  final String? username;
  final int initialIndex;
  final List<dynamic>? chaseList;
  final List<dynamic>? rechaseList;

  const PublicChaseList({
    super.key,
    required this.userId,
    required this.username,
    required this.initialIndex,
    required this.chaseList,
    required this.rechaseList,
  });

  @override
  State<PublicChaseList> createState() => _PublicChaseListState();
}

class _PublicChaseListState extends State<PublicChaseList>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _chaseList = [];
  List<Map<String, dynamic>> _rechaseList = [];
  List<Map<String, dynamic>> _filteredChaseList = [];
  List<Map<String, dynamic>> _filteredRechaseList = [];

  bool _isLoadingChase = false;
  bool _isLoadingRechase = false;
  int _chaseCount = 0;
  int _rechaseCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _initFromPassedLists();
  }

  void _initFromPassedLists() {
    final chase = (widget.chaseList ?? []).map<Map<String, dynamic>>((e) {
      return {
        'user_id': e.userId,
        'username': e.username,
        'avatar_url': e.avatarUrl,
        'is_online': e.isOnline ?? false,
      };
    }).toList();

    final rechase = (widget.rechaseList ?? []).map<Map<String, dynamic>>((e) {
      return {
        'user_id': e.userId,
        'username': e.username,
        'avatar_url': e.avatarUrl,
        'is_online': e.isOnline ?? false,
      };
    }).toList();

    setState(() {
      _chaseList = chase;
      _rechaseList = rechase;
      _filteredChaseList = chase;
      _filteredRechaseList = rechase;
      _chaseCount = chase.length;
      _rechaseCount = rechase.length;
    });
  }

  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChaseList = _chaseList;
        _filteredRechaseList = _rechaseList;
      } else {
        _filteredChaseList = _chaseList.where((user) {
          final name = (user['username'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        _filteredRechaseList = _rechaseList.where((user) {
          final name = (user['username'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: widget.username ?? ''),

      body: Column(
        children: [
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
              labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11.sp,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11.sp,
              ),
              dividerColor: Colors.transparent,
              unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
              tabs: [
                Tab(text: '$_chaseCount ${AppLocalizations.of(context)!.vibe}'),
                Tab(
                  text:
                      '$_rechaseCount ${AppLocalizations.of(context)!.revibe}',
                ),
              ],
            ),
          ),
          Container(
            height: AppConstants.searchbarHeight.h,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 15.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.button),
              boxShadow: const [AppConstants.cardShadow],
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
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: AppColors.primaryColor,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
              onChanged: _filterList,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_filteredChaseList, _isLoadingChase),
                _buildUserList(_filteredRechaseList, _isLoadingRechase),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, bool isLoading) {
    if (isLoading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10.4.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userName = user['username'] ?? 'Unknown User';
    final avatarUrl = user['avatar_url'];
    final isOnline = user['is_online'] as bool? ?? false;

    return GestureDetector(
      onTap: () {
        navigationPush(context, PublicProfile(userId: user['user_id']));
      },
      child: Container(
        height: 40.h,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: const [
            BoxShadow(color: Color(0x1C000000), blurRadius: 5, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(userName, avatarUrl, isOnline),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                userName,
                style: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String userName, String? avatarUrl, bool isOnline) {
    final imageBytes = getConvertImage(avatarUrl);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 28.h,
          width: 28.w,
          margin: EdgeInsets.only(right: 5.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD1D1D1).withOpacity(0.7)),
            image: avatarUrl != null && avatarUrl.isNotEmpty
                ? DecorationImage(
                    image: MemoryImage(imageBytes!),
                    fit: BoxFit.cover,
                  )
                : null,
            color: avatarUrl == null
                ? Theme.of(context).primaryColor.withOpacity(0.08)
                : null,
          ),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? _buildInitialsAvatar(userName)
              : null,
        ),
        // Green dot indicator
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 3.w,
            child: Container(
              height: 10.h,
              width: 10.w,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String userName) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
