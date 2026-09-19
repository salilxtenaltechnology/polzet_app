// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/api_service.dart';
import '../../../../api/api_config.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/feather_icons_compat.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import 'group_created_success_screen.dart';

class CreateGroupAddMember extends StatefulWidget {
  final Set<String> alreadySelected;
  final String? groupTitle;
  final String? groupDescription;
  final File? groupImage;
  final String? groupCategory;
  final String? groupPrivacy;

  const CreateGroupAddMember({
    super.key,
    this.alreadySelected = const {},
    this.groupTitle,
    this.groupDescription,
    this.groupImage,
    this.groupCategory,
    this.groupPrivacy,
  });

  @override
  State<CreateGroupAddMember> createState() => _CreateGroupAddMemberState();
}

class _CreateGroupAddMemberState extends State<CreateGroupAddMember>
    with UtilityMixin {
  final _apiServices = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  late Set<String> _selectedIds;
  bool _isLoadingUsers = false;
  bool _isCreating = false;

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

  List<Map<String, dynamic>> get _selectedUsers {
    return _allUsers.where((u) {
      final id = (u['id'] ?? u['uuid'] ?? u['_id'] ?? u['user_id'])?.toString() ?? '';
      return _selectedIds.contains(id);
    }).toList();
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
        final id = (user['id'] ?? user['uuid'] ?? user['_id'] ?? user['user_id'])
                ?.toString() ??
            '';
        if (id.isNotEmpty && seen.add(id)) {
          merged.add(user);

          final username = user['username']?.toString().toLowerCase() ?? '';
          final name =
              user['name']?.toString().toLowerCase() ??
              user['username']?.toString().toLowerCase() ??
              '';

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
    if (id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'polzet_user')
          .toString();

  String? _resolveProfileUrl(String? url) {
    if (url == null ||
        url.trim().isEmpty ||
        url.trim().toLowerCase() == 'null') {
      return null;
    }
    if (url.startsWith('http') || url.startsWith('data:image')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${ApiConfig.baseUrlImage}$url';
    } else {
      return '${ApiConfig.baseUrlImage}/$url';
    }
  }

  String? _userAvatar(Map<String, dynamic> user) {
    final avatar = (user['avatar'] ??
            user['profile_picture_url'] ??
            user['profile_image'] ??
            user['image'] ??
            user['photo'] ??
            user['profile_picture'])
        ?.toString();
    return _resolveProfileUrl(avatar);
  }

  Future<void> _createGroup() async {
    if (_selectedIds.isEmpty) {
      showToast(message: 'Please select at least one member');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final result = await _apiServices.createGroup(
        title: widget.groupTitle ?? '',
        description: widget.groupDescription,
        profileImage: widget.groupImage,
        members: _selectedIds.toList(),
        category: widget.groupCategory ?? 'general',
        privacy: widget.groupPrivacy ?? 'public',
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            PageTransition(
              type: PageTransitionType.fade,
              duration: const Duration(milliseconds: 300),
              child: const GroupCreatedSuccessScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        showToast(message: 'Failed to create group');
      }
    } catch (e) {
      debugPrint('Error creating group: $e');
      showToast(message: 'Failed to create group');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _onBottomButtonPressed() {
    if (widget.groupTitle != null) {
      _createGroup();
    } else {
      final selectedUsers = _allUsers
          .where((u) {
            final id = (u['id'] ?? u['uuid'] ?? u['_id'] ?? u['user_id'])?.toString() ?? '';
            return _selectedIds.contains(id);
          })
          .toList();
      Navigator.pop(context, {'ids': _selectedIds, 'users': selectedUsers});
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selectedCount = _selectedIds.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.addmemberstogroup,
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
                  hintText: AppLocalizations.of(context)!.searchusers,
                  hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    FeatherIcons.search,
                    size: 17.spMax,
                    color: const Color(0XFF898989),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchController.clear();
                          },
                          child: Icon(
                            Icons.close,
                            size: 18.sp,
                            color: const Color(0XFF898989),
                          ),
                        )
                      : null,
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
            SizedBox(height: 12.h),
            _buildSelectedUsersSection(),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 25),
        height: 90,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: widget.groupTitle != null
              ? (selectedCount > 0
                  ? '${AppLocalizations.of(context)!.creategroup} ($selectedCount)'
                  : AppLocalizations.of(context)!.creategroup)
              : (selectedCount > 0
                  ? '${AppLocalizations.of(context)!.add} ($selectedCount)'
                  : AppLocalizations.of(context)!.add),
          onPressed: (_isCreating || _selectedIds.isEmpty)
              ? null
              : _onBottomButtonPressed,
          isLoading: _isCreating,
        ),
      ),
    );
  }

  Widget _buildSelectedUsersSection() {
    if (_selectedIds.isEmpty) return const SizedBox.shrink();
    final selectedUsers = _selectedUsers;
    if (selectedUsers.isEmpty) return const SizedBox.shrink();

    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      height: 74.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: selectedUsers.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final user = selectedUsers[index];
          final id = (user['id'] ?? user['uuid'] ?? user['_id'] ?? user['user_id'])?.toString() ?? '';
          final avatarUrl = _userAvatar(user);
          final username = user['username'] as String? ?? _userName(user);
          final firstName = user['first_name'] as String? ?? '';
          final displayName = firstName.isNotEmpty ? firstName : username;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleMember(id),
            child: SizedBox(
              width: 54.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
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
                            radius: 21.r,
                            backgroundImage: imageBytes != null
                                ? MemoryImage(imageBytes)
                                : (hasNetworkImage ? NetworkImage(avatarUrl) : null),
                            backgroundColor: (imageBytes == null && !hasNetworkImage)
                                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                                : null,
                            child: (imageBytes == null && !hasNetworkImage)
                                ? Text(
                                    initial,
                                    style: AppTextStyles.subText.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15.sp,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF2C2C30) : const Color(0xFFE0E0E0),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.background,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 10.sp,
                            color: txt.body,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.title,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserList() {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
              )!.startchasingpeopletodiscoverfreshopinionsthenwillappearusershere,
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
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final id = (user['id'] ?? user['uuid'] ?? user['_id'] ?? user['user_id'])?.toString() ?? '';
        final isSelected = _selectedIds.contains(id);
        final avatarUrl = _userAvatar(user);
        final firstName = user['first_name'] as String? ?? '';
        final lastName = user['last_name'] as String? ?? '';
        final username = user['username'] as String? ?? _userName(user);
        final fullName = '$firstName $lastName'.trim();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10.r),
            onTap: () => _toggleMember(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: isSelected
                    ? (isDarkMode
                        ? const Color(0xFF1E202B)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.06))
                    : Colors.transparent,
              ),
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
                        radius: 19.r,
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
                                  fontSize: 16.sp,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  SizedBox(width: 11.w),
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
                    height: 22.r,
                    width: 22.r,
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
                              ).colorScheme.onSurface.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 13.sp, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

