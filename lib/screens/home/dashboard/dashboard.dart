// ignore_for_file: deprecated_member_use, unused_field, unused_local_variable
part of 'dashboard_import.dart';

class Dashboard extends StatefulWidget {
  Dashboard({super.key});

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
        }
        debugPrint('Loaded ${cachedPosts.length} posts from cache');
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }
  }

  Future<void> fetchHomeFeed({bool showLoader = true}) async {
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
          posts = fetchedPosts;
          isLoading = false;
          isInitialLoad = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching home feed: $e');

      // If we have cached posts, show them instead of error
      if (posts.isNotEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            isInitialLoad = false;
            errorMessage = null; // Don't show error if we have cached data
          });
        }
      } else {
        // Only show error if no cached data available
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
      return HomeFeedSimmer();
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
      child: ListView(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(10.w),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return HomeFeedPostCard(post: post, onPressed: () {});
            },
          ),
        ],
      ),
    );
  }
}
