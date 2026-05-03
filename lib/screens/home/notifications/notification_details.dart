// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/custom_card.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:provider/provider.dart';

import '../../../api/api_config.dart';
import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/utils/like_util.dart';
import '../../../models/like/like_uers_model.dart';
import '../../../models/posts/user_post_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/card/things/poll_question_card.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/show_toast.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../profile/posts/popup/image_grid.dart';

class NotificationDetails extends StatefulWidget {
  final int postId;

  const NotificationDetails({super.key, required this.postId});

  @override
  State<NotificationDetails> createState() => _NotificationDetailsState();
}

class _NotificationDetailsState extends State<NotificationDetails> {
  final ApiService apiService = ApiService();
  late Future<UserPostModel?> _postFuture;

  Map<int, double> localPercentages = {};
  Map<String, bool> pollPolledStates = {};

  List<LikeUser> viewLikes = [];

  int likesCount = 0;
  int commentsCount = 0;

  bool isLike = false;
  bool isLikeLoading = false;
  UserPostModel? currentPost;

  @override
  void initState() {
    super.initState();
    _postFuture = _initializeAndLoadPost();
  }

  Future<UserPostModel?> _initializeAndLoadPost() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (!userProvider.isUserDataValid()) {
        final dataReady = await userProvider.waitForUserData(
          timeout: const Duration(seconds: 10),
        );

        if (!dataReady) {
          throw Exception('Unable to load user session. Please try again.');
        }
      }

