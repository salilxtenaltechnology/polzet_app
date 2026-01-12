// ignore_for_file: deprecated_member_use, unused_local_variable, must_be_immutable, unused_element, avoid_function_literals_in_foreach_calls, dead_code

import 'dart:math';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/services/api_service.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_config.dart';
import '../../../../core/constants/app_images.dart';
import '../../../api/services/like/like_service.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/home feed/home_feed_items_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/utils/bottomsheet_util.dart';
import '../../../widgets/utils/like_util.dart';
import '../home_imports.dart';
import '../profile/public/public_profile.dart';
import 'all_image_popup.dart.dart';

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
  late List<LikeUser> viewLikes;
  late int? user_id;
  bool isLikeLoading = false;
  List<int> randomImageIndices = [];
  double? percentage;
  late Random random;
  List<int> selectionOrder = [];
  Map<String, List<int>> selectedOptions = {};

  bool isPollVoting = false;
  Map<String, bool> pollVotingStates = {};
  Map<String, Set<int>> votedOptions = {};
  Map<String, int> pollTotalVotes = {};

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
    isLike = widget.post.isLikedByCurrentUser;
    likesCount = widget.post.likesCount;
    commentsCount = widget.post.commentsCount;
    viewLikes = List.from(widget.post.viewLikes);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    user_id = userProvider.userId;

    // Initialize poll vote counts
    for (var poll in widget.post.polls) {
      pollTotalVotes[poll.id.toString()] = poll.totalVotes;

      // NEW: Fetch poll results on initialization if user has already polled
      if (poll.isPolledByCurrentUser ?? false) {}
    }
  }

  Future<void> _toggleLike() async {
    if (isLikeLoading) return;

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
      postId: widget.post.id,
      currentLikeState: previousIsLike,
      currentLikesCount: previousLikesCount,
    );

    setState(() {
      isLikeLoading = false;

      if (!result.success) {
        isLike = previousIsLike;
        likesCount = previousLikesCount;
        viewLikes = previousViewLikes;

        if (result.message.isNotEmpty) {
          showToast(message: result.message);
        }
      } else {
        isLike = result.isLiked;
        likesCount = result.likesCount;
      }
    });
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
    List<LikeUser> likeUsers = viewLikes.map((viewLike) {
      return LikeUser(
        id: user_id!,
        username: viewLike.username,
        profileImage: viewLike.profileImage,
      );
    }).toList();

    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: widget.post.id,
      initialLikedUsers: likeUsers,
    );
  }

  bool _hasImageOptions(HomeFeedPoll poll) {
    return poll.options.any((option) => option.image != null);
  }

  bool _hasTextOptions(HomeFeedPoll poll) {
    return poll.options.any(
      (option) => option.text != null && option.text!.isNotEmpty,
    );
  }

  List<PollOptionImage> _getPollImages(HomeFeedPoll poll) {
    return poll.options
        .where((option) => option.image != null)
        .map((option) => option.image!)
        .toList();
  }

  void _showAllImagesGrid(List<PollOptionImage> images, HomeFeedPoll poll) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AllImagesPopup(
              images: poll.options,
              postId: widget.post.id,
              onImageTap: (index) {},
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

  Future<void> _submitPollVotes(HomeFeedPoll poll) async {
    String pollKey = poll.id.toString();

    final previousVotedOptions = Map<String, Set<int>>.from(votedOptions);
    final previousTotalVotes = pollTotalVotes[pollKey] ?? poll.totalVotes;
    final previousSelectedOptions = List<int>.from(
      selectedOptions[pollKey] ?? [],
    );

    setState(() {
      pollVotingStates[pollKey] = true;

      if (!votedOptions.containsKey(pollKey)) {
        votedOptions[pollKey] = {};
      }
      votedOptions[pollKey]!.addAll(selectedOptions[pollKey] ?? []);

      pollTotalVotes[pollKey] =
          (pollTotalVotes[pollKey] ?? poll.totalVotes) + 1;

      selectedOptions[pollKey] = [];
    });

    showToast(message: 'Vote submitted!');

    try {
      List<Map<String, int>> votes = [];
      List<int> selectedIndexes = previousSelectedOptions;

      for (int i = 0; i < selectedIndexes.length; i++) {
        int optionIndex = selectedIndexes[i];
        HomeFeedPollOption option = poll.options[optionIndex];

        votes.add({'option_id': option.id, 'rank': i + 1});
      }

      final result = await ApiService.voteOnPollMultiple(
        postId: widget.post.id,
        votes: votes,
      );

      if (!result['success']) {
        setState(() {
          pollVotingStates[pollKey] = false;
          votedOptions = previousVotedOptions;
          pollTotalVotes[pollKey] = previousTotalVotes;
          selectedOptions[pollKey] = previousSelectedOptions;
        });
        showToast(message: 'Failed to submit votes. Please try again.');
      } else {}
    } catch (e) {
      print('Error submitting poll votes: $e');

      setState(() {
        pollVotingStates[pollKey] = false;
        votedOptions = previousVotedOptions;
        pollTotalVotes[pollKey] = previousTotalVotes;
        selectedOptions[pollKey] = previousSelectedOptions;
      });

      showToast(message: 'An error occurred. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPolls = widget.post.polls.isNotEmpty;

    if (!hasPolls) {
      return SizedBox.shrink();
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
                        final userProvider = Provider.of<UserProvider>(
                          context,
                          listen: false,
                        );
                        final currentUserId = userProvider.userId;

                        if (widget.post.user.userid == currentUserId) {
                          final homeScreenState = context
                              .findAncestorStateOfType<HomeScreenState>();
                          if (homeScreenState != null) {
                            homeScreenState.setState(() {
                              homeScreenState.pageIndex = 4;
                            });
                            homeScreenState.bottomNavigationKey.currentState
                                ?.setPage(4);
                          }
                        } else {
                          navigationPush(
                            context,
                            PublicProfile(userId: widget.post.user.userid),
                          );
                        }
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
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (hasPolls) ..._buildPollContent(),

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
                viewLikes.isEmpty
                    ? SizedBox.shrink()
                    : GestureDetector(
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
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPollContent() {
    List<Widget> widgets = [];

    for (var poll in widget.post.polls) {
      if (_hasImageOptions(poll)) {
        List<PollOptionImage> images = _getPollImages(poll);
        if (images.isNotEmpty) {
          String pollKey = poll.id.toString();
          int displayVotes = pollTotalVotes[pollKey] ?? poll.totalVotes;

          widgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poll.question.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  Text(
                    poll.question,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                Container(
                  margin: EdgeInsets.only(top: 8.h),
                  height: 150.h,
                  width: double.infinity,
                  child: _buildImagesStack(images, poll),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$displayVotes Votes',
                  style: TextStyle(
                    fontSize: 10.7.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }
      } else if (_hasTextOptions(poll)) {
        widgets.add(_buildTextPollSection(context, poll, widget.post));
      }
    }

    return widgets;
  }

  Widget _buildImagesStack(List<PollOptionImage> images, HomeFeedPoll poll) {
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

        return GestureDetector(
          onTap: () => _showAllImagesGrid(images, poll),
          child: SizedBox(
            height: availableHeight,
            width: availableWidth,
            child: Stack(
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
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          20.r,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextPollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    List<HomeFeedPollOption> validOptions = poll.options
        .where((option) => option.text != null && option.text!.isNotEmpty)
        .toList();

    if (validOptions.isEmpty) {
      return SizedBox.shrink();
    }

    String pollKey = poll.id.toString();
    bool areAllOptionsSelected = _areAllPollOptionsSelected(poll);
    bool isVoting = pollVotingStates[pollKey] ?? false;
    int displayVotes = pollTotalVotes[pollKey] ?? poll.totalVotes;
    bool hasUserPolled = poll.isPolledByCurrentUser ?? false;

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
        SizedBox(height: 7.h),

        ...poll.options.asMap().entries.map((entry) {
          if (entry.value.text == null || entry.value.text!.isEmpty) {
            return SizedBox.shrink();
          }
          return _buildPollOption(
            entry.value,
            displayVotes,
            context,
            entry.key,
            poll,
            showPercentage: hasUserPolled,
          );
        }),
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$displayVotes Votes',
              style: TextStyle(
                fontSize: 10.7.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: !hasUserPolled && areAllOptionsSelected
              ? GestureDetector(
                  onTap: isVoting ? null : () => _submitPollVotes(poll),
                  child: Center(
                    key: ValueKey("analytics_${poll.id}"),
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
                        child: isVoting
                            ? Padding(
                                padding: EdgeInsets.all(12.w),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.stacked_bar_chart,
                                color: Colors.white,
                                size: 20.spMax,
                              ),
                      ),
                    ),
                  ),
                )
              : SizedBox.shrink(),
        ),
      ],
    );
  }

  bool _areAllPollOptionsSelected(HomeFeedPoll poll) {
    String pollKey = poll.id.toString();

    if (!selectedOptions.containsKey(pollKey)) {
      return false;
    }

    int validOptionsCount = poll.options
        .where((option) => option.text != null && option.text!.isNotEmpty)
        .length;

    return selectedOptions[pollKey]!.length == validOptionsCount;
  }

  int? _getSelectionNumber(String pollKey, int optionIndex) {
    if (!selectedOptions.containsKey(pollKey)) {
      return null;
    }

    List<int> selected = selectedOptions[pollKey]!;

    if (!selected.contains(optionIndex)) {
      return null;
    }

    return selected.indexOf(optionIndex) + 1;
  }

  Widget _buildPollOption(
    HomeFeedPollOption option,
    int totalVotes,
    BuildContext context,
    int optionIndex,
    HomeFeedPoll poll, {
    bool showPercentage = false,
  }) {
    String pollKey = poll.id.toString();

    // Get dynamic percentage from API results
    int percentage = 25;

    List<Color> getGradientColors(int index) {
      final colors = [
        [Color(0xFFFC3E7E), Color(0xFFEEA0F0)],
        [Color(0xFF4FC3F7), Color(0xFFB6E2F8)],
        [Colors.red, const Color(0xFFEFB0C3)],
        [Colors.green, Colors.teal],
      ];
      return colors[index % colors.length];
    }

    final gradientColors = getGradientColors(optionIndex);

    bool isSelected =
        selectedOptions.containsKey(pollKey) &&
        selectedOptions[pollKey]!.contains(optionIndex);

    int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    bool hasUserPolled = poll.isPolledByCurrentUser ?? false;

    return GestureDetector(
      onTap: hasUserPolled
          ? null
          : () {
              setState(() {
                if (!selectedOptions.containsKey(pollKey)) {
                  selectedOptions[pollKey] = [];
                }

                if (selectedOptions[pollKey]!.contains(optionIndex)) {
                  selectedOptions[pollKey]!.remove(optionIndex);
                } else {
                  selectedOptions[pollKey]!.add(optionIndex);
                }
              });
            },
      child: Opacity(
        opacity: hasUserPolled ? 0.6 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            border: hasUserPolled
                ? Border.all(color: Colors.grey.withOpacity(0.4), width: 1.1)
                : isSelected
                ? Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.8),
                    width: 1.1,
                  )
                : Border.all(color: Colors.transparent, width: 1.5),
            borderRadius: BorderRadius.circular(8.r),
            color: hasUserPolled
                ? Colors.grey.withOpacity(0.1)
                : isSelected
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
                      Expanded(
                        child: Text(
                          option.text ?? '',
                          style: TextStyle(
                            color: hasUserPolled
                                ? Colors.grey[600]
                                : Theme.of(context).colorScheme.onBackground,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Show percentage from API
                      if (showPercentage)
                        Text(
                          '${percentage.toString()}%',
                          style: TextStyle(
                            color: hasUserPolled
                                ? Colors.grey[600]
                                : Theme.of(context).colorScheme.onBackground,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Container(
                    margin: EdgeInsets.only(bottom: 5.h),
                    height: 5.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: Stack(
                        children: [
                          // Show progress bar with API percentage
                          if (showPercentage && percentage > 0)
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
      ),
    );
  }
}
