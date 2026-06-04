// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../api/api_config.dart';
import '../../../../../api/services/api_service.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/posts/homefeed_posts_model.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/loader.dart';
import '../submit/rank_submitted_screen.dart';
import '../result/image/image_preview_screen.dart';
import '../result/image/image_result_screen.dart';

class HomefeedImageRanking extends StatefulWidget {
  final List<HomeFeedPollOption> images;
  final HomeFeedUser user;
  final HomeFeedPoll poll;
  final HomeFeedPost post;
  final String? timeAgo;
  final String? question;
  final String? createdAt;
  final String? postId;
  final String? pollId;

  const HomefeedImageRanking({
    super.key,
    required this.images,
    required this.user,
    required this.poll,
    required this.post,
    required this.postId,
    required this.pollId,
    this.timeAgo,
    this.question,
    this.createdAt,
  });

  @override
  State<HomefeedImageRanking> createState() => _ImageRankingState();
}

class _ImageRankingState extends State<HomefeedImageRanking> with UtilityMixin{
  late List<HomeFeedPollOption> _orderedImages;
  bool _hasRanked = false;
  bool _isSubmitting = false;

  Uint8List? _profileImageBytes;

  final GlobalKey _firstImageShowcaseKey = GlobalKey();
  bool _showcaseChecked = false;
  late final HomeFeedPollOption _initialFirstOption;

  @override
  void initState() {
    super.initState();
    debugPrint("POST_ID : ${widget.postId}");
    _orderedImages = List.from(widget.images);
    _initialFirstOption = _orderedImages.first;

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
        widget.post.isPolledByCurrentUser = true;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RankSubmittedScreen(
              nextScreen: ImageResultScreen(
                username: widget.user.username,
                postId: widget.post.id.toString(),
              ),
            ),
          ),
          result: true,
        );
      } else {
        // showToast(
        //   message: result['message'] ?? 'Failed to submit. Please try again.',
        // );
      }
    } catch (e) {
      debugPrint('Error submitting ranking: $e');
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
    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_showcaseChecked) {
          _showcaseChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final prefs = await SharedPreferences.getInstance();
            final bool hasShown =
                prefs.getBool('hasShownRankImageShowcase') ?? false;
            if (!hasShown && mounted) {
              ShowCaseWidget.of(
                showcaseContext,
              ).startShowCase([_firstImageShowcaseKey]);
              await prefs.setBool('hasShownRankImageShowcase', true);
            }
          });
        }

        return SafeArea(
          top: false,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            appBar: const CommonAppBar(title: 'Rank your choices'),
            body: Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    proxyDecorator: _proxyDecorator,
                    onReorder: _onReorder,
                    header: _buildPostHeader(),
                    itemCount: _orderedImages.length,
                    itemBuilder: (context, index) {
                      final option = _orderedImages[index];
                      final isFirstOption = option == _initialFirstOption;
                      final itemKey = ValueKey(
                        option.hashCode,
                      ); // Must be constant across index changes

                      final card = _RankImageCard(
                        option: option,
                        rank: _hasRanked ? index + 1 : null,
                        allImages: _orderedImages,
                        index: index,
                      );

                      if (isFirstOption) {
                        return KeyedSubtree(
                          key: itemKey,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Showcase(
                              tooltipBackgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              overlayColor: const Color(0x0D000000),
                              key: _firstImageShowcaseKey,
                              description:
                                  'Tap to hold & drag then up and down to rank image.',
                              titleTextAlign: TextAlign.center,
                              descTextStyle: AppTextStyles.bodyText.copyWith(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              targetBorderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              child: card,
                            ),
                          ),
                        );
                      } else {
                        return KeyedSubtree(
                          key: itemKey,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: card,
                          ),
                        );
                      }
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
      },
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: child,
      ),
    );
  }

  Widget _buildPostHeader() {
    final txt = AppTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  navigationPush(context, PublicProfileScreen(userId: widget.user.userid));
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                  backgroundImage: _profileImageBytes != null
                      ? MemoryImage(_profileImageBytes!)
                      : null,
                  child: _profileImageBytes == null
                      ? Text(
                          widget.user.firstLetter,
                          style: AppTextStyles.subText.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.user.firstName ?? 'Polzet'} ${widget.user.lastName ?? 'User'}'
                          .trim(),
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: txt.title,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '@${widget.user.username}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: txt.body,
                          ),
                        ),
                        Text(
                          '  • ${timeAgo(widget.createdAt ?? '')}',
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
              // const Icon(Icons.more_vert, size: 20, color: Color(0XFF727272)),
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
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          const SizedBox(height: 4),
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

class _RankImageCard extends StatelessWidget {
  final HomeFeedPollOption option;
  final int? rank;
  final List<HomeFeedPollOption> allImages;
  final int index;

  const _RankImageCard({
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

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            final urls = allImages
                .where((o) => o.image != null)
                .map((o) => '${ApiConfig.baseUrlImage}${o.image!.url}')
                .toList();

            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    ImagePreviewScreen(imageUrls: urls, initialIndex: index),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFB82B53),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: AppTextStyles.subText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
