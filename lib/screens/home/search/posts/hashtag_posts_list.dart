// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../api/services/share/share_service.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../models/search/hashtag/hashtag_posts_list_model.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../core/utils/like_util.dart';
import '../../home feed/rank/result/image/image_result_screen.dart';
import 'rank/hashtags_image_poll_ranking.dart';

const _textSecondary = Color(0xFF888888);

class HashtagPostsList extends StatefulWidget {
  final String hashtag;

  const HashtagPostsList({super.key, required this.hashtag});

  @override
  State<HashtagPostsList> createState() => _HashtagPostsListState();
}

class _HashtagPostsListState extends State<HashtagPostsList> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<HashtagPostModel> _posts = [];
  bool _loading = true;
  String? _error;
  String? _nextPage;
  final bool _loadingMore = false;

  final ScrollController _scrollController = ScrollController();

  // Per-post like state
  final Map<int, bool> _likedMap = {};
  final Map<int, int> _likesCountMap = {};
  final Map<int, int> _commentsCountMap = {};
  final Map<int, int> _sharesCountMap = {};
  final Map<int, List<LikeUser>> _likedUsersMap = {};
  final Map<int, bool> _likedUsersLoadingMap = {};

  // Per-poll vote state
  final Map<int, int> _selectedVotes = {}; // pollId -> optionId
  final Map<String, List<int>> _selectedOptions =
      {}; // pollKey -> ordered indices
  final Map<String, bool> _pollVotingStates = {};

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _scrollController.addListener(_onScroll);
  }

  void _showAllImagesGrid(
    int postId,
    HashtagPollModel poll,
    bool isPolledByCurrentUser,
  ) {
    if (isPolledByCurrentUser) {
      // Already voted → show results
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => ImageResultScreen(
                postId: postId.toString(),
                username: _posts
                    .firstWhere((p) => p.id == postId)
                    .user
                    .username,
              ),
            ),
          )
          .then((result) {
            if (result == true) _fetchPosts();
          });
    } else {
      // Not yet polled → open ranking screen
      final post = _posts.firstWhere((p) => p.id == postId);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => HashtagsImagePollRanking(post: post, poll: poll),
            ),
          )
          .then((result) {
            if (result == true) _fetchPosts();
          });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Pagination scroll ──────────────────────────────────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _nextPage != null) {
      // _fetchMorePosts();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService().searchHashtagPosts(widget.hashtag);
      if (!mounted) return;

      _initPostState(result.results);

      setState(() {
        // _posts = result.results.where((p) => p.polls.isNotEmpty).toList();
        _posts = result.results;
        _nextPage = result.next;
      });

      for (final post in result.results) {
        _fetchLikedUsers(post.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initPostState(List<HashtagPostModel> posts) {
    for (final post in posts) {
      _likedMap[post.id] = post.isLikedByCurrentUser;
      _likesCountMap[post.id] = post.likesCount;
      _commentsCountMap[post.id] = post.commentsCount;
      _sharesCountMap[post.id] = post.sharesCount;

      for (final poll in post.polls) {
        if (poll.isPolledByCurrentUser) {
          if (poll.options.isNotEmpty) {
            _selectedVotes[poll.id] = poll.options.first.id;
          }
        }
      }
    }
  }

  Future<void> _fetchLikedUsers(int postId) async {
    if (_likedUsersLoadingMap[postId] == true ||
        _likedUsersMap.containsKey(postId)) {
      return;
    }

    setState(() => _likedUsersLoadingMap[postId] = true);
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (!mounted) return;
      setState(() {
        _likedUsersMap[postId] = users.take(3).toList();
        _likedUsersLoadingMap[postId] = false;
      });
    } catch (_) {
      if (mounted) setState(() => _likedUsersLoadingMap[postId] = false);
    }
  }

  Future<void> _refreshLikedUsersQuietly(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (!mounted) return;
      setState(() => _likedUsersMap[postId] = users.take(3).toList());
    } catch (_) {}
  }

  // ── Like ───────────────────────────────────────────────────────────────────
  Future<void> _toggleLike(int postId) async {
    final prev = _likedMap[postId] ?? false;
    final prevCount = _likesCountMap[postId] ?? 0;

    setState(() {
      _likedMap[postId] = !prev;
      _likesCountMap[postId] = prev ? prevCount - 1 : prevCount + 1;
    });

    try {
      // await LikeService().togglePostLike(postId: postId);
      await _refreshLikedUsersQuietly(postId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _likedMap[postId] = prev;
          _likesCountMap[postId] = prevCount;
        });
      }
    }
  }

  // ── Image popup ────────────────────────────────────────────────────────────
  // void _showAllImagesGrid(
  //   int postId,
  //   HashtagPollModel poll,
  //   bool isPolledByCurrentUser,
  // ) {
  //   Navigator.of(context)
  //       .push(
  //         MaterialPageRoute(
  //           builder: (_) => SinglePostImagePopup(
  //             images: poll.options,
  //             postId: postId,
  //             pollId: poll.id,
  //             onImageTap: (_) {},
  //             isPolledByCurrentUser: isPolledByCurrentUser,
  //           ),
  //         ),
  //       )
  //       .then((result) {
  //         if (result == true) _fetchPosts();
  //       });
  // }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    try {
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      if (diff.inDays < 7) return '${diff.inDays} d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
      return '${(diff.inDays / 365).floor()} y ago';
    } catch (_) {
      return '';
    }
  }

  Uint8List? _decodeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(
        raw.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''),
      );
    } catch (_) {
      return null;
    }
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrlImage}$path';
  }

  String _formatCount(int count) {
    if (count <= 0) return '';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  bool _isImagePoll(HashtagPostModel post) =>
      post.polls.isNotEmpty &&
      post.polls.first.options.any((o) => o.image != null);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: widget.hashtag),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    if (_error != null) return _buildError();

    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'No posts found for #${widget.hashtag}',
          style: TextStyle(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onPrimary,
      onRefresh: _fetchPosts,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(12.h),
                child: Loader(color: Theme.of(context).colorScheme.onPrimary),
              ),
            );
          }
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  // ── Post card ──────────────────────────────────────────────────────────────
  Widget _buildPostCard(HashtagPostModel post) {
    final isImage = _isImagePoll(post);
    final isLiked = _likedMap[post.id] ?? false;
    final likesCount = _likesCountMap[post.id] ?? 0;
    final commentsCount = _commentsCountMap[post.id] ?? 0;
    final sharesCount = _sharesCountMap[post.id] ?? 0;
    final likedUsers = _likedUsersMap[post.id] ?? [];

    return Container(
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
          _buildHeader(post),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),

          // Description (image polls only)
          if (isImage && (post.description ?? '').isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 10.h),
              child: Text(
                post.description!,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ),
          ],

          // Polls
          ...post.polls.map(
            (poll) => isImage
                ? _buildImagePollBlock(poll, post.id)
                : _buildTextPollBlock(poll),
          ),

          const SizedBox(height: 10),

          // Interaction bar
          _buildInteractionBar(
            post: post,
            isLiked: isLiked,
            likesCount: likesCount,
            commentsCount: commentsCount,
            sharesCount: sharesCount,
          ),

          // Liked users avatars + text
          if (likesCount > 0 && likedUsers.isNotEmpty) ...[
            SizedBox(height: 4.h),
            GestureDetector(
              onTap: () => BottomSheetUtils.showLikedUsersBottomSheet(
                context: context,
                postId: post.id,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LikeUtils.buildLikeAvatarsStack(
                      context,
                      likedUsers,
                      avatarSize: 15,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: SizedBox(
                        height: 20.h,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: LikeUtils.buildLikedByRichText(
                              context,
                              likedUsers,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(HashtagPostModel post) {
    final txt = AppTextColors.of(context);
    final avatarBytes = _decodeBase64(post.user.profileImage);

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.1),
            backgroundImage: avatarBytes != null
                ? MemoryImage(avatarBytes)
                : null,
            child: avatarBytes == null
                ? Text(
                    post.user.username.isNotEmpty
                        ? post.user.username[0].toUpperCase()
                        : 'P',
                    style: AppTextStyles.subText.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${post.user.firstName} ${post.user.lastName}'.trim().isNotEmpty
                    ? '${post.user.firstName} ${post.user.lastName}'.trim()
                    : post.user.username,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: txt.title,
                ),
              ),
              Row(
                children: [
                  Text(
                    post.user.username.isNotEmpty
                        ? '@${post.user.username}'
                        : '${post.user.firstName} ${post.user.lastName}'.trim(),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: txt.body,
                    ),
                  ),
                  Text(
                    '  • ${_timeAgo(DateTime.parse(post.createdAt))}',
                    style: TextStyle(
                      fontSize: 8.8.sp,
                      color: txt.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMAGE POLL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildImagePollBlock(HashtagPollModel poll, int postId) {
    final validImages = poll.options.where((o) => o.image != null).toList();
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final imageHeight = 150.h;

          return GestureDetector(
            onTap: () =>
                _showAllImagesGrid(postId, poll, poll.isPolledByCurrentUser),
            child: SizedBox(
              height: imageHeight,
              width: availableWidth,
              child: Stack(
                children: validImages
                    .asMap()
                    .entries
                    .map<Widget>((entry) {
                      final index = entry.key;
                      final opt = entry.value;
                      final alignment = alignments[index];
                      double imageWidth =
                          (availableWidth * 0.7) - (index * 8.0);
                      imageWidth = imageWidth < 60.w ? 60.w : imageWidth;
                      final imageUrl = opt.image != null
                          ? _resolveUrl(opt.image!.url)
                          : '';

                      return Align(
                        alignment: alignment,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: imageWidth,
                          height: imageHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            value:
                                                progress.expectedTotalBytes !=
                                                    null
                                                ? progress.cumulativeBytesLoaded /
                                                      progress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  )
                                : _imagePlaceholder(),
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

  Widget _imagePlaceholder() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.r),
      color: Colors.grey[200],
    ),
    child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 30),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT POLL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTextPollBlock(HashtagPollModel poll) {
    final pollKey = poll.id.toString();
    final hasUserPolled = _selectedVotes.containsKey(poll.id);
    final isVoting = _pollVotingStates[pollKey] ?? false;
    final areAllSelected = _areAllOptionsSelected(poll);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        ...poll.options.asMap().entries.map(
          (e) => _buildTextOptionRow(
            option: e.value,
            optionIndex: e.key,
            poll: poll,
            showPercentage: hasUserPolled,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: !hasUserPolled && areAllSelected
              ? GestureDetector(
                  key: ValueKey('submit_${poll.id}'),
                  onTap: isVoting ? null : () => _submitTextVote(poll),
                  child: Center(
                    child: Container(
                      margin: EdgeInsets.only(top: 10.h),
                      height: 45.h,
                      width: 45.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFCF4B73), Color(0xFFC76294)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.3),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: isVoting
                          ? Padding(
                              padding: EdgeInsets.all(12.w),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.stacked_bar_chart,
                              color: Colors.white,
                              size: 20.spMax,
                            ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTextOptionRow({
    required HashtagPollOption option,
    required int optionIndex,
    required HashtagPollModel poll,
    required bool showPercentage,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final pollKey = poll.id.toString();
    final hasUserPolled = _selectedVotes.containsKey(poll.id);
    final double percentage = option.percentage;
    final bool isSelected =
        _selectedOptions[pollKey]?.contains(optionIndex) ?? false;
    final int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: hasUserPolled
          ? null
          : () => _toggleTextOption(pollKey, optionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 10.h),
        height: 23.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected && !hasUserPolled
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : isDark
                ? const Color(0xFF30353D)
                : const Color(0xFFE8E8E8),
            width: isSelected && !hasUserPolled ? 1.2 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (showPercentage && percentage > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bar_${poll.id}_${option.id}_$percentage'),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: percentage / 100),
                  builder: (_, value, __) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF30353D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      option.text ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 10.5.sp,
                        fontWeight: isSelected && !hasUserPolled
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showPercentage)
                    TweenAnimationBuilder<int>(
                      key: ValueKey('pct_${poll.id}_${option.id}_$percentage'),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      tween: IntTween(begin: 0, end: percentage.round()),
                      builder: (_, val, __) => Text(
                        '$val%',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.6),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (isSelected)
                    Text(
                      '$selectionNumber',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text-poll helpers ──────────────────────────────────────────────────────
  bool _areAllOptionsSelected(HashtagPollModel poll) {
    final pollKey = poll.id.toString();
    if (!_selectedOptions.containsKey(pollKey)) return false;
    final validCount = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .length;
    return _selectedOptions[pollKey]!.length == validCount;
  }

  int? _getSelectionNumber(String pollKey, int optionIndex) {
    final selected = _selectedOptions[pollKey];
    if (selected == null || !selected.contains(optionIndex)) return null;
    return selected.indexOf(optionIndex) + 1;
  }

  void _toggleTextOption(String pollKey, int optionIndex) {
    setState(() {
      _selectedOptions.putIfAbsent(pollKey, () => []);
      if (_selectedOptions[pollKey]!.contains(optionIndex)) {
        _selectedOptions[pollKey]!.remove(optionIndex);
      } else {
        _selectedOptions[pollKey]!.add(optionIndex);
      }
    });
  }

  Future<void> _submitTextVote(HashtagPollModel poll) async {
    final pollKey = poll.id.toString();
    if (_pollVotingStates[pollKey] == true) return;

    final previousSelected = List<int>.from(_selectedOptions[pollKey] ?? []);

    setState(() {
      _pollVotingStates[pollKey] = true;
      _selectedOptions[pollKey] = [];
    });

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < previousSelected.length; i++) {
        final option = poll.options[previousSelected[i]];
        votes.add({'option_id': option.id, 'rank': i + 1});
      }

      // Wire up vote API when ready:
      // await ApiService().voteOnPollMultiple(votes: votes);

      final firstOptionId = poll.options[previousSelected.first].id;
      setState(() {
        _selectedVotes[poll.id] = firstOptionId;
        _pollVotingStates[pollKey] = false;
      });
      showToast(message: 'Vote submitted successfully!');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pollVotingStates[pollKey] = false;
        _selectedOptions[pollKey] = previousSelected;
      });
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  // ── Interaction bar ────────────────────────────────────────────────────────
  Widget _buildInteractionBar({
    required HashtagPostModel post,
    required bool isLiked,
    required int likesCount,
    required int commentsCount,
    required int sharesCount,
  }) {
    final txt = AppTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Like
          GestureDetector(
            onTap: () => _toggleLike(post.id),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: isLiked
                      ? AppIcons.filledHeart(key: const ValueKey('filled'))
                      : AppIcons.outlineHeart(key: const ValueKey('outline')),
                ),
                const SizedBox(width: 8),
                Text(
                  LikeService.getLikesCountText(likesCount),
                  style: AppTextStyles.subText.copyWith(
                    color: txt.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Comment
          GestureDetector(
            onTap: () => BottomSheetUtils.showCommentsBottomSheet(
              context: context,
              postId: post.id,
              currentUsername: post.user.username,
              onCommentsCountChanged: (count) {
                if (mounted) setState(() => _commentsCountMap[post.id] = count);
              },
            ),
            child: Row(
              children: [
                AppIcons.commnetBox(),
                SizedBox(width: 3.w),
                Text(
                  _formatCount(commentsCount),
                  style: AppTextStyles.subText.copyWith(
                    color: txt.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Share
          GestureDetector(
            onTap: () => ShareService.sharePost(
              post,
              context: context,
              usernameOverride: post.user.username,
              onShareSuccess: (newCount) {
                if (mounted) {
                  setState(() => _sharesCountMap[post.id] = newCount);
                }
              },
            ),
            child: Row(
              children: [
                AppIcons.sharePost(),
                const SizedBox(width: 8),
                Text(
                  _formatCount(sharesCount),
                  style: AppTextStyles.subText.copyWith(
                    color: txt.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: _textSecondary, size: 40.sp),
          SizedBox(height: 12.h),
          Text(
            'Failed to load posts',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _error ?? '',
            style: TextStyle(fontSize: 10.sp, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: _fetchPosts,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
