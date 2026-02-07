// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../core/constants/app_images.dart';
import '../../../models/posts/user_post_model.dart';
import '../../show_toast.dart';
import '../../base64/image_convert.dart';
import '../../diolog/custom_diolog.dart';

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
  });

  final UserPostModel
  post; // FIXED: Changed from PostImagesResponse to PostImagesModel
  final Function(int postId) onDelete;
  final Function(int postId, bool isLiked, int likesCount) onLikeChanged;
  final Function(int postId, int commentsCount) onCommentsChanged;
  final VoidCallback onCommentsIconTap;
  final bool? currentLikeState;
  final int? currentLikesCount;
  final int? currentCommentsCount;
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

  @override
  void initState() {
    super.initState();
    // Initialize with current state or default from post
    isLiked = widget.currentLikeState ?? widget.post.isLiked;
    likesCount = widget.currentLikesCount ?? widget.post.likesCount;
    commentsCount = widget.currentCommentsCount ?? widget.post.commentsCount;
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

    // Show error message if operation failed
    if (!result.success) {
      showToast(message: result.message);
    }
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
          color: Theme.of(context).colorScheme.secondaryContainer,
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
              ), // FIXED: Renamed method and changed params
            ),
            _buildInteractionSection(),
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
                        height: 23.h,
                        width: 23.w,
                      )
                    : Image.asset(
                        Assets.assetsImagesIcHeart,
                        key: ValueKey('outline_${widget.post.id}'),
                        height: 23.h,
                        width: 23.w,
                        color: const Color(0xFFC6C5C5),
                      ),
              ),
              SizedBox(width: 3.w),
              Text(
                likesCount > 0 ? LikeService.getLikesCountText(likesCount) : '',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 5.w),
        // Comments button
        GestureDetector(
          onTap: widget.onCommentsIconTap,
          child: Row(
            children: [
              Icon(
                FeatherIcons.messageSquare,
                size: 21.sp,
                color: const Color(0xFFC6C5C5),
              ),
              SizedBox(width: 3.w),
              Text(
                commentsCount > 0 ? _getCommentsCountText(commentsCount) : '',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thingsQuestionsBlock(
    UserPollQuestion
    pollQuestion, // FIXED: Changed from PollQuestion to UserPollQuestion
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
                        fontSize: 18.sp,
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Placed a post',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.black.withOpacity(0.5),
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
            color: Colors.black,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w400,
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
    //final voteCount = int.tryParse(option.voteCount) ?? 0;
    final percentage = option.percentage;
    // Calculate percentage
    // final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100) : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        height: 25.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.w),
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
                          color: const Color(0xFFF0F0F0),
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
                        color: Colors.grey[700],
                        fontSize: 11.2.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  // Percentage
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
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
