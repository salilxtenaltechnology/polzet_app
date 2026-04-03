// ignore_for_file: deprecated_member_use, must_be_immutable, unused_field

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../api/services/api_service.dart';
import '../../../../../api/services/like/like_service.dart';
import '../../../../../core/constants/app_images.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../models/like/like_uers_model.dart';
import '../../../../../models/public/public_profile_model.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/button/back_button.dart';
import '../../../../../widgets/custom_card.dart';
import '../../../../../widgets/custom_text_styles.dart';
import '../../../../../widgets/show_toast.dart';
import '../../../../../widgets/utils/bottomsheet_util.dart';
import '../../../../../widgets/utils/like_util.dart';

class PublicThingsQuestionsList extends StatefulWidget {
  String? username;
  String? profileImage;
  int userId;

  PublicThingsQuestionsList({
    super.key,
    required this.userId,
    required this.username,
    required this.profileImage,
  });

  @override
  State<PublicThingsQuestionsList> createState() =>
      _PublicThingsQuestionsListState();
}

class _PublicThingsQuestionsListState extends State<PublicThingsQuestionsList> {
  late final ApiService apiService = ApiService();
  late final LikeService likeService = LikeService();

  // ── Poll selection state ───────────────────────────────────────────────────
  // Key: pollId.toString(), Value: ordered list of selected option indices
  Map<String, List<int>> selectedOptions = {};
  Map<String, bool> pollVotingStates = {};
  // Mutable polled state per poll (key: pollId.toString())
  Map<String, bool> pollPolledStates = {};

