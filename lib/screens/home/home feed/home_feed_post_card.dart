// ignore_for_file: deprecated_member_use, unused_local_variable, must_be_immutable, unused_element, avoid_function_literals_in_foreach_calls, dead_code

import 'dart:math';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_config.dart';
import '../../../../core/constants/app_images.dart';
import '../../../api/services/api_service.dart';
import '../../../api/services/like/like_service.dart';
import '../../../models/home feed/home_feed_items_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/utils/bottomsheet_util.dart';
import '../../../widgets/utils/like_util.dart';

class HomeFeedPostCard extends StatefulWidget {
  final HomeFeedPost post;
  final VoidCallback? onPressed;
  Function(List<int>)? onImageSelectionChanged;

  HomeFeedPostCard({
    super.key,
    required this.post,
    this.onPressed,
    this.onImageSelectionChanged,
  });

  @override
  State<HomeFeedPostCard> createState() => _HomeFeedPostCardState();
}

class _HomeFeedPostCardState extends State<HomeFeedPostCard> with UtilityMixin {
  late bool isLike;
  late int likesCount;
  late int commentsCount;
  bool isLikeLoading = false;
  List<int> randomImageIndices = [];
  late Random random;
  List<int> selectionOrder = [];
  Map<String, List<int>> selectedOptions = {};

  int getSelectionNumber(int imageNumber) {
    int index = selectionOrder.indexOf(imageNumber);
    return index == -1 ? 0 : index + 1;
  }

  bool isImageSelected(int imageNumber) {
    return selectionOrder.contains(imageNumber);
  }

  bool get areAllImagesSelected {
    return randomImageIndices.isNotEmpty &&
        selectionOrder.length == randomImageIndices.length;
  }

  List<int> get selectedImageIndices {
    List<int> indices = [];
    selectionOrder.forEach((number) {
      if (number <= randomImageIndices.length) {
        indices.add(randomImageIndices[number - 1]);
      }
    });
    return indices;
  }

  List<int> get unselectedImageIndices {
    Set<int> selectedSet = selectedImageIndices.toSet();
    return randomImageIndices
        .where((index) => !selectedSet.contains(index))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    random = Random();
    _generateRandomImageIndices();
    isLike = widget.post.isLikedByCurrentUser;
    likesCount = widget.post.likesCount;
    commentsCount = widget.post.commentsCount;
  }

  void _generateRandomImageIndices() {
    if (widget.post.images.isNotEmpty) {
      List<int> allIndices = List.generate(
        widget.post.images.length,
        (index) => index,
      );

      allIndices.shuffle(random);
      int maxImages = widget.post.images.length >= 4
          ? 4
          : widget.post.images.length;
      randomImageIndices = allIndices.take(maxImages).toList();
    }
  }

  Future<void> _toggleLike() async {
    if (isLikeLoading) return;

    setState(() {
      isLikeLoading = true;
    });

    final result = await LikeService().togglePostLike(
      context: context,
      postId: widget.post.id,
      currentLikeState: isLike,
      currentLikesCount: likesCount,
    );

    setState(() {
      if (result.success) {
        isLike = result.isLiked;
        likesCount = result.likesCount;
      }
      isLikeLoading = false;
    });

    if (!result.success && result.message.isNotEmpty) {
      print('Like error: ${result.message}');
    }
  }

  Future<String?> _getCurrentUsername() async {
    return Provider.of<UserProvider>(context, listen: false).username;
  }

