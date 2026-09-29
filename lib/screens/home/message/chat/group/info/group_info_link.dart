// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/services/share/share_service.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../../../widgets/appbar/common_appbar.dart';

class GroupInfoLink extends StatefulWidget {
  final String? slug;
  final String? groupName;
  final dynamic groupId;

  const GroupInfoLink({super.key, this.slug, this.groupName, this.groupId});

  @override
  State<GroupInfoLink> createState() => _GroupInfoLinkState();
}

class _GroupInfoLinkState extends State<GroupInfoLink> {
  bool _isCopied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  String get _groupLink {
    final slug = widget.slug ?? '';
    if (slug.isNotEmpty) {
      return 'http://www.polzet.com/g/$slug';
    }
    return 'Url link.............';
  }

  void _copyLink() {
    final slug = widget.slug ?? '';
    if (slug.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: 'http://www.polzet.com/g/$slug'));
      showToast(message: 'Link copied');
      setState(() {
        _isCopied = true;
      });
      _copyTimer?.cancel();
      _copyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    } else {
      showToast(message: 'Group link unavailable');
    }
  }

  void _shareGroup() {
    final slug = widget.slug ?? '';
    if (slug.isNotEmpty) {
      ShareService.shareGroup(
        slug: slug,
        context: context,
        groupName: widget.groupName ?? '',
        groupId: widget.groupId?.toString() ?? '',
      );
    } else {
      showToast(message: 'Group share link unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:  CommonAppBar(title: AppLocalizations.of(context)!.invite),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            // ── Invite Link Tile ──────────────────────────────────────────────
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                children: [
                  Container(
                    height: 47,
                    width: 47,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Icon(
                        FeatherIcons.link,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                        size: 20.sp,
                      ),
                    ),
                  ),
                    const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                         AppLocalizations.of(context)!.invitelink,
                          style: AppTextStyles.cardTitle.copyWith(
                            color: txt.title,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        Text(
                          _groupLink,
                          style: AppTextStyles.cardTitle.copyWith(
                            color: txt.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _copyLink,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        _isCopied ? AppLocalizations.of(context)!.copied : AppLocalizations.of(context)!.copy,
                        style: AppTextStyles.bodyText.copyWith(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Share Tile ────────────────────────────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _shareGroup,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Container(
                      height: 47,
                      width: 47,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Icon(
                          FeatherIcons.share,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.8),
                          size: 17.sp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.share,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: txt.title,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                             AppLocalizations.of(context)!.invitepeopletojointhisgroup,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: txt.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
