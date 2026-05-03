// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../api/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_radius.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/group_chat_provider.dart';
import '../../../provider/private_chat_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import 'chat/group/group_chat_screen.dart';
import 'chat/private/private_chat_screen.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList>
    with UtilityMixin, SingleTickerProviderStateMixin {
  final _apiServices = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  static List<Map<String, dynamic>> _staticChats = [];
  static final Map<String, Uint8List> _staticImageCache = {};
  static bool _everFetched = false;
  static final ValueNotifier<int> unreadMessageCount = ValueNotifier<int>(0);

  static final StreamController<List<Map<String, dynamic>>>
  _globalStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static Timer? _globalPollingTimer;

  String _searchQuery = '';

  // ── Tab filtering ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterByTab(List<Map<String, dynamic>> chats) {
    if (_tabController.index == 0) {
      return chats
          .where((c) => c['chat_type']?.toString() == 'private')
          .toList();
    } else {
      return chats.where((c) => c['chat_type']?.toString() == 'group').toList();
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> chats) {
    final tabFiltered = _filterByTab(chats);
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return tabFiltered;
    return tabFiltered.where((chat) {
      final title = _chatTitle(chat).toLowerCase();
      final last = _lastMessage(chat).toLowerCase();
      return title.contains(q) || last.contains(q);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _globalStreamController.add(_staticChats);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

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

    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {})); // rebuild on tab switch

    if (_staticChats.isNotEmpty) {
      _globalStreamController.add(_staticChats);
    }

    startGlobalPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  static void startGlobalPolling() {
    if (_globalPollingTimer != null) return;
    _fetchAndPushGlobally();
    _globalPollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAndPushGlobally(),
    );
  }

  static void stopGlobalPolling() {
    _globalPollingTimer?.cancel();
    _globalPollingTimer = null;
  }

  static Future<void> _fetchAndPushGlobally() async {
    try {
      final chats = await ApiService().getChatList();
      _everFetched = true;
      if (_listsAreDifferent(_staticChats, chats)) {
        _staticChats = chats;
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
      } else if (_staticChats.isEmpty) {
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
      }
    } catch (_) {
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    }
  }

  static void _updateUnreadCount() {
    int unreadChatCount = 0;
    for (var chat in _staticChats) {
      final unread = (chat['unread_count'] as int?) ?? 0;
      if (unread > 0) unreadChatCount++;
    }
    unreadMessageCount.value = unreadChatCount;
  }

  static bool _listsAreDifferent(
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

  String _formatUnreadCountText(int unread) {
    if (unread > 30) return '30+ new messages';
    if (unread > 25) return '25+ new messages';
    if (unread > 20) return '20+ new messages';
    if (unread > 15) return '15+ new messages';
    if (unread > 10) return '10+ new messages';
    if (unread > 5) return '5+ new messages';
    return '$unread new messages';
  }

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
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
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

    _fetchAndPushGlobally();
  }

  Widget _buildSearchBar() {
    return Container(
      height: AppConstants.searchbarHeight.h,
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.button),
        boxShadow: const [AppConstants.cardShadow],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(right: 12.w, left: 12.w, top: 10.h),
          hintText: AppLocalizations.of(context)!.searchusers,
          hintStyle: AppTextStyles.bodyText.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          ),
          border: InputBorder.none,
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
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: AppColors.primaryColor,
              width: 0.7,
            ),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        style: AppTextStyles.bodyText.copyWith(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildTabLabel(String label, int unreadCount) {
    return Tab(
      child: Stack(
        clipBehavior: Clip.none,

        children: [
          Text(label),
          if (unreadCount > 0) ...[
            Positioned(
              right: -18,
              top: -3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFB82B53),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.background,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    unreadCount.toString(),
                    style: AppTextStyles.subText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared list builder used by both tabs ─────────────────────────────────

  Widget _buildChatList(List<Map<String, dynamic>> chats) {
    return RefreshIndicator(
      onRefresh: _fetchAndPushGlobally,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: chats.length,
        itemBuilder: (context, i) {
          final chat = chats[i];
          final avatarUrl = _avatarUrl(chat);
          final imageBytes = _getCachedImage(avatarUrl);
          final title = _chatTitle(chat);
          final unread = _unreadCount(chat);

          return ListTile(
            onTap: () => _openChat(chat, title, avatarUrl),
            contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: chat['chat_type'] == 'group'
                      ? Colors.blueGrey[600]
                      : Colors.grey[700],
                  backgroundImage: imageBytes != null
                      ? MemoryImage(imageBytes)
                      : null,
                  child: imageBytes == null
                      ? Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?',
                          style: AppTextStyles.subText.copyWith(
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
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.background,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              title,
              style: AppTextStyles.cardTitle.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 12.sp,
              ),
            ),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    unread > 1
                        ? _formatUnreadCountText(unread)
                        : _lastMessage(chat),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subText.copyWith(
                      color: unread > 0
                          ? Theme.of(context).colorScheme.onBackground
                          : Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.6),
                      fontWeight: unread > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '  · ${_formattedTime(chat)}',
                  style: AppTextStyles.subText.copyWith(
                    color: const Color(0XFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBody(List<Map<String, dynamic>> allChats) {
    final chats = _applyFilter(allChats);

    if (allChats.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.nochaseyet,
          style: AppTextStyles.subText.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
      );
    }

    if (chats.isEmpty && _searchQuery.trim().isNotEmpty) {
      return Center(
        child: Text(
          '${AppLocalizations.of(context)!.searchusers} "$_searchQuery"',
          style: AppTextStyles.subText.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
      );
    }

    if (chats.isEmpty) {
      final label = _tabController.index == 0
          ? 'No chats yet'
          : 'No groups yet';
      return Center(
        child: Text(
          label,
          style: AppTextStyles.subText.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
      );
    }

    return _buildChatList(chats);
  }

  int get _unreadChatsCount {
    return _staticChats
        .where(
          (c) =>
              c['chat_type']?.toString() == 'private' &&
              ((c['unread_count'] as int?) ?? 0) > 0,
        )
        .length;
  }

  int get _unreadGroupsCount {
    return _staticChats
        .where(
          (c) =>
              c['chat_type']?.toString() == 'group' &&
              ((c['unread_count'] as int?) ?? 0) > 0,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _globalStreamController.stream,
        initialData: _staticChats,
        builder: (context, snapshot) {
          final allChats = snapshot.data ?? [];

          if (allChats.isEmpty && !_everFetched) {
            return Center(
              child: Loader(color: Theme.of(context).colorScheme.primary),
            );
          }

          return Column(
            children: [
              // _buildSearchBar(),

              // ── Tab bar ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Theme.of(context).colorScheme.onBackground,
                  labelStyle: AppTextStyles.bodyText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  dividerColor: Colors.transparent,
                  indicator: FadeUnderlineTabIndicator(),
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  unselectedLabelColor: const Color(0XFF8E8E8E),
                  tabs: [
                    _buildTabLabel('Chats', _unreadChatsCount),
                    _buildTabLabel('Groups', _unreadGroupsCount),
                  ],
                ),
              ),

              // ── Tab content ───────────────────────────────────────────
              Expanded(child: _buildTabBody(allChats)),
            ],
          );
        },
      ),
    );
  }
}
