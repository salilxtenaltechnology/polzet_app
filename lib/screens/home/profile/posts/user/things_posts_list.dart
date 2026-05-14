// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../../api/services/api_service.dart';
import '../../../../../api/services/like/like_service.dart';
import '../../../../../api/services/share/share_service.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../models/like/like_uers_model.dart';
import '../../../../../models/posts/user_post_model.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/dialog/custom_diolog.dart';
import '../../../../../widgets/loader.dart';
import '../../../../../widgets/show_toast.dart';
import '../../../../../core/utils/bottomsheet_util.dart';
import '../../../../../core/utils/like_util.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../rank/things/user_things_ranking.dart';

class ThingsPostsList extends StatefulWidget {
  String? username;
  String? profileImage;

  ThingsPostsList({super.key, required this.username, this.profileImage});

  @override
  State<ThingsPostsList> createState() => QuestionsPostsListState();
}

class QuestionsPostsListState extends State<ThingsPostsList> {
  late final ApiService _apiService = ApiService();

  List<UserPostModel> postsPolls = [];
  bool isLoading = false;
  bool isInitialLoad = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadPosts(showLoader: true);
  }

  Future<void> loadPosts({bool showLoader = false}) async {
    if (widget.username == null || widget.username!.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Username not available';
        });
      }
      return;
    }

    if (showLoader) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final fetched = await _apiService.fetchOnlyPollPosts(widget.username!);
      final filtered = _filterValidPollPosts(fetched);
      if (mounted) {
        setState(() {
          if (!showLoader && postsPolls.isNotEmpty) {
            _mergePostsData(filtered);
          } else {
            postsPolls = filtered;
          }
          isLoading = false;
          isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
          isInitialLoad = false;
        });
      }
    }
  }

  void _mergePostsData(List<UserPostModel> fetchedPosts) {
    Map<int, UserPostModel> fetchedPostsMap = {
      for (var post in fetchedPosts) post.id: post,
    };

    for (int i = 0; i < postsPolls.length; i++) {
      final currentPost = postsPolls[i];
      final fetchedPost = fetchedPostsMap[currentPost.id];

      if (fetchedPost != null) {
        postsPolls[i] = currentPost.copyWith(
          isLiked: fetchedPost.isLiked,
          likesCount: fetchedPost.likesCount,
          is_polled_by_current_user: fetchedPost.is_polled_by_current_user,
          polls: fetchedPost.polls,
        );
        fetchedPostsMap.remove(currentPost.id);
      }
    }

    postsPolls.addAll(fetchedPostsMap.values);
  }

  showThingsPostVotersBottomSheet(UserPollQuestion poll, int currentPostId) {
    final options = poll.options ?? [];
    options.sort((a, b) => b.percentage.compareTo(a.percentage));
    BottomSheetUtils.showCurrenUserThingsPostBottomSheet(
      context: context,
      poll: poll,
      postId: currentPostId,
    );
  }

  List<UserPostModel> _filterValidPollPosts(List<UserPostModel> posts) {
    return posts.where((post) {
      if (post.polls.isEmpty) return false;
      return post.polls.every(
        (poll) =>
            poll.options != null &&
            poll.options!.every((o) => o.text != null && o.text!.isNotEmpty),
      );
    }).toList();
  }

  void _deletePost(int postId) {
    if (mounted) setState(() => postsPolls.removeWhere((p) => p.id == postId));
  }

  void _showCommentsBottomSheet(int postId) {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username ?? '',
      onCommentsCountChanged: (_) {},
    );
  }

  void _handlePostTap(UserPostModel post) {
    if (post.polls.isEmpty) return;
    final poll = post.polls.first;

    if (post.is_polled_by_current_user) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThingsResultScreen(
            username: widget.username ?? '',
            postId: post.id,
          ),
        ),
      );
    } else {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserThingsRanking(
            firstName: userProvider.firstName,
            lastName: userProvider.lastName,
            profileImage: userProvider.profile_picture,
            post: post,
            poll: poll,
          ),
        ),
      ).then((result) {
        if (result == true) {
          setState(() {});
          loadPosts();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.pollthings),

      body: isLoading && isInitialLoad
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : errorMessage != null && postsPolls.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[600], size: 50),
                  SizedBox(height: 16.h),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => loadPosts(showLoader: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : postsPolls.isEmpty && !isLoading
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noactivepollfound,
                style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadPosts,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                itemCount: postsPolls.length,
                itemBuilder: (context, index) {
                  final post = postsPolls[index];
                  return _PollPostCard(
                    onPostTap: () => _handlePostTap(post),
                    key: ValueKey(post.id),
                    post: post,
                    username: widget.username,
                    profileImage: widget.profileImage,
                    onDelete: _deletePost,
                    onCommentsIconTap: () => _showCommentsBottomSheet(post.id),
                    onViewVotesTap: (poll, postId) =>
                        showThingsPostVotersBottomSheet(poll, postId),
                  );
                },
              ),
            ),
    );
  }
}

