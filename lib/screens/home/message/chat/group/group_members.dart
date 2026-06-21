// ignore_for_file: unused_field, must_be_immutable, deprecated_member_use
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';
import '../../../../../api/api_config.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../provider/group_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../core/utils/bottomsheet_util.dart';

class GroupMembers extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final int chatId;
  const GroupMembers({super.key, required this.members, required this.chatId});

  @override
  State<GroupMembers> createState() => _GroupMembersState();
}

class _GroupMembersState extends State<GroupMembers> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatJoinedDate(String? joinedAtStr) {
    if (joinedAtStr == null) return '';
    try {
      final dt = DateTime.parse(joinedAtStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return '';
    }
  }

  /// Extracts the nested user map from a member entry
  /// Structure: { user: { id, username, profile_image }, is_admin: bool }
  Map<String, dynamic> _user(Map<String, dynamic> member) =>
      Map<String, dynamic>.from(member['user'] as Map? ?? {});

  /// Deduplicates members by user id
  List<Map<String, dynamic>> _deduplicated(List<Map<String, dynamic>> source) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final m in source) {
      final id = _user(m)['id']?.toString() ?? '';
      if (id.isNotEmpty && seen.add(id)) result.add(m);
    }
    return result;
  }

  List<Map<String, dynamic>> _getDisplayList(
    List<Map<String, dynamic>> providerMembers,
  ) {
    final deduped = _deduplicated(providerMembers);
    if (_searchQuery.isEmpty) return deduped;
    return deduped.where((m) {
      final name = (_user(m)['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  bool _isCurrentUserAdmin(GroupChatProvider provider) {
    final currentUsername = context.read<UserProvider>().username;
    if (currentUsername != null && currentUsername.isNotEmpty) {
      for (final member in provider.members) {
        final user = member['user'] as Map?;
        if (user != null) {
          final uName = user['username']?.toString();
          if (uName != null &&
              uName.toLowerCase() == currentUsername.toLowerCase()) {
            if (member['is_admin'] == true) return true;
            final userId = user['id'];
            if (userId != null && provider.isAdmin(userId)) return true;
          }
        }
      }
    }

    final id = context.read<UserProvider>().userId;
    if (id == null) return false;
    return provider.isAdmin(id);
  }

  ImageProvider? _avatarProvider(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String resolved = raw;
    if (!resolved.startsWith('http')) {
      final separator = resolved.startsWith('/') ? '' : '/';
      resolved = '${ApiConfig.baseUrlImage}$separator$resolved';
    }
    return NetworkImage(resolved);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _removeMember(dynamic userId, String username) async {
    final provider = context.read<GroupChatProvider>();

    provider.removeMemberOptimistically(userId);

    final success = await provider.removeMember(userId);

    if (mounted && !success) {
      await provider.refreshChatData();
      showToast(message: 'Failed to remove $username');
    } else if (mounted && success) {
      showToast(message: '$username removed from group');
    }
  }

  Future<void> _makeAdmin(dynamic userId, String username) async {
    final provider = context.read<GroupChatProvider>();

    provider.updateMemberAdminStatus(userId, true);

    final success = await provider.makeAdmin(userId);

    if (mounted && !success) {
      provider.updateMemberAdminStatus(userId, false);
      showToast(message: 'Failed to make $username admin');
    } else if (mounted && success) {
      showToast(message: '$username is now admin');
    }
  }

  Future<void> _handleAddMembers(bool isCurrentUserAdmin) async {
    if (!isCurrentUserAdmin) return;

    final provider = context.read<GroupChatProvider>();

    final existingIds = _deduplicated(provider.members)
        .map((m) => _user(m)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final existingUsernames = _deduplicated(provider.members)
        .map((m) => _user(m)['username']?.toString() ?? '')
        .where((un) => un.isNotEmpty)
        .toSet();

    final Set<String> selectionSet = {...existingIds, ...existingUsernames};

    final result = await BottomSheetUtils.showAddMembersBottomSheet(
      context: context,
      alreadySelected: selectionSet,
    );

    if (result == null) return;

    final selectedIds = result['ids'] as Set<String>;
    final selectedUsers = result['users'] as List<Map<String, dynamic>>;

    final newIds = selectedIds.difference(existingIds);
    final newUsers = selectedUsers
        .where((u) => newIds.contains(u['id']?.toString() ?? ''))
        .toList();

    if (newIds.isEmpty) {
      showToast(message: 'Selected users are already in the group');
      return;
    }

    provider.addMembersOptimistically(newUsers);

    final success = await provider.addGroupMembers(newIds.toList(), newUsers);

    if (!success && mounted) {
      provider.rollbackOptimisticMembers(newIds);
      showToast(message: 'Failed to add members');
    } else if (success && mounted) {
      showToast(message: '${newIds.length} member(s) added');
    }
  }

  void _showOptions(dynamic userId, String username, bool isAdmin) {
    final txt = AppTextColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal),
        ),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4.h,
                  width: 40.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                username,
                style: TextStyle(
                  color: txt.title,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5.h),

              if (!isAdmin) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _makeAdmin(userId, username);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 20.spMax,
                          color: AppColors.primaryColor,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          AppLocalizations.of(context)!.makeadmin,
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
              ],

              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _removeMember(userId, username);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 20.spMax,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        AppLocalizations.of(context)!.removefromgroup,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final provider = context.watch<GroupChatProvider>();
    final providerMembers = provider.members;
    final isCurrentUserAdmin = _isCurrentUserAdmin(provider);
    final displayList = _getDisplayList(providerMembers);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.members,
        showBackButton: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: GestureDetector(
              onTap: () => _handleAddMembers(isCurrentUserAdmin),
              child: Icon(
                FeatherIcons.userPlus,
                size: 20.spMax,
                color: isCurrentUserAdmin
                    ? Theme.of(context).colorScheme.onBackground
                    : Colors.transparent,
              ),
            ),
          ),
        ],
      ),

      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 10.h),
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: const [AppConstants.cardShadow],
              ),
              child: TextField(
                controller: _searchController,
                cursorColor: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.8),
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(
                    right: 12.w,
                    left: 12.w,
                    top: 10.h,
                  ),
                  hintText: AppLocalizations.of(context)!.searchusers,
                  hintStyle: AppTextStyles.bodyText.copyWith(
                    color: txt.muted.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    FeatherIcons.search,
                    size: 17.spMax,
                    color: const Color(0XFF898989),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.1),
                      width: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                style: TextStyle(
                  color: txt.title,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // ── Members list ───────────────────────────────────────────────
            Expanded(
              child: displayList.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.usernotfound,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.4),
                          fontSize: 11.sp,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, i) {
                        final member = displayList[i];
                        final user = _user(member);

                        final dynamic memberId = user['id'];
                        final String username =
                            user['username']?.toString() ?? '';
                        final String? profileImage = user['profile_image']
                            ?.toString();

                        final bool isAdmin = memberId != null
                            ? provider.isAdmin(memberId)
                            : false;

                        final String? currentUserId = context
                            .read<UserProvider>()
                            .userId;
                        final bool isSelf =
                            memberId?.toString() == currentUserId;

                        final String? joinedAtVal =
                            member['joined_at']?.toString() ??
                            user['joined_at']?.toString();
                        final String joinedDate = _formatJoinedDate(
                          joinedAtVal,
                        );

                        final presence = provider.memberPresence[memberId];
                        final bool isOnline =
                            isSelf ||
                            (presence?.isOnline ??
                                (member['is_online'] == true ||
                                    user['is_online'] == true));

                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: GestureDetector(
                            onTap: isCurrentUserAdmin && !isSelf
                                ? () =>
                                      _showOptions(memberId!, username, isAdmin)
                                : null,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              margin: const EdgeInsets.only(bottom: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // ── Avatar ───────────────────────────────
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: _avatarProvider(
                                      profileImage,
                                    ),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.1),
                                    child:
                                        profileImage == null ||
                                            profileImage.isEmpty
                                        ? Text(
                                            username.isNotEmpty
                                                ? username[0].toUpperCase()
                                                : 'P',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 10.w),

                                  // ── Details (Username + Status / Date) ───
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          username,
                                          style: TextStyle(
                                            color: txt.title,
                                            fontSize: 11.2.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 2.h),
                                        Row(
                                          children: [
                                            Text(
                                              isOnline ? 'Online' : 'Offline',
                                              style: TextStyle(
                                                color: isOnline
                                                    ? const Color(0XFF16A34A)
                                                    : txt.muted,
                                                fontSize: 9.2.sp,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (joinedDate.isNotEmpty) ...[
                                              SizedBox(width: 6.w),
                                              Text(
                                                '•',
                                                style: TextStyle(
                                                  color: txt.muted,
                                                  fontSize: 9.2.sp,
                                                ),
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'Joined $joinedDate',
                                                style: TextStyle(
                                                  color: txt.muted,
                                                  fontSize: 9.2.sp,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── Admin badge / more icon ───────────────
                                  if (isAdmin)
                                    Text(
                                      AppLocalizations.of(context)!.admin,
                                      style: TextStyle(
                                        color: const Color(0XFF16A34A),
                                        fontSize: 10.2.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else if (isCurrentUserAdmin && !isSelf)
                                    GestureDetector(
                                      onTap: () => _showOptions(
                                        memberId!,
                                        username,
                                        isAdmin,
                                      ),
                                      child: Icon(
                                        Icons.more_vert,
                                        size: 18.spMax,
                                        color: txt.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
