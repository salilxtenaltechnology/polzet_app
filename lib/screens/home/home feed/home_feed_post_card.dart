// ignore_for_file: deprecated_member_use, unused_local_variable, must_be_immutable, unused_element, avoid_function_literals_in_foreach_calls, dead_code, non_constant_identifier_names

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/image/app_cached_network_image.dart';
import 'package:polzet_app/api/api_service.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_config.dart';
import '../../../api/services/like/like_service.dart';
import '../../../api/services/share/share_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/like/like_uers_model.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../../../core/utils/like_util.dart';
import '../dashboard/dashboard_import.dart';
import '../home_imports.dart';
import '../profile/public/public_profile_screen.dart';
import 'rank/image/homefeed_image_ranking.dart';
import 'rank/result/image/image_result_screen.dart';
import 'rank/result/things/things_result_screen.dart';
import 'rank/things/homefeed_things_ranking.dart';
import '../../../languages/l10n/generated/app_localizations.dart';

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

  static final Map<String, String> globallyChasedUserStates = {};
  static final Map<String, Timer> activeChaseTimers = {};

  @override
  State<HomeFeedPostCard> createState() => _HomeFeedPostCardState();
}

class _HomeFeedPostCardState extends State<HomeFeedPostCard> with UtilityMixin {
  late bool isLike;
  late int likesCount;
  late int commentsCount;
  late int sharesCount;
  List<LikeUser> viewLikes = [];
  late String? user_id;
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

  Uint8List? _profileImageBytes;

  final Map<int, double> _cachedPercentages = {};

  final Map<int, bool> _animationDone = {};

  @override
  void initState() {
    super.initState();
    random = Random();
    isLike = widget.post.isLikedByCurrentUser;
    likesCount = widget.post.likesCount;
    commentsCount = widget.post.commentsCount;
    viewLikes = [];
    sharesCount = widget.post.sharesCount;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    user_id = userProvider.userId;

    if (likesCount > 0) {
      _fetchLikedUsersSilently();
    }

    if (widget.post.followingStatus != 'none') {
      HomeFeedPostCard.globallyChasedUserStates[widget.post.user.userid] =
          'hidden';
    }

    if (widget.post.user.profileImage != null &&
        widget.post.user.profileImage!.isNotEmpty) {
      _profileImageBytes = getProfileImage(widget.post.user.profileImage);
    }

    for (var poll in widget.post.polls) {
      if (poll.totalVotes == 0) {
        int sum = 0;
        for (var option in poll.options) {
          sum += option.originalVoteCount;
        }
        if (sum > 0) {
          poll.totalVotes = sum;
        }
      }
      pollTotalVotes[poll.id.toString()] = poll.totalVotes;
      for (var option in poll.options) {
        option.voteCount = poll.totalVotes;
      }
    }

    final bool alreadyVoted = widget.post.isPolledByCurrentUser;

    if (alreadyVoted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final poll in widget.post.polls) {
          //3  _fetchAndApplyPollResults(poll);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeFeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.followingStatus != oldWidget.post.followingStatus) {
      if (widget.post.followingStatus != 'none') {
        HomeFeedPostCard.globallyChasedUserStates[widget.post.user.userid] =
            'hidden';
      }
    }
    for (var poll in widget.post.polls) {
      if (poll.totalVotes == 0) {
        int sum = 0;
        for (var option in poll.options) {
          sum += option.originalVoteCount;
        }
        if (sum > 0) {
          poll.totalVotes = sum;
        }
      }
      for (var option in poll.options) {
        option.voteCount = poll.totalVotes;
      }
    }
  }

