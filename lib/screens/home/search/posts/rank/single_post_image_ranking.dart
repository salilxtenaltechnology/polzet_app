// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../../../api/api_config.dart';
import '../../../../../../api/services/api_service.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../models/posts/single_post_model.dart';
import '../../../../../../widgets/loader.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../home feed/rank/result/image/image_preview_screen.dart';
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../../home feed/rank/submit/rank_submitted_screen.dart';

class SinglePostImageRanking extends StatefulWidget {
  final SinglePostModel post;
  final SinglePostPoll poll;

  const SinglePostImageRanking({
    super.key,
    required this.post,
    required this.poll,
  });

  @override
  State<SinglePostImageRanking> createState() => _SinglePostImageRankingState();
}

class _SinglePostImageRankingState extends State<SinglePostImageRanking> {
  late List<SinglePostPollOption> _orderedImages;
  bool _hasRanked = false;
  bool _isSubmitting = false;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();

    final profileImage = widget.post.profileImage;
    if (profileImage.isNotEmpty) {
      try {
        String base64Str = profileImage;
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        _profileImageBytes = base64Decode(base64Str);
      } catch (_) {}
    }

    _orderedImages = widget.poll.options.where((o) => o.image != null).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _timeAgo(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
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

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrlImage}$path';
  }

  // ── Reorder ────────────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _orderedImages.removeAt(oldIndex);
      _orderedImages.insert(newIndex, item);
      _hasRanked = true;
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RankSubmittedScreen(
              nextScreen: ImageResultScreen(
                username: widget.post.user,
                postId: widget.post.id.toString(),
              ),
            ),
          ),
        );
      } else {
        showToast(
          message:
              result['message']?.toString() ?? 'Failed to submit. Try again.',
        );
      }
    } catch (e) {
      debugPrint('Error submitting ranking: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                  return _SinglePostRankImageCard(
                    key: ValueKey(option.id),
                    option: option,
                    rank: _hasRanked ? index + 1 : null,
                    allImages: _orderedImages,
                    index: index,
                    resolveUrl: _resolveUrl,
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

  // ── Proxy decorator ────────────────────────────────────────────────────────

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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildPostHeader() {
    final txt = AppTextColors.of(context);
    final post = widget.post;
    final username = post.user;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

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
                backgroundImage: _profileImageBytes != null
                    ? MemoryImage(_profileImageBytes!)
                    : null,
                child: _profileImageBytes == null
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
                      '${post.firstName} ${post.lastName}'.trim(),
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
                          '  • ${_timeAgo(post.createdAt)}',
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
              color: const Color(0xFF898989),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Submit button ──────────────────────────────────────────────────────────

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
               AppLocalizations.of(context)!.submitranking,
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

// ── Private image card ─────────────────────────────────────────────────────────

class _SinglePostRankImageCard extends StatelessWidget {
  final SinglePostPollOption option;
  final int? rank;
  final List<SinglePostPollOption> allImages;
  final int index;
  final String Function(String) resolveUrl;

  const _SinglePostRankImageCard({
    super.key,
    required this.option,
    required this.rank,
    required this.allImages,
    required this.index,
    required this.resolveUrl,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = option.image != null ? resolveUrl(option.image!.url) : '';

    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            // ── Full-width cover image ─────────────────────────────────────
            GestureDetector(
              onTap: () {
                final urls = allImages
                    .where((o) => o.image != null)
                    .map((o) => resolveUrl(o.image!.url))
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
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        )
                      : _placeholder(),
                ),
              ),
            ),

            // ── Rank badge overlay ─────────────────────────────────────────
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
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
        size: 40,
      ),
    );
  }
}
