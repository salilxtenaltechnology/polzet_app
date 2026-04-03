// ignore_for_file: deprecated_member_use, must_be_immutable

import 'dart:typed_data';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../languages/l10n/generated/app_localizations.dart';
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

class GroupChatScreenState extends State<GroupChatScreen>
    with UtilityMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;

  int _previousMessageCount = 0;
  ChatMessage? _previousLastMessage;
  bool _isAtBottom = true;
  int _unreadCount = 0;

  String? _floatingDate;
  final Map<String, GlobalKey> _headerKeys = {};

  GroupChatProvider get provider => context.read<GroupChatProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final userProvider = context.read<UserProvider>();
    _messagesStream = provider.messagesStream;

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.init(
        groupName: widget.groupName,
        groupImageUrl: _avatarUrl,
        chatId: widget.chatId,
        currentUsername: userProvider.username,
        currentUserId: userProvider.userId,
        chat: widget.chat,
      );

      _scrollController.addListener(() {
        if (!_scrollController.hasClients) return;
        if (_scrollController.position.maxScrollExtent > 0 &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 80) {
          _loadMoreHistory();
        }
      });
    });
  }

  Future<void> _loadMoreHistory() async {
    if (!provider.hasMoreHistory || provider.isLoadingHistory) return;
    await provider.fetchMoreHistory();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.position.pixels;
    
    final wasAtBottom = _isAtBottom;
    _isAtBottom = currentScroll < 100;

    if (wasAtBottom != _isAtBottom) {
      if (mounted) setState(() {});
    }

    if (_isAtBottom && _unreadCount > 0) {
      setState(() => _unreadCount = 0);
    }

    _updateFloatingDate();
  }

  void _updateFloatingDate() {
    String? bestDate;
    double maxDy = double.negativeInfinity;

    String? topMostDate;
    double topMostHeaderDy = double.infinity;

    final threshold = MediaQuery.of(context).padding.top + 40.h + 30;

    _headerKeys.forEach((dateStr, key) {
      final currentCtx = key.currentContext;
      if (currentCtx == null) return;
      final box = currentCtx.findRenderObject() as RenderBox?;
      if (box == null) return;

      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy < topMostHeaderDy) {
        topMostHeaderDy = dy;
        topMostDate = dateStr;
      }

      if (dy <= threshold) {
        if (dy > maxDy) {
          maxDy = dy;
          bestDate = dateStr;
        }
      }
    });

    if (bestDate != null) {
      if (_floatingDate != bestDate) {
        setState(() {
          _floatingDate = bestDate;
        });
      }
    } else {
      bool hasMore = context.read<GroupChatProvider>().hasMoreHistory;
      bool isScreenCovered = hasMore;
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        if (_scrollController.position.maxScrollExtent > 0) {
           isScreenCovered = true;
        }
      }

      if (!isScreenCovered) {
        if (_floatingDate != null) {
          setState(() {
            _floatingDate = null;
          });
        }
      } else if (topMostDate != null) {
        if (_floatingDate != topMostDate) {
          setState(() {
            _floatingDate = topMostDate;
          });
        }
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      context.read<GroupChatProvider>().reconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String? get _avatarUrl {
    final profileUrl = widget.chat?['profile_url']?.toString();
    if (profileUrl != null && profileUrl.trim().isNotEmpty) {
      return profileUrl;
    }
    return null;
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    context.read<GroupChatProvider>().stopTyping();
    context.read<GroupChatProvider>().sendMessage(text);
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt).toLowerCase();

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _getDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(msgDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  Widget _buildMessageStatus(ChatMessage message) {
    if (!message.isSentByMe) return const SizedBox.shrink();

    if (message.isFailed) {
      return Icon(Icons.error_outline, size: 11.sp, color: Colors.redAccent);
    }
    if (message.isPending) {
      return Icon(Icons.check, size: 11.sp, color: Colors.white54);
    }
    return Icon(Icons.done_all, size: 11.sp, color: Colors.white70);
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    Uint8List? avatarBytes;
    if (!message.isSentByMe && message.senderProfileImage != null) {
      avatarBytes = getProfileImage(message.senderProfileImage!);
    }

    final String initial = (message.senderUsername?.isNotEmpty == true)
        ? message.senderUsername![0].toUpperCase()
        : '?';

    return Align(
      alignment: message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            message.isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isSentByMe) ...[
            SizedBox(width: 6.w),
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: CircleAvatar(
                radius: 12.r,
                backgroundColor: const Color(0xFFEEEEEE),
                backgroundImage:
                    avatarBytes != null ? MemoryImage(avatarBytes) : null,
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
          Container(
            margin: EdgeInsets.symmetric(vertical: 4.h),
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
                    ? Radius.circular(10.r)
                    : const Radius.circular(0),
                topRight: Radius.circular(10.r),
                bottomLeft: Radius.circular(10.r),
                bottomRight: message.isSentByMe
                    ? const Radius.circular(0)
                    : Radius.circular(10.r),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.created_at),
                          style: TextStyle(
                            fontSize: 8.2.sp,
                            color: message.isSentByMe
                                ? Colors.white60
                                : const Color(0XFF8593A8),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        _buildMessageStatus(message),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (message.isSentByMe) SizedBox(width: 12.w),
        ],
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
    );
  }

  Widget _buildScrollToBottomButton() {
    if (_isAtBottom) return const SizedBox.shrink();
    return Positioned(
      bottom: 35.h,
      right: 14.w,
      child: GestureDetector(
        onTap: () {
          _scrollToBottom();
          setState(() => _unreadCount = 0);
        },
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.keyboard_arrow_down, size: 20.sp, color: Colors.white),
              if (_unreadCount > 0)
                Positioned(
                  top: -13,
                  right: -9,
                  child: Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 2, 148, 77),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.background,
                        fontSize: 7.2.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupChatProvider>();
    final imageBytes = _avatarUrl != null ? getProfileImage(_avatarUrl!) : null;
    final title = provider.groupName ?? widget.groupName ?? 'Chat';

    // We count members based on memberPresence since there's no static members list in the provider
    // Or we could read from widget.chat if available.
    final memberCount = widget.chat?['members']?.length ?? provider.memberPresence.length;
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
              backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
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
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<GroupChatProvider>(),
                      child: ChatDetails(
                        chatName: title,
                        profileUrl: _avatarUrl,
                        isGroupChat: true,
                        chatId: provider.chatId,
                        chat: widget.chat,
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
                    Consumer<GroupChatProvider>(
                      builder: (_, prov, __) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: prov.isSomeoneTyping
                              ? Row(
                                  key: const ValueKey('typing'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      prov.typingIndicatorText,
                                      style: TextStyle(
                                        fontSize: 9.5.sp,
                                        color: Colors.green,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  key: const ValueKey('status'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    (() {
                                      final onlineCount = prov.memberPresence.values
                                          .where((m) => m.isOnline && m.userId != prov.currentUserId)
                                          .length;
                                      if (onlineCount > 0) {
                                        return Text(
                                          '$onlineCount online',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 9.5.sp,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        );
                                      } else {
                                        return ConstrainedBox(
                                          constraints: BoxConstraints(maxWidth: 200.w),
                                          child: Text(
                                            '$memberCount ${memberCount == 1 ? AppLocalizations.of(context)!.member : AppLocalizations.of(context)!.members}',
                                            style: TextStyle(
                                              color: const Color(0XFF8593A8),
                                              fontSize: 9.5.sp,
                                              fontWeight: FontWeight.w300,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                        );
                                      }
                                    })(),
                                  ],
                                ),
                        );
                      },
                    ),
                  ],
                ),
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
          if (provider.historyError != null) _buildHistoryError(provider),
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<List<ChatMessage>>(
                  stream: _messagesStream,
                  initialData: context.read<GroupChatProvider>().messages,
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];
                    final isLoading = context.read<GroupChatProvider>().isLoadingHistory;

                    if (messages.length > _previousMessageCount) {
                      if (_previousMessageCount == 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_isAtBottom || (messages.isNotEmpty && messages.last.isSentByMe)) {
                            _scrollToBottom();
                          }
                        });
                      } else {
                        int newAppendedCount = 0;
                        for (int i = messages.length - 1; i >= 0; i--) {
                          final m = messages[i];
                          if (_previousLastMessage != null &&
                              m.text == _previousLastMessage!.text &&
                              m.created_at == _previousLastMessage!.created_at) {
                            break;
                          }
                          newAppendedCount++;
                        }

                        if (newAppendedCount > 0 && newAppendedCount < messages.length) {
                          final lastIsMe = messages.last.isSentByMe;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_isAtBottom || lastIsMe) {
                              _scrollToBottom();
                            } else {
                              setState(() => _unreadCount += newAppendedCount);
                            }
                          });
                        }
                      }
                    }

                    _previousMessageCount = messages.length;
                    _previousLastMessage = messages.isNotEmpty ? messages.last : null;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _updateFloatingDate();

                      if (_scrollController.hasClients) {
                        final maxScroll = _scrollController.position.maxScrollExtent;
                        if (maxScroll <= 50 &&
                            !context.read<GroupChatProvider>().isLoadingHistory) {
                          context.read<GroupChatProvider>().fetchMoreHistory();
                        }
                      }
                    });

                    if (messages.isEmpty && !isLoading) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)?.nomessagesyetstarttheconversation ??
                              'No messages yet...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0XFF8593A8),
                            fontSize: 10.5.sp,
                          ),
                        ),
                      );
                    }

                    final reversedMessages = messages.reversed.toList();
                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: reversedMessages.length + 1,
                      itemBuilder: (ctx, index) {
                        if (index == reversedMessages.length) {
                          return _buildHistoryLoader(isLoading);
                        }

                        final message = reversedMessages[index];
                        bool showHeader = false;
                        bool isAbsoluteOldestMessage = false;

                        if (index == reversedMessages.length - 1) {
                          showHeader = true;
                          isAbsoluteOldestMessage = true;
                        } else {
                          final previousMessage = reversedMessages[index + 1];
                          showHeader = !_isSameDay(
                            message.created_at,
                            previousMessage.created_at,
                          );
                        }

                        if (showHeader) {
                          final dateStr = _getDateSeparator(message.created_at);
                          if (!_headerKeys.containsKey(dateStr)) {
                            _headerKeys[dateStr] = GlobalKey(debugLabel: dateStr);
                          }

                          bool hideInlineDate = isAbsoluteOldestMessage &&
                              context.read<GroupChatProvider>().hasMoreHistory;

                          if (hideInlineDate) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(key: _headerKeys[dateStr], height: 0, width: 0),
                                _buildMessageBubble(ctx, message),
                              ],
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                key: _headerKeys[dateStr],
                                margin: EdgeInsets.symmetric(vertical: 10.h),
                                padding:
                                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F2),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ),
                              _buildMessageBubble(ctx, message),
                            ],
                          );
                        }

                        return _buildMessageBubble(ctx, message);
                      },
                    );
                  },
                ),
                _buildScrollToBottomButton(),
                if (_floatingDate != null)
                  Positioned(
                    top: -10.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 10.h),
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          _floatingDate ?? '',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
                    onChanged: (_) => context.read<GroupChatProvider>().onUserTyping(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context)?.message ?? 'Message',
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
