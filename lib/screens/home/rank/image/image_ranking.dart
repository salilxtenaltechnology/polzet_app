// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../models/posts/homefeed_posts_model.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/loader.dart';
import '../rank_submitted_screen.dart';
import '../result/image/image_preview_screen.dart';
import '../result/image/image_result_screen.dart';

class ImageRanking extends StatefulWidget {
  final List<HomeFeedPollOption> images;
  final HomeFeedUser user;
  final HomeFeedPoll poll; // ← add
  final HomeFeedPost post; // ← add
  final String? timeAgo;
  final String? question;
  final String? createdAt;
  final int postId; // ← add
  final int pollId; // ← add

  const ImageRanking({
    super.key,
    required this.images,
    required this.user,
    required this.poll, // ← add
    required this.post, // ← add
    required this.postId, // ← add
    required this.pollId, // ← add
    this.timeAgo,
    this.question,
    this.createdAt,
  });

  @override
  State<ImageRanking> createState() => _ImageRankingState();
}

class _ImageRankingState extends State<ImageRanking> {
  late List<HomeFeedPollOption> _orderedImages;
  bool _hasRanked = false;
  bool _isSubmitting = false;

  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _orderedImages = List.from(widget.images);

    if (widget.user.profileImage != null &&
        widget.user.profileImage!.isNotEmpty) {
      _profileImageBytes = getProfileImage(widget.user.profileImage);
    }
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
        postId: widget.postId,
        votes: votes,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Mark poll as voted locally
        widget.poll.isPolledByCurrentUser = true;

        // RankSubmittedScreen → then replace with ImageResultScreen
        // Stack after: HomeScreen → ImageResultScreen only
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RankSubmittedScreen(
              nextScreen: ImageResultScreen(
                user: widget.user,
                poll: widget.poll,
                post: widget.post,
              ),
            ),
          ),
        );
      } else {
        // showToast(
        //   message: result['message'] ?? 'Failed to submit. Please try again.',
        // );
      }
    } catch (e) {
      debugPrint('Error submitting ranking: $e');
      // if (mounted) showToast(message: 'An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _orderedImages.removeAt(oldIndex);
      _orderedImages.insert(newIndex, item);
      _hasRanked = true;
    });
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
      appBar: const CommonAppBar(title: 'Rank your choices'),
      body: Column(
        children: [
          // ── Reorderable image list ────────────────────────────────────
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              proxyDecorator: _proxyDecorator,
              onReorder: _onReorder,
              header: _buildPostHeader(),
              itemCount: _orderedImages.length,
              itemBuilder: (context, index) {
                final option = _orderedImages[index];
                return _RankImageCard(
                  key: ValueKey(option.hashCode ^ index),
                  option: option,
                  rank: _hasRanked ? index + 1 : null,
                  allImages: _orderedImages,
                  index: index,
                );
              },
            ),
          ),

          // ── Submit button ─────────────────────────────────────────────
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // Floating shadow card while dragging
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        shadowColor: Colors.black26,
        child: child,
      ),
    );
  }

  Widget _buildPostHeader() {
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
                backgroundColor: Colors.grey.shade300,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.username,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    Text(
                      timeAgo(widget.createdAt ?? ''),
                      style: AppTextStyles.subText.copyWith(
                        color: const Color(0XFF898989),
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_vert, size: 20, color: Color(0XFF727272)),
            ],
          ),

          const SizedBox(height: 12),

          // Question
          if (widget.question != null && widget.question!.isNotEmpty)
            Text(
              widget.question!,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF111111),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Hold & drag to rank image',
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

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _hasRanked && !_isSubmitting
              ? _submitVotes
              : null, // ← use _submitVotes
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
      ),
    );
  }
}

// ── Single image card ─────────────────────────────────────────────────────────

class _RankImageCard extends StatelessWidget {
  final HomeFeedPollOption option;
  final int? rank;
  final List<HomeFeedPollOption> allImages;
  final int index;

  const _RankImageCard({
    super.key,
    required this.option,
    required this.rank,
    required this.allImages,
    required this.index,
  });
  @override
  Widget build(BuildContext context) {
    final imageUrl = option.image != null
        ? '${ApiConfig.baseUrlImage}${option.image!.url}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // ── Image ────────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              final urls =
                  allImages // ← use parameter
                      .where((o) => o.image != null)
                      .map((o) => '${ApiConfig.baseUrlImage}${o.image!.url}')
                      .toList();

              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ImagePreviewScreen(
                    imageUrls: urls,
                    initialIndex: index, // ← use parameter
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
          ),

          // ── Rank badge ───────────────────────────────────────────────
          if (rank != null)
            Positioned(
              top: 10,
              right: 10,
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB82B53),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.background,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      rank.toString(),
                      style: AppTextStyles.subText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
