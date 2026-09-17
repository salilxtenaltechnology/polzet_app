// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../../../api/api_service.dart';
import '../../../../../../core/constants/app_radius.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../provider/user_provider.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/dialog/custom_diolog.dart';
import '../../../../../../widgets/bottomsheets/report/report_submitted_bottom_sheet.dart';
import '../../../../home_imports.dart';
import '../../../message_list.dart';
import 'group_report.dart';

class GroupPrivacySafety extends StatefulWidget {
  final dynamic chatId;
  final Map<String, dynamic>? groupData;
  final bool? isAdmin;

  const GroupPrivacySafety({
    super.key,
    this.chatId,
    this.groupData,
    this.isAdmin,
  });

  @override
  State<GroupPrivacySafety> createState() => _GroupPrivacySafetyState();
}

class _GroupPrivacySafetyState extends State<GroupPrivacySafety>
    with UtilityMixin {
  final ApiService _apiService = ApiService();

  bool get _isAdmin {
    if (widget.isAdmin != null) return widget.isAdmin!;
    if (widget.groupData?['is_admin'] == true) return true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();

      final createdBy = widget.groupData?['created_by']?.toString();
      final creatorId = widget.groupData?['creator_id']?.toString();
      final adminId = widget.groupData?['admin_id']?.toString();

      if (currentUserId != null && currentUserId.isNotEmpty) {
        if (createdBy == currentUserId ||
            creatorId == currentUserId ||
            adminId == currentUserId) {
          return true;
        }
      }

      final admins = widget.groupData?['admins'] as List<dynamic>? ?? [];
      for (final admin in admins) {
        if (admin is Map) {
          final uuid = (admin['uuid'] ??
                  admin['id'] ??
                  admin['user']?['id'] ??
                  admin['user']?['uuid'])
              ?.toString();
          final username = (admin['username'] ?? admin['user']?['username'])
              ?.toString()
              .toLowerCase();
          if (currentUserId != null &&
              currentUserId.isNotEmpty &&
              uuid != null &&
              uuid == currentUserId) {
            return true;
          }
          if (currentUsername != null &&
              currentUsername.isNotEmpty &&
              username != null &&
              username == currentUsername) {
            return true;
          }
        } else if (admin != null) {
          final adminStr = admin.toString().toLowerCase();
          if (currentUserId != null &&
              adminStr == currentUserId.toLowerCase()) {
            return true;
          }
          if (currentUsername != null && adminStr == currentUsername) {
            return true;
          }
        }
      }

      final members = widget.groupData?['members'] as List<dynamic>? ?? [];
      for (final member in members) {
        if (member is Map) {
          final bool isAdmin =
              (member['is_admin'] == true) || (member['role'] == 'admin');
          if (isAdmin) {
            final userMap =
                (member['user'] is Map) ? member['user'] as Map : member;
            final uuid = (member['uuid'] ??
                    member['id'] ??
                    userMap['uuid'] ??
                    userMap['id'])
                ?.toString();
            final username = (userMap['username'] ?? member['username'])
                ?.toString()
                .toLowerCase();

            if (currentUserId != null &&
                currentUserId.isNotEmpty &&
                uuid != null &&
                uuid == currentUserId) {
              return true;
            }
            if (currentUsername != null &&
                currentUsername.isNotEmpty &&
                username != null &&
                username == currentUsername) {
              return true;
            }
          }
        }
      }
    } catch (_) {}

    return false;
  }

  String get _privacyTitle {
    final privacy =
        widget.groupData?['privacy']?.toString().toLowerCase() ?? 'public';
    if (privacy == 'private') return 'Private';
    if (privacy == 'invite_only' || privacy == 'invite only') {
      return 'Invite Only';
    }
    return 'Public';
  }

  String get _privacySubtitle {
    final privacy =
        widget.groupData?['privacy']?.toString().toLowerCase() ?? 'public';
    if (privacy == 'private') {
      return 'Only members can see and participate in this group';
    }
    if (privacy == 'invite_only' || privacy == 'invite only') {
      return 'Only people you invite can join group';
    }
    return 'Anyone can discover and view this group';
  }

  String get _privacyIcon {
    final privacy =
        widget.groupData?['privacy']?.toString().toLowerCase() ?? 'public';
    if (privacy == 'private') return Assets.images.icSecurity.path;
    if (privacy == 'invite_only' || privacy == 'invite only') {
      return Assets.images.icEmail.path;
    }
    return Assets.images.icPublic.path;
  }

  Future<void> _deleteGroup() async {
    final chatId = widget.chatId;
    if (chatId == null) return;
    try {
      final result = await _apiService.deleteGroup(chatId: chatId);
      if (mounted) {
        Navigator.pop(context);
        if (result['message'] == 'Group deleted successfully') {
          MessageListState.removeChatLocally(chatId);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeScreen(initialIndex: 1), // ← Messages tab
            ),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete group'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Privacy & Safety'),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group Privacy',
              style:  AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 8.h),
            _buildCard(
              children: [
                GestureDetector(
                  onTap: (){},
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          _privacyIcon,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _privacyTitle,
                               style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
                          ),
                            ),
                            Text(
                              _privacySubtitle,
                              style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.2,
                              color: txt.muted,
                              fontWeight: FontWeight.w400,
                            ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
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
                  title: 'Report Group',
                  subtitle: 'Report spam, harmful content, or other concerns',
                  onTap: () async {
                    final bool isReported =
                        widget.groupData?['is_reported'] == true;
                    if (isReported) {
                      showReportSubmittedBottomSheet(context);
                    } else {
                      final result = await navigationPush(
                        context,
                        ReportGroup(groupId: widget.chatId?.toString()),
                      );
                      if (result == true && mounted) {
                        setState(() {
                          if (widget.groupData != null) {
                            widget.groupData!['is_reported'] = true;
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
                  title: 'Block Group',
                  subtitle: 'Report spam, harmful content, or other concerns',
                  showArrow: false,
                  onTap: () {},
                ),
                const SizedBox(height: 3),
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
            SizedBox(height: 8.h),
            Text(
              'See something you’re uncomfortable with? You can report a group if it violates our guidelines, or block it if you simply don’t want to see its content or recommendations.',
              style: AppTextStyles.bodyText.copyWith(
                color: txt.body,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 10),
              _buildDeleteGroupCard(),
            ],
          ],
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

  Widget _buildIconBox(String image) {
    return Container(
      height: 44,
      width: 44,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        image,
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
      ),
    );
  }

  Widget _buildNavTile({
    required String icon,
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
          _buildIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                   style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
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

  Widget _buildDeleteGroupCard() {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        showDeleteGroupDiolog(context, () {
          _deleteGroup();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFFF85D7F).withOpacity(0.06)
              : const Color(0XFFFFF1F4),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: const Color(0XFFD63C5E).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
          child: Row(
            children: [
              Container(
                height: 47,
                width: 47,
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(Assets.images.icDelete.path),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Group',
                      style: AppTextStyles.bodyText.copyWith(
                        color: const Color(0XFFD63C5E).withOpacity(0.8),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Permanently delete this group',
                      style: AppTextStyles.subText.copyWith(
                        color: txt.muted,
                        fontSize: 12,
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
    );
  }
}
