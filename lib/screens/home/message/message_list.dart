// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../provider/connection_provider.dart';
import '../../../api/services/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/group_chat_provider.dart';
import '../../../provider/private_chat_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/connection/no_internet_screen.dart';
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
  late final ScrollController _privateScrollController;
  late final ScrollController _groupScrollController;

  static List<Map<String, dynamic>> _staticChats = [];
  static bool _everFetched = false;
  static final ValueNotifier<int> unreadMessageCount = ValueNotifier<int>(0);
  static String? errorMessage;

  static int _currentPage = 1;
  static bool _hasMore = true;
  static bool _isLoadingMore = false;

  static final StreamController<List<Map<String, dynamic>>>
  _globalStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static Timer? _globalPollingTimer;

  String _searchQuery = '';

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> chats,
    String chatType,
  ) {
    final tabFiltered = chats
        .where((c) => c['chat_type']?.toString() == chatType)
        .toList();
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

  ImageProvider? _avatarProvider(String? avatarUrl) {
    final url = resolveProfileImageUrl(avatarUrl);
    if (url == null) return null;
    return NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _privateScrollController = ScrollController()
      ..addListener(_onPrivateScroll);
    _groupScrollController = ScrollController()..addListener(_onGroupScroll);

    if (_staticChats.isNotEmpty) {
      _globalStreamController.add(_staticChats);
    }

    startGlobalPolling();
  }

  void _onPrivateScroll() {
    if (_searchQuery.trim().isNotEmpty) return;
    if (_privateScrollController.position.pixels >=
            _privateScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreChats();
    }
  }

  void _onGroupScroll() {
    if (_searchQuery.trim().isNotEmpty) return;
    if (_groupScrollController.position.pixels >=
            _groupScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreChats();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _privateScrollController.dispose();
    _groupScrollController.dispose();
    super.dispose();
  }

  static const String _chatsCacheKey = 'cached_chats';

  static Future<void> _loadChatsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_chatsCacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        final decoded = json.decode(cachedData);
        if (decoded is List) {
          _staticChats = List<Map<String, dynamic>>.from(
            decoded.map((item) => Map<String, dynamic>.from(item as Map)),
          );
          _updateUnreadCount();
          _globalStreamController.add(_staticChats);
        }
      }
    } catch (e) {
      debugPrint('Error loading chats from cache: $e');
    }
  }

  static Future<void> _saveChatsToCache(
    List<Map<String, dynamic>> chats,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatsCacheKey, json.encode(chats));
    } catch (e) {
      debugPrint('Error saving chats to cache: $e');
    }
  }

  static void startGlobalPolling() {
    if (_globalPollingTimer != null) return;
    _loadChatsFromCache().then((_) {
      _fetchAndPushGlobally();
    });
    _globalPollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAndPushGlobally(),
    );
  }

  static void stopGlobalPolling() {
    _globalPollingTimer?.cancel();
    _globalPollingTimer = null;
  }

  static List<Map<String, dynamic>> _mergeChats(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> page1,
  ) {
    final Map<dynamic, Map<String, dynamic>> map = {};
    for (var item in existing) {
      final id = item['id'];
      if (id != null) {
        map[id] = item;
      }
    }
    for (var item in page1) {
      final id = item['id'];
      if (id != null) {
        map[id] = item;
      }
    }
    final List<Map<String, dynamic>> result = List.from(page1);
    final Set<dynamic> page1Ids = page1.map((item) => item['id']).toSet();
    for (var item in existing) {
      final id = item['id'];
      if (id != null && !page1Ids.contains(id)) {
        result.add(item);
      }
    }
    return result;
  }

  static Future<void> _loadMoreChats() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    _globalStreamController.add(_staticChats);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService().getChatListResponse(page: nextPage);
      final newChats = response['results'] as List<Map<String, dynamic>>;
      final nextUrl = response['next'];

      if (newChats.isNotEmpty) {
        final Set<dynamic> existingIds = _staticChats
            .map((c) => c['id'])
            .toSet();
        final List<Map<String, dynamic>> merged = List.from(_staticChats);
        for (var chat in newChats) {
          final id = chat['id'];
          if (id != null && !existingIds.contains(id)) {
            merged.add(chat);
          }
        }

        _staticChats = merged;
        _currentPage = nextPage;
        _saveChatsToCache(_staticChats);
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
      }
      _hasMore = nextUrl != null;
    } catch (e) {
      debugPrint('Error loading more chats: $e');
    } finally {
      _isLoadingMore = false;
      _globalStreamController.add(_staticChats);
    }
  }

  static Future<void> refreshGlobally() async {
    await _fetchAndPushGlobally(resetPagination: true);
  }

  static Future<void> _fetchAndPushGlobally({
    bool resetPagination = false,
  }) async {
    try {
      if (resetPagination) {
        _currentPage = 1;
        _hasMore = true;
      }
      final response = await ApiService().getChatListResponse(page: 1);
      final chats = response['results'] as List<Map<String, dynamic>>;
      final nextUrl = response['next'];
      _hasMore = nextUrl != null;
      _everFetched = true;
      errorMessage = null;

      final List<Map<String, dynamic>> updatedChats;
      if (resetPagination) {
        updatedChats = chats;
      } else {
        updatedChats = _mergeChats(_staticChats, chats);
      }

      if (_listsAreDifferent(_staticChats, updatedChats)) {
        _staticChats = updatedChats;
        _saveChatsToCache(_staticChats);
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
      } else if (_staticChats.isEmpty) {
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
      }
    } on SocketException catch (e) {
      debugPrint('No internet connection fetching chat list');
      _everFetched = true;
      if (_staticChats.isEmpty) {
        errorMessage = 'no_internet: ${e.toString()}';
      }
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    } on TimeoutException catch (e) {
      debugPrint('Request timed out fetching chat list');
      _everFetched = true;
      if (_staticChats.isEmpty) {
        errorMessage = 'no_internet: timeout ${e.toString()}';
      }
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    } on DioException catch (e) {
      debugPrint(
        'Dio error fetching chat list: ${e.response?.statusCode} | ${e.type}',
      );
      _everFetched = true;
      if (_staticChats.isEmpty) {
        final statusCode = e.response?.statusCode ?? 0;
        if (statusCode >= 500) {
          errorMessage = 'server_error: status $statusCode';
        } else if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'no_internet: timeout ${e.message}';
        } else {
          errorMessage = 'unknown: status $statusCode ${e.message}';
        }
      }
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    } catch (e) {
      debugPrint('Error fetching chat list: $e');
      _everFetched = true;
      if (_staticChats.isEmpty) {
        errorMessage = 'unknown: ${e.toString()}';
      }
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members != null && members.length > 1) {
      for (final m in members) {
        final user =
            (m as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
        final id = user?['id'];
        final username = user?['username']?.toString();
        if (id != null &&
            id.toString() != currentUserId &&
            (currentUsername == null || username != currentUsername)) {
          return username ?? 'Unknown';
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members == null || members.isEmpty) return null;
    for (final m in members) {
      final user = (m as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      final username = user?['username']?.toString();
      if (user?['id']?.toString() != currentUserId &&
          (currentUsername == null || username != currentUsername)) {
        return user?['profile_image']?.toString();
      }
    }
    final user =
        (members.first as Map<String, dynamic>)['user']
            as Map<String, dynamic>?;
    return user?['profile_image']?.toString();
  }

  bool _isOtherMemberOnline(Map<String, dynamic> chat) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members == null) return false;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      final username = user?['username']?.toString();
      if (user?['id']?.toString() != currentUserId &&
          (currentUsername == null || username != currentUsername)) {
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members == null) return false;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      final username = user?['username']?.toString();
      if (user?['id']?.toString() != currentUserId &&
          (currentUsername == null || username != currentUsername)) {
        return (member['is_block'] as bool?) ?? false;
      }
    }
    return false;
  }

  dynamic _getOtherUserId(Map<String, dynamic> chat) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members == null) return null;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      final username = user?['username']?.toString();
      if (user?['id']?.toString() != currentUserId &&
          (currentUsername == null || username != currentUsername)) {
        return user?['id'];
      }
    }
    return null;
  }

  Future<void> _openChat(
    Map<String, dynamic> chat,
    String title,
    String? avatarUrl,
  ) async {
    final chatId = chat['id'] is int
        ? chat['id'] as int
        : int.tryParse(chat['id']?.toString() ?? '');
    final isBlocked = _isOtherMemberBlocked(chat);

    if (chatId != null && _unreadCount(chat) > 0) {
      final index = _staticChats.indexWhere(
        (c) => c['id']?.toString() == chatId.toString(),
      );
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return Container(
      height: 42,
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(right: 12.w, left: 12.w, top: 10.h),
          hintText: AppLocalizations.of(context)!.searchusers,
          hintStyle: AppTextStyles.bodyText.copyWith(
            color: txt.muted.withOpacity(0.7),
          ),
          border: InputBorder.none,
          prefixIcon: _searchQuery.trim().isNotEmpty
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    Icons.close,
                    size: 17.spMax,
                    color: const Color(0XFF898989),
                  ),
                )
              : Icon(
                  FeatherIcons.search,
                  size: 17.spMax,
                  color: const Color(0XFF898989),
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
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
              width: 0.7,
            ),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        style: AppTextStyles.bodyText.copyWith(
          color: txt.title,
          fontWeight: FontWeight.w500,
          fontSize: 14,
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
                      fontSize: 10.5,
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

  Widget _buildChatList(
    List<Map<String, dynamic>> chats,
    ScrollController controller,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final showLoader = _isLoadingMore && _searchQuery.trim().isEmpty;
    return RefreshIndicator(
      onRefresh: () => _fetchAndPushGlobally(resetPagination: true),
      color: Theme.of(context).colorScheme.onPrimary,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: chats.length + (showLoader ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == chats.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Loader(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            );
          }
          final txt = AppTextColors.of(context);
          final chat = chats[i];
          final avatarUrl = _avatarUrl(chat);
          final avatarProvider = _avatarProvider(avatarUrl);
          final title = _chatTitle(chat);
          final unread = _unreadCount(chat);

          return ListTile(
            onTap: () => _openChat(chat, title, avatarUrl),
            contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
            leading:
                chat['chat_type'] == 'group' &&
                    (avatarUrl == null || avatarUrl.trim().isEmpty)
                ? _buildGroupAvatarStack(
                    members: chat['members'] as List?,
                    size: 55,
                    isDarkMode: isDarkMode,
                    context: context,
                  )
                : Stack(
                    children: [
                      CircleAvatar(
                        radius: 19.r,
                        backgroundColor: isDarkMode
                            ? const Color(0xFF252525)
                            : Theme.of(context).primaryColor.withOpacity(0.08),
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                title.isNotEmpty ? title[0].toUpperCase() : '?',
                                style: AppTextStyles.subText.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 20,
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
                color: txt.title,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
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
                      color: unread > 0 ? txt.title : txt.body.withOpacity(0.6),
                      fontWeight: unread > 0
                          ? FontWeight.w500
                          : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '  · ${_formattedTime(chat)}',
                  style: AppTextStyles.subText.copyWith(
                    color: unread > 0 ? txt.body : txt.muted,
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

  Widget _buildTabBody(List<Map<String, dynamic>> allChats, String chatType) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final chats = _applyFilter(allChats, chatType);

    if (allChats.isEmpty) {
      return SizedBox(
        width: double.infinity,
        // height: 0.5.sh,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                isDarkMode
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Image.asset(
                          Assets.images.noMessage.path,
                          height: 0.22.sh,
                          width: 0.22.sh,
                          fit: BoxFit.contain,
                        ),
                      ),
                Text(
                  AppLocalizations.of(context)!.nomessagesyet,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionHeading.copyWith(
                    fontSize: 18.5,
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.startchattingbysharingpollsorreactingtoconversations,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF595959),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (chats.isEmpty && _searchQuery.trim().isNotEmpty) {
      final txt = AppTextColors.of(context);
      return Center(
        child: Text(
          '${AppLocalizations.of(context)!.searchusers} "$_searchQuery"',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13,
            color: txt.muted,
            height: 1.4,
          ),
        ),
      );
    }

    if (chats.isEmpty) {
      return SizedBox(
        width: double.infinity,
        // height: 0.5.sh,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                isDarkMode
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Image.asset(
                          Assets.images.noMessage.path,
                          height: 0.22.sh,
                          width: 0.22.sh,
                          fit: BoxFit.contain,
                        ),
                      ),

                Text(
                  AppLocalizations.of(context)!.nomessagesyet,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionHeading.copyWith(
                    fontSize: 18.5,
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.startchattingbysharingpollsorreactingtoconversations,

                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF595959),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = chatType == 'private'
        ? _privateScrollController
        : _groupScrollController;
    return _buildChatList(chats, controller);
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

          if (errorMessage != null && allChats.isEmpty) {
            final isOffline = !Provider.of<ConnectivityProvider>(
              context,
              listen: false,
            ).isOnline;
            return ConnectionErrorScreen(
              type: (errorMessage!.startsWith('no_internet') && isOffline)
                  ? ConnectionErrorType.noInternet
                  : ConnectionErrorType.unknown,
              errorMessage: errorMessage,
              onRetry: () {
                errorMessage = null;
                _everFetched = false;
                _globalStreamController.add([]);
                _fetchAndPushGlobally();
              },
            );
          }

          if (allChats.isEmpty && !_everFetched) {
            return Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            );
          }

          return Column(
            children: [
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
                    _buildTabLabel(
                      AppLocalizations.of(context)!.chats,
                      _unreadChatsCount,
                    ),
                    _buildTabLabel(
                      AppLocalizations.of(context)!.groups,
                      _unreadGroupsCount,
                    ),
                  ],
                ),
              ),
              _buildSearchBar(),

              // ── Tab content ───────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabBody(allChats, 'private'),
                    _buildTabBody(allChats, 'group'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
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
        final user = member is Map ? member['user'] as Map? : null;
        if (user != null) {
          final profileUrl =
              (user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['avatar'])
                  ?.toString();
          final name = (user['name'] ?? user['username'] ?? 'Unknown')
              .toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
        }
      }
    }

    if (profileUrls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode
              ? const Color(0xFF252525)
              : Theme.of(context).primaryColor.withOpacity(0.08),
        ),
        child: Center(
          child: Icon(
            Icons.group,
            size: size * 0.5,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
          ),
        ),
      );
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
    final avatarProvider = _avatarProvider(profileUrl);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarProvider == null
            ? (isDarkMode
                  ? const Color(0xFF252525)
                  : Theme.of(context).primaryColor.withOpacity(0.08))
            : null,
        border: hasBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.background,
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
            : null,
      ),
      child: avatarProvider == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                  fontSize: size * 0.4,
                ),
              ),
            )
          : null,
    );
  }
}
