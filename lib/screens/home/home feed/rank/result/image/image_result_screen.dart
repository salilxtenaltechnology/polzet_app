// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../api/api_config.dart';
import '../../../../../../api/services/api_service.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../models/posts/single_post_model.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/loader.dart';
import 'image_preview_screen.dart';

class ImageResultScreen extends StatefulWidget {
  final String username;
  final int postId;

  const ImageResultScreen({
    super.key,
    required this.username,
    required this.postId,
  });

  @override
  State<ImageResultScreen> createState() => _ImageResultScreenState();
}

class _ImageResultScreenState extends State<ImageResultScreen> {
  final ApiService _apiService = ApiService();

  SinglePostModel? _post;
  bool _isLoading = true;
  String? _error;

  Uint8List? _profileImageBytes;

  late List<SinglePostPollOption> _sortedOptions;
  late int _totalVotes;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future<void> _fetchPost() async {
    try {
      final post = await _apiService.getSinglePost(
        widget.username,
        widget.postId,
      );
      _prepareDisplayData(post);

      Uint8List? imageBytes;
      if (post.profileImage.isNotEmpty) {
        try {
          final raw = post.profileImage.contains(',')
              ? post.profileImage.split(',').last
              : post.profileImage;
          imageBytes = base64Decode(raw);
        } catch (_) {
          imageBytes = null;
        }
      }

      if (mounted) {
        setState(() {
          _post = post;
          _profileImageBytes = imageBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Pre-computes sorted options and total-vote count from the first poll.
  void _prepareDisplayData(SinglePostModel post) {
    final poll = post.polls.isNotEmpty ? post.polls.first : null;

    if (poll == null) {
      _sortedOptions = [];
      _totalVotes = 0;
      return;
    }

    // Sort by descending percentage so the winning option appears first,
    // mirroring the rankPosition sort from the old HomeFeedPollOption.
    _sortedOptions = List<SinglePostPollOption>.from(poll.options)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    final parsedTotal = int.tryParse(poll.totalVotes) ?? 0;
    _totalVotes = parsedTotal > 0
        ? parsedTotal
        : _sortedOptions.fold(
            0,
            (sum, o) => sum + (int.tryParse(o.voteCount) ?? 0),
          );
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (_error != null || _post == null) {
      return Center(
        child: Text(
          _error ?? 'Something went wrong.',
          style: AppTextStyles.subText,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        _buildHeader(),
        SizedBox(height: 10.h),
        _buildQuestion(),
        SizedBox(height: 16.h),
        ..._sortedOptions.map((option) => _buildResultCard(option)),
      ],
    );
  }

  // ── Header: username + time + total votes ────────────────────────────────

  Widget _buildHeader() {
    final username = _post!.user;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.15),
          backgroundImage: _profileImageBytes != null
              ? MemoryImage(_profileImageBytes!)
              : null,
          child: _profileImageBytes == null
              ? Text(
                  initial,
                  style: AppTextStyles.subText.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),

        SizedBox(width: 10.w),

        // Username + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              Text(
                timeAgo(_post!.createdAt),
                style: AppTextStyles.subText.copyWith(
                  color: const Color(0XFF898989),
                  fontWeight: FontWeight.w400,
                  fontSize: 12.5,
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

  Widget _buildQuestion() {
    final question = _post!.polls.isNotEmpty ? _post!.polls.first.question : '';

    return Text(
      question,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF111111),
      ),
    );
  }

  Widget _buildResultCard(SinglePostPollOption option) {
    final imageUrl = option.image != null
        ? option.image!.resolvedUrl(ApiConfig.baseUrlImage)
        : '';

    final int votes = int.tryParse(option.voteCount) ?? 0;
    final double pct = option.percentage;
    final int rank = _sortedOptions.indexOf(option) + 1;
    final String rankLabel = rank == 1 ? 'Top pick' : 'Ranked #$rank';

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
          // ── Tappable image ───────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              final urls = _sortedOptions
                  .where((o) => o.image != null)
                  .map((o) => o.image!.resolvedUrl(ApiConfig.baseUrlImage))
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
                      width: 80,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          SizedBox(width: 12.w),

          // ── Text + bar ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.text?.isNotEmpty == true
                      ? option.text!
                      : 'Option $rank',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),

                SizedBox(height: 3.h),

                // Rank label derived from sorted position
                Text(
                  rankLabel,
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
                            minHeight: 10,
                            backgroundColor: const Color(0xFFF6F3F2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10.w),

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

  // ── Placeholder ───────────────────────────────────────────────────────────

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
