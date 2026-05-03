// ignore_for_file: deprecated_member_use, unused_local_variable, must_be_immutable, unused_element, avoid_function_literals_in_foreach_calls, dead_code, non_constant_identifier_names

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/services/api_service.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_config.dart';
import '../../../api/services/like/like_service.dart';
import '../../../api/services/share/share_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../../../core/utils/like_util.dart';
import '../dashboard/dashboard_import.dart';
import '../home_imports.dart';
import '../profile/public/public_profile.dart';
import '../rank/image/image_ranking.dart';
import '../rank/result/image/image_result_screen.dart';

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
  late List<HomeFeedLikeUser> viewLikes;
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
  Map<String, bool> pollResultsLoaded = {};

  bool _isLocalChased = false;
  Uint8List? _profileImageBytes;

  final Map<int, double> _cachedPercentages = {};

  final Map<int, bool> _animationDone = {};

  int getSelectionNumber(int imageNumber) {
    int index = selectionOrder.indexOf(imageNumber);
    return index == -1 ? 0 : index + 1;
  }

  bool isImageSelected(int imageNumber) => selectionOrder.contains(imageNumber);

  bool get areAllImagesSelected =>
      randomImageIndices.isNotEmpty &&
      selectionOrder.length == randomImageIndices.length;

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

    if (widget.post.user.profileImage != null &&
        widget.post.user.profileImage!.isNotEmpty) {
      _profileImageBytes = getProfileImage(widget.post.user.profileImage);
    }

    for (var poll in widget.post.polls) {
      pollTotalVotes[poll.id.toString()] = poll.totalVotes;
    }

    final alreadyVotedPolls = widget.post.polls
        .where((p) => p.isPolledByCurrentUser)
        .toList();

    if (alreadyVotedPolls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final poll in alreadyVotedPolls) {
          _fetchAndApplyPollResults(poll);
        }
      });
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
    final previousViewLikes = List<HomeFeedLikeUser>.from(viewLikes);

    setState(() {
      isLike = !isLike;
      if (isLike) {
        likesCount++;
        viewLikes.insert(
          0,
          HomeFeedLikeUser(
            id: currentUserId,
            username: currentUsername,
            profileImage: currentUserImage,
          ),
        );
        if (viewLikes.length > 3) viewLikes = viewLikes.take(3).toList();
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
        if (result.message.isNotEmpty) showToast(message: result.message);
      } else {
        isLike = result.isLiked;
        likesCount = result.likesCount;
      }
    });
  }

  Future<String?> _getCurrentUsername() async =>
      Provider.of<UserProvider>(context, listen: false).username;

  void _showCommentsBottomSheet(int postId) async {
    final currentUsername = await _getCurrentUsername();
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: currentUsername,
      onCommentsCountChanged: (newCount) =>
          setState(() => commentsCount = newCount),
    );
  }

  void _showLikedUsersBottomSheet() =>
      BottomSheetUtils.showLikedUsersBottomSheet(
        context: context,
        postId: widget.post.id,
      );

  void _showThingsPostVotersBottomSheet(HomeFeedPoll poll) {
    poll.options.sort((a, b) {
      if (a.rankPosition != null && b.rankPosition != null) {
        return a.rankPosition!.compareTo(b.rankPosition!);
      }
      return b.percentage.compareTo(a.percentage);
    });
    BottomSheetUtils.showThingsPostVotersBottomSheet(
      context: context,
      poll: poll,
      postId: widget.post.id,
    );
  }

  bool _hasImageOptions(HomeFeedPoll poll) =>
      poll.options.any((o) => o.image != null);

  bool _hasTextOptions(HomeFeedPoll poll) =>
      poll.options.any((o) => o.text != null && o.text!.isNotEmpty);

  List<PollOptionImage> _getPollImages(HomeFeedPoll poll) =>
      poll.options.where((o) => o.image != null).map((o) => o.image!).toList();

  // void _showAllImagesGrid(List<PollOptionImage> images, HomeFeedPoll poll) {
  //   Navigator.of(context)
  //       .push(
  //         MaterialPageRoute(
  //           builder: (_) => AllImagesPopup(
  //             images: poll.options,
  //             postId: widget.post.id,
  //             pollId: poll.id,
  //             onImageTap: (_) {},
  //             isPolledByCurrentUser: poll.isPolledByCurrentUser,
  //           ),
  //         ),
  //       )
  //       .then((result) {
  //         if (result == true) setState(() {});
  //       });
  // }

  void _showAllImagesGrid(
    List<PollOptionImage> images,
    HomeFeedPost post,
    HomeFeedPoll poll,
  ) {
    if (poll.isPolledByCurrentUser) {
      // ── Already voted → show results
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ImageResultScreen(user: post.user, poll: poll, post: post),
        ),
      );
    } else {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => ImageRanking(
                user: post.user,
                poll: poll,
                post: post,
                question: poll.question,
                images: poll.options,
                createdAt: post.createdAt,
                postId: post.id,
                pollId: poll.id,
              ),
            ),
          )
          .then((result) {
            if (result == true) setState(() {});
          });
    }
  }

  Future<void> _submitPollVotes(HomeFeedPoll poll) async {
    final pollKey = poll.id.toString();
    final previousSelected = List<int>.from(selectedOptions[pollKey] ?? []);
    final previousIsPolled = poll.isPolledByCurrentUser;
    final previousTotalVotes = poll.totalVotes;
    final previousPercentages = poll.options.map((o) => o.percentage).toList();

    setState(() {
      pollVotingStates[pollKey] = true;
      selectedOptions[pollKey] = [];
    });

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < previousSelected.length; i++) {
        final option = poll.options[previousSelected[i]];
        votes.add({'option_id': option.id, 'rank': i + 1});
      }

      final result = await ApiService.voteOnPollMultiple(
        postId: widget.post.id,
        votes: votes,
      );

      if (result['success']) {
        await _fetchAndApplyPollResults(poll);

        if (mounted) {
          setState(() {
            poll.isPolledByCurrentUser = true;
            pollResultsLoaded[pollKey] = true;
            pollVotingStates[pollKey] = false;
          });
        }

        showToast(message: 'Vote submitted successfully!');
        _notifyDashboardOfUpdate();
        Future.delayed(
          const Duration(milliseconds: 500),
          _refreshHomeFeedSilently,
        );
      } else {
        setState(() {
          poll.isPolledByCurrentUser = previousIsPolled;
          poll.totalVotes = previousTotalVotes;
          for (int i = 0; i < poll.options.length; i++) {
            if (i < previousPercentages.length) {
              poll.options[i].percentage = previousPercentages[i];
            }
          }
          selectedOptions[pollKey] = previousSelected;
          pollVotingStates[pollKey] = false;
        });
        showToast(
          message:
              result['message'] ?? 'Failed to submit votes. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Error submitting poll votes: $e');
      setState(() {
        poll.isPolledByCurrentUser = previousIsPolled;
        poll.totalVotes = previousTotalVotes;
        for (int i = 0; i < poll.options.length; i++) {
          if (i < previousPercentages.length) {
            poll.options[i].percentage = previousPercentages[i];
          }
        }
        selectedOptions[pollKey] = previousSelected;
        pollVotingStates[pollKey] = false;
      });
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  Future<void> _fetchAndApplyPollResults(HomeFeedPoll poll) async {
    try {
      final Map<String, dynamic> response = await ApiService().getPollResults(
        widget.post.id,
      );

      if (!mounted) return;
      if (response['status'] != 'success') return;

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final int totalVotes = (data['total_votes'] as int?) ?? poll.totalVotes;
      final List<dynamic> results = data['results'] as List<dynamic>? ?? [];

      final Map<int, int> optionRankMap = {};
      for (int i = 0; i < results.length; i++) {
        final r = results[i] as Map<String, dynamic>;
        optionRankMap[r['option_id'] as int] = i;
      }

      if (!mounted) return;

      setState(() {
        pollTotalVotes[poll.id.toString()] = totalVotes;
        poll.totalVotes = totalVotes;

        for (final dynamic item in results) {
          final r = item as Map<String, dynamic>;
          final int optionId = r['option_id'] as int;
          final double pct = (r['percentage'] as num?)?.toDouble() ?? 0.0;
          final int rank1Count = r['rank_1_count'] as int? ?? 0;

          _cachedPercentages[optionId] = pct;
          _animationDone[optionId] = false;

          for (final option in poll.options) {
            if (option.id == optionId) {
              option.percentage = pct;
              option.rank1Count = rank1Count;
              option.rankPosition = optionRankMap[optionId] ?? 999;
              break;
            }
          }
        }

        poll.options.sort((a, b) {
          final aRank = a.rankPosition ?? 999;
          final bRank = b.rankPosition ?? 999;
          return aRank.compareTo(bRank);
        });
      });
    } catch (e) {
      debugPrint('Error fetching poll results: $e');
    }
  }

  void _notifyDashboardOfUpdate() {
    try {
      context.findAncestorStateOfType<DashboardState>()?.notifyPostsChanged();
    } catch (e) {
      debugPrint('Could not notify dashboard: $e');
    }
  }

  void _refreshHomeFeedSilently() {
    try {
      context.findAncestorStateOfType<DashboardState>()?.fetchHomeFeed(
        showLoader: false,
      );
    } catch (e) {
      debugPrint('Could not refresh home feed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPolls = widget.post.polls.isNotEmpty;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!hasPolls) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 15.h),
          padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
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
                        if (widget.post.user.userid == userProvider.userId) {
                          final homeScreenState = context
                              .findAncestorStateOfType<HomeScreenState>();
                          if (homeScreenState != null) {
                            homeScreenState.setState(
                              () => homeScreenState.pageIndex = 4,
                            );
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
                        radius: 17,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.15),
                        backgroundImage: _profileImageBytes != null
                            ? MemoryImage(_profileImageBytes!)
                            : null,
                        child:
                            widget.post.user.profileImage == null ||
                                widget.post.user.profileImage!.isEmpty
                            ? Text(
                                widget.post.user.firstLetter,
                                style: AppTextStyles.cardTitle.copyWith(
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
                          style: AppTextStyles.subText.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        Text(
                          'Placed a post',
                          style: AppTextStyles.subText.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.post.followingStatus == 'none' &&
                        widget.post.user.userid != user_id)
                      GestureDetector(
                        onTap: () async {
                          if (_isLocalChased) {
                            setState(() => _isLocalChased = false);
                            try {
                              await ApiService().unfriend(
                                widget.post.user.userid,
                              );
                            } catch (e) {
                              setState(() => _isLocalChased = true);
                            }
                          } else {
                            setState(() => _isLocalChased = true);
                            try {
                              await ApiService().sendFriendRequest(
                                widget.post.user.username,
                              );
                            } catch (e) {
                              setState(() => _isLocalChased = false);
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _isLocalChased
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            _isLocalChased ? 'Chased' : 'Chase',
                            style: AppTextStyles.subText.copyWith(
                              color: _isLocalChased
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                if (hasPolls) ..._buildPollContent(),

                /*──── Actions ────*/
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: isLike
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
                            style: AppTextStyles.subText.copyWith(
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
                      onTap: () => _showCommentsBottomSheet(widget.post.id),
                      child: Row(
                        children: [
                          AppIcons.commnetBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.6),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            commentsCount > 0 ? '$commentsCount' : '',
                            style: AppTextStyles.subText.copyWith(
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
                      onTap: () =>
                          ShareService.sharePost(widget.post, context: context),
                      child: AppIcons.sharePost(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),

                viewLikes.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: _showLikedUsersBottomSheet,
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
        final images = _getPollImages(poll);
        if (images.isNotEmpty) {
          widgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poll.question.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  Text(
                    poll.question,
                    style: AppTextStyles.bodyText.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                Container(
                  margin: EdgeInsets.only(top: 8.h),
                  height: 150.h,
                  width: double.infinity,
                  child: _buildImagesStack(images, widget.post, poll),
                ),
                SizedBox(height: 5.h),
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

  Widget _buildImagesStack(
    List<PollOptionImage> images,
    HomeFeedPost post,
    HomeFeedPoll poll,
  ) {
    List<Alignment> getAlignments(int n) {
      switch (n) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return GestureDetector(
          onTap: () => _showAllImagesGrid(images, post, poll),
          child: SizedBox(
            height: h,
            width: w,
            child: Stack(
              children: images
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    final i = entry.key;
                    final img = entry.value;
                    double imgW = (w * 0.7) - (i * 8.0);
                    imgW = imgW < 60.w ? 60.w : imgW;
                    return Align(
                      alignment: alignments[i],
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        width: imgW,
                        height: 150.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Image.network(
                            '${ApiConfig.baseUrlImage}${img.url}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                              size: 30,
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
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

  Widget _buildTextPollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final validOptions = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .toList();
    if (validOptions.isEmpty) return const SizedBox.shrink();

    final pollKey = poll.id.toString();
    final areAllOptionsSelected = _areAllPollOptionsSelected(poll);
    final isVoting = pollVotingStates[pollKey] ?? false;
    final displayVotes = pollTotalVotes[pollKey] ?? poll.totalVotes;
    final hasUserPolled = poll.isPolledByCurrentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5.h),
        Text(
          poll.question,
          style: AppTextStyles.bodyText.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 7.h),

        ...poll.options.asMap().entries.map((entry) {
          if (entry.value.text == null || entry.value.text!.isEmpty) {
            return const SizedBox.shrink();
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

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: !hasUserPolled && areAllOptionsSelected
              ? GestureDetector(
                  onTap: isVoting ? null : () => _submitPollVotes(poll),
                  child: Center(
                    key: ValueKey("analytics_${poll.id}"),
                    child: Container(
                      margin: EdgeInsets.only(top: 10.h),
                      height: 45.h,
                      width: 45.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
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
                              child: const CircularProgressIndicator(
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
                )
              : const SizedBox.shrink(),
        ),

        if (hasUserPolled)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showThingsPostVotersBottomSheet(poll),
                child: Text(
                  'View votes',
                  style: AppTextStyles.subText.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  bool _areAllPollOptionsSelected(HomeFeedPoll poll) {
    final pollKey = poll.id.toString();
    if (!selectedOptions.containsKey(pollKey)) return false;
    final validCount = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .length;
    return selectedOptions[pollKey]!.length == validCount;
  }

  int? _getSelectionNumber(String pollKey, int optionIndex) {
    final selected = selectedOptions[pollKey];
    if (selected == null || !selected.contains(optionIndex)) return null;
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pollKey = poll.id.toString();
    final hasUserPolled = poll.isPolledByCurrentUser;

    final double cachedPct = _cachedPercentages[option.id] ?? 0.0;
    final int pctRounded = cachedPct.round();

    final bool alreadyAnimated = _animationDone[option.id] ?? false;
    final double tweenBegin = alreadyAnimated ? cachedPct / 100 : 0.0;
    final int intTweenBegin = alreadyAnimated ? pctRounded : 0;

    final bool isSelected =
        selectedOptions.containsKey(pollKey) &&
        selectedOptions[pollKey]!.contains(optionIndex);
    final int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: hasUserPolled
          ? null
          : () {
              setState(() {
                selectedOptions.putIfAbsent(pollKey, () => []);
                if (selectedOptions[pollKey]!.contains(optionIndex)) {
                  selectedOptions[pollKey]!.remove(optionIndex);
                } else {
                  selectedOptions[pollKey]!.add(optionIndex);
                }
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 10.h),
        height: 27.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          color: isDarkMode ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
          border: Border.all(
            color: isSelected && !hasUserPolled
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : isDarkMode
                ? const Color(0xFF30353D)
                : const Color(0xFFE8E8E8),
            width: isSelected && !hasUserPolled ? 1.2 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (showPercentage && pctRounded > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bar_${option.id}_$pctRounded'),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: tweenBegin, end: cachedPct / 100),
                  onEnd: () {
                    if (mounted) {
                      setState(() => _animationDone[option.id] = true);
                    }
                  },
                  builder: (_, value, __) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF30353D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 5.h, 8.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.text ?? '',
                      style: AppTextStyles.subText.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: isSelected && !hasUserPolled
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  if (showPercentage) ...[
                    TweenAnimationBuilder<int>(
                      key: ValueKey('pct_${option.id}_$pctRounded'),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      tween: IntTween(begin: intTweenBegin, end: pctRounded),
                      builder: (_, value, __) => Text(
                        '$value%',
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else if (isSelected)
                    Text(
                      '$selectionNumber',
                      style: AppTextStyles.subText.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