  // ── Like / comment tracking ────────────────────────────────────────────────
  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};
  Map<int, int> postCommentsCounts = {};
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};

  final Map<int, double> pollPercentages = {};

  List<PublicPost>? cachedPosts;

  // ── Poll helpers ───────────────────────────────────────────────────────────

  bool _areAllPollOptionsSelected(PublicPoll poll) {
    final pollKey = poll.id.toString();
    if (!selectedOptions.containsKey(pollKey)) return false;
    final validCount = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .length;
    return selectedOptions[pollKey]!.length == validCount;
  }

  int? _getSelectionNumber(String pollKey, int optionIndex) {
    final selected = selectedOptions[pollKey];
    if (selected == null || !selected.contains(optionIndex)) return null;
    return selected.indexOf(optionIndex) + 1;
  }

  void _toggleOption(String pollKey, int optionIndex) {
    setState(() {
      selectedOptions.putIfAbsent(pollKey, () => []);
      if (selectedOptions[pollKey]!.contains(optionIndex)) {
        selectedOptions[pollKey]!.remove(optionIndex);
      } else {
        selectedOptions[pollKey]!.add(optionIndex);
      }
    });
  }

  Future<void> _submitPollVotes(PublicPoll poll, int postId) async {
    final pollKey = poll.id.toString();
    if (pollVotingStates[pollKey] == true) return;

    final previousSelected = List<int>.from(selectedOptions[pollKey] ?? []);

    // ── Step 1: Show spinner only — nothing else changes ──
    setState(() => pollVotingStates[pollKey] = true);

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < previousSelected.length; i++) {
        final option = poll.options[previousSelected[i]];
        votes.add({'option_id': option.id, 'rank': i + 1});
      }

      final result = await ApiService.voteOnPollMultiple(
        postId: postId,
        votes: votes,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // ── Step 2: Fetch real percentages — writes pollPercentages, no setState inside ──
        await _fetchPollResults(postId);

        if (!mounted) return;

        // ── Step 3: One setState reveals everything with real percentages — no 0% flash ──
        setState(() {
          pollVotingStates[pollKey] = false;
          selectedOptions[pollKey] = [];
          pollPolledStates[pollKey] =
              true; // ← flipped AFTER percentages are ready
        });

        showToast(message: 'Vote submitted successfully!');
      } else {
        setState(() {
          pollVotingStates[pollKey] = false;
          selectedOptions[pollKey] = previousSelected;
          // pollPolledStates unchanged — user hasn't voted
        });
        showToast(message: result['message'] ?? 'Failed to submit votes.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        pollVotingStates[pollKey] = false;
        selectedOptions[pollKey] = previousSelected;
        // pollPolledStates unchanged — revert silently
      });
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  Future<void> _fetchPollResultsAndRefresh(PublicPoll poll, int postId) async {
    await _fetchPollResults(postId);
    if (mounted) setState(() {});
  }

  // Writes ONLY into pollPercentages — never calls setState.
  // Caller owns the setState.
  Future<void> _fetchPollResults(int postId) async {
    try {
      final Map<String, dynamic> response = await ApiService().getPollResults(
        postId,
      );

      if (!mounted) return;
      if (response['status'] != 'success') return;

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final List<dynamic> results = data['results'] as List<dynamic>? ?? [];

      for (final dynamic item in results) {
        final r = item as Map<String, dynamic>;
        final int optionId = r['option_id'] as int;
        final double pct = (r['percentage'] as num?)?.toDouble() ?? 0.0;
        // Write directly — no setState, caller owns the setState
        pollPercentages[optionId] = pct;
      }
    } catch (e) {
      debugPrint('Error fetching poll results: $e');
    }
  }

  void _showThingsPostVotersBottomSheet(PublicPoll poll, int postId) {
    poll.options.sort((a, b) => b.percentage.compareTo(a.percentage));
    BottomSheetUtils.showPublicUserThingsPostBottomSheet(
      context: context,
      poll: poll,
      postId: postId,
    );
  }

  void _updateOptionPercentage(
    int postId,
    int pollId,
    int optionId,
    double pct,
  ) {
    if (cachedPosts == null) return;
    final postIdx = cachedPosts!.indexWhere((p) => p.id == postId);
    if (postIdx == -1) return;

    final post = cachedPosts![postIdx];
    final updatedPolls = post.polls.map((poll) {
      if (poll.id != pollId) return poll;
      final updatedOptions = poll.options.map((opt) {
        if (opt.id != optionId) return opt;
        return PublicPollOption(
          id: opt.id,
          text: opt.text,
          image: opt.image,
          voteCount: opt.voteCount,
          percentage: pct,
          voters: opt.voters,
        );
      }).toList();
      return PublicPoll(
        id: poll.id,
        question: poll.question,
        maxOptions: poll.maxOptions,
        options: updatedOptions,
        totalVotes: poll.totalVotes,
        userVote: poll.userVote,
      );
    }).toList();

    cachedPosts![postIdx] = PublicPost(
      id: post.id,
      user: post.user,
      description: post.description,
      createdAt: post.createdAt,
      images: post.images,
      polls: updatedPolls,
      comments: post.comments,
      likesCount: post.likesCount,
      isLiked: post.isLiked,
      is_polled_by_current_user: post.is_polled_by_current_user,
    );
  }

  // void _revertPollState(
  //   String pollKey,
  //   bool previousPolled,
  //   List<int> previousSelected,
  //   PublicPoll poll,
  //   List<double> previousPercentages,
  //   int postId,
  // ) {
  //   if (!mounted) return;
  //   setState(() {
  //     pollPolledStates[pollKey] = previousPolled;
  //     pollVotingStates[pollKey] = false;
  //     selectedOptions[pollKey] = previousSelected;
  //     // Revert percentages
  //     for (int i = 0; i < poll.options.length; i++) {
  //       if (i < previousPercentages.length) {
  //         _updateOptionPercentage(
  //           postId,
  //           poll.id,
  //           poll.options[i].id,
  //           previousPercentages[i],
  //         );
  //       }
  //     }
  //   });
  // }

  // ── Like helpers ───────────────────────────────────────────────────────────

  Future<void> _fetchLikedUsers(int postId) async {
    if (likedUsersLoading[postId] == true ||
        postLikedUsers.containsKey(postId)) {
      return;
    }
    setState(() => likedUsersLoading[postId] = true);
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (mounted) {
        setState(() {
          postLikedUsers[postId] = users.take(3).toList();
          likedUsersLoading[postId] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => likedUsersLoading[postId] = false);
    }
  }

  Future<void> _fetchLikedUsersSilently(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (mounted) {
        setState(() => postLikedUsers[postId] = users.take(3).toList());
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(int postId) async {
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;
    });

    try {
      final result = await likeService.togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );
      if (mounted) {
        setState(() {
          postLikeStates[postId] = result.isLiked;
          postLikeCounts[postId] = result.likesCount;
        });
        if (result.likesCount > 0) {
          _fetchLikedUsersSilently(postId);
        } else {
          setState(() => postLikedUsers.remove(postId));
        }
      }
      if (!result.success && mounted) showToast(message: result.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          postLikeStates[postId] = currentLikeState;
          postLikeCounts[postId] = currentLikeCount;
        });
        showToast(message: 'Failed to update like');
      }
    }
  }

  void _showCommentsBottomSheet(int postId, int currentCommentsCount) {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username!,
      onCommentsCountChanged: (newCount) {
        if (mounted && newCount != currentCommentsCount) {
          setState(() => postCommentsCounts[postId] = newCount);
        }
      },
    );
  }

  void _showLikedUsersBottomSheet(int postId) {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: postId,
    );
  }

  String _getCommentsCountText(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await apiService.fetchPublicPostsPolls(widget.userId);
      if (mounted) {
        setState(() {
          cachedPosts = posts;
          for (var post in posts) {
            postLikeStates[post.id] = post.isLiked;
            postLikeCounts[post.id] = post.likesCount;
            postCommentsCounts[post.id] = post.comments.length;
            for (var poll in post.polls) {
              pollPolledStates[poll.id.toString()] =
                  post.is_polled_by_current_user;
            }
          }
        });

        // ── Fetch real percentages for already-voted posts ──
        for (var post in posts) {
          if (post.is_polled_by_current_user) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              for (final poll in post.polls) {
                _fetchPollResultsAndRefresh(poll, post.id);
              }
            });
          }
          if (post.likesCount > 0 && !likedUsersLoading.containsKey(post.id)) {
            _fetchLikedUsers(post.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) setState(() => cachedPosts = []);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.pollthings,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (cachedPosts == null) return _buildShimmerLoading();

    final postsWithTextPolls = cachedPosts!.where((post) {
      return post.polls.any((poll) {
        return poll.options.every(
          (option) => option.text != null && option.image == null,
        );
      });
    }).toList();

    if (postsWithTextPolls.isEmpty) {
      return _buildEmptyState('No active polls found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: postsWithTextPolls.length,
      itemBuilder: (context, index) {
        return _buildPostCard(postsWithTextPolls[index]);
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        children: List.generate(
          3,
          (index) => Container(
            height: 300.h,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12.h, left: 12.w, right: 12.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(fontSize: 11.5.sp, color: Colors.grey),
      ),
    );
  }

  Widget _buildPostCard(PublicPost post) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: CustomCard(
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            ...post.polls.map((poll) => _buildPollBlock(poll, post)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.15),
          backgroundImage:
              widget.profileImage != null && widget.profileImage!.isNotEmpty
              ? MemoryImage(getProfileImage(widget.profileImage)!)
              : null,
          child: widget.profileImage == null || widget.profileImage!.isEmpty
              ? Text(
                  widget.username?.isNotEmpty == true
                      ? widget.username![0].toUpperCase()
                      : '',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.username!,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            Text(
              'Placed a post',
              style: TextStyle(
                fontSize: 8.8.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPollBlock(PublicPoll poll, PublicPost post) {
    final pollKey = poll.id.toString();
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasUserPolled = pollPolledStates[pollKey] ?? false;
    final areAllSelected = _areAllPollOptionsSelected(poll);
    final isVoting = pollVotingStates[pollKey] ?? false;

    // Only show text-based options
    final textOptions = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .toList();

    if (textOptions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5.h),
        Text(
          poll.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 10.7.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 7.h),

        // ── Options ────────────────────────────────────────────────────
        ...poll.options.asMap().entries.map((entry) {
          final option = entry.value;
          if (option.text == null || option.text!.isEmpty) {
            return const SizedBox.shrink();
          }
          return _buildPollOption(
            option,
            entry.key,
            pollKey,
            isDarkMode,
            hasUserPolled,
          );
        }),

        // ── Submit button ──────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: !hasUserPolled && areAllSelected
              ? GestureDetector(
                  key: ValueKey('poll_btn_${poll.id}'),
                  onTap: isVoting
                      ? null
                      : () => _submitPollVotes(poll, post.id),
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
                      child: Icon(
                        Icons.stacked_bar_chart,
                        color: Colors.white,
                        size: 20.spMax,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (hasUserPolled) ...[
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showThingsPostVotersBottomSheet(poll, post.id),
                child: Text(
                  'View votes',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],

        SizedBox(height: 7.h),
        _buildPostActions(post),
      ],
    );
  }

  Widget _buildPollOption(
    PublicPollOption option,
    int optionIndex,
    String pollKey,
    bool isDarkMode,
    bool hasUserPolled,
  ) {
    // ✅ Read ONLY from pollPercentages — never option.percentage
    final double pct = pollPercentages[option.id] ?? 0.0;
    final int pctRounded = pct.round();

    final isSelected = selectedOptions[pollKey]?.contains(optionIndex) ?? false;
    final int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: hasUserPolled ? null : () => _toggleOption(pollKey, optionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 10.h),
        height: 23.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected && !hasUserPolled
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : isDarkMode
                ? const Color(0xFF30353D)
                : const Color(0xFFE8E8E8),
            width: isSelected && !hasUserPolled ? 1.2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // ── Progress bar ──────────────────────────────────────────────
            if (hasUserPolled && pctRounded > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bar_${pollKey}_${option.id}_$pctRounded'),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: pctRounded / 100),
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF30353D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Content row ───────────────────────────────────────────────
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
                  if (hasUserPolled)
                    TweenAnimationBuilder<int>(
                      key: ValueKey('pct_${pollKey}_${option.id}_$pctRounded'),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      tween: IntTween(begin: 0, end: pctRounded),
                      builder: (context, value, _) => Text(
                        '$value%',
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

  Widget _buildPostActions(PublicPost post) {
    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = postCommentsCounts[post.id] ?? post.comments.length;
    final viewLikes = postLikedUsers[post.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _toggleLike(post.id),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: isLiked
                        ? Image.asset(
                            Assets.assetsImagesIcHeartFilled,
                            key: ValueKey('filled_${post.id}'),
                            height: 21.h,
                            width: 21.w,
                          )
                        : Image.asset(
                            Assets.assetsImagesIcHeart,
                            key: ValueKey('outline_${post.id}'),
                            height: 21.h,
                            width: 21.w,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    likesCount > 0
                        ? LikeService.getLikesCountText(likesCount)
                        : '',
                    style: TextStyle(
                      fontSize: 10.8.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => _showCommentsBottomSheet(post.id, commentsCount),
              child: Row(
                children: [
                  Icon(
                    FeatherIcons.messageSquare,
                    size: 20.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    commentsCount > 0
                        ? _getCommentsCountText(commentsCount)
                        : '',
                    style: TextStyle(
                      fontSize: 10.8.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              FeatherIcons.send,
              size: 18.3.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
        if (likesCount > 0 && viewLikes.isNotEmpty) ...[
          SizedBox(height: 5.h),
          GestureDetector(
            onTap: () => _showLikedUsersBottomSheet(post.id),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LikeUtils.buildLikeAvatarsStack(
                  context,
                  viewLikes,
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
                          viewLikes,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
