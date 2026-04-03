// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../api/services/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../provider/group_chat_provider.dart';
import '../../../../provider/private_chat_provider.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/show_toast.dart';
import '../media/media_screen.dart';
import '../message_list.dart';
import 'group/group_members.dart';

class ChatDetails extends StatefulWidget {
  final String? chatName;
  final String? profileUrl;
  final bool isGroupChat;
  final bool isUserBlock;
  final int? userId;
  final int? chatId;
  final Map<String, dynamic>? chat;

  const ChatDetails({
    super.key,
    required this.chatName,
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
    final currentUserId = context.read<UserProvider>().userId;
    for (final m in members) {
      final user = Map<String, dynamic>.from(m['user'] as Map? ?? {});
      if (user['id'] == currentUserId) return m['is_admin'] == true;
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
      );
      if (pickedFile == null) return;

      final File? croppedFile = await ImagePickerService.cropImage(pickedFile);
      final File imageFile = croppedFile ?? pickedFile;

      setState(() => _isUploadingImage = true);

      final result = await apiService.uploadGroupProfile(
        chatId: provider.chatId!,
        imageFile: imageFile,
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
    final result = await provider.deleteGroup();
    if (mounted) {
      Navigator.pop(context);
      if (result['message'] == 'Group deleted successfully') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MessageList()),
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
    final result = await provider.leaveGroup();
    if (mounted) {
      Navigator.pop(context);
      if (result['message'] == 'You have left the group.') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MessageList()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to leave group')),
        );
      }
    }
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
                  final imgBytes = profileImg != null && profileImg.isNotEmpty
                      ? getProfileImage(profileImg)
                      : null;
                  final username = user['username']?.toString() ?? '?';
                  return Positioned(
                    top: 4.h,
                    left: (i * 13.2).w,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.whiteColor,
                          width: 1.w,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 14.r,
                        backgroundColor: const Color.fromARGB(
                          255,
                          252,
                          195,
                          195,
                        ).withOpacity(0.3),
                        backgroundImage: imgBytes != null
                            ? MemoryImage(imgBytes)
                            : null,
                        child: imgBytes == null
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
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

    final profileUrl = widget.isGroupChat
        ? (groupProvider!.chat?['profile_url']?.toString() ?? widget.profileUrl)
        : widget.profileUrl;

    final imageBytes = profileUrl != null ? getProfileImage(profileUrl) : null;
    final initial = (chatName?.trim().isNotEmpty ?? false)
        ? chatName![0].toUpperCase()
        : '?';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, _isUserBlock),
          child: const Icon(Icons.arrow_back_ios),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        actions: [
          Icon(FeatherIcons.video, size: 20.sp),
          SizedBox(width: 15.w),
          Icon(FeatherIcons.phone, size: 18.sp),
          SizedBox(width: 15.w),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            /*───── Avatar with optional camera button ─────*/
            Stack(
              children: [
                SizedBox(
                  height: 90.h,
                  width: 90.w,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: imageBytes == null
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15)
                          : null,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.1),
                        width: 1.w,
                      ),
                      image: imageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(imageBytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageBytes == null
                        ? Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : null,
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
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _renameGroup(groupProvider!),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  groupProvider!.isRenaming
                      ? SizedBox(
                          height: 16.sp,
                          width: 16.sp,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : GestureDetector(
                          onTap: () => _renameGroup(groupProvider),
                          child: Icon(
                            Icons.check,
                            size: 18.sp,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isEditingName = false;
                      _nameController.text = chatName ?? '';
                    }),
                    child: Icon(Icons.close, size: 18.sp, color: Colors.red),
                  ),
                ] else ...[
                  Text(
                    chatName ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 11.5.sp,
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.5),
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
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
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
                    Icon(FeatherIcons.image, size: 18.spMax),
                    SizedBox(width: 8.w),
                    Text(
                      AppLocalizations.of(context)!.medialinksdocs,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '0',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
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
                        color: const Color(0XFFF44336),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isAdmin
                            ? AppLocalizations.of(context)!.deletegroup
                            : AppLocalizations.of(context)!.leavegroup,
                        style: TextStyle(
                          color: const Color(0XFFF44336),
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
                        color: const Color(0XFFF44336),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        AppLocalizations.of(context)!.report,
                        style: TextStyle(
                          color: const Color(0XFFF44336),
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
                        color: const Color(0XFFF44336),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _isUserBlock
                            ? AppLocalizations.of(context)!.unblock
                            : AppLocalizations.of(context)!.block,
                        style: TextStyle(
                          color: const Color(0XFFF44336),
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
    );
  }

  Widget _switchRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: Row(
        children: [
          Icon(icon, size: 18.spMax),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
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
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: Row(
        children: [
          Icon(icon, size: 18.spMax),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
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
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: Row(
        children: [
          Icon(icon, size: 18.spMax),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
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
