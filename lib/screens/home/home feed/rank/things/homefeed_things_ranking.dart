// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../api/services/api_service.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../models/posts/homefeed_posts_model.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/loader.dart';
import '../submit/rank_submitted_screen.dart';
import '../result/things/things_result_screen.dart';

class HomefeedThingsRanking extends StatefulWidget {
  final HomeFeedPost post;
  final HomeFeedUser user;
  final HomeFeedPoll poll;

  const HomefeedThingsRanking({
    super.key,
    required this.post,
    required this.user,
    required this.poll,
  });

  @override
  State<HomefeedThingsRanking> createState() => _HomefeedThingsRankingState();
}

class _HomefeedThingsRankingState extends State<HomefeedThingsRanking> {
  // Working copy of options — order reflects current user ranking
  late List<HomeFeedPollOption> _rankedOptions;

  // Tracks which indices have been explicitly ranked by the user
  // Once the user drags even one item, all items get their rank badge
  bool _hasInteracted = false;

  bool _isSubmitting = false;

  Uint8List? _profileImageBytes;

  final GlobalKey _firstThingShowcaseKey = GlobalKey();
  bool _showcaseChecked = false;
  late final HomeFeedPollOption _initialFirstOption;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Keep only text options (this is a "things" poll)
    _rankedOptions = widget.poll.options
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .toList();
    if (_rankedOptions.isNotEmpty) {
      _initialFirstOption = _rankedOptions.first;
    }

    // Decode base64 profile image
    final rawImage = widget.user.profileImage;
    if (rawImage != null && rawImage.isNotEmpty) {
      try {
        final raw = rawImage.contains(',')
            ? rawImage.split(',').last
            : rawImage;
        _profileImageBytes = base64Decode(raw);
      } catch (_) {
        _profileImageBytes = null;
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitRanking() async {
    if (!_hasInteracted || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    // Build votes payload: rank is 1-based position in current list order
    final List<Map<String, int>> votes = [];
    for (int i = 0; i < _rankedOptions.length; i++) {
      votes.add({'option_id': _rankedOptions[i].id, 'rank': i + 1});
    }

    final result = await ApiService.voteOnPollMultiple(
      postId: widget.post.id,
      votes: votes,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      widget.poll.isPolledByCurrentUser = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RankSubmittedScreen(
            nextScreen: ThingsResultScreen(
              username: widget.user.username,
              postId: widget.post.id,
            ),
          ),
        ),
        result: true,
      );
    } else {
      showToast(message: result['message']?.toString() ?? 'Failed to submit}');
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
                prefs.getBool('hasShownRankThingsShowcase') ?? false;
            if (!hasShown && mounted && _rankedOptions.isNotEmpty) {
              ShowCaseWidget.of(
                showcaseContext,
              ).startShowCase([_firstThingShowcaseKey]);
              await prefs.setBool('hasShownRankThingsShowcase', true);
            }
          });
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: const CommonAppBar(title: 'Rank your choices'),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  children: [
                    _buildHeader(),
                    SizedBox(height: 12.h),
                    _buildQuestion(),
                    SizedBox(height: 16.h),
                    _buildDraggableList(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(22, 5, 22, 35),
            child: _buildSubmitButton(),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final username = widget.user.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 20,
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

        // Name + handle + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              Text(
                '@$username  •  ${timeAgo(widget.post.createdAt)}',
                style: AppTextStyles.subText.copyWith(
                  color: const Color(0xFF898989),
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // 3-dot menu placeholder
        Icon(
          Icons.more_vert,
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          size: 20,
        ),
      ],
    );
  }

  // ── Question ───────────────────────────────────────────────────────────────

  Widget _buildQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.poll.question,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Hold & drag to rank answer',
          style: AppTextStyles.subText.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF898989),
          ),
        ),
      ],
    );
  }

  // ── Draggable list ─────────────────────────────────────────────────────────

  Widget _buildDraggableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rankedOptions.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _rankedOptions.removeAt(oldIndex);
          _rankedOptions.insert(newIndex, item);
          _hasInteracted = true;
        });
      },
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, __) => Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: child,
          ),
        );
      },
      itemBuilder: (context, index) {
        final option = _rankedOptions[index];
        final isFirstOption =
            _rankedOptions.isNotEmpty && option == _initialFirstOption;
        final itemKey = ValueKey(option.hashCode);

        final card = _buildOptionCard(option, index);

        if (isFirstOption) {
          return KeyedSubtree(
            key: itemKey,
            child: Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Showcase(
                key: _firstThingShowcaseKey,
                description: 'Tap to hold & drag then up and down to rank the answer.',
                titleTextAlign: TextAlign.center,
                descTextStyle: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                targetBorderRadius: BorderRadius.circular(AppRadius.card),
                child: card,
              ),
            ),
          );
        } else {
          return KeyedSubtree(
            key: itemKey,
            child: Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: card,
            ),
          );
        }
      },
    );
  }

  // ── Option card ────────────────────────────────────────────────────────────

  Widget _buildOptionCard(HomeFeedPollOption option, int index) {
    final rank = index + 1;
    final showBadge = _hasInteracted;

    return ReorderableDelayedDragStartListener(
      index: index,
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.08),
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
          children: [
            // ── Drag icon ────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                FeatherIcons.menu,
                size: 20,
                color: Color(0XFF595959),
              ),
            ),

            // ── Option text ──────────────────────────────────────────────
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

            // ── Rank badge (visible after first interaction) ─────────────
            if (showBadge) ...[SizedBox(width: 10.w), _buildRankBadge(rank)],
          ],
        ),
      ),
    );
  }

  // ── Rank badge ─────────────────────────────────────────────────────────────

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

  // ── Submit button ──────────────────────────────────────────────────────────

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
                'Submit ranking',
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
