// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/custom_card.dart';
import 'package:provider/provider.dart';

import '../../../api/api_config.dart';
import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../core/constants/app_images.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../models/posts/user_post_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/show_toast.dart';

class NotificationDetails extends StatefulWidget {
  final int postId;

  const NotificationDetails({super.key, required this.postId});

  @override
  State<NotificationDetails> createState() => _NotificationDetailsState();
}

class _NotificationDetailsState extends State<NotificationDetails> {
  // Initialize with default values - will be updated when post loads
  int likesCount = 0;
  bool isLike = false;
  bool isLikeLoading = false;
  List<LikeUser> viewLikes = [];

  final ApiService apiService = ApiService();
  UserPostModel? currentPost;

  // Store the Future to prevent recreating it on every build
  late Future<UserPostModel?> _postFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the Future once in initState
    _postFuture = loadSinglePost(widget.postId);
  }

  // Initialize like state from loaded post
  void _initializeLikeState(UserPostModel post) {
    currentPost = post;
    isLike = post.isLiked;
    likesCount = post.likesCount;
    // viewLikes = List.from(post.viewLikes);

    debugPrint('==== POST LIKE STATE ====');
    debugPrint('Post ID: ${post.id}');
    debugPrint('isLiked from server: ${post.isLiked}');
    debugPrint('isLike variable: $isLike');
    debugPrint('likesCount: $likesCount');
    debugPrint('========================');
  }

  Future<UserPostModel?> loadSinglePost(int postId) async {
    if (postId == 0) {
      return null;
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final posts = await apiService.fetchPostsImages(userProvider.username!);

      final post = posts.firstWhere(
        (p) => p.id == postId,
        orElse: () => throw Exception('Post not found'),
      );

      if (post.images.isNotEmpty) {
        // Initialize like state when post is loaded
        _initializeLikeState(post);

        // Force a rebuild after initializing state
        if (mounted) {
          setState(() {});
        }

        return post;
      }
      return null;
    } catch (e) {
      debugPrint("Error loading post: $e");
      rethrow;
    }
  }

  Future<void> _toggleLike() async {
    if (isLikeLoading || currentPost == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId ?? 0;
    final currentUsername = userProvider.username ?? '';
    final currentUserImage = userProvider.profile_picture;

    // Store previous state for rollback
    final previousIsLike = isLike;
    final previousLikesCount = likesCount;
    final previousViewLikes = List<LikeUser>.from(viewLikes);

    // Optimistic update - update UI immediately
    setState(() {
      isLike = !isLike;

      if (isLike) {
        // User just liked the post
        likesCount++;

        // Add current user to the beginning of viewLikes
        viewLikes.insert(
          0,
          LikeUser(
            id: currentUserId,
            username: currentUsername,
            profileImage: currentUserImage,
          ),
        );

        // Keep only first 3 users for display
        if (viewLikes.length > 3) {
          viewLikes = viewLikes.take(3).toList();
        }
      } else {
        // User just unliked the post
        likesCount--;
        viewLikes.removeWhere((like) => like.username == currentUsername);
      }

      isLikeLoading = true;
    });

    // Call API to persist the change
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
          // Rollback on failure
          isLike = previousIsLike;
          likesCount = previousLikesCount;
          viewLikes = previousViewLikes;

          if (result.message.isNotEmpty) {
            showToast(message: result.message);
          }
        } else {
          // Update with server response (for accuracy)
          isLike = result.isLiked;
          likesCount = result.likesCount;
        }
      });
    }
  }

  // Build "Liked by" text
  List<TextSpan> _buildLikedByText() {
    if (viewLikes.isEmpty) return [];

    List<TextSpan> spans = [];
    spans.add(
      TextSpan(
        text: 'Liked by ',
        style: TextStyle(
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(0.6),
        ),
      ),
    );

    if (viewLikes.length == 1) {
      spans.add(
        TextSpan(
          text: viewLikes[0].username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else if (viewLikes.length == 2) {
      spans.add(
        TextSpan(
          text: viewLikes[0].username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
      spans.add(
        TextSpan(
          text: ' and ',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(0.6),
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: viewLikes[1].username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: viewLikes[0].username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
      spans.add(
        TextSpan(
          text: ' and ',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(0.6),
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: '${viewLikes.length - 1} others',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return spans;
  }

  // Show bottom sheet with all users who liked
  void _showLikedUsersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 8.h),
              // Drag handle
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Liked by',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$likesCount ${likesCount == 1 ? "like" : "likes"}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              const Divider(height: 1, thickness: 1),
              // User list
              Expanded(
                child: viewLikes.isEmpty
                    ? Center(
                        child: Text(
                          'No likes yet',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: viewLikes.length,
                        itemBuilder: (context, index) {
                          final user = viewLikes[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundImage:
                                  user.profileImage != null &&
                                      user.profileImage!.isNotEmpty
                                  ? MemoryImage(
                                      getProfileImage(user.profileImage)!,
                                    )
                                  : null,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                              child:
                                  user.profileImage == null ||
                                      user.profileImage!.isEmpty
                                  ? Text(
                                      user.username[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.username,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Optional: Add follow button or other actions
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text('Post', style: CustomTextStyles.appBarTitleText(context)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surface,
      ),
      body: FutureBuilder<UserPostModel?>(
        future: _postFuture, // Use the stored Future
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading post',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _postFuture = loadSinglePost(widget.postId);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // No data state
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 60, color: Colors.grey[400]),
                  SizedBox(height: 16.h),
                  Text(
                    'Post not found',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
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
                              radius: 20,
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
                                  userProvider.username ?? '',
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
                        SizedBox(height: 8.h),

                        // Post content
                        Text(
                          post.description,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8.h),

                        // Images
                        if (post.images.isNotEmpty)
                          SizedBox(
                            height: 150.h,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return _buildImagesStack(
                                  post.images,
                                  constraints.maxWidth,
                                );
                              },
                            ),
                          ),
                        SizedBox(height: 12.h),

                        // Like button and count
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              // Animated heart icon
                              Builder(
                                builder: (context) {
                                  debugPrint(
                                    'Building heart icon - isLike: $isLike',
                                  );
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) {
                                      return ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      );
                                    },
                                    child: isLike
                                        ? Image.asset(
                                            Assets.assetsImagesIcHeartFilled,
                                            key: const ValueKey('filled'),
                                            height: 23.h,
                                            width: 23.w,
                                          )
                                        : Image.asset(
                                            Assets.assetsImagesIcHeart,
                                            key: const ValueKey('outline'),
                                            height: 23.h,
                                            width: 23.w,
                                            color: const Color(0xFFC6C5C5),
                                          ),
                                  );
                                },
                              ),
                              SizedBox(width: 3.w),

                              // Like count
                              Text(
                                likesCount > 0
                                    ? LikeService.getLikesCountText(likesCount)
                                    : 'Like',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Who liked preview
                        if (viewLikes.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          GestureDetector(
                            onTap: _showLikedUsersBottomSheet,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar stack
                                SizedBox(
                                  height: 14.h,
                                  width:
                                      (viewLikes.take(3).length * 16.0) + 6.0,
                                  child: Stack(
                                    children: viewLikes
                                        .take(3)
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                          int index = entry.key;
                                          LikeUser user = entry.value;
                                          return Positioned(
                                            left: index * 16.0,
                                            child: CircleAvatar(
                                              radius: 9,
                                              backgroundColor: Colors.white,
                                              child: CircleAvatar(
                                                radius: 14,
                                                backgroundImage:
                                                    user.profileImage != null &&
                                                        user
                                                            .profileImage!
                                                            .isNotEmpty
                                                    ? MemoryImage(
                                                        getProfileImage(
                                                          user.profileImage,
                                                        )!,
                                                      )
                                                    : null,
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.15),
                                                child:
                                                    user.profileImage == null ||
                                                        user
                                                            .profileImage!
                                                            .isEmpty
                                                    ? Text(
                                                        user.username[0]
                                                            .toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 10.sp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                                SizedBox(width: 2.w),

                                // "Liked by" text
                                Expanded(
                                  child: RichText(
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.black87,
                                      ),
                                      children: _buildLikedByText(),
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

  Widget _buildImagesStack(List images, double availableWidth) {
    if (images.isEmpty) {
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

    List<Alignment> alignments = getAlignments(images.length);
    double imageHeight = 150.h;

    return SizedBox(
      height: imageHeight,
      width: availableWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: images
            .asMap()
            .entries
            .map<Widget>((entry) {
              int index = entry.key;
              dynamic imageData = entry.value;
              Alignment alignment = alignments[index];
              double imageWidth = (availableWidth * 0.7) - (index * 8.0);
              imageWidth = imageWidth < 60.w ? 60.w : imageWidth;

              return Align(
                alignment: alignment,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
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
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10.r),
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
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
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
    );
  }
}
