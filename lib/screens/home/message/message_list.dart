// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/group/create_group.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../api/services/api_service.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/group_chat_provider.dart';
import '../../../provider/private_chat_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/custom_text_styles.dart';
import 'chat/group/group_chat_screen.dart';
import 'chat/private/private_chat_screen.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with UtilityMixin {
  final _apiServices = ApiService();

  final _chatStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  List<Map<String, dynamic>> _cachedChats = [];
  Timer? _pollingTimer;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndPush();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAndPush(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _chatStreamController.close();
    super.dispose();
  }

  Future<void> _fetchAndPush() async {
    try {
      final chats = await _apiServices.getChatList();
      if (!mounted) return;
      _cachedChats = chats;
      _chatStreamController.add(chats);
    } catch (e) {
      if (!mounted) return;
      _chatStreamController.add(_cachedChats);
    } finally {
      if (mounted && _initialLoading) {
        setState(() => _initialLoading = false);
      }
    }
  }

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

  int _unreadCount(Map<String, dynamic> chat) =>
      (chat['unread_count'] as int?) ?? 0;

  Future<void> _openChat(
    Map<String, dynamic> chat,
    String title,
    String? avatarUrl,
  ) async {
    final chatId = chat['id'] as int?;

    // Optimistically reset unread count locally
    if (chatId != null && _unreadCount(chat) > 0) {
      final index = _cachedChats.indexWhere((c) => c['id'] == chatId);
      if (index != -1) {
        setState(() {
          _cachedChats[index] = {..._cachedChats[index], 'unread_count': 0};
        });
        _chatStreamController.add(_cachedChats);

        // Call API in background
        _apiServices.markChatAsRead(chatId: chatId);
      }
    }

    final chatType = chat['chat_type']?.toString();

    if (chatType == 'group') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => GroupChatProvider(
              chatId: chatId,
              chatName: title,
              chat: chat,
              members: List<Map<String, dynamic>>.from(
                (chat['members'] as List? ?? []).map(
                  (m) => Map<String, dynamic>.from(m as Map),
                ),
              ),
            ),
            child: GroupChatScreen(
              groupName: title,
              chat: chat,
              chatId: chatId,
            ),
          ),
        ),
      ).then((_) => _fetchAndPush());
    } else {
      final currentUsername = Provider.of<UserProvider>(
        context,
        listen: false,
      ).username;

      Navigator.push(
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
              memberName: title,
              profileUrl: avatarUrl,
              chatId: chatId,
            ),
          ),
        ),
      ).then((_) => _fetchAndPush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        title: Text(
          AppLocalizations.of(context)!.messages,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateGroup()),
            ).then((_) => _fetchAndPush()),

            child: Container(
              margin: EdgeInsets.only(right: 10.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 94, 167, 75),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 17.sp, color: Colors.white),
                  SizedBox(width: 3.w),
                  Text(
                    'New Group',
                    style: TextStyle(fontSize: 10.sp, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatStreamController.stream,
              initialData: _cachedChats,
              builder: (context, snapshot) {
                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: CustomTextStyles.lblSecondryText(context),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _fetchAndPush,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final avatarUrl = _avatarUrl(chat);
                      final imageBytes = avatarUrl != null
                          ? getProfileImage(avatarUrl)
                          : null;
                      final title = _chatTitle(chat);
                      final unread = _unreadCount(chat);

                      return ListTile(
                        onTap: () => _openChat(chat, title, avatarUrl),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[700],
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
                        title: Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
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
                                ? Theme.of(context).colorScheme.onBackground
                                : Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.6),
                            fontSize: 10.8.sp,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                                padding: const EdgeInsets.all(5).w,
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
                );
              },
            ),
    );
  }
}
