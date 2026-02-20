// ignore_for_file: deprecated_member_use, must_be_immutable

import 'dart:typed_data';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/message/message_model.dart';
import '../../../../../provider/group_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/button/back_button.dart';
import '../chat_details.dart';

class GroupChatScreen extends StatefulWidget {
  final String? groupName;
  final int? chatId;
  final Map<String, dynamic>? chat;

  const GroupChatScreen({
    super.key,
    required this.groupName,
    this.chat,
    required this.chatId,
  });

  @override
  State<GroupChatScreen> createState() => GroupChatScreenState();
}

class GroupChatScreenState extends State<GroupChatScreen> with UtilityMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupChatProvider>();
      final userProvider = context.read<UserProvider>();

      provider.init(currentUsername: userProvider.username);

      // Pagination: load older messages when user scrolls to the very top
      _scrollController.addListener(() {
        if (_scrollController.position.pixels <= 80 &&
            provider.hasMoreHistory &&
            !provider.isLoadingHistory) {
          provider.fetchMoreHistory();
        }
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _avatarUrl {
    final members = widget.chat?['members'] as List?;
    if (members == null || members.isEmpty) return null;
    final user =
        (members.first as Map<String, dynamic>)['user']
            as Map<String, dynamic>?;
    return user?['profile_image']?.toString();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    context.read<GroupChatProvider>().sendMessage(text);
    _messageController.clear();
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    Uint8List? avatarBytes;
    if (!message.isSentByMe && message.senderProfileImage != null) {
      avatarBytes = getProfileImage(message.senderProfileImage!);
    }

    final String initial = (message.senderUsername?.isNotEmpty == true)
        ? message.senderUsername![0].toUpperCase()
        : '?';

    return Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: message.isSentByMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isSentByMe) ...[
            SizedBox(width: 6.w),
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: CircleAvatar(
                radius: 12.r,
                backgroundColor: const Color(0xFFEEEEEE),
                backgroundImage: avatarBytes != null
                    ? MemoryImage(avatarBytes)
                    : null,
                child: avatarBytes == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
              ),
            ),
            SizedBox(width: 6.w),
          ],

          // ── Bubble ────────────────────────────────────────────────────────
          Container(
            margin: EdgeInsets.symmetric(vertical: 5.5.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              color: message.isSentByMe
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.only(
                topLeft: message.isSentByMe
                    ? Radius.circular(12.r)
                    : const Radius.circular(0),
                topRight: Radius.circular(12.r),
                bottomLeft: Radius.circular(12.r),

                bottomRight: message.isSentByMe
                    ? const Radius.circular(0)
                    : Radius.circular(12.r),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!message.isSentByMe && message.senderUsername != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 3.h),
                    child: Text(
                      message.senderUsername!,
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 4.w,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isSentByMe
                            ? Colors.white
                            : Theme.of(context).colorScheme.onBackground,
                        fontSize: 10.8.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        _formatTime(message.created_at),
                        style: TextStyle(
                          fontSize: 7.8.sp,
                          color: message.isSentByMe
                              ? Colors.white60
                              : const Color(0XFF8593A8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (message.isSentByMe) SizedBox(width: 6.w),
        ],
      ),
    );
  }

  Widget _buildHistoryLoader(GroupChatProvider provider) {
    if (!provider.isLoadingHistory) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // ── History error banner ──────────────────────────────────────────────────
  Widget _buildHistoryError(GroupChatProvider provider) {
    if (provider.historyError == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
      color: Colors.red.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14.sp, color: Colors.red),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'Failed to load messages. Pull down to retry.',
              style: TextStyle(fontSize: 10.5.sp, color: Colors.red),
            ),
          ),
          GestureDetector(
            onTap: () => provider.fetchMessageHistory(),
            child: Icon(Icons.refresh, size: 16.sp, color: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupChatProvider>();
    final imageBytes = _avatarUrl != null ? getProfileImage(_avatarUrl!) : null;
    final title = provider.chatName ?? widget.groupName ?? 'Chat';
    final memberCount = provider.members.length;
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        toolbarHeight: 40.h,
        automaticallyImplyLeading: false,
        leadingWidth: double.infinity,
        leading: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 12.w),
            const PrimaryBackButton(),
            CircleAvatar(
              radius: 18.r,
              backgroundColor: const Color(0XFFEEEEEE),
              backgroundImage: imageBytes != null
                  ? MemoryImage(imageBytes)
                  : null,
              child: imageBytes == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 7.w),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<GroupChatProvider>(),
                    child: ChatDetails(
                      chatName: provider.chatName,
                      profileUrl: _avatarUrl,
                      isGroupChat: true,
                      chatId: provider.chatId,
                      chat: provider.chat,
                    ),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                          color: provider.isConnected
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: TextStyle(
                          color: const Color(0XFF8593A8),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        actions: [
          Icon(FeatherIcons.video, size: 20.sp),
          SizedBox(width: 15.w),
          Icon(FeatherIcons.phone, size: 18.sp),
          SizedBox(width: 15.w),
        ],
      ),
      body: Column(
        children: [
          // Error banner — only rebuilds this section, not the message list
          _buildHistoryError(provider),

          Expanded(
            // ✅ StreamBuilder — only the message list rebuilds on new data
            // No full screen reload, no flicker
            child: StreamBuilder<List<ChatMessage>>(
              stream: context.read<GroupChatProvider>().messagesStream,
              // initialData feeds the list immediately from cached messages
              // so there is zero blank flash on first render
              initialData: context.read<GroupChatProvider>().messages,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                final prov = context.read<GroupChatProvider>();

                if (messages.isEmpty && !prov.isLoadingHistory) {
                  return Center(
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0XFF8593A8),
                        fontSize: 10.5.sp,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  // ✅ Normal top→bottom — no reverse
                  // index 0 = oldest (top), last = newest (bottom)
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: messages.length + 1,
                  itemBuilder: (ctx, index) {
                    // index 0 → history loader spinner at top
                    if (index == 0) return _buildHistoryLoader(prov);
                    // index 1..n → oldest→newest, top→bottom
                    return _buildMessageBubble(ctx, messages[index - 1]);
                  },
                );
              },
            ),
          ),

          // ── Input bar ──────────────────────────────────────────────────────
          Container(
            height: 37.h,
            width: double.infinity,
            margin: const EdgeInsets.all(12).w,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type here...',
                      hintStyle: TextStyle(color: Color(0XFF8593A8)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Icon(
                    FeatherIcons.image,
                    size: 20.spMax,
                    color: const Color(0XFF8593A8),
                  ),
                ),
                SizedBox(width: 7.w),
                GestureDetector(
                  onTap: () {},
                  child: Icon(
                    FeatherIcons.smile,
                    size: 20.spMax,
                    color: const Color(0XFF8593A8),
                  ),
                ),
                SizedBox(width: 7.w),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FeatherIcons.send,
                      size: 16.spMax,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
