// screens/post/single_post_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../provider/user_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
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

  final Map<int, int> _selectedVotes = {};

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

  Future<void> _fetchPost() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService().getSinglePost(
        widget.username,
        widget.postId,
      );

      Uint8List? imageBytes;
      if (result.profileImage.isNotEmpty) {
        try {
          final raw = result.profileImage.contains(',')
              ? result.profileImage.split(',').last
              : result.profileImage;
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

      await _fetchLikedUsers(result.id.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
            if (result == true) _fetchPost();
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
            if (result == true) _fetchPost();
          });
    }
  }

  // Add this method to _SinglePostDetailsState
  void _navigateTextPoll(SinglePostPoll poll) {
    final isPolledByCurrentUser = _post?.isPolledByCurrentUser ?? false;

    if (isPolledByCurrentUser) {
      // Already voted → show results
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
            if (result == true) _fetchPost();
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
            if (result == true) _fetchPost();
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
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _fetchPost,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
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
          if (post.isImagePoll && post.description.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 0),
              child: Text(
                post.description,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ),
          ],
          SizedBox(height: 5.h),
          ...post.polls.map(
            (poll) => post.isImagePoll
                ? _buildImagePollBlock(poll, post.id, post)
                : _buildTextPollBlock(poll),
          ),
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
    final username = _post!.user;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.1),
            backgroundImage: _profileImageBytes != null
                ? MemoryImage(_profileImageBytes!)
                : null,
            child: _profileImageBytes == null
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
                    '@${post.user}',
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
              final imageHeight = 150.h;
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
                                  width: 1.2,
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
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12.r),
                                                    color: Colors.grey[200],
                                                  ),
                                                );
                                              }
                                              final token = snapshot.data;
                                              final headers = token != null && imageUrl.contains('/api/')
                                                  ? {'Authorization': 'Bearer $token'}
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

  // Replace _buildTextPollBlock with this updated version
  Widget _buildTextPollBlock(SinglePostPoll poll) {
    final hasUserPolled = _selectedVotes.containsKey(poll.id);
    final totalVotes = int.tryParse(poll.totalVotes) ?? 0;

    // ── Show polled UI if: own post OR already voted ─────────────────────────
    final isOwnPost = _post?.user == widget.username;
    final isPolledByCurrentUser = _post?.isPolledByCurrentUser ?? false;
    final showPolledUi = isOwnPost || isPolledByCurrentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateTextPoll(poll),
            child: Text(
              poll.question,
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (showPolledUi)
            // ── Own post or already voted → show result bars ───────────────
            _buildTextPolledOptions(poll, () => _navigateTextPoll(poll))
          else
            // ── Other user's post, not yet voted → show plain options ──────
            ...poll.options.asMap().entries.map(
              (e) => GestureDetector(
                onTap: () => _navigateTextPoll(poll),
                child: _buildTextOptionRow(
                  option: e.value,
                  optionIndex: e.key,
                  poll: poll,
                  totalVotes: totalVotes,
                  showPercentage: hasUserPolled,
                ),
              ),
            ),
        ],
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 10.h),
      height: 27.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: isDark ? const Color(0xFF30353D) : const Color(0xFFE8E8E8),
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
                          ? const Color(0xFF30353D)
                          : const Color(0xFFE8E8E8),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
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
                SizedBox(width: 15.w),
                // ── Vote count ───────────────────────────────────────────────
                Text(
                  '${option.voteCount} votes',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8E8E8E),
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
              usernameOverride: post.user,
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
}
