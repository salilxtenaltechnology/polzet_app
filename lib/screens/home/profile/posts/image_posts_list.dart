// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../models/posts/user_post_model.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/diolog/custom_diolog.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/utils/bottomsheet_util.dart';
import '../../../../widgets/utils/like_util.dart';
import 'image_grid.dart';

class ImagePostsList extends StatefulWidget {
  String? username;
  String? profileImage;
  ImagePostsList({super.key, required this.username, this.profileImage});

  @override
  State<ImagePostsList> createState() => _ImagePostsListState();
}

class _ImagePostsListState extends State<ImagePostsList> {
  late final ApiService apiService = ApiService();
  late final LikeService likeService = LikeService();

  // Track like state for each post
  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};

  // Track comments count for each post
  Map<int, int> postCommentsCounts = {};

  // Track liked users for each post (fetched on-demand)
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};

  // Cache the posts data
  List<UserPostModel>? cachedPosts;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // Load posts and initialize like states and comments counts
  Future<void> _loadPosts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final postsImage = await apiService.fetchImagePosts(widget.username!);

      // Debug: Print the like states from API
      for (var post in postsImage) {
        debugPrint(
          'Post ${post.id}: isLiked=${post.isLiked}, likesCount=${post.likesCount}',
        );
      }

      setState(() {
        cachedPosts = postsImage;
        isLoading = false;

        // Initialize like states and comments counts from fetched data
        postLikeStates.clear();
        postLikeCounts.clear();
        postCommentsCounts.clear();

        for (var post in postsImage) {
          // Explicitly set the values from the post model
          postLikeStates[post.id] = post.isLiked;
          postLikeCounts[post.id] = post.likesCount;
          postCommentsCounts[post.id] = post.commentsCount;

          // Fetch liked users for posts with likes
          if (post.likesCount > 0) {
            _fetchLikedUsers(post.id);
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
      setState(() {
        cachedPosts = [];
        isLoading = false;
      });
    }
  }

  // Fetch liked users for a specific post
  Future<void> _fetchLikedUsers(int postId) async {
    // Don't fetch if already loading or already loaded
    if (likedUsersLoading[postId] == true ||
        postLikedUsers.containsKey(postId)) {
      return;
    }

    setState(() {
      likedUsersLoading[postId] = true;
    });

    try {
      final users = await ApiService().fetchLikedUsers(postId);

      setState(() {
        postLikedUsers[postId] = users
            .take(3)
            .toList(); // Only keep first 3 for display
        likedUsersLoading[postId] = false;
      });
    } catch (e) {
      setState(() {
        likedUsersLoading[postId] = false;
      });
    }
  }

  // Silently fetch liked users without clearing existing data (prevents flickering)
  Future<void> _fetchLikedUsersSilently(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);

      setState(() {
        postLikedUsers[postId] = users
            .take(3)
            .toList(); // Only keep first 3 for display
      });
    } catch (e) {
      // debugPrint('Error silently fetching liked users for post $postId: $e');
    }
  }

  void _showAllImagesGrid(
    int postId,
    UserPollQuestion poll,
    bool isPolledByCurrentUser,
  ) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ShowImagesPopup(
              images: poll.options ?? [],
              postId: postId,
              pollId: poll.id,
              onImageTap: (index) {},
              isPolledByCurrentUser: isPolledByCurrentUser,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            setState(() {
              _loadPosts();
            });
          }
        });
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
          cachedPosts![postIndex] = cachedPosts![postIndex].copyWith(
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
            cachedPosts![postIndex] = cachedPosts![postIndex].copyWith(
              isLiked: result.isLiked,
              likesCount: result.likesCount,
            );
          }
        }
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
            cachedPosts![postIndex] = cachedPosts![postIndex].copyWith(
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
        setState(() => postCommentsCounts[postId] = newCount);
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

  Future<void> deletePost(int postId, int index) async {
    try {
      // Call the API to delete
      bool success = await apiService.userDeletePost(postId);
      if (success) {
        // Remove from UI after successful API call
        setState(() {
          cachedPosts?.removeAt(index);
          // Clean up tracking maps
          postLikeStates.remove(postId);
          postLikeCounts.remove(postId);
          postCommentsCounts.remove(postId);
          postLikedUsers.remove(postId);
          likedUsersLoading.remove(postId);
        });

        showToast(message: 'Post deleted successfully');
      } else {
        showToast(message: 'Failed to delete post');
      }
    } catch (error) {
      showToast(message: 'Error: ${error.toString()}');
    }
  }

  // Format comments count text similar to likes
  String _getCommentsCountText(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
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
          AppLocalizations.of(context)!.posts,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: isLoading
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : cachedPosts == null || cachedPosts!.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.nopostsfound,
                style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
              ),
            )
          : _buildPostsList(cachedPosts!),
    );
  }

  Widget _buildPostsList(List<UserPostModel> postsImage) {
    return ListView.builder(
      itemCount: postsImage.length,
      itemBuilder: (context, index) {
        final imagePost = postsImage[index];

        // Check if post has images in polls
        bool hasImages = imagePost.polls.any(
          (poll) =>
              poll.options?.any((option) => option.image != null) ?? false,
        );

        // Skip posts without images in polls
        if (!hasImages) {
          return const SizedBox.shrink();
        }

        // FIXED: Directly read from tracking maps with fallback
        // Use postLikeStates first, if not found, use cached post value
        final isLiked = postLikeStates.containsKey(imagePost.id)
            ? postLikeStates[imagePost.id]!
            : imagePost.isLiked;
        final likesCount = postLikeCounts.containsKey(imagePost.id)
            ? postLikeCounts[imagePost.id]!
            : imagePost.likesCount;
        final commentsCount = postCommentsCounts.containsKey(imagePost.id)
            ? postCommentsCounts[imagePost.id]!
            : imagePost.commentsCount;

        // Get liked users for this post
        final viewLikes = postLikedUsers[imagePost.id] ?? [];

        // Debug print for verification
        debugPrint(
          'Rendering Post ${imagePost.id}: isLiked=$isLiked, likesCount=$likesCount',
        );

        return Container(
          padding: EdgeInsets.all(8.w),
          margin: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(30, 0, 0, 0),
                blurRadius: 5,
                spreadRadius: 2,
              ),
            ],
          ),
          width: double.infinity,
          child: Column(
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
                        widget.profileImage != null &&
                            widget.profileImage!.isNotEmpty
                        ? MemoryImage(getProfileImage(widget.profileImage)!)
                        : null,
                    child:
                        widget.profileImage == null ||
                            widget.profileImage!.isEmpty
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
                      showUserDeletePostDiolog(context, () {
                        Navigator.pop(context);
                        deletePost(imagePost.id, index);
                      });
                    },
                    child: Icon(FeatherIcons.moreVertical, size: 16.spMax),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  imagePost.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildImagesStack(
                imagePost.id,
                imagePost.polls,
                imagePost.is_polled_by_current_user,
              ),
              SizedBox(height: 5.h),
              Row(
                children: [
                  // Like button
                  GestureDetector(
                    onTap: () => _toggleLike(imagePost.id),
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
                                  key: ValueKey('filled_${imagePost.id}'),
                                  height: 21.h,
                                  width: 21.w,
                                )
                              : Image.asset(
                                  Assets.assetsImagesIcHeart,
                                  key: ValueKey('outline_${imagePost.id}'),
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
                  // Comments button
                  GestureDetector(
                    onTap: () => _showCommentsBottomSheet(imagePost.id),
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
                  GestureDetector(
                    onTap: () {
                      // ShareService.sharePost(widget.post, context: context);
                    },
                    child: Icon(
                      FeatherIcons.send,
                      size: 18.3.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
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
                    onTap: () => _showLikedUsersBottomSheet(imagePost.id),
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
          ),
        );
      },
    );
  }

  Widget _buildImagesStack(
    int postId,
    List<UserPollQuestion> polls,
    bool isPolledByCurrentUser,
  ) {
    // Extract images from poll options
    List<PollOptionImage> validImages = [];
    UserPollQuestion? firstPollWithImages;

    for (var poll in polls) {
      if (poll.options != null) {
        for (var option in poll.options!) {
          if (option.image != null) {
            validImages.add(option.image!);
            firstPollWithImages ??= poll; // Store first poll with images
          }
        }
      }
    }

    // If no valid images, return empty container
    if (validImages.isEmpty || firstPollWithImages == null) {
      return const SizedBox.shrink();
    }

    List<Alignment> getAlignments(int totalImages) {
      switch (totalImages) {
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
        case 4:
        default:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.centerRight,
          ];
      }
    }

    List<Alignment> alignments = getAlignments(validImages.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double imageHeight = 150.h;

        return GestureDetector(
          onTap: () => _showAllImagesGrid(
            postId,
            firstPollWithImages!,
            isPolledByCurrentUser,
          ),
          child: SizedBox(
            height: imageHeight,
            width: availableWidth,
            child: Stack(
              children: validImages
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    int index = entry.key;
                    PollOptionImage imageData = entry.value;
                    Alignment alignment = alignments[index];
                    double imageWidth = (availableWidth * 0.7) - (index * 8.0);
                    imageWidth = imageWidth < 60.w ? 60.w : imageWidth;

                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        width: imageWidth,
                        height: imageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: Image.network(
                              '${ApiConfig.baseUrlImage}${imageData.url}',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.r),
                                    color: Colors.grey[200],
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[600],
                                    size: 30,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                        color: Colors.grey[200],
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
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
    );
  }
}
