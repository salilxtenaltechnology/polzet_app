// screens/global_search_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:polzet_app/data/token/shared_preferences.dart';
import '../../../api/services/api_service.dart';
import '../../../api/api_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/global search/global_search_model.dart';
import '../../../models/global search/recent_search.dart';
import '../../../widgets/button/chase/toggle_chase_button.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import '../profile/public/public_profile_screen.dart';
import 'posts/hashtag_posts_list.dart';
import 'posts/single_post_details.dart';

// ─── Palette ────────────────────────────────────────────────────────────────

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
  static final Map<String, GlobalSearchModel> _tabSearchCache = {};
  int? _fetchingPage;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  // _snapshot holds the latest value delivered by the stream so widgets
  // that are not inside a StreamBuilder can still read current data.
  GlobalSearchModel? _snapshot;

  bool _loading = false; // only true on very first open (no cache)
  Timer? _debounce;
  Timer? _autoRefreshTimer;
  Future<String?>? _authTokenFuture;
  bool _forceShowTabs = false;

  static const _tabs = ['Top', 'Accounts', 'Polls', 'Photos', 'Tags', 'Places'];

  List<RecentSearchModel> _recentSearches = [];
  List<String> _removedSearchIds = [];

  int _currentTabIndex = 0;
  bool _loadingMore = false;

  bool _shouldCache(String query, String tab) {
    if (query.isEmpty) {
      return tab == 'top';
    }
    return true;
  }

  String _getApiTabValue(int index) {
    if (index < 0 || index >= _tabs.length) return 'top';
    final tabName = _tabs[index].toLowerCase();
    if (tabName == 'polls') return 'posts';
    return tabName;
  }

  void _handleTabSelection() {
    if (_tabController.index != _currentTabIndex) {
      _currentTabIndex = _tabController.index;
      _fetchingPage = null; // Reset fetching page tracker on tab change!
      _doSearch(_searchController.text.trim());
    }
  }

  Widget _wrapWithScrollListener(Widget child) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo is ScrollUpdateNotification ||
            scrollInfo is OverscrollNotification) {
          final metrics = scrollInfo.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) {
            _loadNextPage();
          }
        }
        return true;
      },
      child: child,
    );
  }

  Future<void> _loadNextPage() async {
    final currentModel = _snapshot;
    if (currentModel == null) return;
    if (_loading || _loadingMore) return;

    final pagination = currentModel.pagination;
    if (!pagination.hasNext) return;

    final nextPage = pagination.page + 1;
    if (_fetchingPage == nextPage) return;
    _fetchingPage = nextPage;

    final tab = _getApiTabValue(_tabController.index);
    final query = _searchController.text.trim();

    if (mounted) setState(() => _loadingMore = true);

    try {
      final userId = await SharedPrefService.getUserId();
      final nextResult = await ApiService().globalSearch(
        query,
        tab: tab,
        page: nextPage,
        limit: 10,
        publicId: userId,
      );

      if (nextResult == null || !mounted) return;

      final currentData = currentModel.data;
      final nextData = nextResult.data;

      final mergedAccounts = List<SearchAccount>.from(currentData.accounts)
        ..addAll(nextData.accounts);
      final mergedPosts = List<SearchPost>.from(currentData.posts)
        ..addAll(nextData.posts);
      final mergedPhotos = List<SearchPhoto>.from(currentData.photos)
        ..addAll(nextData.photos);
      final mergedHashtags = List<SearchHashtag>.from(currentData.hashtags)
        ..addAll(nextData.hashtags);
      final mergedPlaces = List<SearchPlace>.from(currentData.places)
        ..addAll(nextData.places);

      final updatedModel = GlobalSearchModel(
        success: nextResult.success,
        query: nextResult.query,
        tab: nextResult.tab,
        pagination: nextResult.pagination,
        data: GlobalSearchData(
          accounts: mergedAccounts,
          posts: mergedPosts,
          photos: mergedPhotos,
          hashtags: mergedHashtags,
          places: mergedPlaces,
        ),
      );

      _searchStream.add(updatedModel);
    } catch (e) {
      debugPrint('Error loading next page: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _authTokenFuture = SharedPrefService.getToken();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _currentTabIndex = _tabController.index;
    _tabController.addListener(_handleTabSelection);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _fetchRecentSearches();

    // Mirror every stream event into _snapshot so non-StreamBuilder
    // widgets (tab bar visibility etc.) stay in sync.
    _searchStream.stream.listen((data) {
      if (mounted) setState(() => _snapshot = data);
    });

    final activeTab = _getApiTabValue(_tabController.index);
    final cached = _tabSearchCache['$activeTab|'];
    if (cached != null) {
      _snapshot = cached;
      _searchStream.add(cached);
      _silentRefresh();
      _preloadAllTabs();
    } else {
      _preloadAllTabs();
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
    _tabController.removeListener(_handleTabSelection);
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

  Future<void> _preloadAllTabs() async {
    final activeTab = _getApiTabValue(_tabController.index);
    if (!_tabSearchCache.containsKey('$activeTab|')) {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final userId = await SharedPrefService.getUserId();
      await Future.wait([
        _preloadTab('top', userId),
        _preloadTab('accounts', userId),
        _preloadTab('posts', userId),
        _preloadTab('photos', userId),
        _preloadTab('tags', userId),
        _preloadTab('places', userId),
      ]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preloadTab(String tab, String? userId) async {
    try {
      final cacheKey = '$tab|';
      final result = await ApiService().globalSearch(
        '',
        tab: tab,
        page: 1,
        limit: 10,
        publicId: userId,
      );
      if (result != null) {
        _tabSearchCache[cacheKey] = result;
        if (tab == 'top') {
          _cachedDefaultResult = result;
        }

        final activeTab = _getApiTabValue(_tabController.index);
        if (tab == activeTab && _searchController.text.trim().isEmpty) {
          _snapshot = result;
          _searchStream.add(result);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error preloading tab $tab: $e');
    }
  }

  Future<void> _silentRefresh() async {
    // Only refresh if user hasn't typed a query.
    if (_searchController.text.trim().isNotEmpty) return;
    try {
      final userId = await SharedPrefService.getUserId();
      final tab = _getApiTabValue(_tabController.index);
      final result = await ApiService().globalSearch(
        '',
        tab: tab,
        page: 1,
        limit: 10,
        publicId: userId,
      );
      if (!mounted) return;
      if (result != null) {
        if (_shouldCache('', tab)) {
          _tabSearchCache['$tab|'] = result;
        }
        if (tab == 'top') {
          _cachedDefaultResult = result;
        }
      }

      final activeTab = _getApiTabValue(_tabController.index);
      if (result != null &&
          result.tab == activeTab &&
          _searchController.text.trim().isEmpty) {
        _searchStream.add(result);
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _forceShowTabs = false;
    _fetchingPage = null; // Reset fetching page tracker on query change!
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
    final tab = _getApiTabValue(_tabController.index);
    final cacheKey = '$tab|$query';

    // If cache exists, push it immediately so the UI transitions instantly.
    if (_shouldCache(query, tab) && _tabSearchCache.containsKey(cacheKey)) {
      _snapshot = _tabSearchCache[cacheKey];
      _searchStream.add(_snapshot);
      if (mounted) setState(() {});
    } else {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final userId = await SharedPrefService.getUserId();
      final result = await ApiService().globalSearch(
        query,
        tab: tab,
        page: 1,
        limit: 10,
        publicId: userId,
      );
      if (!mounted) return;

      if (result != null) {
        if (_shouldCache(query, tab)) {
          _tabSearchCache[cacheKey] = result;
        }
        if (query.isEmpty && tab == 'top') {
          _cachedDefaultResult = result;
        }
      }

      final activeTab = _getApiTabValue(_tabController.index);
      final currentQuery = _searchController.text.trim();
      if (result != null &&
          result.tab == activeTab &&
          result.query == currentQuery) {
        _searchStream.add(result);
      }
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
    //  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            // Tab bar is driven by _snapshot so it appears as soon as
            // the first stream event arrives.
            if (_snapshot != null &&
                (_searchController.text.trim().isNotEmpty || _forceShowTabs))
              _buildTabBar(),
            Expanded(
              // StreamBuilder wraps the entire body so every push to
              // _searchStream triggers a silent, flicker-free rebuild.
              child:
                  (_focusNode.hasFocus &&
                      _searchController.text.isEmpty &&
                      !_forceShowTabs)
                  ? _buildRecentSearchesList()
                  : StreamBuilder<GlobalSearchModel?>(
                      stream: _searchStream.stream,
                      initialData: _cachedDefaultResult,
                      builder: (context, snap) {
                        // First open, no cache — shimmer
                        if (_loading && _snapshot == null) {
                          // return _buildShimmer();
                          return Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          );
                        }

                        // API error before any data — fallback prompt
                        if (_snapshot == null) return _buildSearchPrompt();

                        final data = _snapshot!.data;
                        if (_searchController.text.trim().isEmpty &&
                            !_forceShowTabs) {
                          return _buildDefaultSuggestions(
                            data.accounts,
                            data.posts,
                          );
                        }
                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _wrapWithScrollListener(
                              _buildTopTab(data.accounts),
                            ),
                            _wrapWithScrollListener(
                              _buildAccountsList(data.accounts),
                            ),
                            _wrapWithScrollListener(
                              _buildPollsList(data.posts),
                            ),
                            _wrapWithScrollListener(
                              _buildPhotosList(data.photos),
                            ),
                            _wrapWithScrollListener(
                              _buildHashtagsList(data.hashtags),
                            ),
                            _wrapWithScrollListener(
                              _buildPlacesList(data.places),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_loadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5).w,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                autofocus: false,
                cursorColor: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.8),
                cursorWidth: 1.5,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(
                    context,
                  )!.searchaccountspostsplaces,
                  hintStyle: AppTextStyles.bodyText.copyWith(
                    color: const Color(0XFF898989),
                    fontWeight: FontWeight.w400,
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    FeatherIcons.search,
                    size: 17.spMax,
                    color: const Color(0XFF898989),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0XFF898989),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.outline
                          : const Color(0xFFDCDCDC),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
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
    final txt = AppTextColors.of(context);
    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          'No recent searches',
          style: AppTextStyles.bodyText.copyWith(
            color: txt.muted,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
          ),
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
                  AppLocalizations.of(context)!.recentsearches,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _clearAllRecentSearches,
                  child: Text(
                    AppLocalizations.of(context)!.clearall,
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
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDarkMode
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Image.asset(
                    Assets.images.noSearchFound.path,
                    height: 180,
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                ),
          Text(
            'Search anything',
            style: AppTextStyles.sectionHeading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: txt.title,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find accounts, posts, photos & more',
            style: AppTextStyles.bodyText.copyWith(
              color: txt.muted,
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.4,
            ),
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
        style: AppTextStyles.cardTitle.copyWith(
          color: Theme.of(context).colorScheme.onBackground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Top tab ────────────────────────────────────────────────────────────────

  Widget _buildTopTab(List<SearchAccount> accounts) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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

    // No query — show default suggestions (accounts and polls)
    if (query.isEmpty) {
      return _buildDefaultSuggestions(
        _snapshot?.data.accounts ?? [],
        _snapshot?.data.posts ?? [],
      );
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isDarkMode
                ? const SizedBox()
                : Image.asset(
                    Assets.images.noSearchFound.path,
                    height: 0.22.sh,
                    width: 0.22.sh,
                    fit: BoxFit.contain,
                  ),
            const SizedBox(height: 15),
            Text(
              '${AppLocalizations.of(context)!.notfound} "$query"',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionHeading.copyWith(
                fontSize: 15.5,
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(
                context,
              )!.tryanotherkeywordorexploretrendingpolls,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                color: const Color(0xFF595959),
                height: 1.4,
              ),
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

        // ── Polls (Things Only) ───────────────────────────────────────────
        if (data?.posts.any((post) {
              final poll = post.polls.isNotEmpty ? post.polls.first : null;
              final bool isImage =
                  poll != null && poll.options.any((o) => o.image != null);
              return !isImage;
            }) ??
            false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader('Polls'),
          ...data!.posts
              .where((post) {
                final poll = post.polls.isNotEmpty ? post.polls.first : null;
                final bool isImage =
                    poll != null && poll.options.any((o) => o.image != null);
                return !isImage;
              })
              .map((post) => _buildSearchPostCard(post)),
        ],

        // ── Posts ─────────────────────────────────────────────────────────
        if (data?.posts.any(
              (post) =>
                  post.thumbnail != null && post.thumbnail!.trim().isNotEmpty,
            ) ??
            false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader(AppLocalizations.of(context)!.posts),
          ...data!.posts
              .where(
                (post) =>
                    post.thumbnail != null && post.thumbnail!.trim().isNotEmpty,
              )
              .map((post) => _buildTopTabPostCard(post)),
        ],

        // ── Photos ────────────────────────────────────────────────────────
        if (data?.photos.isNotEmpty ?? false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader(AppLocalizations.of(context)!.photos),
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
                final String username = photo.username.isNotEmpty
                    ? photo.username
                    : photo.author.username;
                navigationPush(
                  context,
                  SinglePostDetails(postId: photo.postId, username: username),
                );
              });
            },
          ),
        ],

        // ── Hashtags ──────────────────────────────────────────────────────
        if (data?.hashtags.isNotEmpty ?? false) ...[
          SizedBox(height: 8.h),
          _buildSectionHeader('Tags'),
          const SizedBox(height: 10),
          ...data!.hashtags.map((tag) => _buildHashtagTile(tag)),
        ],
      ],
    );
  }

  // ── Default suggestions (Top tab, no query) ────────────────────────────────

  Widget _buildTopTabPostCard(SearchPost post) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        navigationPush(
          context,
          SinglePostDetails(username: post.author.username, postId: post.id),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                : const Color(0XFFEFEFEF),
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail Image on the left
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                width: 75,
                height: 70.w,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                child:
                    post.thumbnail != null && post.thumbnail!.trim().isNotEmpty
                    ? _buildNetworkImage(post.thumbnail!)
                    : const Icon(Icons.image_rounded, color: _textSecondary),
              ),
            ),
            SizedBox(width: 16.w),
            // Title, Avatars & Vote count on the right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    post.caption.isNotEmpty ? post.caption : post.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '@${post.author.username}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w500,
                      color: txt.body,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTypeIcon(SearchPost post, Color color, {double size = 10}) {
    if (post.thumbnail == null || post.thumbnail!.trim().isEmpty) {
      return Assets.images.thingsIcon.image(
        color: color,
        width: size,
        height: size,
      );
    } else {
      return Assets.images.imageIcon.image(
        color: color,
        width: size,
        height: size,
      );
    }
  }

  Widget _buildTrendingPollCard(SearchPost post) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        navigationPush(
          context,
          SinglePostDetails(username: post.author.username, postId: post.id),
        );
      },
      child: Container(
        width: 145.w,
        margin: EdgeInsets.only(right: 12.w, bottom: 8.h),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                : const Color(0XFFEFEFEF),
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.button),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.1),
                    child:
                        post.thumbnail != null &&
                            post.thumbnail!.trim().isNotEmpty
                        ? _buildNetworkImage(post.thumbnail!)
                        : _buildPostTypeIcon(
                            post,
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                  ),
                ),
              ),
            ),
            // Title
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.w, 2.h, 10.w, 8.h),
                child: Text(
                  post.caption.isNotEmpty ? post.caption : post.title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onBackground,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingPollsSection(List<SearchPost> posts) {
    final validPosts = posts
        .where(
          (post) => post.thumbnail != null && post.thumbnail!.trim().isNotEmpty,
        )
        .toList();
    if (validPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Trending Polls",
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _forceShowTabs = true;
                    _tabController.animateTo(2);
                  });
                },
                child: Text(
                  AppLocalizations.of(context)!.seeall,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: validPosts.length,
            itemBuilder: (context, index) {
              return _buildTrendingPollCard(validPosts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularThingsSection(List<SearchPost> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Popular things",
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _forceShowTabs = true;
                    _tabController.animateTo(2);
                  });
                },
                child: Text(
                  AppLocalizations.of(context)!.seeall,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...posts.map((post) => _buildPopularThingCard(post)),
      ],
    );
  }

  Widget _buildPopularThingCard(SearchPost post) {
    final poll = post.polls.isNotEmpty ? post.polls.first : null;
    if (poll == null) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final optionsCount = poll.options.length;
    final children = <Widget>[];

    if (optionsCount > 0) {
      children.add(
        Expanded(child: _buildPopularThingOption(poll.options[0].text ?? '')),
      );
    }
    if (optionsCount > 1) {
      if (optionsCount == 2) {
        children.add(SizedBox(width: 8.w));
        children.add(
          Expanded(child: _buildPopularThingOption(poll.options[1].text ?? '')),
        );
      } else {
        children.add(SizedBox(width: 8.w));
        children.add(
          Expanded(child: _buildPopularThingOption(poll.options[1].text ?? '')),
        );
        children.add(SizedBox(width: 8.w));
        children.add(
          Expanded(
            child: _buildPopularThingOption(
              '+${optionsCount - 2} more',
              isMore: true,
            ),
          ),
        );
      }
    }

    return GestureDetector(
      onTap: () {
        navigationPush(
          context,
          SinglePostDetails(username: post.author.username, postId: post.id),
        );
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                : const Color(0XFFEFEFEF),
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.description.isNotEmpty ? post.description : poll.question,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularThingOption(String text, {bool isMore = false}) {
    final txt = AppTextColors.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isMore ? FontWeight.w600 : FontWeight.w400,
            color: txt.title,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultSuggestions(
    List<SearchAccount> accounts,
    List<SearchPost> posts,
  ) {
    // _snapshot is the latest stream value — always up to date
    final data = _snapshot?.data;
    if (data == null || (accounts.isEmpty && posts.isEmpty)) {
      return const SizedBox.shrink();
    }

    final validPosts = posts
        .where(
          (post) => post.thumbnail != null && post.thumbnail!.trim().isNotEmpty,
        )
        .toList();

    final thingsPosts = posts.where((post) {
      final poll = post.polls.isNotEmpty ? post.polls.first : null;
      final bool isImage =
          poll != null && poll.options.any((o) => o.image != null);
      return !isImage;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (validPosts.isNotEmpty) ...[
          _buildTrendingPollsSection(validPosts),
          SizedBox(height: 16.h),
        ],

        // Accounts - Shown SECOND!
        if (accounts.isNotEmpty) ...[
          _buildSectionHeader('Accounts'),
          SizedBox(height: 8.h),
          ...accounts.map((acc) => _buildAccountTile(acc)),
        ],

        // Popular things - Shown THIRD!
        if (thingsPosts.isNotEmpty) ...[
          SizedBox(height: 8.h),
          _buildPopularThingsSection(thingsPosts),
        ],
      ],
    );
  }

  Widget _buildTabEmpty(String label, String message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDarkMode
              ? const SizedBox()
              : Image.asset(
                  Assets.images.noSearchFound.path,
                  height: 0.22.sh,
                  width: 0.22.sh,
                  fit: BoxFit.contain,
                ),
          const SizedBox(height: 10),
          Text(
            '${AppLocalizations.of(context)!.no} $label ${AppLocalizations.of(context)!.found}',
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionHeading.copyWith(
              fontSize: 15.5,
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13,
              color: const Color(0xFF595959),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Accounts tab ───────────────────────────────────────────────────────────

  Widget _buildAccountsList(List<SearchAccount> accounts) {
    if (accounts.isEmpty) {
      return _buildTabEmpty(
        AppLocalizations.of(context)!.accountslower,
        AppLocalizations.of(
          context,
        )!.trysearchingwithadifferentusernameorkeyword,
      );
    }
    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (_, i) => _buildAccountTile(accounts[i]),
    );
  }

  Widget _buildAccountTile(SearchAccount acc) {
    final txt = AppTextColors.of(context);
    final avatar = _avatarProvider(acc.profileImage);
    return GestureDetector(
      onTap: () =>
          navigationPush(context, PublicProfileScreen(userId: acc.uuid)),
      child: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 12.w, vertical: 7),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(0.08),
              backgroundImage: avatar,
              child: avatar == null
                  ? Text(
                      acc.username.isNotEmpty
                          ? acc.username[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 7.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acc.username,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.body,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  acc.fullName.isEmpty ? acc.username : acc.fullName,
                  //   '@${acc.username} · ${_formatCount(acc.followersCount)} chases',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.5,
                    color: txt.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ToggleChaseButton(
              userId: acc.uuid,
              username: acc.username,
              followStatus: acc.followStatus,
              isPrivate: acc.isPrivate,
              apiService: ApiService(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Posts tab ──────────────────────────────────────────────────────────────

  Widget _buildPollsList(List<SearchPost> posts) {
    if (posts.isEmpty) {
      return _buildTabEmpty(
        AppLocalizations.of(context)!.post,
        AppLocalizations.of(
          context,
        )!.exploretrendingconversationsortryanothersearch,
      );
    }
    return ListView.builder(
      itemCount: posts.length,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemBuilder: (_, i) => _buildSearchPostCard(posts[i]),
    );
  }

  Widget _buildSearchPostCard(SearchPost post) {
    final txt = AppTextColors.of(context);

    // Header
    final author = post.author;
    final initial = author.username.isNotEmpty
        ? author.username[0].toUpperCase()
        : 'P';
    final name = '${author.firstName} ${author.lastName}'.trim();
    final displayName = name.isNotEmpty ? name : author.username;

    // Check if it's an image poll
    final poll = post.polls.isNotEmpty ? post.polls.first : null;
    final bool isImage =
        poll != null && poll.options.any((o) => o.image != null);

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
      padding: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    navigationPush(
                      context,
                      PublicProfileScreen(userId: author.id),
                    );
                  },
                  child: CircleAvatar(
                    radius: 19.5,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.1),
                    backgroundImage: _avatarProvider(author.profileImage),
                    child:
                        author.profileImage == null ||
                            author.profileImage!.isEmpty
                        ? Text(
                            initial,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.sectionHeading.copyWith(
                          color: txt.title,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '@${author.username}',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: txt.body,
                            ),
                          ),
                          Text(
                            ' • ${_timeAgo(post.createdAt)}',
                            style: AppTextStyles.subText.copyWith(
                              color: txt.muted,
                              fontWeight: FontWeight.w400,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // IconButton(
                //   icon: const Icon(Icons.more_vert),
                //   onPressed: () {},
                //   color: txt.muted,
                // ),
              ],
            ),
          ),

          Divider(color: Theme.of(context).colorScheme.outlineVariant),

          // Question/Description
          GestureDetector(
            onTap: () {
              navigationPush(
                context,
                SinglePostDetails(username: author.username, postId: post.id),
              );
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
              child: Text(
                post.description.isNotEmpty
                    ? post.description
                    : (poll?.question ?? ''),
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.heading,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Poll Content (Image Stack or Text Options)
          if (poll != null) ...[
            if (isImage)
              _buildSearchImageStack(poll, post)
            else
              _buildSearchTextOptions(poll, post),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchImageStack(SearchPostPoll poll, SearchPost post) {
    final validImages = poll.options.where((o) => o.image != null).toList();
    if (validImages.isEmpty) return const SizedBox.shrink();

    final displayImages = validImages.take(4).toList();
    final n = displayImages.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = 150.h;
          final cardWidth = n == 1 ? w : w * 0.55;
          final spacing = n > 1 ? (w - cardWidth) / (n - 1) : 0.0;

          return GestureDetector(
            onTap: () {
              navigationPush(
                context,
                SinglePostDetails(
                  username: post.author.username,
                  postId: post.id,
                ),
              );
            },
            child: SizedBox(
              height: h,
              width: w,
              child: Stack(
                children: displayImages
                    .asMap()
                    .entries
                    .map<Widget>((entry) {
                      final i = entry.key;
                      final opt = entry.value;
                      final img = opt.image!;

                      final imageUrl = img.url.startsWith('http')
                          ? img.url
                          : '${ApiConfig.baseUrlImage}${img.url}';

                      Widget imageWidget = _buildNetworkImage(
                        imageUrl,
                        errorWidget: Icon(
                          Icons.image_not_supported,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          size: 30,
                        ),
                      );

                      if (i > 0) {
                        imageWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageWidget,
                              BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 2.0,
                                  sigmaY: 2.0,
                                ),
                                child: Container(color: Colors.transparent),
                              ),
                            ],
                          ),
                        );
                      }

                      return Positioned(
                        left: i * spacing,
                        width: cardWidth,
                        height: h,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: imageWidget,
                          ),
                        ),
                      );
                    })
                    .toList()
                    .reversed
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchTextOptions(SearchPostPoll poll, SearchPost post) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: poll.options.map((option) {
        return GestureDetector(
          onTap: () {
            navigationPush(
              context,
              SinglePostDetails(
                username: post.author.username,
                postId: post.id,
              ),
            );
          },
          child: Container(
            // height: 40,
            margin: EdgeInsets.only(bottom: 10.h, left: 10.w, right: 10.w),
            padding: EdgeInsets.fromLTRB(10.w, 7.h, 10.w, 7.h),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF242831) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
            child: Text(
              option.text ?? '',
              style: AppTextStyles.subText.copyWith(
                color: txt.title,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _timeAgo(String createdAt) {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      if (diff.inDays < 7) return '${diff.inDays} d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
      return '${(diff.inDays / 30).floor()} mo ago';
    } catch (_) {
      return '';
    }
  }

  // ── Photos tab ─────────────────────────────────────────────────────────────

  Widget _buildPhotosList(List<SearchPhoto> photos) {
    if (photos.isEmpty) {
      return _buildTabEmpty(
        AppLocalizations.of(context)!.photoslower,
        AppLocalizations.of(context)!.wecouldnotfindanymatchingphotos,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 0.7,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        return _buildPhotoCell(photo, () {
          final String username = photo.username.isNotEmpty
              ? photo.username
              : photo.author.username;
          navigationPush(
            context,
            SinglePostDetails(postId: photo.postId, username: username),
          );
        });
      },
    );
  }

  Widget _buildNetworkImage(
    String imageUrl, {
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    if (imageUrl.trim().isEmpty) {
      return errorWidget ??
          const Icon(Icons.broken_image_rounded, color: _textSecondary);
    }
    return FutureBuilder<String?>(
      future: _authTokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey[100]);
        }
        final token = snapshot.data;
        final headers = token != null && imageUrl.contains('/api/')
            ? {'Authorization': 'Bearer $token'}
            : null;
        return Image.network(
          imageUrl,
          fit: fit,
          headers: headers,
          errorBuilder: (_, __, ___) =>
              errorWidget ??
              const Icon(Icons.broken_image_rounded, color: _textSecondary),
        );
      },
    );
  }

  Widget _buildPhotoCell(SearchPhoto photo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.grey[100]!,
        child: _buildNetworkImage(photo.imageUrl),
      ),
    );
  }

  // ── Hashtags tab ───────────────────────────────────────────────────────────

  Widget _buildHashtagsList(List<SearchHashtag> hashtags) {
    if (hashtags.isEmpty) {
      return _buildTabEmpty(
        AppLocalizations.of(context)!.tag,
        AppLocalizations.of(context)!.trysearchingforanothertopicorkeyword,
      );
    }
    return ListView.builder(
      itemCount: hashtags.length,
      itemBuilder: (_, i) => _buildHashtagTile(hashtags[i]),
    );
  }

  Widget _buildHashtagTile(SearchHashtag tag) {
    final txt = AppTextColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () {
          navigationPush(context, HashtagPostsList(hashtag: tag.tag));
        },
        child: Row(
          children: [
            Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
              ),
              child: Center(
                child: Icon(
                  FeatherIcons.hash,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.8),
                  size: 18.spMax,
                ),
              ),
            ),
            SizedBox(width: 7.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.tag,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.body,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_formatCount(tag.postsCount)} posts',
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Places tab ─────────────────────────────────────────────────────────────

  Widget _buildPlacesList(List<SearchPlace> places) {
    final txt = AppTextColors.of(context);

    if (places.isEmpty) {
      return _buildTabEmpty('places', 'We could not find any matching places');
    }

    return ListView.builder(
      itemCount: places.length,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemBuilder: (_, i) {
        final place = places[i];
        final nameParts = place.name.split(',');
        final String name = nameParts.first.trim();
        final String subtitle = nameParts.length > 1
            ? nameParts.sublist(1).join(',').trim()
            : '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Icon(
                      FeatherIcons.mapPin,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.8),
                      size: 15.spMax,
                    ),
                  ),
                ),
                SizedBox(width: 7.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.body,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTextStyles.bodyText.copyWith(
                          color: txt.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
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
