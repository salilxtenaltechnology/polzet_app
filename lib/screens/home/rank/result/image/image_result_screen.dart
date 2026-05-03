// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../api/api_config.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../models/posts/homefeed_posts_model.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/base64/image_convert.dart';
import 'image_preview_screen.dart';

class ImageResultScreen extends StatefulWidget {
  final HomeFeedUser user;
  final HomeFeedPoll poll;
  final HomeFeedPost post;

  const ImageResultScreen({
    super.key,
    required this.user,
    required this.poll,
    required this.post,
  });

  @override
  State<ImageResultScreen> createState() => _ImageResultScreenState();
}

class _ImageResultScreenState extends State<ImageResultScreen> {
  Uint8List? _profileImageBytes;

  late final List<HomeFeedPollOption> _sortedOptions;

  late final int _totalVotes;

  @override
  void initState() {
    super.initState();

    if (widget.user.profileImage != null &&
        widget.user.profileImage!.isNotEmpty) {
      _profileImageBytes = getProfileImage(widget.user.profileImage);
    }

    _sortedOptions = List.from(widget.poll.options)
      ..sort((a, b) {
        final aRank = a.rankPosition ?? 999;
        final bRank = b.rankPosition ?? 999;
        return aRank.compareTo(bRank);
      });

    _totalVotes = widget.poll.totalVotes > 0
        ? widget.poll.totalVotes
        : _sortedOptions.fold(0, (sum, o) => sum + o.voteCount);
  }

  String timeAgo(String createdAt) {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);

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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Poll result'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        children: [
          _buildHeader(),
          SizedBox(height: 10.h),
          _buildQuestion(),
          SizedBox(height: 16.h),
          ..._sortedOptions.map((option) => _buildResultCard(option)),
        ],
      ),
    );
  }

  // ── Header: avatar + name + total votes ────────

  Widget _buildHeader() {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.15),
          backgroundImage: _profileImageBytes != null
              ? MemoryImage(_profileImageBytes!)
              : null,
          child: _profileImageBytes == null
              ? Text(
                  widget.user.firstLetter,
                  style: AppTextStyles.subText.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),

        SizedBox(width: 10.w),

        // Name + handle + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.username,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              Text(
                timeAgo(widget.post.createdAt),
                style: AppTextStyles.subText.copyWith(
                  color: const Color(0XFF898989),
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Total votes
        Text(
          'Total votes : $_totalVotes',
          style: AppTextStyles.subText.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0XFF8E8E8E),
          ),
        ),
      ],
    );
  }

  // ── Question ─────────────

  Widget _buildQuestion() {
    return Text(
      widget.poll.question,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF111111),
      ),
    );
  }

  // ── Result card per option ────────────

  Widget _buildResultCard(HomeFeedPollOption option) {
    final imageUrl = option.image != null
        ? '${ApiConfig.baseUrlImage}${option.image!.url}'
        : '';

    final int votes = option.voteCount;
    final double pct = option.percentage;
    final int rank1Pct = option.rank1Count;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0XFF9B3046).withOpacity(0.09),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              // Build full url list from sorted options
              final urls = _sortedOptions
                  .where((o) => o.image != null)
                  .map((o) => '${ApiConfig.baseUrlImage}${o.image!.url}')
                  .toList();

              final tappedIndex = _sortedOptions.indexOf(option);

              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ImagePreviewScreen(
                    imageUrls: urls,
                    initialIndex: tappedIndex,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 72.w,
                      height: 72.w,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          SizedBox(width: 12.w),

          // ── Text + bar ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.text?.isNotEmpty == true
                      ? option.text!
                      : 'Option ${(option.rankPosition ?? 0) + 1}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),

                SizedBox(height: 3.h),

                // Sub label: "Chosen as #1 by X% voters"
                Text(
                  'Chosen as #1 by $rank1Pct% voters',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.5,
                    color: const Color(0xFF898989),
                    fontWeight: FontWeight.w400,
                  ),
                ),

                SizedBox(height: 8.h),

                // Progress bar + vote count
                Row(
                  children: [
                    // Bar
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            begin: 0,
                            end: (pct / 100).clamp(0.0, 1.0),
                          ),
                          builder: (_, value, __) => LinearProgressIndicator(
                            value: value,
                            minHeight: 7.h,
                            backgroundColor: const Color(0xFFF6F3F2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10.w),

                    // Vote count
                    Text(
                      '$votes votes',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0XFF8E8E8E),
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
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72.w,
      height: 72.w,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
        size: 28,
      ),
    );
  }
}
