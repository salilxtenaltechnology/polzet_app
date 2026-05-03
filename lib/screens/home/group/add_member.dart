// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/custom_text_styles.dart';

class AddMember extends StatefulWidget {
  /// Pre-selected IDs passed from CreateGroup (so selections survive back/forth)
  final Set<int> alreadySelected;

  const AddMember({super.key, this.alreadySelected = const {}});

  @override
  State<AddMember> createState() => AddMemberState();
}

class AddMemberState extends State<AddMember> with UtilityMixin {
  final _apiServices = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  late Set<int> _selectedIds;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<int>.from(widget.alreadySelected);
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

      final seen = <int>{};
      final merged = <Map<String, dynamic>>[];

      for (final user in [...results[0], ...results[1]]) {
        final id = user['id'];
        if (id is int && seen.add(id)) merged.add(user);
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
          : _allUsers
                .where((u) => _userName(u).toLowerCase().contains(query))
                .toList();
    });
  }

  void _toggleMember(int id) => setState(() {
    _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
  });

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'Unknown')
          .toString();

  String? _userAvatar(Map<String, dynamic> user) =>
      (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])
          ?.toString();

  void _onAdd() {
    final selectedUsers = _allUsers
        .where((u) => _selectedIds.contains(u['id']))
        .toList();
    Navigator.pop(context, {'ids': _selectedIds, 'users': selectedUsers});
  }

  @override
  Widget build(BuildContext context) {
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
              margin: EdgeInsets.only(top: 10.h),
              height: AppConstants.searchbarHeight.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: const [AppConstants.cardShadow],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(
                    right: 12.w,
                    left: 12.w,
                    top: 10.h,
                  ),
                  hintText: AppLocalizations.of(context)!.searchusers,
                  hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                  border: InputBorder.none,
                  suffixIcon: Icon(
                    FeatherIcons.search,
                    size: 17.spMax,
                    color: Theme.of(context).colorScheme.onBackground,
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
                    borderSide: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
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
        padding: EdgeInsets.fromLTRB(12.w, 5.h, 12.w, 12.h),
        height: 50.h,
        child: GestureDetector(
          onTap: _selectedIds.isEmpty ? null : _onAdd,
          child: Container(
            width: double.infinity,

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
                  color: Colors.white,
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
    if (_isLoadingUsers) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FeatherIcons.users,
              size: 40.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            SizedBox(height: 10.h),
            Text(
              AppLocalizations.of(context)!.nousersfound,
              style: CustomTextStyles.lblSecondryText(context),
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
        final id = user['id'] as int;
        final isSelected = _selectedIds.contains(id);
        final avatarUrl = _userAvatar(user);

        return GestureDetector(
          onTap: () => _toggleMember(id),
          child: Container(
            height: 40.h,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x13000000),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Builder(
                  builder: (_) {
                    final imageBytes = avatarUrl != null
                        ? getProfileImage(avatarUrl)
                        : null;
                    final initial = _userName(user).trim().isNotEmpty
                        ? _userName(user).trim()[0].toUpperCase()
                        : '?';
                    return CircleAvatar(
                      radius: 13.r,
                      backgroundImage: imageBytes != null
                          ? MemoryImage(imageBytes)
                          : null,
                      backgroundColor: imageBytes == null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      child: imageBytes == null
                          ? Text(
                              initial,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _userName(user),
                    style: AppTextStyles.bodyText.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    overflow: TextOverflow.ellipsis,
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
