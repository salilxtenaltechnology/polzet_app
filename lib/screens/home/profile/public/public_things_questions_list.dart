// ignore_for_file: deprecated_member_use, must_be_immutable, unused_field

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/services/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_card.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/utils/bottomsheet_util.dart';
import '../../../../widgets/utils/like_util.dart';

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

  Map<String, int?> selectedOptions = {};

  // Maps to track like states and counts for each post
  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};

  // Track comments count for each post
  Map<int, int> postCommentsCounts = {};

  // Track liked users for each post (fetched on-demand)
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};

  List<PublicPost>? cachedPosts;

  @override
  void initState() {
    super.initState();
  }

  // Fetch liked users for a specific post
  Future<void> _fetchLikedUsers(int postId) async {
    // Don't fetch if already loading or already loaded
    if (likedUsersLoading[postId] == true || postLikedUsers.containsKey(postId)) {
      return;
    }

    setState(() {
      likedUsersLoading[postId] = true;
    });

    try {
      final users = await ApiService().fetchLikedUsers(postId);
      
      if (mounted) {
        setState(() {
          postLikedUsers[postId] = users.take(3).toList(); // Only keep first 3 for display
          likedUsersLoading[postId] = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching liked users for post $postId: $e');
      if (mounted) {
        setState(() {
          likedUsersLoading[postId] = false;
        });
      }
    }
  }

  // Silently fetch liked users without clearing existing data (prevents flickering)
  Future<void> _fetchLikedUsersSilently(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      
      if (mounted) {
        setState(() {
          postLikedUsers[postId] = users.take(3).toList(); // Only keep first 3 for display
        });
      }
    } catch (e) {
      debugPrint('Error silently fetching liked users for post $postId: $e');
    }
  }

  Future<void> _toggleLike(int postId) async {
    // Get current state from our tracking maps
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    // Optimistically update UI - single setState
    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;
    });

    try {
      // Call the LikeService
      final result = await likeService.togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );

      // Update with server response
      if (mounted) {
        setState(() {
          postLikeStates[postId] = result.isLiked;
          postLikeCounts[postId] = result.likesCount;
        });

        // Silently refresh liked users in background without clearing current data
        if (result.likesCount > 0) {
          _fetchLikedUsersSilently(postId);
        } else {
          // Remove liked users if no likes left
          setState(() {
            postLikedUsers.remove(postId);
          });
        }
      }

      // Show error message if operation failed
      if (!result.success && mounted) {
        showToast(message: result.message);
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          postLikeStates[postId] = currentLikeState;
          postLikeCounts[postId] = currentLikeCount;
        });
        showToast(message: 'Failed to update like');
      }
    }
  }

  // Comments Bottom Sheet
  void _showCommentsBottomSheet(int postId, int currentCommentsCount) async {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username!,
      onCommentsCountChanged: (newCount) {
        // Silent update - only if count actually changed
        if (mounted && newCount != currentCommentsCount) {
          setState(() {
            postCommentsCounts[postId] = newCount;
            
            if (cachedPosts != null) {
              final postIndex = cachedPosts!.indexWhere(
                (post) => post.id == postId,
              );
              if (postIndex != -1) {
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
        }
      },
    );
  }

  // Show Liked Users Bottom Sheet
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

  bool isAnyOptionSelected(String pollId) {
    return selectedOptions[pollId] != null;
  }

  @override
  Widget build(BuildContext context) {
    // Only fetch once if not cached
    if (cachedPosts == null) {
      _loadPosts();
    }

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

  // Separate method to load posts
  Future<void> _loadPosts() async {
    try {
      final posts = await apiService.fetchPublicPostsPolls(widget.userId);
      
      if (mounted) {
        setState(() {
          cachedPosts = posts;
          // Initialize tracking maps
          for (var post in posts) {
            postLikeStates[post.id] = post.isLiked;
            postLikeCounts[post.id] = post.likesCount;
            postCommentsCounts[post.id] = post.comments.length;
          }
        });

        // Fetch liked users after state is set
        for (var post in posts) {
          if (post.likesCount > 0 && !likedUsersLoading.containsKey(post.id)) {
            _fetchLikedUsers(post.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() {
          cachedPosts = []; // Set empty to show error state
        });
      }
    }
  }

  Widget _buildBody() {
    // Show loading shimmer only on initial load
    if (cachedPosts == null) {
      return _buildShimmerLoading();
    }

    // Show empty state if no posts
    if (cachedPosts!.isEmpty) {
      return _buildEmptyState('No posts with things');
    }

    // Filter posts that have at least one text-based poll
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
      itemCount: postsWithTextPolls.length > 3 ? 3 : postsWithTextPolls.length,
      itemBuilder: (context, index) {
        final post = postsWithTextPolls[index];
        return _buildPostCard(post, index);
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
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(fontSize: 11.5.sp, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PublicPost post, int index) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: CustomCard(
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            ...post.polls.map(
              (poll) => _buildPollBlock(poll, post, index),
            ),
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
                  ? MemoryImage(
                      getProfileImage(widget.profileImage)!,
                    )
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
                fontSize: 11.5.sp,
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

  Widget _buildPollBlock(PublicPoll poll, PublicPost post, int postIndex) {
    final pollId = poll.id.toString();
    final isSelected = isAnyOptionSelected(pollId);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5.h),
        Text(
          poll.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        ...poll.options.map(
          (option) => _buildPollOption(
            poll, 
            poll.options.indexOf(option),
            isDarkMode,
          ),
        ),
        SizedBox(height: 7.h),
        _buildPostActions(post),
        _buildAnalyticsButton(poll, pollId, isSelected),
      ],
    );
  }

  Widget _buildPostActions(PublicPost post) {
    // Get current states from tracking maps
    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = postCommentsCounts[post.id] ?? post.comments.length;
    final viewLikes = postLikedUsers[post.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
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
            // Comments button
            GestureDetector(
              onTap: () => _showCommentsBottomSheet(post.id, commentsCount),
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                // ShareService.sharePost(post, context: context);
              },
              child: Icon(
                FeatherIcons.send,
                size: 18.3.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        // Liked Users Display - Shows immediately, updates silently
        if (likesCount > 0) ...[
          SizedBox(height: 5.h),
          if (viewLikes.isNotEmpty)
            // Show liked users with avatars and text (updates silently in background)
            GestureDetector(
              onTap: () => _showLikedUsersBottomSheet(post.id),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
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

  Widget _buildAnalyticsButton(PublicPoll poll, String pollId, bool isSelected) {
    return Center(
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
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.3),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
          child: GestureDetector(
            onTap: isSelected
                ? () {
                    debugPrint('Analytics button tapped for poll: ${poll.id}');
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
    );
  }

  Widget _buildPollOption(PublicPoll poll, int optionIndex, bool isDarkMode) {
    final option = poll.options[optionIndex];
    final percentage = option.percentage;
    final pollId = poll.id.toString();
    final isSelected = selectedOptions[pollId] == optionIndex;

    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Container(
          height: 23.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF242831)
                : const Color(0xFFF5F6F7),
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
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 3.h, 8.w, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        option.text ?? '',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.7),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onBackground
                            .withOpacity(0.6),
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
      ),
    );
  }
}