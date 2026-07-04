// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../api/api_config.dart';
import '../../../../../api/api_service.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../models/posts/single_post_model.dart';
import '../../../../../../widgets/loader.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../../home feed/rank/submit/rank_submitted_screen.dart';

class SinglePostThingsRanking extends StatefulWidget {
  final SinglePostModel post;
  final SinglePostPoll poll;

  const SinglePostThingsRanking({
    super.key,
    required this.post,
    required this.poll,
  });

  @override
  State<SinglePostThingsRanking> createState() =>
      _SinglePostThingsRankingState();
}

class _SinglePostThingsRankingState extends State<SinglePostThingsRanking> {
  late List<SinglePostPollOption> _rankedOptions;
  bool _hasInteracted = false;
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

    _rankedOptions = widget.poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .toList();
  }

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

  Future<void> _submitRanking() async {
    if (!_hasInteracted || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final List<Map<String, int>> votes = [];
      for (int i = 0; i < _rankedOptions.length; i++) {
        votes.add({'option_id': _rankedOptions[i].id, 'rank': i + 1});
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
              nextScreen: ThingsResultScreen(
                username: widget.post.user.username,
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
                itemCount: _rankedOptions.length,
                itemBuilder: (context, index) {
                  final option = _rankedOptions[index];
                  return _buildOptionCard(
                    option,
                    index,
                    key: ValueKey(option.id),
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _rankedOptions.removeAt(oldIndex);
      _rankedOptions.insert(newIndex, item);
      _hasInteracted = true;
    });
  }

  Widget _buildPostHeader() {
    final post = widget.post;
    final username = post.user.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'P';
    final txt = AppTextColors.of(context);

    final String profileUrl = widget.post.profileImage;
    ImageProvider? avatarImage;
    if (_profileImageBytes != null) {
      avatarImage = MemoryImage(_profileImageBytes!);
    } else if (profileUrl.isNotEmpty) {
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
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.15),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        initial,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
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

          if (widget.poll.question.isNotEmpty)
            Text(
              widget.poll.question,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),

          const SizedBox(height: 4),

          Text(
            'Hold & drag to rank answer',
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

  Widget _buildOptionCard(
    SinglePostPollOption option,
    int index, {
    required Key key,
  }) {
    final rank = index + 1;

    return KeyedSubtree(
      key: key,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ReorderableDragStartListener(
          index: index,
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B3046).withOpacity(0.09),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Drag handle ──────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    FeatherIcons.menu,
                    size: 20,
                    color: Color(0xFF595959),
                  ),
                ),

                // ── Option text ──────────────────────────────────────────
                Expanded(
                  child: Text(
                    option.text ?? '',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),

                // ── Rank badge ───────────────────────────────────────────
                if (_hasInteracted) ...[
                  SizedBox(width: 10.w),
                  _buildRankBadge(rank),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    return Container(
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
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: AppTextStyles.subText.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = _hasInteracted && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? _submitRanking : null,
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
                  color: isEnabled
                      ? Colors.white
                      : const Color(0xFF898989).withOpacity(0.6),
                ),
              ),
      ),
    );
  }
}
