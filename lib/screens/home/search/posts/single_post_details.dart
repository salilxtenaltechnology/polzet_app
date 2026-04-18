// screens/post/single_post_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:polzet_app/api/api_config.dart';
import 'package:polzet_app/models/posts/single_post_model.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../../api/services/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../core/utils/like_util.dart';
import '../../profile/posts/popup/single_post_image_popup.dart';

const _accent = AppColors.primaryColor;
const _textSecondary = Color(0xFF888888);

class SinglePostDetails extends StatefulWidget {
  final String username;
  final int postId;

  const SinglePostDetails({
    super.key,
    required this.username,
    required this.postId,
  });

  @override
  State<SinglePostDetails> createState() => _SinglePostDetailsState();
}

class _SinglePostDetailsState extends State<SinglePostDetails> {
  SinglePostModel? _post;
  bool _loading = true;
  String? _error;

  final Map<int, int> _selectedVotes = {};

  final Map<String, List<int>> _selectedOptions = {};
  final Map<String, bool> _pollVotingStates = {};
  Map<int, List<LikeUser>> postLikedUsers = {};

  Map<int, bool> likedUsersLoading = {};

  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;

  @override
  void initState() {
    super.initState();
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
      if (!mounted) return;
      setState(() {
        _post = result;
        for (final poll in result.polls) {
          if (poll.userVote != null) {
            _selectedVotes[poll.id] = poll.userVote!;
          }
        }
      });

      await _fetchLikedUsers(result.id);
      if (mounted) {
        setState(() {
          _likesCount = postLikedUsers[result.id]?.length ?? 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAllImagesGrid(
    int postId,
    SinglePostPoll poll,
    bool isPolledByCurrentUser,
  ) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => SinglePostImagePopup(
              images: poll.options,
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
              _fetchPost();
            });
          }
        });
  }

  Future<void> _fetchLikedUsers(int postId) async {
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

  Uint8List? _decodeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(
        raw.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''),
      );
    } catch (_) {
      return null;
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text('Post', style: CustomTextStyles.appBarTitleText(context)),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        toolbarHeight: 25.h,
      ),
      body: _loading
          ? Center(child: Loader(color: AppColors.primaryColor))
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
      color: _accent,
      onRefresh: _fetchPost,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        children: [_buildPostCard(post)],
      ),
    );
  }

  Widget _buildPostCard(SinglePostModel post) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
        ],
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(post),
          if (post.isImagePoll && post.description.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              post.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: 8.h),
          ...post.polls.map(
            (poll) => post.isImagePoll
                ? _buildImagePollBlock(poll, post.id)
                : _buildTextPollBlock(poll),
          ),
          SizedBox(height: 4.h),
          _buildInteractionBar(post),
          if (_likesCount > 0) ...[
            if ((postLikedUsers[post.id] ?? []).isNotEmpty) ...[
              SizedBox(height: 4.h),
              GestureDetector(
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
                      postLikedUsers[post.id]!,
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
                              postLikedUsers[post.id]!,
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
        ],
      ),
    );
  }

  Widget _buildHeader(SinglePostModel post) {
    final avatarBytes = _decodeBase64(null);
    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.15),
          backgroundImage: avatarBytes != null
              ? MemoryImage(avatarBytes)
              : null,
          child: avatarBytes == null
              ? Text(
                  post.user.isNotEmpty ? post.user[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.user,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            Text(
              _timeAgo(post.createdAt),
              style: TextStyle(
                fontSize: 8.8.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMAGE POLL  — mirrors ImagePostsList._buildImagesStack style
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildImagePollBlock(SinglePostPoll poll, int postId) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final imageHeight = 150.h;
            return GestureDetector(
              onTap: () => _showAllImagesGrid(postId, poll, false),
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
                              borderRadius: BorderRadius.circular(AppRadius.button),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          loadingBuilder: (_, child, progress) {
                                            if (progress == null) return child;
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

  Widget _buildTextPollBlock(SinglePostPoll poll) {
    final pollKey = poll.id.toString();
    final hasUserPolled = _selectedVotes.containsKey(poll.id);
    final isVoting = _pollVotingStates[pollKey] ?? false;
    final areAllSelected = _areAllOptionsSelected(poll);
    final totalVotes = int.tryParse(poll.totalVotes) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll.question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        ...poll.options.asMap().entries.map(
          (e) => _buildTextOptionRow(
            option: e.value,
            optionIndex: e.key,
            poll: poll,
            totalVotes: totalVotes,
            showPercentage: hasUserPolled,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: !hasUserPolled && areAllSelected
              ? GestureDetector(
                  key: ValueKey('submit_${poll.id}'),
                  onTap: isVoting ? null : () => _submitTextVote(poll),
                  child: Center(
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
      ],
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
    final pollKey = poll.id.toString();
    final hasUserPolled = _selectedVotes.containsKey(poll.id);
    final double percentage = option.percentage;
    final bool isSelected =
        _selectedOptions[pollKey]?.contains(optionIndex) ?? false;
    final int? selectionNumber = _getSelectionNumber(pollKey, optionIndex);

    return GestureDetector(
      onTap: hasUserPolled
          ? null
          : () => _toggleTextOption(pollKey, optionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 10.h),
        height: 27.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: isSelected && !hasUserPolled
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : isDark
                ? const Color(0xFF30353D)
                : const Color(0xFFE8E8E8),
            width: isSelected && !hasUserPolled ? 1.2 : 1,
          ),
        ),
        child: Stack(
          children: [
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
                        fontWeight: isSelected && !hasUserPolled
                            ? FontWeight.w600
                            : FontWeight.w500,
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
                    )
                  else if (isSelected)
                    Text(
                      '$selectionNumber',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11.5.sp,
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

  bool _areAllOptionsSelected(SinglePostPoll poll) {
    final pollKey = poll.id.toString();
    if (!_selectedOptions.containsKey(pollKey)) return false;
    final validCount = poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .length;
    return _selectedOptions[pollKey]!.length == validCount;
  }

  int? _getSelectionNumber(String pollKey, int optionIndex) {
    final selected = _selectedOptions[pollKey];
    if (selected == null || !selected.contains(optionIndex)) return null;
    return selected.indexOf(optionIndex) + 1;
  }

  void _toggleTextOption(String pollKey, int optionIndex) {
    setState(() {
      _selectedOptions.putIfAbsent(pollKey, () => []);
      if (_selectedOptions[pollKey]!.contains(optionIndex)) {
        _selectedOptions[pollKey]!.remove(optionIndex);
      } else {
        _selectedOptions[pollKey]!.add(optionIndex);
      }
    });
  }

  Future<void> _submitTextVote(SinglePostPoll poll) async {
    final pollKey = poll.id.toString();
    if (_pollVotingStates[pollKey] == true) return;

    final previousSelected = List<int>.from(_selectedOptions[pollKey] ?? []);

    setState(() {
      _pollVotingStates[pollKey] = true;
      _selectedOptions[pollKey] = [];
    });

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < previousSelected.length; i++) {
        final option = poll.options[previousSelected[i]];
        votes.add({'option_id': option.id, 'rank': i + 1});
      }

      final firstOptionId = poll.options[previousSelected.first].id;
      setState(() {
        _selectedVotes[poll.id] = firstOptionId;
        _pollVotingStates[pollKey] = false;
      });
      showToast(message: 'Vote submitted successfully!');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pollVotingStates[pollKey] = false;
        _selectedOptions[pollKey] = previousSelected;
      });
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Interaction bar — like / comment / share (same as both reference files)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInteractionBar(SinglePostModel post) {
    return Row(
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
                    : AppIcons.outlineHeart(
                        key: const ValueKey('outline'),
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                      ),
              ),
              SizedBox(width: 3.w),
              Text(
                LikeService.getLikesCountText(_likesCount),
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
              AppIcons.commnetBox(
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.6),
              ),
              SizedBox(width: 3.w),
              Text(
                _formatCount(_commentsCount),
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
          onTap: () {},
          child: AppIcons.sharePost(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshLikedUsersQuietly(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (!mounted) return;
      setState(() {
        postLikedUsers[postId] = users.take(3).toList();
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final prev = _isLiked;
    final prevCount = _likesCount;

    setState(() {
      _isLiked = !prev;
      _likesCount = prev ? prevCount - 1 : prevCount + 1;
    });

    try {
      if (_post != null) {
        await _refreshLikedUsersQuietly(_post!.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = prev;
          _likesCount = prevCount;
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
                color: _accent,
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

  // ── Shimmer ───────────────────────────────────────────────────────────────

  Widget _buildShimmer(BuildContext context) {
    // If we already know the post type use the right shimmer,
    // otherwise default to text poll shimmer
    final isImage = _post?.isImagePoll ?? false;
    return isImage
        ? _buildImagePollShimmer(context)
        : _buildTextPollShimmer(context);
  }
}

Widget _buildImagePollShimmer(BuildContext context) {
  return ListView(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
    children: [
      Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShimmerBox(height: 34.h, width: 34.w, radius: 17.r),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(height: 11.h, width: 100.w, radius: 5.r),
                    SizedBox(height: 4.h),
                    _ShimmerBox(height: 9.h, width: 70.w, radius: 5.r),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _ShimmerBox(height: 12.h, width: 200.w, radius: 5.r),
            SizedBox(height: 12.h),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
                childAspectRatio: 0.85,
              ),
              itemCount: 2,
              itemBuilder: (_, __) => _ShimmerBox(height: 0, radius: 12.r),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                _ShimmerBox(height: 20.h, width: 50.w, radius: 5.r),
                SizedBox(width: 12.w),
                _ShimmerBox(height: 20.h, width: 50.w, radius: 5.r),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildTextPollShimmer(BuildContext context) {
  return ListView(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
    children: [
      Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _ShimmerBox(height: 34.h, width: 34.w, radius: 17.r),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(height: 11.h, width: 110.w, radius: 5.r),
                    SizedBox(height: 4.h),
                    _ShimmerBox(height: 9.h, width: 70.w, radius: 5.r),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Question
            _ShimmerBox(height: 11.h, width: 200.w, radius: 5.r),
            SizedBox(height: 10.h),

            // Poll option bars
            _ShimmerBox(height: 23.h, radius: 10.r),
            SizedBox(height: 8.h),
            _ShimmerBox(height: 23.h, radius: 10.r),
            SizedBox(height: 8.h),
            _ShimmerBox(height: 23.h, radius: 10.r),
            SizedBox(height: 8.h),
            _ShimmerBox(height: 23.h, radius: 10.r),
            SizedBox(height: 12.h),

            // Interaction bar
            Row(
              children: [
                _ShimmerBox(height: 20.h, width: 50.w, radius: 5.r),
                SizedBox(width: 12.w),
                _ShimmerBox(height: 20.h, width: 50.w, radius: 5.r),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
// ─── Shimmer Box ──────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const _ShimmerBox({required this.height, this.width, required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(
          Colors.grey[300]!,
          Colors.grey[200]!,
          _anim.value,
        )!;
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
