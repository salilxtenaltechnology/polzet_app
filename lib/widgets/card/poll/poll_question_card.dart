// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../core/constants/app_images.dart';
import '../../../models/polls/poll_question_model.dart';
import '../../../models/posts/post_polls_model.dart';
import '../../../widgets/show_toast.dart';
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

  final PostPolls post;
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
        padding: EdgeInsets.all(10).w,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.post.polls.map(
              (p) => _thigsQuestionsBloc(p, widget.post, context),
            ),
            // Add Like and Comment section at the bottom
            SizedBox(height: 8.h),
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
                duration: Duration(milliseconds: 200),
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
                        color: Color(0xFFC6C5C5),
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
        SizedBox(width: 12.w),
        // Comments button
        GestureDetector(
          onTap: widget.onCommentsIconTap,
          child: Row(
            children: [
              Icon(
                FeatherIcons.messageSquare,
                size: 21.sp,
                color: Color(0xFFC6C5C5),
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

  Widget _thigsQuestionsBloc(
    PollQuestion pollQuestion,
    final PostPolls post,
    BuildContext context,
  ) {
    final ApiService apiService = ApiService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
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
                  widget.username!,
                  style: TextStyle(
                    fontSize: 12.8.sp,
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
            Spacer(),
            GestureDetector(
              onTap: () {
                if (kDebugMode) {
                  print('ID : ${post.id}');
                }
                showUserDeletePostDiolog(context, () async {
                  Navigator.pop(context);
                  await apiService.userDeletePost(post.id);
                  widget.onDelete(post.id);
                });
              },
              child: Icon(Icons.more_vert, size: 17.spMax),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        Text(
          pollQuestion.question, //  post.description,
          style: TextStyle(
            color: Colors.black,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 8.h),
        ...pollQuestion.options.map(
          (option) => _buildPollOption(
            pollQuestion,
            pollQuestion.totalVotesCount,
            context,
            pollQuestion.options.indexOf(option),
          ),
        ),
        Text(
          '${pollQuestion.totalVotesCount} votes',
          style: TextStyle(
            fontSize: 10.7.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPollOption(
    final PollQuestion pollQuestion,
    int totalVotes,
    BuildContext context,
    int optionIndex,
  ) {
    final option = pollQuestion.options[optionIndex];

    // Parse vote count from String to int
    final voteCount = option.voteCountInt;

    // Calculate percentage
    final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100) : 0;

    // Define different gradient colors for dynamic options
    List<Color> getGradientColors(int index) {
      final colors = [
        [Color(0xFFFC3E7E), Color(0xFFEEA0F0)], // Option 1
        [Color(0xFF4FC3F7), Color(0xFFB6E2F8)], // Option 2
        [Colors.red, Color(0xFFEFB0C3)], // Option 3
        [Colors.green, Colors.teal], // Option 4
        [Colors.orange, Colors.deepOrange], // Option 5
        [Colors.purple, Colors.deepPurple], // Option 6
      ];
      return colors[index % colors.length];
    }

    final gradientColors = getGradientColors(optionIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                option.displayText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            voteCount == 0
                ? Text('')
                : Text(
                    '$voteCount ${voteCount == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          height: 8.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: Stack(
              children: [
                if (percentage > 0)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      height: 8.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
