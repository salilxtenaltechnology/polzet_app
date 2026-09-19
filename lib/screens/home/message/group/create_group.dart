// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/widgets/loader.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import 'create_group_add_member.dart';

class CreateGroup extends StatefulWidget {
  const CreateGroup({super.key});

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> with UtilityMixin {
  final _groupNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isUploadingImage = false;
  File? _selectedImage;
  String? _groupNameError;

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
      'image': Assets.images.icPublic.path,
      'subtitle': AppLocalizations.of(
        context,
      )!.anyonecanfindjoinandviewmessages,
    },
    {
      'value': 'Private',
      'title': AppLocalizations.of(context)!.private,
      'image': Assets.images.icSecurity.path,
      'subtitle': AppLocalizations.of(
        context,
      )!.onlyapprovedmemberscanjoinandview,
    },
    {
      'value': 'Invite Only',
      'title': AppLocalizations.of(context)!.inviteonly,
      'image': Assets.images.icEmail.path,
      'subtitle': AppLocalizations.of(
        context,
      )!.hiddenfromsearchjoinbyinvitelink,
    },
  ];

  @override
  void initState() {
    super.initState();
    _groupNameController.addListener(_onGroupNameChanged);
  }

  void _onGroupNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _groupNameController.removeListener(_onGroupNameChanged);
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _onContinue() async {
    final groupName = _groupNameController.text.trim();
    final groupDescription = _descriptionController.text.trim();

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

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupAddMember(
          groupTitle: groupName,
          groupDescription: groupDescription.isNotEmpty
              ? groupDescription
              : null,
          groupImage: _selectedImage,
          groupCategory: _selectedCategory.toLowerCase(),
          groupPrivacy: _privacyValue,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

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
            Center(
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _pickGroupImage,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 95.w,
                          height: 95.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFF5F5F7),
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _isUploadingImage
                              ? Center(
                                  child: Loader(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : (_selectedImage == null
                                    ? Center(
                                        child: Image.asset(
                                          Assets.images.icAvatar.path,
                                         
                                          
                                        ),
                                      )
                                    : null),
                        ),
                          Positioned(
                            bottom: 8,
                            right: 0,
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
                              child: Center(
                                child: Image.asset(
                                  Assets.images.icCamera.path,
                                  width: 13.w,
                                  height: 13.w,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      _selectedImage == null
                          ? 'Add group photo'
                          : 'Change group photo',
                      style: TextStyle(
                        color: txt.muted,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 15.h),
            Text(
              AppLocalizations.of(context)!.namegroup,
              style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
               fontSize: 14.5,
                fontWeight: FontWeight.w500,
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
            SizedBox(height: 15.h),
            Text(
              AppLocalizations.of(context)!.description,
               style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
               fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 5.h),
            SecondryTextfield(
              controller: _descriptionController,
              hintText: 'Enter group description',
              minLines: 3,
              maxLines: 5,
            ),
            SizedBox(height: 15.h),
            Text(
              AppLocalizations.of(context)!.category,
               style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
               fontSize: 14.5,
                fontWeight: FontWeight.w500,
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
                        horizontal: 11.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : (isDarkMode
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.08)),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 15.sp,
                            color: isSelected
                                ? AppColors.primaryColor
                                : Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.8),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            cat['name'] as String,
                           style: AppTextStyles.bodyText.copyWith(
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : txt.title,
                              fontSize: 12.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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
               style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
               fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10.h),
            Column(
              children: List.generate(_privacyOptions.length, (index) {
                final opt = _privacyOptions[index];
                final isSelected = _selectedPrivacy == opt['value'];
                final isLast = index == _privacyOptions.length - 1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPrivacy = opt['value'] as String;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
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
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Image.asset(
                              opt['image'] as String,
                              width: 18.w,
                              height: 18.w,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: txt.title,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                opt['subtitle'] as String,
                                style:  AppTextStyles.bodyText.copyWith(
                                  color: txt.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
       padding: const EdgeInsets.only(bottom: 25),
        height: 90,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.continueButton,
          onPressed: _groupNameController.text.trim().isNotEmpty
              ? _onContinue
              : null,
          isLoading: false,
        ),
      ),
    );
  }
}
