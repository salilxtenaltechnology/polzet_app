// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:polzet_app/gen/assets.gen.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../api/api_config.dart';
import '../../../../../api/api_service.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/message/message_model.dart';
import '../../../../../models/posts/single_post_model.dart';
import '../../../../../provider/private_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/button/back_button.dart';
import '../../../../../widgets/show_toast.dart';
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../../search/posts/rank/single_post_image_ranking.dart';
import '../../../search/posts/rank/single_post_things_ranking.dart';
import '../../../profile/profile_screen.dart';
import '../../../profile/public/public_profile_screen.dart';
import '../../../search/posts/single_post_details.dart';
import 'info/private_user_info.dart';
import '../../../../../widgets/card/shared_group_card.dart';
import '../../../../../widgets/dialog/custom_diolog.dart';
import '../../message_list.dart';

class PrivateChatScreen extends StatefulWidget {
  final String? memberName;
  final String? username;
  final String? profileUrl;
  final dynamic userId;
  final dynamic chatId;
  final bool isUserBlock;
  final Map<String, dynamic>? chat;
  final dynamic chatTheme;

  const PrivateChatScreen({
    super.key,
    required this.memberName,
    this.username,
    required this.profileUrl,
    required this.userId,
    this.chatId,
    this.isUserBlock = false,
    this.chat,
    this.chatTheme,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with UtilityMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;
  bool _isPolzetAiUsername(String? username) {
    if (username == null) return false;
    final u = username.trim().toLowerCase();
    return u == 'polzet_ai' || u == 'polet_ai';
  }

  bool _isPolzetAiChat() {
    if (_isPolzetAiUsername(widget.username)) return true;
    if (_isPolzetAiUsername(widget.memberName)) return true;
    if (widget.chat != null) {
      final title = widget.chat!['title']?.toString();
      if (_isPolzetAiUsername(title)) return true;
      final displayName = widget.chat!['display_name']?.toString();
      if (_isPolzetAiUsername(displayName)) return true;
    }
    return false;
  }

  late bool _isUserBlock;

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
          messageToDelete.chatId ??
          _resolvedChatId ??
          widget.chatId ??
          provider.chatId;

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

      // If chatId is still missing and we have userId, resolve chatId
      if (chatId == null && widget.userId != null) {
        try {
          final chatResponse = await _apiService.createPrivateChatId(
            withUserId: widget.userId.toString(),
          );
          chatId = chatResponse['id']?.toString();
          _resolvedChatId = chatId;
        } catch (e) {
          debugPrint('Error creating/fetching chat id: $e');
        }
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
          debugPrint('Error refreshing history for message ID: $e');
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
        debugPrint('❌ Failed to delete message: $e');
        showToast(message: e.toString().replaceAll('Exception: ', ''));
      }
    });
  }

  int _previousMessageCount = 0;
  ChatMessage? _previousLastMessage;
  bool _isAtBottom = true;
  int _unreadCount = 0;

  String? _floatingDate;
  final Map<String, GlobalKey> _headerKeys = {};

  dynamic _resolvedChatId;
  bool _isLoadingChatId = false;
  final ApiService _apiService = ApiService();

  PrivateChatProvider get provider => context.read<PrivateChatProvider>();

  @override
  void initState() {
    super.initState();

    debugPrint('Chat Theme : ${widget.chatTheme}');
    WidgetsBinding.instance.addObserver(this);
    _isUserBlock = widget.isUserBlock;
    _resolvedChatId =
        (widget.chatId == 0 || widget.chatId == '0' || widget.chatId == null)
        ? null
        : widget.chatId;

    _messagesStream = provider.messagesStream;

    debugPrint('User id : ${widget.userId}');
    debugPrint('Chat id : ${widget.chatId}');

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  Future<void> _initChat() async {
    final userProvider = context.read<UserProvider>();

    if (_resolvedChatId == null && widget.userId != null) {
      if (mounted) {
        setState(() {
          _isLoadingChatId = true;
        });
      }
      try {
        final chatResponse = await _apiService.createPrivateChatId(
          withUserId: widget.userId.toString(),
        );
        final parsedChatId = chatResponse['id']?.toString();
        if (mounted) {
          setState(() {
            _resolvedChatId = parsedChatId;
          });
        }
      } catch (e) {
        debugPrint('Error creating/fetching private chat ID: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingChatId = false;
          });
        }
      }
    }

    bool? isMuted;
    if (widget.chat != null) {
      final muted =
          widget.chat!['is_muted'] ??
          widget.chat!['is_mute'] ??
          widget.chat!['isMuted'];
      if (muted != null) {
        if (muted is bool) {
          isMuted = muted;
        } else if (muted is num) {
          isMuted = muted != 0;
        } else {
          final str = muted.toString().toLowerCase().trim();
          isMuted = str == 'true' || str == '1';
        }
      }
    }

    provider.init(
      memberName: widget.memberName,
      profileUrl: widget.profileUrl,
      chatId: _resolvedChatId,
      currentUsername: userProvider.username,
      isMuted: isMuted,
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

    if (widget.userId != null) {
      provider.setMemberUserId(widget.userId!);
    }
  }

  Map<String, dynamic>? _getOtherMemberUserFromChat(
    Map<String, dynamic>? chat,
  ) {
    if (chat == null) return null;
    final members = chat['members'] as List?;
    if (members == null) return null;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();
      for (final m in members) {
        if (m is Map) {
          final user =
              m['user'] as Map<String, dynamic>? ??
              (m is Map<String, dynamic> && m.containsKey('username')
                  ? m
                  : null);
          if (user != null) {
            final username = user['username']?.toString().toLowerCase();
            final id = (user['uuid'] ?? user['id'])?.toString();
            if (id != currentUserId &&
                (currentUsername == null || username != currentUsername)) {
              return user;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String get _resolvedMemberName {
    final otherUser = _getOtherMemberUserFromChat(widget.chat);
    if (otherUser != null) {
      final name =
          otherUser['name']?.toString() ??
          (otherUser['first_name'] != null
              ? '${otherUser['first_name']} ${otherUser['last_name'] ?? ''}'
                    .trim()
              : null) ??
          otherUser['full_name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    if (widget.memberName != null &&
        widget.memberName!.trim().isNotEmpty &&
        widget.memberName != widget.username) {
      return widget.memberName!;
    }
    final title =
        widget.chat?['title']?.toString() ??
        widget.chat?['display_name']?.toString();
    if (title != null && title.trim().isNotEmpty && title != widget.username) {
      return title;
    }
    if (widget.memberName != null && widget.memberName!.trim().isNotEmpty) {
      return widget.memberName!;
    }
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username!;
    }
    return 'Polzet User';
  }

  String? get _resolvedUsername {
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username;
    }
    final otherUser = _getOtherMemberUserFromChat(widget.chat);
    final u =
        otherUser?['username']?.toString() ??
        widget.chat?['username']?.toString();
    if (u != null && u.trim().isNotEmpty) return u;
    return null;
  }

  dynamic get _resolvedUserId {
    if (widget.userId != null) return widget.userId;
    final otherUser = _getOtherMemberUserFromChat(widget.chat);
    final id = otherUser?['uuid'] ?? otherUser?['id'];
    if (id != null) return id;
    return null;
  }

  Future<void> _loadMoreHistory() async {
    if (!provider.hasMoreHistory || provider.isLoadingHistory) return;
    await provider.fetchMoreHistory();
  }

  Future<void> _openChatDetails() async {
    final pp = context.read<PrivateChatProvider>();
    final updatedBlock = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: pp,
          child: PrivateUserInfo(
            userId: _resolvedUserId,
            name: _resolvedMemberName,
            username: _resolvedUsername,
            profileUrl: widget.profileUrl,
            chatId: _resolvedChatId ?? widget.chatId,
            chat: widget.chat,
            isUserBlock: _isUserBlock,
            privateChatProvider: pp,
          ),
        ),
      ),
    );
    if (mounted && updatedBlock != null) {
      setState(() => _isUserBlock = updatedBlock);
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
    final chatId = _resolvedChatId?.toString() ?? widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) return;
    try {
      final response = await _apiService.deleteChat(chatId: chatId);
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
    final chatId = _resolvedChatId?.toString() ?? widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) {
      showToast(message: 'Cannot clear a new chat');
      return;
    }

    // Instantly remove messages locally for immediate response
    provider.clearLocalMessages();
    MessageListState.clearChatLocally(chatId);

    try {
      showToast(message: 'Clearing chat...');
      final response = await _apiService.clearChat(chatId: chatId);
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
    } else if (difference > 1 && difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('d MMMM yyyy').format(date);
    }
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
            navigationPush(
              context,
              PublicProfileScreen(username: profileUsername),
            );
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

  // ── Message status icon (pending / failed / sent / read) ──────────────────────────
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
        size: 11.sp,
        color: statusColor ?? fallbackColor,
      );
    }
    if (message.isRead) {
      return Icon(
        Icons.done_all,
        size: 11.sp,
        color: statusColor ?? Colors.blue,
      );
    }
    // Sent (delivered)
    return Icon(
      Icons.done_all,
      size: 11.sp,
      color: statusColor ?? fallbackColor,
    );
  }

  // ── Shared Post Card ───────────────────────────────────────────────────────
  Widget _buildSharedPostCard(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    final post = message.sharedPost!;
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
          top: 4.h,
          bottom: 12,
          left: message.isSentByMe ? 40.w : 12.w,
          right: message.isSentByMe ? 12.w : 40.w,
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
                    navigationPush(
                      context,
                      PublicProfileScreen(
                        userId: userId.toString(),
                        username: username,
                      ),
                    );
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
                                ? Image.asset(Assets.images.icAvatar.path)
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
                                    color: (currentTheme?.id == 'midnight_navy' || isDarkMode)
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
            navigationPush(
              context,
              PublicProfileScreen(
                userId: userId.isNotEmpty ? userId : null,
                username: username.isNotEmpty ? username : null,
              ),
            );
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 4.h,
          bottom: 12.h,
          left: message.isSentByMe ? 120.w : 12.w,
          right: message.isSentByMe ? 12.w : 120.w,
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
                        ? Image.asset(Assets.images.icAvatar.path)
                        : null,
                  ),
            SizedBox(width: 10.w),
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
                            color: (currentTheme?.id == 'midnight_navy' || isDarkMode)
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
                  border: Border.all(
                    color: pollBorderColor,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    fontWeight: isMidnightNavy ? FontWeight.w600 : FontWeight.w500,
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
                  border: Border.all(
                    color: pollBorderColor,
                    width: 1,
                  ),
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
                            children: [
                              imageWidget,
                              // Positioned(
                              //   top: 8,
                              //   right: 8,
                              //   child: Container(
                              //     height: 28,
                              //     width: 28,
                              //     decoration: BoxDecoration(
                              //       shape: BoxShape.circle,
                              //       color: Theme.of(context).colorScheme.primary,
                              //       border: Border.all(
                              //         color: Colors.white,
                              //         width: 1,
                              //       ),
                              //     ),
                              //     child: Center(
                              //       child: Text(
                              //         '${i + 1}',
                              //         style: AppTextStyles.subText.copyWith(
                              //           fontSize: 12,
                              //           fontWeight: FontWeight.w600,
                              //           color: Colors.white,
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
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

  // ── Message bubble ─────────────────────────────────────────────────────────
  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = provider.currentTheme;
    final bubble = Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 4.h,
              bottom: 2.h,
              left: 12.w,
              right: 12.w,
            ),
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.2.h),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
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
            child: _buildMessageText(
              context,
              text: message.text,
              baseStyle: AppTextStyles.bodyText.copyWith(
                color: message.isSentByMe ? Colors.white : txt.body,
                fontSize: 13.6,
                fontWeight: FontWeight.w400,
              ),
              isSentByMe: message.isSentByMe,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 4.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.created_at),
                  style: TextStyle(
                    fontSize: 8.4.sp,
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
      ),
    );

    final isTextMessage =
        message.sharedPost == null &&
        message.sharedProfile == null &&
        message.sharedGroup == null &&
        message.text.trim().isNotEmpty;

    if (message.sharedPost != null) {
      return Column(
        crossAxisAlignment: message.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildSharedPostCard(context, message),
          if (message.text.isNotEmpty) bubble,
        ],
      );
    }

    if (message.sharedProfile != null) {
      return Column(
        crossAxisAlignment: message.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildSharedProfileCard(context, message),
          if (message.text.isNotEmpty) bubble,
        ],
      );
    }

    if (message.sharedGroup != null) {
      return Column(
        crossAxisAlignment: message.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildSharedGroupCard(context, message),
          if (message.text.isNotEmpty) bubble,
        ],
      );
    }

    if (!isTextMessage) {
      return bubble;
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
        child: bubble,
      ),
    );
  }

  // ── Top loader for pagination ──────────────────────────────────────────────
  Widget _buildHistoryLoader(bool isLoading) {
    if (!isLoading) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  // ── Scroll-to-bottom FAB with unread badge ─────────────────────────────────
  Widget _buildScrollToBottomButton() {
    if (_isAtBottom) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = provider.currentTheme?.getOutgoingColor(isDarkMode) ??
        Theme.of(context).colorScheme.primary;

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
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<PrivateChatProvider>();

    final avatarUrl = resolveProfileImageUrl(widget.profileUrl);
    final avatarProvider = avatarUrl != null ? NetworkImage(avatarUrl) : null;

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
                          color: Theme.of(context).colorScheme.onBackground,
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
                          color: txt.title,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        onPressed: _copySelectedMessage,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 22,
                          color: Theme.of(context).colorScheme.onBackground,
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
                  backgroundColor:
                      provider.currentTheme?.getBgColor(isDarkMode) ??
                      Theme.of(context).colorScheme.background,
                  surfaceTintColor:
                      provider.currentTheme?.getBgColor(isDarkMode) ??
                      Theme.of(context).colorScheme.background,
                  leading: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 12.w),
                      const PrimaryBackButton(),
                      _isPolzetAiChat()
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
                                          top: 11,
                                          bottom: 6,
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
                          : Stack(
                              children: [
                                CircleAvatar(
                                  radius: 19,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.1),
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? Image.asset(Assets.images.icAvatar.path)
                                      : null,
                                ),
                                // Green dot when member is online
                                Consumer<PrivateChatProvider>(
                                  builder: (_, p, __) {
                                    if (!p.isMemberOnline) {
                                      return const SizedBox.shrink();
                                    }
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.background,
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
                        onTap: _openChatDetails,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _resolvedMemberName,
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: provider.currentTheme?.getTitleColor(isDarkMode) ??
                                        (provider.currentTheme?.id == 'midnight_navy'
                                            ? const Color(0xFFCCCCD0)
                                            : txt.title),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_isPolzetAiChat()) ...[
                                  SizedBox(width: 4.w),
                                  Image.asset(
                                    Assets.images.icVerify.path,
                                    height: 13,
                                    width: 13,
                                  ),
                                ],
                              ],
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
                                              p.isMemberOnline
                                                  ? AppLocalizations.of(
                                                      context,
                                                    )!.online
                                                  : AppLocalizations.of(
                                                      context,
                                                    )!.offline,
                                              style: AppTextStyles.subText
                                                  .copyWith(
                                                    color: p.isMemberOnline
                                                        ? Colors.green
                                                        : Colors.grey,
                                                    fontSize: 9.5.sp,
                                                    fontWeight: FontWeight.w400,
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
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: Icon(
                          FeatherIcons.moreVertical,
                          size: 22,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        offset: const Offset(0, 45),
                        elevation: 2,
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'user_info') {
                            _openChatDetails();
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
                              value: 'user_info',
                              child: Text(
                                'User info',
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
              child: _isLoadingChatId
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Column(
                      children: [
                        // ── Connection banner ──────────────────────────────────────────────
                        // _buildConnectionBanner(provider),

                        // ── History error banner ───────────────────────────────────────────
                        if (provider.historyError != null)
                          Container(
                            width: double.infinity,

                            padding: EdgeInsets.symmetric(
                              vertical: 6.h,
                              horizontal: 12.w,
                            ),

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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
                          ),

                        // ── Message list ───────────────────────────────────────────────────
                        Expanded(
                          child: Stack(
                            children: [
                              StreamBuilder<List<ChatMessage>>(
                                stream: _messagesStream,
                                initialData: context
                                    .read<PrivateChatProvider>()
                                    .messages,
                                builder: (context, snapshot) {
                                  final messages = snapshot.data ?? [];
                                  final isLoading = context
                                      .read<PrivateChatProvider>()
                                      .isLoadingHistory;

                                  // Auto-scroll logic
                                  if (messages.length > _previousMessageCount) {
                                    if (_previousMessageCount == 0) {
                                      // First load!
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (_isAtBottom ||
                                                (messages.isNotEmpty &&
                                                    messages.last.isSentByMe)) {
                                              _scrollToBottom();
                                              context
                                                  .read<PrivateChatProvider>()
                                                  .markAsRead();
                                            }
                                          });
                                    } else {
                                      // Find how many new messages were newly added to the end (new incoming messages)
                                      int newAppendedCount = 0;
                                      for (
                                        int i = messages.length - 1;
                                        i >= 0;
                                        i--
                                      ) {
                                        final m = messages[i];
                                        if (_previousLastMessage != null &&
                                            m.text ==
                                                _previousLastMessage!.text &&
                                            m.created_at ==
                                                _previousLastMessage!
                                                    .created_at) {
                                          break; // found the old boundary
                                        }
                                        newAppendedCount++;
                                      }

                                      // If messages were added at the end, trigger badge / scroll
                                      // Note: If newAppendedCount == 0, it means it was an older history fetch at the top, so we ignore it completely!
                                      if (newAppendedCount > 0 &&
                                          newAppendedCount < messages.length) {
                                        final lastIsMe =
                                            messages.last.isSentByMe;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (_isAtBottom || lastIsMe) {
                                                _scrollToBottom();
                                                context
                                                    .read<PrivateChatProvider>()
                                                    .markAsRead();
                                              } else {
                                                setState(
                                                  () => _unreadCount +=
                                                      newAppendedCount,
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

                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    _updateFloatingDate();

                                    // Auto-fetch more history if the layout is underfilled (e.g., large screen or few messages)
                                    if (_scrollController.hasClients) {
                                      final maxScroll = _scrollController
                                          .position
                                          .maxScrollExtent;
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
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 12.5,
                                          color: txt.muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }

                                  final reversedMessages = messages.reversed
                                      .toList();
                                  return ListView.builder(
                                    reverse: true,
                                    controller: _scrollController,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.h,
                                    ),
                                    itemCount: reversedMessages.length + 1,
                                    itemBuilder: (ctx, index) {
                                      if (index == reversedMessages.length) {
                                        return _buildHistoryLoader(isLoading);
                                      }

                                      final message = reversedMessages[index];
                                      bool showHeader = false;
                                      bool isAbsoluteOldestMessage = false;

                                      if (index ==
                                          reversedMessages.length - 1) {
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
                                                        ?.getDateColor(
                                                          isDarkMode,
                                                        ) ??
                                                    (isDarkMode
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .secondaryContainer
                                                        : const Color(
                                                            0xFFF2F2F2,
                                                          )),
                                                borderRadius:
                                                    BorderRadius.circular(5.r),
                                              ),
                                              child: Text(
                                                dateStr,
                                                style: TextStyle(
                                                  fontSize: 9.sp,
                                                  fontWeight: FontWeight.w500,
                                                  color: txt.body,
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
                                      margin: EdgeInsets.symmetric(
                                        vertical: 10.h,
                                      ),
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
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                : const Color(0xFFF2F2F2)),
                                        borderRadius: BorderRadius.circular(
                                          5.r,
                                        ),
                                      ),
                                      child: Text(
                                        _floatingDate ?? '',
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w500,
                                          color: txt.body,
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
                                      .read<PrivateChatProvider>()
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
                                        provider.currentTheme
                                            ?.getMessageBarColor(isDarkMode) ??
                                        Theme.of(
                                          context,
                                        ).colorScheme.background,
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
                                        color: isDarkMode
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outline
                                            : const Color(0xFFDDDDDD),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.card,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outline
                                            : const Color(0xFFDDDDDD),
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
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    6,
                                    9,
                                    4,
                                  ).w,
                                  decoration: BoxDecoration(
                                    color:
                                        provider.currentTheme?.getOutgoingColor(
                                          isDarkMode,
                                        ) ??
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      Assets.images.icSend.path,
                                    ),
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
