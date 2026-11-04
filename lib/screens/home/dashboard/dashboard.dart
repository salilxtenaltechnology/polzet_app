// ignore_for_file: deprecated_member_use, unused_field, unused_local_variable, unused_element
part of 'dashboard_import.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<StatefulWidget> createState() {
    return DashboardState();
  }
}

class DashboardState extends State<Dashboard>
    with
        UtilityMixin,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final AnimationController _goldBorderController;
  late final AnimationController _aiAssistantController;
  late final AnimationController _aiOptionsController;
  late final AnimationController _aiDescriptionController;
  late final ApiService apiService = ApiService();
  static List<HomeFeedPost> _staticPosts = [];
  static bool _everFetched = false;
  List<HomeFeedPost> posts = List.from(_staticPosts);
  bool isLoading = false;
  late bool isInitialLoad = _staticPosts.isEmpty;
  bool _isRestoringCache = false;
  bool _isBackgroundRefreshing = false;
  String? errorMessage;

  final Set<dynamic> _chasedUserIds = {};
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int? _nextPage;
  String? _snapshot;
  final ScrollController _scrollController = ScrollController();
  int? _selectedPollTabIndex;
  final TextEditingController _textPollQuestionController =
      TextEditingController();
  final TextEditingController _textPollDescriptionController =
      TextEditingController();
  bool _showTextPollDescription = false;
  final List<TextEditingController> _textPollOptionControllers = [];
  String _textPollQuestionErrorText = '';
  String _textPollOptionsErrorText = '';

  void _onTextPollQuestionChanged() {
    if (_textPollQuestionErrorText.isNotEmpty &&
        _textPollQuestionController.text.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _textPollQuestionErrorText = '';
        });
      }
    }
  }

  void _onTextPollOptionChanged() {
    if (_textPollOptionsErrorText.isNotEmpty) {
      final validCount = _textPollOptionControllers
          .where((c) => c.text.trim().isNotEmpty)
          .length;
      if (validCount >= 2 && mounted) {
        setState(() {
          _textPollOptionsErrorText = '';
        });
      }
    }
  }

  void _initTextPollOptions() {
    for (int i = 0; i < 2; i++) {
      final controller = TextEditingController();
      controller.addListener(_onTextPollOptionChanged);
      _textPollOptionControllers.add(controller);
    }
  }

  void _addTextPollOption() {
    if (_textPollOptionControllers.length < 4) {
      setState(() {
        final controller = TextEditingController();
        controller.addListener(_onTextPollOptionChanged);
        _textPollOptionControllers.add(controller);
      });
    }
  }

  void _removeTextPollOption(int index) {
    if (_textPollOptionControllers.length > 2) {
      setState(() {
        final controller = _textPollOptionControllers[index];
        controller.removeListener(_onTextPollOptionChanged);
        controller.dispose();
        _textPollOptionControllers.removeAt(index);
      });
    }
  }

  bool _isCreatingTextPoll = false;
  bool _isGeneratingAiQuestion = false;

  Future<void> _generateTextPollQuestion() async {
    if (_isGeneratingAiQuestion) return;

    final query = _textPollQuestionController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _textPollQuestionErrorText =
            AppLocalizations.of(context)?.pleaseenteratopic ??
            'Please enter a topic';
      });
      return;
    }

    setState(() {
      _isGeneratingAiQuestion = true;
    });
    _aiAssistantController.repeat();

    try {
      final response = await apiService.generateQuestion(input: query);
      debugPrint('generateQuestion response: $response');

      final questionText = response['question']?.toString();
      if (questionText != null && questionText.trim().isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _textPollQuestionController.text = questionText;
          _textPollQuestionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textPollQuestionController.text.length),
          );
          _textPollQuestionErrorText = '';
        });
        showToast(message: 'Question generated!');
      } else {
        if (!mounted) return;
        showToast(
          message:
              response['message']?.toString() ?? 'Failed to generate question',
        );
      }
    } catch (e) {
      debugPrint('generateQuestion error: $e');
      if (mounted) {
        showToast(message: e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiQuestion = false;
        });
        _aiAssistantController.stop();
        _aiAssistantController.reset();
      }
    }
  }

  bool _isGeneratingAiOptions = false;

  Future<void> _generateTextPollOptions() async {
    if (_isGeneratingAiOptions) return;

    final question = _textPollQuestionController.text.trim();
    if (question.isEmpty) {
      setState(() {
        _textPollQuestionErrorText =
            AppLocalizations.of(context)?.pleaseenteraquestion ??
            'Please enter a question';
      });
      return;
    }

    setState(() {
      _isGeneratingAiOptions = true;
    });
    _aiOptionsController.repeat();

    try {
      final response = await apiService.generateOptions(input: question);
      debugPrint('generateOptions response: $response');

      final List<dynamic>? optionsList = response['options'];
      if (optionsList != null && optionsList.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          final count = optionsList.length.clamp(2, 4);

          while (_textPollOptionControllers.length < count) {
            final controller = TextEditingController();
            controller.addListener(_onTextPollOptionChanged);
            _textPollOptionControllers.add(controller);
          }

          while (_textPollOptionControllers.length > count) {
            final controller = _textPollOptionControllers.removeLast();
            controller.removeListener(_onTextPollOptionChanged);
            controller.dispose();
          }

          for (int i = 0; i < count; i++) {
            _textPollOptionControllers[i].text = optionsList[i].toString();
          }
          _textPollOptionsErrorText = '';
        });
        showToast(message: 'Options generated!');
      } else {
        if (!mounted) return;
        showToast(
          message:
              response['message']?.toString() ?? 'Failed to generate options',
        );
      }
    } catch (e) {
      debugPrint('generateOptions error: $e');
      if (mounted) {
        showToast(message: e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiOptions = false;
        });
        _aiOptionsController.stop();
        _aiOptionsController.reset();
      }
    }
  }

  bool _isGeneratingAiDescription = false;

  Future<void> _generateTextPollDescription() async {
    if (_isGeneratingAiDescription) return;

    final question = _textPollQuestionController.text.trim();
    final validOptions = _textPollOptionControllers
        .map((c) => c.text.trim())
        .where((opt) => opt.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      setState(() {
        _textPollQuestionErrorText =
            AppLocalizations.of(context)?.pleaseenteraquestion ??
            'Please enter a question';
      });
      return;
    }

    if (validOptions.length < 2) {
      setState(() {
        _textPollOptionsErrorText =
            AppLocalizations.of(context)?.pleaseenteratleasttwooptions ??
            'Please enter at least two options';
      });
      return;
    }

    setState(() {
      _isGeneratingAiDescription = true;
    });
    _aiDescriptionController.repeat();

    try {
      final descResponse = await apiService.generateDescription(
        question: question,
        options: validOptions,
      );
      debugPrint('generateDescription response: $descResponse');

      final String descriptionText =
          (descResponse["description"] ?? descResponse["data"]?["description"])
              ?.toString()
              .trim() ??
          '';

      final dynamic rawHashtags =
          descResponse['hashtags'] ?? descResponse['data']?['hashtags'];
      List<String> hashtagsList = [];
      if (rawHashtags is List) {
        hashtagsList = rawHashtags
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (rawHashtags is String) {
        hashtagsList = rawHashtags
            .split(RegExp(r'[\s,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      String fullText = descriptionText;
      if (hashtagsList.isNotEmpty) {
        final formattedHashtags = hashtagsList
            .map((h) => h.startsWith('#') ? h : '#$h')
            .join(' ');
        if (fullText.isNotEmpty) {
          fullText = '$fullText\n\n$formattedHashtags';
        } else {
          fullText = formattedHashtags;
        }
      }

      if (fullText.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _textPollDescriptionController.text = fullText;
          _textPollDescriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textPollDescriptionController.text.length),
          );
          _showTextPollDescription = true;
        });
        showToast(message: 'Description generated!');
      } else {
        if (!mounted) return;
        showToast(
          message:
              descResponse['message']?.toString() ??
              'Failed to generate description',
        );
      }
    } catch (e) {
      debugPrint('generateDescription error: $e');
      if (mounted) {
        showToast(message: e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiDescription = false;
        });
        _aiDescriptionController.stop();
        _aiDescriptionController.reset();
      }
    }
  }

  void _resetTextPollFields() {
    _textPollQuestionController.clear();
    _textPollDescriptionController.clear();
    _showTextPollDescription = false;
    _textPollQuestionErrorText = '';
    _textPollOptionsErrorText = '';
    if (_isGeneratingAiDescription) {
      _aiDescriptionController.stop();
      _aiDescriptionController.reset();
      _isGeneratingAiDescription = false;
    }
    for (final controller in _textPollOptionControllers) {
      controller.removeListener(_onTextPollOptionChanged);
      controller.dispose();
    }
    _textPollOptionControllers.clear();
    _initTextPollOptions();
  }

  Future<void> _createTextPoll() async {
    if (_isCreatingTextPoll) return;

    final question = _textPollQuestionController.text.trim();
    final validOptions = _textPollOptionControllers
        .map((c) => c.text.trim())
        .where((opt) => opt.isNotEmpty)
        .toList();

    bool isValid = true;
    String newQuestionError = '';
    String newOptionsError = '';

    if (question.isEmpty) {
      newQuestionError =
          AppLocalizations.of(context)?.pleaseenteraquestion ??
          'Please enter a question';
      isValid = false;
    }

    if (validOptions.length < 2) {
      newOptionsError =
          AppLocalizations.of(context)?.pleaseenteratleasttwooptions ??
          'Please enter at least two options';
      isValid = false;
    }

    if (!isValid) {
      setState(() {
        _textPollQuestionErrorText = newQuestionError;
        _textPollOptionsErrorText = newOptionsError;
      });
      return;
    }

    final description = _textPollDescriptionController.text.trim();

    setState(() => _isCreatingTextPoll = true);

    try {
      await apiService.createTextPoll(
        question: question,
        pollOptions: validOptions,
        description: description,
        votingType: 'ranking',
        maxOptions: validOptions.length,
      );

      if (!mounted) return;

      showToast(
        message:
            AppLocalizations.of(context)?.pollcreated ??
            'Poll created successfully!',
      );

      Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadUserDataSilently(force: true);
      _resetTextPollFields();
      setState(() {
        _selectedPollTabIndex = null;
      });
      fetchHomeFeed(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();
      showToast(
        message: errorMsg.isNotEmpty ? errorMsg : 'Failed to create poll',
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingTextPoll = false);
      }
    }
  }

  final TextEditingController _imagePollQuestionController =
      TextEditingController();
  List<File> _selectedImagePollImages = [];
  final List<TextEditingController> _imagePollLabelControllers = [];
  static const int _maxImagePollImages = 4;

  void _syncImagePollLabelControllers() {
    while (_imagePollLabelControllers.length <
        _selectedImagePollImages.length) {
      _imagePollLabelControllers.add(TextEditingController());
    }
    while (_imagePollLabelControllers.length >
        _selectedImagePollImages.length) {
      final controller = _imagePollLabelControllers.removeLast();
      controller.dispose();
    }
  }

  Future<void> _pickImagePollImages() async {
    try {
      final int remaining =
          _maxImagePollImages - _selectedImagePollImages.length;
      if (remaining <= 0) return;

      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: remaining,
        allowCamera: true,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty && mounted) {
        setState(() {
          _selectedImagePollImages.addAll(pickedFiles);
          if (_selectedImagePollImages.length > _maxImagePollImages) {
            _selectedImagePollImages = _selectedImagePollImages.sublist(
              0,
              _maxImagePollImages,
            );
          }
          _syncImagePollLabelControllers();
        });
      }
    } catch (e) {
      debugPrint('Error picking image poll images: $e');
    }
  }

  void _removeImagePollImage(int index) {
    if (index >= 0 && index < _selectedImagePollImages.length) {
      setState(() {
        _selectedImagePollImages.removeAt(index);
        _syncImagePollLabelControllers();
      });
    }
  }

  final TextEditingController _battlePollQuestionController =
      TextEditingController();
  final List<File?> _selectedBattlePollImages = [null, null];
  final TextEditingController _battlePollLabel1Controller =
      TextEditingController();
  final TextEditingController _battlePollLabel2Controller =
      TextEditingController();

  Future<void> _pickBattlePollImage(int index) async {
    try {
      int otherSelectedCount = 0;
      for (int i = 0; i < _selectedBattlePollImages.length; i++) {
        if (i != index && _selectedBattlePollImages[i] != null) {
          otherSelectedCount++;
        }
      }
      final int allowedMaxImages = (2 - otherSelectedCount).clamp(1, 2);

      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: allowedMaxImages,
        allowCamera: true,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty && mounted) {
        setState(() {
          if (pickedFiles.length >= 2) {
            _selectedBattlePollImages[0] = pickedFiles[0];
            _selectedBattlePollImages[1] = pickedFiles[1];
          } else {
            _selectedBattlePollImages[index] = pickedFiles[0];
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking battle poll image: $e');
    }
  }

  void _removeBattlePollImage(int index) {
    if (index >= 0 && index < _selectedBattlePollImages.length) {
      setState(() {
        _selectedBattlePollImages[index] = null;
      });
    }
  }

  final StreamController<List<HomeFeedPost>> _postsStreamController =
      StreamController<List<HomeFeedPost>>.broadcast();

  static String _getFeedCacheKey([String? userId]) {
    final cleanId = userId?.trim();
    if (cleanId != null && cleanId.isNotEmpty) {
      return 'home_feed_cache_$cleanId';
    }
    return 'home_feed_cache';
  }

  static String _getFeedTimeKey([String? userId]) {
    final cleanId = userId?.trim();
    if (cleanId != null && cleanId.isNotEmpty) {
      return 'home_feed_cache_time_$cleanId';
    }
    return 'home_feed_cache_time';
  }

  static List<HomeFeedPost> _parseCachedPostsJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return [];
      final List<HomeFeedPost> result = [];
      for (final item in decoded) {
        if (item is Map) {
          try {
            result.add(HomeFeedPost.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Error parsing cached post item: $e');
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error decoding cached posts json: $e');
      return [];
    }
  }

  /// Pre-warms feed cache from local storage before Dashboard widget mounts
  static Future<void> prewarmFeedCache({String? userId}) async {
    try {
      if (_staticPosts.isNotEmpty) return;
      final activeUserId = userId ?? await SharedPrefService.getUserId();
      final key = _getFeedCacheKey(activeUserId);
      String? cachedJsonString = await SharedPrefService.getString(key);
      if ((cachedJsonString == null || cachedJsonString.isEmpty) &&
          activeUserId != null) {
        cachedJsonString =
            await SharedPrefService.getString(_getFeedCacheKey(null));
      }
      if (cachedJsonString != null && cachedJsonString.isNotEmpty) {
        final parsed = _parseCachedPostsJson(cachedJsonString);
        if (parsed.isNotEmpty) {
          _staticPosts = parsed;
          debugPrint('✅ Pre-warmed ${_staticPosts.length} posts from cache');
        }
      }
    } catch (e) {
      debugPrint('Error pre-warming feed cache: $e');
    }
  }

  static void clearStaticCache() {
    _staticPosts = [];
    _everFetched = false;
  }

  static Future<void> clearAllFeedCaches() async {
    clearStaticCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('home_feed_cache'))
          .toList();
      for (final key in feedKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing feed caches: $e');
    }
  }

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
    _initTextPollOptions();
    _textPollQuestionController.addListener(_onTextPollQuestionChanged);
    _goldBorderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8500),
    )..repeat();
    _aiAssistantController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _aiOptionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _aiDescriptionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
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
        _staticPosts = List.from(posts);
      });
      if (posts.length != originalLength) {
        _savePostsToCache(posts);
        _postsStreamController.add(List.from(posts));
      }
    }
  }

  @override
  void dispose() {
    _goldBorderController.dispose();
    _aiAssistantController.dispose();
    _aiOptionsController.dispose();
    _aiDescriptionController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _postsStreamController.close();
    _refreshSubscription?.cancel();
    _userProvider?.removeListener(_onUserProviderChanged);
    _textPollQuestionController.removeListener(_onTextPollQuestionChanged);
    _textPollQuestionController.dispose();
    _textPollDescriptionController.dispose();
    for (final controller in _textPollOptionControllers) {
      controller.removeListener(_onTextPollOptionChanged);
      controller.dispose();
    }
    _imagePollQuestionController.dispose();
    for (final controller in _imagePollLabelControllers) {
      controller.dispose();
    }
    _battlePollQuestionController.dispose();
    _battlePollLabel1Controller.dispose();
    _battlePollLabel2Controller.dispose();
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
        _staticPosts = List.from(posts);
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
    if (posts.isEmpty) {
      await _loadCachedPosts();
    }
    // Stale-while-revalidate: fetch latest data in background without blocking cached content
    fetchHomeFeed(showLoader: posts.isEmpty);
    if (mounted) {
      Provider.of<UserProvider>(context, listen: false).loadUserDataSilently();
    }
  }

  Future<void> _savePostsToCache(List<HomeFeedPost> postsToCache) async {
    try {
      final userId = await SharedPrefService.getUserId();
      final cacheKey = _getFeedCacheKey(userId);
      final cacheTimeKey = _getFeedTimeKey(userId);
      final jsonList = postsToCache.map((post) => post.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await SharedPrefService.setString(cacheKey, jsonString);
      await SharedPrefService.setString(
        cacheTimeKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving posts to cache: $e');
    }
  }

  Future<void> _loadCachedPosts() async {
    if (posts.isNotEmpty) return;
    try {
      _isRestoringCache = true;
      final userId = await SharedPrefService.getUserId();
      final key = _getFeedCacheKey(userId);
      String? cachedJsonString = await SharedPrefService.getString(key);
      if ((cachedJsonString == null || cachedJsonString.isEmpty) &&
          userId != null) {
        cachedJsonString =
            await SharedPrefService.getString(_getFeedCacheKey(null));
      }

      if (cachedJsonString != null && cachedJsonString.isNotEmpty) {
        final cachedPosts = _parseCachedPostsJson(cachedJsonString);
        if (cachedPosts.isNotEmpty && mounted) {
          setState(() {
            posts = cachedPosts;
            _staticPosts = List.from(cachedPosts);
            isInitialLoad = false;
            _isRestoringCache = false;
          });
          _updateGloballyChasedUsers();
          _postsStreamController.add(List.from(posts));
        }
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    } finally {
      if (mounted && _isRestoringCache) {
        setState(() {
          _isRestoringCache = false;
        });
      }
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
      } else {
        _isBackgroundRefreshing = true;
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
          _staticPosts = List.from(response.results);
          _everFetched = true;
          isLoading = false;
          isInitialLoad = false;
          _isBackgroundRefreshing = false;
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
          _isBackgroundRefreshing = false;
          if (posts.isEmpty) errorMessage = 'no_internet: ${e.toString()}';
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('Request timed out');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoad = false;
          _isBackgroundRefreshing = false;
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
          _isBackgroundRefreshing = false;
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
          _isBackgroundRefreshing = false;
          if (posts.isEmpty) errorMessage = 'unknown: ${e.toString()}';
        });
      }
    }
  }

  void updatePostLocally(HomeFeedPost updatedPost) {
    final index = posts.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      posts[index] = updatedPost;
      _staticPosts = List.from(posts);
      _savePostsToCache(posts);
    }
  }

  void updatePostInStream(HomeFeedPost updatedPost) {
    final index = posts.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      posts[index] = updatedPost;
      _staticPosts = List.from(posts);
      _savePostsToCache(posts);
      _postsStreamController.add(List.from(posts));
    }
  }

  void notifyPostsChanged() {
    _savePostsToCache(posts);
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
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _buildBody(),
    );
  }

  void _showMorePollsDialog(TapDownDetails details) {
    final screenSize = MediaQuery.of(context).size;
    final double tapY = details.globalPosition.dy;
    final double tapX = details.globalPosition.dx;
    final bool showAbove = tapY > screenSize.height - 240;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              top: showAbove ? null : tapY + 8,
              bottom: showAbove ? (screenSize.height - tapY + 8) : null,
              right: 16.w,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 210,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMorePollOption(
                        icon: Assets.images.icThisThat.path,
                        iconBg: const Color(0x1E16A34A),
                        iconDarkBg: const  Color(0x3316A34A),
                        title: AppLocalizations.of(context)!.thisorthat,
                        txt: txt,
                        onTap: () {
                          Navigator.pop(ctx);
                          navigationPush(context, const NewThisOrThat());
                        },
                      ),
                      SizedBox(height: 12.h),
                      _buildMorePollOption(
                        icon: Assets.images.icHot.path,
                        iconBg: const Color(0x1AEA580C),
                        iconDarkBg: const Color(0x33EA580C),
                        title: AppLocalizations.of(context)!.hottakespoll,
                        txt: txt,
                        onTap: () {
                          Navigator.pop(ctx);
                          navigationPush(context, const NewHotTakePoll());
                        },
                      ),
                      SizedBox(height: 12.h),
                      _buildMorePollOption(
                        icon: Assets.images.icAnonymous.path,
                        iconBg: const Color(0x1A7C3AED),
                        iconDarkBg: const  Color(0x337C3AED),
                        title: AppLocalizations.of(context)!.anonymouspoll,
                        txt: txt,
                        onTap: () {
                          Navigator.pop(ctx);
                          navigationPush(context, const NewAnonymousPoll());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.90, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            alignment: showAbove ? Alignment.bottomRight : Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildMorePollOption({
    required String icon,
    required Color iconBg,
    required Color iconDarkBg,
    required String title,
    required AppTextColors txt,
    required VoidCallback onTap,
  }) {
   final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? iconDarkBg : iconBg),
            alignment: Alignment.center,
            child: Image.asset(icon, height: 16.r, width: 16.r),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: txt.title,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollTab({
    required int index,
    required String title,
    required String icon,
    required bool isDarkmode,
    required Color bg,
    required Color darkBg,
    required AppTextColors txt,
    VoidCallback? onTap,
  }) {
    final bool isSelected = _selectedPollTabIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          onTap ??
          () {
            if (index == 0) {
              setState(() {
                _selectedPollTabIndex = isSelected ? null : index;
              });
            } else if (index == 1) {
              navigationPush(context, const NewImagePoll());
            } else if (index == 2) {
              navigationPush(context, const NewBattelPoll());
            }
          },
      child: Container(
        height: 30,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: isDarkmode ? darkBg : bg,
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(icon, height: 16.h, width: 16.w),
              SizedBox(width: 5.w),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: AppTextStyles.bodyText.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: txt.title,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextPollSection(
    BuildContext context,
    bool isDarkmode,
    AppTextColors txt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.question,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: txt.title,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isGeneratingAiQuestion ? null : _generateTextPollQuestion,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: AnimatedBuilder(
                  animation: _aiAssistantController,
                  builder: (context, child) {
                    if (!_isGeneratingAiQuestion) {
                      return child!;
                    }
                    final double angle =
                        _aiAssistantController.value * 2 * math.pi;
                    final double scale =
                        1.0 +
                        0.22 *
                            math.sin(
                              _aiAssistantController.value * 2 * math.pi,
                            );
                    return Transform.scale(
                      scale: scale,
                      child: Transform.rotate(angle: angle, child: child),
                    );
                  },
                  child: Image.asset(
                    Assets.images.icAssistant.path,
                    height: 16.h,
                    width: 16.w,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: _textPollQuestionController,
          hintText: AppLocalizations.of(context)!.pleaseenteraquestion,
          focusedBorderColor: AppColors.primaryColor,
          onChanged: (val) {
            if (_textPollQuestionErrorText.isNotEmpty &&
                val.trim().isNotEmpty) {
              setState(() {
                _textPollQuestionErrorText = '';
              });
            }
          },
        ),
        if (_textPollQuestionErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: Text(
              _textPollQuestionErrorText,
              style: CustomTextStyles.msgErrorText(context),
            ),
          ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.polloptions,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: txt.title,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isGeneratingAiOptions ? null : _generateTextPollOptions,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: AnimatedBuilder(
                  animation: _aiOptionsController,
                  builder: (context, child) {
                    if (!_isGeneratingAiOptions) {
                      return child!;
                    }
                    final double angle =
                        _aiOptionsController.value * 2 * math.pi;
                    final double scale =
                        1.0 +
                        0.22 *
                            math.sin(_aiOptionsController.value * 2 * math.pi);
                    return Transform.scale(
                      scale: scale,
                      child: Transform.rotate(angle: angle, child: child),
                    );
                  },
                  child: Image.asset(
                    Assets.images.icAssistant.path,
                    height: 16.h,
                    width: 16.w,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ...List.generate(_textPollOptionControllers.length, (index) {
          final canRemove = _textPollOptionControllers.length > 2;
          return Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              children: [
                Expanded(
                  child: SecondryTextfield(
                    controller: _textPollOptionControllers[index],
                    hintText:
                        '${AppLocalizations.of(context)!.option} ${index + 1}',
                    focusedBorderColor: AppColors.primaryColor,
                    onChanged: (val) {
                      if (_textPollOptionsErrorText.isNotEmpty) {
                        final validCount = _textPollOptionControllers
                            .where((c) => c.text.trim().isNotEmpty)
                            .length;
                        if (validCount >= 2) {
                          setState(() {
                            _textPollOptionsErrorText = '';
                          });
                        }
                      }
                    },
                  ),
                ),
                if (canRemove) ...[
                  SizedBox(width: 8.w),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _removeTextPollOption(index),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (_textPollOptionControllers.length < 4) ...[
          GestureDetector(
            onTap: _addTextPollOption,
            child: Row(
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.primaryColor),
                SizedBox(width: 6.w),
                Text(
                  AppLocalizations.of(context)!.addoption,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_textPollOptionsErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: 4.h),
            child: Text(
              _textPollOptionsErrorText,
              style: CustomTextStyles.msgErrorText(context),
            ),
          ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _showTextPollDescription = !_showTextPollDescription;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showTextPollDescription
                        ? 'Hide description and tags'
                        : 'Add description and tags',
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF898989),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    _showTextPollDescription
                        ? Icons.keyboard_arrow_up_outlined
                        : Icons.keyboard_arrow_down_outlined,
                    size: 25,
                    color: const Color(0xFF898989),
                  ),
                ],
              ),
            ),
            if (_showTextPollDescription)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isGeneratingAiDescription
                    ? null
                    : _generateTextPollDescription,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: AnimatedBuilder(
                    animation: _aiDescriptionController,
                    builder: (context, child) {
                      if (!_isGeneratingAiDescription) {
                        return child!;
                      }
                      final double angle =
                          _aiDescriptionController.value * 2 * math.pi;
                      final double scale =
                          1.0 +
                          0.22 *
                              math.sin(
                                _aiDescriptionController.value * 2 * math.pi,
                              );
                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(angle: angle, child: child),
                      );
                    },
                    child: Image.asset(
                      Assets.images.icAssistant.path,
                      height: 16.h,
                      width: 16.w,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_showTextPollDescription) ...[
          SizedBox(height: 8.h),
          SecondryTextfield(
            controller: _textPollDescriptionController,
            hintText:
                AppLocalizations.of(context)?.typedescriptionorhashtags ??
                'Type description or hashtags',
            maxLines: 4,
            minLines: 1,
            focusedBorderColor: AppColors.primaryColor,
          ),
        ],
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedPollTabIndex = null;
                  _resetTextPollFields();
                });
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isCreatingTextPoll ? null : _createTextPoll,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: _isCreatingTextPoll
                    ? SizedBox(
                        height: 14.h,
                        width: 14.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create Poll',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePollSection(
    BuildContext context,
    bool isDarkmode,
    AppTextColors txt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.question,
          style: AppTextStyles.cardTitle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13.5.sp,
            color: txt.title,
          ),
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: _imagePollQuestionController,
          hintText: AppLocalizations.of(context)!.pleaseenteraquestion,
          focusedBorderColor: AppColors.primaryColor,
        ),
        SizedBox(height: 12.h),
        Text(
          AppLocalizations.of(context)!.polloptions,
          style: AppTextStyles.cardTitle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13.5.sp,
            color: txt.title,
          ),
        ),
        SizedBox(height: 8.h),
        if (_selectedImagePollImages.isEmpty) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickImagePollImages,
            child: SizedBox(
              width: double.infinity,
              height: 120.h,
              child: CustomPaint(
                painter: DottedBorderPainter(
                  color: AppColors.primaryColor.withOpacity(0.5),
                  strokeWidth: 1.5,
                  gap: 5,
                  borderRadius: AppRadius.card,
                ),
                child: Center(
                  child: Assets.images.addImage.image(
                    height: 25.sp,
                    width: 25.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            AppLocalizations.of(
              context,
            )!.addtwoorfoursimilarimagesegoutfitsplacesfood,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.muted,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _pickImagePollImages,
              icon: const Icon(
                Icons.add,
                size: 18,
                color: AppColors.primaryColor,
              ),
              label: Text(
                AppLocalizations.of(context)!.addoption,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.primaryColor.withOpacity(0.8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
            ),
          ),
        ] else ...[
          Builder(
            builder: (context) {
              final rows = <List<int>>[];
              for (var i = 0; i < _selectedImagePollImages.length; i += 2) {
                rows.add([
                  i,
                  if (i + 1 < _selectedImagePollImages.length) i + 1,
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows.map((row) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          children: [
                            ...row.map((i) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i % 2 == 0 ? 5.w : 0,
                                    left: i % 2 == 1 ? 5.w : 0,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1.4,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.button,
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.file(
                                              _selectedImagePollImages[i],
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 5.h,
                                            right: 5.w,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _removeImagePollImage(i),
                                              child: Container(
                                                width: 22.w,
                                                height: 22.h,
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 14.sp,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (row.length == 1)
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Row(
                          children: [
                            ...row.map((i) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i % 2 == 0 ? 5.w : 0,
                                    left: i % 2 == 1 ? 5.w : 0,
                                  ),
                                  child: i < _imagePollLabelControllers.length
                                      ? SecondryTextfield(
                                          controller:
                                              _imagePollLabelControllers[i],
                                          hintText:
                                              '${AppLocalizations.of(context)!.option} ${i + 1}',
                                          focusedBorderColor:
                                              AppColors.primaryColor,
                                        )
                                      : const SizedBox(),
                                ),
                              );
                            }),
                            if (row.length == 1)
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          if (_selectedImagePollImages.length < _maxImagePollImages) ...[
            SizedBox(height: 4.h),
            Text(
              AppLocalizations.of(
                context,
              )!.addtwoorfoursimilarimagesegoutfitsplacesfood,
              style: AppTextStyles.bodyText.copyWith(
                color: txt.muted,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _pickImagePollImages,
                icon: const Icon(
                  Icons.add,
                  size: 18,
                  color: AppColors.primaryColor,
                ),
                label: Text(
                  AppLocalizations.of(context)!.addoption,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.primaryColor.withOpacity(0.8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ),
          ],
        ],
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedPollTabIndex = null;
                });
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // UI only action
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  AppLocalizations.of(context)!.addpoll,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBattlePollSection(
    BuildContext context,
    bool isDarkmode,
    AppTextColors txt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.question,
          style: AppTextStyles.cardTitle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13.5.sp,
            color: txt.title,
          ),
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: _battlePollQuestionController,
          hintText: AppLocalizations.of(context)!.pleaseenteraquestion,
          focusedBorderColor: AppColors.primaryColor,
        ),
        SizedBox(height: 12.h),
        Text(
          AppLocalizations.of(context)!.competitors,
          style: AppTextStyles.cardTitle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13.5.sp,
            color: txt.title,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildBattleCompetitorCard(
                index: 0,
                controller: _battlePollLabel1Controller,
                isDarkmode: isDarkmode,
                txt: txt,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildBattleCompetitorCard(
                index: 1,
                controller: _battlePollLabel2Controller,
                isDarkmode: isDarkmode,
                txt: txt,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          AppLocalizations.of(context)!.addtwosimilarimagesegoutfitsplacesfood,
          style: AppTextStyles.bodyText.copyWith(
            color: txt.muted,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedPollTabIndex = null;
                });
              },
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // UI only action
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  AppLocalizations.of(context)!.addpoll,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBattleCompetitorCard({
    required int index,
    required TextEditingController controller,
    required bool isDarkmode,
    required AppTextColors txt,
  }) {
    final bool hasImage = _selectedBattlePollImages[index] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!hasImage) {
              _pickBattlePollImage(index);
            }
          },
          child: AspectRatio(
            aspectRatio: 1.3,
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            _selectedBattlePollImages[index]!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 5.h,
                          right: 5.w,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _removeBattlePollImage(index),
                            child: Container(
                              width: 22.w,
                              height: 22.h,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomPaint(
                    painter: DottedBorderPainter(
                      color: AppColors.primaryColor.withOpacity(0.5),
                      strokeWidth: 1.5,
                      gap: 5,
                      borderRadius: AppRadius.card,
                    ),
                    child: Center(
                      child: Assets.images.addImage.image(
                        height: 25.sp,
                        width: 25.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.2),
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(height: 8.h),
        SecondryTextfield(
          controller: controller,
          hintText: AppLocalizations.of(context)!.addlabel,
          focusedBorderColor: AppColors.primaryColor,
        ),
      ],
    );
  }

  Widget _buildBody() {
    final txt = AppTextColors.of(context);

    if (posts.isEmpty && (_isRestoringCache || isLoading || isInitialLoad)) {
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

    if (posts.isEmpty && !_isRestoringCache && !isLoading && !isInitialLoad) {
      return const Center(child: Text('No posts available'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          fetchHomeFeed(),
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).loadUserDataSilently(force: true),
        ]);
      },
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
            if (isLoading || isInitialLoad) {
              return Center(
                child: Loader(color: Theme.of(context).colorScheme.onPrimary),
              );
            }
            return ListView(
              children: [
                SizedBox(height: 200.h),
                const Center(child: Text('No posts available')),
              ],
            );
          }

          return ListView.builder(
            key: const PageStorageKey<String>('dashboard_home_feed_list'),
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

              if (index == 0) {
                return Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    // 6-hour poll timer check:
                    // If a poll was created within 6 hours, hide index == 0 (show only HomeFeedPostCard).
                    // After 6 hours have passed, show index == 0.
                    if (userProvider.isPollHideTimerActive) {
                      return HomeFeedPostCard(
                        key: ValueKey(currentPosts[index].id),
                        post: currentPosts[index],
                        onPressed: () {},
                      );
                    }
                    final txt = AppTextColors.of(context);
                    final isDarkmode =
                        Theme.of(context).brightness == Brightness.dark;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedEntrance(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              padding: const EdgeInsets.all(10).w,
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
                                    )!.curiouswhatpeoplethink,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.subText.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onBackground,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.askitgetrealopinionsfromthecrowd,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.subText.copyWith(
                                      color: txt.body,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  if (_selectedPollTabIndex == 0) ...[
                                    SizedBox(height: 12.h),
                                    _buildTextPollSection(
                                      context,
                                      isDarkmode,
                                      txt,
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedPollTabIndex = 0;
                                              });
                                            },
                                            child: Container(
                                              height: 40,
                                              padding: EdgeInsets.fromLTRB(
                                                10.w,
                                                0,
                                                6.w,
                                                0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDarkmode
                                                    ? const Color(
                                                        0xFF292628,
                                                      ).withValues(alpha: 0.95)
                                                    : Colors.white.withValues(
                                                        alpha: 0.92,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                                border: Border.all(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isDarkmode
                                                        ? Colors.black
                                                              .withValues(
                                                                alpha: 0.15,
                                                              )
                                                        : const Color(
                                                            0xFF9B3046,
                                                          ).withValues(
                                                            alpha: 0.04,
                                                          ),
                                                    blurRadius: 7,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              alignment: Alignment.centerLeft,
                                              child: _AnimatedTypewriterHint(
                                                style: AppTextStyles.subText
                                                    .copyWith(
                                                      color: isDarkmode
                                                          ? const Color(
                                                              0xFF9F999B,
                                                            )
                                                          : const Color(
                                                              0xFF9E9E9E,
                                                            ),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedPollTabIndex = 0;
                                            });
                                          },
                                          child: Container(
                                            height: 40,
                                            width: 110,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.outline,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.createpoll,
                                              style: AppTextStyles.subText
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildPollTab(
                                            index: 0,
                                            icon: Assets.images.icTextPoll.path,
                                            title: AppLocalizations.of(
                                              context,
                                            )!.textpoll,
                                            isDarkmode: isDarkmode,
                                            txt: txt,
                                            bg: const Color(0x1AC026D3),
                                            darkBg: const Color(0x33C026D3),
                                            onTap: () {
                                              setState(() {
                                                _selectedPollTabIndex = 0;
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: _buildPollTab(
                                            index: 1,
                                            icon:
                                                Assets.images.icImagePoll.path,
                                            title: AppLocalizations.of(
                                              context,
                                            )!.imagepoll,
                                            isDarkmode: isDarkmode,
                                            txt: txt,
                                            bg: const Color(0x1ADE42AA),
                                            darkBg: const Color(0x33DE42AA),
                                            onTap: () {
                                              navigationPush(
                                                context,
                                                const NewImagePoll(),
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: _buildPollTab(
                                            index: 2,
                                            icon: Assets.images.icBattel.path,
                                            title: AppLocalizations.of(
                                              context,
                                            )!.battlepoll,
                                            isDarkmode: isDarkmode,
                                            txt: txt,
                                            bg: const Color(0x1ADC2626),
                                            darkBg: const Color(0x33DC2626),
                                            onTap: () {
                                              navigationPush(
                                                context,
                                                const NewBattelPoll(),
                                              );
                                            },
                                          ),
                                        ),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: _showMorePollsDialog,
                                          child: Container(
                                            height: 30,
                                            width: 40,
                                            margin: EdgeInsets.only(left: 5.w),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 5.w,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer,
                                              borderRadius:
                                                  const BorderRadius.all(
                                                    Radius.circular(5),
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.keyboard_arrow_down,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        HomeFeedPostCard(
                          key: ValueKey(currentPosts[index].id),
                          post: currentPosts[index],
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
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
                    const PollTopics(),
                    const SizedBox(height: 15),
                  ],
                );
              }

              // Suggested users at index 6
              if (index == 11) {
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


class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  const _AnimatedEntrance({required this.child});

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  static bool hasAnimatedOnce = false;
  late final bool _shouldAnimate;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _shouldAnimate = !hasAnimatedOnce;
    if (_shouldAnimate) {
      hasAnimatedOnce = true;
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      );

      _fadeAnimation = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      );

      _slideAnimation =
          Tween<Offset>(
            begin: const Offset(0.0, 0.25),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

      _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_shouldAnimate) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

class _AnimatedTypewriterHint extends StatefulWidget {
  final TextStyle style;
  const _AnimatedTypewriterHint({required this.style});

  @override
  State<_AnimatedTypewriterHint> createState() =>
      _AnimatedTypewriterHintState();
}

class _AnimatedTypewriterHintState extends State<_AnimatedTypewriterHint> {
  static const List<String> _pollQuestionsHints = [
    'Best street food in town?',
    'Beach trip or mountain getaway?',
    'Which movie should I watch next?',
    'Coffee or tea?',
    'What’s your perfect weekend plan?',
    'Which city would you visit again?',
    'Best comfort food?',
    'Early bird or night owl?',
    'Which song is on repeat?',
    'Dine out or order in?',
    'Which season do you enjoy most?',
    'Android or iPhone?',
    'Which sport is most exciting to watch?',
    'What’s your dream travel destination?',
    'Agree or disagree: less is more?',
  ];

  static const String _initialHint = "What's on your mind?";

  String _currentText = _initialHint;
  int _lastIndex = -1;
  Timer? _pauseTimer;
  Timer? _charTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _scheduleNextChange();
  }

  void _scheduleNextChange() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _startTypingNextQuestion();
    });
  }

  void _startTypingNextQuestion() {
    // Pick next question randomly (not sequential, different from last)
    int nextIndex = _random.nextInt(_pollQuestionsHints.length);
    if (_pollQuestionsHints.length > 1 && nextIndex == _lastIndex) {
      nextIndex =
          (nextIndex + 1 + _random.nextInt(_pollQuestionsHints.length - 1)) %
          _pollQuestionsHints.length;
    }
    _lastIndex = nextIndex;
    final targetText = _pollQuestionsHints[nextIndex];

    // Delete current text with backspace animation, then type new question
    _charTimer?.cancel();
    _charTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentText.isNotEmpty) {
        setState(() {
          _currentText = _currentText.substring(0, _currentText.length - 1);
        });
      } else {
        timer.cancel();
        // Type the target text character by character (writing animation)
        int charIndex = 0;
        _charTimer = Timer.periodic(const Duration(milliseconds: 40), (
          typeTimer,
        ) {
          if (!mounted) {
            typeTimer.cancel();
            return;
          }
          if (charIndex < targetText.length) {
            charIndex++;
            setState(() {
              _currentText = targetText.substring(0, charIndex);
            });
          } else {
            typeTimer.cancel();
            _scheduleNextChange();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _charTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