  Future<void> _fetchLikedUsersSilently({bool force = false}) async {
    if (!force && viewLikes.isNotEmpty) return;
    try {
      final users = await ApiService().fetchLikedUsers(widget.post.id);
      if (mounted) {
        setState(() {
          viewLikes = users.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching liked users in HomeFeedPostCard: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (isLikeLoading) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId ?? '';
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

    if (result.success) {
      if (likesCount > 0) {
        _fetchLikedUsersSilently(force: true);
      } else {
        setState(() {
          viewLikes = [];
        });
      }
    }
  }

  Future<String?> _getCurrentUsername() async =>
      Provider.of<UserProvider>(context, listen: false).username;

  void _showCommentsBottomSheet(String postId) async {
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

  // void _showThingsPostVotersBottomSheet(HomeFeedPoll poll) {
  //   poll.options.sort((a, b) {
  //     if (a.rankPosition != null && b.rankPosition != null) {
  //       return a.rankPosition!.compareTo(b.rankPosition!);
  //     }
  //     return b.percentage.compareTo(a.percentage);
  //   });
  //   BottomSheetUtils.showThingsPollVotersBottomSheet(
  //     context: context,
  //     poll: poll,
  //     postId: widget.post.id,
  //   );
  // }

  bool _hasImageOptions(HomeFeedPoll poll) =>
      poll.options.any((o) => o.image != null);

  bool _hasTextOptions(HomeFeedPoll poll) =>
      poll.options.any((o) => o.text != null && o.text!.isNotEmpty);

  List<PollOptionImage> _getPollImages(HomeFeedPoll poll) =>
      poll.options.where((o) => o.image != null).map((o) => o.image!).toList();

  void _showAllImagesGrid(
    List<PollOptionImage> images,
    HomeFeedPost post,
    HomeFeedPoll poll,
  ) {
    if (post.isPolledByCurrentUser) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageResultScreen(
            username: post.user.username,
            postId: post.id.toString(),
          ),
        ),
      );
    } else {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => HomefeedImageRanking(
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

  String _getPercentageText(HomeFeedPoll poll, HomeFeedPollOption option) {
    final pollKey = poll.id.toString();
    if (pollVotingStates[pollKey] == true) {
      return "";
    }
    final percentage = option.percentage;
    final num val = percentage == percentage.toInt()
        ? percentage.toInt()
        : percentage;
    return "$val%";
  }

  String _getPercentageTextForValue(HomeFeedPoll poll, double percentage) {
    final pollKey = poll.id.toString();
    if (pollVotingStates[pollKey] == true) {
      return "";
    }
    final num val = percentage == percentage.toInt()
        ? percentage.toInt()
        : percentage;
    return "$val%";
  }

  Future<void> _submitPollVotes(HomeFeedPoll poll) async {
    final pollKey = poll.id.toString();
    final previousSelected = List<int>.from(selectedOptions[pollKey] ?? []);
    final previousIsPolled = widget.post.isPolledByCurrentUser;
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
        if (mounted) {
          setState(() {
            widget.post.isPolledByCurrentUser = true;
            pollResultsLoaded[pollKey] = true;
            pollVotingStates[pollKey] = false;
          });
        }

        showToast(message: 'Vote submitted!');
        _notifyDashboardOfUpdate();
        Future.delayed(
          const Duration(milliseconds: 500),
          _refreshHomeFeedSilently,
        );
      } else {
        setState(() {
          widget.post.isPolledByCurrentUser = previousIsPolled;
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
        widget.post.isPolledByCurrentUser = previousIsPolled;
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

  Future<void> _submitSinglePollVote(HomeFeedPoll poll, int optionId) async {
    final pollKey = poll.id.toString();
    final previousIsPolled = widget.post.isPolledByCurrentUser;
    final previousTotalVotes = poll.totalVotes;
    final previousPercentages = poll.options.map((o) => o.percentage).toList();

    setState(() {
      pollVotingStates[pollKey] = true;
    });

    try {
      final List<Map<String, int>> votes = [
        {'option_id': optionId, 'rank': 1},
      ];

      final result = await ApiService.voteOnPollSingle(
        postId: widget.post.id,
        votes: votes,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            widget.post.isPolledByCurrentUser = true;
            pollResultsLoaded[pollKey] = true;
            pollVotingStates[pollKey] = false;

            final responseOptions = result['data']?['options'];
            if (responseOptions is List && responseOptions.isNotEmpty) {
              for (final optionData in responseOptions) {
                if (optionData is! Map) continue;
                final rawId = optionData['option_id'];
                if (rawId == null) continue;
                final optId = rawId is int ? rawId : (rawId as num).toInt();
                final pct =
                    (optionData['percentage'] as num?)?.toDouble() ?? 0.0;

                for (var option in poll.options) {
                  if (option.id == optId) {
                    option.percentage = pct;
                  }
                }
              }
            }
          });
        }

        showToast(message: 'Vote submitted successfully!');
        _notifyDashboardOfUpdate();
        Future.delayed(
          const Duration(milliseconds: 500),
          _refreshHomeFeedSilently,
        );
      } else {
        if (mounted) {
          setState(() {
            widget.post.isPolledByCurrentUser = previousIsPolled;
            poll.totalVotes = previousTotalVotes;
            for (int i = 0; i < poll.options.length; i++) {
              if (i < previousPercentages.length) {
                poll.options[i].percentage = previousPercentages[i];
              }
            }
            pollVotingStates[pollKey] = false;
          });
        }
        showToast(
          message:
              result['message'] ?? 'Failed to submit vote. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Error submitting single poll vote: $e');
      if (mounted) {
        setState(() {
          widget.post.isPolledByCurrentUser = previousIsPolled;
          poll.totalVotes = previousTotalVotes;
          for (int i = 0; i < poll.options.length; i++) {
            if (i < previousPercentages.length) {
              poll.options[i].percentage = previousPercentages[i];
            }
          }
          pollVotingStates[pollKey] = false;
        });
      }
      showToast(message: 'An error occurred. Please try again.');
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

  String _timeAgo(DateTime dt) {
    try {
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      if (diff.inDays < 7) return '${diff.inDays} d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
      return '${(diff.inDays / 365).floor()} y ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final bool hasPolls = widget.post.polls.isNotEmpty;
    if (hasPolls) {
      for (var poll in widget.post.polls) {
        if (poll.totalVotes == 0) {
          int sum = 0;
          for (var option in poll.options) {
            sum += option.originalVoteCount;
          }
          if (sum > 0) {
            poll.totalVotes = sum;
          }
        }
        for (var option in poll.options) {
          option.voteCount = poll.totalVotes;
        }
      }
    }
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bool isAnonymous = widget.post.polls.any(
      (p) => p.pollType == 'anonymous',
    );

    final String chaseState =
        HomeFeedPostCard.globallyChasedUserStates[widget.post.user.userid] ??
        (widget.post.followingStatus != 'none' ? 'hidden' : 'none');

    if (!hasPolls || widget.post.polls.any((p) => p.options.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 15.h),
          padding: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (isAnonymous) return;
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
                            PublicProfileScreen(
                              username: widget.post.user.username,
                            ),
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 19.5,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.1),
                        backgroundImage: _profileImageBytes != null
                            ? MemoryImage(_profileImageBytes!)
                            : (widget.post.user.profileImage != null &&
                                      widget.post.user.profileImage!.isNotEmpty
                                  ? NetworkImage(widget.post.user.profileImage!)
                                  : null),
                        child:
                            _profileImageBytes == null &&
                                (widget.post.user.profileImage == null ||
                                    widget.post.user.profileImage!.isEmpty)
                            ? Text(
                                widget.post.user.firstLetter,
                                style: AppTextStyles.cardTitle.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.post.user.firstName != null ||
                                    widget.post.user.lastName != null
                                ? '${widget.post.user.firstName ?? 'Polzet'} ${widget.post.user.lastName ?? 'User'}'
                                      .trim()
                                : 'Polzet User'),
                            style: AppTextStyles.sectionHeading.copyWith(
                              color: txt.title,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@${widget.post.user.username}',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: txt.body,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '  • ${_timeAgo(DateTime.parse(widget.post.createdAt))}',
                                style: AppTextStyles.subText.copyWith(
                                  color: txt.muted,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (chaseState != 'hidden' &&
                        widget.post.user.username != userProvider.username) ...[
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () async {
                          final userId = widget.post.user.userid;
                          final username = widget.post.user.username;
                          final dashboardState = context
                              .findAncestorStateOfType<DashboardState>();

                          if (chaseState == 'chasing') {
                            // User wants to cancel request / unfriend
                            HomeFeedPostCard.activeChaseTimers[userId]
                                ?.cancel();
                            HomeFeedPostCard.activeChaseTimers.remove(userId);

                            setState(() {
                              HomeFeedPostCard
                                      .globallyChasedUserStates[userId] =
                                  'none';
                            });
                            _notifyDashboardOfUpdate();

                            try {
                              await ApiService().unfriend(userId);
                            } catch (e) {
                              debugPrint('Error unfriending user: $e');
                            }
                          } else {
                            // User wants to Chase
                            HomeFeedPostCard.activeChaseTimers[userId]
                                ?.cancel();

                            setState(() {
                              HomeFeedPostCard
                                      .globallyChasedUserStates[userId] =
                                  'chasing';
                            });
                            _notifyDashboardOfUpdate();

                            // Start a 10-second timer to hide the button
                            HomeFeedPostCard.activeChaseTimers[userId] = Timer(
                              const Duration(seconds: 10),
                              () {
                                HomeFeedPostCard
                                        .globallyChasedUserStates[userId] =
                                    'hidden';
                                HomeFeedPostCard.activeChaseTimers.remove(
                                  userId,
                                );
                                try {
                                  dashboardState?.notifyPostsChanged();
                                } catch (e) {
                                  debugPrint('Could not notify dashboard: $e');
                                }
                              },
                            );

                            try {
                              await ApiService().sendFriendRequest(username);
                            } catch (e) {
                              debugPrint('Error sending friend request: $e');
                              if (HomeFeedPostCard
                                      .globallyChasedUserStates[userId] ==
                                  'chasing') {
                                HomeFeedPostCard.activeChaseTimers[userId]
                                    ?.cancel();
                                HomeFeedPostCard.activeChaseTimers.remove(
                                  userId,
                                );
                                setState(() {
                                  HomeFeedPostCard
                                          .globallyChasedUserStates[userId] =
                                      'none';
                                });
                                _notifyDashboardOfUpdate();
                              }
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: chaseState == 'chasing'
                                ? Colors.transparent
                                : Theme.of(context).colorScheme.primary,
                            border: chaseState == 'chasing'
                                ? Border.all(
                                    color: isDarkMode
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.3)
                                        : Theme.of(context).colorScheme.primary
                                              .withOpacity(0.8),
                                    width: 1,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          child: Text(
                            chaseState == 'chasing' ? 'Chasing' : 'Chase',
                            style: AppTextStyles.subText.copyWith(
                              fontSize: 12.5,
                              color: chaseState == 'chasing'
                                  ? (isDarkMode
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.7)
                                        : Theme.of(context).colorScheme.primary)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),

              if (hasPolls) ..._buildPollContent(),

              /*──── Actions ────*/
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 5, 10.w, 0.h),
                child: Row(
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
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            likesCount > 0
                                ? LikeService.getLikesCountText(likesCount)
                                : '',
                            style: AppTextStyles.subText.copyWith(
                              color: txt.body,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
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
                          AppIcons.commnetBox(),
                          const SizedBox(width: 8),
                          Text(
                            commentsCount > 0 ? '$commentsCount' : '',
                            style: AppTextStyles.subText.copyWith(
                              color: txt.body,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () => ShareService.sharePost(
                        widget.post,
                        context: context,
                        onShareSuccess: (newCount) {
                          if (mounted) {
                            setState(() {
                              sharesCount = newCount;
                            });
                          }
                        },
                      ),
                      child: Row(
                        children: [
                          AppIcons.sharePost(),
                          const SizedBox(width: 8),
                          Text(
                            sharesCount > 0 ? '$sharesCount' : '',
                            style: AppTextStyles.subText.copyWith(
                              color: txt.body,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              viewLikes.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.fromLTRB(10.w, 3.h, 10.w, 0),
                      child: GestureDetector(
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
                    ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPollContent() {
    final txt = AppTextColors.of(context);
    List<Widget> widgets = [];
    for (var poll in widget.post.polls) {
      if (poll.pollType == 'battle') {
        widgets.add(_buildBattlePollSection(context, poll, widget.post));
      } else if (poll.pollType == 'hot_take') {
        widgets.add(_buildHotTakePollSection(context, poll, widget.post));
      } else if (poll.pollType == 'this_or_that') {
        widgets.add(_buildThisOrThatPollSection(context, poll, widget.post));
      } else if (poll.pollType == 'anonymous' &&
          _hasImageOptions(poll) &&
          _hasTextOptions(poll)) {
        widgets.add(
          _buildAnonymousImageTextPollSection(context, poll, widget.post),
        );
      } else if (_hasImageOptions(poll)) {
        final images = _getPollImages(poll);
        if (images.isNotEmpty) {
          if (poll.vottingType == 'single_choice') {
            widgets.add(
              _buildSingleChoiceImagePollSection(context, poll, widget.post),
            );
          } else {
            widgets.add(
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (poll.question.isNotEmpty) ...[
                      SizedBox(height: 5.h),
                      _buildQuestionRow(context, poll, txt),
                    ],
                    if (widget.post.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: _buildDescriptionWithHashtags(
                          context,
                          widget.post.description,
                          txt,
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      height: 165.h,
                      width: double.infinity,
                      child: _buildImagesStack(images, widget.post, poll),
                    ),
                    SizedBox(height: 5.h),
                  ],
                ),
              ),
            );
          }
        }
      } else if (_hasTextOptions(poll)) {
        widgets.add(_buildTextPollSection(context, poll, widget.post));
      }
    }
    return widgets;
  }

  Widget _buildQuestionRow(
    BuildContext context,
    HomeFeedPoll poll,
    AppTextColors txt, {
    VoidCallback? onVotesTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            poll.question,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.heading,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (poll.totalVotes > 0) ...[
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onVotesTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionWithHashtags(
    BuildContext context,
    String description,
    AppTextColors txt,
  ) {
    if (!description.contains('#')) {
      return Text(
        description,
        style: AppTextStyles.bodyText.copyWith(
          color: txt.body,
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final RegExp exp = RegExp(r'(#[a-zA-Z0-9_]+)');
    final List<TextSpan> spans = [];

    description.splitMapJoin(
      exp,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: AppTextStyles.bodyText.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String text) {
        if (text.isNotEmpty) {
          spans.add(
            TextSpan(
              text: text,
              style: AppTextStyles.bodyText.copyWith(
                color: txt.body,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }
        return '';
      },
    );

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildAnonymousImageTextPollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final txt = AppTextColors.of(context);
    final validOptions = poll.options
        .where((o) => o.image != null && o.text != null && o.text!.isNotEmpty)
        .toList();

    if (validOptions.isEmpty) return const SizedBox.shrink();

    final hasUserPolled = post.isPolledByCurrentUser;

    Widget optionsWidget;
    if (validOptions.length == 4) {
      optionsWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[0],
                  0,
                  hasUserPolled,
                  poll,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[1],
                  1,
                  hasUserPolled,
                  poll,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[2],
                  2,
                  hasUserPolled,
                  poll,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[3],
                  3,
                  hasUserPolled,
                  poll,
                ),
              ),
            ],
          ),
        ],
      );
    } else if (validOptions.length == 3) {
      optionsWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[0],
              0,
              hasUserPolled,
              poll,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[1],
              1,
              hasUserPolled,
              poll,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[2],
              2,
              hasUserPolled,
              poll,
            ),
          ),
        ],
      );
    } else {
      optionsWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(validOptions.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < validOptions.length - 1 ? 10 : 0,
              ),
              child: _buildAnonymousOptionCard(
                context,
                validOptions[index],
                index,
                hasUserPolled,
                poll,
              ),
            ),
          );
        }),
      );
    }

    return GestureDetector(
      onTap: () => _showAllImagesGrid(_getPollImages(poll), post, poll),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (post.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _buildDescriptionWithHashtags(
                  context,
                  post.description,
                  txt,
                ),
              ),
            if (poll.question.isNotEmpty || post.description.isNotEmpty)
              SizedBox(height: 12.h),
            optionsWidget,
            SizedBox(height: 5.h),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousOptionCard(
    BuildContext context,
    HomeFeedPollOption option,
    int index,
    bool hasUserPolled,
    HomeFeedPoll poll,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget = const SizedBox.shrink();
    if (option.image != null) {
      imageWidget = AppCachedNetworkImage(
        imageUrl: option.image!.resolvedUrl(ApiConfig.baseUrlImage),
        fit: BoxFit.cover,
      );
    }

    return SizedBox(
      height: 155.h,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.60),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              if (hasUserPolled)
                Positioned(
                  bottom: 2,
                  left: 8.w,
                  right: 8.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.text ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getPercentageText(poll, option),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Positioned(
                  bottom: 5.h,
                  left: 8.w,
                  right: 8.w,
                  child: Text(
                    option.text ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleChoiceImageOptionCard(
    BuildContext context,
    HomeFeedPollOption option,
    int index,
    HomeFeedPoll poll,
    bool hasUserPolled,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget = const SizedBox.shrink();
    if (option.image != null) {
      imageWidget = AppCachedNetworkImage(
        imageUrl: option.image!.resolvedUrl(ApiConfig.baseUrlImage),
        fit: BoxFit.cover,
        showSpinnerPlaceholder: true,
      );
    }

    return GestureDetector(
      onTap: hasUserPolled
          ? () {
              navigationPush(
                context,
                ImageResultScreen(
                  username: widget.post.user.username,
                  postId: widget.post.id.toString(),
                ),
              );
            }
          : () {
              final pollKey = poll.id.toString();
              setState(() {
                selectedOptions[pollKey] = [index];
              });
              _submitPollVotes(poll);
            },
      child: SizedBox(
        height: 155.h,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageWidget,
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.60),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (hasUserPolled)
                  Positioned(
                    bottom: 2,
                    left: 8.w,
                    right: 8.w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (option.text != null && option.text!.isNotEmpty)
                          Text(
                            option.text!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        Text(
                          _getPercentageText(poll, option),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (option.text != null && option.text!.isNotEmpty)
                  Positioned(
                    bottom: 5.h,
                    left: 8.w,
                    right: 8.w,
                    child: Text(
                      option.text!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleChoiceImagePollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final txt = AppTextColors.of(context);
    final validOptions = poll.options.where((o) => o.image != null).toList();
    if (validOptions.isEmpty) return const SizedBox.shrink();

    final hasUserPolled = post.isPolledByCurrentUser;

    Widget optionsWidget;
    if (validOptions.length == 4) {
      optionsWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSingleChoiceImageOptionCard(
                  context,
                  validOptions[0],
                  0,
                  poll,
                  hasUserPolled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSingleChoiceImageOptionCard(
                  context,
                  validOptions[1],
                  1,
                  poll,
                  hasUserPolled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSingleChoiceImageOptionCard(
                  context,
                  validOptions[2],
                  2,
                  poll,
                  hasUserPolled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSingleChoiceImageOptionCard(
                  context,
                  validOptions[3],
                  3,
                  poll,
                  hasUserPolled,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      optionsWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(validOptions.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < validOptions.length - 1 ? 10 : 0,
              ),
              child: _buildSingleChoiceImageOptionCard(
                context,
                validOptions[index],
                index,
                poll,
                hasUserPolled,
              ),
            ),
          );
        }),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (poll.question.isNotEmpty) ...[
            SizedBox(height: 5.h),
            _buildQuestionRow(context, poll, txt),
          ],
          if (post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _buildDescriptionWithHashtags(
                context,
                post.description,
                txt,
              ),
            ),
          if (poll.question.isNotEmpty || post.description.isNotEmpty)
            SizedBox(height: 12.h),
          optionsWidget,
          SizedBox(height: 5.h),
        ],
      ),
    );
  }

  Widget _buildImagesStack(
    List<PollOptionImage> images,
    HomeFeedPost post,
    HomeFeedPoll poll,
  ) {
    final txt = AppTextColors.of(context);
    final displayImages = images.take(4).toList();
    final n = displayImages.length;
    final hasUserPolled = post.isPolledByCurrentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final cardWidth = n == 1 ? w : w * 0.55;
        final spacing = n > 1 ? (w - cardWidth) / (n - 1) : 0.0;

        return GestureDetector(
          onTap: () => _showAllImagesGrid(images, post, poll),
          child: SizedBox(
            height: h,
            width: w,
            child: Stack(
              children: displayImages
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    final i = entry.key;
                    final img = entry.value;

                    Widget imageWidget = Image.network(
                      img.resolvedUrl(ApiConfig.baseUrlImage),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                          size: 30,
                        ),
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
                    );

                    if (i > 0) {
                      imageWidget = ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                        child: imageWidget,
                      );
                    }

                    return Positioned(
                      left: i * spacing,
                      top: 0,
                      bottom: 0,
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageWidget,
                              if (hasUserPolled)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    height: 28,
                                    width: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: AppTextStyles.subText.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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

  Widget _buildThisOrThatPollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = poll.options.isNotEmpty ? poll.options[0].text ?? '' : '';
    final option2 = poll.options.length > 1 ? poll.options[1].text ?? '' : '';

    final double pct1 = poll.options.isNotEmpty
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = poll.options.length > 1
        ? poll.options[1].percentage
        : 0.0;

    final hasImages = _hasImageOptions(poll);

    return GestureDetector(
      onTap: () {
        if (post.isPolledByCurrentUser) {
          if (hasImages) {
            navigationPush(
              context,
              ImageResultScreen(
                username: post.user.username,
                postId: post.id.toString(),
              ),
            );
          } else {
            navigationPush(
              context,
              ThingsResultScreen(
                username: post.user.username,
                postId: post.id.toString(),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (post.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _buildDescriptionWithHashtags(
                  context,
                  post.description,
                  txt,
                ),
              ),
            if (poll.question.isNotEmpty || post.description.isNotEmpty)
              const SizedBox(height: 12),
            if (hasImages) ...[
              GestureDetector(
                onTap: post.isPolledByCurrentUser ? null : () {},
                child: SizedBox(
                  height: 165.h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.isNotEmpty
                                          ? poll.options[0].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(poll, optionId);
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.isNotEmpty &&
                                          poll.options[0].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: poll.options[0].image!
                                              .resolvedUrl(
                                                ApiConfig.baseUrlImage,
                                              ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option1,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                _getPercentageTextForValue(
                                                  poll,
                                                  pct1,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option1,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.length > 1
                                          ? poll.options[1].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(poll, optionId);
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card - 1.2,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.length > 1 &&
                                          poll.options[1].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: poll.options[1].image!
                                              .resolvedUrl(
                                                ApiConfig.baseUrlImage,
                                              ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option2,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                _getPercentageTextForValue(
                                                  poll,
                                                  pct2,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option2,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          width: 36.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
                                  : const [
                                      Color(0xFF111111),
                                      Color(0xFF2C2C2C),
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2E323D)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Or',
                            style: TextStyle(
                              color: isDarkMode ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              SizedBox(
                height: post.isPolledByCurrentUser ? 70 : 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: post.isPolledByCurrentUser
                                ? null
                                : () {
                                    final optionId = poll.options.isNotEmpty
                                        ? poll.options[0].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(poll, optionId);
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF242831)
                                    : Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    option1,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1F2937),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  if (post.isPolledByCurrentUser) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _getPercentageTextForValue(poll, pct1),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: isDarkMode
                                            ? Colors.white70
                                            : const Color(0xFF4B5563),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 800,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        tween: Tween<double>(
                                          begin: 0,
                                          end: (pct1 / 100.0).clamp(0.0, 1.0),
                                        ),
                                        builder: (_, value, __) => ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: value,
                                            minHeight: 6,
                                            backgroundColor: isDarkMode
                                                ? const Color(0xFF2D2D2D)
                                                : const Color(0xFFF6F3F2),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: post.isPolledByCurrentUser
                                ? null
                                : () {
                                    final optionId = poll.options.length > 1
                                        ? poll.options[1].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(poll, optionId);
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF242831)
                                    : Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    option2,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1F2937),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  if (post.isPolledByCurrentUser) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _getPercentageTextForValue(poll, pct2),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: isDarkMode
                                            ? Colors.white70
                                            : const Color(0xFF4B5563),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: (post.isPolledByCurrentUser ? 35 : 25) - 16.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 36.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
                                  : const [
                                      Color(0xFF111111),
                                      Color(0xFF2C2C2C),
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2E323D)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Or',
                            style: TextStyle(
                              color: isDarkMode ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHotTakePollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final double pct1 = poll.options.isNotEmpty
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = poll.options.length > 1
        ? poll.options[1].percentage
        : 0.0;

    final firstImage = poll.options.isEmpty
        ? null
        : (poll.options
              .firstWhere((o) => o.image != null, orElse: () => poll.options[0])
              .image);

    return GestureDetector(
      onTap: () {
        // Do not open ThingsResultScreen
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(
                context,
                poll,
                txt,
                onVotesTap: () {
                  BottomSheetUtils.showPollVotersBottomSheet(
                    context: context,
                    postId: post.id.toString(),
                    question: poll.question,
                    pollType: poll.pollType,
                  );
                },
              ),
            ],
            if (post.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _buildDescriptionWithHashtags(
                  context,
                  post.description,
                  txt,
                ),
              ),
            if (poll.question.isNotEmpty || post.description.isNotEmpty)
              const SizedBox(height: 12),
            if (firstImage != null) ...[
              GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 165.h,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: AppCachedNetworkImage(
                      imageUrl: firstImage.resolvedUrl(ApiConfig.baseUrlImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(
              height: 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!post.isPolledByCurrentUser) {
                          final optionId = poll.options.isNotEmpty
                              ? poll.options[0].id
                              : null;
                          if (optionId != null) {
                            _submitSinglePollVote(poll, optionId);
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF101F1B)
                              : const Color(0xFFECFDF5),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF19322A)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: Stack(
                            children: [
                              if (post.isPolledByCurrentUser)
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct1 / 100.0,
                                      child: Container(
                                        color: isDarkMode
                                            ? const Color(0xFF0F3A2E)
                                            : const Color(
                                                0xFF16A34A,
                                              ).withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        post.isPolledByCurrentUser
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        Assets.images.icAgree.path,
                                        height: 22,
                                        width: 22,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Agree',
                                        style: AppTextStyles.sectionHeading
                                            .copyWith(
                                              color: isDarkMode
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF059669),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      if (post.isPolledByCurrentUser) ...[
                                        const Spacer(),
                                        Text(
                                          _getPercentageTextForValue(
                                            poll,
                                            pct1,
                                          ),
                                          style: AppTextStyles.sectionHeading
                                              .copyWith(
                                                color: isDarkMode
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFF059669),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!post.isPolledByCurrentUser) {
                          final optionId = poll.options.length > 1
                              ? poll.options[1].id
                              : null;
                          if (optionId != null) {
                            _submitSinglePollVote(poll, optionId);
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF201315)
                              : const Color(0xFFFDE5E5),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFFCB5B5B).withOpacity(0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Stack(
                            children: [
                              if (post.isPolledByCurrentUser)
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct2 / 100.0,
                                      child: Container(
                                        color: isDarkMode
                                            ? const Color(0xFF4C1D24)
                                            : const Color(0xFFFECACA),
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        post.isPolledByCurrentUser
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        Assets.images.icDisagree.path,
                                        height: 22,
                                        width: 22,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Disagree',
                                        style: AppTextStyles.sectionHeading
                                            .copyWith(
                                              color: isDarkMode
                                                  ? const Color(0xFFE53E3E)
                                                  : const Color(0xFFC81E1E),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      if (post.isPolledByCurrentUser) ...[
                                        const Spacer(),
                                        Text(
                                          _getPercentageTextForValue(
                                            poll,
                                            pct2,
                                          ),
                                          style: AppTextStyles.sectionHeading
                                              .copyWith(
                                                color: isDarkMode
                                                    ? const Color(0xFFE53E3E)
                                                    : const Color(0xFFC81E1E),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildBattlePollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = poll.options.isNotEmpty ? poll.options[0].text ?? '' : '';
    final option2 = poll.options.length > 1 ? poll.options[1].text ?? '' : '';

    final double pct1 = poll.options.isNotEmpty
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = poll.options.length > 1
        ? poll.options[1].percentage
        : 0.0;

    final hasImages = _hasImageOptions(poll);

    return GestureDetector(
      onTap: () {
        if (post.isPolledByCurrentUser) {
          if (hasImages) {
            navigationPush(
              context,
              ImageResultScreen(
                username: post.user.username,
                postId: post.id.toString(),
              ),
            );
          } else {
            navigationPush(
              context,
              ThingsResultScreen(
                username: post.user.username,
                postId: post.id.toString(),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (post.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _buildDescriptionWithHashtags(
                  context,
                  post.description,
                  txt,
                ),
              ),
            if (poll.question.isNotEmpty || post.description.isNotEmpty)
              const SizedBox(height: 12),
            if (hasImages) ...[
              GestureDetector(
                onTap: post.isPolledByCurrentUser ? null : () {},
                child: SizedBox(
                  height: 165.h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.isNotEmpty
                                          ? poll.options[0].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(poll, optionId);
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.isNotEmpty &&
                                          poll.options[0].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: poll.options[0].image!
                                              .resolvedUrl(
                                                ApiConfig.baseUrlImage,
                                              ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option1,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                _getPercentageTextForValue(
                                                  poll,
                                                  pct1,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option1,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.length > 1
                                          ? poll.options[1].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(poll, optionId);
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card - 1.2,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.length > 1 &&
                                          poll.options[1].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: poll.options[1].image!
                                              .resolvedUrl(
                                                ApiConfig.baseUrlImage,
                                              ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option2,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                _getPercentageTextForValue(
                                                  poll,
                                                  pct2,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option2,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          width: 36.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
                                  : const [
                                      Color(0xFF111111),
                                      Color(0xFF2C2C2C),
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2E323D)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Vs',
                            style: TextStyle(
                              color: isDarkMode ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: post.isPolledByCurrentUser ? 70 : 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!post.isPolledByCurrentUser) {
                                final optionId = poll.options.isNotEmpty
                                    ? poll.options[0].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(poll, optionId);
                                }
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.2),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (post.isPolledByCurrentUser) ...[
                                    Text(
                                      _getPercentageTextForValue(poll, pct1),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    option1,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: txt.title,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!post.isPolledByCurrentUser) {
                                final optionId = poll.options.length > 1
                                    ? poll.options[1].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(poll, optionId);
                                }
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.2),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (post.isPolledByCurrentUser) ...[
                                    SizedBox(height: 4.h),
                                    Text(
                                      _getPercentageTextForValue(poll, pct2),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    option2,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: txt.title,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? const [
                                    Color(0xFFFFFFFF), // 0%
                                    Color(0xFFFCFCFC), // 100%
                                  ]
                                : const [Color(0xFF111111), Color(0xFF2C2C2C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF2E323D)
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Vs',
                          style: TextStyle(
                            color: isDarkMode ? Colors.black : Colors.white,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPollSection(
    BuildContext context,
    HomeFeedPoll poll,
    HomeFeedPost post,
  ) {
    final txt = AppTextColors.of(context);
    final validOptions = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .toList();
    if (validOptions.isEmpty) return const SizedBox.shrink();

    final hasUserPolled = post.isPolledByCurrentUser;
    final isSingleChoice = poll.vottingType == 'single_choice';

    return GestureDetector(
      onTap: () {
        if (post.isPolledByCurrentUser) {
          navigationPush(
            context,
            ThingsResultScreen(
              username: post.user.username,
              postId: post.id.toString(),
            ),
          );
        } else if (!isSingleChoice) {
          navigationPush(
            context,
            HomefeedThingsRanking(post: post, user: post.user, poll: poll),
          ).then((result) {
            if (result == true) setState(() {});
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (post.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _buildDescriptionWithHashtags(
                  context,
                  post.description,
                  txt,
                ),
              ),
            if (poll.question.isNotEmpty || post.description.isNotEmpty)
              const SizedBox(height: 12),

            ...poll.options.asMap().entries.map((entry) {
              if (entry.value.text == null || entry.value.text!.isEmpty) {
                return const SizedBox.shrink();
              }
              final optionIndex = entry.key;
              final option = entry.value;

              return GestureDetector(
                onTap: hasUserPolled
                    ? () {
                        navigationPush(
                          context,
                          ThingsResultScreen(
                            username: post.user.username,
                            postId: post.id.toString(),
                          ),
                        );
                      }
                    : (isSingleChoice
                          ? () {
                              final pollKey = poll.id.toString();
                              setState(() {
                                selectedOptions[pollKey] = [optionIndex];
                              });
                              _submitPollVotes(poll);
                            }
                          : () {
                              navigationPush(
                                context,
                                HomefeedThingsRanking(
                                  post: post,
                                  user: post.user,
                                  poll: poll,
                                ),
                              ).then((result) {
                                if (result == true) setState(() {});
                              });
                            }),
                child: _buildPollOption(
                  option,
                  context,
                  optionIndex,
                  poll,
                  showPercentage: hasUserPolled,
                ),
              );
            }),
            // if (hasUserPolled)
            //   Row(
            //     mainAxisAlignment: MainAxisAlignment.end,
            //     children: [
            //       GestureDetector(
            //         onTap: () => _showThingsPostVotersBottomSheet(poll),
            //         child: Text(
            //           'View votes',
            //           style: AppTextStyles.subText.copyWith(
            //             color: Theme.of(context).colorScheme.primary,
            //             fontWeight: FontWeight.w700,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollOption(
    HomeFeedPollOption option,
    BuildContext context,
    int optionIndex,
    HomeFeedPoll poll, {
    bool showPercentage = false,
  }) {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final double cachedPct = _cachedPercentages[option.id] ?? 0.0;
    final int pctRounded = cachedPct.round();

    final bool alreadyAnimated = _animationDone[option.id] ?? false;
    final double tweenBegin = alreadyAnimated ? cachedPct / 100 : 0.0;
    final int intTweenBegin = alreadyAnimated ? pctRounded : 0;

    final hasUserPolled = widget.post.isPolledByCurrentUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(
        bottom: 10.h,
      ), // padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        color: hasUserPolled
            ? (isDarkMode
                  ? const Color(0XFF2A2026).withOpacity(0.7)
                  : const Color(0xFFFCF9F9))
            : (isDarkMode
                  ? const Color(0xFF242831).withOpacity(0.7)
                  : Colors.white),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text ?? '',
                style: AppTextStyles.subText.copyWith(
                  color: txt.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (hasUserPolled)
              poll.vottingType == 'single_choice'
                  ? Text(
                      _getPercentageText(poll, option),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Center(
                        child: Text(
                          '${optionIndex + 1}',
                          style: AppTextStyles.subText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
