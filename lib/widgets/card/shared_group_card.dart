// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../gen/assets.gen.dart';
import '../../mixin/utility_mixins.dart';
import '../../provider/group_chat_provider.dart';
import '../../screens/home/message/chat/group/group_chat_screen.dart';
import '../base64/image_convert.dart';

class SharedGroupCard extends StatefulWidget {
  final Map<String, dynamic> groupData;
  final bool isSentByMe;
  final String? currentChatId;

  const SharedGroupCard({
    super.key,
    required this.groupData,
    required this.isSentByMe,
    this.currentChatId,
  });

  @override
  State<SharedGroupCard> createState() => _SharedGroupCardState();
}

class _SharedGroupCardState extends State<SharedGroupCard> with UtilityMixin {
  late Map<String, dynamic> _group;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _group = Map<String, dynamic>.from(widget.groupData);
    _fetchPreviewIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SharedGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupData != widget.groupData) {
      _group = Map<String, dynamic>.from(widget.groupData);
      _fetchPreviewIfNeeded();
    }
  }

  Future<void> _fetchPreviewIfNeeded() async {
    final slug = _group['slug']?.toString() ?? '';
    final publicId =
        _group['public_id']?.toString() ?? _group['id']?.toString() ?? '';
    final targetSlug = slug.isNotEmpty ? slug : publicId;

    if (targetSlug.isNotEmpty && !_group.containsKey('mutual_friends')) {
      try {
        final previewData = await ApiService().getGroupPreview(
          slug: targetSlug,
        );
        if (mounted && previewData.isNotEmpty) {
          setState(() {
            _group.addAll(previewData);
          });
        }
      } catch (e) {
        debugPrint('Error fetching group preview in SharedGroupCard: $e');
      }
    }
  }

  String _formatMemberCount(int count) {
    if (count >= 1000000) {
      final val = count / 1000000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}M members';
    } else if (count >= 1000) {
      final val = count / 1000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}k members';
    } else {
      return '$count ${count == 1 ? 'member' : 'members'}';
    }
  }

  Future<void> _handleGroupAction() async {
    final publicId =
        _group['public_id']?.toString() ??
        _group['chat']?.toString() ??
        _group['id']?.toString() ??
        _group['slug']?.toString() ??
        '';
    final title =
        _group['title']?.toString() ?? _group['name']?.toString() ?? 'Group';
    final privacy = _group['privacy']?.toString().toLowerCase() ?? 'public';
    final canJoin = _group['can_join'] == true;
    final isJoined =
        _group['is_joined'] == true ||
        _group['joined_status']?.toString().toLowerCase() == 'joined';

    if (publicId.isEmpty) return;

    if (widget.currentChatId != null &&
        publicId.toString() == widget.currentChatId.toString()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already in this group')),
      );
      return;
    }

    if (isJoined) {
      navigationPush(
        context,
        ChangeNotifierProvider(
          create: (_) => GroupChatProvider(),
          child: GroupChatScreen(groupName: title, chatId: publicId),
        ),
      );
      return;
    }

    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      if (privacy == 'public' || canJoin) {
        final res = await ApiService().joinGroup(chatId: publicId);
        if (mounted) {
          final msg = res['message']?.toString() ?? 'Joined group successfully';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
          setState(() {
            _group['is_joined'] = true;
            _group['joined_status'] = 'joined';
          });
          navigationPush(
            context,
            ChangeNotifierProvider(
              create: (_) => GroupChatProvider(),
              child: GroupChatScreen(groupName: title, chatId: publicId),
            ),
          );
        }
      } else {
        final res = await ApiService().requestJoinGroup(chatId: publicId);
        if (mounted) {
          final msg =
              res['message']?.toString() ?? 'Join request sent successfully';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
          setState(() {
            _group['joined_status'] = 'pending';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    final title =
        _group['title']?.toString() ?? _group['name']?.toString() ?? 'Group';
    final pictureUrlRaw =
        _group['group_picture_url']?.toString() ??
        _group['profile_url']?.toString() ??
        _group['picture_url']?.toString();
    final avatarUrl = resolveProfileImageUrl(pictureUrlRaw);
    final totalMembers =
        int.tryParse(
          _group['total_members']?.toString() ??
              _group['members_count']?.toString() ??
              '0',
        ) ??
        0;

    final isJoined =
        _group['is_joined'] == true ||
        _group['joined_status']?.toString().toLowerCase() == 'joined';
    final isPending =
        _group['joined_status']?.toString().toLowerCase() == 'pending';

    // Parse mutual friends
    final List<dynamic> rawMutual = _group['mutual_friends'] as List? ?? [];
    final List<Map<String, dynamic>> mutualFriends = rawMutual
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final int mutualFriendsCount =
        int.tryParse(_group['mutual_friends_count']?.toString() ?? '') ??
        mutualFriends.length;

    // Determine button text
    String buttonText;
    if (isJoined) {
      buttonText = 'View chat';
    } else if (isPending) {
      buttonText = 'Requested';
    } else {
      buttonText = 'Join Group';
    }

    final cardBgColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1F23)
        : Theme.of(context).colorScheme.primaryContainer;

    final titleInitial = title.isNotEmpty ? title[0].toUpperCase() : 'G';

    return Container(
      margin: EdgeInsets.only(
        top: 4.h,
        bottom: 12.h,
        left: widget.isSentByMe ? 120.w : 12.w,
        right: widget.isSentByMe ? 12.w : 120.w,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top Header Row (Group Avatar + Title & Members) ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 45.w,
                height: 45.w,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: avatarUrl == null
                    ? Text(
                        titleInitial,
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatMemberCount(totalMembers),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: txt.body,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Middle Row (Mutual Friends) ──────────────────────────────────
          if (mutualFriendsCount > 0 || mutualFriends.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildMutualFriendsAvatars(
                  context,
                  mutualFriends: mutualFriends,
                  count: mutualFriendsCount,
                  cardBgColor: cardBgColor,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '$mutualFriendsCount mutual ${mutualFriendsCount == 1 ? 'friend' : 'friends'}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: txt.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // ── Bottom Action Button ──────────────────────────────────────────
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: _handleGroupAction,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 15.w),
              padding: EdgeInsets.symmetric(vertical: 5.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              alignment: Alignment.center,
              child: _isJoining
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutualFriendsAvatars(
    BuildContext context, {
    required List<Map<String, dynamic>> mutualFriends,
    required int count,
    required Color cardBgColor,
  }) {
    final displayCount = mutualFriends.isNotEmpty
        ? mutualFriends.length.clamp(1, 3)
        : count.clamp(1, 3);
    final double avatarRadius = 11.r; // diameter 26.r
    final double overlapOffset = 14.w;
    final double totalWidth =
        (avatarRadius * 2) + (displayCount - 1) * overlapOffset;

    return SizedBox(
      width: totalWidth,
      height: avatarRadius * 2,
      child: Stack(
        children: List.generate(displayCount, (index) {
          final friendData = index < mutualFriends.length
              ? mutualFriends[index]
              : null;
          final username =
              friendData?['username']?.toString() ??
              friendData?['name']?.toString() ??
              '';
          final imgRaw =
              friendData?['profile_image']?.toString() ??
              friendData?['avatar']?.toString();
          final friendAvatarUrl = resolveProfileImageUrl(imgRaw);
          final initial = username.isNotEmpty ? username[0].toUpperCase() : 'F';

          return Positioned(
            left: index * overlapOffset,
            child: Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                border: Border.all(color: cardBgColor, width: 2),
                image: friendAvatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(friendAvatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: friendAvatarUrl == null
                  ? Image.asset(Assets.images.icAvatar.path)
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
