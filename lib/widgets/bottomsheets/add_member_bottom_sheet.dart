// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';

class AddMemberBottomSheet extends StatefulWidget {
  /// Pre-selected IDs passed from parent (so selections survive re-opens)
  final Set<int> alreadySelected;

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
  late Set<int> _selectedIds;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    // Clone so we don't mutate the caller's set
    _selectedIds = Set<int>.from(widget.alreadySelected);
    _fetchUsers();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────

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

  // ── Search ─────────────────────────────────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _toggleMember(int id) => setState(() {
    _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
  });

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'Unknown')
          .toString();

  String? _userAvatar(Map<String, dynamic> user) =>
      (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])
          ?.toString();

  /// Pop and return selected IDs + their full user maps to caller
  void _onAdd() {
    final selectedUsers = _allUsers
        .where((u) => _selectedIds.contains(u['id']))
        .toList();
    Navigator.pop(context, {'ids': _selectedIds, 'users': selectedUsers});
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          // ── Handle bar ──────────────────────────────────────────────────
          Container(
            margin: EdgeInsets.only(top: 10.h),
            height: 4.h,
            width: 40.w,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),

          // ── Title ───────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                'Add Members',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Container(
              height: 34.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(
                    right: 12.w,
                    left: 12.w,
                    top: 10.h,
                  ),
                  hintText: 'Search',
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
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: AppColors.primaryColor,
                      width: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          // ── User list ───────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: _buildUserList(),
            ),
          ),

          // ── Add button ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).colorScheme.background,
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
                  borderRadius: BorderRadius.circular(50.r),
                ),
                child: Center(
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Add'
                        : 'Add (${_selectedIds.length})',
                    style: CustomTextStyles.btnPrimaryText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User list widget ────────────────────────────────────────────────────────

  Widget _buildUserList() {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
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
              'No users found',
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
          child: CustomCard(
            widget: Row(
              children: [
                // ── Avatar ───────────────────────────────────────────────
                Builder(
                  builder: (_) {
                    final imageBytes = avatarUrl != null
                        ? getProfileImage(avatarUrl)
                        : null;
                    final initial = _userName(user).trim().isNotEmpty
                        ? _userName(user).trim()[0].toUpperCase()
                        : '?';
                    return CircleAvatar(
                      radius: 15.r,
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
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    );
                  },
                ),

                SizedBox(width: 12.w),

                // ── Name ─────────────────────────────────────────────────
                Expanded(
                  child: Text(
                    _userName(user),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 11.2.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ── Checkbox ─────────────────────────────────────────────
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
