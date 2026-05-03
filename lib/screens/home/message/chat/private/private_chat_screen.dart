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
    with UtilityMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;
  late bool _isUserBlock;

  int _previousMessageCount = 0;
  ChatMessage? _previousLastMessage;
  bool _isAtBottom = true;
  int _unreadCount = 0;

  String? _floatingDate;
  final Map<String, GlobalKey> _headerKeys = {};

  PrivateChatProvider get provider => context.read<PrivateChatProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isUserBlock = widget.isUserBlock;

    final userProvider = context.read<UserProvider>();
    _messagesStream = provider.messagesStream;

    debugPrint('User id : ${widget.userId}');

    // Track scroll position to know if user is at bottom
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.userId != null) {
        provider.setMemberUserId(widget.userId!);
      }
      provider.init(
        memberName: widget.memberName,
        profileUrl: widget.profileUrl,
        chatId: widget.chatId,
        currentUsername: userProvider.username,
      );

      _scrollController.addListener(() {
        if (!_scrollController.hasClients) return;
        if (_scrollController.position.maxScrollExtent > 0 &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 80) {
          _loadMoreHistory();
        }
      });

      if (widget.userId != null) {
        provider.setMemberUserId(widget.userId!);
      }
    });
  }

  Future<void> _loadMoreHistory() async {
    if (!provider.hasMoreHistory || provider.isLoadingHistory) return;
    await provider.fetchMoreHistory();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.position.pixels;
    // With reverse: true, the bottom is at pixels == 0
    final wasAtBottom = _isAtBottom;
    _isAtBottom = currentScroll < 100;

    if (wasAtBottom != _isAtBottom) {
      if (mounted) setState(() {});
    }

    if (_isAtBottom && _unreadCount > 0) {
      setState(() => _unreadCount = 0);
      context.read<PrivateChatProvider>().markAsRead();
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
      bool hasMore = context.read<PrivateChatProvider>().hasMoreHistory;
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
    // Reconnect WS when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      context.read<PrivateChatProvider>().reconnect();
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

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    context.read<PrivateChatProvider>().stopTyping();
    context.read<PrivateChatProvider>().sendMessage(text);
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatTime(DateTime dt) =>
      DateFormat('h:mm a').format(dt).toLowerCase();

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

  // ── Message status icon (pending / failed / sent / read) ──────────────────────────
  Widget _buildMessageStatus(ChatMessage message) {
    if (!message.isSentByMe) return const SizedBox.shrink();

    if (message.isFailed) {
      return Icon(Icons.error_outline, size: 11.sp, color: Colors.redAccent);
    }
    if (message.isPending) {
      return Icon(Icons.check, size: 11.sp, color: Colors.white54);
    }
    if (message.isRead) {
      return Icon(Icons.done_all, size: 11.sp, color: Colors.blue);
    }
    // Sent (delivered)
    return Icon(Icons.done_all, size: 11.sp, color: Colors.white70);
  }

  // ── Message bubble ─────────────────────────────────────────────────────────
  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    return Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.2.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
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
      ),
    );
  }

  // ── Top loader for pagination ──────────────────────────────────────────────
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

  // ── Scroll-to-bottom FAB with unread badge ─────────────────────────────────
  Widget _buildScrollToBottomButton() {
    if (_isAtBottom) return const SizedBox.shrink();
    return Positioned(
      bottom: 35.h,
      right: 14.w,
      child: GestureDetector(
        onTap: () {
          _scrollToBottom();
          setState(() => _unreadCount = 0);
          context.read<PrivateChatProvider>().markAsRead();
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

  // ── Typing dots animation ──────────────────────────────────────────────────
  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return _AnimatedDot(delay: Duration(milliseconds: i * 150));
      }),
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
            // ── Avatar with online indicator dot ───────────────────────────
            Stack(
              children: [
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
                // Green dot when member is online
                Consumer<PrivateChatProvider>(
                  builder: (_, p, __) {
                    if (!p.isMemberOnline) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.background,
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(width: 7.w),
            // ── Name + typing / online status ──────────────────────────────
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
                    builder: (_, p, __) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: p.isMemberTyping
                            ? Row(
                                key: const ValueKey('typing'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'typing',
                                    style: TextStyle(
                                      fontSize: 9.5.sp,
                                      color: Colors.green,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  SizedBox(width: 3.w),
                                  _buildTypingDots(),
                                ],
                              )
                            : Row(
                                key: const ValueKey('status'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p.isMemberOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: p.isMemberOnline
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
          // ── Connection banner ──────────────────────────────────────────────
          // _buildConnectionBanner(provider),

          // ── History error banner ───────────────────────────────────────────
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

          // ── Message list ───────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<List<ChatMessage>>(
                  stream: _messagesStream,
                  initialData: context.read<PrivateChatProvider>().messages,
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];
                    final isLoading = context
                        .read<PrivateChatProvider>()
                        .isLoadingHistory;

                    // Auto-scroll logic
                    if (messages.length > _previousMessageCount) {
                      if (_previousMessageCount == 0) {
                        // First load!
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_isAtBottom ||
                              (messages.isNotEmpty &&
                                  messages.last.isSentByMe)) {
                            _scrollToBottom();
                            context.read<PrivateChatProvider>().markAsRead();
                          }
                        });
                      } else {
                        // Find how many new messages were newly added to the end (new incoming messages)
                        int newAppendedCount = 0;
                        for (int i = messages.length - 1; i >= 0; i--) {
                          final m = messages[i];
                          if (_previousLastMessage != null &&
                              m.text == _previousLastMessage!.text &&
                              m.created_at ==
                                  _previousLastMessage!.created_at) {
                            break; // found the old boundary
                          }
                          newAppendedCount++;
                        }

                        // If messages were added at the end, trigger badge / scroll
                        // Note: If newAppendedCount == 0, it means it was an older history fetch at the top, so we ignore it completely!
                        if (newAppendedCount > 0 &&
                            newAppendedCount < messages.length) {
                          final lastIsMe = messages.last.isSentByMe;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_isAtBottom || lastIsMe) {
                              _scrollToBottom();
                              context.read<PrivateChatProvider>().markAsRead();
                            } else {
                              setState(() => _unreadCount += newAppendedCount);
                            }
                          });
                        }
                      }
                    }

                    _previousMessageCount = messages.length;
                    _previousLastMessage = messages.isNotEmpty
                        ? messages.last
                        : null;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _updateFloatingDate();

                      // Auto-fetch more history if the layout is underfilled (e.g., large screen or few messages)
                      if (_scrollController.hasClients) {
                        final maxScroll =
                            _scrollController.position.maxScrollExtent;
                        if (maxScroll <= 50 &&
                            !context
                                .read<PrivateChatProvider>()
                                .isLoadingHistory) {
                          context
                              .read<PrivateChatProvider>()
                              .fetchMoreHistory();
                        }
                      }
                    });

                    if (messages.isEmpty && !isLoading) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(
                                context,
                              )?.nomessagesyetstarttheconversation ??
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
                            _headerKeys[dateStr] = GlobalKey(
                              debugLabel: dateStr,
                            );
                          }

                          bool hideInlineDate =
                              isAbsoluteOldestMessage &&
                              context
                                  .read<PrivateChatProvider>()
                                  .hasMoreHistory;

                          if (hideInlineDate) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  key: _headerKeys[dateStr],
                                  height: 0,
                                  width: 0,
                                ),
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F2),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground.withOpacity(0.6),
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

                // ── Scroll-to-bottom FAB ─────────────────────────────────
                _buildScrollToBottomButton(),

                // ── Sticky Floating Date Header ─────────────────────────
                if (_floatingDate != null)
                  Positioned(
                    top: -10.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 10.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          _floatingDate ?? '',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
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
                      hintText:
                          AppLocalizations.of(context)?.message ?? 'Message',
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

// ── Animated typing dot ────────────────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  final Duration delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(
      begin: 0,
      end: -4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 3.5,
          height: 3.5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
