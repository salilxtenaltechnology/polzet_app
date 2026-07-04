// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/api_config.dart';
import '../../../api/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../loader.dart';

class AddMemberBottomSheet extends StatefulWidget {
  final Set<String> alreadySelected;

  const AddMemberBottomSheet({super.key, this.alreadySelected = const {}});

  @override
  State<AddMemberBottomSheet> createState() => _AddMemberBottomSheetState();
}

class _AddMemberBottomSheetState extends State<AddMemberBottomSheet>
    with UtilityMixin {
  final _apiServices = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  late Set<String> _selectedIds;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
    _fetchUsers();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final results = await Future.wait([
        _apiServices.getFollowersList(),
        _apiServices.getFollowingList(),
      ]);

      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];

      for (final user in [...results[0], ...results[1]]) {
        final id = user['id']?.toString() ?? '';
        if (id.isNotEmpty && seen.add(id)) {
          merged.add(user);

          final username = user['username']?.toString().toLowerCase() ?? '';
          final name = user['name']?.toString().toLowerCase() ?? user['username']?.toString().toLowerCase() ?? '';

          final bool isAlreadySelected = widget.alreadySelected.any((sel) {
            final selLower = sel.toLowerCase();
            return selLower == id || selLower == username || selLower == name;
          });

          if (isAlreadySelected) {
            _selectedIds.add(id);
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
              final firstName = (u['first_name'] as String?)?.toLowerCase() ?? '';
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

  void _toggleMember(String id) => setState(() {
    _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
  });

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'Unknown')
          .toString();

  String? _userAvatar(Map<String, dynamic> user) =>
      (user['profile_image'] ??
              user['avatar'] ??
              user['profile_picture_url'] ??
              user['image'] ??
              user['photo'] ??
              user['profile_picture'])
          ?.toString();

  ImageProvider? _avatarProvider(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(raw.split(',').last));
      } catch (_) {
        return null;
      }
    }
    // Check if it is base64 string
    if (!raw.startsWith('/') && !raw.startsWith('http') && !raw.contains('/')) {
      try {
        return MemoryImage(base64Decode(raw.split(',').last));
      } catch (_) {
        // Fall through to network
      }
    }
    String resolved = raw;
    if (!resolved.startsWith('http')) {
      if (resolved.startsWith('/')) {
        resolved = '${ApiConfig.baseUrlImage}$resolved';
      } else {
        resolved = '${ApiConfig.baseUrlImage}/$resolved';
      }
    }
    return NetworkImage(resolved);
  }

  void _onAdd() {
    final selectedUsers = _allUsers
        .where((u) => _selectedIds.contains(u['id']?.toString()))
        .map((u) {
          final normalized = Map<String, dynamic>.from(u);
          normalized['profile_image'] ??=
              u['profile_image'] ??
              u['avatar'] ??
              u['profile_picture_url'] ??
              u['image'] ??
              u['photo'] ??
              u['profile_picture'];
          return normalized;
        })
        .toList();

    Navigator.pop(context, {'ids': _selectedIds, 'users': selectedUsers});
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
       top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.modal),
            topRight: Radius.circular(AppRadius.modal),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 10.h),
              height: 4.h,
              width: 40.w,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.addmember,
                  style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Container(
                height: 43,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: TextField(
                  controller: _searchController,
                  cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                cursorWidth: 1.5,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.only(
                      right: 12.w,
                      left: 12.w,
                      top: 10.h,
                    ),
                    hintText: AppLocalizations.of(context)!.searchusers,
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
                  style: TextStyle(
                    color: txt.title,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: _buildUserList(),
              ),
            ),
            Container(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: EdgeInsets.fromLTRB(12.w, 5.h, 12.w, 16.h),
              child: GestureDetector(
                onTap: _selectedIds.isEmpty ? null : _onAdd,
                child: Container(
                  width: double.infinity,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: _selectedIds.isEmpty
                        ? AppColors.primaryColor.withOpacity(0.4)
                        : AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: Center(
                    child: Text(
                      _selectedIds.isEmpty
                          ? AppLocalizations.of(context)!.add
                          : '${AppLocalizations.of(context)!.add} (${_selectedIds.length})',
                      style: CustomTextStyles.btnPrimaryText,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
        child: Text(
          AppLocalizations.of(context)!.nousersfound,
          style: CustomTextStyles.lblSecondryText(context),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 2),
              ],
            ),
            child: Row(
              children: [
                Builder(
                  builder: (_) {
                    final provider = _avatarProvider(avatarUrl);
                    final initial = username.trim().isNotEmpty
                        ? username.trim()[0].toUpperCase()
                        : 'P';
                    return CircleAvatar(
                      radius: 19,
                      backgroundImage: provider,
                      backgroundColor: provider == null
                          ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                          : null,
                      child: provider == null
                          ? Text(
                              initial,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: txt.body,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (fullName.isNotEmpty) ...[
                        Text(
                          fullName,
                          style: TextStyle(
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
                          style: TextStyle(
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