  void _showCommentsBottomSheet(int postId) async {
    final currentUsername = await _getCurrentUsername();

    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: currentUsername,
      onCommentsCountChanged: (newCount) {
        setState(() => commentsCount = newCount);
      },
    );
  }

  void _showLikedUsersBottomSheet() {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: widget.post.id,
      initialLikedUsers: widget.post.viewLikes,
    );
  }

  Future<void> _submitAllImageVotes() async {
    if (!areAllImagesSelected || selectionOrder.isEmpty) {
      showToast(message: 'Please select all images first');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Loader(color: Theme.of(context).colorScheme.primary),
              SizedBox(height: 15.h),
              Text(
                'Submitting votes...',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );

    List<Map<String, dynamic>> results = [];
    int successCount = 0;
    int failureCount = 0;

    for (int i = 0; i < selectionOrder.length; i++) {
      int imageNumber = selectionOrder[i];
      int imageIndex = randomImageIndices[imageNumber - 1];
      final imageId = widget.post.images[imageIndex].id;

      final result = await ApiService.voteOnPoll(
        postId: widget.post.id,
        optionId: imageId,
      );

      print('IDs : ${result}');

      results.add({
        'selection_order': i + 1,
        'image_index': imageIndex,
        'option_id': imageId,
        'result': result,
      });

      if (result['success'] == true) {
        successCount++;
      } else {
        failureCount++;
      }

      if (i < selectionOrder.length - 1) {
        await Future.delayed(Duration(milliseconds: 300));
      }
    }

    if (mounted) Navigator.of(context).pop();
    
    if (failureCount == 0) {
      showToast(
        message: 'All votes submitted successfully! ($successCount/${selectionOrder.length})',
      );
      setState(() {
        selectionOrder.clear();
      });
    } else if (successCount > 0) {
      showToast(
        message: 'Partially completed: $successCount succeeded, $failureCount failed',
      );
    } else {
      showToast(message: 'Failed to submit votes. Please try again.');
    }

    if (kDebugMode) {
      print('Vote submission results:');
      for (var result in results) {
        print(
          'Selection ${result['selection_order']}: Option ID ${result['option_id']} - ${result['result']['success'] ? 'Success' : 'Failed'}',
        );
      }
    }
  }

  Future<void> _submitAllPollVotes(HomeFeedPoll poll) async {
    String pollKey = poll.id.toString();

    if (!selectedOptions.containsKey(pollKey) ||
        selectedOptions[pollKey]!.isEmpty) {
      showToast(message: 'Please select poll options first');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Loader(color: Theme.of(context).colorScheme.primary),
              SizedBox(height: 15.h),
              Text(
                'Submitting votes...',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );

    List<Map<String, dynamic>> results = [];
    int successCount = 0;
    int failureCount = 0;
    List<int> selectedIndices = selectedOptions[pollKey]!;

    for (int i = 0; i < selectedIndices.length; i++) {
      int optionIndex = selectedIndices[i];
      final option = poll.options[optionIndex];

      final result = await ApiService.voteOnPoll(
        postId: widget.post.id,
        optionId: option.id,
      );

      results.add({
        'selection_order': i + 1,
        'option_index': optionIndex,
        'option_id': option.id,
        'option_text': option.text,
        'result': result,
      });

      if (result['success'] == true) {
        successCount++;
      } else {
        failureCount++;
      }

      if (i < selectedIndices.length - 1) {
        await Future.delayed(Duration(milliseconds: 300));
      }
    }

    if (mounted) Navigator.of(context).pop();

    if (failureCount == 0) {
      showToast(
        message: 'All votes submitted successfully! ($successCount/${selectedIndices.length})',
      );
      setState(() {
        selectedOptions[pollKey] = [];
      });
    } else if (successCount > 0) {
      showToast(
        message: 'Partially completed: $successCount succeeded, $failureCount failed',
      );
    } else {
      showToast(message: 'Failed to submit votes. Please try again.');
    }

    if (kDebugMode) {
      print('Poll vote submission results:');
      for (var result in results) {
        print(
          'Selection ${result['selection_order']}: ${result['option_text']} (ID: ${result['option_id']}) - ${result['result']['success'] ? 'Success' : 'Failed'}',
        );
      }
    }
  }

  void _showImageVotersBottomSheet(HomeFeedPostImage image) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Poll results',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${image.voteCount} ${image.voteCount == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: image.userList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 50.sp,
                            color: Colors.grey.withOpacity(0.4),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            'No votes yet',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      itemCount: image.userList.length,
                      itemBuilder: (context, index) {
                        final user = image.userList[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 15.r,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15),
                            backgroundImage:
                                user.profileImage != null &&
                                    user.profileImage!.isNotEmpty
                                ? MemoryImage(
                                    getProfileImage(user.profileImage)!,
                                  )
                                : null,
                            child:
                                user.profileImage == null ||
                                    user.profileImage!.isEmpty
                                ? Text(
                                    user.firstLetter,
                                    style: TextStyle(
                                      fontSize: 14.sp,
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
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImages = widget.post.images.isNotEmpty;
    final bool hasPolls = widget.post.polls.isNotEmpty;

    if (!hasImages && !hasPolls) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 15.h),
          padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(30, 0, 0, 0),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(right: 10.w, left: 10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigationPush(
                          context,
                          PublicProfile(userId: widget.post.user.userid),
                        );
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.15),
                        backgroundImage:
                            widget.post.user.profileImage != null &&
                                widget.post.user.profileImage!.isNotEmpty
                            ? MemoryImage(
                                getProfileImage(widget.post.user.profileImage)!,
                              )
                            : null,
                        child:
                            widget.post.user.profileImage == null ||
                                widget.post.user.profileImage!.isEmpty
                            ? Text(
                                widget.post.user.firstLetter,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.user.username,
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

                if (hasImages)
                  Container(
                    margin: EdgeInsets.only(top: 8.h),
                    height: 150.h,
                    width: double.infinity,
                    child: _buildImagesStack(widget.post.images),
                  ),

                if (hasPolls) _buildPollsSection(context),

                SizedBox(height: 3.h),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: isLike
                                ? Image.asset(
                                    Assets.assetsImagesIcHeartFilled,
                                    key: ValueKey('filled'),
                                    height: 23.h,
                                    width: 23.w,
                                  )
                                : Image.asset(
                                    Assets.assetsImagesIcHeart,
                                    key: ValueKey('outline'),
                                    height: 23.h,
                                    width: 23.w,
                                    color: Color(0xFFC6C5C5),
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
                    SizedBox(width: 10.w),
                    GestureDetector(
                      onTap: () => _showCommentsBottomSheet(widget.post.id),
                      child: Row(
                        children: [
                          Icon(
                            FeatherIcons.messageSquare,
                            size: 21.sp,
                            color: Color(0xFFC6C5C5),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            commentsCount > 0 ? '$commentsCount' : '',
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
                widget.post.viewLikes.isEmpty
                    ? SizedBox.shrink()
                    : GestureDetector(
                        onTap: _showLikedUsersBottomSheet,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            LikeUtils.buildLikeAvatarsStack(
                              context,
                              widget.post.viewLikes,
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
                                      widget.post.viewLikes,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: areAllImagesSelected
                      ? GestureDetector(
                          onTap: _submitAllImageVotes,
                          child: Center(
                            key: ValueKey("analytics_$areAllImagesSelected"),
                            child: AnimatedOpacity(
                              duration: Duration(milliseconds: 300),
                              opacity: 1.0,
                              child: Container(
                                margin: EdgeInsets.only(top: 10.h),
                                height: 45.h,
                                width: 45.w,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFCF4B73),
                                      Color(0xFFC76294),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground
                                          .withOpacity(0.3),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.analytics,
                                  color: Colors.white,
                                  size: 22.spMax,
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWithNumber(
    String imageUrl,
    int number,
    double height, {
    BoxFit fit = BoxFit.cover,
  }) {
    bool isSelected = isImageSelected(number);
    int selectionNumber = getSelectionNumber(number);

    // Get the actual image object
    int imageIndex = randomImageIndices[number - 1];
    final image = widget.post.images[imageIndex];

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isImageSelected(number)) {
            selectionOrder.remove(number);
          } else {
            selectionOrder.add(number);
          }
        });
        if (widget.onImageSelectionChanged != null) {
          widget.onImageSelectionChanged!(selectedImageIndices);
        }
      },
      onLongPress: () {
        // Show voters list on long press
        _showImageVotersBottomSheet(image);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image container
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  // Image with overlay when selected
                  Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        height: height,
                        width: double.infinity,
                        fit: fit,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: height,
                            color: Colors.grey[200],
                            child: Center(
                              child: Loader(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: height,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      if (isSelected)
                        Container(
                          height: height,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                    ],
                  ),
                  // Selection number (bottom-right, inside image)
                  if (isSelected)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 300),
                        opacity: 1.0,
                        child: Container(
                          width: 30.w,
                          height: 30.h,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$selectionNumber',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Voter avatars and count (outside, below the image)
          if (image.voteCount > 0)
            Padding(
              padding: EdgeInsets.only(top: 8.h, left: 4.w),
              child: GestureDetector(
                onTap: () => _showImageVotersBottomSheet(image),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stacked user avatars
                    SizedBox(
                      height: 24.h,
                      width: (image.userList.take(3).length * 16 + 8).w,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          for (
                            int i = 0;
                            i < image.userList.take(3).length;
                            i++
                          )
                            Positioned(
                              left: i * 14.0.w,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 12.r,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2),
                                  backgroundImage:
                                      image.userList[i].profileImage != null &&
                                          image
                                              .userList[i]
                                              .profileImage!
                                              .isNotEmpty
                                      ? MemoryImage(
                                          getProfileImage(
                                            image.userList[i].profileImage,
                                          )!,
                                        )
                                      : null,
                                  child:
                                      image.userList[i].profileImage == null ||
                                          image
                                              .userList[i]
                                              .profileImage!
                                              .isEmpty
                                      ? Text(
                                          image.userList[i].firstLetter,
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Vote count and text (Flexible for responsive wrapping)
                    Expanded(
                      child: Text(
                        '${image.voteCount}+ picked this as top choice',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagesStack(List images) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double availableHeight = constraints.maxHeight;
        double imageHeight = 150.h;

        return SizedBox(
          height: availableHeight,
          width: availableWidth,
          child: Stack(
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
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19.r),
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
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
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
                    ),
                  );
                })
                .toList()
                .reversed
                .toList(),
          ),
        );
      },
    );
  }

  // Widget _buildImagesSection(BuildContext context) {
  //   if (randomImageIndices.isEmpty) return const SizedBox.shrink();

  //   // Description widget (reusable)
  //   Widget buildDescription() {
  //     if (widget.post.description.isNotEmpty &&
  //         widget.post.description != 'fkglfd') {
  //       return Padding(
  //         padding: EdgeInsets.only(top: 5.h, bottom: 8.h),
  //         child: Text(
  //           widget.post.description,
  //           style: CustomTextStyles.lblSecondryText(context),
  //         ),
  //       );
  //     }
  //     return const SizedBox.shrink();
  //   }

  //   if (randomImageIndices.length == 1) {
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         buildDescription(),
  //         _buildImageWithNumber(
  //           '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[0]].url}',
  //           1,
  //           200.h,
  //         ),
  //       ],
  //     );
  //   } else if (randomImageIndices.length == 2) {
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         buildDescription(),
  //         Row(
  //           children: [
  //             Expanded(
  //               child: _buildImageWithNumber(
  //                 '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[0]].url}',
  //                 1,
  //                 150.h,
  //               ),
  //             ),
  //             SizedBox(width: 7.w),
  //             Expanded(
  //               child: _buildImageWithNumber(
  //                 '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[1]].url}',
  //                 2,
  //                 150.h,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     );
  //   } else if (randomImageIndices.length == 3) {
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         buildDescription(),
  //         Row(
  //           children: [
  //             Expanded(
  //               child: _buildImageWithNumber(
  //                 '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[0]].url}',
  //                 1,
  //                 150.h,
  //               ),
  //             ),
  //             SizedBox(width: 5.w),
  //             Expanded(
  //               child: _buildImageWithNumber(
  //                 '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[1]].url}',
  //                 2,
  //                 150.h,
  //               ),
  //             ),
  //             SizedBox(width: 5.w),
  //             Expanded(
  //               child: _buildImageWithNumber(
  //                 '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[2]].url}',
  //                 3,
  //                 150.h,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     );
  //   } else if (randomImageIndices.length >= 4) {
  //     // 4 or more images - show 2x2 grid
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         buildDescription(),
  //         Column(
  //           children: [
  //             // First row
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: _buildImageWithNumber(
  //                     '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[0]].url}',
  //                     1,
  //                     100.h,
  //                   ),
  //                 ),
  //                 SizedBox(width: 5.w),
  //                 Expanded(
  //                   child: _buildImageWithNumber(
  //                     '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[1]].url}',
  //                     2,
  //                     100.h,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             SizedBox(height: 5.h),
  //             // Second row
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: _buildImageWithNumber(
  //                     '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[2]].url}',
  //                     3,
  //                     100.h,
  //                   ),
  //                 ),
  //                 SizedBox(width: 5.w),
  //                 Expanded(
  //                   child: _buildImageWithNumber(
  //                     '${ApiConfig.baseUrlImage}${widget.post.images[randomImageIndices[3]].url}',
  //                     4,
  //                     100.h,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ],
  //     );
  //   }

  //   return const SizedBox.shrink();
  // }

  Widget _buildPollsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.post.polls.map((poll) {
        // Check if any option has null or empty text
        bool hasInvalidOption = poll.options.any(
          (option) => option.text.isEmpty,
        );

        // If any option is invalid, don't render this poll at all
        if (hasInvalidOption) {
          return SizedBox.shrink();
        }

        // Check if all options in this poll are selected
        String pollKey = poll.id.toString();
        bool areAllOptionsSelected = _areAllPollOptionsSelected(poll);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 5.h),
            Text(
              poll.question,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10.h),
            ...poll.options.asMap().entries.map(
              (entry) => _buildPollOption(
                entry.value,
                poll.totalVotes,
                context,
                entry.key,
                poll,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              '${poll.totalVotes.toString()} Votes',
              style: TextStyle(
                fontSize: 10.7.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),

            // Show analytics button when all options are selected
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: areAllOptionsSelected
                  ? Center(
                      key: ValueKey("analytics_$areAllImagesSelected"),
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 300),
                        opacity: 1.0,
                        child: Container(
                          height: 45.h,
                          width: 45.w,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFCF4B73), Color(0xFFC76294)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground.withOpacity(0.3),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.stacked_bar_chart,
                            color: Colors.white,
                            size: 20.spMax,
                          ),
                        ),
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          ],
        );
      }).toList(),
    );
  }

  // Helper method to check if all options in a poll are selected
  bool _areAllPollOptionsSelected(HomeFeedPoll poll) {
    String pollKey = poll.id.toString();

    // Check if this poll has selections and if all options are selected
    if (!selectedOptions.containsKey(pollKey)) {
      return false;
    }

    // Count only valid options (non-empty text)
    int validOptionsCount = poll.options
        .where((option) => option.text.isNotEmpty)
        .length;

    return selectedOptions[pollKey]!.length == validOptionsCount;
  }

  // Helper method to get selection number for an option
  int? _getSelectionNumber(String pollKey, int optionIndex) {
    if (!selectedOptions.containsKey(pollKey)) {
      return null;
    }

    // Get the list of selected indices in order of selection
    List<int> selected = selectedOptions[pollKey]!;

    // If this option is not selected, return null
    if (!selected.contains(optionIndex)) {
      return null;
    }

    // Return the position (1-indexed) based on when it was selected
    return selected.indexOf(optionIndex) + 1;
  }

  Widget _buildPollOption(
    HomeFeedPollOption option,
    int totalVotes,
    BuildContext context,
    int optionIndex,
    HomeFeedPoll poll,
  ) {
    final percentage = totalVotes > 0
        ? ((option.voteCount) / totalVotes * 100)
        : 0.0;

    // Define different gradient colors for dynamic options
    List<Color> getGradientColors(int index) {
      final colors = [
        [Color(0xFFFC3E7E), Color(0xFFEEA0F0)], // Option 1
        [Color(0xFF4FC3F7), Color(0xFFB6E2F8)], // Option 2
        [Colors.red, const Color(0xFFEFB0C3)], // Option 3
        [Colors.green, Colors.teal], // Option 4
      ];
      return colors[index % colors.length];
    }

    final gradientColors = getGradientColors(optionIndex);

    int percentageFull = 100;
    int totalVoteCount = ((option.voteCount * 100) / percentageFull).round();

    // Check if this option is selected
    String pollKey = poll.id.toString();
    bool isSelected =
        selectedOptions.containsKey(pollKey) &&
        selectedOptions[pollKey]!.contains(optionIndex);

    // Get selection number
    int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: () {
        // Handle option selection/deselection
        setState(() {
          // Initialize the list if it doesn't exist
          if (!selectedOptions.containsKey(pollKey)) {
            selectedOptions[pollKey] = [];
          }

          // Toggle selection
          if (selectedOptions[pollKey]!.contains(optionIndex)) {
            // If already selected, unselect it
            selectedOptions[pollKey]!.remove(optionIndex);
          } else {
            // If not selected, add it to the end (preserves selection order)
            selectedOptions[pollKey]!.add(optionIndex);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                  width: 1.1,
                )
              : Border.all(color: Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(8.r),
          color: isSelected
              ? const Color.fromARGB(24, 0, 0, 0)
              : Colors.transparent,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Show selection number if selected
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5.h),
                Container(
                  height: 5.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey[200], // Grey background for unfilled area
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: Stack(
                      children: [
                        // Only show filled area if total_vote_count > 0
                        if (totalVoteCount > 0)
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: totalVoteCount / 100,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${totalVoteCount.toInt()}%',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isSelected
                ? SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        '$selectionNumber',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
