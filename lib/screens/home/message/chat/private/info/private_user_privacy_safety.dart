// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../../../api/api_service.dart';
import '../../../../../../core/constants/app_radius.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../provider/user_provider.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/bottomsheets/report/report_submitted_bottom_sheet.dart';
import '../../../../../../widgets/dialog/custom_diolog.dart';
import '../../../../../../widgets/show_toast.dart';
import 'private_user_report.dart';

class PrivateUserPrivacySafety extends StatefulWidget {
  final dynamic chatId;
  final dynamic userId;
  final Map<String, dynamic>? chat;
  final bool? isReported;
  final bool? isUserBlock;

  const PrivateUserPrivacySafety({
    super.key,
    this.chatId,
    this.userId,
    this.chat,
    this.isReported,
    this.isUserBlock,
  });

  @override
  State<PrivateUserPrivacySafety> createState() =>
      _PrivateUserPrivacySafetyState();
}

class _PrivateUserPrivacySafetyState extends State<PrivateUserPrivacySafety>
    with UtilityMixin {
  final ApiService _apiService = ApiService();
  late bool _isReported;
  late bool _isUserBlock;

  @override
  void initState() {
    super.initState();
    _isReported = _resolveIsReported();
    _isUserBlock = _resolveIsBlocked();
  }

  @override
  void didUpdateWidget(covariant PrivateUserPrivacySafety oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isReported != widget.isReported ||
        oldWidget.chat != widget.chat) {
      _isReported = _resolveIsReported();
    }
    if (oldWidget.isUserBlock != widget.isUserBlock ||
        oldWidget.chat != widget.chat) {
      _isUserBlock = _resolveIsBlocked();
    }
  }

  bool _resolveIsReported() {
    if (widget.isReported != null) {
      return widget.isReported!;
    }
    if (widget.chat != null) {
      return _getIsReportedFromChat(widget.chat!);
    }
    return false;
  }

  bool _resolveIsBlocked() {
    if (widget.isUserBlock != null) {
      return widget.isUserBlock!;
    }
    if (widget.chat != null) {
      return _getIsBlockedFromChat(widget.chat!);
    }
    return false;
  }

  bool _getIsReportedFromChat(Map<String, dynamic> chat) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();
      final members = chat['members'] as List?;
      if (members != null) {
        for (final m in members) {
          if (m is! Map) continue;
          final member = m as Map<String, dynamic>;
          final user =
              member['user'] as Map<String, dynamic>? ??
              (m.containsKey('username') ? member : null);
          final username = user?['username']?.toString().toLowerCase();
          final id = (user?['uuid'] ?? user?['id'])?.toString();
          if (id != currentUserId &&
              (currentUsername == null || username != currentUsername)) {
            final val =
                member['is_reported'] ??
                member['is_report'] ??
                member['isReported'] ??
                user?['is_reported'] ??
                user?['is_report'];
            if (val == true || val == 1 || val?.toString() == 'true') {
              return true;
            }
          }
        }
      }
      final directVal =
          chat['is_reported'] ?? chat['isReported'] ?? chat['is_report'];
      if (directVal == true ||
          directVal == 1 ||
          directVal?.toString() == 'true') {
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool _getIsBlockedFromChat(Map<String, dynamic> chat) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();
      final members = chat['members'] as List?;
      if (members != null) {
        for (final m in members) {
          if (m is! Map) continue;
          final member = m as Map<String, dynamic>;
          final user =
              member['user'] as Map<String, dynamic>? ??
              (m.containsKey('username') ? member : null);
          final username = user?['username']?.toString().toLowerCase();
          final id = (user?['uuid'] ?? user?['id'])?.toString();
          if (id != currentUserId &&
              (currentUsername == null || username != currentUsername)) {
            return (member['is_block'] == true) ||
                (member['is_blocked'] == true) ||
                (user?['is_blocked'] == true) ||
                (user?['is_block'] == true);
          }
        }
      }
      final directVal =
          chat['is_block'] ?? chat['is_blocked'] ?? chat['isBlocked'];
      if (directVal == true ||
          directVal == 1 ||
          directVal?.toString() == 'true') {
        return true;
      }
    } catch (_) {}
    return false;
  }

  dynamic _getTargetUserId() {
    if (widget.userId != null) return widget.userId;
    if (widget.chat == null) return null;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();
      final members = widget.chat!['members'] as List?;
      if (members != null) {
        for (final m in members) {
          if (m is! Map) continue;
          final member = m as Map<String, dynamic>;
          final user =
              member['user'] as Map<String, dynamic>? ??
              (m.containsKey('username') ? member : null);
          final username = user?['username']?.toString().toLowerCase();
          final id = (user?['uuid'] ?? user?['id'])?.toString();
          if (id != currentUserId &&
              (currentUsername == null || username != currentUsername)) {
            return id;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _updateOtherMemberReportedInChat(
    Map<String, dynamic> chat,
    bool isReported,
  ) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();
      final members = chat['members'] as List?;
      if (members != null) {
        for (final m in members) {
          if (m is Map<String, dynamic>) {
            final user =
                m['user'] as Map<String, dynamic>? ??
                (m.containsKey('username') ? m : null);
            final username = user?['username']?.toString().toLowerCase();
            final id = (user?['uuid'] ?? user?['id'])?.toString();
            if (id != currentUserId &&
                (currentUsername == null || username != currentUsername)) {
              m['is_reported'] = isReported;
            }
          }
        }
      }
      chat['is_reported'] = isReported;
    } catch (_) {}
  }

  void _updateOtherMemberBlockedInChat(
    Map<String, dynamic> chat,
    bool isBlocked,
  ) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();
      final members = chat['members'] as List?;
      if (members != null) {
        for (final m in members) {
          if (m is Map<String, dynamic>) {
            final user =
                m['user'] as Map<String, dynamic>? ??
                (m.containsKey('username') ? m : null);
            final username = user?['username']?.toString().toLowerCase();
            final id = (user?['uuid'] ?? user?['id'])?.toString();
            if (id != currentUserId &&
                (currentUsername == null || username != currentUsername)) {
              m['is_block'] = isBlocked;
              m['is_blocked'] = isBlocked;
            }
          }
        }
      }
      chat['is_block'] = isBlocked;
      chat['is_blocked'] = isBlocked;
    } catch (_) {}
  }

  Future<void> _toggleBlockUser() async {
    showBlockUserDiolog(context, () async {
      final wasBlocked = _isUserBlock;
      Navigator.pop(context);
      if (mounted) setState(() => _isUserBlock = !wasBlocked);
      final targetId = _getTargetUserId();
      if (targetId == null) {
        showToast(message: 'User ID not found');
        return;
      }
      final result = wasBlocked
          ? await _apiService.unblockUser(targetId)
          : await _apiService.blockUser(targetId);
      if (mounted) {
        if (result['success'] == true || result['status'] == 'success') {
          showToast(message: wasBlocked ? 'User unblocked' : 'User blocked');
          if (widget.chat != null) {
            _updateOtherMemberBlockedInChat(widget.chat!, !wasBlocked);
          }
        } else {
          setState(() => _isUserBlock = wasBlocked);
          showToast(message: result['message']?.toString() ?? 'Action failed');
        }
      }
    }, _isUserBlock);
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _isUserBlock);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title: 'Privacy & Safety',
          onBack: () => Navigator.pop(context, _isUserBlock),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Support',
                style: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 8.h),
              _buildCard(
                children: [
                  _buildNavTile(
                    icon: Assets.images.icReport.path,
                    padding: 12,
                    title: 'Report',
                    subtitle: 'Report spam, harmful content, or other concerns',
                    onTap: () async {
                      if (_isReported) {
                        await showReportSubmittedBottomSheet(context);
                      } else {
                        final result = await navigationPush(
                          context,
                          PrivateUserReport(
                            userId: _getTargetUserId(),
                            isReported: false,
                          ),
                        );
                        if (result == true && mounted) {
                          setState(() {
                            _isReported = true;
                            if (widget.chat != null) {
                              _updateOtherMemberReportedInChat(
                                widget.chat!,
                                true,
                              );
                            }
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 5),
                  _buildDivider(),
                  const SizedBox(height: 8),
                  _buildNavTile(
                    icon: Assets.images.icBlockAccount.path,
                    padding: 13,
                    title: _isUserBlock
                        ? (AppLocalizations.of(context)?.unblockuser ??
                              AppLocalizations.of(context)?.unblock ??
                              'Unblock User')
                        : (AppLocalizations.of(context)?.blockuser ??
                              AppLocalizations.of(context)?.block ??
                              'Block User'),
                    subtitle: _isUserBlock
                        ? 'Unblock this user to allow messages and interactions'
                        : 'Stop receiving messages and seeing this user\'s content',
                    showArrow: false,
                    onTap: _toggleBlockUser,
                  ),
                ],
              ),
              SizedBox(height: 15.h),
              Text(
                'Privacy Information',
                style: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                'Your privacy and safety matter. Report this person if something feels inappropriate or violates our guidelines, or block them if you no longer want to interact with them.',
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.body,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildIconBox(String image, double padding) {
    return Container(
      height: 47,
      width: 47,
      padding:  EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        image,
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
      ),
    );
  }

  Widget _buildNavTile({
    required String icon,
    required double padding,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    final txt = AppTextColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Row(
        children: [
          _buildIconBox(icon, padding),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(
                      color: txt.title,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.cardTitle.copyWith(
                      color: txt.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                ),
              ],
            ),
          ),
          if (showArrow)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0XFF595959),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      thickness: 0.5,
      height: 5,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
