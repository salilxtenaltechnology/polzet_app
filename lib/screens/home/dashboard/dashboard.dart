// ignore_for_file: deprecated_member_use, unused_field, unused_local_variable
part of 'dashboard_import.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<StatefulWidget> createState() {
    return DashboardState();
  }
}

class DashboardState extends State<Dashboard> with UtilityMixin {
  late final ApiService apiService = ApiService();
  List<HomeFeedPost> posts = [];
  bool isLoading = false;
  bool isInitialLoad = true;
  String? errorMessage;

  final Set<dynamic> _chasedUserIds = {};
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int? _nextPage;
  String? _snapshot;
  final ScrollController _scrollController = ScrollController();

  final StreamController<List<HomeFeedPost>> _postsStreamController =
      StreamController<List<HomeFeedPost>>.broadcast();

  static const String _cacheKey = 'home_feed_cache';
  static const String _cacheTimeKey = 'home_feed_cache_time';
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  late Future<UserSuggestionsModel> _suggestionsFuture;
  UserProvider? _userProvider;

  static final StreamController<void> _refreshTriggerController =
      StreamController<void>.broadcast();
  StreamSubscription<void>? _refreshSubscription;

  static void triggerRefresh() {
    _refreshTriggerController.add(null);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _suggestionsFuture = apiService.fetchUserSuggestions();
    _loadInitialData();
    _refreshSubscription = _refreshTriggerController.stream.listen((_) {
      if (mounted) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        fetchHomeFeed(showLoader: posts.isEmpty);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    if (_userProvider != userProvider) {
      _userProvider?.removeListener(_onUserProviderChanged);
      _userProvider = userProvider;
      _userProvider?.addListener(_onUserProviderChanged);
    }
  }

  void _onUserProviderChanged() {
    if (_userProvider != null && _userProvider!.deletedPostIds.isNotEmpty) {
      final deletedIds = _userProvider!.deletedPostIds;
      final originalLength = posts.length;
      setState(() {
        posts.removeWhere((post) => deletedIds.contains(post.id));
      });
      if (posts.length != originalLength) {
        _savePostsToCache(posts);
        _postsStreamController.add(List.from(posts));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _postsStreamController.close();
    _refreshSubscription?.cancel();
    _userProvider?.removeListener(_onUserProviderChanged);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (!mounted) return;
    if (_isLoadingMore || !_hasMoreData || _nextPage == null) return;

    setState(() => _isLoadingMore = true);

    try {
      debugPrint('Fetching page: $_nextPage');
      final response = await ApiService.fetchHomeFeedPosts(
        page: _nextPage,
        snapshot: _snapshot,
        isPagination: true,
      );
      if (!mounted) return;
      setState(() {
        posts.addAll(response.results);
        _nextPage = response.page != null ? response.page! + 1 : null;
        _snapshot = response.snapshot;
        _hasMoreData = response.hasMore ?? false;
        _isLoadingMore = false;
      });
      debugPrint('Loaded page, next page is: $_nextPage');
      _updateGloballyChasedUsers();
      _postsStreamController.add(List.from(posts));
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadInitialData() async {
    await _loadCachedPosts();
    fetchHomeFeed(showLoader: posts.isEmpty);
  }

  Future<void> _savePostsToCache(List<HomeFeedPost> postsToCache) async {
    try {
      final jsonList = postsToCache.map((post) => post.toJson()).toList();
      final jsonString = await compute(_encodePostsBackground, jsonList);
      await SharedPrefService.setString(_cacheKey, jsonString);
      await SharedPrefService.setString(
        _cacheTimeKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving posts to cache: $e');
    }
  }

  Future<void> _loadCachedPosts() async {
    try {
      final cachedJsonString = await SharedPrefService.getString(_cacheKey);
      final cacheTimeString = await SharedPrefService.getString(_cacheTimeKey);

      if (cachedJsonString != null && cachedJsonString.isNotEmpty) {
        if (cacheTimeString != null) {
          final cacheTime = DateTime.parse(cacheTimeString);
          final isValid =
              DateTime.now().difference(cacheTime) < _cacheValidDuration;
          if (!isValid) {
            debugPrint(
              'Cache expired, but loading anyway to show UI instantly',
            );
          }
        }

        final List<dynamic> jsonList = await compute(
          _decodePostsBackground,
          cachedJsonString,
        );
        final cachedPosts = jsonList
            .map((json) => HomeFeedPost.fromJson(json as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            posts = cachedPosts;
            isInitialLoad = false;
          });
          _updateGloballyChasedUsers();
          _postsStreamController.add(posts);
        }
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }
  }

  Future<void> fetchHomeFeed({bool showLoader = false}) async {
    if (!mounted) return;
    try {
      if (showLoader) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      _nextPage = null;
      _snapshot = null;
      _hasMoreData = true;

      final response = await ApiService.fetchHomeFeedPosts();
      _nextPage = response.page != null ? response.page! + 1 : null;
      _snapshot = response.snapshot;
      _hasMoreData = response.hasMore ?? false;
      debugPrint('Initial page loaded, next page is: $_nextPage');

      if (mounted) {
        setState(() {
          posts = response.results;
          isLoading = false;
          isInitialLoad = false;
          errorMessage = null;
        });

        _updateGloballyChasedUsers();
        _savePostsToCache(posts);
        _postsStreamController.add(List.from(posts));
      }
    } on SocketException catch (e) {
      debugPrint('No internet connection');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          if (posts.isEmpty) errorMessage = 'no_internet: ${e.toString()}';
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('Request timed out');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          if (posts.isEmpty) {
            errorMessage = 'no_internet: timeout ${e.toString()}';
          }
        });
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.response?.statusCode} | ${e.type}');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          if (posts.isEmpty) {
            final statusCode = e.response?.statusCode ?? 0;
            if (statusCode >= 500) {
              errorMessage = 'server_error: status $statusCode';
            } else if (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout) {
              errorMessage = 'no_internet: timeout ${e.message}';
            } else {
              errorMessage = 'unknown: status $statusCode ${e.message}';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching home feed: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          if (posts.isEmpty) errorMessage = 'unknown: ${e.toString()}';
        });
      }
    }
  }

  void updatePostInStream(HomeFeedPost updatedPost) {
    final index = posts.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      posts[index] = updatedPost;
      _postsStreamController.add(List.from(posts));
    }
  }

  void notifyPostsChanged() {
    _postsStreamController.add(List.from(posts));
  }

  void _updateGloballyChasedUsers() {
    for (var post in posts) {
      if (post.followingStatus != 'none') {
        HomeFeedPostCard.globallyChasedUserStates[post.user.userid] = 'hidden';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final txt = AppTextColors.of(context);

    if (isLoading && isInitialLoad) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    if (errorMessage != null && posts.isEmpty) {
      return ConnectionErrorScreen(
        type: errorMessage!.startsWith('no_internet')
            ? ConnectionErrorType.noInternet
            : errorMessage!.startsWith('server_error')
            ? ConnectionErrorType.serverError
            : ConnectionErrorType.unknown,
        errorMessage: errorMessage,
        onRetry: () {
          setState(() {
            errorMessage = null;
            isInitialLoad = true;
          });
          fetchHomeFeed(showLoader: true);
        },
      );
    }

    if (posts.isEmpty && !isLoading) {
      return const Center(child: Text('No posts available'));
    }

    return RefreshIndicator(
      onRefresh: fetchHomeFeed,
      color: Theme.of(context).colorScheme.onPrimary,
      child: StreamBuilder<List<HomeFeedPost>>(
        stream: _postsStreamController.stream,
        initialData: posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              posts.isEmpty) {
            return Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            );
          }

          final userProvider = Provider.of<UserProvider>(context);
          final currentPosts = (snapshot.data ?? posts)
              .where((post) => !userProvider.deletedPostIds.contains(post.id))
              .toList();

          if (currentPosts.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: 200.h),
                const Center(child: Text('No posts available')),
              ],
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 70).w,
            itemCount: currentPosts.length + (_hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == currentPosts.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: _isLoadingMore
                        ? Loader(color: Theme.of(context).colorScheme.onPrimary)
                        : const SizedBox.shrink(),
                  ),
                );
              }

