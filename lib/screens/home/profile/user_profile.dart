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

  // Cached data
  List<UserPostModel> _cachedPosts = [];
  List<Map<String, dynamic>> _cachedFollowers = [];
  List<Map<String, dynamic>> _cachedFollowing = [];
  String? _cachedCoverImage;
  String? _cachedProfileImage;

  // Futures for UI
  late Future<List<Map<String, dynamic>>> getFollowers;
  late Future<List<Map<String, dynamic>>> getFollowing;
  late Future<List<UserPostModel>> _postsFuture;

  bool isInitialLoad = true;
  bool autoRefreshEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Initialize with cached data or empty futures
    getFollowers = _loadFollowersWithCache();
    getFollowing = _loadFollowingWithCache();
    _postsFuture = _loadPostsWithCache(userProvider.username);

    // Load profile data silently
    _loadProfileSilently();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && autoRefreshEnabled) {
      _refreshAllDataSilently();
    }
  }

  // PROFILE IMAGE & COVER - Load silently with cache
  Future<void> _loadProfileSilently() async {
    try {
      final accessToken = await SharedPrefService.getAccessToken();
      if (accessToken == null) return;

      var dio = Dio();
      var response = await dio.get(
        ApiConstants.userProfile,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        Map<String, dynamic> data = response.data;
        setState(() {
          _cachedCoverImage = data['cover_photo_url'] ?? '';
          _cachedProfileImage = data['profile_picture_url'] ?? '';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user profile: $e');
      }
    }
  }

  // FOLLOWERS - Load with cache
  Future<List<Map<String, dynamic>>> _loadFollowersWithCache() async {
    try {
      final followers = await apiService.getFollowersList();
      if (mounted) {
        setState(() {
          _cachedFollowers = followers;
        });
      }
      return followers;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading followers: $e');
      }
      // Return cached data on error
      return _cachedFollowers;
    }
  }

  // FOLLOWING - Load with cache
  Future<List<Map<String, dynamic>>> _loadFollowingWithCache() async {
    try {
      final following = await apiService.getFollowingList();
      if (mounted) {
        setState(() {
          _cachedFollowing = following;
        });
      }
      return following;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading following: $e');
      }
      // Return cached data on error
      return _cachedFollowing;
    }
  }

  // POSTS - Load with cache
  Future<List<UserPostModel>> _loadPostsWithCache(String? username) async {
    if (username == null || username.isEmpty) {
      return _cachedPosts;
    }

    try {
      final posts = await apiService.fetchPostsImages(username);
      final imagePosts = posts.where((p) => p.images.isNotEmpty).toList();
      imagePosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final latestPosts = imagePosts.take(4).toList();

      if (mounted) {
        setState(() {
          _cachedPosts = latestPosts;
          isInitialLoad = false;
        });
      }

      return latestPosts;
    } catch (e) {
      if (kDebugMode) {
        print("Error loading posts: $e");
      }
      // Return cached data on error
      return _cachedPosts;
    }
  }

  // SILENT REFRESH - Updates data in background without showing loading
  void _refreshAllDataSilently() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Refresh profile
    _loadProfileSilently();

    // Refresh followers/following silently
    if (mounted) {
      apiService
          .getFollowersList()
          .then((followers) {
            if (mounted) {
              setState(() {
                _cachedFollowers = followers;
                getFollowers = Future.value(followers);
              });
            }
          })
          .catchError((e) {
            if (kDebugMode) print('Silent refresh followers error: $e');
          });

      apiService
          .getFollowingList()
          .then((following) {
            if (mounted) {
              setState(() {
                _cachedFollowing = following;
                getFollowing = Future.value(following);
              });
            }
          })
          .catchError((e) {
            if (kDebugMode) print('Silent refresh following error: $e');
          });

      // Refresh posts silently
      if (userProvider.username != null && userProvider.username!.isNotEmpty) {
        _loadPostsWithCache(userProvider.username)
            .then((posts) {
              if (mounted) {
                setState(() {
                  _postsFuture = Future.value(posts);
                });
              }
            })
            .catchError((e) {
              if (kDebugMode) print('Silent refresh posts error: $e');
            });
      }
    }
  }

  // PULL TO REFRESH - Shows brief loading indicator
  Future<void> _handleRefresh() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await Future.wait([
      _loadProfileSilently(),
      _loadFollowersWithCache().then((data) {
        if (mounted) {
          setState(() {
            getFollowers = Future.value(data);
          });
        }
      }),
      _loadFollowingWithCache().then((data) {
        if (mounted) {
          setState(() {
            getFollowing = Future.value(data);
          });
        }
      }),
      if (userProvider.username != null && userProvider.username!.isNotEmpty)
        _loadPostsWithCache(userProvider.username).then((data) {
          if (mounted) {
            setState(() {
              _postsFuture = Future.value(data);
            });
          }
        }),
    ]);
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

  Uint8List? getCoverImage(coverPhoto) {
    if (coverPhoto == null || coverPhoto.isEmpty) return null;
    try {
      String base64Data = coverPhoto.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }

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
              // Cover Image Section
              Container(
                height: 180.h,
                width: double.infinity,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  image: getCoverImage(_cachedCoverImage) == null
                      ? const DecorationImage(
                          image: AssetImage(Assets.assetsImagesDefaultCover),
                          fit: BoxFit.fill,
                        )
                      : DecorationImage(
                          image: MemoryImage(getCoverImage(_cachedCoverImage)!),
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
                              FeatherIcons.settings,
                              color: Colors.white,
                              size: 16.spMax,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child:
                          Container(
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
                                    image:
                                        getProfileImage(_cachedProfileImage) ==
                                            null
                                        ? const DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                            fit: BoxFit.fill,
                                          )
                                        : DecorationImage(
                                            image: MemoryImage(
                                              getProfileImage(
                                                _cachedProfileImage,
                                              )!,
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

              // Stats and Chase/Re-chase Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Column
                  SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: 80.w,
                          height: 80.h,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          margin: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              statTile(
                                FeatherIcons.arrowUp,
                                userProvider.isLoading
                                    ? '-'
                                    : (userProvider.following_count ?? '-'),
                                () {
                                  navigationPush(
                                    context,
                                    UserChase(
                                      username: userProvider.username ?? '-',
                                      followingCount:
                                          userProvider.following_count ?? '0',
                                      followerCount:
                                          userProvider.followers_count ?? '0',
                                      initialIndex: 1,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 80.w,
                          height: 80.h,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7.h),
                          margin: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              statTile(
                                FeatherIcons.arrowDown,
                                userProvider.isLoading
                                    ? '-'
                                    : (userProvider.followers_count ?? '-'),
                                () {
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
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chase/Re-chase Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.revibe,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                navigationPush(
                                  context,
                                  UserChase(
                                    username: userProvider.username ?? '-',
                                    followingCount:
                                        userProvider.following_count ?? '0',
                                    followerCount:
                                        userProvider.followers_count ?? '0',
                                    initialIndex: 1,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.only(right: 10.w),
                                child: Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.seeall,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryColor
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14.spMax,
                                      color: AppColors.primaryColor.withOpacity(
                                        0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5.h),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: getFollowing,
                          builder: (context, snapshot) {
                            // Show cached data immediately while loading
                            final usersVibe = snapshot.data ?? _cachedFollowing;

                            if (isInitialLoad &&
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _cachedFollowing.isEmpty) {
                              return const UserChaseSimmer();
                            }

                            if (usersVibe.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: 15.h,
                                    bottom: 30.h,
                                  ),
                                  child: const Text(
                                    'No re-chase yet 👀',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final recentUsers = usersVibe.length > 4
                                ? usersVibe.take(4).toList()
                                : usersVibe;

                            return Container(
                              height: 55.h,
                              padding: EdgeInsets.symmetric(horizontal: 5.w),
                              child: Row(
                                mainAxisAlignment: usersVibe.length < 4
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.spaceBetween,
                                children: recentUsers.map((user) {
                                  final profilePic =
                                      user['profile_picture_url'] as String?;
                                  final firstName =
                                      user['first_name'] as String? ??
                                      user['name'] as String? ??
                                      '';
                                  final firstLetter = firstName.isNotEmpty
                                      ? firstName[0].toUpperCase()
                                      : '?';

                                  return GestureDetector(
                                    onTap: () {
                                      navigationPush(
                                        context,
                                        PublicProfile(userId: user['id']),
                                      );
                                    },
                                    child: Container(
                                      height: 55.h,
                                      width: 55.w,
                                      margin: EdgeInsets.only(right: 5.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.7),
                                        ),
                                        image: profilePic != null
                                            ? DecorationImage(
                                                image: MemoryImage(
                                                  getProfileImage(profilePic)!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        color: profilePic == null
                                            ? Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.08)
                                            : null,
                                      ),
                                      child: profilePic == null
                                          ? Center(
                                              child: Text(
                                                firstLetter,
                                                style: TextStyle(
                                                  fontSize: 20.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.vibe,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
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
                              },
                              child: Padding(
                                padding: EdgeInsets.only(right: 10.w),
                                child: Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.seeall,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryColor
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14.spMax,
                                      color: AppColors.primaryColor.withOpacity(
                                        0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5.h),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: getFollowers,
                          builder: (context, snapshot) {
                            // Show cached data immediately while loading
                            final usersVibe = snapshot.data ?? _cachedFollowers;

                            if (isInitialLoad &&
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _cachedFollowers.isEmpty) {
                              return const UserChaseSimmer();
                            }

                            if (usersVibe.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10.h),
                                  child: const Text(
                                    'No chase yet 👀',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final recentUsers = usersVibe.length > 4
                                ? usersVibe.take(4).toList()
                                : usersVibe;

                            return Container(
                              height: 55.h,
                              padding: EdgeInsets.symmetric(horizontal: 5.w),
                              child: Row(
                                mainAxisAlignment: usersVibe.length < 4
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.spaceBetween,
                                children: recentUsers.map((user) {
                                  final profilePic =
                                      user['profile_picture_url'] as String?;
                                  final firstName =
                                      user['first_name'] as String? ??
                                      user['name'] as String? ??
                                      '';
                                  final firstLetter = firstName.isNotEmpty
                                      ? firstName[0].toUpperCase()
                                      : '?';

                                  return GestureDetector(
                                    onTap: () {
                                      navigationPush(
                                        context,
                                        PublicProfile(userId: user['id']),
                                      );
                                    },
                                    child: Container(
                                      height: 55.h,
                                      width: 55.w,
                                      margin: EdgeInsets.only(right: 5.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.7),
                                        ),
                                        image: profilePic != null
                                            ? DecorationImage(
                                                image: MemoryImage(
                                                  getProfileImage(profilePic)!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        color: profilePic == null
                                            ? Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.08)
                                            : null,
                                      ),
                                      child: profilePic == null
                                          ? Center(
                                              child: Text(
                                                firstLetter,
                                                style: TextStyle(
                                                  fontSize: 22.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 5.h),
                      ],
                    ),
                  ),
                ],
              ),

              // Polls/Things Section
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
                      (userProvider.image_post_count ?? 0).toString(),
                      Icons.image,
                      () {
                        navigationPush(
                          context,
                          ImagePostsList(
                            username: userProvider.username!,
                            profileImage: userProvider.profile_picture,
                          ),
                        );
                      },
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
                      (userProvider.text_post_count ?? 0).toString(),
                      Icons.image,
                      () {
                        navigationPush(
                          context,
                          QuestionsPostsList(
                            username: userProvider.username!,
                            profileImage: userProvider.profile_picture,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Posts Section Header
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.poll,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        navigationPush(
                          context,
                          ImagePostsList(
                            username: userProvider.username!,
                            profileImage: _cachedProfileImage,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.seeall,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor.withOpacity(0.8),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14.spMax,
                            color: AppColors.primaryColor.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Posts Grid
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: FutureBuilder<List<UserPostModel>>(
                  future: _postsFuture,
                  builder: (context, snapshot) {
                    // Show cached data immediately while loading
                    final posts = snapshot.data ?? _cachedPosts;

                    if (isInitialLoad &&
                        snapshot.connectionState == ConnectionState.waiting &&
                        _cachedPosts.isEmpty) {
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            Container(
                              height: 110.h,
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 5.h),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (posts.isEmpty) {
                      return Center(
                        child: CustomPaint(
                          painter: DottedBorderPainter(
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 2,
                            gap: 5,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              navigationPush(context, const PollImages());
                            },
                            child: SizedBox(
                              height: 100.h,
                              width: double.infinity,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Create Something Cool'),
                                    Container(
                                      height: 27.h,
                                      width: 200.w,
                                      margin: EdgeInsets.only(top: 8.h),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFB91C1C),
                                            Color(0xFFDB2777),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Create your first poll',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

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
                        final post = posts[index];
                        return GestureDetector(
                          onTap: () {
                            navigationPush(
                              context,
                              ImagePostsList(
                                username: userProvider.username!,
                                profileImage: userProvider.profile_picture,
                              ),
                            );
                          },
                          child: _buildImagesStack(post.polls),
                        );
                      },
                    );
                  },
                ),
              ),

              // Things Section Header
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0.h),
                child: Row(
                  children: [
                    Text(
                      'Things',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        navigationPush(
                          context,
                          QuestionsPostsList(
                            username: userProvider.username!,
                            profileImage: _cachedProfileImage,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.seeall,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor.withOpacity(0.8),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14.spMax,
                            color: AppColors.primaryColor.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Things Polls Section
              FutureBuilder<List<UserPostModel>>(
                future: apiService.fetchOnlyPollPosts(userProvider.username!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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

                  final postsPolls = snapshot.data ?? const <UserPostModel>[];

                  // Filter posts: only show polls where ALL options have text (image == null)
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

                  if (postsWithTextPolls.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      child: CustomPaint(
                        painter: DottedBorderPainter(
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                          gap: 5,
                        ),
                        child: SizedBox(
                          height: 100.h,
                          width: double.infinity,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                navigationPush(context, const PollQuestion());
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Create Something Cool'),
                                  Container(
                                    height: 27.h,
                                    width: 200.w,
                                    margin: EdgeInsets.only(top: 8.h),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFB91C1C),
                                          Color(0xFFDB2777),
                                        ],
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
                                        'Create your first poll',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(12.w),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: postsWithTextPolls.length > 3
                        ? 3
                        : postsWithTextPolls.length,
                    itemBuilder: (context, index) {
                      const List<List<Color>> gradientOptions = [
                        [Color(0xFFFC3E7E), Color.fromARGB(255, 147, 89, 148)],
                        [Color(0xFF4FC3F7), Color.fromARGB(255, 124, 156, 172)],
                        [Colors.red, Color.fromARGB(255, 159, 108, 123)],
                      ];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < postsWithTextPolls.length - 1
                              ? 12.h
                              : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            navigationPush(
                              context,
                              QuestionsPostsList(
                                username: userProvider.username!,
                                profileImage: userProvider.profile_picture,
                              ),
                            );
                          },
                          child: UserThingsCard(
                            post: postsWithTextPolls[index],
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
    // Extract images from poll options
    List<PollOptionImage> validImages = [];

    for (var poll in polls) {
      if (poll.options != null) {
        for (var option in poll.options!) {
          if (option.image != null) {
            validImages.add(option.image!);
          }
        }
      }
    }

    // If no valid images, return empty container
    if (validImages.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Alignment> getAlignments(int totalImages) {
      switch (totalImages) {
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
        case 4:
        default:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.centerRight,
          ];
      }
    }

    List<Alignment> alignments = getAlignments(validImages.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double imageHeight = 150.h;

        return SizedBox(
          height: imageHeight,
          width: availableWidth,
          child: Stack(
            children: validImages
                .asMap()
                .entries
                .map<Widget>((entry) {
                  int index = entry.key;
                  PollOptionImage imageData = entry.value;
                  Alignment alignment = alignments[index];
                  double imageWidth = (availableWidth * 0.7) - (index * 8.0);
                  imageWidth = imageWidth < 60.w ? 60.w : imageWidth;

                  return Align(
                    alignment: alignment,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      width: imageWidth,
                      height: imageHeight,
                      child: Container(
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
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: Colors.grey[200],
                                ),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[600],
                                  size: 30,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
                                  color: Colors.grey[200],
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
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
