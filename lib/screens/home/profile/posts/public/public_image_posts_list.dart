// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../api/api_config.dart';
import '../../../../../api/services/api_service.dart';
import '../../../../../api/services/like/like_service.dart';
import '../../../../../core/constants/app_images.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../models/like/like_uers_model.dart';
import '../../../../../models/public/public_profile_model.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/button/back_button.dart';
import '../../../../../widgets/custom_text_styles.dart';
import '../../../../../widgets/loader.dart';
import '../../../../../widgets/show_toast.dart';
import '../../../../../widgets/utils/bottomsheet_util.dart';
import '../../../../../widgets/utils/like_util.dart';
import '../popup/public_image_grid.dart';

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

  List<PublicPost>? cachedPosts;
  bool isLoading = true;

  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};
  Map<int, int> postCommentsCounts = {};
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => isLoading = true);

    try {
      final posts = await apiService.fetchPostsWithImages(widget.userId);

      setState(() {
        cachedPosts = posts;
        isLoading = false;
        postLikeStates.clear();
        postLikeCounts.clear();
        postCommentsCounts.clear();
        for (var post in posts) {
          postLikeStates[post.id] = post.isLiked;
          postLikeCounts[post.id] = post.likesCount;
          postCommentsCounts[post.id] = post.comments.length;
        }
      });
      for (var post in posts) {
        if (post.likesCount > 0) {
          _fetchLikedUsers(post.id);
        }
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      setState(() {
        cachedPosts = [];
        isLoading = false;
      });
    }
  }

  void _showAllImagesGrid(int postId, List<PublicPoll> polls) {
    if (polls.isEmpty) return;

    final List<PublicPollOption> allPollOptions = [];
    for (var poll in polls) {
      allPollOptions.addAll(poll.options);
    }

    final int pollId = polls.first.id;
    final post = cachedPosts?.firstWhere((p) => p.id == postId);
    final bool isPolledByCurrentUser = post?.is_polled_by_current_user ?? false;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PublicImagesPopup(
              images: allPollOptions,
              postId: postId,
              pollId: pollId,
              onImageTap: (index) {},
              isPolledByCurrentUser: isPolledByCurrentUser,
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _loadPosts();
          }
        });
  }

  Future<void> _fetchLikedUsers(int postId) async {
    if (likedUsersLoading[postId] == true ||
        postLikedUsers.containsKey(postId)) {
      return;
    }

    setState(() => likedUsersLoading[postId] = true);

    try {
      final users = await ApiService().fetchLikedUsers(postId);
      setState(() {
        postLikedUsers[postId] = users.take(3).toList();
        likedUsersLoading[postId] = false;
      });
    } catch (e) {
      debugPrint('Error fetching liked users for post $postId: $e');
      setState(() => likedUsersLoading[postId] = false);
    }
  }

  Future<void> _fetchLikedUsersSilently(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      setState(() => postLikedUsers[postId] = users.take(3).toList());
    } catch (e) {
      debugPrint('Error silently fetching liked users for post $postId: $e');
    }
  }

  Future<void> _toggleLike(int postId) async {
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;

      if (cachedPosts != null) {
        final i = cachedPosts!.indexWhere((p) => p.id == postId);
        if (i != -1) {
          cachedPosts![i] = PublicPost(
            id: cachedPosts![i].id,
            user: cachedPosts![i].user,
            description: cachedPosts![i].description,
            createdAt: cachedPosts![i].createdAt,
            images: cachedPosts![i].images,
            polls: cachedPosts![i].polls,
            comments: cachedPosts![i].comments,
            isLiked: !currentLikeState,
            likesCount: currentLikeState
                ? currentLikeCount - 1
                : currentLikeCount + 1,
            is_polled_by_current_user:
                cachedPosts![i].is_polled_by_current_user,
          );
        }
      }
    });

    try {
      final result = await likeService.togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );

      setState(() {
        postLikeStates[postId] = result.isLiked;
        postLikeCounts[postId] = result.likesCount;

        if (cachedPosts != null) {
          final i = cachedPosts!.indexWhere((p) => p.id == postId);
          if (i != -1) {
            cachedPosts![i] = PublicPost(
              id: cachedPosts![i].id,
              user: cachedPosts![i].user,
              description: cachedPosts![i].description,
              createdAt: cachedPosts![i].createdAt,
              images: cachedPosts![i].images,
              polls: cachedPosts![i].polls,
              comments: cachedPosts![i].comments,
              isLiked: result.isLiked,
              likesCount: result.likesCount,
              is_polled_by_current_user:
                  cachedPosts![i].is_polled_by_current_user,
            );
          }
        }
      });

      if (result.likesCount > 0) {
        _fetchLikedUsersSilently(postId);
      } else {
        setState(() => postLikedUsers.remove(postId));
      }

      if (!result.success) showToast(message: result.message);
    } catch (e) {
      setState(() {
        postLikeStates[postId] = currentLikeState;
        postLikeCounts[postId] = currentLikeCount;

        if (cachedPosts != null) {
          final i = cachedPosts!.indexWhere((p) => p.id == postId);
          if (i != -1) {
            cachedPosts![i] = PublicPost(
              id: cachedPosts![i].id,
              user: cachedPosts![i].user,
              description: cachedPosts![i].description,
              createdAt: cachedPosts![i].createdAt,
              images: cachedPosts![i].images,
              polls: cachedPosts![i].polls,
              comments: cachedPosts![i].comments,
              isLiked: currentLikeState,
              likesCount: currentLikeCount,
              is_polled_by_current_user:
                  cachedPosts![i].is_polled_by_current_user,
            );
          }
        }
      });
      showToast(message: 'Failed to update like');
    }
  }

  void _showCommentsBottomSheet(int postId) {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username!,
      onCommentsCountChanged: (newCount) {
        setState(() {
          postCommentsCounts[postId] = newCount;

          if (cachedPosts != null) {
            final i = cachedPosts!.indexWhere((p) => p.id == postId);
            if (i != -1) {
              cachedPosts![i] = PublicPost(
                id: cachedPosts![i].id,
                user: cachedPosts![i].user,
                description: cachedPosts![i].description,
                createdAt: cachedPosts![i].createdAt,
                images: cachedPosts![i].images,
                polls: cachedPosts![i].polls,
                comments: List.generate(newCount, (_) => {}),
                isLiked: cachedPosts![i].isLiked,
                likesCount: cachedPosts![i].likesCount,
                is_polled_by_current_user:
                    cachedPosts![i].is_polled_by_current_user,
              );
            }
          }
        });
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 45.spMax,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'No posts with image',
                    style: TextStyle(fontSize: 11.5.sp, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _buildPostsList(cachedPosts!),
    );
  }

  Widget _buildPostsList(List<PublicPost> postsWithImages) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 5.h),
      itemCount: postsWithImages.length,
      itemBuilder: (context, index) {
        final post = postsWithImages[index];
        final isLiked = postLikeStates.containsKey(post.id)
            ? postLikeStates[post.id]!
            : post.isLiked;
        final likesCount = postLikeCounts.containsKey(post.id)
            ? postLikeCounts[post.id]!
            : post.likesCount;
        final commentsCount = postCommentsCounts.containsKey(post.id)
            ? postCommentsCounts[post.id]!
            : post.comments.length;
        final viewLikes = postLikedUsers[post.id] ?? [];

        List<PollOptionImage> pollImages = [];
        if (post.polls.isNotEmpty) {
          for (var poll in post.polls) {
            for (var option in poll.options) {
              if (option.image != null) pollImages.add(option.image!);
            }
          }
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(8.w),
          margin: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
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
                ],
              ),
              SizedBox(height: 5.h),
              Text(
                post.description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 10.7.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.h),
              if (pollImages.isNotEmpty)
                _buildPollImagesStack(post.id, pollImages, post.polls)
              else
                SizedBox(height: 120.h),
              SizedBox(height: 5.h),
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
                    onTap: () => _showCommentsBottomSheet(post.id),
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
                    onTap: () {},
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
          ),
        );
      },
    );
  }

  Widget _buildPollImagesStack(
    int postId,
    List<PollOptionImage> images,
    List<PublicPoll> polls,
  ) {
    List<Alignment> getAlignments(int total) {
      switch (total) {
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
        default:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.centerRight,
          ];
      }
    }

    final alignments = getAlignments(images.length);
    final double imageHeight = 150.h;

    return GestureDetector(
      onTap: () => _showAllImagesGrid(postId, polls),
      child: SizedBox(
        height: imageHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            return Stack(
              children: images
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    final int index = entry.key;
                    final PollOptionImage imageData = entry.value;
                    double imageWidth = (availableWidth * 0.7) - (index * 8.0);
                    imageWidth = imageWidth < 60.w ? 60.w : imageWidth;

                    return Align(
                      alignment: alignments[index],
                      child: Container(
                        margin: EdgeInsets.only(top: 5.h),
                        width: imageWidth,
                        height: imageHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: Image.network(
                            '${ApiConfig.baseUrlImage}${imageData.url}',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[600],
                                    size: 30,
                                  ),
                                ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value:
                                        loadingProgress.expectedTotalBytes !=
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
