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

  final Set<int> _chasedUserIds = {};

  // ── Pagination ─────────────────────────────────────────────────────────────
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _nextPageUrl;
  final ScrollController _scrollController = ScrollController();

  final StreamController<List<HomeFeedPost>> _postsStreamController =
      StreamController<List<HomeFeedPost>>.broadcast();

  final List<Category> categories = [
    Category(name: 'Sports', icon: Icons.sports_soccer),
    Category(name: 'Movie', icon: Icons.movie),
    Category(name: 'Tech', icon: Icons.laptop),
    Category(name: 'Trending polls', icon: Icons.trending_up),
    Category(name: 'Music', icon: Icons.music_note),
    Category(name: 'Gaming', icon: Icons.games),
  ];

  // Cache configuration
  static const String _cacheKey = 'home_feed_cache';
  static const String _cacheTimeKey = 'home_feed_cache_time';
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  late Future<UserSuggestionsModel> _suggestionsFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _suggestionsFuture = apiService.fetchUserSuggestions();
    _loadInitialData();
    // ✅ No connectivity listener here — ConnectivityOverlay handles UI globally.
    //    Auto-refresh on reconnect is driven by ConnectivityProvider via overlay.
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _postsStreamController.close();
    super.dispose();
  }

  // ── Scroll listener ────────────────────────────────────────────────────────

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMorePosts();
    }
  }

  // ── Load more ──────────────────────────────────────────────────────────────

  Future<void> _loadMorePosts() async {
    if (!mounted) return;
    if (_isLoadingMore || !_hasMoreData || _nextPageUrl == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await ApiService.fetchHomeFeedPosts(url: _nextPageUrl, isPagination: true);
      if (!mounted) return;
      setState(() {
        posts.addAll(response.results);
        _nextPageUrl = response.next;
        _hasMoreData = response.next != null;
        _isLoadingMore = false;
      });
      _postsStreamController.add(List.from(posts));
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Initial load ───────────────────────────────────────────────────────────

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
            debugPrint('Cache expired, will fetch fresh data');
            return;
          }
        }

        final List<dynamic> jsonList = await compute(_decodePostsBackground, cachedJsonString);
        final cachedPosts = jsonList
            .map((json) => HomeFeedPost.fromJson(json as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            posts = cachedPosts;
            isInitialLoad = false;
          });
          _postsStreamController.add(posts);
        }
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }
  }

  // ── Fetch (first page) ─────────────────────────────────────────────────────

  Future<void> fetchHomeFeed({bool showLoader = false}) async {
    if (!mounted) return;
    try {
      if (showLoader) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      _nextPageUrl = null;
      _hasMoreData = true;

      final response = await ApiService.fetchHomeFeedPosts();
      _nextPageUrl = response.next;
      _hasMoreData = response.next != null;

      await _savePostsToCache(response.results);

      if (mounted) {
        setState(() {
          if (!showLoader && posts.isNotEmpty) {
            _mergePostsData(response.results);
          } else {
            posts = response.results;
          }
          isLoading = false;
          isInitialLoad = false;
          errorMessage = null;
        });
        _postsStreamController.add(List.from(posts));
      }
    } on SocketException {
      debugPrint('No internet connection');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          if (posts.isEmpty) errorMessage = 'no_internet';
        });
      }
    } on TimeoutException {
      debugPrint('Request timed out');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          if (posts.isEmpty) errorMessage = 'no_internet';
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
              errorMessage = 'server_error';
            } else if (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout) {
              errorMessage = 'no_internet';
            } else {
              errorMessage = 'unknown';
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
          if (posts.isEmpty) errorMessage = 'unknown';
        });
      }
    }
  }

  void _mergePostsData(List<HomeFeedPost> fetchedPosts) {
    Map<int, HomeFeedPost> fetchedPostsMap = {
      for (var post in fetchedPosts) post.id: post,
    };

    for (int i = 0; i < posts.length; i++) {
      final currentPost = posts[i];
      final fetchedPost = fetchedPostsMap[currentPost.id];

      if (fetchedPost != null) {
        if (currentPost.polls.isNotEmpty && fetchedPost.polls.isNotEmpty) {
          for (int j = 0; j < currentPost.polls.length; j++) {
            if (j < fetchedPost.polls.length) {
              final currentPoll = currentPost.polls[j];
              final fetchedPoll = fetchedPost.polls[j];
              currentPoll.isPolledByCurrentUser =
                  fetchedPoll.isPolledByCurrentUser;
              currentPoll.totalVotes = fetchedPoll.totalVotes;
              for (int k = 0; k < currentPoll.options.length; k++) {
                if (k < fetchedPoll.options.length) {
                  currentPoll.options[k].percentage =
                      fetchedPoll.options[k].percentage;
                }
              }
            }
          }
        }
        fetchedPostsMap.remove(currentPost.id);
      }
    }

    posts.addAll(fetchedPostsMap.values);
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading && isInitialLoad) {
      return const HomeFeedSimmer();
    }

    if (errorMessage != null && posts.isEmpty) {
      return ConnectionErrorScreen(
        type: errorMessage == 'no_internet'
            ? ConnectionErrorType.noInternet
            : errorMessage == 'server_error'
            ? ConnectionErrorType.serverError
            : ConnectionErrorType.unknown,
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
      return ListView(
        children: [
          SizedBox(height: 200.h),
          const Center(child: Text('No posts available')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: fetchHomeFeed,
      child: StreamBuilder<List<HomeFeedPost>>(
        stream: _postsStreamController.stream,
        initialData: posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              posts.isEmpty) {
            return const HomeFeedSimmer();
          }

          final currentPosts = snapshot.data ?? posts;

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
            padding: EdgeInsets.all(10.w),
            itemCount: currentPosts.length + (_hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == currentPosts.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: _isLoadingMore
                        ? Loader(color: Theme.of(context).colorScheme.primary)
                        : const SizedBox.shrink(),
                  ),
                );
              }

              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              final int completion = userProvider.profile_completion ?? 0;
              final bool showProfileCard = completion < 100;

              // Profile completion card at index 3
              if (index == 3 && showProfileCard) {
                final bool isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;
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
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDarkMode ? 0.3 : 0.05,
                            ),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.improveyourprofile,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            '$completion%',
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 18.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: LinearProgressIndicator(
                              value: completion / 100,
                              minHeight: 4.h,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(height: 14.h),
                          GestureDetector(
                            onTap: () =>
                                navigationPush(context, const EditProfile()),
                            child: Container(
                              width: double.infinity,
                              height: 28.h,
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(25.r),
                              ),
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context)!.completeprofilesetup,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.sp,
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
                          AppLocalizations.of(context)!.peopleyoumayknow,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.2.sp,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              navigationPush(context, const SuggestionUsers()),
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
                    const SizedBox(height: 5),
                    PeopleYouMayKnowSection(
                      key: const ValueKey('suggestions'),
                      suggestionsFuture: _suggestionsFuture,
                      chasedUserIds: _chasedUserIds,
                      apiService: apiService,
                    ),
                    const SizedBox(height: 12),
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

// ── Isolate Parsing Functions ────────────────────────────────────────────────

String _encodePostsBackground(List<dynamic> jsonList) {
  return jsonEncode(jsonList);
}

List<dynamic> _decodePostsBackground(String jsonString) {
  return jsonDecode(jsonString) as List<dynamic>;
}