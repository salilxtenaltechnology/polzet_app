// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../../../api/services/api_service.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../models/posts/user_post_model.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/loader.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../../home feed/rank/submit/rank_submitted_screen.dart';

class UserThingsRanking extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String? profileImage;
  final UserPostModel post;
  final UserPollQuestion poll;

  const UserThingsRanking({
    super.key,
    required this.post,
    required this.poll,
    required this.firstName,
    required this.lastName,
    required this.profileImage,
  });

  @override
  State<UserThingsRanking> createState() => _UserThingsRankingState();
}

class _UserThingsRankingState extends State<UserThingsRanking> {
  late List<UserPollOption> _rankedOptions;
  bool _hasInteracted = false;
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

    _rankedOptions = (widget.poll.options ?? [])
        .where((o) => o.text != null && o.text!.isNotEmpty)
        .toList();
  }

  String timeAgo(DateTime createdAt) {
    try {
      final diff = DateTime.now().difference(createdAt.toLocal());
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
      widget.post.is_polled_by_current_user = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RankSubmittedScreen(
            nextScreen: ThingsResultScreen(
              username: widget.post.user,
              postId: widget.post.id,
            ),
          ),
        ),
        result: true,
      );
    } else {
      showToast(message: result['message']?.toString() ?? 'Failed to submit');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Rank your choices'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
  }

  Widget _buildHeader() {
    final username = widget.post.user;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Row(
      children: [
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
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Theme.of(context).colorScheme.primary,
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
                '${widget.firstName ?? ''} ${widget.lastName ?? ''}'.trim(),
                style: AppTextStyles.sectionHeading.copyWith(
                  color: const Color(0XFF2C2C2C),
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
                      color: const Color(0XFF595959),
                    ),
                  ),
                  Text(
                    '  • ${timeAgo(widget.post.createdAt)}',
                    style: AppTextStyles.subText.copyWith(
                      color: const Color(0xFF898989),
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ],
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
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: child,
          ),
        );
      },
      itemBuilder: (context, index) {
        final option = _rankedOptions[index];
        return _buildOptionCard(option, index, key: ValueKey(option.id));
      },
    );
  }

  Widget _buildOptionCard(
    UserPollOption option,
    int index, {
    required Key key,
  }) {
    final rank = index + 1;

    return KeyedSubtree(
      key: key,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: ReorderableDelayedDragStartListener(
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
                // ── Drag handle ──────────────────────────────────────────────
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
