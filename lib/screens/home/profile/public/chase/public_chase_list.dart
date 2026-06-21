// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../api/services/validator/api_service.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/base64/image_convert.dart';
import 'package:polzet_app/api/api_config.dart';
import '../../../../../widgets/button/chase/toggle_chase_button.dart';
import '../../../../../widgets/loader.dart';
import '../../../../../widgets/tabbar/indicatore_animation.dart';
import '../public_profile_screen.dart';

class PublicChaseList extends StatefulWidget {
  final dynamic userId;
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
  // int _chaseCount = 0;
  // int _rechaseCount = 0;

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
        'first_name': e.firstName,
        'last_name': e.lastName,
        'avatar_url': e.avatarUrl,
        'is_online': e.isOnline ?? false,
        'follow_status': e.followStatus,
        'is_private': e.isPrivate ?? false,
      };
    }).toList();

    final rechase = (widget.rechaseList ?? []).map<Map<String, dynamic>>((e) {
      return {
        'user_id': e.userId,
        'username': e.username,
        'first_name': e.firstName,
        'last_name': e.lastName,
        'avatar_url': e.avatarUrl,
        'is_online': e.isOnline ?? false,
        'follow_status': e.followStatus,
        'is_private': e.isPrivate ?? false,
      };
    }).toList();

    setState(() {
      _chaseList = chase;
      _rechaseList = rechase;
      _filteredChaseList = chase;
      _filteredRechaseList = rechase;
      // _chaseCount = chase.length;
      // _rechaseCount = rechase.length;
    });
  }

  void _filterList(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredChaseList = _chaseList;
        _filteredRechaseList = _rechaseList;
      } else {
        _filteredChaseList = _chaseList.where((user) {
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final firstName =
              (user['first_name'] as String?)?.toLowerCase() ?? '';
          final lastName = (user['last_name'] as String?)?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();

          return username.contains(q) ||
              firstName.contains(q) ||
              lastName.contains(q) ||
              fullName.contains(q);
        }).toList();

        _filteredRechaseList = _rechaseList.where((user) {
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final firstName =
              (user['first_name'] as String?)?.toLowerCase() ?? '';
          final lastName = (user['last_name'] as String?)?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();

          return username.contains(q) ||
              firstName.contains(q) ||
              lastName.contains(q) ||
              fullName.contains(q);
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
                      //  '$_chaseCount ${AppLocalizations.of(context)!.vibe}'
                      AppLocalizations.of(context)!.vibe,
                ),
                Tab(
                  text:
                      // '$_rechaseCount ${AppLocalizations.of(context)!.revibe}',
                      AppLocalizations.of(context)!.revibe,
                ),
              ],
            ),
          ),
          Container(
            height: 43,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 15.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
              ),
              onChanged: _filterList,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(
                  _filteredChaseList,
                  _isLoadingChase,
                  'No chase users',
                ),
                _buildUserList(
                  _filteredRechaseList,
                  _isLoadingRechase,
                  'No re-chase users',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    bool isLoading,
    String emptyMessage,
  ) {
    final txt = AppTextColors.of(context);
    if (isLoading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isNotEmpty
              ? AppLocalizations.of(context)!.nousersfound
              : emptyMessage,
          style: AppTextStyles.sectionHeading.copyWith(
            fontSize: 18.5,
            color: txt.title,
            fontWeight: FontWeight.w600,
            height: 1.4,
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
    final txt = AppTextColors.of(context);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final firstName = user['first_name'] ?? 'Polzet';
    final lastName = user['last_name'] ?? 'User';
    final userName = user['username'] ?? 'polzet_user';
    final avatarUrl = user['avatar_url'];
    final isOnline = user['is_online'] as bool? ?? false;
    final followStatus = user['follow_status'] ?? 'none';
    final isPrivate = user['is_private'] == true;

    return GestureDetector(
      onTap: () {
        navigationPush(context, PublicProfileScreen(userId: user['user_id']?.toString() ?? ''));
      },
      child: Padding(
        padding: const EdgeInsetsGeometry.symmetric(vertical: 10),
        child: Row(
          children: [
            _buildAvatar(userName, avatarUrl, isOnline),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if ('$firstName $lastName'.trim().isNotEmpty) ...[
                    Text(
                      '$userName',
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
                      '$userName',
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.body,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$userName',
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
            if (userProvider.userId?.toString() != user['user_id']?.toString())
              ToggleChaseButton(
                username: userName,
                userId: user['user_id'],
                followStatus: followStatus,
                apiService: apiService,
                isPrivate: isPrivate,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String userName, String? avatarUrl, bool isOnline) {
    final imageBytes = getConvertImage(avatarUrl);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
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
            color: isDarkMode
                ? const Color(0xFF252525)
                : Theme.of(context).primaryColor.withOpacity(0.08),
          ),
          child: ClipOval(
            child: (() {
              if (avatarUrl != null && avatarUrl.isNotEmpty) {
                if (imageBytes != null) {
                  return Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitialsAvatar(userName),
                  );
                }
                final imageUrl = avatarUrl.startsWith('http')
                    ? avatarUrl
                    : (avatarUrl.startsWith('/')
                        ? '${ApiConfig.baseUrlImage}$avatarUrl'
                        : '${ApiConfig.baseUrlImage}/$avatarUrl');
                return CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildInitialsAvatar(userName),
                );
              }
              return _buildInitialsAvatar(userName);
            })(),
          ),
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
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        ),
      ),
    );
  }
}
