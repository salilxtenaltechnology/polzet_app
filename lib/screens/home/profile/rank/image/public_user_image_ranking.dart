// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../api/api_config.dart';
import '../../../../../api/services/validator/api_service.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../models/public/public_profile_model.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/loader.dart';
import '../../../home feed/rank/result/image/image_preview_screen.dart';
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../../home feed/rank/submit/rank_submitted_screen.dart';

class PublicUserImageRanking extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String? profileImage;
  final PublicPost post;
  final PublicPoll poll;
  const PublicUserImageRanking({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.profileImage,
    required this.post,
    required this.poll,
  });

  @override
  State<PublicUserImageRanking> createState() => _PublicUserImageRankingState();
}

class _PublicUserImageRankingState extends State<PublicUserImageRanking> {
  late List<PublicPollOption> _orderedImages;

  bool _hasRanked = false;
  bool _isSubmitting = false;

  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();

    if (widget.profileImage != null && widget.profileImage!.isNotEmpty) {
      try {
        String base64Str = widget.profileImage!;
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        _profileImageBytes = base64Decode(base64Str);
      } catch (_) {}
    }

    _orderedImages = (widget.poll.options)
        .where((o) => o.image != null)
        .toList();
  }

  String _timeAgo(String createdAt) {
    // ← accept String
    final parsed = DateTime.parse(createdAt); // ← parse inside
    final diff = DateTime.now().difference(parsed);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
    return '${(diff.inDays / 365).floor()} y ago';
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _orderedImages.removeAt(oldIndex);
      _orderedImages.insert(newIndex, item);
      _hasRanked = true;
    });
  }

  Future<void> _submitVotes() async {
    if (!_hasRanked || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < _orderedImages.length; i++) {
        votes.add({'option_id': _orderedImages[i].id, 'rank': i + 1});
      }

      final result = await ApiService.voteOnPollMultiple(
        postId: widget.post.id,
        votes: votes,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        widget.post.is_polled_by_current_user = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RankSubmittedScreen(
              nextScreen: ImageResultScreen(
                username: widget.post.user,
                postId: widget.post.id.toString(),
              ),
            ),
          ),
          result: true,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Failed to submit. Try again.',
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting ranking: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title: AppLocalizations.of(context)!.rankyourchoices,
        ),
        body: Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                proxyDecorator: _proxyDecorator,
                onReorder: _onReorder,
                buildDefaultDragHandles: false,
                header: _buildPostHeader(),
                itemCount: _orderedImages.length,
                itemBuilder: (context, index) {
                  final option = _orderedImages[index];
                  return _UserRankImageCard(
                    key: ValueKey(option.id),
                    option: option,
                    rank: _hasRanked ? index + 1 : null,
                    allImages: _orderedImages,
                    index: index,
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 35),
          child: _buildSubmitButton(),
        ),
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: child,
      ),
    );
  }

  Widget _buildPostHeader() {
    final txt = AppTextColors.of(context);
    final username = widget.post.user;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    final String? profileUrl = widget.profileImage;
    ImageProvider? avatarImage;
    if (_profileImageBytes != null) {
      avatarImage = MemoryImage(_profileImageBytes!);
    } else if (profileUrl != null && profileUrl.isNotEmpty) {
      if (profileUrl.startsWith('http') ||
          profileUrl.startsWith('/') ||
          profileUrl.contains('/')) {
        final imageUrl = profileUrl.startsWith('http')
            ? profileUrl
            : (profileUrl.startsWith('/')
                ? '${ApiConfig.baseUrlImage}$profileUrl'
                : '${ApiConfig.baseUrlImage}/$profileUrl');
        avatarImage = CachedNetworkImageProvider(imageUrl);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.1),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        initial,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.firstName ?? ''} ${widget.lastName ?? ''}'
                          .trim(),
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: txt.title,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '@$username',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: txt.body,
                          ),
                        ),
                        Text(
                          '  • ${_timeAgo(widget.post.createdAt)}',
                          style: AppTextStyles.subText.copyWith(
                            color: txt.muted,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question
          if (widget.poll.question.isNotEmpty)
            Text(
              widget.poll.question,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          const SizedBox(height: 7),
          Text(
            AppLocalizations.of(context)!.holdanddragtorankimage,
            style: AppTextStyles.subText.copyWith(
              fontSize: 13,
              color: txt.muted,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _hasRanked && !_isSubmitting ? _submitVotes : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: const Color(0x269B3046),
          disabledForegroundColor: const Color(0xFF898989),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: Loader(color: Colors.white),
              )
            : Text(
                'Submit ranking',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _hasRanked
                      ? Colors.white
                      : const Color(0xFF898989).withOpacity(0.6),
                ),
              ),
      ),
    );
  }
}

class _UserRankImageCard extends StatelessWidget {
  final PublicPollOption option;
  final int? rank;
  final List<PublicPollOption> allImages;
  final int index;

  const _UserRankImageCard({
    super.key,
    required this.option,
    required this.rank,
    required this.allImages,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = option.image != null
        ? option.image!.resolvedUrl(ApiConfig.baseUrlImage)
        : '';

    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            // ── Image ──────────────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                final urls = allImages
                    .where((o) => o.image != null)
                    .map((o) => o.image!.resolvedUrl(ApiConfig.baseUrlImage))
                    .toList();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ImagePreviewScreen(
                      imageUrls: urls,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
            ),

            // ── Rank badge ─────────────────────────────────────────────────
            if (rank != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB82B53),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rank.toString(),
                    style: AppTextStyles.subText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }
}
