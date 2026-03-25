// screens/global_search_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile.dart';
import 'api/services/api_service.dart';
import 'core/constants/app_colors.dart';
import 'mixin/utility_mixins.dart';
import 'models/global search/global_search_model.dart';
import 'widgets/custom_text_styles.dart';
import 'widgets/tabbar/indicatore_animation.dart';

// ─── Palette ────────────────────────────────────────────────────────────────

const _accent = AppColors.primaryColor;
const _accentSoft = Color(0x336C63FF);
const _textPrimary = Color(0xFFEEEEEE);
const _textSecondary = Color(0xFF888888);

// ─── Entry point ─────────────────────────────────────────────────────────────
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  GlobalSearchModel? _result;
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  static const _tabs = ['Top', 'Accounts', 'Posts', 'Photos', 'Tags', 'Places'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _doSearch(''));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── search logic ──────────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(''));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _doSearch(query.trim()),
    );
  }

  Future<void> _doSearch(String query) async {
    setState(() => _loading = true);
    try {
      final result = await ApiService().globalSearch(query);
      setState(() {
        _result = result;
        _hasSearched = true;
      });
    } catch (_) {
      setState(() => _hasSearched = true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────
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

  Uint8List? getProfileImage(profilePicture) {
    if (profilePicture == null || profilePicture.isEmpty) return null;
    try {
      String base64Data = profilePicture.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_hasSearched || _result != null) _buildTabBar(),
            Expanded(child: _buildBody()),
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
                autofocus: true,
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

  // ── Body dispatcher ────────────────────────────────────────────────────────
  Widget _buildBody() {
    // 1. Nothing typed yet — show idle prompt
    if (!_hasSearched && _searchController.text.isEmpty) {
      return _buildIdleState();
    }

    // 2. Still fetching — shimmer
    if (_loading) return _buildShimmer();

    // 3. API returned null — show tab-wise error states
    if (_result == null && _hasSearched) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildNotFound(),
          _buildNotFound(),
          _buildNotFound(),
          _buildNotFound(),
          _buildNotFound(),
          _buildNotFound(),
        ],
      );
    }

    // 4. Has data — each tab shows only its own data
    final data = _result!.data;
    return TabBarView(
      controller: _tabController,

      children: [
        _buildTopTab(data.accounts, _loading), // Top: shows accounts list only
        _buildAccountsList(data.accounts), // Accounts tab
        _buildPostsList(data.posts), // Posts tab
        _buildPhotosList(data.photos), // Photos tab
        _buildHashtagsList(data.hashtags), // Hashtags tab
        _buildPlacesList(context), // Place tab
      ],
    );
  }

  // ── Idle (nothing typed yet) ───────────────────────────────────────────────
  Widget _buildIdleState() {
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
          const Text(
            'Search anything',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
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

  // ── Top tab: "No suggestions" placeholder ─────────────────────────────────
  Widget _buildTopNoSuggestions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No suggestions available right now.',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    final query = _searchController.text.trim();
    return Center(
      child: query.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(query.isNotEmpty ? 'Not found "$query"' : 'Not found'),
                const Text('Try searching for accounts, posts, or hashtags'),
              ],
            )
          : Text(
              'No suggestions available right now.',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
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

  // ── Shimmer loading ────────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      itemCount: 10,
      itemBuilder: (_, __) => _ShimmerTile(),
    );
  }

  // ── TOP tab ────────────────────────────────────────────────────────────────
  // Shows accounts list when there's a query result, otherwise no-suggestions.
  Widget _buildTopTab(List<SearchAccount> accounts, [bool isLoading = false]) {
    final query = _searchController.text.trim();

    // ① Searching... state — shown whenever a query is active and loading
    if (isLoading && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, color: _accent, size: 32),
            ),
            const SizedBox(height: 14),
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

    // ② No query typed — default idle text
    if (query.isEmpty) {
      return _buildTopNoSuggestions();
    }

    // ③ Query typed but no results
    if (accounts.isEmpty) {
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
              'Try searching for accounts, posts, or hashtags',
              style: TextStyle(fontSize: 11.sp, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ④ Has results — show accounts list
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: accounts.length,
      itemBuilder: (_, i) => _buildAccountTile(accounts[i]),
    );
  }

  // Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) {
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Text(
  //           title,
  //           style: const TextStyle(
  //             color: _textPrimary,
  //             fontSize: 15,
  //             fontWeight: FontWeight.w700,
  //           ),
  //         ),
  //         if (onSeeAll != null)
  //           GestureDetector(
  //             onTap: onSeeAll,
  //             child: const Text(
  //               'See all',
  //               style: TextStyle(color: _accent, fontSize: 13),
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  /*────── Accounts tab ──────*/
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
      onTap: () {
        navigationPush(context, PublicProfile(userId: acc.id));
      },
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
        minVerticalPadding: 0,
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.08),
          backgroundImage: avatar,
          child: avatar == null
              ? Text(
                  acc.fullName.isNotEmpty ? acc.fullName[0].toUpperCase() : '?',
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
                acc.fullName,
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
        trailing: _FollowButton(isFollowing: acc.isFollowing),
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
    return Container(
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
              child: post.thumbnail != null && post.thumbnail!.trim().isNotEmpty
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
                          ? Icons.poll_rounded
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
      itemBuilder: (_, i) => _buildPhotoCell(photos[i]),
    );
  }

  Widget _buildPhotoCell(SearchPhoto photo) {
    return Container(
      color: Colors.grey[100]!,
      child: ((photo.imageUrl.trim().isNotEmpty))
          ? Image.network(
              photo.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_rounded, color: _textSecondary),
            )
          : const Icon(Icons.broken_image_rounded, color: _textSecondary),
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

// ─── Follow Button ─────────────────────────────────────────────────────────────
class _FollowButton extends StatefulWidget {
  final bool isFollowing;
  const _FollowButton({required this.isFollowing});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _following = !_following),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _following ? Colors.transparent : _accent,
          border: Border.all(color: _accent, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _following ? 'Chased' : 'Chase',
          style: TextStyle(
            color: _following ? _accent : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Post Type Badge ───────────────────────────────────────────────────────────
class _PostTypeBadge extends StatelessWidget {
  final String type;
  const _PostTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEBEE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          color: _accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
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
          Colors.grey[300]!,
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