      return await loadSinglePost(widget.postId);
    } catch (e) {
      debugPrint('❌ NotificationDetails: Initialization error: $e');
      rethrow;
    }
  }

  void _handlePercentagesUpdated(Map<int, double> updated) {
    if (mounted) {
      setState(() => localPercentages.addAll(updated));
    }
  }

  void _handlePollPolledStateChanged(String pollKey, bool polled) {
    if (mounted) {
      setState(() => pollPolledStates[pollKey] = polled);
    }
  }

  void _initializeLikeState(UserPostModel post) {
    currentPost = post;
    isLike = post.isLiked;
    likesCount = post.likesCount;
    commentsCount = post.commentsCount;

    localPercentages.clear();
    pollPolledStates.clear();
    for (var poll in post.polls) {
      pollPolledStates[poll.id.toString()] = post.is_polled_by_current_user;
      for (var option in poll.options ?? []) {
        localPercentages[option.id] = option.percentage;
      }
    }
  }

  Future<UserPostModel?> loadSinglePost(int postId) async {
    if (postId == 0) {
      debugPrint("❌ Invalid postId: 0");
      throw Exception('Invalid post ID');
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final username = userProvider.username;

      if (username == null || username.isEmpty) {
        debugPrint("❌ Username is null or empty");
        throw Exception('User session not found. Please login again.');
      }

      final posts = await apiService.fetchPostsImages(username);

      final post = posts.firstWhere(
        (p) => p.id == postId,
        orElse: () => throw Exception('Post not found'),
      );

      if (post.images.isEmpty && post.polls.isEmpty) {
        throw Exception('This post has no content to display');
      }

      _initializeLikeState(post);

      if (post.likesCount > 0) {
        _fetchLikedUsersSilently(post.id);
      }

      if (mounted) {
        setState(() {});
      }

      return post;
    } catch (e) {
      debugPrint("❌ Error loading post: $e");
      rethrow;
    }
  }

  bool _isPollPost(UserPostModel post) {
    return post.polls.isNotEmpty &&
        post.polls.every(
          (poll) =>
              poll.options != null &&
              poll.options!.every(
                (option) => option.text != null && option.text!.isNotEmpty,
              ),
        );
  }

  Future<void> _toggleLike() async {
    if (isLikeLoading || currentPost == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId ?? 0;
    final currentUsername = userProvider.username ?? '';
    final currentUserImage = userProvider.profile_picture;

    final previousIsLike = isLike;
    final previousLikesCount = likesCount;
    final previousViewLikes = List<LikeUser>.from(viewLikes);

    setState(() {
      isLike = !isLike;

      if (isLike) {
        likesCount++;

        viewLikes.insert(
          0,
          LikeUser(
            id: currentUserId,
            username: currentUsername,
            profileImage: currentUserImage,
          ),
        );

        if (viewLikes.length > 3) {
          viewLikes = viewLikes.take(3).toList();
        }
      } else {
        likesCount--;
        viewLikes.removeWhere((like) => like.username == currentUsername);
      }

      isLikeLoading = true;
    });

    final result = await LikeService().togglePostLike(
      context: context,
      postId: widget.postId,
      currentLikeState: previousIsLike,
      currentLikesCount: previousLikesCount,
    );

    if (mounted) {
      setState(() {
        isLikeLoading = false;

        if (!result.success) {
          isLike = previousIsLike;
          likesCount = previousLikesCount;
          viewLikes = previousViewLikes;

          if (result.message.isNotEmpty) {
            showToast(message: result.message);
          }

          isLike = result.isLiked;
          likesCount = result.likesCount;

          if (likesCount > 0) {
            _fetchLikedUsersSilently(widget.postId);
          } else {
            viewLikes.clear();
          }
        }
      });
    }
  }

  void _handleLikeChanged(int postId, bool isLiked, int newLikesCount) {
    if (mounted && postId == widget.postId) {
      setState(() {
        isLike = isLiked;
        likesCount = newLikesCount;
      });
    }
  }

  void _handleCommentsChanged(int postId, int newCommentsCount) {
    if (mounted && postId == widget.postId) {
      setState(() {
        commentsCount = newCommentsCount;
      });
    }
  }

  void _showCommentsBottomSheet() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final username = userProvider.username;

    if (username == null || username.isEmpty) {
      showToast(message: 'Unable to load comments. Username not available.');
      return;
    }

    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: widget.postId,
      currentUsername: username,
      onCommentsCountChanged: (newCount) {
        if (mounted) {
          setState(() => commentsCount = newCount);
        }
      },
    );
  }

  String _getCommentsCountText(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _showLikedUsersBottomSheet() {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: widget.postId,
    );
  }

  Future<void> _fetchLikedUsersSilently(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (mounted) {
        setState(() {
          viewLikes = users.take(3).toList();
        });
      }
    } catch (e) {}
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
              _postFuture = _initializeAndLoadPost();
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text('Post', style: AppTextStyles.pageTitleTextStyle(context)),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: FutureBuilder<UserPostModel?>(
        future: _postFuture,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Loader(color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 12.h),
                  Text(
                    'Loading post...',
                    style: AppTextStyles.subText.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Unable to Load Post',
                      style: AppTextStyles.sectionHeading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      error.contains('Exception:')
                          ? error.replaceFirst('Exception:', '').trim()
                          : 'Something went wrong. Please try again.',
                      style: AppTextStyles.bodyText.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Go Back'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _postFuture = _initializeAndLoadPost();
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.post_add,
                    size: 60,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Post Not Found',
                    style: AppTextStyles.sectionHeading.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'This post may have been deleted',
                    style: AppTextStyles.bodyText.copyWith(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final post = snapshot.data!;
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );

          if (_isPollPost(post)) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                child: ThingsQustionsCard(
                  post: post,
                  onDelete: (_) {
                    Navigator.pop(context);
                  },
                  onLikeChanged: _handleLikeChanged,
                  onCommentsChanged: _handleCommentsChanged,
                  onCommentsIconTap: _showCommentsBottomSheet,
                  username: userProvider.username,
                  profileImage: userProvider.profile_picture,
                  // Pass current tracked states
                  currentLikeState: isLike,
                  currentLikesCount: likesCount,
                  currentCommentsCount: commentsCount,
                  currentLikedUsers: viewLikes,
                  onLikedUsersUpdated: (postId, users) {
                    if (mounted) setState(() => viewLikes = users);
                  },
                  localPercentages: localPercentages,
                  pollPolledStates: pollPolledStates,
                  onPercentagesUpdated: _handlePercentagesUpdated,
                  onPollPolledStateChanged: _handlePollPolledStateChanged,
                  onViewVotesTap: (poll, postId) {
                    final options = poll.options ?? [];
                    options.sort(
                      (a, b) => b.percentage.compareTo(a.percentage),
                    );
                    BottomSheetUtils.showCurrenUserThingsPostBottomSheet(
                      context: context,
                      poll: poll,
                      postId: postId,
                    );
                  },
                ),
              ),
            );
          }

          // Otherwise, show image post
          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomCard(
                    widget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                              backgroundImage:
                                  userProvider.profile_picture != null &&
                                      userProvider.profile_picture!.isNotEmpty
                                  ? MemoryImage(
                                      getProfileImage(
                                        userProvider.profile_picture,
                                      )!,
                                    )
                                  : null,
                              child:
                                  userProvider.profile_picture == null ||
                                      userProvider.profile_picture!.isEmpty
                                  ? Text(
                                      userProvider.username?.isNotEmpty == true
                                          ? userProvider.username![0]
                                                .toUpperCase()
                                          : '',
                                      style: AppTextStyles.cardTitle.copyWith(
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
                                  userProvider.username ?? '',
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                  ),
                                ),
                                Text(
                                  'Placed a post',
                                  style: AppTextStyles.subText.copyWith(
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

                        // Post content
                        Text(
                          post.description,
                          style: AppTextStyles.bodyText.copyWith(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5.h),

                        // Images
                        _buildImagesStack(
                          post.id,
                          post.polls,
                          post.is_polled_by_current_user,
                        ),
                        SizedBox(height: 5.h),

                        // Like button and count
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Row(
                                children: [
                                  // Animated heart icon
                                  Builder(
                                    builder: (context) {
                                      return AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                        child: isLike
                                            ? AppIcons.filledHeart(
                                                key: const ValueKey('filled'),
                                              )
                                            : AppIcons.outlineHeart(
                                                key: const ValueKey('outline'),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onBackground
                                                    .withOpacity(0.6),
                                              ),
                                      );
                                    },
                                  ),
                                  SizedBox(width: 3.w),

                                  // Like count
                                  Text(
                                    likesCount > 0
                                        ? LikeService.getLikesCountText(
                                            likesCount,
                                          )
                                        : '',
                                    style: AppTextStyles.subText.copyWith(
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
                              onTap: _showCommentsBottomSheet,
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
                                    style: AppTextStyles.subText.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  GestureDetector(
                                    onTap: () {
                                      // ShareService.sharePost(widget.post, context: context);
                                    },
                                    child: AppIcons.sharePost(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                          ],
                        ),

                        // Who liked preview
                        if (likesCount > 0) ...[
                          SizedBox(height: 5.h),
                          if (viewLikes.isNotEmpty)
                            GestureDetector(
                              onTap: _showLikedUsersBottomSheet,
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
            firstPollWithImages ??= poll;
          }
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
          ),
          child: SizedBox(
            height: imageHeight,
            width: availableWidth,
            child: Stack(
              clipBehavior: Clip.none,
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
                        width: imageWidth,
                        height: imageHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Image.network(
                            '${ApiConfig.baseUrlImage}${imageData.url}',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                ),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[600],
                                  size: 30,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
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
            ),
          ),
        );
      },
    );
  }
}
