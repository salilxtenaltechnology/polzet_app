// screens/global_search_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../api/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/global search/global_search_model.dart';
import '../../../models/global search/recent_search.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import 'posts/hashtag_posts_list.dart';
import 'posts/single_post_details.dart';

// ─── Palette ────────────────────────────────────────────────────────────────

const _accent = AppColors.primaryColor;
const _accentSoft = Color(0x336C63FF);
const _textPrimary = Color(0xFFEEEEEE);
const _textSecondary = Color(0xFF888888);

// ─── Stream controller (static — shared across rebuilds) ─────────────────────
// Lives outside the widget so it survives hot-reload and screen pop/push.
// All UI that wraps a StreamBuilder on this stream updates silently whenever
// new data is pushed — no setState, no loading spinner.
final _searchStream = StreamController<GlobalSearchModel?>.broadcast();

// ─── Entry point ─────────────────────────────────────────────────────────────

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin, UtilityMixin {
  // ── Static cache — instant data on re-open ────────────────────────────────
  static GlobalSearchModel? _cachedDefaultResult;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  // _snapshot holds the latest value delivered by the stream so widgets
  // that are not inside a StreamBuilder can still read current data.
  GlobalSearchModel? _snapshot;

  bool _loading = false; // only true on very first open (no cache)
  Timer? _debounce;
  Timer? _autoRefreshTimer;

  static const _tabs = ['Top', 'Accounts', 'Posts', 'Photos', 'Tags', 'Places'];

  List<RecentSearchModel> _recentSearches = [];
  List<String> _removedSearchIds = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _fetchRecentSearches();

    // Mirror every stream event into _snapshot so non-StreamBuilder
    // widgets (tab bar visibility etc.) stay in sync.
    _searchStream.stream.listen((data) {
      if (mounted) setState(() => _snapshot = data);
    });

    if (_cachedDefaultResult != null) {
      // Push cache onto the stream immediately — UI renders without a spinner.
      _snapshot = _cachedDefaultResult;
      _searchStream.add(_cachedDefaultResult!);
      // Quietly fetch fresh data in the background.
      _silentRefresh();
    } else {
      // Very first open — show shimmer until data arrives.
      setState(() => _loading = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDefault());
    }

    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // ── Fetch helpers ─────────────────────────────────────────────────────────

  Future<void> _fetchRecentSearches() async {
    try {
      final response = await ApiService().getRecentSearch();
      final prefs = await SharedPreferences.getInstance();
      _removedSearchIds = prefs.getStringList('removed_recent_searches') ?? [];
      
      if (mounted) {
        setState(() {
          _recentSearches = response.data
              .where((item) => !_removedSearchIds.contains(item.id))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent searches: $e');
    }
  }

  Future<void> _removeRecentSearch(String id) async {
    setState(() {
      _recentSearches.removeWhere((item) => item.id == id);
      if (!_removedSearchIds.contains(id)) {
        _removedSearchIds.add(id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('removed_recent_searches', _removedSearchIds);
  }

  Future<void> _clearAllRecentSearches() async {
    setState(() {
      for (var item in _recentSearches) {
        if (!_removedSearchIds.contains(item.id)) {
          _removedSearchIds.add(item.id);
        }
      }
      _recentSearches.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('removed_recent_searches', _removedSearchIds);
  }

  /// First-open fetch — shows shimmer, then pushes result to stream.
  Future<void> _fetchDefault() async {
    try {
      final result = await ApiService().globalSearch('');
      if (!mounted) return;
      _cachedDefaultResult = result;
      _searchStream.add(result); // triggers StreamBuilder rebuild
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _silentRefresh() async {
    // Only refresh if user hasn't typed a query.
    if (_searchController.text.trim().isNotEmpty) return;
    try {
      final result = await ApiService().globalSearch('');
      if (!mounted) return;
      _cachedDefaultResult = result;
      _searchStream.add(result);
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    if (mounted) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      query.trim().isEmpty
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 500),
      () => _doSearch(query.trim()),
    );
  }

  /// Search for an explicit query — pushes result to stream.
  Future<void> _doSearch(String query) async {
    if (query.isEmpty) {
      if (_cachedDefaultResult != null) {
        _searchStream.add(_cachedDefaultResult!);
      } else {
        await _fetchDefault();
      }
      return;
    }
    
    if (mounted) setState(() => _loading = true);
    try {
      final result = await ApiService().globalSearch(query);
      if (!mounted) return;
      _searchStream.add(result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ImageProvider? _avatarProvider(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('data:image')) {
      return MemoryImage(base64Decode(raw.split(',').last));
    }
    return NetworkImage(raw);
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Uint8List? getProfileImage(dynamic profilePicture) {
    if (profilePicture == null || profilePicture.isEmpty) return null;
    try {
      final base64Data = (profilePicture as String).replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            // Tab bar is driven by _snapshot so it appears as soon as
            // the first stream event arrives.
            if (_snapshot != null && !(_focusNode.hasFocus && _searchController.text.isEmpty)) _buildTabBar(),
            Expanded(
              // StreamBuilder wraps the entire body so every push to
              // _searchStream triggers a silent, flicker-free rebuild.
              child: (_focusNode.hasFocus && _searchController.text.isEmpty)
                  ? _buildRecentSearchesList()
                  : StreamBuilder<GlobalSearchModel?>(
                stream: _searchStream.stream,
                initialData: _cachedDefaultResult,
                builder: (context, snap) {
                  // First open, no cache — shimmer
                  if (_loading && snap.data == null) return _buildShimmer();

                  // API error before any data — fallback prompt
                  if (snap.data == null) return _buildSearchPrompt();

                  final data = snap.data!.data;
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTopTab(data.accounts),
                      _buildAccountsList(data.accounts),
                      _buildPostsList(data.posts),
                      _buildPhotosList(data.photos),
                      _buildHashtagsList(data.hashtags),
                      _buildPlacesList(context),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 5).w,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 34.7.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                autofocus: false,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: _accent,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search accounts, posts, places…',
                  hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _textSecondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 8.h),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return TabBar(
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      tabAlignment: TabAlignment.fill,
      indicator: FadeUnderlineTabIndicator(),
      controller: _tabController,
      labelPadding: EdgeInsets.symmetric(horizontal: 5.w),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onBackground,
        fontSize: 11.2.sp,
        fontWeight: FontWeight.w500,
      ),
      dividerColor: Colors.transparent,
      unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
      tabs: _tabs.map((t) => Tab(text: t)).toList(),
    );
  }

  // ── Recent Searches ────────────────────────────────────────────────────────

  Widget _buildRecentSearchesList() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          'No recent searches',
          style: TextStyle(color: _textSecondary, fontSize: 13.sp),
        ),
      );
    }
    return ListView.builder(
      itemCount: _recentSearches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _clearAllRecentSearches,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final item = _recentSearches[index - 1];
        return ListTile(
          leading: const Icon(Icons.history, color: _textSecondary),
          title: Text(
            item.value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 13.sp,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: _textSecondary, size: 18),
            onPressed: () => _removeRecentSearch(item.id),
          ),
          onTap: () {
            _searchController.text = item.value;
            _focusNode.unfocus();
            _onSearchChanged(item.value);
          },
        );
      },
    );
  }

  // ── Fallback — only shown if API fails on very first open ─────────────────

  Widget _buildSearchPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded, color: _accent, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Search anything',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find accounts, posts, photos & more',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 12.w),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontSize: 11.2.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Top tab ────────────────────────────────────────────────────────────────

  Widget _buildTopTab(List<SearchAccount> accounts) {
    final query = _searchController.text.trim();

    // Active search with a query — show spinner
    if (_loading && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, color: _textSecondary, size: 26.sp),
            SizedBox(height: 12.h),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ],
        ),
      );
    }

    // No query — show only popular photos
    if (query.isEmpty) {
      return _buildDefaultTopSuggestions(_snapshot?.data.photos ?? []);
    }

    final data = _snapshot?.data;

    // Query typed but nothing found across all types
    final bool hasResults =
        accounts.isNotEmpty ||
        (data?.posts.isNotEmpty ?? false) ||
        (data?.photos.isNotEmpty ?? false) ||
        (data?.hashtags.isNotEmpty ?? false);

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: _textSecondary,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              'Not found "$query"',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for accounts, posts or hashtags',
              style: TextStyle(fontSize: 11.sp, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Has search results — show accounts + posts + photos + hashtags
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // ── Accounts ──────────────────────────────────────────────────────
        if (accounts.isNotEmpty) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader('Accounts'),
          ...accounts.map((acc) => _buildAccountTile(acc)),
        ],

        // ── Posts ─────────────────────────────────────────────────────────
        if (data?.posts.isNotEmpty ?? false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader('Posts'),
          ...data!.posts.map((post) => _buildPostTile(post)),
        ],

        // ── Photos ────────────────────────────────────────────────────────
        if (data?.photos.isNotEmpty ?? false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader('Photos'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: data!.photos.length,
            itemBuilder: (_, i) {
              final photo = data.photos[i];
              return _buildPhotoCell(data.photos[i], () {
                navigationPush(
                  context,
                  SinglePostDetails(
                    postId: photo.postId,
                    username: photo.author.username,
                  ),
                );
              });
            },
          ),
        ],

        // ── Hashtags ──────────────────────────────────────────────────────
        if (data?.hashtags.isNotEmpty ?? false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader('Tags'),
          ...data!.hashtags.map((tag) => _buildHashtagTile(tag)),
        ],
      ],
    );
  }

  // ── Default suggestions (Top tab, no query) ────────────────────────────────

  Widget _buildDefaultTopSuggestions(List<SearchPhoto> photos) {
    // _snapshot is the latest stream value — always up to date
    final data = _snapshot?.data;
    if (data == null || photos.isEmpty) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Photos
        if (data.photos.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: data.photos.length,
            itemBuilder: (_, i) {
              final photo = data.photos[i];
              return _buildPhotoCell(data.photos[i], () {
                navigationPush(
                  context,
                  SinglePostDetails(
                    postId: photo.postId,
                    username: photo.author.username,
                  ),
                );
              });
            },
          ),
        ],
      ],
    );
  }

  // ── Per-tab empty state ────────────────────────────────────────────────────

  Widget _buildTabEmpty(String label, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _textSecondary, size: 40),
          const SizedBox(height: 12),
          Text(
            'No $label found',
            style: const TextStyle(color: _textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.h, 0),
      itemCount: 10,
      itemBuilder: (_, __) => _ShimmerTile(),
    );
  }

  // ── Accounts tab ───────────────────────────────────────────────────────────

  Widget _buildAccountsList(List<SearchAccount> accounts) {
    if (accounts.isEmpty) {
      return _buildTabEmpty('accounts', Icons.person_search_rounded);
    }
    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (_, i) => _buildAccountTile(accounts[i]),
    );
  }

  Widget _buildAccountTile(SearchAccount acc) {
    final avatar = _avatarProvider(acc.profileImage);
    return GestureDetector(
      onTap: () => navigationPush(context, PublicProfile(userId: acc.id)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
        minVerticalPadding: 0,
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.08),
          backgroundImage: avatar,
          child: avatar == null
              ? Text(
                  acc.username.isNotEmpty ? acc.username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                acc.fullName.isEmpty ? acc.username : acc.fullName,
                style: TextStyle(
                  fontSize: 10.2.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (acc.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, color: _accent, size: 14),
            ],
          ],
        ),
        subtitle: Text(
          '@${acc.username} · ${_formatCount(acc.followersCount)} chases',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: ChaseButton(
          userId: acc.id,
          username: acc.username,
          isChase: acc.isFollowing,
        ),
      ),
    );
  }

  // ── Posts tab ──────────────────────────────────────────────────────────────

  Widget _buildPostsList(List<SearchPost> posts) {
    if (posts.isEmpty) return _buildTabEmpty('posts', Icons.article_outlined);
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (_, i) => _buildPostTile(posts[i]),
    );
  }

  Widget _buildPostTile(SearchPost post) {
    return GestureDetector(
      onTap: () {
        navigationPush(
          context,
          SinglePostDetails(username: post.author.username, postId: post.id),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 35.w,
                height: 30.h,
                color: AppColors.primaryColor.withOpacity(0.15),
                child:
                    post.thumbnail != null && post.thumbnail!.trim().isNotEmpty
                    ? Image.network(
                        post.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_rounded,
                          color: _textSecondary,
                        ),
                      )
                    : Icon(
                        post.postType == 'poll'
                            ? Icons.article
                            : post.postType == 'video'
                            ? Icons.play_circle_rounded
                            : Icons.image_rounded,
                        color: AppColors.primaryColor,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption.isNotEmpty)
                    Text(
                      post.caption,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: AppColors.primaryColor,
                        backgroundImage:
                            getProfileImage(post.author.profileImage) != null
                            ? MemoryImage(
                                getProfileImage(post.author.profileImage)!,
                              )
                            : null,
                        child: post.author.profileImage == null
                            ? Text(
                                post.author.username.isNotEmpty
                                    ? post.author.username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: _textPrimary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '@${post.author.username}',
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Photos tab ─────────────────────────────────────────────────────────────

  Widget _buildPhotosList(List<SearchPhoto> photos) {
    if (photos.isEmpty) {
      return _buildTabEmpty('photos', Icons.photo_library_outlined);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        return _buildPhotoCell(photo, () {
          navigationPush(
            context,
            SinglePostDetails(
              postId: photo.postId,
              username: photo.author.username,
            ),
          );
        });
      },
    );
  }

  Widget _buildPhotoCell(SearchPhoto photo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.grey[100]!,
        child: photo.imageUrl.trim().isNotEmpty
            ? Image.network(
                photo.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: _textSecondary,
                ),
              )
            : const Icon(Icons.broken_image_rounded, color: _textSecondary),
      ),
    );
  }

  // ── Hashtags tab ───────────────────────────────────────────────────────────

  Widget _buildHashtagsList(List<SearchHashtag> hashtags) {
    if (hashtags.isEmpty) return _buildTabEmpty('hashtags', Icons.tag_rounded);
    return ListView.builder(
      itemCount: hashtags.length,
      itemBuilder: (_, i) => _buildHashtagTile(hashtags[i]),
    );
  }

  Widget _buildHashtagTile(SearchHashtag tag) {
    return ListTile(
      onTap: () {
        navigationPush(context, HashtagPostsList(hashtag: tag.tag));
      },

      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      leading: Container(
        width: 35.w,
        height: 30.h,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '#',
            style: TextStyle(
              color: _accent,
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        tag.tag,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
      subtitle: Text(
        '${_formatCount(tag.postsCount)} posts',
        style: TextStyle(color: _textSecondary, fontSize: 10.sp),
      ),
    );
  }
}

// ── Places tab ─────────────────────────────────────────────────────────────

Widget _buildPlacesList(BuildContext context) {
  final places = [
    {
      'name': 'Ahmedabad',
      'subtitle': 'Gujarat, India',
      'icon': Icons.location_on_rounded,
    },
  ];

  return ListView.builder(
    itemCount: places.length,
    itemBuilder: (_, i) {
      final place = places[i];
      return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
        leading: Container(
          width: 35.w,
          height: 30.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).primaryColor.withOpacity(0.08),
          ),
          child: Center(
            child: Icon(place['icon'] as IconData, color: _accent, size: 18),
          ),
        ),
        title: Text(
          place['name'] as String,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        subtitle: Text(
          place['subtitle'] as String,
          style: TextStyle(color: _textSecondary, fontSize: 10.sp),
        ),
      );
    },
  );
}

