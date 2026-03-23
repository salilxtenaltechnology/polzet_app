// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import 'package:provider/provider.dart';

import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/message/message_model.dart';
import '../../../../../provider/private_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/button/back_button.dart';
import '../chat_details.dart';

class PrivateChatScreen extends StatefulWidget {
  final String? memberName;
  final String? profileUrl;
  final int? userId;
  final int? chatId;
  final bool isUserBlock;

  const PrivateChatScreen({
    super.key,
    required this.memberName,
    required this.profileUrl,
    required this.userId,
    this.chatId,
    this.isUserBlock = false,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with UtilityMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;
  late bool _isUserBlock;

  @override
  void initState() {
    super.initState();
    _isUserBlock = widget.isUserBlock;
    final provider = context.read<PrivateChatProvider>();
    final userProvider = context.read<UserProvider>();
    _messagesStream = provider.messagesStream;

    debugPrint('User id : ${widget.userId}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.init(
        memberName: widget.memberName,
        profileUrl: widget.profileUrl,
        chatId: widget.chatId,
        currentUsername: userProvider.username,
      );

      _scrollController.addListener(() {
        if (_scrollController.position.pixels <= 80 &&
            provider.hasMoreHistory &&
            !provider.isLoadingHistory) {
          provider.fetchMoreHistory();
        }
      });

      if (widget.userId != null) {
        provider.setMemberUserId(widget.userId!);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    context.read<PrivateChatProvider>().stopTyping();
    context.read<PrivateChatProvider>().sendMessage(text);
    _messageController.clear();
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    return Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color:
              (message.isSentByMe
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.tertiaryContainer)
                  .withOpacity(message.isPending ? 0.6 : 1.0),
          borderRadius: BorderRadius.only(
            topLeft: message.isSentByMe
                ? Radius.circular(15.r)
                : const Radius.circular(0),
            topRight: Radius.circular(15.r),
            bottomLeft: Radius.circular(15.r),

            bottomRight: message.isSentByMe
                ? const Radius.circular(0)
                : Radius.circular(15.r),
          ),
        ),
        child: Wrap(
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
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.created_at),
                  style: TextStyle(
                    fontSize: 7.8.sp,
                    color: message.isSentByMe
                        ? Colors.white60
                        : const Color(0XFF8593A8),
                  ),
                ),
                if (message.isSentByMe && message.isPending) ...[
                  SizedBox(width: 3.w),
                  Icon(
                    Icons.access_time_rounded,
                    size: 9.sp,
                    color: Colors.white54,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryLoader(bool isLoading) {
    if (!isLoading) return const SizedBox.shrink();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrivateChatProvider>();

    final imageBytes = widget.profileUrl != null
        ? getProfileImage(widget.profileUrl!)
        : null;
    final initial = (widget.memberName?.trim().isNotEmpty ?? false)
        ? widget.memberName![0].toUpperCase()
        : '?';

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
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 7.w),
            GestureDetector(
              onTap: () async {
                final updatedBlock = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<PrivateChatProvider>(),
                      child: ChatDetails(
                        userId: widget.userId,
                        chatName: widget.memberName,
                        profileUrl: widget.profileUrl,
                        isGroupChat: false,
                        isUserBlock: _isUserBlock,
                      ),
                    ),
                  ),
                );
                if (mounted && updatedBlock != null) {
                  setState(() => _isUserBlock = updatedBlock);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.memberName ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Consumer<PrivateChatProvider>(
                    builder: (_, provider, __) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: provider.isMemberTyping
                            ? Row(
                                key: const ValueKey('typing'),
                                children: [
                                  Text(
                                    'typing...',
                                    style: TextStyle(
                                      fontSize: 9.5.sp,
                                      color: const Color(0xFF8593A8),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  const SizedBox(
                                    width: 16,
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                      backgroundColor: Colors.transparent,
                                      color: Color(0xFF8593A8),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('status'),
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
                                    provider.isConnected ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: provider.isConnected
                                          ? Colors.green
                                          : Colors.grey,
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w300,
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
          if (provider.historyError != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 14.sp, color: Colors.red),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Failed to load messages. Tap to retry.',
                      style: TextStyle(fontSize: 10.5.sp, color: Colors.red),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => provider.fetchMessageHistory(),
                    child: Icon(Icons.refresh, size: 16.sp, color: Colors.red),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              initialData: context.read<PrivateChatProvider>().messages,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                final isLoading = context
                    .read<PrivateChatProvider>()
                    .isLoadingHistory;

                if (messages.isEmpty && !isLoading) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.nomessagesyetstarttheconversation,
                    
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
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: messages.length + 1,
                  itemBuilder: (ctx, index) {
                    if (index == 0) return _buildHistoryLoader(isLoading);
                    return _buildMessageBubble(ctx, messages[index - 1]);
                  },
                );
              },
            ),
          ),

          Container(
            height: 35.h,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 5, 12, 12).w,
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
                    onChanged: (_) =>
                        context.read<PrivateChatProvider>().onUserTyping(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context)!.message,
                      hintStyle: TextStyle(
                        color: const Color(0XFF8593A8),
                        fontSize: 11.5.sp,
                      ),
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
