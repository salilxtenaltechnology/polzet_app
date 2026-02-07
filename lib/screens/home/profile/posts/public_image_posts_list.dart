// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/utils/bottomsheet_util.dart';
import 'public_image_grid.dart';

class PublicImagePostsList extends StatefulWidget {
  String? username;
  String? profileImage;
  int userId;
  PublicImagePostsList({
    super.key,
    required this.userId,
    required this.username,
    required this.profileImage,
  });

  @override
  State<PublicImagePostsList> createState() => _PublicPostsListState();
}

class _PublicPostsListState extends State<PublicImagePostsList> {
  final ApiService apiService = ApiService();
  late final LikeService likeService = LikeService();

  // Store the posts data to avoid rebuilding FutureBuilder
  List<PublicPost>? cachedPosts;

  // Maps to track like states and counts for each post
  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};

  void _showAllImagesGrid(int postId, List<PublicPoll> polls) {
    List<PublicPollOption> allPollOptions = [];

    for (var poll in polls) {
      allPollOptions.addAll(poll.options);
    }

    bool hasUserVoted = polls.any((poll) => poll.userVote != null);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PublicImagesPopup(
              images: allPollOptions,
              postId: postId,
              onImageTap: (index) {},
              isPolledByCurrentUser: hasUserVoted,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            setState(() {
              // Refresh poll data here if needed
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

  Widget _buildPostsList(List<PublicPost> postsWithImages) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 5.h),
      itemCount: postsWithImages.length > 4 ? 4 : postsWithImages.length,
      itemBuilder: (context, index) {
        final post = postsWithImages[index];

        // Initialize like state and count from post data if not already set
        if (!postLikeStates.containsKey(post.id)) {
          postLikeStates[post.id] = post.isLiked;
          postLikeCounts[post.id] = post.likesCount;
        }

        // Get current like state and count for this post
        final isLiked = postLikeStates[post.id] ?? post.isLiked;
        final likesCount = postLikeCounts[post.id] ?? post.likesCount;
        final commentsCount = post.comments.length;

        // Extract poll option images from the post
        List<PollOptionImage> pollImages = [];
        if (post.polls.isNotEmpty) {
          for (var poll in post.polls) {
            for (var option in poll.options) {
              if (option.image != null) {
                pollImages.add(option.image!);
              }
            }
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10).w,
          margin: EdgeInsets.only(bottom: 10.h, right: 10.w, left: 10.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2),
            ],
          ),
          child: Column(
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
                ],
              ),
              SizedBox(height: 5.h),
              Text(
                post.description,
                style: Theme.of(context).textTheme.titleSmall,
              ),

              // Only display if there are poll images
              if (pollImages.isNotEmpty)
                _buildPollImagesStack(post.id, pollImages, post.polls)
              else
                SizedBox(height: 120.h),
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
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: isLiked
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
                          likesCount > 0
                              ? LikeService.getLikesCountText(likesCount)
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
                          commentsCount > 0
                              ? _getCommentsCountText(commentsCount)
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
            ],
          ),
        );
      },
    );
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
      body: cachedPosts == null
          ? FutureBuilder<List<PublicPost>>(
              future: apiService.fetchPostsWithImages(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: ListView(
                      children: [
                        SizedBox(height: 10.h),
                        Container(
                          height: 300.h,
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            bottom: 10.h,
                            right: 10.w,
                            left: 10.w,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        Container(
                          height: 300.h,
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            bottom: 10.h,
                            right: 10.w,
                            left: 10.w,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
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
                        Icon(
                          Icons.error_outline,
                          color: Colors.grey[600],
                          size: 50,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'Error loading posts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final postsWithImages = snapshot.data ?? [];
                if (postsWithImages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 10.h),
                        Icon(
                          Icons.photo_library_outlined,
                          size: 45.spMax,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'No posts with image',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  );
                }

                // Cache the posts data
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    cachedPosts = postsWithImages;
                    // Initialize like states and counts from cached posts
                    for (var post in postsWithImages) {
                      if (!postLikeStates.containsKey(post.id)) {
                        postLikeStates[post.id] = post.isLiked;
                        postLikeCounts[post.id] = post.likesCount;
                      }
                    }
                  });
                });

                return _buildPostsList(postsWithImages);
              },
            )
          : _buildPostsList(cachedPosts!),
    );
  }

  Widget _buildPollImagesStack(
    int postId,
    List<PollOptionImage> images,
    List<PublicPoll> polls,
  ) {
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

    List<Alignment> alignments = getAlignments(images.length);
    double imageHeight = 150.h;

    return GestureDetector(
      onTap: () => _showAllImagesGrid(postId, polls),
      child: SizedBox(
        height: imageHeight, // Fixed height instead of using availableHeight
        child: LayoutBuilder(
          builder: (context, constraints) {
            double availableWidth = constraints.maxWidth;

            return Stack(
              children: images
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
                        margin: EdgeInsets.only(top: 5.h),
                        width: imageWidth,
                        height: imageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 1),
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
                                          12.r,
                                        ),
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
            );
          },
        ),
      ),
    );
  }
}
