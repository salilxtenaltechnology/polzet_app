// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';

import '../../../api/services/api_service.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/button/primary_button.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/text_field/secondry_textfield.dart';
import 'add_member.dart';

class CreateGroup extends StatefulWidget {
  const CreateGroup({super.key});

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> with UtilityMixin {
  final _apiServices = ApiService();
  final _groupNameController = TextEditingController();

  /// Selected member IDs to pass to API
  Set<int> _selectedIds = {};

  /// Full user maps for displaying the selected members list
  List<Map<String, dynamic>> _selectedUsers = [];

  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  // ── Open AddMember and receive selection back ────────────────────────────────

  Future<void> _openAddMember() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMember(alreadySelected: _selectedIds),
      ),
    );

    // result is null if user pressed Cancel (Navigator.pop with no data)
    if (result == null) return;

    setState(() {
      _selectedIds = result['ids'] as Set<int>;
      _selectedUsers = List<Map<String, dynamic>>.from(result['users'] as List);
    });
  }

  // ── Create group API ─────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      _showSnackBar('Please enter a group name.');
      return;
    }
    if (_selectedIds.isEmpty) {
      _showSnackBar('Please select at least one member.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final result = await _apiServices.createGroup(
        title: groupName,
        members: _selectedIds.toList(),
      );

      if (result['success'] == true) {
        if (mounted) Navigator.pop(context, result['chat_id']);
      } else {
        _showSnackBar(result['message'] ?? 'Failed to create group.');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _removeMember(int id) {
    setState(() {
      _selectedIds.remove(id);
      _selectedUsers.removeWhere((u) => u['id'] == id);
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'Unknown')
          .toString();

  String? _userAvatar(Map<String, dynamic> user) =>
      (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])
          ?.toString();

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        title: Text(
          'Create Group',
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12).w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name Group',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 5.h),
            SecondryTextfield(
              controller: _groupNameController,
              hintText: 'Enter group name',
            ),
            SizedBox(height: 15.h),
            Row(
              children: [
                Text(
                  'Members',
                   style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  Text(
                    '${_selectedIds.length} selected',
                    style: CustomTextStyles.lblSecondryText(
                      context,
                    ).copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _openAddMember,
              child: Container(
                height: 30.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEF0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Add members to the group'
                        : 'Edit members',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 10.3.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            if (_selectedUsers.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _selectedUsers.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final user = _selectedUsers[index];
                    final id = user['id'] as int;
                    final avatarUrl = _userAvatar(user);

                    return CustomCard(
                      widget: Row(
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
                          Expanded(
                            child: Text(
                              _userName(user),
                              style: CustomTextStyles.lblSecondryText(context),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeMember(id),
                            child: Icon(
                              Icons.close,
                              size: 18.spMax,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 50.h,
        child: PrimaryButton(
          title: 'Create Group',
          onPressed: _createGroup,
          isLoading: _isCreating,
        ),
      ),
    );
  }
}
