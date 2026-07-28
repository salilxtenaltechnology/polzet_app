// screens/post/single_post_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile_screen.dart';
import 'package:provider/provider.dart';
import '../../../../provider/user_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:polzet_app/widgets/image/app_cached_network_image.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../api/api_config.dart';
import '../../../../api/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../api/services/share/share_service.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../models/posts/single_post_model.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/loader.dart';
import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../core/utils/like_util.dart';
import '../../home feed/rank/result/image/image_result_screen.dart';
import '../../home feed/rank/result/things/things_result_screen.dart';
import 'rank/single_post_image_ranking.dart';
import 'rank/single_post_things_ranking.dart';
import 'package:polzet_app/data/token/shared_preferences.dart';
import 'package:polzet_app/gen/assets.gen.dart';

const _textSecondary = Color(0xFF888888);

class SinglePostDetails extends StatefulWidget {
  final String username;
  final String postId;

  const SinglePostDetails({
    super.key,
    required this.username,
    required this.postId,
  });

  @override
  State<SinglePostDetails> createState() => _SinglePostDetailsState();
}

class _SinglePostDetailsState extends State<SinglePostDetails>
    with UtilityMixin {
  SinglePostModel? _post;
  bool _loading = true;
  String? _error;
  Future<String?>? _authTokenFuture;

  final Map<String, int> _selectedVotes = {};

  Map<String, List<LikeUser>> postLikedUsers = {};

  Map<String, bool> likedUsersLoading = {};

  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0;

  Uint8List? _profileImageBytes;
  bool _isLikeLoading = false;

  @override
  void initState() {
    super.initState();
    _authTokenFuture = SharedPrefService.getToken();
    _fetchPost();
  }

  Future<void> _fetchPost({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ApiService().getSinglePost(
        widget.username,
        widget.postId,
      );

      Uint8List? imageBytes;
      final imageToDecode = result.user.profileImage.isNotEmpty
          ? result.user.profileImage
          : result.profileImage;
      if (imageToDecode.isNotEmpty) {
        try {
          final raw = imageToDecode.contains(',')
              ? imageToDecode.split(',').last
              : imageToDecode;
          imageBytes = base64Decode(raw);
        } catch (_) {
          imageBytes = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _post = result;
        _profileImageBytes = imageBytes;
        _isLiked = result.isLiked;
        _likesCount = result.likesCount;
        _commentsCount = result.commentsCount;
        _sharesCount = result.sharesCount;
        for (final poll in result.polls) {
          if (poll.userVote != null) {
            _selectedVotes[poll.id] = poll.userVote!;
          }
        }
      });

      await _fetchLikedUsers(result.id.toString(), force: true);
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
    }
  }

  void _showAllImagesGrid(dynamic postId, SinglePostPoll poll) {
    final isPolledByCurrentUser = _post?.isPolledByCurrentUser ?? false;

    if (isPolledByCurrentUser) {
      // Already voted → show results
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => ImageResultScreen(
                postId: postId.toString(),
                username: widget.username,
              ),
            ),
          )
          .then((result) {
            if (result == true) _fetchPost(showLoading: false);
          });
    } else {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) =>
                  SinglePostImageRanking(post: _post!, poll: poll),
            ),
          )
          .then((result) {
            if (result == true) _fetchPost(showLoading: false);
          });
    }
  }

  // Add this method to _SinglePostDetailsState
  void _navigateTextPoll(SinglePostPoll poll) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUsername = userProvider.username ?? '';
    final isOwnPost = _post?.user.username == currentUsername;
    final isPolledByCurrentUser = _post?.isPolledByCurrentUser ?? false;

    if (isOwnPost || isPolledByCurrentUser) {
      // Already voted or own post → show results
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => ThingsResultScreen(
                username: widget.username,
                postId: _post!.id.toString(),
              ),
            ),
          )
          .then((result) {
            if (result == true) _fetchPost(showLoading: false);
          });
    } else {
      // Not yet polled → SinglePostThingsRanking
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) =>
                  SinglePostThingsRanking(post: _post!, poll: poll),
            ),
          )
          .then((result) {
            if (result == true) _fetchPost(showLoading: false);
          });
    }
  }

  Future<void> _fetchLikedUsers(String postId, {bool force = false}) async {
    if (likedUsersLoading[postId] == true ||
        (!force && postLikedUsers.containsKey(postId))) {
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

  String _timeAgo(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrlImage}$path';
  }

  String _formatCount(int count) {
    if (count <= 0) return '';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  bool _hasImageOptions(SinglePostPoll poll) =>
      poll.options.any((o) => o.image != null);

  bool _hasTextOptions(SinglePostPoll poll) =>
      poll.options.any((o) => o.text != null && o.text!.isNotEmpty);

  Widget _buildQuestionRow(
    BuildContext context,
    SinglePostPoll poll,
    AppTextColors txt, {
    VoidCallback? onVotesTap,
  }) {
    final int totalVotes = poll.options.fold<int>(
      0,
      (sum, opt) => sum + (int.tryParse(opt.voteCount) ?? 0),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            poll.question,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.heading,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (totalVotes > 0) ...[
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onVotesTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              '$totalVotes ${AppLocalizations.of(context)!.votes}',
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

  Future<void> _submitSinglePollVote(
    SinglePostPoll poll,
    dynamic optionId,
  ) async {
    try {
      final int optId = optionId is int
          ? optionId
          : int.tryParse(optionId.toString()) ?? 0;

      final List<Map<String, int>> votes = [
        {'option_id': optId, 'rank': 1},
      ];

      final result = await ApiService.voteOnPollSingle(
        postId: _post!.id,
        votes: votes,
      );

      if (result['success'] == true) {
        showToast(message: 'Vote submitted successfully!');
        _fetchPost(showLoading: false);
      } else {
        showToast(
          message:
              result['message'] ?? 'Failed to submit vote. Please try again.',
        );
      }
    } catch (e) {
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  Widget _buildAnonymousOptionCard(
    BuildContext context,
    SinglePostPollOption option,
    int index,
    bool hasUserPolled,
  ) {
    Widget imageWidget = const SizedBox.shrink();
    if (option.image != null) {
      imageWidget = AppCachedNetworkImage(
        imageUrl: option.image!.resolvedUrl(ApiConfig.baseUrlImage),
        fit: BoxFit.cover,
      );
    }

    return SizedBox(
      height: 165.h,
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
                        '${option.percentage.round()}%',
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

  Widget _buildHotTakePollSection(
    BuildContext context,
    SinglePostPoll poll,
    SinglePostModel post, {
    bool showQuestion = true,
  }) {
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
            if (showQuestion && poll.question.isNotEmpty) ...[
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
            if (showQuestion && poll.question.isNotEmpty)
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
                                          '${pct1.round()}%',
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
                                          '${pct2.round()}%',
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
    SinglePostPoll poll,
    SinglePostModel post, {
    bool showQuestion = true,
  }) {
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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ThingsResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
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
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (showQuestion && poll.question.isNotEmpty)
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
                                                '${pct1.round()}%',
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
                                                '${pct2.round()}%',
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
                                  width: 1,
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
                                      '${pct1.round()}%',
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
                        SizedBox(width: 18.w),
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
                                  width: 1,
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
                                      '${pct2.round()}%',
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

  Widget _buildThisOrThatPollSection(
    BuildContext context,
    SinglePostPoll poll,
    SinglePostModel post, {
    bool showQuestion = true,
  }) {
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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ThingsResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
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
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (showQuestion && poll.question.isNotEmpty)
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
                                                '${pct1.round()}%',
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
                                                '${pct2.round()}%',
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
                                      '${pct1.round()}%',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: isDarkMode
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
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
                                      '${pct2.round()}%',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: isDarkMode
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
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
                    Center(
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousImageTextPollSection(
    BuildContext context,
    SinglePostPoll poll,
    SinglePostModel post, {
    bool showQuestion = true,
  }) {
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[1],
                  1,
                  hasUserPolled,
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[3],
                  3,
                  hasUserPolled,
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
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[1],
              1,
              hasUserPolled,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[2],
              2,
              hasUserPolled,
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
              ),
            ),
          );
        }),
      );
    }

    return GestureDetector(
      onTap: () => _showAllImagesGrid(post.id, poll),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (showQuestion && poll.question.isNotEmpty)
              SizedBox(height: 12.h),
            optionsWidget,
            SizedBox(height: 5.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Post'),
      body: _loading
          ? Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            )
          : _error != null
          ? _buildError()
          : _post == null
          ? const SizedBox.shrink()
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final post = _post!;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onPrimary,
      onRefresh: () => _fetchPost(showLoading: false),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        children: [_buildPostCard(post)],
      ),
    );
  }

  Widget _buildPostCard(SinglePostModel post) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(post),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          if (post.polls.isNotEmpty &&
              post.polls.first.question.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 2.h, 10.w, 5.h),
              child: _buildQuestionRow(
                context,
                post.polls.first,
                AppTextColors.of(context),
                onVotesTap: post.polls.first.pollType == 'hot_take'
                    ? () {
                        BottomSheetUtils.showPollVotersBottomSheet(
                          context: context,
                          postId: post.id.toString(),
                          question: post.polls.first.question,
                          pollType: post.polls.first.pollType,
                        );
                      }
                    : null,
              ),
            ),
          ],
          if (post.description.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 2.h),
              child: _buildDescriptionWithHashtags(
                context,
                post.description,
                AppTextColors.of(context),
              ),
            ),
          ],
          SizedBox(height: 5.h),
          ...post.polls.asMap().entries.map((entry) {
            final index = entry.key;
            final poll = entry.value;
            final showQuestion = index > 0;
            if (poll.pollType == 'battle') {
              return _buildBattlePollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else if (poll.pollType == 'hot_take') {
              return _buildHotTakePollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else if (poll.pollType == 'this_or_that') {
              return _buildThisOrThatPollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else if (poll.pollType == 'anonymous' &&
                _hasImageOptions(poll) &&
                _hasTextOptions(poll)) {
              return _buildAnonymousImageTextPollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else {
              return post.isImagePoll
                  ? _buildImagePollBlock(poll, post.id, post)
                  : _buildTextPollBlock(poll, showQuestion: showQuestion);
            }
          }),
          const SizedBox(height: 10),
          _buildInteractionBar(post),
          if ((postLikedUsers[post.id.toString()] ?? []).isNotEmpty) ...[
            SizedBox(height: 5.h),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => BottomSheetUtils.showLikedUsersBottomSheet(
                  context: context,
                  postId: post.id,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    LikeUtils.buildLikeAvatarsStack(
                      context,
                      postLikedUsers[post.id.toString()]!,
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
                              postLikedUsers[post.id.toString()]!,
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
        ],
      ),
    );
  }

  Widget _buildHeader(SinglePostModel post) {
    final txt = AppTextColors.of(context);
    final username = _post!.user.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              navigationPush(
                context,
                PublicProfileScreen(
                  userId: _post!.user.uuid,
                  username: username,
                ),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(0.1),
              backgroundImage: _profileImageBytes != null
                  ? MemoryImage(_profileImageBytes!)
                  : (_post!.user.profileImage.isNotEmpty
                        ? NetworkImage(_post!.user.profileImage)
                        : null),
              child:
                  _profileImageBytes == null && _post!.user.profileImage.isEmpty
                  ? Text(
                      initial,
                      style: AppTextStyles.subText.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
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
                '${post.firstName} ${post.lastName}'.trim(),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: txt.title,
                ),
              ),
              Row(
                children: [
                  Text(
                    '@${post.user.username}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: txt.body,
                    ),
                  ),
                  Text(
                    '  • ${_timeAgo(post.createdAt)}',
                    style: TextStyle(
                      fontSize: 8.8.sp,
                      color: txt.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMAGE POLL  — mirrors ImagePostsList._buildImagesStack style
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildImagePollBlock(
    SinglePostPoll poll,
    dynamic postId,
    SinglePostModel post,
  ) {
    final validImages = poll.options.where((o) => o.image != null).toList();
    if (validImages.isEmpty) return const SizedBox.shrink();

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

    final alignments = getAlignments(validImages.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final imageHeight = 165.h;
              return GestureDetector(
                onTap: () => _showAllImagesGrid(postId, poll),
                child: SizedBox(
                  height: imageHeight,
                  width: availableWidth,
                  child: Stack(
                    children: validImages
                        .asMap()
                        .entries
                        .map<Widget>((entry) {
                          final index = entry.key;
                          final opt = entry.value;
                          final alignment = alignments[index];
                          double imageWidth =
                              (availableWidth * 0.7) - (index * 8.0);
                          imageWidth = imageWidth < 60.w ? 60.w : imageWidth;
                          final imageUrl = opt.image != null
                              ? _resolveUrl(opt.image!.url)
                              : '';
                          return Align(
                            alignment: alignment,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: imageWidth,
                              height: imageHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    imageUrl.isNotEmpty
                                        ? FutureBuilder<String?>(
                                            future: _authTokenFuture,
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppRadius.button,
                                                        ),
                                                    color: Colors.grey[200],
                                                  ),
                                                );
                                              }
                                              final token = snapshot.data;
                                              final headers =
                                                  token != null &&
                                                      imageUrl.contains('/api/')
                                                  ? {
                                                      'Authorization':
                                                          'Bearer $token',
                                                    }
                                                  : null;
                                              return Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                headers: headers,
                                                loadingBuilder: (_, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    color: Colors.grey[200],
                                                    child: Center(
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        value:
                                                            progress.expectedTotalBytes !=
                                                                null
                                                            ? progress.cumulativeBytesLoaded /
                                                                  progress
                                                                      .expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (_, __, ___) =>
                                                    _imagePlaceholder(),
                                              );
                                            },
                                          )
                                        : _imagePlaceholder(),
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
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.grey[200],
      ),
      child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 30),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT POLL  — mirrors QuestionsPostsList._buildPollBlock style exactly
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTextPollBlock(SinglePostPoll poll, {bool showQuestion = true}) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUsername = userProvider.username ?? '';
    final isOwnPost = _post?.user.username == currentUsername;
    final hasUserPolled = _post?.isPolledByCurrentUser ?? false;
    final isSingleChoice = poll.votingType == 'single_choice';

    final totalVotes = poll.options.fold<int>(
      0,
      (sum, opt) => sum + (int.tryParse(opt.voteCount) ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showQuestion) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateTextPoll(poll),
                    child: Text(
                      poll.question,
                      style: AppTextStyles.bodyText.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '$totalVotes ${AppLocalizations.of(context)!.votes}',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (isOwnPost)
            // ── Own post → show text option rows with percentage ───────────
            ...poll.options.asMap().entries.map(
              (e) => GestureDetector(
                onTap: () => _navigateTextPoll(poll),
                child: _buildTextOptionRow(
                  option: e.value,
                  optionIndex: e.key,
                  poll: poll,
                  totalVotes: totalVotes,
                  showPercentage: true,
                ),
              ),
            )
          else
            // ── Other user's post → show poll option style as per home feed ─
            ...poll.options.asMap().entries.map((entry) {
              if (entry.value.text == null || entry.value.text!.isEmpty) {
                return const SizedBox.shrink();
              }
              final optionIndex = entry.key;
              final option = entry.value;

              return GestureDetector(
                onTap: hasUserPolled
                    ? () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (context) => ThingsResultScreen(
                                  username: widget.username,
                                  postId: _post!.id.toString(),
                                ),
                              ),
                            )
                            .then((result) {
                              if (result == true) {
                                _fetchPost(showLoading: false);
                              }
                            });
                      }
                    : (isSingleChoice
                          ? () {
                              _submitSinglePollVote(poll, option.id);
                            }
                          : () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SinglePostThingsRanking(
                                            post: _post!,
                                            poll: poll,
                                          ),
                                    ),
                                  )
                                  .then((result) {
                                    if (result == true) {
                                      _fetchPost(showLoading: false);
                                    }
                                  });
                            }),
                child: _buildPollOption(
                  option: option,
                  optionIndex: optionIndex,
                  poll: poll,
                  hasUserPolled: hasUserPolled,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPollOption({
    required SinglePostPollOption option,
    required int optionIndex,
    required SinglePostPoll poll,
    required bool hasUserPolled,
  }) {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 10.h),
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
              poll.votingType == 'single_choice'
                  ? Text(
                      '${option.percentage.round()}%',
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

  Widget _buildTextOptionRow({
    required SinglePostPollOption option,
    required int optionIndex,
    required SinglePostPoll poll,
    required int totalVotes,
    required bool showPercentage,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double percentage = option.percentage;
      final txt = AppTextColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 10.h),
    
      
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ?  const Color(0xFF242831).withOpacity(0.7) :Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // ── Percentage fill bar (shown after voted) ──────────────────────
          if (showPercentage && percentage > 0)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('bar_${poll.id}_${option.id}_$percentage'),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: percentage / 100),
                builder: (_, value, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0XFF2A2026).withOpacity(0.7)
                          : const Color(0xFFFCF9F9),
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
            ),

          // ── Option text + percentage label ───────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 3.h, 8.w, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (showPercentage)
                  TweenAnimationBuilder<int>(
                    key: ValueKey('pct_${poll.id}_${option.id}_$percentage'),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    tween: IntTween(begin: 0, end: percentage.round()),
                    builder: (_, val, __) => Text(
                      '$val%',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Polled options UI (own post or already voted) ──────────────────────────

  Widget _buildTextPolledOptions(SinglePostPoll poll, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: poll.options.map((option) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option.text ?? '',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${option.percentage.toInt()}%',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Stack(
                        children: [
                          // ── Background track ───────────────────────────────
                          Container(
                            width: double.infinity,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9D9D9).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                            ),
                          ),
                          // ── Filled portion ─────────────────────────────────
                          FractionallySizedBox(
                            widthFactor: (option.percentage / 100).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9E2A46),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // Interaction bar — like / comment / share (same as both reference files)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInteractionBar(SinglePostModel post) {
    final txt = AppTextColors.of(context);
    final String commentText = _formatCount(_commentsCount);
    final String shareText = _formatCount(_sharesCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  child: _isLiked
                      ? AppIcons.filledHeart(key: const ValueKey('filled'))
                      : AppIcons.outlineHeart(key: const ValueKey('outline')),
                ),
                const SizedBox(width: 8),
                Text(
                  LikeService.getLikesCountText(_likesCount),
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

          // Comment
          GestureDetector(
            onTap: () => BottomSheetUtils.showCommentsBottomSheet(
              context: context,
              postId: post.id,
              currentUsername: widget.username,
              onCommentsCountChanged: (count) {
                if (mounted) setState(() => _commentsCount = count);
              },
            ),
            child: Row(
              children: [
                AppIcons.commnetBox(),
                const SizedBox(width: 8),
                Text(
                  commentText,
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

          // Share
          GestureDetector(
            onTap: () => ShareService.sharePost(
              post,
              context: context,
              usernameOverride: post.user.username,
              onShareSuccess: (newCount) {
                if (mounted) {
                  setState(() {
                    _sharesCount = newCount;
                  });
                }
              },
            ),
            child: Row(
              children: [
                AppIcons.sharePost(),
                const SizedBox(width: 8),
                Text(
                  shareText,
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
    );
  }

  Future<void> _refreshLikedUsersQuietly(String postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (!mounted) return;
      setState(() {
        postLikedUsers[postId] = users.take(3).toList();
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_post == null || _isLikeLoading) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId ?? '';
    final currentUsername = userProvider.username ?? '';
    final currentUserFullName =
        '${userProvider.firstName ?? ''} ${userProvider.lastName ?? ''}'.trim();
    final currentUserImage = userProvider.profile_picture;

    final prev = _isLiked;
    final prevCount = _likesCount;
    final postId = _post!.id.toString();
    final previousLikedUsers = List<LikeUser>.from(
      postLikedUsers[postId] ?? [],
    );

    setState(() {
      _isLikeLoading = true;
      _isLiked = !prev;
      _likesCount = prev ? prevCount - 1 : prevCount + 1;

      if (_isLiked) {
        final list = List<LikeUser>.from(postLikedUsers[postId] ?? []);
        if (!list.any((u) => u.username == currentUsername)) {
          list.insert(
            0,
            LikeUser(
              id: currentUserId,
              fullName: currentUserFullName.isNotEmpty
                  ? currentUserFullName
                  : 'You',
              username: currentUsername,
              profileImage: currentUserImage,
            ),
          );
          postLikedUsers[postId] = list.take(3).toList();
        }
      } else {
        final list = List<LikeUser>.from(postLikedUsers[postId] ?? []);
        list.removeWhere((u) => u.username == currentUsername);
        postLikedUsers[postId] = list;
      }
    });

    try {
      final result = await LikeService().togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: prev,
        currentLikesCount: prevCount,
      );

      if (mounted) {
        setState(() {
          _isLikeLoading = false;
          if (!result.success) {
            _isLiked = prev;
            _likesCount = prevCount;
            postLikedUsers[postId] = previousLikedUsers;
          } else {
            _isLiked = result.isLiked;
            _likesCount = result.likesCount;
          }
        });
        if (result.success) {
          await _refreshLikedUsersQuietly(postId);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
          _isLiked = prev;
          _likesCount = prevCount;
          postLikedUsers[postId] = previousLikedUsers;
        });
      }
    }
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: _textSecondary, size: 40.sp),
          SizedBox(height: 12.h),
          Text(
            'Failed to load post',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _error ?? '',
            style: TextStyle(fontSize: 10.sp, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: _fetchPost,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
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
          fontSize: 14,
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
}
