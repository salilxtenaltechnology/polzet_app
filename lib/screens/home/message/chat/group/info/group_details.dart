// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../../../api/api_config.dart';
import '../../../../../../api/api_service.dart';
import '../../../../../../api/services/image/image_picker_service.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../provider/group_chat_provider.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/base64/image_convert.dart';
import '../../../../../../widgets/button/primary_button.dart';
import '../../../../../../widgets/dialog/custom_diolog.dart';
import '../../../../../../widgets/loader.dart';
import '../../../../../../widgets/show_toast.dart';
import '../../../../../../widgets/text_field/secondry_textfield.dart';
import '../../../message_list.dart';

class GroupDetails extends StatefulWidget {
  final dynamic chatId;
  final String? groupName;
  final String? groupDescription;
  final String? groupCategory;
  final String? groupPrivacy;
  final File? groupImage;
  final String? groupImageUrl;
  final List<dynamic>? members;
  final ValueChanged<String>? onGroupImageUpdated;
  final ValueChanged<Map<String, dynamic>>? onGroupDetailsUpdated;
  final GroupChatProvider? groupChatProvider;

  const GroupDetails({
    super.key,
    this.chatId,
    this.groupName,
    this.groupDescription,
    this.groupCategory,
    this.groupPrivacy,
    this.groupImage,
    this.groupImageUrl,
    this.members,
    this.onGroupImageUpdated,
    this.onGroupDetailsUpdated,
    this.groupChatProvider,
  });

  @override
  State<GroupDetails> createState() => _GroupDetailsState();
}

class _GroupDetailsState extends State<GroupDetails> with UtilityMixin {
  final _apiService = ApiService();
  late final TextEditingController _groupNameController;
  late final TextEditingController _descriptionController;

  bool _isUploadingImage = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _groupNameError;
  late String _selectedCategory;
  late String _selectedPrivacy;
  late final String _initialCategory;
  late final String _initialPrivacy;
  bool _isSaving = false;

  bool get _hasChanges {
    final currentName = _groupNameController.text.trim();
    final initialName = (widget.groupName ?? '').trim();
    final nameChanged = currentName != initialName;

    final currentDesc = _descriptionController.text.trim();
    final initialDesc = (widget.groupDescription ?? '').trim();
    final descChanged = currentDesc != initialDesc;

    final catChanged =
        _selectedCategory.toLowerCase() != _initialCategory.toLowerCase();
    final privacyChanged = _selectedPrivacy != _initialPrivacy;
    final imageChanged =
        _selectedImage != widget.groupImage ||
        (_uploadedImageUrl != null &&
            _uploadedImageUrl != widget.groupImageUrl);

    return (nameChanged ||
            descChanged ||
            catChanged ||
            privacyChanged ||
            imageChanged) &&
        currentName.isNotEmpty;
  }

  final List<Map<String, dynamic>> _categories = [
    {'name': 'General', 'icon': Icons.people_outline},
    {'name': 'Gaming', 'icon': Icons.sports_esports_outlined},
    {'name': 'Education', 'icon': Icons.menu_book_outlined},
    {'name': 'Explore', 'icon': Icons.explore_outlined},
  ];


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
    _groupNameController = TextEditingController(text: widget.groupName ?? '');
    _descriptionController = TextEditingController(
      text: widget.groupDescription ?? '',
    );
    final initialCat = widget.groupCategory?.trim() ?? '';
    final matchedCat = _categories.firstWhere(
      (c) => (c['name'] as String).toLowerCase() == initialCat.toLowerCase(),
      orElse: () => _categories.first,
    );
    _selectedCategory = matchedCat['name'] as String;
    _initialCategory = _selectedCategory;

    final initialPrivacy = widget.groupPrivacy?.trim().toLowerCase() ?? '';
    if (initialPrivacy == 'private') {
      _selectedPrivacy = 'Private';
    } else if (initialPrivacy == 'invite_only' ||
        initialPrivacy == 'invite only' ||
        initialPrivacy == 'inviteonly') {
      _selectedPrivacy = 'Invite Only';
    } else {
      _selectedPrivacy = 'Public';
    }
    _initialPrivacy = _selectedPrivacy;

    _selectedImage = widget.groupImage;
    _uploadedImageUrl = widget.groupImageUrl;
    _groupNameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _groupNameController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
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

    if (widget.chatId != null) {
      setState(() => _isUploadingImage = true);
      try {
        final result = await _apiService.uploadGroupProfile(
          chatId: widget.chatId,
          imageFile: finalFile,
        );
        if (mounted) {
          final picUrl = (result['picture_url'] ??
                  result['group_picture_url'] ??
                  result['data']?['picture_url'] ??
                  result['data']?['group_picture_url'] ??
                  result['data']?['profile_url'] ??
                  result['profile_url'])
              ?.toString();

          if ((picUrl != null && picUrl.isNotEmpty) ||
              result['success'] == true ||
              result['status'] == 'success') {
            if (picUrl != null && picUrl.isNotEmpty) {
              _uploadedImageUrl = picUrl;
              widget.onGroupImageUpdated?.call(picUrl);
              widget.groupChatProvider?.updateGroupPicture(picUrl);
              try {
                Provider.of<GroupChatProvider>(context, listen: false)
                    .updateGroupPicture(picUrl);
              } catch (_) {}
              if (widget.chatId != null) {
                MessageListState.updateGroupChatAvatarLocally(
                  widget.chatId.toString(),
                  picUrl,
                );
              }
            }
            showToast(message: 'Group image updated successfully');
          } else {
            showToast(
              message: result['error'] ??
                  result['message'] ??
                  'Failed to upload image',
            );
          }
        }
      } catch (e) {
        debugPrint('Error uploading group image: $e');
        if (mounted) {
          showToast(message: 'Failed to upload image');
        }
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }
  }

