// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../api/services/api_service.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/group_chat_provider.dart';
import '../../../provider/private_chat_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/loader.dart';
import 'chat/group/group_chat_screen.dart';
import 'chat/private/private_chat_screen.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList> with UtilityMixin {
  final _apiServices = ApiService();
  final TextEditingController _searchController = TextEditingController();

  // ── Static cache ──────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _staticChats = [];
  static final Map<String, Uint8List> _staticImageCache = {};
  static bool _everFetched = false;

  // ── Local state ───────────────────────────────────────────────────────────
  final _streamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  String _searchQuery = '';
  Timer? _pollingTimer;

  // ── Filtered view of _staticChats ─────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> chats) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return chats.where((chat) {
      final title = _chatTitle(chat).toLowerCase();
      final last = _lastMessage(chat).toLowerCase();
      return title.contains(q) || last.contains(q);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    // Re-emit current cached chats so StreamBuilder rebuilds with filter applied
    _streamController.add(_staticChats);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  // ── Image cache ───────────────────────────────────────────────────────────
  Uint8List? _getCachedImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    if (_staticImageCache.containsKey(avatarUrl)) {
      return _staticImageCache[avatarUrl];
    }
    final bytes = getProfileImage(avatarUrl);
    if (bytes != null) _staticImageCache[avatarUrl] = bytes;
    return bytes;
  }

  @override
  void initState() {
    super.initState();

    if (_staticChats.isNotEmpty) {
      _streamController.add(_staticChats);
    }

    _fetchAndPush();

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAndPush(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _streamController.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPush() async {
    try {
      final chats = await _apiServices.getChatList();
      if (!mounted) return;

      _everFetched = true;

      if (_listsAreDifferent(_staticChats, chats)) {
        _staticChats = chats;
        _streamController.add(_staticChats);
      } else if (_staticChats.isEmpty) {
        _streamController.add(_staticChats);
      }
    } catch (_) {
      if (!mounted) return;
      _streamController.add(_staticChats);
    }
  }

  bool _listsAreDifferent(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] ||
          a[i]['unread_count'] != b[i]['unread_count'] ||
          a[i]['updated_at'] != b[i]['updated_at']) {
        return true;
      }
    }
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _chatTitle(Map<String, dynamic> chat) {
    if (chat['title'] != null && (chat['title'] as String).trim().isNotEmpty) {
      return chat['title'] as String;
    }
    final currentUserId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).userId;
    final members = chat['members'] as List?;
    if (members != null && members.length > 1) {
      for (final m in members) {
        final user =
            (m as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
        final id = user?['id'];
        if (id != null && id != currentUserId) {
          return user?['username']?.toString() ?? 'Unknown';
        }
      }
    }
    if (members != null && members.isNotEmpty) {
      final user =
          (members.first as Map<String, dynamic>)['user']
              as Map<String, dynamic>?;
      return user?['username']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  String _lastMessage(Map<String, dynamic> chat) {
    final lastMessage = chat['last_message'];
    if (lastMessage == null) return 'No message yet';
    if (lastMessage is Map<String, dynamic>) {
      return lastMessage['text']?.toString() ?? 'No message yet';
    }
    return 'No message yet';
  }

  String _formattedTime(Map<String, dynamic> chat) {
    final raw = chat['updated_at']?.toString() ?? '';
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      final weeks = (diff.inDays / 7).floor();
      if (weeks < 52) return '${weeks}w';
      return '${(diff.inDays / 365).floor()}y';
    } catch (_) {
      return '';
    }
  }

  String? _avatarUrl(Map<String, dynamic> chat) {
    final chatType = chat['chat_type']?.toString();
    if (chatType == 'group') {
      final profileUrl = chat['profile_url']?.toString();
      return (profileUrl != null && profileUrl.trim().isNotEmpty)
          ? profileUrl
          : null;
    }
    final currentUserId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).userId;
    final members = chat['members'] as List?;
    if (members == null || members.isEmpty) return null;
    for (final m in members) {
      final user = (m as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      if (user?['id'] != currentUserId) {
        return user?['profile_image']?.toString();
      }
    }
    final user =
        (members.first as Map<String, dynamic>)['user']
            as Map<String, dynamic>?;
    return user?['profile_image']?.toString();
  }

  bool _isOtherMemberOnline(Map<String, dynamic> chat) {
    final currentUserId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).userId;
    final members = chat['members'] as List?;
    if (members == null) return false;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      if (user?['id'] != currentUserId) {
        return (member['is_online'] as bool?) ?? false;
      }
    }
    return false;
  }

  int _unreadCount(Map<String, dynamic> chat) =>
      (chat['unread_count'] as int?) ?? 0;

  bool _isOtherMemberBlocked(Map<String, dynamic> chat) {
    final currentUserId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).userId;
    final members = chat['members'] as List?;
    if (members == null) return false;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      if (user?['id'] != currentUserId) {
        return (member['is_block'] as bool?) ?? false;
      }
    }
    return false;
  }

  int? _getOtherUserId(Map<String, dynamic> chat) {
    final currentUserId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).userId;
    final members = chat['members'] as List?;
    if (members == null) return null;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      if (user?['id'] != currentUserId) return user?['id'] as int?;
    }
    return null;
  }

  // ── Open chat ─────────────────────────────────────────────────────────────
  Future<void> _openChat(
    Map<String, dynamic> chat,
    String title,
    String? avatarUrl,
  ) async {
    final chatId = chat['id'] as int?;
    final isBlocked = _isOtherMemberBlocked(chat);

    if (chatId != null && _unreadCount(chat) > 0) {
      final index = _staticChats.indexWhere((c) => c['id'] == chatId);
      if (index != -1) {
        _staticChats[index] = {..._staticChats[index], 'unread_count': 0};
        _streamController.add(_staticChats);
        _apiServices.markChatAsRead(chatId: chatId);
      }
    }

    final chatType = chat['chat_type']?.toString();

    if (chatType == 'group') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => GroupChatProvider(),
            child: GroupChatScreen(
              groupName: title,
              chat: chat,
              chatId: chatId,
            ),
          ),
        ),
      );
    } else {
      final currentUsername = Provider.of<UserProvider>(
        context,
        listen: false,
      ).username;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => PrivateChatProvider()
              ..init(
                memberName: title,
                profileUrl: avatarUrl,
                chatId: chatId,
                currentUsername: currentUsername,
              ),
            child: PrivateChatScreen(
              userId: _getOtherUserId(chat),
              memberName: title,
              profileUrl: avatarUrl,
              chatId: chatId,
              isUserBlock: isBlocked,
            ),
          ),
        ),
      );
    }

    _fetchAndPush();
  }

  // ── Search bar widget ─────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 33.h,
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C000000),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(
            right: 12.w,
            left: 12.w,
            top: 10.h,
          ),
          hintText: AppLocalizations.of(context)!.searchusers,
          hintStyle: CustomTextStyles.lblPrimaryHintText(context),
          border: InputBorder.none,
          // Show clear button when text is present, search icon when empty
          suffixIcon: _searchQuery.trim().isNotEmpty
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    Icons.close,
                    size: 17.spMax,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                )
              : Icon(
                  FeatherIcons.search,
                  size: 17.spMax,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(13.r),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: AppColors.primaryColor,
              width: 0.7,
            ),
            borderRadius: BorderRadius.circular(13.r),
          ),
        ),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontSize: 13.sp,
          fontWeight: FontWeight.w400,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _streamController.stream,
        initialData: _staticChats,
        builder: (context, snapshot) {
          final allChats = snapshot.data ?? [];

          // Cold launch spinner
          if (allChats.isEmpty && !_everFetched) {
            return Center(
              child: Loader(color: Theme.of(context).colorScheme.primary),
            );
          }

          // Apply search filter
          final chats = _applyFilter(allChats);

          return Column(
            children: [
              // ── Search bar ───────────────────────────────────────────────
              _buildSearchBar(),

              // ── Chat list ────────────────────────────────────────────────
              Expanded(
                child: allChats.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.nochaseyet,
                          style: CustomTextStyles.lblSecondryText(context),
                        ),
                      )
                    : chats.isEmpty
                        ? Center(
                            child: Text(
                              // "No results for '<query>'"
                              '${AppLocalizations.of(context)!.searchusers} "$_searchQuery"',
                              style:
                                  CustomTextStyles.lblSecondryText(context),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchAndPush,
                            child: ListView.builder(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 10.w),
                              itemCount: chats.length,
                              itemBuilder: (context, i) {
                                final chat = chats[i];
                                final avatarUrl = _avatarUrl(chat);
                                final imageBytes =
                                    _getCachedImage(avatarUrl);
                                final title = _chatTitle(chat);
                                final unread = _unreadCount(chat);

                                return ListTile(
                                  onTap: () =>
                                      _openChat(chat, title, avatarUrl),
                                  contentPadding: EdgeInsets.zero,
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            chat['chat_type'] == 'group'
                                                ? Colors.blueGrey[600]
                                                : Colors.grey[700],
                                        backgroundImage: imageBytes != null
                                            ? MemoryImage(imageBytes)
                                            : null,
                                        child: imageBytes == null
                                            ? Text(
                                                title.isNotEmpty
                                                    ? title[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            : null,
                                      ),
                                      if (chat['chat_type'] == 'private' &&
                                          _isOtherMemberOnline(chat))
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 10.w,
                                            height: 10.h,
                                            decoration: BoxDecoration(
                                              color:
                                                  const Color(0xFF4CAF50),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .background,
                                                width: 1.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _lastMessage(chat),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unread > 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                          : Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                              .withOpacity(0.6),
                                      fontSize: 10.8.sp,
                                      fontWeight: unread > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formattedTime(chat),
                                        style: TextStyle(
                                          fontSize: 8.5.sp,
                                          color: const Color(0XFF999999),
                                        ),
                                      ),
                                      if (unread > 0) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding:
                                              const EdgeInsets.all(5).w,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$unread',
                                            style: TextStyle(
                                              fontSize: 8.sp,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}