// ignore_for_file: deprecated_member_use

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';
import 'package:polzet_app/api/api_config.dart';
import '../../../../widgets/button/chase/toggle_chase_button.dart';
import '../../../../widgets/tabbar/indicatore_animation.dart';
import '../../../../widgets/loader.dart';
import '../../../../provider/user_provider.dart';
import '../public/public_profile_screen.dart';

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ScrollController _chaseScrollController = ScrollController();
  final ScrollController _rechaseScrollController = ScrollController();

  final List<Map<String, dynamic>> _allFollowers = [];
  final List<Map<String, dynamic>> _allFollowing = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  List<Map<String, dynamic>> _filteredFollowing = [];

  bool _isLoadingChase = false;
  bool _isLoadingRechase = false;
  int _chasePage = 1;
  int _rechasePage = 1;
  bool _chaseHasMore = true;
  bool _rechaseHasMore = true;
  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    _chaseScrollController.addListener(_onChaseScroll);
    _rechaseScrollController.addListener(_onRechaseScroll);

    _fetchChasePage(1, isRefresh: true);
    _fetchRechasePage(1, isRefresh: true);
  }

  void _onChaseScroll() {
    if (!mounted) return;
    if (_chaseScrollController.position.pixels >=
            _chaseScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingChase &&
        _chaseHasMore) {
      _fetchChasePage(_chasePage + 1);
    }
  }

  void _onRechaseScroll() {
    if (!mounted) return;
    if (_rechaseScrollController.position.pixels >=
            _rechaseScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingRechase &&
        _rechaseHasMore) {
      _fetchRechasePage(_rechasePage + 1);
    }
  }

  Future<void> _fetchChasePage(int page, {bool isRefresh = false}) async {
    if (_isLoadingChase) return;
    setState(() {
      _isLoadingChase = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';

      final response = await apiService.fetchChaseList(
        targetUserId: myUserId,
        page: page,
      );

      if (response != null && mounted) {
        final List<dynamic> results = response['results'] ?? [];
        final mapped = results.map<Map<String, dynamic>>((e) {
          final rawStatus = e['follow_status'] ?? e['followStatus'];
          final followStatus = rawStatus != null
              ? rawStatus.toString().toLowerCase()
              : 'none';

          return {
            'user_id': e['id']?.toString() ?? '',
            'username': e['username'] ?? '',
            'first_name': e['first_name'] ?? '',
            'last_name': e['last_name'] ?? '',
            'avatar_url': e['profile_picture_url'],
            'is_online': false,
            'follow_status': followStatus,
            'is_private': e['is_private'] == true,
          };
        }).toList();

        setState(() {
          if (isRefresh) {
            _allFollowers.clear();
          }
          _allFollowers.addAll(mapped);
           _chasePage = page;
           _chaseHasMore = response['next'] != null;
           _filterUsers(_searchController.text);
        });
      }
    } catch (e) {
      debugPrint('Error fetching chase list page $page: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChase = false;
        });
      }
    }
  }

  Future<void> _fetchRechasePage(int page, {bool isRefresh = false}) async {
    if (_isLoadingRechase) return;
    setState(() {
      _isLoadingRechase = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';

      final response = await apiService.fetchRechaseList(
        targetUserId: myUserId,
        page: page,
      );

      if (response != null && mounted) {
        final List<dynamic> results = response['results'] ?? [];
        final mapped = results.map<Map<String, dynamic>>((e) {
          final rawStatus = e['follow_status'] ?? e['followStatus'];
          final followStatus = rawStatus != null
              ? rawStatus.toString().toLowerCase()
              : 'none';

          return {
            'user_id': e['id']?.toString() ?? '',
            'username': e['username'] ?? '',
            'first_name': e['first_name'] ?? '',
            'last_name': e['last_name'] ?? '',
            'avatar_url': e['profile_picture_url'],
            'is_online': false,
            'follow_status': followStatus,
            'is_private': e['is_private'] == true,
          };
        }).toList();

        setState(() {
          if (isRefresh) {
            _allFollowing.clear();
          }
          _allFollowing.addAll(mapped);
           _rechasePage = page;
           _rechaseHasMore = response['next'] != null;
           _filterUsers(_searchController.text);
        });
      }
    } catch (e) {
      debugPrint('Error fetching rechase list page $page: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRechase = false;
        });
      }
    }
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
    _chaseScrollController.dispose();
    _rechaseScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState({
    required String image,
    required String title,
    required String message,
    required Future<void> Function() onRefresh,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
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
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateUserFollowStatus(String userId, String newStatus) {
    setState(() {
      for (var user in _allFollowers) {
        if (user['user_id']?.toString() == userId) {
          user['follow_status'] = newStatus;
        }
      }
      for (var user in _filteredFollowers) {
        if (user['user_id']?.toString() == userId) {
          user['follow_status'] = newStatus;
        }
      }
      for (var user in _allFollowing) {
        if (user['user_id']?.toString() == userId) {
          user['follow_status'] = newStatus;
        }
      }
      for (var user in _filteredFollowing) {
        if (user['user_id']?.toString() == userId) {
          user['follow_status'] = newStatus;
        }
      }
    });
  }

  Widget _buildUserListItem({required Map<String, dynamic> user}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final profilePic = user['avatar_url'] as String?;
    final firstName = user['first_name'] ?? 'Polzet';
    final lastName = user['last_name'] ?? 'User';
    final username = user['username'] as String? ?? '';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final userId = user['user_id']?.toString() ?? '';
    final followStatus = user['follow_status'] as String? ?? '';
    final isPrivate = user['is_private'] == true;

    return GestureDetector(
      onTap: () => navigationPush(
        context,
        PublicProfileScreen(userId: userId, username: username),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10),
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
                color: isDarkMode
                    ? const Color(0xFF252525)
                    : Theme.of(context).primaryColor.withOpacity(0.08),
              ),
              child: ClipOval(
                child: (() {
                  if (profilePic != null && profilePic.isNotEmpty) {
                    final bytes = getProfileImage(profilePic);
                    if (bytes != null) {
                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
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
                        ),
                      );
                    }
                    final imageUrl = profilePic.startsWith('http')
                        ? profilePic
                        : (profilePic.startsWith('/')
                              ? '${ApiConfig.baseUrlImage}$profilePic'
                              : '${ApiConfig.baseUrlImage}/$profilePic');
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
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
                      ),
                    );
                  }
                  return Center(
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
                  );
                })(),
              ),
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
            if (userProvider.userId?.toString() != userId)
              ToggleChaseButton(
                username: username,
                userId: userId,
                followStatus: followStatus,
                apiService: apiService,
                isPrivate: isPrivate,
                onToggle: (newStatus) {
                  userProvider.loadUserDataSilently();
                  _updateUserFollowStatus(userId, newStatus);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    bool isLoading,
    ScrollController scrollController,
    Future<void> Function() onRefresh,
    Widget emptyState,
  ) {
    if (isLoading && users.isEmpty) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (users.isEmpty) {
      return emptyState;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == users.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Center(
                child: Loader(color: Theme.of(context).colorScheme.primary),
              ),
            );
          }
          final user = users[index];
          return _buildUserListItem(user: user);
        },
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
                Tab(text: AppLocalizations.of(context)!.vibe),
                Tab(text: AppLocalizations.of(context)!.revibe),
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
                _buildUserList(
                  _filteredFollowers,
                  _isLoadingChase,
                  _chaseScrollController,
                  () => _fetchChasePage(1, isRefresh: true),
                  _buildEmptyState(
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
                    onRefresh: () => _fetchChasePage(1, isRefresh: true),
                  ),
                ),

                // ── Following (Rechase) tab ──
                _buildUserList(
                  _filteredFollowing,
                  _isLoadingRechase,
                  _rechaseScrollController,
                  () => _fetchRechasePage(1, isRefresh: true),
                  _buildEmptyState(
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
                    onRefresh: () => _fetchRechasePage(1, isRefresh: true),
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
