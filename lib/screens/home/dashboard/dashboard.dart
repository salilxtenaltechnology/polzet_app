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

  final StreamController<List<HomeFeedPost>> _postsStreamController =
      StreamController<List<HomeFeedPost>>.broadcast();

  // Sample categories list (you can replace this with your actual data)
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _postsStreamController.close();
    super.dispose();
  }

  /// Load cached data first, then fetch fresh data
  Future<void> _loadInitialData() async {
    // Load cached data immediately
    await _loadCachedPosts();

    // Then fetch fresh data in background
    fetchHomeFeed(showLoader: posts.isEmpty);
  }

  /// Save posts to cache
  Future<void> _savePostsToCache(List<HomeFeedPost> postsToCache) async {
    try {
      final jsonString = jsonEncode(
        postsToCache.map((post) => post.toJson()).toList(),
      );
      await SharedPrefService.setString(_cacheKey, jsonString);
      await SharedPrefService.setString(
        _cacheTimeKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving posts to cache: $e');
    }
  }

  /// Load posts from cache
  Future<void> _loadCachedPosts() async {
    try {
      final cachedJsonString = await SharedPrefService.getString(_cacheKey);
      final cacheTimeString = await SharedPrefService.getString(_cacheTimeKey);

      if (cachedJsonString != null && cachedJsonString.isNotEmpty) {
        // Check if cache is still valid
        if (cacheTimeString != null) {
          final cacheTime = DateTime.parse(cacheTimeString);
          final now = DateTime.now();
          final isValid = now.difference(cacheTime) < _cacheValidDuration;

          if (!isValid) {
            debugPrint('Cache expired, will fetch fresh data');
            return;
          }
        }

        // Parse cached posts
        final List<dynamic> jsonList = jsonDecode(cachedJsonString);
        final cachedPosts = jsonList
            .map((json) => HomeFeedPost.fromJson(json as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            posts = cachedPosts;
            isInitialLoad = false;
          });
          // Emit to stream
          _postsStreamController.add(posts);
        }
        debugPrint('Loaded ${cachedPosts.length} posts from cache');
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }
  }

  Future<void> fetchHomeFeed({bool showLoader = false}) async {
    try {
      if (showLoader) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      final fetchedPosts = await ApiService.fetchHomeFeedPosts();

      // Save to cache
      await _savePostsToCache(fetchedPosts);

      if (mounted) {
        setState(() {
          // Smart merge: update existing posts instead of replacing
          if (!showLoader && posts.isNotEmpty) {
            _mergePostsData(fetchedPosts);
          } else {
            posts = fetchedPosts;
          }

          isLoading = false;
          isInitialLoad = false;
          errorMessage = null;
        });

        // Emit updated posts to stream for instant UI update
        _postsStreamController.add(posts);
      }
    } catch (e) {
      debugPrint('Error fetching home feed: $e');

      if (posts.isNotEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            isInitialLoad = false;
            errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = e.toString();
            isLoading = false;
            isInitialLoad = false;
          });
        }
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

  /// Method to update a specific post in the stream
  /// Call this from HomeFeedPostCard after voting
  void updatePostInStream(HomeFeedPost updatedPost) {
    final index = posts.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      posts[index] = updatedPost;
      // Emit updated list to stream
      _postsStreamController.add(List.from(posts));
    }
  }

  /// Method to notify stream of any changes without full refresh
  void notifyPostsChanged() {
    _postsStreamController.add(List.from(posts));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show loader during initial load
    if (isLoading && isInitialLoad) {
      return const HomeFeedSimmer();
    }

    if (errorMessage != null) {
      return ListView(
        children: [
          SizedBox(height: 200.h),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isInitialLoad = true;
                    });
                    fetchHomeFeed();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
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
          // Handle different stream states
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

          return ListView(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(10.w),
                itemCount: currentPosts.length,
                itemBuilder: (context, index) {
                  final post = currentPosts[index];
                  return HomeFeedPostCard(
                    key: ValueKey(post.id), // Important for proper rebuilding
                    post: post,
                    onPressed: () {},
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