              // Profile completion card at index 3
              if (index == 3) {
                return Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    final int completion = userProvider.profile_completion ?? 0;
                    final bool showProfileCard = completion < 100;
                    if (showProfileCard) {
                      return Column(
                        children: [
                          HomeFeedPostCard(
                            key: ValueKey(currentPosts[index].id),
                            post: currentPosts[index],
                            onPressed: () {},
                          ),
                          Container(
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: const EdgeInsets.all(12).w,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.improveyourprofile,
                                  style: AppTextStyles.subText.copyWith(
                                    color: txt.title,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '$completion%',
                                  style: AppTextStyles.sectionHeading.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: completion / 100,
                                    minHeight: 4.h,
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.primaryColor,
                                        ),
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                GestureDetector(
                                  onTap: () => navigationPush(
                                    context,
                                    const EditProfile(),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor,
                                      borderRadius: BorderRadius.circular(50.r),
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.completeprofilesetup,
                                        style: AppTextStyles.subText.copyWith(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    } else {
                      return HomeFeedPostCard(
                        key: ValueKey(currentPosts[index].id),
                        post: currentPosts[index],
                        onPressed: () {},
                      );
                    }
                  },
                );
              }

              // Suggested users at index 6
              if (index == 6) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HomeFeedPostCard(
                      key: ValueKey(currentPosts[index].id),
                      post: currentPosts[index],
                      onPressed: () {},
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Suggested for you',
                          style: AppTextStyles.subText.copyWith(
                            color: txt.title,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => navigationPush(
                            context,
                            const SuggestedUsersList(),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.seeall,
                            style: AppTextStyles.subText.copyWith(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SuggestedUsers(
                      key: const ValueKey('suggestions'),
                      suggestionsFuture: _suggestionsFuture,
                      chasedUserIds: _chasedUserIds,
                      apiService: apiService,
                    ),
                    const SizedBox(height: 15),
                  ],
                );
              }

              final post = currentPosts[index];
              return HomeFeedPostCard(
                key: ValueKey(post.id),
                post: post,
                onPressed: () {},
              );
            },
          );
        },
      ),
    );
  }
}

String _encodePostsBackground(List<dynamic> jsonList) {
  return jsonEncode(jsonList);
}

List<dynamic> _decodePostsBackground(String jsonString) {
  return jsonDecode(jsonString) as List<dynamic>;
}
