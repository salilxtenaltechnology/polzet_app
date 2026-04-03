// ignore_for_file: deprecated_member_use, unused_field, strict_top_level_inference

part of 'posts/user_profile_import.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<StatefulWidget> createState() {
    return ProfileState();
  }
}

class ProfileState extends State<UserProfile>
    with UtilityMixin, WidgetsBindingObserver, TickerProviderStateMixin {
  final ApiService apiService = ApiService();
  final _cache = ProfileCache.instance;

  // ── Local mirror of cache ────────────────────────────────────────────────
  List<UserPostModel> _cachedPosts = [];
  List<Map<String, dynamic>> _cachedFollowers = [];
  List<Map<String, dynamic>> _cachedFollowing = [];
  final Map<String, Uint8List?> _decodedImageCache = {};

  String? _cachedCoverImage;
  String? _cachedProfileImage;
  List<UserPostModel> _cachedTextPolls = [];

  Uint8List? _cachedProfileImageBytes;
  Uint8List? _cachedCoverImageBytes;

  // ── Futures for FutureBuilders ───────────────────────────────────────────
  late Future<List<Map<String, dynamic>>> getChase;
  late Future<List<Map<String, dynamic>>> getRechase;
  late Future<List<UserPostModel>> _postsFuture;
  late Future<List<UserPostModel>> _pollPostsFuture;

  bool isInitialLoad = true;
  bool autoRefreshEnabled = true;

  int _totalImagePostsCount = 0;
  int _totalTextPostsCount = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _seedFromCache();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    getChase = _loadChaseWithCache();
    getRechase = _loadRechaseWithCache();
    _postsFuture = _loadPostsWithCache(userProvider.username);
    _pollPostsFuture = _loadPollPostsWithCache(userProvider.username);
    _loadProfileSilently();
    // ✅ No connectivity listener — ConnectivityOverlay handles UI globally
  }

  @override
  void dispose() {
    _clearLocalMirror();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && autoRefreshEnabled) {
      _refreshAllDataSilently();
      _loadProfileSilently();
    }
  }

  // ── Cache helpers ────────────────────────────────────────────────────────

  void _seedFromCache() {
    _cachedPosts = List.of(_cache.imagePosts);
    _cachedTextPolls = List.of(_cache.textPosts);
    _cachedFollowers = List.of(_cache.followers);
    _cachedFollowing = List.of(_cache.following);

    _cachedProfileImage = _cache.profileImageRaw;
    _cachedCoverImage = _cache.coverImageRaw;
    _cachedProfileImageBytes = _cache.profileImageBytes;
    _cachedCoverImageBytes = _cache.coverImageBytes;

    _totalImagePostsCount = _cache.totalImageCount;
    _totalTextPostsCount = _cache.totalTextCount;
  }

  void _applyProfileImages({String? profileRaw, String? coverRaw}) {
    if (!mounted) return;

    bool needsUpdate = false;
    Uint8List? profileBytes = _cachedProfileImageBytes;
    Uint8List? coverBytes = _cachedCoverImageBytes;

    if (profileRaw != null && profileRaw.isNotEmpty && profileRaw != _cachedProfileImage) {
      profileBytes = decodeBase64Image(profileRaw);
      _cache.profileImageRaw = profileRaw;
      _cache.profileImageBytes = profileBytes;
      needsUpdate = true;
    }
    
    if (coverRaw != null && coverRaw.isNotEmpty && coverRaw != _cachedCoverImage) {
      coverBytes = decodeBase64Image(coverRaw);
      _cache.coverImageRaw = coverRaw;
      _cache.coverImageBytes = coverBytes;
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {
        if (profileRaw != null && profileRaw.isNotEmpty) {
          _cachedProfileImage = profileRaw;
          _cachedProfileImageBytes = profileBytes;
        }
        if (coverRaw != null && coverRaw.isNotEmpty) {
          _cachedCoverImage = coverRaw;
          _cachedCoverImageBytes = coverBytes;
        }
      });
    }
  }

  void _clearLocalMirror() {
    _cachedPosts = [];
    _cachedFollowers = [];
    _cachedFollowing = [];
    _cachedCoverImage = null;
    _cachedProfileImage = null;
    _cachedTextPolls = [];
    _cachedProfileImageBytes = null;
    _cachedCoverImageBytes = null;
    _decodedImageCache.clear();
    _totalImagePostsCount = 0;
    _totalTextPostsCount = 0;
  }

  void clearAllCache() {
    _cache.clearAll();
    _clearLocalMirror();
  }

  // ── Data loaders ─────────────────────────────────────────────────────────

  Future<void> _loadProfileSilently() async {
    await Provider.of<UserProvider>(context, listen: false).loadUserImages();
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _applyProfileImages(
      profileRaw: userProvider.profile_picture,
      coverRaw: userProvider.cover_photo,
    );

    try {
      final accessToken = await SharedPrefService.getToken();
      if (accessToken == null) return;

      final response = await Dio().get(
        ApiConstants.userProfile,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data as Map<String, dynamic>;
        _applyProfileImages(
          profileRaw: data['profile_picture_url'] as String?,
          coverRaw: data['cover_photo_url'] as String?,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching user profile: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadChaseWithCache() async {
    final list = Provider.of<UserProvider>(context, listen: false).chase_list;
    _cache.followers = list;
    _cachedFollowers = list;
    return list;
  }

  Future<List<Map<String, dynamic>>> _loadRechaseWithCache() async {
    final list = Provider.of<UserProvider>(context, listen: false).rechase_list;
    _cache.following = list;
    _cachedFollowing = list;
    return list;
  }

  Future<List<UserPostModel>> _loadPostsWithCache(String? username) async {
    if (username == null || username.isEmpty) return _cachedPosts;

    try {
      final posts = await apiService.fetchPostsImages(username);
      final imagePosts = posts.where((p) => p.images.isNotEmpty).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final latestPosts = imagePosts.take(4).toList();

      _cache.imagePosts = latestPosts;
      _cache.totalImageCount = imagePosts.length;

      bool countChanged = _totalImagePostsCount != imagePosts.length;
      _cachedPosts = latestPosts;
      _totalImagePostsCount = imagePosts.length;

      if (mounted && countChanged) {
        setState(() {});
      }
      isInitialLoad = false;
      return latestPosts;
    } catch (e) {
      if (kDebugMode) print('Error loading posts: $e');
      return _cache.hasImagePosts ? _cache.imagePosts : _cachedPosts;
    }
  }

  Future<List<UserPostModel>> _loadPollPostsWithCache(String? username) async {
    if (username == null || username.isEmpty) return _cachedTextPolls;

    try {
      final postsPolls = await apiService.fetchOnlyPollPosts(username);
      final postsWithTextPolls = postsPolls.where((post) {
        if (post.polls.isEmpty) return false;
        return post.polls.every(
          (poll) => poll.options!.every(
            (option) =>
                option.text != null &&
                option.text!.isNotEmpty &&
                option.image == null,
          ),
        );
      }).toList();

      _cache.textPosts = postsWithTextPolls;
      _cache.totalTextCount = postsWithTextPolls.length;

      bool countChanged = _totalTextPostsCount != postsWithTextPolls.length;
      _cachedTextPolls = postsWithTextPolls;
      _totalTextPostsCount = postsWithTextPolls.length;

      if (mounted && countChanged) {
        setState(() {});
      }
      return postsWithTextPolls;
    } catch (e) {
      if (kDebugMode) print('Error loading poll posts: $e');
      return _cache.hasTextPosts ? _cache.textPosts : _cachedTextPolls;
    }
  }

  // ── Silent refresh ────────────────────────────────────────────────────────

  void _refreshAllDataSilently() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    _loadProfileSilently();

    final freshFollowers = userProvider.chase_list;
    final freshFollowing = userProvider.rechase_list;

    _cache.followers = freshFollowers;
    _cache.following = freshFollowing;

    if (mounted) {
      setState(() {
        _cachedFollowers = freshFollowers;
        getChase = Future.value(freshFollowers);
        _cachedFollowing = freshFollowing;
        getRechase = Future.value(freshFollowing);
      });
    }

    if (mounted &&
        userProvider.username != null &&
        userProvider.username!.isNotEmpty) {
      _loadPostsWithCache(userProvider.username)
          .then((posts) {
            if (mounted) setState(() { _postsFuture = Future.value(posts); });
          })
          .catchError((e) {
            if (kDebugMode) print('Silent refresh posts error: $e');
          });

      _loadPollPostsWithCache(userProvider.username).then((data) {
        if (mounted) setState(() { _pollPostsFuture = Future.value(data); });
      });
    }
  }

  // ── Pull-to-refresh ───────────────────────────────────────────────────────

  Future<void> _handleRefresh() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await Future.wait([
      _loadProfileSilently(),
      _loadChaseWithCache().then((data) {
        if (mounted) setState(() { getChase = Future.value(data); });
      }),
      _loadRechaseWithCache().then((data) {
        if (mounted) setState(() { getRechase = Future.value(data); });
      }),
      if (userProvider.username != null && userProvider.username!.isNotEmpty)
        _loadPostsWithCache(userProvider.username).then((data) {
          if (mounted) setState(() { _postsFuture = Future.value(data); });
        }),
      _loadPollPostsWithCache(userProvider.username).then((data) {
        if (mounted) setState(() { _pollPostsFuture = Future.value(data); });
      }),
    ]);
  }

  // ── Image decoding ────────────────────────────────────────────────────────

  Uint8List? decodeBase64Image(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final base64Data = value.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }

  Uint8List? getCachedProfileImage(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    if (_decodedImageCache.containsKey(base64Str)) {
      return _decodedImageCache[base64Str];
    }
    final bytes = decodeBase64Image(base64Str);
    _decodedImageCache[base64Str] = bytes;
    return bytes;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            children: [
              // ── Cover Image ────────────────────────────────────────────
              Container(
                height: 180.h,
                width: double.infinity,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  image: _cachedCoverImageBytes == null
                      ? const DecorationImage(
                          image: AssetImage(Assets.assetsImagesDefaultCover),
                          fit: BoxFit.fill,
                        )
                      : DecorationImage(
                          image: MemoryImage(_cachedCoverImageBytes!),
                          fit: BoxFit.fill,
                        ),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () {
                          navigationPush(context, const EditProfile());
                          _loadProfileSilently();
                        },
                        child: Container(
                          margin: EdgeInsets.only(top: 17.h, right: 5.w),
                          height: 24.5.h,
                          width: 24.5.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: Center(
                            child: Icon(
                              FeatherIcons.edit2,
                              color: Colors.white,
                              size: 13.spMax,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        height: 60.h,
                        padding: EdgeInsets.all(8.w),
                        child: Row(
                          children: [
                            Container(
                              height: 50.h,
                              width: 50.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5.w,
                                ),
                                image: _cachedProfileImageBytes == null
                                    ? const DecorationImage(
                                        image: AssetImage(
                                          Assets.assetsImagesIcUser,
                                        ),
                                        fit: BoxFit.fill,
                                      )
                                    : DecorationImage(
                                        image: MemoryImage(
                                          _cachedProfileImageBytes!,
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProvider.isLoading
                                      ? '-'
                                      : userProvider.username ?? '-',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  userProvider.isLoading
                                      ? '-'
                                      : userProvider.bio ?? '-',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).asGlass(
                        tintColor: Colors.black,
                        clipBorderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Stats + Chase/Re-chase ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildStatContainer(
                          icon: FeatherIcons.arrowUp,
                          value: userProvider.isLoading
                              ? '-'
                              : (userProvider.counts?['chasing']?.toString() ??
                                    '-'),
                          onTap: () => navigationPush(
                            context,
                            UserChase(
                              username: userProvider.username ?? '-',
                              followingCount:
                                  (userProvider.counts?['rechasing']
                                      ?.toString() ??
                                  '0'),
                              followerCount:
                                  (userProvider.counts?['chasing']
                                      ?.toString() ??
                                  '0'),
                              initialIndex: 0,
                            ),
                          ),
                          topMargin: 10.h,
                        ),
                        _buildStatContainer(
                          icon: FeatherIcons.arrowDown,
                          value: userProvider.isLoading
                              ? '-'
                              : (userProvider.counts?['rechasing']
                                        ?.toString() ??
                                    '-'),
                          onTap: () => navigationPush(
                            context,
                            UserChase(
                              username: userProvider.username ?? '-',
                              followingCount:
                                  (userProvider.counts?['rechasing']
                                      ?.toString() ??
                                  '0'),
                              followerCount:
                                  (userProvider.counts?['chasing']
                                      ?.toString() ??
                                  '0'),
                              initialIndex: 1,
                            ),
                          ),
                          topMargin: 5.h,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10.h),
                        _buildSectionHeader(
                          label: AppLocalizations.of(context)!.vibe,
                          showSeeAll: _cachedFollowers.isNotEmpty,
                          onSeeAll: () {
                            navigationPush(
                              context,
                              UserChase(
                                username: userProvider.username ?? '-',
                                followingCount:
                                    userProvider.following_count ?? '0',
                                followerCount:
                                    userProvider.followers_count ?? '0',
                                initialIndex: 0,
                              ),
                            );
                            if (mounted) {
                              setState(() {
                                getChase = _loadChaseWithCache();
                                getRechase = _loadRechaseWithCache();
                              });
                            }
                          },
                        ),
                        SizedBox(height: 5.h),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: getChase,
                          initialData: _cachedFollowers,
                          builder: (context, snapshot) {
                            final users = snapshot.hasData ? snapshot.data! : _cachedFollowers;
                            if (isInitialLoad &&
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _cachedFollowers.isEmpty) {
                              return const UserChaseSimmer();
                            }
                            if (users.isEmpty) {
                              return _buildEmptyChaseText(
                                AppLocalizations.of(context)!.nochaseyet,
                              );
                            }
                            return _buildUserAvatarRow(users);
                          },
                        ),
                        SizedBox(height: 8.h),
                        _buildSectionHeader(
                          label: AppLocalizations.of(context)!.revibe,
                          showSeeAll: _cachedFollowing.isNotEmpty,
                          onSeeAll: () => navigationPush(
                            context,
                            UserChase(
                              username: userProvider.username ?? '-',
                              followingCount:
                                  userProvider.following_count ?? '0',
                              followerCount:
                                  userProvider.followers_count ?? '0',
                              initialIndex: 1,
                            ),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: getRechase,
                          initialData: _cachedFollowing,
                          builder: (context, snapshot) {
                            final users = snapshot.hasData ? snapshot.data! : _cachedFollowing;
                            if (isInitialLoad &&
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _cachedFollowing.isEmpty) {
                              return const UserChaseSimmer();
                            }
                            if (users.isEmpty) {
                              return _buildEmptyChaseText(
                                AppLocalizations.of(context)!.norechaseyet,
                              );
                            }
                            return _buildUserAvatarRow(users);
                          },
                        ),
                        SizedBox(height: 5.h),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Polls / Things count bar ──────────────────────────────
              Container(
                width: double.infinity,
                height: 38.h,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 5.h),
                margin: EdgeInsets.only(
                  left: 12.w,
                  right: 12.w,
                  top: 10.h,
                  bottom: 10.h,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    pollThingsTile(
                      Assets.assetsImagesPoll,
                      _totalImagePostsCount.toString(),
                      Icons.image,
                      () => navigationPush(
                        context,
                        ImagePostsList(
                          username: userProvider.username!,
                          profileImage: userProvider.profile_picture,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 30.h,
                      child: const VerticalDivider(
                        color: Color(0xA7FFFFFF),
                        thickness: 0.63,
                        width: 1,
                      ),
                    ),
                    pollThingsTile(
                      Assets.assetsImagesThings,
                      _totalTextPostsCount.toString(),
                      Icons.image,
                      () => navigationPush(
                        context,
                        ThingsPostsList(
                          username: userProvider.username!,
                          profileImage: userProvider.profile_picture,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Image posts section ────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.poll,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_cachedPosts.isNotEmpty)
                      GestureDetector(
                        onTap: () => navigationPush(
                          context,
                          ImagePostsList(
                            username: userProvider.username!,
                            profileImage: _cachedProfileImage,
                          ),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context)!.seeall} >',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5.sp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: FutureBuilder<List<UserPostModel>>(
                  future: _postsFuture,
                  initialData: _cachedPosts,
                  builder: (context, snapshot) {
                    final posts = snapshot.hasData ? snapshot.data! : _cachedPosts;

                    if (isInitialLoad &&
                        snapshot.connectionState == ConnectionState.waiting &&
                        _cachedPosts.isEmpty) {
                      return _buildPostsShimmer();
                    }

                    if (posts.isEmpty) return _buildEmptyPostsPlaceholder();

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.3,
                          ),
                      itemCount: posts.length > 4 ? 4 : posts.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => navigationPush(
                            context,
                            ImagePostsList(
                              username: userProvider.username!,
                              profileImage: userProvider.profile_picture,
                            ),
                          ),
                          child: _buildImagesStack(posts[index].polls),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Text-poll (Things) section ────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0.h),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.things,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_cachedTextPolls.isNotEmpty)
                      GestureDetector(
                        onTap: () => navigationPush(
                          context,
                          ThingsPostsList(
                            username: userProvider.username!,
                            profileImage: _cachedProfileImage,
                          ),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context)!.seeall} >',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5.sp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              FutureBuilder<List<UserPostModel>>(
                future: _pollPostsFuture,
                initialData: _cachedTextPolls,
                builder: (context, snapshot) {
                  final postsWithTextPolls = snapshot.hasData ? snapshot.data! : _cachedTextPolls;

                  if (isInitialLoad &&
                      snapshot.connectionState == ConnectionState.waiting &&
                      _cachedTextPolls.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.h),
                        child: const CircularProgressIndicator(
                          color: AppColors.primaryColor,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (postsWithTextPolls.isEmpty) {
                    return _buildEmptyThingsPlaceholder();
                  }

                  const List<List<Color>> gradientOptions = [
                    [Color(0xFFFC3E7E), Color(0xFF935994)],
                    [Color(0xFF4FC3F7), Color(0xFF7C9CAC)],
                    [Colors.red, Color(0xFF9F6C7B)],
                  ];

                  return ListView.builder(
                    padding: EdgeInsets.all(12.w),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: postsWithTextPolls.length > 3
                        ? 3
                        : postsWithTextPolls.length,
                    itemBuilder: (context, index) {
                      final post = postsWithTextPolls[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < postsWithTextPolls.length - 1
                              ? 12.h
                              : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => navigationPush(
                            context,
                            ThingsPostsList(
                              username: userProvider.username!,
                              profileImage: userProvider.profile_picture,
                            ),
                          ),
                          child: UserThingsCard(
                            post: post.polls.first,
                            gradientColors:
                                gradientOptions[index % gradientOptions.length],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small widget builders ─────────────────────────────────────────────────

  Widget _buildStatContainer({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    required double topMargin,
  }) {
    return Container(
      width: 80.w,
      height: 80.h,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 8.h),
      margin: EdgeInsets.fromLTRB(10.w, topMargin, 10.w, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [statTile(icon, value, onTap)],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required bool showSeeAll,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (showSeeAll)
          GestureDetector(
            onTap: onSeeAll,
            child: Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: Text(
                '${AppLocalizations.of(context)!.seeall} >',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5.sp,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyChaseText(String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 15.h, bottom: 25.h),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10.8.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatarRow(List<Map<String, dynamic>> users) {
    final recentUsers = users.length > 4 ? users.take(4).toList() : users;
    return Container(
      height: 55.h,
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Row(
        mainAxisAlignment: users.length < 4
            ? MainAxisAlignment.start
            : MainAxisAlignment.spaceBetween,
        children: recentUsers.map((user) {
          final profilePic = user['avatar_url'] as String?;
          final firstName = user['username'] as String;
          final firstLetter = firstName.isNotEmpty
              ? firstName[0].toUpperCase()
              : '?';
          final imageBytes = getCachedProfileImage(profilePic);

          return GestureDetector(
            onTap: () =>
                navigationPush(context, PublicProfile(userId: user['user_id'])),
            child: Container(
              height: 55.h,
              width: 55.w,
              margin: EdgeInsets.only(right: 5.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
                ),
                image: imageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(imageBytes),
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
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Container(
            height: 110.h,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 5.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          Container(
            height: 110.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPostsPlaceholder() {
    return Center(
      child: CustomPaint(
        painter: DottedBorderPainter(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          strokeWidth: 1.5,
          gap: 5,
        ),
        child: GestureDetector(
          onTap: () => navigationPush(context, const PollImages()),
          child: SizedBox(
            height: 100.h,
            width: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.createsomethingcool,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.6),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _buildGradientButton(
                    AppLocalizations.of(context)!.createyourfirstpoll,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyThingsPlaceholder() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: CustomPaint(
        painter: DottedBorderPainter(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          strokeWidth: 1.5,
        ),
        child: SizedBox(
          height: 100.h,
          width: double.infinity,
          child: Center(
            child: GestureDetector(
              onTap: () => navigationPush(context, const PollQuestion()),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.createsomethingcool,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.6),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _buildGradientButton(
                    AppLocalizations.of(context)!.createyourfirstthings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton(String label) {
    return Container(
      height: 27.h,
      width: 200.w,
      margin: EdgeInsets.only(top: 8.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB91C1C), Color(0xFFDB2777)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Reusable tile widgets ─────────────────────────────────────────────────

  Widget statTile(IconData icon, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  Assets.assetsImagesCurrentUser,
                  height: 18.5.h,
                  width: 18.5.w,
                ),
                SizedBox(height: 2.h),
                Icon(
                  icon,
                  size: 20.spMax,
                  color: Colors.white.withOpacity(0.8),
                ),
                SizedBox(height: 2.h),
                Image.asset(
                  Assets.assetsImagesAddUsers,
                  height: 18.5.h,
                  width: 18.5.w,
                ),
              ],
            ),
            SizedBox(width: 7.h),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget pollThingsTile(
    String icon,
    String value,
    IconData pollImage,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        width: 130.w,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 5.w),
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Image.asset(icon, height: 19.h, width: 19.w),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesStack(List<UserPollQuestion> polls) {
    final validImages = <PollOptionImage>[];
    for (final poll in polls) {
      if (poll.options != null) {
        for (final option in poll.options!) {
          if (option.image != null) validImages.add(option.image!);
        }
      }
    }

    if (validImages.isEmpty) return const SizedBox.shrink();

    List<Alignment> getAlignments(int total) {
      switch (total) {
        case 1:
          return [Alignment.center];
        case 2:
          return [Alignment.centerLeft, Alignment.centerRight];
        case 3:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
          ];
        default:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.centerRight,
          ];
      }
    }

    final alignments = getAlignments(validImages.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final imageHeight = 150.h;

        return SizedBox(
          height: imageHeight,
          width: availableWidth,
          child: Stack(
            children: validImages
                .asMap()
                .entries
                .map<Widget>((entry) {
                  final index = entry.key;
                  final imageData = entry.value;
                  final alignment = alignments[index];
                  final imageWidth =
                      ((availableWidth * 0.7) - (index * 8.0))
                          .clamp(60.w, double.infinity);

                  return Align(
                    alignment: alignment,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      width: imageWidth,
                      height: imageHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19.r),
                        child: Image.network(
                          '${ApiConfig.baseUrlImage}${imageData.url}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              color: Colors.grey[200],
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[600],
                              size: 30,
                            ),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                                color: Colors.grey[200],
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                })
                .toList()
                .reversed
                .toList(),
          ),
        );
      },
    );
  }
}