  bool _isPolzetAiUsername(String? username) {
    if (username == null) return false;
    final lower = username.toLowerCase();
    return lower == 'polzet ai' ||
        lower == 'polzetai' ||
        lower == 'polzet_ai' ||
        lower == 'polzet-ai' ||
        lower.contains('polzet ai') ||
        lower.contains('polzetai');
  }

  Widget _buildGroupAvatarStack({
    required List<dynamic>? members,
    required double size,
    required bool isDarkMode,
    required BuildContext context,
  }) {
    final List<String?> profileUrls = [];
    final List<String> initials = [];
    final List<String?> usernames = [];

    if (members != null) {
      for (final member in members) {
        if (profileUrls.length >= 2) break;
        final user = member is Map
            ? (member['user'] is Map ? member['user'] as Map : member)
            : null;
        if (user != null) {
          String? profileUrl =
              (user['avatar_url'] ??
                      user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['avatar'])
                  ?.toString();
          final username = user['username']?.toString();
          if (profileUrl != null &&
              profileUrl.trim().isNotEmpty &&
              profileUrl != 'null') {
            if (!profileUrl.startsWith('http') &&
                !profileUrl.startsWith('data:image')) {
              final separator = profileUrl.startsWith('/') ? '' : '/';
              profileUrl = '${ApiConfig.baseUrlImage}$separator$profileUrl';
            }
          } else {
            profileUrl = Assets.images.icAvatar.path;
          }
          final name = (user['name'] ?? username ?? 'Unknown').toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
          usernames.add(username);
        }
      }
    }

    while (profileUrls.length < 2) {
      profileUrls.add(Assets.images.icAvatar.path);
      initials.add('?');
      usernames.add(null);
    }

    final double circleSize = size * 0.70;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _buildSingleAvatarCircle(
              profileUrl: profileUrls[0],
              initial: initials[0],
              size: circleSize,
              isDarkMode: isDarkMode,
              context: context,
              username: usernames.isNotEmpty ? usernames[0] : null,
            ),
          ),
          if (profileUrls.length > 1)
            Positioned(
              bottom: 2,
              right: 3,
              child: _buildSingleAvatarCircle(
                profileUrl: profileUrls[1],
                initial: initials[1],
                size: circleSize,
                isDarkMode: isDarkMode,
                context: context,
                hasBorder: true,
                username: usernames.length > 1 ? usernames[1] : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleAvatarCircle({
    required String? profileUrl,
    required String initial,
    required double size,
    required bool isDarkMode,
    required BuildContext context,
    bool hasBorder = false,
    String? username,
  }) {
    if (_isPolzetAiUsername(username) || _isPolzetAiUsername(profileUrl)) {
      return Container(
        width: size,
        height: size,
        decoration: hasBorder
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.background,
                  width: 2,
                ),
              )
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 6,
                    bottom: 0,
                    left: 8,
                    right: 7,
                  ),
                  child: Image.asset(
                    Assets.images.icSplash.path,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                Assets.images.aiFrame.path,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    }

    final ImageProvider? avatarProvider = (profileUrl == null ||
            profileUrl.trim().isEmpty ||
            profileUrl == 'null' ||
            profileUrl == Assets.images.icAvatar.path)
        ? AssetImage(Assets.images.icAvatar.path)
        : (getProfileImage(profileUrl) != null
            ? MemoryImage(getProfileImage(profileUrl)!)
            : (resolveProfileImageUrl(profileUrl) != null &&
                    resolveProfileImageUrl(profileUrl)!.startsWith('http')
                ? NetworkImage(resolveProfileImageUrl(profileUrl)!)
                : (resolveProfileImageUrl(profileUrl) != null &&
                        resolveProfileImageUrl(profileUrl)!.startsWith('assets/')
                    ? AssetImage(resolveProfileImageUrl(profileUrl)!)
                    : AssetImage(Assets.images.icAvatar.path))));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.background,
                width: 2,
              )
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.05),
                width: 1,
              ),
        image: avatarProvider != null
            ? DecorationImage(image: avatarProvider, fit: BoxFit.cover)
            : null,
      ),
    );
  }

  Widget _buildAvatarWidget({required bool isDarkMode}) {
    if (_isUploadingImage) {
      return Container(
        width: 90.w,
        height: 90.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode
              ? const Color(0xFF252525)
              : Theme.of(context).primaryColor.withOpacity(0.08),
        ),
        child: Center(
          child: Loader(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_selectedImage != null) {
      return Container(
        width: 90.w,
        height: 90.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: FileImage(_selectedImage!),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    }

    final avatarUrl = _uploadedImageUrl ?? widget.groupImageUrl;
    if (avatarUrl != null &&
        avatarUrl.trim().isNotEmpty &&
        avatarUrl != 'null') {
      final imageBytes = getProfileImage(avatarUrl);
      final resolvedUrl = resolveProfileImageUrl(avatarUrl);
      final ImageProvider? provider = imageBytes != null
          ? MemoryImage(imageBytes)
          : (resolvedUrl != null && resolvedUrl.startsWith('http')
                ? NetworkImage(resolvedUrl)
                : (resolvedUrl != null && resolvedUrl.startsWith('assets/')
                      ? AssetImage(resolvedUrl)
                      : null));

      if (provider != null) {
        return Container(
          width: 90.w,
          height: 90.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: provider,
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      }
    }

    return _buildGroupAvatarStack(
      members: widget.members,
      size: 90.w,
      isDarkMode: isDarkMode,
      context: context,
    );
  }

  Map<String, dynamic> _buildReturnData() {
    return {
      'groupName': _groupNameController.text.trim(),
      'groupDescription': _descriptionController.text.trim(),
      'groupCategory': _selectedCategory,
      'groupPrivacy': _privacyValue,
      'privacy': _privacyValue,
      'groupImage': _selectedImage,
      'groupImageUrl': _uploadedImageUrl,
    };
  }

  Future<void> _saveGroupDetails() async {
    final newTitle = _groupNameController.text.trim();
    if (newTitle.isEmpty) {
      setState(() {
        _groupNameError = 'Please enter a group name';
      });
      return;
    }

    final newDesc = _descriptionController.text.trim();
    final newCategory = _selectedCategory.toLowerCase();
    final newPrivacy = _privacyValue;
    final data = _buildReturnData();

    // 1. Immediately update UI locally in GroupInfoScreen
    widget.onGroupDetailsUpdated?.call(data);

    // 2. Immediately update UI locally in GroupChatScreen (provider)
    if (widget.groupChatProvider != null) {
      widget.groupChatProvider?.updateGroupNameLocally(newTitle);
    }
    try {
      Provider.of<GroupChatProvider>(context, listen: false)
          .updateGroupNameLocally(newTitle);
    } catch (_) {}

    // 3. Immediately update UI locally in Message list screen
    if (widget.chatId != null) {
      MessageListState.updateGroupChatTitleLocally(widget.chatId, newTitle);
      if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
        MessageListState.updateGroupChatAvatarLocally(
          widget.chatId,
          _uploadedImageUrl!,
        );
      }
    }

    if (widget.chatId != null) {
      setState(() => _isSaving = true);
      try {
        final response = await _apiService.updateGroupInfo(
          groupChatId: widget.chatId.toString(),
          title: newTitle,
          description: newDesc,
          category: newCategory,
          privacy: newPrivacy,
        );

        final msg = response['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          showToast(message: msg);
        }
      } catch (e) {
        debugPrint('Error updating group info: $e');
        showToast(message: 'Failed to update group info: $e');
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, data);
        }
      }
    } else {
      Navigator.pop(context, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        final data = _buildReturnData();
        widget.onGroupDetailsUpdated?.call(data);
        Navigator.pop(context, data);
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title: 'Group Details',
          showBackButton: true,
          onBack: () {
            final data = _buildReturnData();
            widget.onGroupDetailsUpdated?.call(data);
            Navigator.pop(context, data);
          },
        ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Image & Group Name ────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _pickGroupImage,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildAvatarWidget(isDarkMode: isDarkMode),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      _groupNameController.text.trim().isEmpty
                          ? (widget.groupName ?? 'Group Name')
                          : _groupNameController.text.trim(),
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 15.h),

            // ── Group Name Input ──────────────────────────────────────────────
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
              hintText: 'Enter group name',
              onChanged: (_) {
                if (_groupNameError != null) {
                  setState(() => _groupNameError = null);
                }
              },
            ),
            if (_groupNameError != null) ...[
              SizedBox(height: 4.h),
              Text(
                _groupNameError!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            SizedBox(height: 14.h),

            // ── Description Input ─────────────────────────────────────────────
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
              hintText: 'Add group description (optional)',
              maxLines: 2,
            ),
            SizedBox(height: 14.h),

            // ── Category Selector ─────────────────────────────────────────────
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
                  final name = cat['name'] as String;
                  final icon = cat['icon'] as IconData;
                  final isSelected =
                      _selectedCategory.toLowerCase() == name.toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = name;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor
                            : (isDarkMode
                                  ? const Color(0xFF161821)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : (isDarkMode
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.08)),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 13.sp,
                            color: isSelected ? Colors.white : txt.muted,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : txt.title,
                              fontSize: 11.sp,
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
          title: 'Save',
          onPressed: (_isSaving || !_hasChanges) ? null : _saveGroupDetails,
          isLoading: _isSaving,
        ),
      ),
    ),
  );
  }
}
