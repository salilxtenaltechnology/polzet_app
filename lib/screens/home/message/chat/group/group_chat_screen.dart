// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../api/api_config.dart';
import '../../../../../api/api_service.dart';
import '../../../../../api/services/share/share_service.dart';
import '../../../../../gen/assets.gen.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/message/message_model.dart';
import '../../../../../models/posts/single_post_model.dart';
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../../search/posts/rank/single_post_image_ranking.dart';
import '../../../search/posts/rank/single_post_things_ranking.dart';
import '../../../profile/profile_screen.dart';
import '../../../profile/public/public_profile_screen.dart';
import '../../../search/posts/single_post_details.dart';
import '../../../../../provider/group_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/show_toast.dart';
import 'info/group_info_screen.dart';
import '../../../../../widgets/card/shared_group_card.dart';
import '../../../../../widgets/dialog/custom_diolog.dart';
import '../../message_list.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.groupName,
    this.chat,
    required this.chatId,
    this.chatTheme,
  });

  final Map<String, dynamic>? chat;
  final dynamic chatId;
  final String? groupName;
  final dynamic chatTheme;

  @override
  State<GroupChatScreen> createState() => GroupChatScreenState();
}

class GroupChatScreenState extends State<GroupChatScreen>
    with UtilityMixin, WidgetsBindingObserver {
  String? _floatingDate;
  String? _localGroupImageUrl;
  final Map<String, GlobalKey> _headerKeys = {};
  bool _isPolzetAiUsername(String? username) {
    if (username == null) return false;
    final u = username.trim().toLowerCase();
    return u == 'polzet_ai' || u == 'polet_ai';
  }

  bool _isAtBottom = true;
  final TextEditingController _messageController = TextEditingController();
  late Stream<List<ChatMessage>> _messagesStream;
  ChatMessage? _previousLastMessage;
  int _previousMessageCount = 0;
  final ScrollController _scrollController = ScrollController();
  int _unreadCount = 0;

  ChatMessage? _selectedMessage;

  bool _isMessageSelected(ChatMessage message) {
    if (_selectedMessage == null) return false;
    if (identical(_selectedMessage, message)) return true;
    if (_selectedMessage!.id != null && message.id != null) {
      return _selectedMessage!.id.toString() == message.id.toString();
    }
    return _selectedMessage!.created_at == message.created_at &&
        _selectedMessage!.text == message.text &&
        _selectedMessage!.isSentByMe == message.isSentByMe;
  }

  Future<void> _copySelectedMessage() async {
    if (_selectedMessage != null && _selectedMessage!.text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _selectedMessage!.text));
      showToast(message: 'Message copied');
      setState(() {
        _selectedMessage = null;
      });
    }
  }

  void _deleteSelectedMessage() {
    if (_selectedMessage == null) return;
    final messageToDelete = _selectedMessage!;

    showDeleteMessageDialog(context, () async {
      Navigator.of(context).pop();
      setState(() {
        _selectedMessage = null;
      });

      dynamic messageId = messageToDelete.id;
      dynamic chatId =
          messageToDelete.chatId ?? widget.chatId ?? provider.chatId;

      // Try to find matching message in provider's updated list if id is missing
      if (messageId == null) {
        final matched = provider.messages.firstWhere(
          (m) =>
              m.id != null &&
              m.text == messageToDelete.text &&
              m.isSentByMe == messageToDelete.isSentByMe,
          orElse: () => messageToDelete,
        );
        messageId = matched.id;
        chatId ??= matched.chatId;
      }

      // If messageId is still missing, refresh history to get server IDs
      if (messageId == null && chatId != null) {
        try {
          await provider.fetchMessageHistory();
          final matched = provider.messages.firstWhere(
            (m) =>
                m.id != null &&
                m.text == messageToDelete.text &&
                m.isSentByMe == messageToDelete.isSentByMe,
            orElse: () => messageToDelete,
          );
          messageId = matched.id;
          chatId ??= matched.chatId;
        } catch (e) {
          debugPrint('Error refreshing group history for message ID: $e');
        }
      }

      if (messageId == null || chatId == null) {
        showToast(message: 'Unable to delete message: Missing ID');
        return;
      }

      try {
        await provider.deleteMessage(messageId: messageId, chatId: chatId);
        showToast(message: 'Message deleted');
      } catch (e) {
        debugPrint('❌ Failed to delete group message: $e');
        showToast(message: e.toString().replaceAll('Exception: ', ''));
      }
    });
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
        chatTheme:
            widget.chatTheme ??
            widget.chat?['chat_theme'] ??
            widget.chat?['chatTheme'],
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

  GroupChatProvider get provider => context.read<GroupChatProvider>();

  Future<void> _loadMoreHistory() async {
    if (!provider.hasMoreHistory || provider.isLoadingHistory) return;
    await provider.fetchMoreHistory();
  }

  Future<void> _openChatDetails(String title) async {
    final gp = context.read<GroupChatProvider>();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: gp,
          child: GroupInfoScreen(
            chatId: provider.chatId,
            groupChatProvider: gp,
            groupImage: _avatarUrl,
            groupName: provider.groupName ?? widget.groupName,
          ),
        ),
      ),
    );
    if (mounted) {
      if (result is Map) {
        final imgUrl = result['groupImageUrl']?.toString();
        final name = result['groupName']?.toString();
        if (imgUrl != null && imgUrl.isNotEmpty) {
          _localGroupImageUrl = imgUrl;
          gp.updateGroupPicture(imgUrl);
        }
        if (name != null && name.isNotEmpty) {
          gp.updateGroupNameLocally(name);
        }
      }
      setState(() {});
    }
  }

  Future<void> _showClearChatConfirmationDialog() async {
    showClearChatDiolog(context, () {
      Navigator.pop(context);
      _clearChatMessages();
    });
  }

  Future<void> _showDeleteChatConfirmationDialog() async {
    showDeleteChatDiolog(context, () {
      Navigator.pop(context);
      _deleteChat();
    });
  }

  Future<void> _deleteChat() async {
    final chatId = widget.chatId?.toString() ?? provider.chatId?.toString();
    if (chatId == null || chatId.isEmpty) return;
    try {
      final response = await ApiService().deleteChat(chatId: chatId);
      if (response['status'] == 'success' || response['success'] == true) {
        MessageListState.removeChatLocally(chatId);
        showToast(message: 'Chat deleted');
        Navigator.pop(context);
      } else {
        showToast(
          message: response['message']?.toString() ?? 'Failed to delete chat',
        );
      }
    } catch (e) {
      showToast(message: 'Failed to delete chat: $e');
    }
  }

  Future<void> _clearChatMessages() async {
    final chatId = widget.chatId?.toString() ?? provider.chatId?.toString();
    if (chatId == null || chatId.isEmpty) {
      showToast(message: 'Cannot clear a new chat');
      return;
    }

    // Instantly remove messages locally for immediate response
    provider.clearLocalMessages();
    MessageListState.clearChatLocally(chatId);

    try {
      showToast(message: 'Clearing chat...');
      final response = await ApiService().clearChat(chatId: chatId);
      if (response['status'] == 'success' || response['success'] == true) {
        provider.clearLocalMessages();
        MessageListState.clearChatLocally(chatId);
        showToast(message: 'Chat cleared');
      } else {
        showToast(
          message: response['message']?.toString() ?? 'Failed to clear chat',
        );
      }
    } catch (e) {
      showToast(message: 'Failed to clear chat: $e');
    }
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
      context.read<GroupChatProvider>().markAsRead();
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

  String? get _avatarUrl {
    if (_localGroupImageUrl != null && _localGroupImageUrl!.trim().isNotEmpty) {
      return _localGroupImageUrl!.trim();
    }
    final providerImg = provider.groupImageUrl;
    if (providerImg != null &&
        providerImg.trim().isNotEmpty &&
        providerImg != 'null') {
      return providerImg.trim();
    }
    final chatData = provider.chat ?? widget.chat;
    final profileUrl =
        (chatData?['profile_url'] ??
                chatData?['group_picture_url'] ??
                chatData?['picture_url'] ??
                chatData?['avatar_url'])
            ?.toString();
    if (profileUrl != null &&
        profileUrl.trim().isNotEmpty &&
        profileUrl != 'null') {
      return profileUrl.trim();
    }
    final fallbackUrl =
        (widget.chat?['profile_url'] ??
                widget.chat?['group_picture_url'] ??
                widget.chat?['picture_url'] ??
                widget.chat?['avatar_url'])
            ?.toString();
    if (fallbackUrl != null &&
        fallbackUrl.trim().isNotEmpty &&
        fallbackUrl != 'null') {
      return fallbackUrl.trim();
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
    } else if (difference > 1 && difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('d MMMM yyyy').format(date);
    }
  }

  Color _getUsernameColor(String username) {
    final colors = [
      const Color(0xFFE53935), // red
      const Color(0xFF8E24AA), // purple
      const Color(0xFF1E88E5), // blue
      const Color(0xFF00897B), // teal
      const Color(0xFFF4511E), // deep orange
      // const Color(0xFF3949AB), // indigo
      const Color(0xFF039BE5), // light blue
      const Color(0xFF43A047), // green
      const Color(0xFFFFB300), // amber
    ];
    int hash = 0;
    for (int i = 0; i < username.length; i++) {
      hash = username.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  Color _getInitialColor(String username) {
    return _getUsernameColor(username);
  }

  void _navigateToPublicProfile(String? userId, String? username) {
    if (userId == null && (username == null || username.isEmpty)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId, username: username),
      ),
    );
  }

  static final RegExp _urlRegex = RegExp(
    r'((?:https?:\/\/|www\.|(?:[a-zA-Z0-9-]+\.)?polzet\.(?:com|in)\/)[^\s<>()]+(?:\([^\s<>()]+\)|[^\s`!()\[\]{};:\x27"\x22.,<>?«»“”‘’]))|(polzet:\/\/[^\s]+)',
    caseSensitive: false,
  );

  String? _extractProfileUsernameFromUri(Uri uri) {
    try {
      // 1. Custom scheme: polzet://profile/{username} or polzet://{username}
      if (uri.scheme.toLowerCase() == 'polzet') {
        final host = uri.host.toLowerCase();
        if (host == 'post') {
          return null;
        }
        if (host == 'profile') {
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            final username = segments[0].replaceFirst(RegExp(r'^@'), '').trim();
            if (username.isNotEmpty) return username;
          }
        } else if (host.isNotEmpty && host != 'g' && host != 'group') {
          final username = uri.host.replaceFirst(RegExp(r'^@'), '').trim();
          if (username.isNotEmpty) return username;
        }
      }

      // 2. HTTPS / HTTP link with polzet domain or deepLinkHost
      final host = uri.host.toLowerCase();
      final isPolzetHost =
          host.contains('polzet.com') ||
          host.contains('polzet.in') ||
          host == ApiConfig.deepLinkHost.toLowerCase();

      if (isPolzetHost) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isEmpty) return null;

        // Skip post routes: /post/{username}/{postId} or /post/{postId}
        if (segments[0].toLowerCase() == 'post') {
          return null;
        }

        // Skip group routes: /g/{slug} or /group/{slug}
        if (segments[0].toLowerCase() == 'g' ||
            segments[0].toLowerCase() == 'group') {
          return null;
        }

        // Format: /profile/{username}
        if (segments[0].toLowerCase() == 'profile') {
          if (segments.length >= 2) {
            final username = segments[1].replaceFirst(RegExp(r'^@'), '').trim();
            if (username.isNotEmpty) return username;
          }
          return null;
        }

        // Format: /{username} (e.g. /mileco_555 or /@mileco_555)
        if (segments.length == 1) {
          final first = segments[0].toLowerCase();
          const reservedRoutes = {
            'post',
            'profile',
            'g',
            'group',
            'static',
            'assets',
            'terms',
            'privacy',
            'about',
            'help',
            'faq',
            'settings',
            'login',
            'signup',
            'register',
            'api',
          };
          if (!reservedRoutes.contains(first)) {
            final username = segments[0].replaceFirst(RegExp(r'^@'), '').trim();
            if (username.isNotEmpty) return username;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing profile URI: $e');
    }
    return null;
  }

  Map<String, String>? _extractPostInfoFromUri(Uri uri) {
    try {
      // 1. Custom scheme: polzet://post/{username}/{postId}
      if (uri.scheme == 'polzet' && uri.host == 'post') {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length >= 2) {
          return {'username': segments[0], 'postId': segments[1]};
        }
      }

      // 2. HTTPS / HTTP link with polzet domain or deepLinkHost
      final host = uri.host.toLowerCase();
      final isPolzetHost =
          host.contains('polzet.com') ||
          host.contains('polzet.in') ||
          host == ApiConfig.deepLinkHost.toLowerCase();

      if (isPolzetHost) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        // Format: /post/{username}/{postId}
        if (segments.length >= 3 && segments[0].toLowerCase() == 'post') {
          return {'username': segments[1], 'postId': segments[2]};
        }
        // Format: /post/{postId}
        if (segments.length == 2 && segments[0].toLowerCase() == 'post') {
          return {'username': 'user', 'postId': segments[1]};
        }
      }
    } catch (e) {
      debugPrint('Error parsing post URI: $e');
    }
    return null;
  }

  Future<void> _handleLinkTap(BuildContext context, String rawUrl) async {
    if (_selectedMessage != null) {
      return;
    }

    String formattedUrl = rawUrl.trim();
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://') &&
        !formattedUrl.startsWith('polzet://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    try {
      final uri = Uri.parse(formattedUrl);

      // 1. Check if it is a Polzet profile link
      final profileUsername = _extractProfileUsernameFromUri(uri);
      if (profileUsername != null && profileUsername.isNotEmpty) {
        if (context.mounted) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final currentUsername = userProvider.username;
          final isCurrentUser =
              currentUsername != null &&
              currentUsername.isNotEmpty &&
              currentUsername.toLowerCase() == profileUsername.toLowerCase();

          if (isCurrentUser) {
            navigationPush(context, const ProfileScreen());
          } else {
            _navigateToPublicProfile(null, profileUsername);
          }
        }
        return;
      }

      // 2. Check if it is a current app post link
      final postInfo = _extractPostInfoFromUri(uri);
      if (postInfo != null) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SinglePostDetails(
                username: postInfo['username']!,
                postId: postInfo['postId']!,
              ),
            ),
          );
        }
        return;
      }

      // Otherwise launch in chrome / external application
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } else {
        showToast(message: 'Could not open link');
      }
    } catch (e) {
      debugPrint('Error opening link: $e');
      showToast(message: 'Invalid link');
    }
  }

  Widget _buildMessageText(
    BuildContext context, {
    required String text,
    required TextStyle baseStyle,
    required bool isSentByMe,
  }) {
    final matches = _urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = provider.currentTheme;
    final linkColor = isSentByMe
        ? (theme?.getOutgoingLinkTextColor(isDarkMode) ??
              const Color(0xFF90CAF9))
        : (theme?.getIncomingLinkTextColor(isDarkMode) ??
              (isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF1976D2)));

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _handleLinkTap(context, url);
            },
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildMessageStatus(ChatMessage message, {Color? statusColor}) {
    if (!message.isSentByMe) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fallbackColor = isDarkMode
        ? const Color(0xBDFFFFFF)
        : AppTextColors.of(context).muted;

    if (message.isFailed) {
      return Icon(Icons.error_outline, size: 11.sp, color: Colors.redAccent);
    }
    if (message.isPending) {
      return Icon(
        Icons.check,
        size: 11.5.sp,
        color: statusColor ?? fallbackColor,
      );
    }
    return Icon(
      Icons.done_all,
      size: 11.5.sp,
      color: statusColor ?? fallbackColor,
    );
  }

  // ── Shared Post Card ───────────────────────────────────────────────────────
  Widget _buildSharedPostCard(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    final post = message.sharedPost!;

    final bool isLocked =
        post['is_locked'] == true ||
        post['is_locked']?.toString().toLowerCase() == 'true';
    if (isLocked) {
      final authorUsername =
          post['author_username']?.toString() ??
          (post['user'] is Map ? post['user']['username']?.toString() : null) ??
          '';
      final authorUserId =
          post['user_id']?.toString() ??
          post['userId']?.toString() ??
          (post['user'] is Map
              ? (post['user']['userid'] ?? post['user']['id'])?.toString()
              : null);
      final errorMsg = post['error']?.toString().trim();
      final displayError = (errorMsg != null && errorMsg.isNotEmpty)
          ? errorMsg
          : 'This post is from a private account. Follow this user to view their polls.';

      void handleViewProfile() {
        if (authorUsername.isNotEmpty ||
            (authorUserId != null && authorUserId.isNotEmpty)) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final currentUserId = userProvider.userId?.toString();
          final currentUsername = userProvider.username;
          final isCurrentUser =
              (currentUserId != null &&
                  currentUserId.isNotEmpty &&
                  authorUserId != null &&
                  authorUserId.isNotEmpty &&
                  currentUserId == authorUserId) ||
              (currentUsername != null &&
                  currentUsername.isNotEmpty &&
                  authorUsername.isNotEmpty &&
                  currentUsername.toLowerCase() ==
                      authorUsername.toLowerCase());

          if (isCurrentUser) {
            navigationPush(context, const ProfileScreen());
          } else {
            _navigateToPublicProfile(
              (authorUserId != null && authorUserId.isNotEmpty)
                  ? authorUserId
                  : null,
              authorUsername.isNotEmpty ? authorUsername : null,
            );
          }
        }
      }

      return Container(
        margin: EdgeInsets.only(
          top: 12,
          bottom: 12,
          left: message.isSentByMe ? 50.w : 0,
          right: message.isSentByMe ? 0 : 50.w,
        ),
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
        decoration: BoxDecoration(
          color:
              (message.isSentByMe
                  ? currentTheme?.getOutgoingCardColor(isDarkMode)
                  : currentTheme?.getIncomingCardColor(isDarkMode)) ??
              Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: currentTheme?.id == 'midnight_navy'
                ? const Color(0x339EAFC0)
                : Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Poll unavailable',
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              displayError,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: currentTheme?.id == 'midnight_navy'
                    ? const Color(0xFF9EAFC0)
                    : (isDarkMode ? const Color(0xFFB0B0B0) : txt.body),
              ),
            ),
            SizedBox(height: 14.h),
            GestureDetector(
              onTap: handleViewProfile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                alignment: Alignment.center,
                child: Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final user = post['user'] ?? {};
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final username = user['username']?.toString() ?? '';
    final String? avatarUrlRaw = user['profile_image']?.toString();
    String? avatarUrl;
    if (avatarUrlRaw != null && avatarUrlRaw.isNotEmpty) {
      if (avatarUrlRaw.startsWith('http') ||
          avatarUrlRaw.startsWith('data:image')) {
        avatarUrl = avatarUrlRaw;
      } else {
        if (avatarUrlRaw.startsWith('/')) {
          avatarUrl = '${ApiConfig.baseUrlImage}$avatarUrlRaw';
        } else {
          avatarUrl = '${ApiConfig.baseUrlImage}/$avatarUrlRaw';
        }
      }
    }
    final description = post['description']?.toString() ?? '';
    final isPolledByCurrentUser = post['is_polled_by_current_user'] == true;

    // Get time ago
    final dtStr = post['created_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(dtStr) ?? DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    String timeAgo = '';
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours} hr ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    // Extract images & poll text
    List<String> imageUrls = [];
    String pollQuestion = '';
    String pollType = '';
    List<String> pollTextOptions = [];

    if (post['polls'] != null && (post['polls'] as List).isNotEmpty) {
      for (var p in (post['polls'] as List)) {
        if (p is Map) {
          if (pollType.isEmpty) {
            pollType =
                p['poll_type']?.toString().toLowerCase() ??
                p['type']?.toString().toLowerCase() ??
                '';
          }
          if (pollQuestion.isEmpty &&
              p['question'] != null &&
              p['question'].toString().trim().isNotEmpty) {
            pollQuestion = p['question'].toString().trim();
          }
          final options = p['options'] as List? ?? [];
          for (var opt in options) {
            if (opt is Map) {
              if (opt['image'] != null && opt['image'] is Map) {
                final url =
                    opt['image']['url'] ?? opt['image']['thumbnail_url'];
                if (url != null && url.toString().isNotEmpty) {
                  imageUrls.add(url.toString());
                }
              } else if (opt['text'] != null &&
                  opt['text'].toString().trim().isNotEmpty) {
                pollTextOptions.add(opt['text'].toString().trim());
              }
            }
          }
        }
      }
    }

    if (post['images'] != null && (post['images'] as List).isNotEmpty) {
      for (var img in post['images']) {
        if (img is Map) {
          final url = img['image'] ?? img['url'] ?? img['thumbnail_url'];
          if (url != null && url.toString().isNotEmpty) {
            imageUrls.add(url.toString());
          }
        } else if (img is String && img.isNotEmpty) {
          imageUrls.add(img);
        }
      }
    }

    if (pollQuestion.isEmpty && post['question'] != null) {
      pollQuestion = post['question'].toString().trim();
    }
    if (pollType.isEmpty) {
      pollType =
          post['poll_type']?.toString().toLowerCase() ??
          post['type']?.toString().toLowerCase() ??
          '';
    }

    final bool isHotTake =
        pollType == 'hot_take' ||
        pollType == 'hot take' ||
        pollType == 'hot-take';

    final seenUrls = <String>{};
    imageUrls = imageUrls
        .where((e) => e.isNotEmpty && seenUrls.add(e))
        .toList();

    if (isHotTake && imageUrls.isNotEmpty) {
      imageUrls = [imageUrls.first];
    }

    // Removed base64 decode logic for avatar

    return GestureDetector(
      onTap: () {
        if (isHotTake) {
          final postId = post['id']?.toString() ?? '';
          if (postId.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SinglePostDetails(username: username, postId: postId),
              ),
            );
          }
          return;
        }

        final isImagePoll = imageUrls.isNotEmpty;
        final isThingsPoll = pollTextOptions.isNotEmpty;

        if (!isImagePoll && !isThingsPoll) return;

        if (isPolledByCurrentUser) {
          if (isImagePoll) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageResultScreen(
                  username: username,
                  postId: post['id'].toString(),
                ),
              ),
            );
          } else if (isThingsPoll) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ThingsResultScreen(
                  username: username,
                  postId: post['id'].toString(),
                ),
              ),
            );
          }
        } else {
          try {
            final userMap = post['user'] as Map<String, dynamic>? ?? {};
            final mappedJson = {
              'id': post['id'],
              'first_name': userMap['first_name'],
              'last_name': userMap['last_name'],
              'user': userMap['username'],
              'profile_image': userMap['profile_image'],
              'description': post['description'],
              'created_at': post['created_at'],
              'polls': post['polls'],
              'is_liked': post['is_liked_by_current_user'],
              'is_polled_by_current_user': post['is_polled_by_current_user'],
              'location_name': post['location_name'],
              'comments_count': post['comments_count'],
              'likes_count': post['likes_count'],
              'following_status': post['following_status'],
              'shares_count': post['shares_count'],
            };

            final singlePost = SinglePostModel.fromJson(mappedJson);
            if (singlePost.polls.isNotEmpty) {
              if (isImagePoll) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SinglePostImageRanking(
                      post: singlePost,
                      poll: singlePost.polls.first,
                    ),
                  ),
                );
              } else if (isThingsPoll) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SinglePostThingsRanking(
                      post: singlePost,
                      poll: singlePost.polls.first,
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('Error parsing shared post for navigation: $e');
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 12,
          bottom: 12,
          left: message.isSentByMe ? 50.w : 0,
          right: message.isSentByMe ? 0 : 50.w,
        ),
        decoration: BoxDecoration(
          color:
              (message.isSentByMe
                  ? currentTheme?.getOutgoingCardColor(isDarkMode)
                  : currentTheme?.getIncomingCardColor(isDarkMode)) ??
              Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: currentTheme?.id == 'midnight_navy'
                ? const Color(0x339EAFC0)
                : Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
              child: GestureDetector(
                onTap: () {
                  final userId =
                      user['userid'] ?? user['id'] ?? user['user_id'];
                  if (userId != null) {
                    _navigateToPublicProfile(userId.toString(), username);
                  }
                },
                child: Row(
                  children: [
                    _isPolzetAiUsername(username)
                        ? SizedBox(
                            width: 45.w,
                            height: 45.h,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipOval(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 0,
                                        left: 10,
                                        right: 9,
                                      ),
                                      child: Image.asset(
                                        Assets.images.icSplash.path,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Image.asset(
                                    Assets.images.aiFrame.path,
                                    height: 55,
                                    width: 55,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : CircleAvatar(
                            radius: 19,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.1),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : (username.isNotEmpty
                                              ? username[0].toUpperCase()
                                              : 'P'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
                          ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name.isNotEmpty ? name : username,
                                  style: AppTextStyles.sectionHeading.copyWith(
                                    color:
                                        (currentTheme?.id == 'midnight_navy' ||
                                            isDarkMode)
                                        ? Colors.white
                                        : txt.title,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isPolzetAiUsername(username)) ...[
                                SizedBox(width: 4.w),
                                Image.asset(
                                  Assets.images.icVerify.path,
                                  height: 13,
                                  width: 13,
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@$username',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: currentTheme?.id == 'midnight_navy'
                                        ? const Color(0xFF9EAFC0)
                                        : (isDarkMode
                                              ? const Color(0xFFB0B0B0)
                                              : txt.body),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                ' • $timeAgo',
                                style: AppTextStyles.subText.copyWith(
                                  color: currentTheme?.id == 'midnight_navy'
                                      ? const Color(0xFF9EAFC0)
                                      : txt.muted,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              color: currentTheme?.id == 'midnight_navy'
                  ? const Color(0x229EAFC0)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),

            if (pollQuestion.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
                child: Text(
                  pollQuestion,
                  style: AppTextStyles.bodyText.copyWith(
                    color: (currentTheme?.id == 'midnight_navy' || isDarkMode)
                        ? Colors.white
                        : txt.heading,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            if (description.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  10.w,
                  pollQuestion.isNotEmpty ? 4.h : 0,
                  10.w,
                  0,
                ),
                child: Text(
                  description,
                  style: AppTextStyles.bodyText.copyWith(
                    color: (currentTheme?.id == 'midnight_navy' || isDarkMode)
                        ? Colors.white.withOpacity(0.9)
                        : txt.body,
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            if (imageUrls.isNotEmpty) ...[
              SizedBox(height: 10.h),
              _buildStackedImages(imageUrls),
            ] else if (pollTextOptions.isNotEmpty) ...[
              SizedBox(height: 10.h),
              _buildTextPoll(
                context,
                pollTextOptions,
                isSentByMe: message.isSentByMe,
              ),
            ] else ...[
              SizedBox(height: 10.h),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSharedProfileCard(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    final profile = message.sharedProfile!;
    final userId =
        profile['user_id']?.toString() ?? profile['id']?.toString() ?? '';
    final firstName = profile['first_name']?.toString() ?? '';
    final lastName = profile['last_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final username = profile['username']?.toString() ?? '';
    final profileUrlRaw = profile['profile_url']?.toString();
    final avatarUrl = resolveProfileImageUrl(profileUrlRaw);

    final displayName = name.isNotEmpty ? name : username;

    return GestureDetector(
      onTap: () {
        if (userId.isNotEmpty || username.isNotEmpty) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final currentUserId = userProvider.userId?.toString();
          final currentUsername = userProvider.username;
          final isCurrentUser =
              (currentUserId != null &&
                  currentUserId.isNotEmpty &&
                  userId.isNotEmpty &&
                  currentUserId == userId) ||
              (currentUsername != null &&
                  currentUsername.isNotEmpty &&
                  username.isNotEmpty &&
                  currentUsername.toLowerCase() == username.toLowerCase());

          if (isCurrentUser) {
            navigationPush(context, const ProfileScreen());
          } else {
            _navigateToPublicProfile(
              userId.isNotEmpty ? userId : null,
              username.isNotEmpty ? username : null,
            );
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 4.h,
          bottom: 12.h,
          left: message.isSentByMe ? 120.w : 0,
          right: message.isSentByMe ? 0 : 120.w,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color:
              (message.isSentByMe
                  ? currentTheme?.getOutgoingCardColor(isDarkMode)
                  : currentTheme?.getIncomingCardColor(isDarkMode)) ??
              Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: currentTheme?.id == 'midnight_navy'
                ? const Color(0x339EAFC0)
                : Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
        ),
        child: Row(
          children: [
            _isPolzetAiUsername(username)
                ? SizedBox(
                    width: 45.w,
                    height: 45.h,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 0,
                                left: 10,
                                right: 9,
                              ),
                              child: Image.asset(Assets.images.icSplash.path),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Image.asset(
                            Assets.images.aiFrame.path,
                            height: 55,
                            width: 55,
                          ),
                        ),
                      ],
                    ),
                  )
                : CircleAvatar(
                    radius: 21,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.1),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'P',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                  ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: AppTextStyles.sectionHeading.copyWith(
                            color:
                                (currentTheme?.id == 'midnight_navy' ||
                                    isDarkMode)
                                ? Colors.white
                                : Theme.of(context).colorScheme.onBackground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isPolzetAiUsername(username)) ...[
                        SizedBox(width: 4.w),
                        Image.asset(
                          Assets.images.icVerify.path,
                          height: 13,
                          width: 13,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '@$username',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: currentTheme?.id == 'midnight_navy'
                          ? const Color(0xFF9EAFC0)
                          : txt.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedGroupCard(BuildContext context, ChatMessage message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    return SharedGroupCard(
      groupData: message.sharedGroup!,
      isSentByMe: message.isSentByMe,
      currentChatId: widget.chatId?.toString(),
      cardColor: message.isSentByMe
          ? currentTheme?.getOutgoingCardColor(isDarkMode)
          : currentTheme?.getIncomingCardColor(isDarkMode),
    );
  }

  Widget _buildTextPoll(
    BuildContext context,
    List<String> options, {
    bool isSentByMe = false,
  }) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    final isMidnightNavy = currentTheme?.id == 'midnight_navy';

    final pollBgColor = isMidnightNavy
        ? const Color(0xFF9EAFC0)
        : (currentTheme?.getBgColor(isDarkMode) ??
              Theme.of(context).colorScheme.surface);
    final pollBorderColor = isMidnightNavy
        ? const Color(0xFF9EAFC0)
        : (currentTheme?.getUnselectedBorderColor(isDarkMode) ??
              Theme.of(context).colorScheme.outline);
    final textColor = isMidnightNavy
        ? const Color(0xFF0A1523)
        : (isDarkMode ? Colors.white : txt.heading);

    final displayOptions = options.take(2).toList();
    final remainingCount = options.length - displayOptions.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
      child: Row(
        children: [
          ...displayOptions.map((opt) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: pollBgColor,
                  border: Border.all(color: pollBorderColor, width: 1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    fontWeight: isMidnightNavy
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
          if (remainingCount > 0)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: pollBgColor,
                  border: Border.all(color: pollBorderColor, width: 1),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$remainingCount more',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStackedImages(List<String> urls) {
    final displayUrls = urls.take(4).toList();
    final n = displayUrls.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = 140.h;

          final cardWidth = n == 1 ? w : w * 0.55;
          final spacing = n > 1 ? (w - cardWidth) / (n - 1) : 0.0;

          return SizedBox(
            height: h,
            width: w,
            child: Stack(
              children: displayUrls
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    final i = entry.key;
                    final url = entry.value;

                    Widget imageWidget = _buildNetworkImage(url);

                    if (i > 0) {
                      imageWidget = ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                        child: imageWidget,
                      );
                    }

                    return Positioned(
                      left: i * spacing,
                      top: 0,
                      bottom: 0,
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [imageWidget],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList()
                  .reversed
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    final fullUrl = url.startsWith('http')
        ? url
        : '${ApiConfig.baseUrlImage}$url';
    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
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
        final user = member is Map
            ? (member['user'] is Map ? member['user'] as Map : member)
            : null;
        if (user != null) {
          var profileUrl =
              (user['avatar_url'] ??
                      user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['profile_url'] ??
                      user['avatar'])
                  ?.toString();
          if (profileUrl != null &&
              profileUrl.isNotEmpty &&
              profileUrl != 'null') {
            if (!profileUrl.startsWith('http') &&
                !profileUrl.startsWith('assets/') &&
                !profileUrl.startsWith('data:image')) {
              final separator = profileUrl.startsWith('/') ? '' : '/';
              profileUrl = '${ApiConfig.baseUrlImage}$separator$profileUrl';
            }
          } else {
            profileUrl = Assets.images.icAvatar.path;
          }
          final username = user['username']?.toString();
          final name = (user['name'] ?? username ?? 'Unknown').toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
        }
      }
    }

    while (profileUrls.length < 2) {
      profileUrls.add(Assets.images.icAvatar.path);
      initials.add('?');
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
        (profileUrl == null ||
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
                              resolveProfileImageUrl(
                                profileUrl,
                              )!.startsWith('assets/')
                          ? AssetImage(resolveProfileImageUrl(profileUrl)!)
                          : AssetImage(Assets.images.icAvatar.path))));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode
            ? const Color(0xFF252525)
            : Theme.of(context).primaryColor.withOpacity(0.08),
        border: hasBorder
            ? Border.all(
                color:
                    provider.currentTheme?.getBgColor(isDarkMode) ??
                    Theme.of(context).colorScheme.background,
                width: 1.5,
              )
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.05),
                width: 1,
              ),
        image: avatarProvider != null
            ? DecorationImage(image: avatarProvider, fit: BoxFit.cover)
            : DecorationImage(
                image: AssetImage(Assets.images.icAvatar.path),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    final avatarUrl = resolveProfileImageUrl(message.senderProfileImage);
    final avatarProvider = avatarUrl != null ? NetworkImage(avatarUrl) : null;

    final String initial = (message.senderUsername?.isNotEmpty == true)
        ? message.senderUsername![0].toUpperCase()
        : 'P';

    final bubble = Column(
      crossAxisAlignment: message.isSentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: EdgeInsets.only(top: 4.h, bottom: 2.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          decoration: BoxDecoration(
            color: currentTheme != null
                ? (message.isSentByMe
                      ? currentTheme.getOutgoingColor(isDarkMode)
                      : currentTheme.getIncomingColor(isDarkMode))
                : (message.isSentByMe
                      ? Theme.of(context).colorScheme.primary
                      : (isDarkMode
                            ? const Color(0xFF2A2A2E)
                            : const Color(0xFFF3F4F6))),
            borderRadius: BorderRadius.only(
              topLeft: message.isSentByMe
                  ? const Radius.circular(AppRadius.card)
                  : const Radius.circular(0),
              topRight: const Radius.circular(AppRadius.card),
              bottomLeft: const Radius.circular(AppRadius.card),
              bottomRight: message.isSentByMe
                  ? const Radius.circular(0)
                  : const Radius.circular(AppRadius.card),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isSentByMe && message.senderUsername != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: GestureDetector(
                    onTap: () => _navigateToPublicProfile(
                      message.senderId?.toString(),
                      message.senderUsername,
                    ),
                    child: Text(
                      message.senderUsername!,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: _getUsernameColor(message.senderUsername!),
                      ),
                    ),
                  ),
                ),
              _buildMessageText(
                context,
                text: message.text,
                baseStyle: TextStyle(
                  color: message.isSentByMe
                      ? (currentTheme?.getOutgoingMessageTextColor(
                              isDarkMode,
                            ) ??
                            Colors.white)
                      : (currentTheme?.getIncomingMessageTextColor(
                              isDarkMode,
                            ) ??
                            (isDarkMode ? Colors.white : txt.body)),
                  fontSize: 13.6,
                  fontWeight: FontWeight.w400,
                ),
                isSentByMe: message.isSentByMe,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 2.w, right: 2.w, bottom: 4.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.created_at),
                style: TextStyle(
                  fontSize: 9.sp,
                  color:
                      currentTheme?.getMessageTimeColor(isDarkMode) ??
                      (isDarkMode ? const Color(0xBDFFFFFF) : txt.muted),
                ),
              ),
              if (message.isSentByMe) ...[
                SizedBox(width: 3.w),
                _buildMessageStatus(
                  message,
                  statusColor:
                      currentTheme?.getMessageTimeColor(isDarkMode) ??
                      (isDarkMode ? const Color(0xBDFFFFFF) : txt.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final isTextMessage =
        message.sharedPost == null &&
        message.sharedProfile == null &&
        message.sharedGroup == null &&
        message.text.trim().isNotEmpty;

    final messageRow = Align(
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
              child: GestureDetector(
                onTap: () => _navigateToPublicProfile(
                  message.senderId?.toString(),
                  message.senderUsername,
                ),
                child: _isPolzetAiUsername(message.senderUsername)
                    ? SizedBox(
                        width: 42.w,
                        height: 42.h,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 7,
                                    bottom: 0,
                                    left: 9,
                                    right: 8,
                                  ),
                                  child: Image.asset(
                                    Assets.images.icSplash.path,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Image.asset(
                                Assets.images.aiFrame.path,
                                height: 50,
                                width: 50,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CircleAvatar(
                        radius: 17,
                        backgroundColor: _getInitialColor(
                          message.senderUsername ?? 'P',
                        ).withOpacity(0.8),
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
              ),
            ),
            SizedBox(width: 6.w),
          ],
          if (message.sharedPost != null)
            Expanded(
              child: Column(
                crossAxisAlignment: message.isSentByMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSharedPostCard(context, message),
                  if (message.text.isNotEmpty) bubble,
                ],
              ),
            )
          else if (message.sharedProfile != null)
            Expanded(
              child: Column(
                crossAxisAlignment: message.isSentByMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSharedProfileCard(context, message),
                  if (message.text.isNotEmpty) bubble,
                ],
              ),
            )
          else if (message.sharedGroup != null)
            Expanded(
              child: Column(
                crossAxisAlignment: message.isSentByMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSharedGroupCard(context, message),
                  if (message.text.isNotEmpty) bubble,
                ],
              ),
            )
          else
            bubble,
          if (message.isSentByMe) SizedBox(width: 12.w),
        ],
      ),
    );

    if (!isTextMessage) {
      return messageRow;
    }

    final isSelected = _isMessageSelected(message);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        setState(() {
          _selectedMessage = message;
        });
      },
      onTap: _selectedMessage != null
          ? () {
              setState(() {
                if (_isMessageSelected(message)) {
                  _selectedMessage = null;
                } else {
                  _selectedMessage = message;
                }
              });
            }
          : null,
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
            : Colors.transparent,
        child: messageRow,
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
          Icon(
            Icons.error_outline,
            size: 14.sp,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'Failed to load messages. Tap to retry.',
              style: TextStyle(
                fontSize: 10.5.sp,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => provider.fetchMessageHistory(),
            child: Icon(
              Icons.refresh,
              size: 16.sp,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    if (_isAtBottom) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor =
        provider.currentTheme?.getOutgoingColor(isDarkMode) ??
        Theme.of(context).colorScheme.primary;

    return Positioned(
      bottom: 35.h,
      right: 14.w,
      child: GestureDetector(
        onTap: () {
          _scrollToBottom();
          setState(() => _unreadCount = 0);
          context.read<GroupChatProvider>().markAsRead();
        },
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: buttonColor,
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
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final provider = context.watch<GroupChatProvider>();
    final rawAvatar = _avatarUrl;
    final imageBytes = rawAvatar != null ? getProfileImage(rawAvatar) : null;
    final groupAvatarUrl = resolveProfileImageUrl(rawAvatar);
    final ImageProvider? groupAvatarProvider = imageBytes != null
        ? MemoryImage(imageBytes)
        : (groupAvatarUrl != null && groupAvatarUrl.startsWith('http')
              ? NetworkImage(groupAvatarUrl)
              : (groupAvatarUrl != null && groupAvatarUrl.startsWith('assets/')
                    ? AssetImage(groupAvatarUrl)
                    : null));
    final title = provider.groupName ?? widget.groupName ?? 'Chat';

    // We count members based on memberPresence since there's no static members list in the provider
    // Or we could read from widget.chat if available.
    final memberCount =
        widget.chat?['members']?.length ?? provider.memberPresence.length;

    return SafeArea(
      top: false,
      child: PopScope(
        canPop: _selectedMessage == null,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_selectedMessage != null) {
            setState(() {
              _selectedMessage = null;
            });
          }
        },
        child: Scaffold(
          backgroundColor:
              provider.currentTheme?.getBgColor(isDarkMode) ??
              Theme.of(context).colorScheme.background,
          appBar: _selectedMessage != null
              ? AppBar(
                  toolbarHeight: 40.h,
                  automaticallyImplyLeading: false,
                  leadingWidth: double.infinity,
                  backgroundColor:
                      provider.currentTheme?.getBgColor(isDarkMode) ??
                      Theme.of(context).colorScheme.background,
                  surfaceTintColor:
                      provider.currentTheme?.getBgColor(isDarkMode) ??
                      Theme.of(context).colorScheme.background,
                  leading: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 4.w),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 22,
                          color: provider.currentTheme?.id == 'midnight_navy'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onBackground,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedMessage = null;
                          });
                        },
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '1',
                        style: AppTextStyles.bodyText.copyWith(
                          color: provider.currentTheme?.id == 'midnight_navy'
                              ? Colors.white
                              : txt.title,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: provider.currentTheme?.id == 'midnight_navy'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onBackground,
                        ),
                        onPressed: _copySelectedMessage,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 22,
                          color: provider.currentTheme?.id == 'midnight_navy'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onBackground,
                        ),
                        onPressed: _deleteSelectedMessage,
                      ),
                      SizedBox(width: 4.w),
                    ],
                  ),
                )
              : AppBar(
                  toolbarHeight: 40.h,
                  automaticallyImplyLeading: false,
                  leadingWidth: double.infinity,
                  leading: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 12.w),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: provider.currentTheme?.id == 'midnight_navy'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onBackground,
                          size: 24,
                        ),
                      ),
                      groupAvatarProvider != null
                          ? CircleAvatar(
                              key: ValueKey(groupAvatarUrl ?? rawAvatar ?? ''),
                              radius: 18.r,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.1),
                              backgroundImage: groupAvatarProvider,
                            )
                          : _buildGroupAvatarStack(
                              members:
                                  (provider.chat?['members'] ??
                                          widget.chat?['members'] ??
                                          provider.members)
                                      as List?,
                              size: 38.w,
                              isDarkMode: isDarkMode,
                              context: context,
                            ),
                      SizedBox(width: 7.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openChatDetails(title),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    title,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color:
                                          provider.currentTheme?.getTitleColor(
                                            isDarkMode,
                                          ) ??
                                          (provider.currentTheme?.id ==
                                                  'midnight_navy'
                                              ? const Color(0xFFCCCCD0)
                                              : txt.title),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                                                int otherOnlineCount = prov
                                                    .memberPresence
                                                    .values
                                                    .where(
                                                      (m) =>
                                                          m.isOnline &&
                                                          m.userId !=
                                                              prov.currentUserId,
                                                    )
                                                    .length;

                                                int totalOnline =
                                                    otherOnlineCount;

                                                String memberText =
                                                    '$memberCount ${memberCount == 1 ? AppLocalizations.of(context)!.member : AppLocalizations.of(context)!.members}';

                                                if (otherOnlineCount > 0) {
                                                  return Text(
                                                    '$totalOnline ${AppLocalizations.of(context)!.online}',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 9.5.sp,
                                                      fontWeight:
                                                          FontWeight.w300,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  );
                                                } else {
                                                  return ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxWidth: 200.w,
                                                    ),
                                                    child: Text(
                                                      memberText,
                                                      style: AppTextStyles
                                                          .subText
                                                          .copyWith(
                                                            color: txt.muted,
                                                            fontSize: 9.5.sp,
                                                            fontWeight:
                                                                FontWeight.w300,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                      PopupMenuButton<String>(
                        icon: Icon(
                          FeatherIcons.moreVertical,
                          size: 22,
                          color: provider.currentTheme?.id == 'midnight_navy'
                              ? Colors.white
                              : Theme.of(context).colorScheme.onBackground,
                        ),
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        offset: const Offset(0, 45),
                        elevation: 2,
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'group_info') {
                            _openChatDetails(title);
                          } else if (value == 'share') {
                            _shareGroup();
                          } else if (value == 'clear_chat') {
                            _showClearChatConfirmationDialog();
                          } else if (value == 'delete_chat') {
                            _showDeleteChatConfirmationDialog();
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return [
                            PopupMenuItem<String>(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                              height: 38,
                              value: 'group_info',
                              child: Text(
                                AppLocalizations.of(context)!.groupinfo,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: txt.title,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                              height: 38,
                              value: 'share',
                              child: Text(
                                AppLocalizations.of(context)!.share,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: txt.title,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                              height: 38,
                              value: 'clear_chat',
                              child: Text(
                                AppLocalizations.of(context)!.clearchat,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: txt.title,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                              height: 38,
                              value: 'delete_chat',
                              child: Text(
                                AppLocalizations.of(context)!.deletechat,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  backgroundColor:
                      provider.currentTheme?.getBgColor(isDarkMode) ??
                      Theme.of(context).colorScheme.background,
                  surfaceTintColor:
                      provider.currentTheme?.getBgColor(isDarkMode) ??
                      Theme.of(context).colorScheme.background,
                ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_selectedMessage != null) {
                setState(() {
                  _selectedMessage = null;
                });
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: provider.currentTheme?.getBgColor(isDarkMode),
                image:
                    (provider.currentTheme == null ||
                        provider.currentTheme?.id == 'classic_maroon')
                    ? DecorationImage(
                        image: isDarkMode
                            ? AssetImage(Assets.images.bgChatDark.path)
                            : AssetImage(Assets.images.bgChatLight.path),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Column(
                children: [
                  if (provider.historyError != null)
                    _buildHistoryError(provider),
                  Expanded(
                    child: Stack(
                      children: [
                        StreamBuilder<List<ChatMessage>>(
                          stream: _messagesStream,
                          initialData: context
                              .read<GroupChatProvider>()
                              .messages,
                          builder: (context, snapshot) {
                            final messages = snapshot.data ?? [];
                            final isLoading = context
                                .read<GroupChatProvider>()
                                .isLoadingHistory;

                            if (messages.length > _previousMessageCount) {
                              if (_previousMessageCount == 0) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (_isAtBottom ||
                                      (messages.isNotEmpty &&
                                          messages.last.isSentByMe)) {
                                    _scrollToBottom();
                                    context
                                        .read<GroupChatProvider>()
                                        .markAsRead();
                                  }
                                });
                              } else {
                                int newAppendedCount = 0;
                                for (int i = messages.length - 1; i >= 0; i--) {
                                  final m = messages[i];
                                  if (_previousLastMessage != null &&
                                      m.text == _previousLastMessage!.text &&
                                      m.created_at ==
                                          _previousLastMessage!.created_at) {
                                    break;
                                  }
                                  newAppendedCount++;
                                }

                                if (newAppendedCount > 0 &&
                                    newAppendedCount < messages.length) {
                                  final lastIsMe = messages.last.isSentByMe;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_isAtBottom || lastIsMe) {
                                      _scrollToBottom();
                                      context
                                          .read<GroupChatProvider>()
                                          .markAsRead();
                                    } else {
                                      setState(
                                        () => _unreadCount += newAppendedCount,
                                      );
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

                              if (_scrollController.hasClients) {
                                final maxScroll =
                                    _scrollController.position.maxScrollExtent;
                                if (maxScroll <= 50 &&
                                    !context
                                        .read<GroupChatProvider>()
                                        .isLoadingHistory) {
                                  context
                                      .read<GroupChatProvider>()
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
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12.5,
                                    color: txt.muted,
                                    fontWeight: FontWeight.w500,
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
                                  final previousMessage =
                                      reversedMessages[index + 1];
                                  showHeader = !_isSameDay(
                                    message.created_at,
                                    previousMessage.created_at,
                                  );
                                }

                                if (showHeader) {
                                  final dateStr = _getDateSeparator(
                                    message.created_at,
                                  );
                                  if (!_headerKeys.containsKey(dateStr)) {
                                    _headerKeys[dateStr] = GlobalKey(
                                      debugLabel: dateStr,
                                    );
                                  }

                                  bool hideInlineDate =
                                      isAbsoluteOldestMessage &&
                                      context
                                          .read<GroupChatProvider>()
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
                                        margin: EdgeInsets.symmetric(
                                          vertical: 10.h,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 3.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              provider.currentTheme
                                                  ?.getDateColor(isDarkMode) ??
                                              (isDarkMode
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer
                                                  : const Color(0xFFF2F2F2)),
                                          borderRadius: BorderRadius.circular(
                                            5.r,
                                          ),
                                        ),
                                        child: Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                provider.currentTheme?.id ==
                                                    'midnight_navy'
                                                ? Colors.white
                                                : txt.body,
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      provider.currentTheme?.getDateColor(
                                        isDarkMode,
                                      ) ??
                                      (isDarkMode
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer
                                          : const Color(0xFFF2F2F2)),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  _floatingDate ?? '',
                                  style: TextStyle(
                                    color:
                                        provider.currentTheme?.id ==
                                            'midnight_navy'
                                        ? Colors.white
                                        : txt.title,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 9.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(5, 5, 5, 15).w,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            onChanged: (_) => context
                                .read<GroupChatProvider>()
                                .onUserTyping(),
                            cursorColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.8),
                            cursorWidth: 1.5,
                            maxLines: 5,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor:
                                  provider.currentTheme?.getMessageBarColor(
                                    isDarkMode,
                                  ) ??
                                  Theme.of(context).colorScheme.background,
                              border: InputBorder.none,
                              hintText:
                                  '${AppLocalizations.of(context)?.message}...',
                              hintStyle: AppTextStyles.bodyText.copyWith(
                                color: const Color(0XFF898989),
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      provider.currentTheme?.id ==
                                          'midnight_navy'
                                      ? const Color(0x80636363)
                                      : (isDarkMode
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outline
                                            : const Color(0xFFDDDDDD)),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      provider.currentTheme?.id ==
                                          'midnight_navy'
                                      ? const Color(0x80636363)
                                      : (isDarkMode
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outline
                                            : const Color(0xFFDDDDDD)),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                            ),
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.title,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            height: 45,
                            width: 45,
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.fromLTRB(8, 6, 9, 4).w,
                            decoration: BoxDecoration(
                              color:
                                  provider.currentTheme?.getOutgoingColor(
                                    isDarkMode,
                                  ) ??
                                  Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Image.asset(Assets.images.icSend.path),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _shareGroup() {
    final provider = context.read<GroupChatProvider>();
    final chatMap = provider.chat ?? widget.chat;
    final slug = chatMap?['slug']?.toString();
    final groupId = (chatMap?['id'] ?? widget.chatId)?.toString() ?? '';

    if (slug != null && slug.isNotEmpty) {
      ShareService.shareGroup(
        slug: slug,
        groupId: groupId,
        context: context,
        groupName:
            widget.groupName ??
            chatMap?['title'] ??
            chatMap?['display_name'] ??
            '',
      );
    } else {
      showToast(message: 'Group share link unavailable');
    }
  }
}