// ─── Chase Button ─────────────────────────────────────────────────────────────

class ChaseButton extends StatefulWidget {
  final bool isChase;
  final String username;
  final int userId;

  const ChaseButton({
    super.key,
    required this.isChase,
    required this.username,
    required this.userId,
  });

  @override
  State<ChaseButton> createState() => _ChaseButtonState();
}

class _ChaseButtonState extends State<ChaseButton> {
  final Set<int> _chasedUserIds = {};
  @override
  void initState() {
    super.initState();
    if (widget.isChase) _chasedUserIds.add(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();

    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isChased = _chasedUserIds.contains(widget.userId);

        return GestureDetector(
          onTap: () async {
            if (isChased) {
              setLocalState(() => _chasedUserIds.remove(widget.userId));
              try {
                await apiService.unfriend(widget.userId);
              } catch (e) {
                setLocalState(() => _chasedUserIds.add(widget.userId));
              }
            } else {
              setLocalState(() => _chasedUserIds.add(widget.userId));
              try {
                await apiService.sendFriendRequest(widget.username);
              } catch (e) {
                setLocalState(() => _chasedUserIds.remove(widget.userId));
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 21.h,
            width: 63.w,
            margin: EdgeInsets.only(left: 10.w),
            decoration: BoxDecoration(
              color: isChased
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8.r),
              border: isChased
                  ? Border.all(width: 1, color: AppColors.primaryColor)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isChased ? 'Chased' : 'Chase',
                  style: TextStyle(
                    color: isChased ? AppColors.primaryColor : Colors.white,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Shimmer Tile ──────────────────────────────────────────────────────────────

class _ShimmerTile extends StatefulWidget {
  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(
          Colors.grey[300]!,
          Colors.grey[200]!,
          _anim.value,
        )!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 10).w,
          child: Row(
            children: [
              CircleAvatar(radius: 19, backgroundColor: color),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: 250,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 11,
                      width: 120,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
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
}
