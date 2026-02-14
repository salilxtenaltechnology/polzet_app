// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../core/constants/app_images.dart';
import '../../../models/like/like_uers_model.dart';
import '../../../models/posts/user_post_model.dart';
import '../../show_toast.dart';
import '../../base64/image_convert.dart';
import '../../diolog/custom_diolog.dart';
import '../../utils/bottomsheet_util.dart';
import '../../utils/like_util.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize with current state or default from post
    isLiked = widget.currentLikeState ?? widget.post.isLiked;
    likesCount = widget.currentLikesCount ?? widget.post.likesCount;
    commentsCount = widget.currentCommentsCount ?? widget.post.commentsCount;
    likedUsers = widget.currentLikedUsers ?? [];
  }

  @override
  void didUpdateWidget(ThingsQustionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state when parent updates
    if (widget.currentLikeState != null) {
      isLiked = widget.currentLikeState!;
    }
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

  // Silently fetch liked users without clearing existing data (prevents flickering)
  Future<void> _fetchLikedUsersSilently() async {
    try {
      final users = await ApiService().fetchLikedUsers(widget.post.id);
      
      if (mounted) {
        setState(() {
          likedUsers = users.take(3).toList(); // Only keep first 3 for display
        });
        
        // Notify parent of the update
        widget.onLikedUsersUpdated?.call(widget.post.id, users.take(3).toList());
      }
    } catch (e) {
      debugPrint('Error silently fetching liked users for post ${widget.post.id}: $e');
    }
  }

  Future<void> _toggleLike() async {
    final currentLikeState = isLiked;
    final currentLikeCount = likesCount;

    // Optimistically update UI
    setState(() {
      isLiked = !currentLikeState;
      likesCount = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;
    });

    try {
      // Call the LikeService
      final result = await likeService.togglePostLike(
        context: context,
        postId: widget.post.id,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );

      // Update UI with server response
      setState(() {
        isLiked = result.isLiked;
        likesCount = result.likesCount;
      });

      // Notify parent to update its tracking
      widget.onLikeChanged(widget.post.id, result.isLiked, result.likesCount);

      // Silently refresh liked users in background without clearing current data
      if (result.likesCount > 0) {
        _fetchLikedUsersSilently();
      } else {
        // Remove liked users if no likes left
        setState(() {
          likedUsers = [];
        });
        widget.onLikedUsersUpdated?.call(widget.post.id, []);
      }

      // Show error message if operation failed
      if (!result.success) {
        showToast(message: result.message);
      }
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        isLiked = currentLikeState;
        likesCount = currentLikeCount;
      });
      showToast(message: 'Failed to update like');
    }
  }

  // Show Liked Users Bottom Sheet
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
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.post.polls.map(
              (p) => _thingsQuestionsBlock(
                p,
                context,
              ),
            ),
            _buildInteractionSection(),
            if (likesCount > 0 && likedUsers.isNotEmpty) ...[
              GestureDetector(
                onTap: _showLikedUsersBottomSheet,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
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
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionSection() {
    return Row(
      children: [
        // Like button
        GestureDetector(
          onTap: _toggleLike,
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: isLiked
                    ? Image.asset(
                        Assets.assetsImagesIcHeartFilled,
                        key: ValueKey('filled_${widget.post.id}'),
                        height: 21.h,
                        width: 21.w,
                      )
                    : Image.asset(
                        Assets.assetsImagesIcHeart,
                        key: ValueKey('outline_${widget.post.id}'),
                        height: 21.h,
                        width: 21.w,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
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
              Icon(
                FeatherIcons.messageSquare,
                size: 20.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
          onTap: () {
            // ShareService.sharePost(widget.post, context: context);
          },
          child: Icon(
            FeatherIcons.send,
            size: 18.3.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

    // Parse total votes from String to int
    final totalVotes = int.tryParse(pollQuestion.totalVotes) ?? 0;

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
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
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
        // FIXED: Added null check for options
        if (pollQuestion.options != null)
          ...pollQuestion.options!.asMap().entries.map(
            (entry) => _buildPollOption(
              pollQuestion.options![entry.key],
              totalVotes,
              context,
              entry.key,
            ),
          ),
      ],
    );
  }

  Widget _buildPollOption(
    UserPollOption option,
    int totalVotes,
    BuildContext context,
    int optionIndex,
  ) {
    final percentage = option.percentage;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        height: 23.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF30353D)
                : const Color(0xFFE8E8E8),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Progress bar background
            if (percentage > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: percentage / 100),
                  builder: (context, value, child) {
                    return FractionallySizedBox(
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
                    );
                  },
                ),
              ),
            // Content overlay
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Option text
                  Expanded(
                    child: Text(
                      option.text ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Percentage
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.6),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
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