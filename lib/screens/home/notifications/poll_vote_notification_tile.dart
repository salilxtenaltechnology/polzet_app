// ignore_for_file: deprecated_member_use
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/search/posts/single_post_details.dart';
import '../home feed/rank/result/image/image_result_screen.dart';
import '../home feed/rank/result/things/things_result_screen.dart';
import 'package:provider/provider.dart';

import '../../../api/api_config.dart';
import '../../../api/services/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/notifications/notification_model.dart';
import '../../../models/posts/single_post_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/loader.dart';

class PollVoteNotificationTile extends StatefulWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final String timeAgo;
  final Uint8List? Function(String?) getUserImage;

  const PollVoteNotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.timeAgo,
    required this.getUserImage,
  });

  @override
  State<PollVoteNotificationTile> createState() =>
      _PollVoteNotificationTileState();
}

class _PollVoteNotificationTileState extends State<PollVoteNotificationTile>
    with UtilityMixin {
  static final Map<dynamic, SinglePostModel> _cache = {};
  static final Set<dynamic> _fetching = {};

  bool _isExpanded = false;
  bool _fetchFailed = false;

  // ── Convenience getters ────────────────────────────────────────────────────
  dynamic get _postId => widget.notification.post?.postId;

  SinglePostModel? get _cachedPost => _postId != null ? _cache[_postId] : null;

  bool get _isFetchingPoll => _postId != null && _fetching.contains(_postId);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Only fetch if not already cached or in-flight
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _cachedPost == null && !_isFetchingPoll) {
        _fetchPollDetails();
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final String base = ApiConfig.baseUrlImage.endsWith('/')
        ? ApiConfig.baseUrlImage.substring(0, ApiConfig.baseUrlImage.length - 1)
        : ApiConfig.baseUrlImage;
    final String path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  int _totalVotesFromPost(SinglePostModel post) {
    if (post.polls.isEmpty) return 0;
    int total = 0;
    for (final option in post.polls.first.options) {
      total += int.tryParse(option.voteCount) ?? 0;
    }
    return total;
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> _fetchPollDetails({bool forceRefresh = false}) async {
    final dynamic postId = _postId;
    if (postId == null || postId == 0 || postId == '0' || postId.toString().trim().isEmpty) return;

    // If cached and not forcing refresh, nothing to do
    if (!forceRefresh && _cache.containsKey(postId)) return;

    // If already in-flight, nothing to do
    if (_fetching.contains(postId)) return;

    _fetching.add(postId);

    // Only show spinner inside expanded body — never in header (silent bg fetch)
    if (_isExpanded && mounted) setState(() {});

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final username = userProvider.username;
      if (username == null) {
        _fetching.remove(postId);
        return;
      }

      final SinglePostModel post = await ApiService().getSinglePost(
        username,
        postId,
      );

      // Store in static cache
      _cache[postId] = post;

      // if (kDebugMode) {
      //   for (final poll in post.polls) {
      //     debugPrint(
      //       '   poll ${poll.id} "${poll.question}" | options=${poll.options.length}',
      //     );
      //     for (final opt in poll.options) {
      //       debugPrint(
      //         '     opt ${opt.id} votes=${opt.voteCount} pct=${opt.percentage}%',
      //       );
      //     }
      //   }
      // }
    } catch (e, st) {
      if (kDebugMode) debugPrint('❌ [Tile #$postId] fetch failed: $e\n$st');

      // Only surface error if the user has the panel open
      if (mounted && _isExpanded) {
        setState(() => _fetchFailed = true);
      }
    } finally {
      _fetching.remove(postId);
      if (mounted) setState(() {}); // Refresh UI after fetch completes
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      // Clear error so retry works cleanly
      if (_isExpanded) _fetchFailed = false;
    });

    // If expanding and no cache yet, trigger fetch (shows spinner in body)
    if (_isExpanded && _cachedPost == null && !_isFetchingPoll) {
      _fetchPollDetails();
    }
  }

  String getInitial(String name) {
    if (name.isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final SinglePostModel? fetchedPost = _cachedPost;

    final SinglePostPoll? poll =
        (fetchedPost != null && fetchedPost.polls.isNotEmpty)
        ? fetchedPost.polls.first
        : null;

    // Before cache loads → show 0; after cache → show real sum
    final int totalVotes = fetchedPost != null
        ? _totalVotesFromPost(fetchedPost)
        : 0;

    final String? postImageUrl = widget.notification.post?.imageUrl;
    final String? avatarUrl = widget.notification.actor.avatarUrl;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _isExpanded
              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: InkWell(
                onTap: _toggleExpand,
                child: Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildLeadingThumbnail(postImageUrl, avatarUrl),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: widget.notification.actor.name,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: txt.title,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' voted on your poll!',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: txt.title,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '$totalVotes votes • ${widget.notification.timeAgo.isNotEmpty ? widget.notification.timeAgo : widget.timeAgo}',
                              style: AppTextStyles.subText.copyWith(
                                color: txt.title.withOpacity(0.6),
                                fontSize: 10.5.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                        size: 24.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Expanded body ──────────────────────────────────────────
            if (_isExpanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              if (_isFetchingPoll)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 28.h),
                  child: Loader(
                    color: Theme.of(context).colorScheme.onPrimary,
                    
                  ),
                )
              else if (_fetchFailed)
                _buildErrorRow(context)
              else if (poll == null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 12.w,
                  ),
                  child: Text(
                    'Poll details not available.',
                    style: AppTextStyles.subText.copyWith(
                      color: txt.muted,
                      fontSize: 13.sp,
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
                  child: _buildPollContent(context, poll, totalVotes),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Error row ──────────────────────────────────────────────────────────────

  Widget _buildErrorRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16.sp,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Could not load poll details.',
              style: AppTextStyles.subText.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13.sp,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _fetchFailed = false);
              _fetchPollDetails(forceRefresh: true);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Poll content dispatcher ────────────────────────────────────────────────

  Widget _buildPollContent(
    BuildContext context,
    SinglePostPoll poll,
    int totalVotes,
  ) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String username = userProvider.username ?? '';
    final bool hasAnyImage = poll.options.any((o) => o.image != null);
    final bool hasAnyText = poll.options.any(
      (o) => o.text != null && o.text!.isNotEmpty,
    );

    if (hasAnyImage && !hasAnyText) {
      return _buildImagePoll(context, poll, totalVotes, username);
    }
    if (hasAnyText && !hasAnyImage) {
      return _buildTextPoll(context, poll, totalVotes, username);
    }
    if (hasAnyImage) {
      return _buildImagePoll(context, poll, totalVotes, username);
    }
    return Text(
      poll.question.isNotEmpty ? poll.question : 'No poll content.',
      style: AppTextStyles.subText.copyWith(
        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        fontSize: 13.sp,
      ),
    );
  }

  // ── Leading thumbnail ──────────────────────────────────────────────────────

  Widget _buildLeadingThumbnail(String? postImageUrl, String? avatarUrl) {
    final bool hasNetworkPost = postImageUrl != null && postImageUrl.isNotEmpty;
    final bool hasNetworkAvatar =
        avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http');
    final bool hasBase64Avatar =
        avatarUrl != null && avatarUrl.startsWith('data:image');
    final Uint8List? base64Bytes = hasBase64Avatar
        ? widget.getUserImage(avatarUrl)
        : null;

    // ── Check if any real image is available ──
    final bool hasAnyImage =
        hasNetworkPost ||
        hasNetworkAvatar ||
        (hasBase64Avatar && base64Bytes != null);

    // ── Fallback: first letter of actor name ──
    if (!hasAnyImage) {
      final String initial = getInitial(widget.notification.actor.name);
      return Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
          ),
        ),
      );
    }

    DecorationImage? decorationImage;
    if (hasNetworkPost) {
      decorationImage = DecorationImage(
        image: NetworkImage(_resolveImageUrl(postImageUrl)),
        fit: BoxFit.cover,
      );
    } else if (hasNetworkAvatar) {
      decorationImage = DecorationImage(
        image: NetworkImage(avatarUrl),
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: 33.w,
      height: 33.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.button),
        color: Colors.grey.withOpacity(0.2),
        image: decorationImage,
      ),
      child: (hasBase64Avatar && base64Bytes != null && !hasNetworkPost)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Image.memory(
                base64Bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            )
          : null,
    );
  }

  // ── Text Poll ──────────────────────────────────────────────────────────────

  Widget _buildTextPoll(
    BuildContext context,
    SinglePostPoll poll,

    int totalVotes,
    String username,
  ) {
    final double maxPercentage = poll.options
        .map((o) => o.percentage)
        .reduce((a, b) => a > b ? a : b);

    return GestureDetector(
      onTap: () {
        final String? postId = widget.notification.meta?.postId?.toString();
        if (postId == null) return;

        final bool isPolled = _cachedPost?.isPolledByCurrentUser == true;
        final String targetUsername = _cachedPost?.user.username ?? username;

        if (isPolled) {
          navigationPush(
            context,
            ThingsResultScreen(username: targetUsername, postId: postId),
          );
        } else {
          navigationPush(
            context,
            SinglePostDetails(username: targetUsername, postId: postId),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (poll.question.isNotEmpty) ...[
            Text(
              poll.question,
              style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 12.h),
          ],
          ...poll.options.map(
            (o) => _buildTextOptionRow(
              context,
              o,
              totalVotes,
              o.percentage == maxPercentage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOptionRow(
    BuildContext context,
    SinglePostPollOption option,
    int totalVotes,
    bool isHighest,
  ) {
    final txt = AppTextColors.of(context);
    final int voteCount = int.tryParse(option.voteCount) ?? 0;
    double percentage = option.percentage;
    if (percentage == 0.0 && totalVotes > 0 && voteCount > 0) {
      percentage = (voteCount / totalVotes) * 100;
    }
    // final double fillValue = (percentage / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  option.text ?? 'Option',

                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.body,
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 47,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.left,
                  style: AppTextStyles.bodyText.copyWith(
                    color: isHighest
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          //  SizedBox(height: 8.h),
          // Row(
          //   crossAxisAlignment: CrossAxisAlignment.center,
          //   children: [
          //     Expanded(
          //       child: ClipRRect(
          //         borderRadius: BorderRadius.circular(10.r),
          //         child: LinearProgressIndicator(
          //           value: fillValue,
          //           minHeight: 7.h,
          //           backgroundColor: Theme.of(
          //             context,
          //           ).colorScheme.outline.withOpacity(0.2),
          //           valueColor: AlwaysStoppedAnimation<Color>(
          //             Theme.of(context).colorScheme.primary,
          //           ),
          //         ),
          //       ),
          //     ),
          //     SizedBox(width: 10.w),
          //     SizedBox(
          //       width: 60.w,
          //       child: Text(
          //         '$voteCount votes',
          //         textAlign: TextAlign.right,
          //         style: AppTextStyles.subText.copyWith(
          //           color: Theme.of(
          //             context,
          //           ).colorScheme.onBackground.withOpacity(0.5),
          //           fontSize: 11.sp,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  // ── Image Poll ─────────────────────────────────────────────────────────────

  Widget _buildImagePoll(
    BuildContext context,
    SinglePostPoll poll,
    int totalVotes,
    String username,
  ) {
    final List<SinglePostPollOption> options = poll.options;

    final List<String> allVoterPics = [];
    for (final option in options) {
      for (final voter in option.voters) {
        final String? pic = voter.profilePictureUrl;
        if (pic != null && pic.isNotEmpty && !allVoterPics.contains(pic)) {
          allVoterPics.add(pic);
        }
      }
    }

    final List<MapEntry<String, ImageProvider?>> entries = [];
    for (final String pic in allVoterPics.where(
      (p) => p.startsWith('data:image'),
    )) {
      final Uint8List? bytes = widget.getUserImage(pic);
      if (bytes != null) entries.add(MapEntry(pic, MemoryImage(bytes)));
    }
    for (final String pic in allVoterPics.where(
      (p) => p.startsWith('http://') || p.startsWith('https://'),
    )) {
      entries.add(MapEntry(pic, NetworkImage(_resolveImageUrl(pic))));
    }

    // final List<MapEntry<String, ImageProvider?>> displayVoters = entries
    //     .take(3)
    //     .toList();
    // final int extra = entries.length > 3 ? entries.length - 3 : 0;

    return GestureDetector(
      onTap: () {
        final String? postId = widget.notification.meta?.postId?.toString();
        if (postId == null) return;

        final bool isPolled = _cachedPost?.isPolledByCurrentUser == true;
        final String targetUsername = _cachedPost?.user.username ?? username;

        if (isPolled) {
          navigationPush(
            context,
            ImageResultScreen(username: targetUsername, postId: postId),
          );
        } else {
          navigationPush(
            context,
            SinglePostDetails(username: targetUsername, postId: postId),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (poll.question.isNotEmpty) ...[
            Text(
              poll.question,
              style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 12.h),
          ],
          SizedBox(
            height: 160.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (options.isNotEmpty && options[0].image != null)
                  Expanded(
                    flex: 2,
                    child: _pollImageBox(
                      options[0].image!.resolvedUrl(ApiConfig.baseUrlImage),
                      borderRadius: 10.r,
                    ),
                  ),
                if (options.length > 1) ...[
                  SizedBox(width: 8.w),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        if (options[1].image != null)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _pollImageBox(
                                    options[1].image!.resolvedUrl(
                                      ApiConfig.baseUrlImage,
                                    ),
                                    borderRadius: 10.r,
                                  ),
                                  BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 1.5,
                                      sigmaY: 1.5,
                                    ),
                                    child: Container(color: Colors.transparent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (options.length > 2 && options[2].image != null) ...[
                          SizedBox(height: 8.h),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _pollImageBox(
                                    options[2].image!.resolvedUrl(
                                      ApiConfig.baseUrlImage,
                                    ),
                                    borderRadius: 10.r,
                                  ),
                                  BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 2.5,
                                      sigmaY: 2.5,
                                    ),
                                    child: Container(color: Colors.transparent),
                                  ),
                                  if (options.length > 3)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '+${options.length - 3} more',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Row(
          //       children: [
          //         if (displayVoters.isNotEmpty)
          //           SizedBox(
          //             width: (24 + (displayVoters.length - 1) * 14.0).w,
          //             height: 24.w,
          //             child: Stack(
          //               children: List.generate(displayVoters.length, (i) {
          //                 final ImageProvider? provider =
          //                     displayVoters[i].value;
          //                 if (provider == null) return const SizedBox.shrink();
          //                 return Positioned(
          //                   left: i * 14.0.w,
          //                   child: Container(
          //                     width: 24.w,
          //                     height: 24.w,
          //                     decoration: BoxDecoration(
          //                       shape: BoxShape.circle,
          //                       border: Border.all(
          //                         color: Theme.of(context).colorScheme.surface,
          //                         width: 1.5,
          //                       ),
          //                       image: DecorationImage(
          //                         image: provider,
          //                         fit: BoxFit.cover,
          //                         onError: (_, __) {},
          //                       ),
          //                     ),
          //                   ),
          //                 );
          //               }),
          //             ),
          //           ),
          //         if (extra > 0)
          //           Padding(
          //             padding: EdgeInsets.only(
          //               left: displayVoters.isNotEmpty ? 6.w : 0,
          //             ),
          //             child: Text(
          //               '+$extra',
          //               style: AppTextStyles.subText.copyWith(
          //                 color: Theme.of(
          //                   context,
          //                 ).colorScheme.onBackground.withOpacity(0.6),
          //                 fontSize: 13.sp,
          //                 fontWeight: FontWeight.w500,
          //               ),
          //             ),
          //           ),
          //       ],
          //     ),
          //     Text(
          //       '$totalVotes votes',
          //       style: AppTextStyles.subText.copyWith(
          //         color: Theme.of(
          //           context,
          //         ).colorScheme.onBackground.withOpacity(0.5),
          //         fontSize: 11.sp,
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  // ── Poll image box helper ──────────────────────────────────────────────────

  Widget _pollImageBox(String url, {required double borderRadius}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey.withOpacity(0.15),
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
          onError: (_, __) {},
        ),
      ),
    );
  }
}
