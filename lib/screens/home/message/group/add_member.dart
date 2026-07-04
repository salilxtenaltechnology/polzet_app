// ignore_for_file: deprecated_member_use

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../../api/api_service.dart';
import '../../../../api/api_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/custom_text_styles.dart';

class AddMember extends StatefulWidget {
  final Set<String> alreadySelected;

  const AddMember({super.key, this.alreadySelected = const {}});

  @override
  State<AddMember> createState() => AddMemberState();
}

class AddMemberState extends State<AddMember> with UtilityMixin {
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

  void _toggleMember(String id) => setState(() {
    _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
  });

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
    final avatar = (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])?.toString();
    return _resolveProfileUrl(avatar);
  }

  void _onAdd() {
    final selectedUsers = _allUsers
        .where((u) => _selectedIds.contains(u['id']?.toString()))
        .toList();
    Navigator.pop(context, {'ids': _selectedIds, 'users': selectedUsers});
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
        color: Theme.of(context).colorScheme.background,
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 35),
        child: GestureDetector(
          onTap: _selectedIds.isEmpty ? null : _onAdd,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: _selectedIds.isEmpty
                  ? AppColors.primaryColor.withOpacity(0.4)
                  : AppColors.primaryColor,
              borderRadius: AppRadius.buttonRadius,
            ),
            child: Center(
              child: Text(
                _selectedIds.isEmpty
                    ? AppLocalizations.of(context)!.add
                    : '${AppLocalizations.of(context)!.addmemberstogroup} (${_selectedIds.length})',
                style: AppTextStyles.bodyText.copyWith(
                  color: _selectedIds.isEmpty
                      ? const Color(0xFF898989).withOpacity(0.6)
                      : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
            margin: const EdgeInsets.only(bottom: 5),
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
                    final imageBytes = avatarUrl != null
                        ? getProfileImage(avatarUrl)
                        : null;
                    final hasNetworkImage = imageBytes == null &&
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
