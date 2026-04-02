// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/image/image_picker_service.dart';
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
  bool _isUploadingImage = false;

  bool _isCreating = false;
  File? _selectedImage;
  String? _base64ProfileImage;
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

  Future<void> _pickGroupImage() async {
    final file = await ImagePickerService.pickImage(context: context);
    if (file == null) return;

    final cropped = await ImagePickerService.cropImage(file);
    final finalFile = cropped ?? file;

    final bytes = await finalFile.readAsBytes();
    final base64Str = base64Encode(bytes);

    setState(() {
      _selectedImage = finalFile;
      _base64ProfileImage = base64Str;
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      showToast(message: 'Please enter a group name');
      return;
    }
    if (_selectedIds.isEmpty) {
      showToast(message: 'Please select at least one member');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final result = await _apiServices.createGroup(
        title: groupName,
        profileImage: _base64ProfileImage ?? '',
        members: _selectedIds.toList(),
      );

     

      if (result['success'] == true) {
        if (mounted) Navigator.pop(context, result['chat_id']);
      } else {
        showToast(message: 'Failed to create group');
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
          AppLocalizations.of(context)!.creategroup,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 90.h,
                      width: 90.w,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.14),
                            width: 1.5.w,
                          ),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Center(
                                child: Icon(
                                  Icons.group_rounded, 
                                  size: 36.sp,
                                  color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.14),
                                ),
                              )
                            : null,
                      ),
                    ),

                    Positioned(
                      bottom: 12.h,
                      right: 10,
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickGroupImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.background,
                              width: 1.5.w,
                            ),
                          ),
                          child: _isUploadingImage
                              ? SizedBox(
                                  width: 12.sp,
                                  height: 12.sp,
                                  child: Loader(color: AppColors.primaryColor),
                                )
                              : Icon(
                                  FeatherIcons.camera,
                                  size: 10.sp,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              AppLocalizations.of(context)!.namegroup,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 5.h),
            SecondryTextfield(
              controller: _groupNameController,
              hintText: AppLocalizations.of(context)!.entergroupame,
            ),
            SizedBox(height: 15.h),
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.members,
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
                        ? AppLocalizations.of(context)!.addmemberstogroup
                        : AppLocalizations.of(context)!.editmembers,
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
          title: AppLocalizations.of(context)!.creategroup,
          onPressed: _createGroup,
          isLoading: _isCreating,
        ),
      ),
    );
  }
}
