// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/api_config.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/feather_icons_compat.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/cache/poll_topics_cache.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/poll/poll_topic_model.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/image/app_cached_network_image.dart';
import '../../../widgets/shimmer/topic_card_shimmer.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import '../new poll/type/new_anonymous_poll.dart';
import '../new poll/type/new_battel_poll.dart';
import '../new poll/type/new_hot_take_poll.dart';
import '../new poll/type/new_image_poll.dart';
import '../new poll/type/new_text_poll.dart';
import '../new poll/type/new_this_or_that.dart';

class PollIdeas extends StatefulWidget {
  const PollIdeas({super.key});

  @override
  State<PollIdeas> createState() => _PollIdeasState();
}

class _PollIdeasState extends State<PollIdeas>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;
  List<PollTopicModel> _allTopics = [];
  bool _isLoading = true;
  bool _isSearchActive = false;
  List<String> _recentSearches = [];
  Set<String> _selectedPollTypes = {};

  static const List<String> _defaultRecents = [
    'AI',
    'Fun Poll',
    'Creative Brainstorming',
    'User Feedback',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: 0);
    _focusNode.addListener(_onFocusChange);
    _loadRecentSearches();

    if (PollTopicsCache.hasCache) {
      _allTopics = PollTopicsCache.topics;
      _isLoading = false;
      if (PollTopicsCache.isExpired) {
        _fetchTopics(silent: true);
      }
    } else {
      _isLoading = true;
      _fetchTopics(silent: false);
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_isSearchActive) {
      setState(() {
        _isSearchActive = true;
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('poll_ideas_recent_searches');
      if (mounted) {
        setState(() {
          if (saved != null) {
            _recentSearches = saved;
          } else {
            _recentSearches = List.from(_defaultRecents);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _removeRecentSearch(String item) async {
    setState(() {
      _recentSearches.remove(item);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('poll_ideas_recent_searches', _recentSearches);
  }

  Future<void> _clearAllRecentSearches() async {
    setState(() {
      _recentSearches.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('poll_ideas_recent_searches', []);
  }

  Future<void> _addRecentSearch(String item) async {
    final query = item.trim();
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 20) {
        _recentSearches = _recentSearches.sublist(0, 20);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('poll_ideas_recent_searches', _recentSearches);
  }

  Future<void> _fetchTopics({bool silent = false}) async {
    if (!silent && _allTopics.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final feedTopics = await PollTopicsCache.loadTopics(
        forceRefresh: !silent && !PollTopicsCache.hasCache,
      );
      if (mounted) {
        setState(() {
          _allTopics = feedTopics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching poll topics feed in PollIdeas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<PollTopicModel> _getTopicsForCategory(String categorySlug) {
    return _allTopics
        .where(
          (t) =>
              t.categorySlug?.trim().toLowerCase() ==
              categorySlug.toLowerCase(),
        )
        .toList();
  }

  List<PollTopicModel> _getFilteredTopics(String query) {
    final q = query.trim().toLowerCase();
    return _allTopics.where((topic) {
      if (q.isNotEmpty) {
        final question = topic.question.toLowerCase();
        final badge = (topic.badgeLabel ?? '').toLowerCase();
        final pollType = topic.pollType.toLowerCase();
        final category = (topic.categoryTitle ?? '').toLowerCase();
        final matchesText =
            question.contains(q) ||
            badge.contains(q) ||
            pollType.contains(q) ||
            category.contains(q);
        if (!matchesText) return false;
      }

      if (_selectedPollTypes.isNotEmpty) {
        final pType = topic.pollType.toLowerCase();
        final badge = (topic.badgeLabel ?? '').toLowerCase();

        bool matchesType = false;
        for (final filter in _selectedPollTypes) {
          final fLower = filter.toLowerCase();
          if (fLower.contains('text') &&
              (pType.contains('text') || badge.contains('text'))) {
            matchesType = true;
            break;
          } else if (fLower.contains('image') &&
              (pType.contains('image') || badge.contains('image'))) {
            matchesType = true;
            break;
          } else if ((fLower.contains('battle') || fLower.contains('battel')) &&
              (pType.contains('battle') ||
                  pType.contains('battel') ||
                  badge.contains('battle') ||
                  badge.contains('battel'))) {
            matchesType = true;
            break;
          } else if (fLower.contains('anon') &&
              (pType.contains('anon') || badge.contains('anon'))) {
            matchesType = true;
            break;
          } else if ((fLower.contains('this') || fLower.contains('that')) &&
              (pType.contains('this') ||
                  pType.contains('that') ||
                  badge.contains('this') ||
                  badge.contains('that'))) {
            matchesType = true;
            break;
          } else if ((fLower.contains('hot') || fLower.contains('take')) &&
              (pType.contains('hot') ||
                  pType.contains('take') ||
                  badge.contains('hot') ||
                  badge.contains('take'))) {
            matchesType = true;
            break;
          }
        }
        if (!matchesType) return false;
      }

      return true;
    }).toList();
  }

  void _showFilterBottomSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final filterOptions = [
      {'name': 'Text Poll', 'icon': Assets.images.icTextPoll.path},
      {'name': 'Image Poll', 'icon': Assets.images.icImagePoll.path},
      {'name': 'Battle Poll', 'icon': Assets.images.icBattel.path},
      {'name': 'Anonymous Poll', 'icon': Assets.images.icAnonymous.path},
      {'name': 'This or That', 'icon': Assets.images.icThisThat.path},
      {'name': 'Hot Takes Poll', 'icon': Assets.images.icHot.path},
    ];

    Set<String> tempSelected = Set.from(_selectedPollTypes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 4.h),
                    Center(
                      child: Container(
                        width: 55.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white24
                              : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Center(
                      child: Text(
                        'Filter',
                        style: AppTextStyles.subText.copyWith(
                          color: txt.title,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...filterOptions.map((opt) {
                      final name = opt['name']!;
                      final icon = opt['icon']!;
                      final isSelected = tempSelected.contains(name);

                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              tempSelected.remove(name);
                            } else {
                              tempSelected.add(name);
                            }
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 9.5,
                          ),
                          child: Row(
                            children: [
                              Image.asset(icon, width: 19.r, height: 19.r),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: txt.title,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                width: 19.r,
                                height: 19.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryColor
                                        : (isDarkMode
                                              ? Colors.white38
                                              : const Color(0xFF9CA3AF)),
                                    width: 1.2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: isSelected
                                    ? Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    // SizedBox(height: 16.h),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 10.h, 10.w, 10.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPollTypes.clear();
                              });
                              Navigator.pop(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              AppLocalizations.of(context)!.clearall,
                              style: const TextStyle(
                                color: Color(0xFFF43F5E),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPollTypes = Set.from(tempSelected);
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 25.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onTopicTap(BuildContext context, PollTopicModel topic) {
    final lower = topic.pollType.toLowerCase();
    if (lower.contains('image')) {
      navigationPush(
        context,
        NewImagePoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('battle') || lower.contains('battel')) {
      navigationPush(
        context,
        NewBattelPoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('this') || lower.contains('that')) {
      navigationPush(
        context,
        NewThisOrThat(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('hot') || lower.contains('take')) {
      navigationPush(
        context,
        NewHotTakePoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('anon')) {
      navigationPush(
        context,
        NewAnonymousPoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else {
      navigationPush(
        context,
        NewTextPoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    }
  }

  String _getPollTypeIcon(PollTopicModel topic) {
    if (topic.pollTypeIcon != null && topic.pollTypeIcon!.isNotEmpty) {
      return topic.pollTypeIcon!;
    }
    final lower = topic.pollType.toLowerCase();
    if (lower.contains('image')) {
      return Assets.images.icImagePoll.path;
    } else if (lower.contains('battle') || lower.contains('battel')) {
      return Assets.images.icBattel.path;
    } else if (lower.contains('this') || lower.contains('that')) {
      return Assets.images.icThisThat.path;
    } else if (lower.contains('hot')) {
      return Assets.images.icHot.path;
    } else if (lower.contains('anon')) {
      return Assets.images.icAnonymous.path;
    }
    return Assets.images.icTextPoll.path;
  }

  Color _getPollTypeBadgeColor(BuildContext context, PollTopicModel topic) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (topic.pollTypeColor != null) {
      return topic.pollTypeColor!;
    }
    final lower = topic.pollType.toLowerCase();
    if (lower.contains('image')) {
      return isDarkMode ? const Color(0x33DE42AA) : const Color(0x1ADE42AA);
    } else if (lower.contains('battle') || lower.contains('battel')) {
      return isDarkMode ? const Color(0x33DC2626) : const Color(0x1ADC2626);
    } else if (lower.contains('this') || lower.contains('that')) {
      return isDarkMode ? const Color(0x3316A34A) : const Color(0x1E16A34A);
    } else if (lower.contains('hot')) {
      return isDarkMode ? const Color(0x33EA580C) : const Color(0x1AEA580C);
    } else if (lower.contains('anon')) {
      return isDarkMode ? const Color(0x337C3AED) : const Color(0x1A7C3AED);
    }
    return isDarkMode ? const Color(0x33C026D3) : const Color(0x1AC026D3);
  }

  String _getPollTypeLabel(BuildContext context, PollTopicModel topic) {
    final lower = topic.pollType.toLowerCase();
    final l10n = AppLocalizations.of(context)!;
    if (lower.contains('image')) {
      return l10n.imagepoll;
    } else if (lower.contains('battle') || lower.contains('battel')) {
      return l10n.battlepoll;
    } else if (lower.contains('this') || lower.contains('that')) {
      return l10n.thisorthat;
    } else if (lower.contains('hot')) {
      return l10n.hottakespoll;
    } else if (lower.contains('anon')) {
      return l10n.anonymouspoll;
    }
    return l10n.textpoll;
  }

  String _resolveBannerUrl(String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) return '';

    final baseUrl = ApiConfig.baseUrlImage.replaceAll(RegExp(r'/$'), '');
    String url = value.replaceAll('BASE_URL', baseUrl);

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '$baseUrl/${url.replaceFirst(RegExp(r'^/'), '')}';
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '';
    }

    return uri.toString();
  }

  Widget _buildTopicImage(String bannerImageUrl) {
    final imageUrl = _resolveBannerUrl(bannerImageUrl);

    if (imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }

    return AppCachedNetworkImage(
      imageUrl: imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildImagePlaceholder(),
      errorWidget: (context, url, error) => _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: Colors.grey),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, PollTopicModel topic) {
    final txt = AppTextColors.of(context);
    final iconPath = _getPollTypeIcon(topic);
    final badgeBgColor = _getPollTypeBadgeColor(context, topic);

    return GestureDetector(
      onTap: () => _onTopicTap(context, topic),
      child: Container(
        padding: const EdgeInsets.all(10),
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
            // Poll Type Badge
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(iconPath, height: 16, width: 16),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _getPollTypeLabel(context, topic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: txt.title,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Topic Image
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 98,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _buildTopicImage(topic.bannerImageUrl),
              ),
            ),
            const SizedBox(height: 10),

            // Poll Question
            SizedBox(
              height: 38,
              child: Text(
                topic.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Create Poll Button
            GestureDetector(
              onTap: () => _onTopicTap(context, topic),
              child: Container(
                height: 34,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                alignment: Alignment.center,
                child: Text(
                  AppLocalizations.of(context)!.createpoll,
                  style: AppTextStyles.bodyText.copyWith(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsGrid(List<PollTopicModel> topics) {
    if (_isLoading && _allTopics.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          mainAxisExtent: 252.0,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerTopicCard(),
      );
    }

    if (topics.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Text(
          'No topics available',
          style: AppTextStyles.bodyText.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 14,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        mainAxisExtent: 252.0,
      ),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        return _buildTopicCard(context, topics[index]);
      },
    );
  }

  Widget _buildRecentsView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    if (_recentSearches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Text(
              AppLocalizations.of(context)!.recents,
              style: AppTextStyles.subText.copyWith(
                color: txt.title,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.norecentsearches,
                style: AppTextStyles.bodyText.copyWith(
                  color: isDarkMode ? Colors.white60 : txt.muted,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 4.h),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
               AppLocalizations.of(context)!.recents,
                style: AppTextStyles.subText.copyWith(
                  color: txt.title,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _clearAllRecentSearches,
                behavior: HitTestBehavior.opaque,
                child: Text(
                AppLocalizations.of(context)!.clearall,
                  style: TextStyle(
                    color: const Color(0xFFF43F5E),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        ..._recentSearches.map((item) {
          return InkWell(
            onTap: () {
              _searchController.text = item;
              _addRecentSearch(item);
              _focusNode.unfocus();
              setState(() {});
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.2.h),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.access_time_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.title,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeRecentSearch(item),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.all(6.r),
                      child: Icon(
                        Icons.close,
                        size: 17.5.sp,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSearchResultsView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final query = _searchController.text.trim();
    final results = _getFilteredTopics(query);
    if (results.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 200),
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
              _selectedPollTypes.isNotEmpty
                  ? '${AppLocalizations.of(context)!.notopicsfoundfor} "$query" ${AppLocalizations.of(context)!.withselectedfilters}'
                  : '${AppLocalizations.of(context)!.notopicsfoundfor} "$query"',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionHeading.copyWith(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 15),
            Text(
             AppLocalizations.of(context)!.tryanotherkeywordorexploretrendingpolls,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return _buildTopicsGrid(results);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    return PopScope(
      canPop: !_isSearchActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSearchActive) {
          _focusNode.unfocus();
          _searchController.clear();
          setState(() {
            _isSearchActive = false;
            _selectedPollTypes.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          showBackButton: true,
          title: AppLocalizations.of(context)!.pollideas,
          onBack: () {
            if (_isSearchActive) {
              _focusNode.unfocus();
              _searchController.clear();
              setState(() {
                _isSearchActive = false;
                _selectedPollTypes.clear();
              });
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 43,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF1F1F23)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        cursorColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                        cursorWidth: 1.5,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.only(
                            right: 12.w,
                            left: 12.w,
                            top: 10.h,
                          ),
                          hintText: AppLocalizations.of(
                            context,
                          )!.searchpolltopics,
                          hintStyle: AppTextStyles.bodyText.copyWith(
                            color: const Color(0XFF898989),
                            fontWeight: FontWeight.w400,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            FeatherIcons.search,
                            size: 17.spMax,
                            color: const Color(0XFF898989),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _focusNode.unfocus();
                                    _searchController.clear();
                                    setState(() {
                                      _isSearchActive = false;
                                      _selectedPollTypes.clear();
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0XFF898989),
                                  ),
                                )
                              : null,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                              width: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          color: txt.title,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        onTap: () {
                          if (!_isSearchActive) {
                            setState(() {
                              _isSearchActive = true;
                            });
                          }
                        },
                        onChanged: (value) {
                          setState(() {});
                        },
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _addRecentSearch(value.trim());
                          }
                        },
                      ),
                    ),
                  ),
                  if (_searchController.text.trim().isNotEmpty) ...[
                    GestureDetector(
                      onTap: _showFilterBottomSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.only(left: 7.w, right: 4.w),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              Assets.images.icPreference.path,
                              height: 26,
                              width: 26,
                              color: _selectedPollTypes.isNotEmpty
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : txt.body,
                            ),
                            if (_selectedPollTypes.isNotEmpty)
                              Positioned(
                                right: -6,
                                top: -5,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 16.5,
                                    minHeight: 16.5,
                                  ),
                                  padding: EdgeInsets.all(2.r),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${_selectedPollTypes.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isSearchActive) ...[
              SizedBox(
                height: 33.h,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  labelPadding: EdgeInsets.symmetric(horizontal: 12.w),
                  controller: _tabController,
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: FadeUnderlineTabIndicator(),
                  labelColor: Theme.of(context).colorScheme.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  dividerColor: Colors.transparent,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onBackground,
                  tabs: [
                    Tab(text: AppLocalizations.of(context)!.foryou),
                    Tab(text: AppLocalizations.of(context)!.dailylife),
                    Tab(text: AppLocalizations.of(context)!.food),
                    Tab(text: AppLocalizations.of(context)!.travel),
                    Tab(text: AppLocalizations.of(context)!.tech),
                    Tab(text: AppLocalizations.of(context)!.entertainment),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTopicsGrid(_allTopics),
                    _buildTopicsGrid(
                      _getTopicsForCategory('ideas-for-daily-life'),
                    ),
                    _buildTopicsGrid(_getTopicsForCategory('ideas-for-food')),
                    _buildTopicsGrid(_getTopicsForCategory('ideas-for-travel')),
                    _buildTopicsGrid(
                      _getTopicsForCategory('ideas-for-tech-ai'),
                    ),
                    _buildTopicsGrid(
                      _getTopicsForCategory('ideas-for-entertainment'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: _searchController.text.trim().isEmpty
                    ? _buildRecentsView()
                    : _buildSearchResultsView(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
