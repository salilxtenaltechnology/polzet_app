// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'dart:io';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import '../../../../api/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
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
  Set<String> _selectedIds = {};

  /// Full user maps for displaying the selected members list
  List<Map<String, dynamic>> _selectedUsers = [];
  bool _isUploadingImage = false;

  bool _isCreating = false;
  File? _selectedImage;
  String? _groupNameError;
  String? _groupMembersError;

  String _selectedCategory = 'General';
  String _selectedPrivacy = 'Public';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'General', 'icon': Icons.people_outline},
    {'name': 'Gaming', 'icon': Icons.sports_esports_outlined},
    {'name': 'Education', 'icon': Icons.menu_book_outlined},
    {'name': 'Explore', 'icon': Icons.explore_outlined},
  ];

  List<Map<String, dynamic>> get _privacyOptions => [
    {
      'value': 'Public',
      'title': AppLocalizations.of(context)!.public,
      'icon': Icons.language_outlined,
      'subtitle': AppLocalizations.of(
        context,
      )!.anyonecanfindjoinandviewmessages,
    },
    {
      'value': 'Private',
      'title': AppLocalizations.of(context)!.private,
      'icon': Icons.lock_outline,
      'subtitle': AppLocalizations.of(
        context,
      )!.onlyapprovedmemberscanjoinandview,
    },
    {
      'value': 'Invite Only',
      'title': AppLocalizations.of(context)!.inviteonly,
      'icon': Icons.mail_outline,
      'subtitle': AppLocalizations.of(
        context,
      )!.hiddenfromsearchjoinbyinvitelink,
    },
  ];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _openAddMember() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMember(alreadySelected: _selectedIds),
      ),
    );

    if (result == null) return;

    setState(() {
      _selectedIds = result['ids'] as Set<String>;
      _selectedUsers = List<Map<String, dynamic>>.from(result['users'] as List);
      if (_selectedIds.isNotEmpty) {
        _groupMembersError = null;
      }
    });
  }

  Future<void> _pickGroupImage() async {
    final file = await ImagePickerService.pickImage(
      context: context,
      pickOriginal: true,
    );
    if (file == null || !mounted) return;

    final shouldCrop = await cropImageDiolog(context);
    if (!mounted) return;

    File finalFile = file;
    if (shouldCrop == true) {
      final cropped = await ImagePickerService.cropImage(file);
      if (cropped != null) finalFile = cropped;
    }

    setState(() {
      _selectedImage = finalFile;
    });
  }

  String get _privacyValue {
    switch (_selectedPrivacy) {
      case 'Public':
        return 'public';
      case 'Private':
        return 'private';
      case 'Invite Only':
        return 'invite_only';
      default:
        return _selectedPrivacy.toLowerCase().replaceAll(' ', '_');
    }
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      setState(() {
        _groupNameError = 'Please enter a group name';
      });
      return;
    } else {
      setState(() {
        _groupNameError = null;
      });
    }
    if (_selectedIds.isEmpty) {
      setState(() {
        _groupMembersError = 'Please select at least one member';
      });
      return;
    } else {
      setState(() {
        _groupMembersError = null;
      });
    }

    setState(() => _isCreating = true);

    try {
      final result = await _apiServices.createGroup(
        title: groupName,
        profileImage: _selectedImage,
        members: _selectedIds.toList(),
        category: _selectedCategory.toLowerCase(),
        privacy: _privacyValue,
      );

      if (result['success'] == true) {
        if (mounted) Navigator.pop(context, result['chat_id'] ?? true);
      } else {
        showToast(message: 'Failed to create group');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _removeMember(String id) {
    setState(() {
      _selectedIds.remove(id);
      _selectedUsers.removeWhere((u) => u['id']?.toString() == id);
    });
  }

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'Unknown')
          .toString();

  String? _userAvatar(Map<String, dynamic> user) =>
      (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])
          ?.toString();

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.creategroup,
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                      width: 100,
                      height: 100,
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
                      bottom: 8,
                      right: 10,
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickGroupImage,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.background,
                              width: 1.5,
                            ),
                          ),
                          child: _isUploadingImage
                              ? SizedBox(
                                  width: 12.sp,
                                  height: 12.sp,
                                  child: Loader(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(
                                  FeatherIcons.camera,
                                  size: 14,
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
              onChanged: (val) {
                if (_groupNameError != null) {
                  setState(() {
                    _groupNameError = null;
                  });
                }
              },
            ),
            if (_groupNameError != null) ...[
              SizedBox(height: 5.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Text(
                  _groupNameError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            SizedBox(height: 18.h),
            Text(
              AppLocalizations.of(context)!.category,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat['name'] as String;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.5.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor
                            : (isDarkMode
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 15.sp,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.8),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            cat['name'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : txt.title,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              AppLocalizations.of(context)!.privacygroup,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: List.generate(_privacyOptions.length, (index) {
                final opt = _privacyOptions[index];
                final isSelected = _selectedPrivacy == opt['value'];
                final isLast = index == _privacyOptions.length - 1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPrivacy = opt['value'] as String;
                      });
                    },
                    child: AnimatedContainer(
                      height: 150.h,
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: isLast ? 0 : 8.w),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF161821)
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : (isDarkMode
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.08)),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30.w,
                            height: 30.w,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryColor.withOpacity(0.15)
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: Icon(
                                opt['icon'] as IconData,
                                size: 16.sp,
                                color: isSelected
                                    ? AppColors.primaryColor
                                    : Theme.of(context).colorScheme.onBackground
                                          .withOpacity(0.7),
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            opt['title'] as String,
                            style: TextStyle(
                              color: txt.title,
                              fontSize: 10.8.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            opt['subtitle'] as String,
                            style: TextStyle(
                              color: txt.muted,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 18.h),
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
                    '${_selectedIds.length} ${AppLocalizations.of(context)!.selected}',
                    style: AppTextStyles.subText.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
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
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFFFE8EB),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Center(
                  child: Text(
                    _selectedIds.isEmpty
                        ? AppLocalizations.of(context)!.addmemberstogroup
                        : AppLocalizations.of(context)!.editmembers,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 10.3.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            if (_groupMembersError != null) ...[
              SizedBox(height: 5.h),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  _groupMembersError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            if (_selectedUsers.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedUsers.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  final id = user['id']?.toString() ?? '';
                  final avatarUrl = _userAvatar(user);
                  final firstName = user['first_name'] as String? ?? '';
                  final lastName = user['last_name'] as String? ?? '';
                  final username =
                      user['username'] as String? ?? _userName(user);
                  final fullName = '$firstName $lastName'.trim();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                            final resolvedUrl = resolveProfileImageUrl(
                              avatarUrl,
                            );
                            final avatarProvider = resolvedUrl != null
                                ? NetworkImage(resolvedUrl)
                                : null;
                            final initial = username.trim().isNotEmpty
                                ? username.trim()[0].toUpperCase()
                                : 'P';
                            return CircleAvatar(
                              radius: 15,
                              backgroundImage: avatarProvider,
                              backgroundColor: avatarProvider == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.1)
                                  : null,
                              child: avatarProvider == null
                                  ? Text(
                                      initial,
                                      style: AppTextStyles.subText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
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
                        GestureDetector(
                          onTap: () => _removeMember(id),
                          child: Icon(
                            Icons.close,
                            size: 18.spMax,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 50.h,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.creategroup,
          onPressed: _createGroup,
          isLoading: _isCreating,
        ),
      ),
    );
  }
}
