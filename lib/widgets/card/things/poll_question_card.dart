// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../models/like/like_uers_model.dart';
import '../../../models/posts/user_post_model.dart';
import '../../dialog/custom_diolog.dart';
import '../../show_toast.dart';
import '../../base64/image_convert.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../../../core/utils/like_util.dart';

class ThingsQustionsCard extends StatefulWidget {
  ThingsQustionsCard({
    super.key,
    required this.post,
    required this.onDelete,
    required this.onLikeChanged,
    required this.onCommentsChanged,
    required this.onCommentsIconTap,
    this.profileImage,
    required this.username,
    this.currentLikeState,
    this.currentLikesCount,
    this.currentCommentsCount,
    this.currentLikedUsers,
    this.onLikedUsersUpdated,
    required this.localPercentages,
    required this.pollPolledStates,
    required this.onPercentagesUpdated,
    required this.onPollPolledStateChanged,
    this.onVoteSuccess,
    required this.onViewVotesTap,
  });

  final UserPostModel post;
  final Function(int postId) onDelete;
  final Function(int postId, bool isLiked, int likesCount) onLikeChanged;
  final Function(int postId, int commentsCount) onCommentsChanged;
  final VoidCallback onCommentsIconTap;
  final bool? currentLikeState;
  final int? currentLikesCount;
  final int? currentCommentsCount;
  final List<LikeUser>? currentLikedUsers;
  final Function(int postId, List<LikeUser> users)? onLikedUsersUpdated;
  String? username;
  String? profileImage;
  final Map<int, double> localPercentages;
  final Map<String, bool> pollPolledStates;
  final Function(Map<int, double> updated) onPercentagesUpdated;
  final Function(String pollKey, bool polled) onPollPolledStateChanged;
  final VoidCallback? onVoteSuccess;
  final Function(UserPollQuestion poll, int postId) onViewVotesTap;
  @override
  State<ThingsQustionsCard> createState() => _ThingsQustionsCardState();
}

class _ThingsQustionsCardState extends State<ThingsQustionsCard> {
  late final LikeService likeService = LikeService();

  // Local state for optimistic updates
  late bool isLiked;
  late int likesCount;
  late int commentsCount;
  late List<LikeUser> likedUsers;

  // Poll selection state - mirrors HomeFeedPostCard logic
  // Key: pollId.toString(), Value: ordered list of selected option indices
  Map<String, List<int>> selectedOptions = {};
  Map<String, bool> pollVotingStates = {};
  // Track is_polled_by_current_user per poll (mutable for optimistic update)

  @override
  void initState() {
    super.initState();
    isLiked = widget.currentLikeState ?? widget.post.isLiked;
    likesCount = widget.currentLikesCount ?? widget.post.likesCount;
    commentsCount = widget.currentCommentsCount ?? widget.post.commentsCount;
    likedUsers = widget.currentLikedUsers ?? [];
  }

