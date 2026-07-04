// ignore_for_file: deprecated_member_use
import 'dart:io';

import '../../../../../api/api_config.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../api/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/app_themes.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../provider/group_chat_provider.dart';
import '../../../../provider/private_chat_provider.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/show_toast.dart';
import '../../home_imports.dart';
import '../media/media_screen.dart';
import 'group/group_members.dart';
import '../../profile/widgets/profile_image_preview.dart';
import '../../profile/public/public_profile_screen.dart';
import '../message_list.dart';

class ChatDetails extends StatefulWidget {
  final String? chatName;
  final String? username;
  final String? profileUrl;
  final bool isGroupChat;
  final bool isUserBlock;
  final dynamic userId;
  final int? chatId;
  final Map<String, dynamic>? chat;

  const ChatDetails({
    super.key,
    required this.chatName,
    this.username,
    required this.profileUrl,
    this.chat,
    required this.isGroupChat,
    this.isUserBlock = false,
    this.userId,
    this.chatId,
  });

  @override
  State<ChatDetails> createState() => _ChatDetailsState();
}

class _ChatDetailsState extends State<ChatDetails> with UtilityMixin {
  ApiService apiService = ApiService();
  bool _isEditingName = false;
  bool _isUploadingImage = false;
  late TextEditingController _nameController;
  late bool _isUserBlock;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.isGroupChat
          ? context.read<GroupChatProvider>().chatName ?? ''
          : widget.chatName ?? '',
    );
    _isUserBlock = widget.isUserBlock;
    _nameController = TextEditingController(
      text: widget.isGroupChat
          ? context.read<GroupChatProvider>().chatName ?? ''
          : widget.chatName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isCurrentUserAdmin(List<Map<String, dynamic>> members) {
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    for (final m in members) {
      final user = Map<String, dynamic>.from(m['user'] as Map? ?? {});
      final username = user['username']?.toString();
      if (user['id']?.toString() == currentUserId ||
          (currentUsername != null && username == currentUsername)) {
        return m['is_admin'] == true;
      }
    }
    return false;
  }

  Future<void> _renameGroup(GroupChatProvider provider) async {
    final newTitle = _nameController.text.trim();
    if (newTitle.isEmpty || newTitle == provider.chatName) {
      setState(() => _isEditingName = false);
      return;
    }
    final success = await provider.renameGroup(newTitle);
    if (mounted) {
      setState(() => _isEditingName = false);
      if (!success) {
        _nameController.text = provider.chatName ?? '';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to rename group')));
      }
    }
  }

  Future<void> _pickAndUploadGroupImage(GroupChatProvider provider) async {
    try {
      final File? pickedFile = await ImagePickerService.pickImage(
        context: context,
        allowCamera: true,
        pickOriginal: true,
      );
      if (pickedFile == null || !mounted) return;

      final shouldCrop = await cropImageDiolog(context);
      if (!mounted) return;

      File finalFile = pickedFile;
      if (shouldCrop == true) {
        final croppedFile = await ImagePickerService.cropImage(pickedFile);
        if (croppedFile != null) finalFile = croppedFile;
      }

      setState(() => _isUploadingImage = true);

      final result = await apiService.uploadGroupProfile(
        chatId: provider.chatId!,
        imageFile: finalFile,
      );

      if (mounted) {
        if (result['picture_url'] != null) {
          provider.updateGroupPicture(result['picture_url'] as String);
        } else {
          showToast(message: result['error'] ?? 'Failed to upload image');
        }
      }
    } catch (e) {
      showToast(message: 'Error uploading image: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _deleteGroup(GroupChatProvider provider) async {
    final chatId = widget.chatId;
    final result = await provider.deleteGroup();
    if (mounted) {
      Navigator.pop(context);
      if (result['message'] == 'Group deleted successfully') {
        MessageListState.removeChatLocally(chatId);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(initialIndex: 1), // ← Messages tab
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete group'),
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup(GroupChatProvider provider) async {
    final chatId = widget.chatId;
    final result = await provider.leaveGroup();
    if (mounted) {
      Navigator.pop(context);
      if (result['message'] == 'You have left the group.') {
        MessageListState.removeChatLocally(chatId);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(initialIndex: 1), // ← Messages tab
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to leave group')),
        );
      }
    }
  }

  ImageProvider? _avatarProvider(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == 'null') return null;
    String resolved = raw;
    if (!resolved.startsWith('http')) {
      final separator = resolved.startsWith('/') ? '' : '/';
      resolved = '${ApiConfig.baseUrlImage}$separator$resolved';
    }
    return NetworkImage(resolved);
  }

  Widget _buildGroupAvatarStack({
    required List<dynamic>? members,
    required double size,
    required bool isDarkMode,
    required BuildContext context,
  }) {
    final List<String?> profileUrls = [];
    final List<String> initials = [];

    if (members != null) {
      for (final member in members) {
        if (profileUrls.length >= 2) break;
        final user = member is Map ? member['user'] as Map? : null;
        if (user != null) {
          String? profileUrl =
              (user['avatar_url'] ??
                      user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['avatar'])
                  ?.toString();
          if (profileUrl != null && profileUrl.trim().isNotEmpty && profileUrl != 'null') {
            if (!profileUrl.startsWith('http') && !profileUrl.startsWith('data:image')) {
              final separator = profileUrl.startsWith('/') ? '' : '/';
              profileUrl = '${ApiConfig.baseUrlImage}$separator$profileUrl';
            }
          } else {
            profileUrl = Assets.images.icAvatar.path;
          }
          final name = (user['name'] ?? user['username'] ?? 'Unknown')
              .toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
        }
      }
    }

    // Ensure we always have at least 2 items to show the stacked preview (overlapping circles)
    while (profileUrls.length < 2) {
      profileUrls.add(Assets.images.icAvatar.path);
      initials.add('?');
    }

    final double circleSize = size * 0.75;

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
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildSingleAvatarCircle(
              profileUrl: profileUrls[1],
              initial: initials[1],
              size: circleSize,
              isDarkMode: isDarkMode,
              context: context,
              hasBorder: true,
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
  }) {
    final ImageProvider? avatarProvider =
        (profileUrl == null || profileUrl.trim().isEmpty || profileUrl == 'null' || profileUrl == Assets.images.icAvatar.path)
        ? AssetImage(Assets.images.icAvatar.path)
        : _avatarProvider(profileUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarProvider == null
            ? (isDarkMode
                ? const Color(0xFF252525)
                : Theme.of(context).primaryColor.withOpacity(0.08))
            : null,
        border: hasBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.background,
                width: 1.5,
              )
            : Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                width: 1,
              ),
        image: avatarProvider != null
            ? DecorationImage(
                image: avatarProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }

  Widget _buildSeeAllMembers(
    List<Map<String, dynamic>> members,
    int? chatId,
    GroupChatProvider provider,
  ) {
    final preview = members.take(3).toList();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: GroupMembers(members: members, chatId: chatId!),
          ),
        ),
      ),
      child: Container(
        height: 38.h,
        width: double.infinity,
        margin: EdgeInsets.only(top: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.primaryColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            SizedBox(
              width: (preview.length * 20 + 8).w,
              height: 32.h,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(preview.length, (i) {
                  final user = Map<String, dynamic>.from(
                    preview[i]['user'] as Map? ?? {},
                  );
                  final profileImg = user['profile_image']?.toString();
                  final avatarProvider =
                      (profileImg == null || profileImg.trim().isEmpty)
                      ? AssetImage(Assets.images.icAvatar.path)
                      : _avatarProvider(profileImg) as ImageProvider;
                  return Positioned(
                    top: 4.h,
                    left: (i * 13.2).w,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemes.lightMode.colorScheme.outlineVariant,
                          width: 1.w,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color.fromARGB(
                          255,
                          252,
                          195,
                          195,
                        ).withOpacity(0.3),
                        backgroundImage: avatarProvider,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Spacer(),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.seeallmembers,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              FeatherIcons.chevronRight,
              color: Colors.white,
              size: 18.spMax,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final groupProvider = widget.isGroupChat
        ? context.watch<GroupChatProvider>()
        : null;
    final privateProvider = widget.isGroupChat
        ? null
        : context.watch<PrivateChatProvider>();

    final chatName = widget.isGroupChat
        ? groupProvider!.chatName
        : privateProvider!.memberName;
    final members = groupProvider?.members ?? [];
    final isAdmin = widget.isGroupChat ? _isCurrentUserAdmin(members) : false;

    final isMuteNotification = widget.isGroupChat
        ? false
        : privateProvider!.isMuteNotification;
    final isProtectedChat = widget.isGroupChat
        ? false
        : privateProvider!.isProtectedChat;
    final isHideChat = widget.isGroupChat ? false : privateProvider!.isHideChat;
    final isHideChatHistory = widget.isGroupChat
        ? false
        : privateProvider!.isHideChatHistory;

    final profileUrlRaw = widget.isGroupChat
        ? (groupProvider?.chat?['profile_url']?.toString() ?? widget.profileUrl)
        : widget.profileUrl;
    final profileUrl = profileUrlRaw;

    final provider = _avatarProvider(profileUrl);
    final initial = (chatName?.trim().isNotEmpty ?? false)
        ? chatName![0].toUpperCase()
        : '?';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _isUserBlock);
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).colorScheme.background,

        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context, _isUserBlock),
            child: Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.onBackground,
                size: 24,
              ),
            ),
          ),
          leadingWidth: 48.w,
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.background,
          toolbarHeight: AppConstants.toolbarHeight.h,
          actions: [
            if (!widget.isGroupChat)
              GestureDetector(
                onTap: () {
                  if (widget.userId != null) {
                    navigationPush(
                      context,
                      PublicProfileScreen(
                        userId: widget.userId.toString(),
                        username: widget.username ?? widget.chatName,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Image.asset(
                    Assets.images.inactiveUser.path,
                    color: Theme.of(context).colorScheme.onBackground,
                    height: 22.h,
                    width: 22.w,
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            children: [
              /*───── Avatar with optional camera button ─────*/
              Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (profileUrl == null || profileUrl.isEmpty) return;
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierColor: Colors.transparent,
                          transitionDuration: const Duration(milliseconds: 150),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 150,
                          ),
                          pageBuilder:
                              (context, animation, secondaryAnimation) {
                                return ProfileImagePreview(
                                  imageSource: profileUrl,
                                  username: chatName,
                                );
                              },
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                        ),
                      );
                    },
                    child: SizedBox(
                      height: 90.h,
                      width: 90.w,
                      child: widget.isGroupChat && (profileUrl == null || profileUrl.trim().isEmpty || profileUrl == 'null')
                          ? _buildGroupAvatarStack(
                              members: members,
                              size: 90.w,
                              isDarkMode: Theme.of(context).brightness == Brightness.dark,
                              context: context,
                            )
                          : Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider == null
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimary.withOpacity(0.1)
                                    : null,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.1),
                                  width: 1.w,
                                ),
                                image: provider != null
                                    ? DecorationImage(
                                        image: provider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: provider == null
                                  ? Center(
                                      child: Text(
                                        initial,
                                        style: AppTextStyles.cardTitle.copyWith(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                    ),
                  ),

                  // Camera icon — only for group chat + admin
                  if (widget.isGroupChat && isAdmin)
                    Positioned(
                      bottom: 12.h,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingImage
                            ? null
                            : () => _pickAndUploadGroupImage(groupProvider!),
                        child: Container(
                          padding: const EdgeInsets.all(5),
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
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  FeatherIcons.camera,
                                  size: 11.sp,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                ],
              ),

              // ── Group name / edit row ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isEditingName && widget.isGroupChat) ...[
                    SizedBox(
                      width: 180.w,
                      height: 32.h,
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.2.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                              width: 1,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _renameGroup(groupProvider!),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    groupProvider!.isRenaming
                        ? SizedBox(
                            height: 14.sp,
                            width: 14.sp,
                            child: Loader(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _renameGroup(groupProvider),
                            child: Icon(
                              Icons.check,
                              size: 18.sp,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isEditingName = false;
                        _nameController.text = chatName ?? '';
                      }),
                      child: Icon(
                        Icons.close,
                        size: 18.sp,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ] else ...[
                    Text(
                      chatName ?? '',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.isGroupChat && isAdmin) ...[
                      SizedBox(width: 6.w),
                      GestureDetector(
                        onTap: () => setState(() => _isEditingName = true),
                        child: Icon(
                          FeatherIcons.edit2,
                          size: 13.sp,
                          color: txt.muted,
                        ),
                      ),
                    ],
                  ],
                ],
              ),

              if (widget.isGroupChat)
                _buildSeeAllMembers(
                  members,
                  groupProvider!.chatId,
                  groupProvider,
                ),

              SizedBox(height: 8.h),
              Divider(
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),

              Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: GestureDetector(
                  onTap: () => navigationPush(
                    context,
                    MediaScreen(memberName: chatName ?? ''),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FeatherIcons.image,
                        size: 18.spMax,
                        color: txt.title,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        AppLocalizations.of(context)!.medialinksdocs,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: txt.title,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '10',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Icon(
                        FeatherIcons.chevronRight,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.5),
                        size: 20.spMax,
                      ),
                    ],
                  ),
                ),
              ),
              _switchRow(
                AppLocalizations.of(context)!.mutenotification,
                FeatherIcons.volume2,
                isMuteNotification,
                (v) => widget.isGroupChat
                    ? null
                    : privateProvider!.toggleMuteNotification(v),
              ),
              _arrowRow(
                AppLocalizations.of(context)!.customnotification,
                FeatherIcons.bell,
              ),
              _switchRow(
                AppLocalizations.of(context)!.protectedchat,
                FeatherIcons.shield,
                isProtectedChat,
                (v) => widget.isGroupChat
                    ? null
                    : privateProvider!.toggleProtectedChat(v),
              ),
              _switchRow(
                AppLocalizations.of(context)!.hidechat,
                FeatherIcons.eye,
                isHideChat,
                (v) => widget.isGroupChat
                    ? null
                    : privateProvider!.toggleHideChat(v),
              ),
              _switchRow(
                AppLocalizations.of(context)!.hidechathistory,
                FeatherIcons.eye,
                isHideChatHistory,
                (v) => widget.isGroupChat
                    ? null
                    : privateProvider!.toggleHideChatHistory(v),
              ),
              _colorRow(
                AppLocalizations.of(context)!.customcolorchat,
                Icons.color_lens_outlined,
                Theme.of(context).colorScheme.primary,
              ),
              _colorRow(
                AppLocalizations.of(context)!.custombackgroundchat,
                FeatherIcons.image,
                const Color(0XFFF0F0F3),
              ),

              if (widget.isGroupChat)
                Padding(
                  padding: EdgeInsets.only(top: 15.h),
                  child: GestureDetector(
                    onTap: () {
                      if (isAdmin) {
                        showDeleteGroupDiolog(
                          context,
                          () => _deleteGroup(groupProvider!),
                        );
                      } else {
                        showLeaveGroupDiolog(
                          context,
                          () => _leaveGroup(groupProvider!),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          isAdmin
                              ? Icons.delete_forever_rounded
                              : Icons.exit_to_app_rounded,
                          size: 20.spMax,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isAdmin
                              ? AppLocalizations.of(context)!.deletegroup
                              : AppLocalizations.of(context)!.leavegroup,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!widget.isGroupChat) ...[
                GestureDetector(
                  onTap: () {
                    showReportChatDiolog(context, () {
                      Navigator.pop(context);
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.only(top: 15.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 18.spMax,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          AppLocalizations.of(context)!.report,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 15.h),
                  child: GestureDetector(
                    onTap: () {
                      showBlockUserDiolog(context, () async {
                        final wasBlocked = _isUserBlock;
                        Navigator.pop(context);
                        if (mounted) setState(() => _isUserBlock = !wasBlocked);
                        final result = wasBlocked
                            ? await privateProvider!.unblockUser(widget.userId!)
                            : await privateProvider!.blockUser(widget.userId!);
                        if (mounted && result['success'] != true) {
                          setState(() => _isUserBlock = wasBlocked);
                          // showToast(message: result['error'] ?? 'Action failed');
                        }
                      }, _isUserBlock);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block,
                          size: 18.spMax,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          _isUserBlock
                              ? AppLocalizations.of(context)!.unblock
                              : AppLocalizations.of(context)!.block,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final txt = AppTextColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: Row(
        children: [
          Icon(icon, size: 18.spMax, color: txt.title),
          SizedBox(width: 8.w),
          Text(
            label,
            style: AppTextStyles.cardTitle.copyWith(
              color: txt.title,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 35.w,
            height: 20.h,
            child: Transform.scale(
              scale: 0.75,
              child: CupertinoSwitch(
                activeTrackColor: AppColors.primaryColor,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowRow(String label, IconData icon) {
    final txt = AppTextColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: Row(
        children: [
          Icon(icon, size: 18.spMax, color: txt.title),
          SizedBox(width: 8.w),
          Text(
            label,
            style: AppTextStyles.cardTitle.copyWith(
              color: txt.title,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(
            FeatherIcons.chevronRight,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
            size: 20.spMax,
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, IconData icon, Color color) {
    final txt = AppTextColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: Row(
        children: [
          Icon(icon, size: 18.spMax, color: txt.title),
          SizedBox(width: 8.w),
          Text(
            label,
            style: AppTextStyles.cardTitle.copyWith(
              color: txt.title,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            height: 18.h,
            width: 20.w,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5.r),
            ),
          ),
        ],
      ),
    );
  }
}
