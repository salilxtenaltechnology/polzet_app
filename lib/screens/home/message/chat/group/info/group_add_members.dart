// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../../../api/api_config.dart';
import '../../../../../../api/api_service.dart';
import '../../../../../../core/constants/app_radius.dart';
import '../../../../../../core/constants/feather_icons_compat.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../provider/group_chat_provider.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/base64/image_convert.dart';
import '../../../../../../widgets/button/primary_button.dart';
import '../../../../../../widgets/custom_text_styles.dart';
import '../../../../../../widgets/loader.dart';
import '../../../../../../widgets/show_toast.dart';

class GroupAddMembers extends StatefulWidget {
  final Set<String> alreadySelected;
  final String? groupId;

  const GroupAddMembers({
    super.key,
    this.alreadySelected = const {},
    this.groupId,
  });

  @override
  State<GroupAddMembers> createState() => _GroupAddMembersState();
}

class _GroupAddMembersState extends State<GroupAddMembers> with UtilityMixin {
  final _apiServices = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  late Set<String> _selectedIds;
  final Set<String> _alreadyInGroupIds = {};
  bool _isLoadingUsers = false;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
    _fetchUsers();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final futures = <Future<dynamic>>[
        _apiServices.getFollowersList(),
        _apiServices.getFollowingList(),
      ];
      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        futures.add(_apiServices.getGroupChatInfo(chatId: widget.groupId!));
      }

      final results = await Future.wait(futures);

      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];

      // Collect all existing member identifiers
      final existingIdentifiers = <String>{...widget.alreadySelected};

      // 1. From GroupChatProvider if available
      try {
        final provider = context.read<GroupChatProvider>();
        for (final m in provider.members) {
          final user = (m['user'] is Map) ? m['user'] as Map : m;
          final id = (user['id'] ?? user['uuid'] ?? m['id'] ?? m['uuid'])
              ?.toString();
          final username = (user['username'] ?? m['username'])
              ?.toString()
              .toLowerCase();
          final name =
              (user['name'] ?? user['full_name'] ?? m['name'] ?? m['full_name'])
                  ?.toString()
                  .toLowerCase();
          if (id != null && id.isNotEmpty) existingIdentifiers.add(id);
          if (username != null && username.isNotEmpty) {
            existingIdentifiers.add(username);
          }
          if (name != null && name.isNotEmpty) existingIdentifiers.add(name);
        }
      } catch (_) {}

      // 2. From getGroupChatInfo response if groupId was provided
      if (results.length > 2 && results[2] is Map) {
        final groupInfo = results[2] as Map<String, dynamic>;
        final groupMembers = groupInfo['members'] as List<dynamic>? ?? [];
        for (final m in groupMembers) {
          if (m is Map) {
            final user = (m['user'] is Map) ? m['user'] as Map : m;
            final id = (user['id'] ?? user['uuid'] ?? m['id'] ?? m['uuid'])
                ?.toString();
            final username = (user['username'] ?? m['username'])
                ?.toString()
                .toLowerCase();
            final name =
                (user['name'] ??
                        user['full_name'] ??
                        m['name'] ??
                        m['full_name'])
                    ?.toString()
                    .toLowerCase();
            if (id != null && id.isNotEmpty) existingIdentifiers.add(id);
            if (username != null && username.isNotEmpty) {
              existingIdentifiers.add(username);
            }
            if (name != null && name.isNotEmpty) existingIdentifiers.add(name);
          }
        }
      }

      for (final user in [...results[0], ...results[1]]) {
        final id = user['id']?.toString() ?? '';
        if (id.isNotEmpty && seen.add(id)) {
          merged.add(user);

          final username = user['username']?.toString().toLowerCase() ?? '';
          final name =
              user['name']?.toString().toLowerCase() ??
              user['username']?.toString().toLowerCase() ??
              '';

          final bool isAlreadySelected = existingIdentifiers.any((sel) {
            final selLower = sel.toLowerCase();
            return selLower == id || selLower == username || selLower == name;
          });

          if (isAlreadySelected) {
            _selectedIds.add(id);
            _alreadyInGroupIds.add(id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _allUsers = merged;
          _filteredUsers = merged;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = query.isEmpty
          ? _allUsers
          : _allUsers.where((u) {
              final username = (u['username'] as String?)?.toLowerCase() ?? '';
              final firstName =
                  (u['first_name'] as String?)?.toLowerCase() ?? '';
              final lastName = (u['last_name'] as String?)?.toLowerCase() ?? '';
              final fullName = '$firstName $lastName'.trim();
              final name = (u['name'] as String?)?.toLowerCase() ?? '';
              return username.contains(query) ||
                  firstName.contains(query) ||
                  lastName.contains(query) ||
                  fullName.contains(query) ||
                  name.contains(query);
            }).toList();
    });
  }

  void _toggleMember(String id) {
    if (widget.groupId != null && _alreadyInGroupIds.contains(id)) return;
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  bool get _hasNewSelection {
    if (widget.groupId != null) {
      return _selectedIds.any((id) => !_alreadyInGroupIds.contains(id));
    }
    return _selectedIds.isNotEmpty;
  }

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'polzet_user')
          .toString();

  String? _resolveProfileUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (!url.startsWith('http') && !url.startsWith('data:image')) {
      if (url.startsWith('/')) {
        return '${ApiConfig.baseUrlImage}$url';
      } else {
        return '${ApiConfig.baseUrlImage}/$url';
      }
    }
    return url;
  }

  String? _userAvatar(Map<String, dynamic> user) {
    final avatar =
        (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])
            ?.toString();
    return _resolveProfileUrl(avatar);
  }

  Future<void> _onBottomButtonPressed() async {
    final newSelectedIds = _selectedIds
        .where((id) => !_alreadyInGroupIds.contains(id))
        .toList();

    if (widget.groupId != null) {
      if (newSelectedIds.isEmpty) return;

      setState(() => _isAdding = true);

      final newUsers = _allUsers
          .where((u) => newSelectedIds.contains(u['id']?.toString()))
          .toList();

      GroupChatProvider? provider;
      try {
        provider = context.read<GroupChatProvider>();
      } catch (_) {}

      // Add members optimistically to provider
      if (provider != null && newUsers.isNotEmpty) {
        provider.addMembersOptimistically(newUsers);
      }

      try {
        final result = await _apiServices.addGroupChatMembers(
          groupChatId: widget.groupId!,
          members: newSelectedIds,
        );

        final isSuccess =
            result['success'] == true ||
            result['message'] == 'Members added' ||
            result['added'] != null;

        if (isSuccess) {
          if (provider != null) {
            await provider.refreshChatData();
          }
          if (mounted) {
            showToast(
              message: result['message'] ?? 'Members added successfully',
            );
            Navigator.pop(context, true);
          }
        } else {
          if (provider != null) {
            provider.rollbackOptimisticMembers(newSelectedIds.toSet());
          }
          if (mounted) {
            showToast(message: result['message'] ?? 'Failed to add members');
          }
        }
      } catch (e) {
        debugPrint('Error adding members: $e');
        if (provider != null) {
          provider.rollbackOptimisticMembers(newSelectedIds.toSet());
        }
        if (mounted) {
          showToast(message: 'Failed to add members');
        }
      } finally {
        if (mounted) setState(() => _isAdding = false);
      }
    } else {
      if (_selectedIds.isEmpty) return;
      final selectedUsers = _allUsers
          .where((u) => _selectedIds.contains(u['id']?.toString()))
          .toList();
      Navigator.pop(context, {'ids': _selectedIds, 'users': selectedUsers});
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)?.addmemberstogroup ?? 'Add Members',
        showBackButton: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            Container(
              height: 43,
              margin: EdgeInsets.only(top: 10.h),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
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
                  hintText:
                      AppLocalizations.of(context)?.searchusers ??
                      'Search users',
                  hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    FeatherIcons.search,
                    size: 17.spMax,
                    color: const Color(0XFF898989),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.title,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 15.h),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 25),
        height: 90,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)?.add ?? 'Add',
          onPressed: (_isAdding || !_hasNewSelection)
              ? null
              : _onBottomButtonPressed,
          isLoading: _isAdding,
        ),
      ),
    );
  }

  Widget _buildUserList() {
    final txt = AppTextColors.of(context);
    if (_isLoadingUsers) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(
                    context,
                  )?.startchasingpeopletodiscoverfreshopinionsthenwillappearusershere ??
                  'No users found',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                color: txt.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filteredUsers.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final id = user['id']?.toString() ?? '';
        final isSelected = _selectedIds.contains(id);
        final avatarUrl = _userAvatar(user);
        final firstName = user['first_name'] as String? ?? '';
        final lastName = user['last_name'] as String? ?? '';
        final username = user['username'] as String? ?? _userName(user);
        final fullName = '$firstName $lastName'.trim();

        return GestureDetector(
          onTap: () => _toggleMember(id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Builder(
                  builder: (_) {
                    final imageBytes = avatarUrl != null
                        ? getProfileImage(avatarUrl)
                        : null;
                    final hasNetworkImage =
                        imageBytes == null &&
                        avatarUrl != null &&
                        avatarUrl.trim().isNotEmpty &&
                        avatarUrl.startsWith('http');
                    final initial = username.trim().isNotEmpty
                        ? username.trim()[0].toUpperCase()
                        : 'P';
                    return CircleAvatar(
                      radius: 19,
                      backgroundImage: imageBytes != null
                          ? MemoryImage(imageBytes)
                          : (hasNetworkImage ? NetworkImage(avatarUrl) : null),
                      backgroundColor: (imageBytes == null && !hasNetworkImage)
                          ? Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.1)
                          : null,
                      child: (imageBytes == null && !hasNetworkImage)
                          ? Text(
                              initial,
                              style: AppTextStyles.subText.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 17,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: txt.body,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (fullName.isNotEmpty) ...[
                        Text(
                          fullName,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.5,
                            color: txt.muted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        Text(
                          username,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.5,
                            color: txt.muted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 20.sp,
                  width: 20.sp,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 12.sp, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
