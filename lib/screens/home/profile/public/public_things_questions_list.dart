// ignore_for_file: deprecated_member_use, must_be_immutable, unused_field

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/services/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_card.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/utils/bottomsheet_util.dart';

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

  Future<List<PublicPost>>? _postsFuture;
  Map<String, int?> selectedOptions =
      {}; // Track selected poll options for all polls

  // Maps to track like states and counts for each post
  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};

  List<PublicPost>? cachedPosts;

  @override
  void initState() {
    super.initState();
    _postsFuture = Future.value(<PublicPost>[]);
  }

  Future<void> _toggleLike(int postId) async {
    // Get current state from our tracking maps
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    // Optimistically update UI
    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;

      // Also update the cached post model
      if (cachedPosts != null) {
        final postIndex = cachedPosts!.indexWhere((post) => post.id == postId);
        if (postIndex != -1) {
          cachedPosts![postIndex] = PublicPost(
            id: cachedPosts![postIndex].id,
            user: cachedPosts![postIndex].user,
            description: cachedPosts![postIndex].description,
            createdAt: cachedPosts![postIndex].createdAt,
            images: cachedPosts![postIndex].images,
            polls: cachedPosts![postIndex].polls,
            comments: cachedPosts![postIndex].comments,
            isLiked: !currentLikeState,
            likesCount: currentLikeState
                ? currentLikeCount - 1
                : currentLikeCount + 1,
          );
        }
      }
    });

    try {
      // Call the LikeService
      final result = await likeService.togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );

      // Update UI with server response
      setState(() {
        postLikeStates[postId] = result.isLiked;
        postLikeCounts[postId] = result.likesCount;

        // Update the cached post model with server response
        if (cachedPosts != null) {
          final postIndex = cachedPosts!.indexWhere(
            (post) => post.id == postId,
          );
          if (postIndex != -1) {
            cachedPosts![postIndex] = PublicPost(
              id: cachedPosts![postIndex].id,
              user: cachedPosts![postIndex].user,
              description: cachedPosts![postIndex].description,
              createdAt: cachedPosts![postIndex].createdAt,
              images: cachedPosts![postIndex].images,
              polls: cachedPosts![postIndex].polls,
              comments: cachedPosts![postIndex].comments,
              isLiked: result.isLiked,
              likesCount: result.likesCount,
            );
          }
        }
      });

      // Show error message if operation failed
      if (!result.success) {
        showToast(message: result.message);
      }
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        postLikeStates[postId] = currentLikeState;
        postLikeCounts[postId] = currentLikeCount;

        // Revert the cached post model
        if (cachedPosts != null) {
          final postIndex = cachedPosts!.indexWhere(
            (post) => post.id == postId,
          );
          if (postIndex != -1) {
            cachedPosts![postIndex] = PublicPost(
              id: cachedPosts![postIndex].id,
              user: cachedPosts![postIndex].user,
              description: cachedPosts![postIndex].description,
              createdAt: cachedPosts![postIndex].createdAt,
              images: cachedPosts![postIndex].images,
              polls: cachedPosts![postIndex].polls,
              comments: cachedPosts![postIndex].comments,
              isLiked: currentLikeState,
              likesCount: currentLikeCount,
            );
          }
        }
      });
      showToast(message: 'Failed to update like');
    }
  }

  // Comments Bottom Sheet
  void _showCommentsBottomSheet(int postId) async {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username!,
      onCommentsCountChanged: (newCount) {
        setState(() {
          // Update the cached post model with new comments count
          if (cachedPosts != null) {
            final postIndex = cachedPosts!.indexWhere(
              (post) => post.id == postId,
            );
            if (postIndex != -1) {
              // Create a new comments list with the updated count
              // Since we don't have actual comment objects, we'll create a list with the count
              final updatedComments = List.generate(newCount, (index) => {});

              cachedPosts![postIndex] = PublicPost(
                id: cachedPosts![postIndex].id,
                user: cachedPosts![postIndex].user,
                description: cachedPosts![postIndex].description,
                createdAt: cachedPosts![postIndex].createdAt,
                images: cachedPosts![postIndex].images,
                polls: cachedPosts![postIndex].polls,
                comments: updatedComments,
                isLiked: cachedPosts![postIndex].isLiked,
                likesCount: cachedPosts![postIndex].likesCount,
              );
            }
          }
        });
      },
    );
  }

  String _getCommentsCountText(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  // Helper method to check if any option is selected for a specific poll
  bool isAnyOptionSelected(String pollId) {
    return selectedOptions[pollId] != null;
  }

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
      body: FutureBuilder<List<PublicPost>>(
        future: apiService.fetchPublicPostsPolls(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListView(
                children: [
                  Container(
                    height: 300.h,
                    width: double.infinity,
                    margin: EdgeInsets.only(
                      bottom: 12.h,
                      left: 12.w,
                      right: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  Container(
                    height: 300.h,
                    width: double.infinity,
                    margin: EdgeInsets.only(
                      bottom: 12.h,
                      left: 12.w,
                      right: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  Container(
                    height: 300.h,
                    width: double.infinity,
                    margin: EdgeInsets.only(
                      bottom: 12.h,
                      left: 12.w,
                      right: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[600], size: 50),
                  SizedBox(height: 10.h),
                  Text(
                    'Error loading polls',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data ?? const <PublicPost>[];

          // Cache the posts and initialize tracking maps
          if (cachedPosts == null) {
            cachedPosts = posts;
            for (var post in posts) {
              postLikeStates[post.id] = post.isLiked;
              postLikeCounts[post.id] = post.likesCount;
            }
          }

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 12.h),
                  Text(
                    'No posts with things',
                    style: TextStyle(fontSize: 11.5.sp, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Filter posts that have at least one text-based poll (where all options have text and no images)
          final postsWithTextPolls = posts.where((post) {
            return post.polls.any((poll) {
              return poll.options.every(
                (option) => option.text != null && option.image == null,
              );
            });
          }).toList();

          if (postsWithTextPolls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No active polls found',
                    style: TextStyle(fontSize: 11.5.sp, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            shrinkWrap: true,
            itemCount: postsWithTextPolls.length > 3
                ? 3
                : postsWithTextPolls.length,
            itemBuilder: (context, index) {
              final post = postsWithTextPolls[index];

              // Build card directly
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: CustomCard(
                  widget: Column(
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
                                widget.profileImage != null &&
                                    widget.profileImage!.isNotEmpty
                                ? MemoryImage(
                                    getProfileImage(widget.profileImage)!,
                                  )
                                : null,
                            child:
                                widget.profileImage == null ||
                                    widget.profileImage!.isEmpty
                                ? Text(
                                    widget.username?.isNotEmpty == true
                                        ? widget.username![0].toUpperCase()
                                        : '',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                        ],
                      ),
                      // Build each poll in this post
                      ...post.polls.map(
                        (poll) => _buildPollBlock(poll, post, index),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Build poll block (previously _PublicQuestionsBlock)
  Widget _buildPollBlock(PublicPoll poll, PublicPost post, int postIndex) {
    final pollId = poll.id.toString();
    final isSelected = isAnyOptionSelected(pollId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5.h),
        Text(
          poll.question,
          style: TextStyle(
            color: Colors.black,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
        ...poll.options.map(
          (option) => _buildPollOption(poll, poll.options.indexOf(option)),
        ),
        SizedBox(height: 5.h),
        Row(
          children: [
            // Like button
            GestureDetector(
              onTap: () => _toggleLike(post.id),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: (postLikeStates[post.id] ?? post.isLiked)
                        ? Image.asset(
                            Assets.assetsImagesIcHeartFilled,
                            key: ValueKey('filled_${post.id}'),
                            height: 23.h,
                            width: 23.w,
                          )
                        : Image.asset(
                            Assets.assetsImagesIcHeart,
                            key: ValueKey('outline_${post.id}'),
                            height: 23.h,
                            width: 23.w,
                            color: const Color(0xFFC6C5C5),
                          ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    (postLikeCounts[post.id] ?? post.likesCount) > 0
                        ? LikeService.getLikesCountText(
                            postLikeCounts[post.id] ?? post.likesCount,
                          )
                        : '',
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
              onTap: () => _showCommentsBottomSheet(post.id),
              child: Row(
                children: [
                  Icon(
                    FeatherIcons.messageSquare,
                    size: 21.sp,
                    color: const Color(0xFFC6C5C5),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    post.comments.isNotEmpty
                        ? _getCommentsCountText(post.comments.length)
                        : '',
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
        ),
        // Animated analytics button
        Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isSelected ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(top: isSelected ? 10.h : 0),
              height: isSelected ? 45.h : 0,
              width: isSelected ? 45.w : 0,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFCF4B73), Color(0xFFC76294)],
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.3),
                          blurRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: GestureDetector(
                onTap: isSelected
                    ? () {
                        // Handle analytics button tap
                        debugPrint(
                          'Analytics button tapped for poll: ${poll.id}',
                        );
                        int? selectedIndex = selectedOptions[pollId];
                        if (selectedIndex != null) {
                          debugPrint(
                            'Selected option: ${poll.options[selectedIndex].text}',
                          );
                        }
                      }
                    : null,
                child: Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: isSelected ? 22.spMax : 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build individual poll option
  Widget _buildPollOption(PublicPoll poll, int optionIndex) {
    final option = poll.options[optionIndex];
    final percentage = option.percentage;
    final pollId = poll.id.toString();
    final isSelected = selectedOptions[pollId] == optionIndex;

    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Container(
          height: 25.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 1.5.w,
                  )
                : Border.all(color: Colors.grey.withOpacity(0.3), width: 1.w),
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
      ),
    );
  }
}