class _PollPostCard extends StatefulWidget {
  const _PollPostCard({
    super.key,
    required this.post,
    required this.onDelete,
    required this.onCommentsIconTap,
    required this.onViewVotesTap,
    required this.onPostTap,
    this.username,
    this.profileImage,
  });

  final UserPostModel post;
  final String? username;
  final String? profileImage;
  final Function(int postId) onDelete;
  final VoidCallback onCommentsIconTap;
  final Function(UserPollQuestion poll, int postId) onViewVotesTap;
  final VoidCallback onPostTap;

  @override
  State<_PollPostCard> createState() => _PollPostCardState();
}

class _PollPostCardState extends State<_PollPostCard> {
  late final LikeService _likeService = LikeService();

  late bool isLiked = widget.post.isLiked;
  late int likesCount = widget.post.likesCount;
  late int commentsCount = widget.post.commentsCount;
  List<LikeUser> likedUsers = [];

  final Map<String, List<int>> selectedOptions = {};
  final Map<String, bool> pollVotingStates = {};
  final Map<String, bool> pollPolledStates = {};
  final Map<int, double> pollPercentages = {};

  @override
  void initState() {
    super.initState();
    for (final poll in widget.post.polls) {
      pollPolledStates[poll.id.toString()] =
          widget.post.is_polled_by_current_user;
    }
    if (widget.post.likesCount > 0) _fetchLikedUsers();

    if (widget.post.is_polled_by_current_user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final poll in widget.post.polls) {
          _fetchPollResultsAndRefresh(poll);
        }
      });
    }
  }

  bool _areAllOptionsSelected(UserPollQuestion poll) {
    final key = poll.id.toString();
    final selected = selectedOptions[key];
    if (selected == null) return false;
    final validCount =
        poll.options
            ?.where((o) => o.text != null && o.text!.isNotEmpty)
            .length ??
        0;
    return selected.length == validCount;
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

  Future<void> _submitPollVotes(UserPollQuestion poll) async {
    final pollKey = poll.id.toString();
    if (pollVotingStates[pollKey] == true) return;

    final previousSelected = List<int>.from(selectedOptions[pollKey] ?? []);

    setState(() => pollVotingStates[pollKey] = true);

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < previousSelected.length; i++) {
        final option = poll.options![previousSelected[i]];
        votes.add({'option_id': option.id, 'rank': i + 1});
      }

      final result = await ApiService.voteOnPollMultiple(
        postId: widget.post.id,
        votes: votes,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await _fetchPollResults(poll);

        if (!mounted) return;

        setState(() {
          pollVotingStates[pollKey] = false;
          selectedOptions[pollKey] = [];
          pollPolledStates[pollKey] = true;
        });

        showToast(message: 'Vote submitted successfully!');
      } else {
        setState(() {
          pollVotingStates[pollKey] = false;
          selectedOptions[pollKey] = previousSelected;
        });
        showToast(message: result['message'] ?? 'Failed to submit votes.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        pollVotingStates[pollKey] = false;
        selectedOptions[pollKey] = previousSelected;
      });
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  Future<void> _fetchPollResultsAndRefresh(UserPollQuestion poll) async {
    await _fetchPollResults(poll);
    if (mounted) setState(() {});
  }

  Future<void> _fetchPollResults(UserPollQuestion poll) async {
    try {
      final Map<String, dynamic> response = await ApiService().getPollResults(
        widget.post.id,
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
        pollPercentages[optionId] = pct;
      }
    } catch (e) {
      debugPrint('Error fetching poll results: $e');
    }
  }

  Future<void> _fetchLikedUsers() async {
    try {
      final users = await ApiService().fetchLikedUsers(widget.post.id);
      if (mounted) setState(() => likedUsers = users.take(3).toList());
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final prevLike = isLiked;
    final prevCount = likesCount;

    setState(() {
      isLiked = !prevLike;
      likesCount = prevLike ? prevCount - 1 : prevCount + 1;
    });

    try {
      final result = await _likeService.togglePostLike(
        context: context,
        postId: widget.post.id,
        currentLikeState: prevLike,
        currentLikesCount: prevCount,
      );
      if (!mounted) return;
      setState(() {
        isLiked = result.isLiked;
        likesCount = result.likesCount;
      });
      if (result.likesCount > 0) {
        _fetchLikedUsers();
      } else {
        setState(() => likedUsers = []);
      }
      if (!result.success) showToast(message: result.message);
    } catch (_) {
      setState(() {
        isLiked = prevLike;
        likesCount = prevCount;
      });
      showToast(message: 'Failed to update like');
    }
  }

  String _formatCount(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: GestureDetector(
        onTap: widget.onPostTap,

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10).w,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...widget.post.polls.map((p) => _buildPollBlock(p)),
              _buildInteractionRow(),
              if (likesCount > 0 && likedUsers.isNotEmpty)
                GestureDetector(
                  onTap: () => BottomSheetUtils.showLikedUsersBottomSheet(
                    context: context,
                    postId: widget.post.id,
                  ),
                  child: Row(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractionRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _toggleLike,
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: isLiked
                    ? AppIcons.filledHeart(key: const ValueKey('filled'))
                    : AppIcons.outlineHeart(
                        key: const ValueKey('outline'),
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                      ),
              ),
              SizedBox(width: 3.w),
              Text(
                likesCount > 0 ? LikeService.getLikesCountText(likesCount) : '',
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
          onTap: widget.onCommentsIconTap,
          child: Row(
            children: [
              AppIcons.commnetBox(
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.6),
              ),
              SizedBox(width: 3.w),
              Text(
                _formatCount(commentsCount),
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
          onTap: () => ShareService.sharePost(
            widget.post,
            context: context,
            usernameOverride: widget.username,
          ),
          child: AppIcons.sharePost(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPollBlock(UserPollQuestion poll) {
    final pollKey = poll.id.toString();
    final hasUserPolled = pollPolledStates[pollKey] ?? false;
    final areAllSelected = _areAllOptionsSelected(poll);
    final isVoting = pollVotingStates[pollKey] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  widget.username ?? '',
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                showUserDeletePostDiolog(context, () async {
                  Navigator.pop(context);
                  await ApiService().userDeletePost(widget.post.id);
                  widget.onDelete(widget.post.id);
                });
              },
              child: Icon(Icons.more_vert, size: 17.spMax),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        Text(
          poll.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        if (poll.options != null)
          ...poll.options!.asMap().entries.map(
            (entry) => _buildPollOption(
              option: entry.value,
              optionIndex: entry.key,
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
                  key: ValueKey('poll_btn_${poll.id}'),
                  onTap: isVoting ? null : () => _submitPollVotes(poll),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
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

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => widget.onViewVotesTap(poll, widget.post.id),
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
    );
  }

  Widget _buildPollOption({
    required UserPollOption option,
    required int optionIndex,
    required UserPollQuestion poll,
    required bool showPercentage,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pollKey = poll.id.toString();
    final hasUserPolled = pollPolledStates[pollKey] ?? false;
    final double pct = pollPercentages[option.id] ?? 0.0;
    final int pctRounded = pct.round();

    final bool isSelected =
        selectedOptions[pollKey]?.contains(optionIndex) ?? false;
    final int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: hasUserPolled ? null : () => _toggleOption(pollKey, optionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 10.h),
        height: 27.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(AppRadius.button),
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
            if (showPercentage && pctRounded > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bar_${poll.id}_${option.id}_$pctRounded'),
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
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 3.h, 8.w, 0),
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
                      key: ValueKey('pct_${poll.id}_${option.id}_$pctRounded'),
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
}
