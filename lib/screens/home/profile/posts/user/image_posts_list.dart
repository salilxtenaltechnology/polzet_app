// ignore_for_file: must_be_immutable, deprecated_member_use

import 'dart:typed_data';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../api/api_config.dart';
import '../../../../../api/api_service.dart';
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
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../rank/image/user_image_ranking.dart';

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

  Map<String, bool> postLikeStates = {};
  Map<String, int> postLikeCounts = {};
  Map<String, int> postCommentsCounts = {};
  Map<String, List<LikeUser>> postLikedUsers = {};
  Map<String, bool> likedUsersLoading = {};

  List<UserPostModel>? cachedPosts;
  bool isLoading = false;
  bool isInitialLoad = true;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.profileImage != null && widget.profileImage!.isNotEmpty) {
      _profileImageBytes = getProfileImage(widget.profileImage);
    }
    _loadPosts(showLoader: true);
  }

  Future<void> _loadPosts({bool showLoader = false}) async {
    if (showLoader) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final postsImage = await apiService.fetchImagePosts(widget.username!);

      if (!mounted) return;
      setState(() {
        cachedPosts = postsImage;
        isLoading = false;
        isInitialLoad = false;

        postLikeStates.clear();
        postLikeCounts.clear();
        postCommentsCounts.clear();

        for (var post in postsImage) {
          postLikeStates[post.id] = post.isLiked;
          postLikeCounts[post.id] = post.likesCount;
          postCommentsCounts[post.id] = post.commentsCount;

          if (post.likesCount > 0) {
            if (showLoader) {
              _fetchLikedUsers(post.id);
            } else {
              _fetchLikedUsersSilently(post.id);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (!mounted) return;
      setState(() {
        cachedPosts = [];
        isLoading = false;
        isInitialLoad = false;
      });
    }
  }

  Future<void> _fetchLikedUsers(String postId) async {
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
        postLikedUsers[postId] = users.take(3).toList();
        likedUsersLoading[postId] = false;
      });
    } catch (e) {
      setState(() {
        likedUsersLoading[postId] = false;
      });
    }
  }

  Future<void> _fetchLikedUsersSilently(String postId, {bool force = false}) async {
    if (!force && postLikedUsers.containsKey(postId)) return;
    try {
      final users = await ApiService().fetchLikedUsers(postId);

      setState(() {
        postLikedUsers[postId] = users.take(3).toList();
      });
      // ignore: empty_catches
    } catch (e) {}
  }

  void _showAllImagesGrid(
    String postId,
    UserPollQuestion poll,
    bool isPolledByCurrentUser,
    UserPostModel post, // ← add this
  ) {
    if (isPolledByCurrentUser) {
      // Already voted → show results
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ImageResultScreen(username: post.user, postId: post.id),
        ),
      );
    } else {
      // Not yet voted → go to ranking screen
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => UserImageRanking(
                firstName: userProvider.firstName,
                lastName: userProvider.lastName,
                profileImage: userProvider.profile_picture,
                post: post,
                poll: poll,
              ),
            ),
          )
          .then((result) {
            if (result == true) {
              setState(() {});
              _loadPosts();
            }
          });
    }
  }

  Future<void> _toggleLike(String postId) async {
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;

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

      if (result.likesCount > 0) {
        _fetchLikedUsersSilently(postId, force: true);
      } else {
        setState(() {
          postLikedUsers.remove(postId);
        });
      }

      if (!result.success) {
        showToast(message: result.message);
      }
    } catch (e) {
      setState(() {
        postLikeStates[postId] = currentLikeState;
        postLikeCounts[postId] = currentLikeCount;

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

  void _showCommentsBottomSheet(String postId) async {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username!,
      onCommentsCountChanged: (newCount) {
        setState(() => postCommentsCounts[postId] = newCount);
      },
    );
  }

  void _showLikedUsersBottomSheet(String postId) {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: postId,
    );
  }

  Future<void> deletePost(String postId, int index) async {
    try {
      bool success = await apiService.userDeletePost(postId);
      if (success) {
        setState(() {
          cachedPosts?.removeAt(index);
          postLikeStates.remove(postId);
          postLikeCounts.remove(postId);
          postCommentsCounts.remove(postId);
          postLikedUsers.remove(postId);
          likedUsersLoading.remove(postId);
        });

        Provider.of<UserProvider>(context, listen: false).notifyPostDeleted(postId);

        showToast(message: 'Post deleted successfully');
      } else {
        showToast(message: 'Failed to delete post');
      }
    } catch (error) {
      showToast(message: 'Error: ${error.toString()}');
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.posts),
      body: isLoading && isInitialLoad
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: cachedPosts == null || cachedPosts!.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 200.h),
                        Center(
                          child: Text(
                            AppLocalizations.of(context)!.nopostsfound,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildPostsList(cachedPosts!),
            ),
    );
  }

  Widget _buildPostsList(List<UserPostModel> postsImage) {
    return ListView.builder(
      itemCount: postsImage.length,
      itemBuilder: (context, index) {
        final imagePost = postsImage[index];

        bool hasImages = imagePost.polls.any(
          (poll) =>
              poll.options.any((option) => option.image != null) ?? false,
        );

        if (!hasImages) {
          return const SizedBox.shrink();
        }
        final isLiked = postLikeStates.containsKey(imagePost.id)
            ? postLikeStates[imagePost.id]!
            : imagePost.isLiked;
        final likesCount = postLikeCounts.containsKey(imagePost.id)
            ? postLikeCounts[imagePost.id]!
            : imagePost.likesCount;
        final commentsCount = postCommentsCounts.containsKey(imagePost.id)
            ? postCommentsCounts[imagePost.id]!
            : imagePost.commentsCount;

        final viewLikes = postLikedUsers[imagePost.id] ?? [];

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
                    backgroundImage: (() {
                      if (_profileImageBytes != null) {
                        return MemoryImage(_profileImageBytes!) as ImageProvider;
                      }
                      final imgUrl = widget.profileImage;
                      if (imgUrl != null && imgUrl.isNotEmpty && (imgUrl.startsWith('http') || imgUrl.startsWith('/') || imgUrl.contains('/'))) {
                        final imageUrl = imgUrl.startsWith('http')
                            ? imgUrl
                            : (imgUrl.startsWith('/')
                                ? '${ApiConfig.baseUrlImage}$imgUrl'
                                : '${ApiConfig.baseUrlImage}/$imgUrl');
                        return CachedNetworkImageProvider(imageUrl) as ImageProvider;
                      }
                      return null;
                    })(),
                    child: (() {
                      final hasImage = _profileImageBytes != null ||
                          (widget.profileImage != null &&
                              widget.profileImage!.isNotEmpty &&
                              (widget.profileImage!.startsWith('http') ||
                                  widget.profileImage!.startsWith('/') ||
                                  widget.profileImage!.contains('/')));
                      if (hasImage) return null;
                      return Text(
                        widget.username?.isNotEmpty == true
                            ? widget.username![0].toUpperCase()
                            : '',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    })(),
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
              SizedBox(height: 7.h),
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
                              ? AppIcons.filledHeart(
                                  key: const ValueKey('filled'),
                                )
                              : AppIcons.outlineHeart(
                                  key: const ValueKey('outline'),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.6),
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
                        AppIcons.commnetBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.6),
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
                      ShareService.sharePost(
                        usernameOverride: widget.username,
                        imagePost,
                        context: context,
                      );
                    },
                    child: AppIcons.sharePost(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              if (likesCount > 0) ...[
                SizedBox(height: 5.h),
                if (viewLikes.isNotEmpty)
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
    String postId,
    List<UserPollQuestion> polls,
    bool isPolledByCurrentUser,
  ) {
    List<PollOptionImage> validImages = [];
    UserPollQuestion? firstPollWithImages;

    for (var poll in polls) {
      for (var option in poll.options) {
        if (option.image != null) {
          validImages.add(option.image!);
          firstPollWithImages ??= poll;
        }
      }
    }

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
            cachedPosts!.firstWhere((p) => p.id == postId),
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
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: imageData.resolvedUrl(ApiConfig.baseUrlImage),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
                                  color: Colors.grey[200],
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  color: Colors.grey[200],
                                ),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[600],
                                  size: 30,
                                ),
                              ),
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