  @override
  void didUpdateWidget(ThingsQustionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLikeState != null) isLiked = widget.currentLikeState!;
    if (widget.currentLikesCount != null) {
      likesCount = widget.currentLikesCount!;
    }
    if (widget.currentCommentsCount != null) {
      commentsCount = widget.currentCommentsCount!;
    }
    if (widget.currentLikedUsers != null) {
      likedUsers = widget.currentLikedUsers!;
    }
  }

  bool _areAllPollOptionsSelected(UserPollQuestion poll) {
    final pollKey = poll.id.toString();
    if (!selectedOptions.containsKey(pollKey)) return false;
    final validCount =
        poll.options
            ?.where((o) => o.text != null && o.text!.isNotEmpty)
            .length ??
        0;
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

  Future<void> _submitPollVotes(UserPollQuestion poll) async {
    final pollKey = poll.id.toString();
    if (pollVotingStates[pollKey] == true) return;

    final previousSelected = List<int>.from(selectedOptions[pollKey] ?? []);
    final previousPolled = widget.pollPolledStates[pollKey] ?? false;
    final previousPercentages =
        poll.options
            ?.map((o) => widget.localPercentages[o.id] ?? o.percentage)
            .toList() ??
        [];

    if (!mounted) return;

    setState(() {
      pollVotingStates[pollKey] = true;
      selectedOptions[pollKey] = [];
    });

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
        bool hasApiPercentages = false;
        final responseOptions = result['data']?['options'];
        if (responseOptions is List && responseOptions.isNotEmpty) {
          final Map<int, double> updated = {};
          for (final optionData in responseOptions) {
            if (optionData is! Map) continue;
            final rawId = optionData['option_id'];
            if (rawId == null) continue;
            // Handle both int and num (JSON can decode as either)
            final optionId = rawId is int ? rawId : (rawId as num).toInt();
            final pct = (optionData['percentage'] as num?)?.toDouble() ?? 0.0;
            updated[optionId] = pct;
          }
          if (updated.isNotEmpty) {
            widget.onPercentagesUpdated(updated);
            hasApiPercentages = true;
          }
        }

        setState(() => pollVotingStates[pollKey] = false);

        if (hasApiPercentages) {
          widget.onPollPolledStateChanged(pollKey, true);
        }

        showToast(message: 'Vote submitted successfully!');

        widget.onVoteSuccess?.call();
      } else {
        _revertPollState(
          poll,
          pollKey,
          previousPolled,
          previousSelected,
          previousPercentages,
        );
        showToast(message: result['message'] ?? 'Failed to submit votes.');
      }
    } catch (_) {
      if (!mounted) return;
      _revertPollState(
        poll,
        pollKey,
        previousPolled,
        previousSelected,
        previousPercentages,
      );
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  void _revertPollState(
    UserPollQuestion poll,
    String pollKey,
    bool previousPolled,
    List<int> previousSelected,
    List<double> previousPercentages,
  ) {
    if (!mounted) return;
    widget.onPollPolledStateChanged(pollKey, previousPolled);
    final Map<int, double> reverted = {};
    for (int i = 0; i < (poll.options?.length ?? 0); i++) {
      if (i < previousPercentages.length) {
        reverted[poll.options![i].id] = previousPercentages[i];
      }
    }
    widget.onPercentagesUpdated(reverted);
    setState(() {
      pollVotingStates[pollKey] = false;
      selectedOptions[pollKey] = previousSelected;
    });
  }

  Future<void> _fetchLikedUsersSilently() async {
    try {
      final users = await ApiService().fetchLikedUsers(widget.post.id);
      if (mounted) {
        setState(() => likedUsers = users.take(3).toList());
        widget.onLikedUsersUpdated?.call(
          widget.post.id,
          users.take(3).toList(),
        );
      }
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
      final result = await likeService.togglePostLike(
        context: context,
        postId: widget.post.id,
        currentLikeState: prevLike,
        currentLikesCount: prevCount,
      );
      setState(() {
        isLiked = result.isLiked;
        likesCount = result.likesCount;
      });
      widget.onLikeChanged(widget.post.id, result.isLiked, result.likesCount);

      if (result.likesCount > 0) {
        _fetchLikedUsersSilently();
      } else {
        setState(() => likedUsers = []);
        widget.onLikedUsersUpdated?.call(widget.post.id, []);
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

  void _showLikedUsersBottomSheet() {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: widget.post.id,
    );
  }

  String _getCommentsCountText(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10).w,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppRadius.cardRadius,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.post.polls.map((p) => _thingsQuestionsBlock(p, context)),
            _buildInteractionSection(),
            if (likesCount > 0 && likedUsers.isNotEmpty)
              GestureDetector(
                onTap: _showLikedUsersBottomSheet,
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
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionSection() {
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
                commentsCount > 0 ? _getCommentsCountText(commentsCount) : '',
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
          onTap: () {},
          child: AppIcons.sharePost(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _thingsQuestionsBlock(
    UserPollQuestion pollQuestion,
    BuildContext context,
  ) {
    final ApiService apiService = ApiService();
    final totalVotes = int.tryParse(pollQuestion.totalVotes) ?? 0;
    final pollKey = pollQuestion.id.toString();
    final hasUserPolled = widget.pollPolledStates[pollKey] ?? false;
    final areAllSelected = _areAllPollOptionsSelected(pollQuestion);
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
                  await apiService.userDeletePost(widget.post.id);
                  widget.onDelete(widget.post.id);
                });
              },
              child: Icon(Icons.more_vert, size: 17.spMax),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        Text(
          pollQuestion.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        if (pollQuestion.options != null)
          ...pollQuestion.options!.asMap().entries.map(
            (entry) => _buildPollOption(
              pollQuestion.options![entry.key],
              totalVotes,
              context,
              entry.key,
              pollQuestion,
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
                  key: ValueKey('poll_btn_${pollQuestion.id}'),
                  onTap: isVoting ? null : () => _submitPollVotes(pollQuestion),
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
              onTap: () => widget.onViewVotesTap(pollQuestion, widget.post.id),
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

  Widget _buildPollOption(
    UserPollOption option,
    int totalVotes,
    BuildContext context,
    int optionIndex,
    UserPollQuestion poll, {
    bool showPercentage = false,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pollKey = poll.id.toString();
    final double percentage =
        widget.localPercentages[option.id] ?? option.percentage;
    final hasUserPolled = widget.pollPolledStates[pollKey] ?? false;

    final bool isSelected =
        selectedOptions[pollKey]?.contains(optionIndex) ?? false;
    final int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: hasUserPolled
          ? null 
          : () => _toggleOption(pollKey, optionIndex),
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
            if (showPercentage && percentage > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bar_${poll.id}_${option.id}_$percentage'),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: percentage / 100),
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
                      key: ValueKey('pct_${poll.id}_${option.id}_$percentage'),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      tween: IntTween(begin: 0, end: percentage.round()),
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
                        fontSize: 10.5.sp,
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
