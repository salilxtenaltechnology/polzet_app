// ignore_for_file: deprecated_member_use, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../widgets/show_toast.dart';
import '../../../provider/connection_provider.dart';
import '../../../api/api_config.dart';
import '../../../api/api_service.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/group_chat_provider.dart';
import '../../../provider/private_chat_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/connection/no_internet_screen.dart';
import 'chat/group/group_chat_screen.dart';
import 'chat/private/private_chat_screen.dart';
import 'archived_chats_screen.dart';
import '../../../widgets/dialog/custom_diolog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/bottomsheet_util.dart';
import 'group/create_group.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList>
    with UtilityMixin, SingleTickerProviderStateMixin {
  final _apiServices = ApiService();
  final TextEditingController _searchController = TextEditingController();
  bool _showPrivateArchived = false;
  bool _showGroupArchived = false;

  late final TabController _tabController;
  late final ScrollController _privateScrollController;
  late final ScrollController _groupScrollController;
  late final ScrollController _favouriteScrollController;

  static MessageListState? activeState;

  static List<Map<String, dynamic>> _staticChats = [];
  static List<Map<String, dynamic>> _favouriteChats = [];
  static bool _everFetched = false;
  static final ValueNotifier<int> unreadMessageCount = ValueNotifier<int>(0);
  static String? errorMessage;

  static int _currentPage = 1;
  static bool _hasMore = true;
  static bool _isLoadingMore = false;
  static String? _nextPageUrl;
  static final Set<String> _fetchedNextUrls = {};

  static final StreamController<List<Map<String, dynamic>>>
  _globalStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static Timer? _globalPollingTimer;

  String _searchQuery = '';

  static bool _isChatPinned(Map<String, dynamic> chat) {
    final val = chat['is_pinned'] ?? chat['isPinned'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static void togglePinChatLocally(dynamic chatId, bool isPinned) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _staticChats.indexWhere((c) => c['id']?.toString() == idStr);
    if (index != -1) {
      final List<Map<String, dynamic>> newList = List.from(_staticChats);
      newList[index] = {
        ...newList[index],
        'is_pinned': isPinned,
        'isPinned': isPinned,
      };
      _staticChats = newList;
      _saveChatsToCache(_staticChats);
      _globalStreamController.add(_staticChats);
    }
  }

  static bool _isChatMuted(Map<String, dynamic> chat) {
    final val = chat['is_muted'] ?? chat['isMuted'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static bool _isChatFavourite(Map<String, dynamic> chat) {
    final val = chat['is_favourite'] ?? chat['isFavourite'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static void toggleMuteChatLocally(dynamic chatId, bool isMuted) {
    _toggleMuteChatLocally(chatId, isMuted);
  }

  static void _toggleMuteChatLocally(dynamic chatId, bool isMuted) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _staticChats.indexWhere((c) => c['id']?.toString() == idStr);
    if (index != -1) {
      final List<Map<String, dynamic>> newList = List.from(_staticChats);
      newList[index] = {
        ...newList[index],
        'is_muted': isMuted,
        'isMuted': isMuted,
      };
      _staticChats = newList;
      _saveChatsToCache(_staticChats);
      _globalStreamController.add(_staticChats);
    }

    final favIndex = _favouriteChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (favIndex != -1) {
      final List<Map<String, dynamic>> newList = List.from(_favouriteChats);
      newList[favIndex] = {
        ...newList[favIndex],
        'is_muted': isMuted,
        'isMuted': isMuted,
      };
      _favouriteChats = newList;
      _saveFavsToCache(_favouriteChats);
    }
  }

  static void toggleFavouriteChatLocally(dynamic chatId, bool isFavourite) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _staticChats.indexWhere((c) => c['id']?.toString() == idStr);
    if (index != -1) {
      final List<Map<String, dynamic>> newList = List.from(_staticChats);
      newList[index] = {
        ...newList[index],
        'is_favourite': isFavourite,
        'isFavourite': isFavourite,
      };
      _staticChats = newList;
      _saveChatsToCache(_staticChats);
    }

    // Also update _favouriteChats list
    if (isFavourite) {
      final favIndex = _favouriteChats.indexWhere(
        (c) => c['id']?.toString() == idStr,
      );
      if (favIndex == -1) {
        final chat = _staticChats.firstWhere(
          (c) => c['id']?.toString() == idStr,
          orElse: () => <String, dynamic>{},
        );
        if (chat.isNotEmpty) {
          final List<Map<String, dynamic>> newFavList = List.from(
            _favouriteChats,
          );
          newFavList.add({...chat, 'is_favourite': true, 'isFavourite': true});
          _favouriteChats = newFavList;
        }
      } else {
        final List<Map<String, dynamic>> newFavList = List.from(
          _favouriteChats,
        );
        newFavList[favIndex] = {
          ...newFavList[favIndex],
          'is_favourite': true,
          'isFavourite': true,
        };
        _favouriteChats = newFavList;
      }
    } else {
      final List<Map<String, dynamic>> newFavList = List.from(_favouriteChats);
      newFavList.removeWhere((c) => c['id']?.toString() == idStr);
      _favouriteChats = newFavList;
    }

    _saveFavsToCache(_favouriteChats);
    _globalStreamController.add(_staticChats);
  }

  static bool _isChatArchived(Map<String, dynamic> chat) {
    final val = chat['is_archived'] ?? chat['isArchived'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static void toggleArchiveChatLocally(dynamic chatId, bool isArchived) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _staticChats.indexWhere((c) => c['id']?.toString() == idStr);
    if (index != -1) {
      final List<Map<String, dynamic>> newList = List.from(_staticChats);
      newList[index] = {
        ...newList[index],
        'is_archived': isArchived,
        'isArchived': isArchived,
      };
      _staticChats = newList;
      _saveChatsToCache(_staticChats);
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    }
  }

  Widget _buildPopupItem({
    required String text,
    required VoidCallback onTap,
    required bool isDarkMode,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              color:
                  textColor ??
                  (isDarkMode ? Colors.white : const Color(0xFF2E2E2E)),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isLastMessageFromOtherUser(Map<String, dynamic> chat) {
    final lastMessage = chat['last_message'];
    if (lastMessage == null) return false;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId?.toString();
    final currentUsername = userProvider.username;

    if (lastMessage is Map<String, dynamic>) {
      // 1. Check sender block
      final sender = lastMessage['sender'];
      if (sender is Map<String, dynamic>) {
        final senderId =
            (sender['id'] ??
                    sender['uuid'] ??
                    sender['userid'] ??
                    sender['user_id'])
                ?.toString();
        final senderUsername = sender['username']?.toString();
        if (senderId != null && currentUserId != null) {
          return senderId != currentUserId;
        }
        if (senderUsername != null && currentUsername != null) {
          return senderUsername != currentUsername;
        }
      }

      // 2. Check direct fields in last_message
      final senderId =
          (lastMessage['sender_id'] ??
                  lastMessage['senderId'] ??
                  lastMessage['user_id'])
              ?.toString();
      final senderUsername =
          (lastMessage['sender_username'] ??
                  lastMessage['senderUsername'] ??
                  lastMessage['username'])
              ?.toString();

      if (senderId != null && currentUserId != null) {
        return senderId != currentUserId;
      }
      if (senderUsername != null && currentUsername != null) {
        return senderUsername != currentUsername;
      }
    }
    return false;
  }

  static void toggleReadUnreadLocally(dynamic chatId, bool isUnread) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _staticChats.indexWhere((c) => c['id']?.toString() == idStr);
    if (index != -1) {
      _staticChats[index] = {
        ..._staticChats[index],
        'unread_count': isUnread ? 1 : 0,
      };
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    }

    // Also update _favouriteChats
    final favIndex = _favouriteChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (favIndex != -1) {
      _favouriteChats[favIndex] = {
        ..._favouriteChats[favIndex],
        'unread_count': isUnread ? 1 : 0,
      };
      _updateUnreadCount();
    }
  }

  Future<void> _showDeleteChatConfirmationDialog(dynamic chatId) async {
    showDeleteChatDiolog(context, () {
      Navigator.pop(context);
      _deleteChat(chatId);
    });
  }

  Future<void> _clearChat(dynamic chatId) async {
    if (chatId == null) return;
    try {
      final response = await _apiServices.clearChat(chatId: chatId.toString());
      if (response['status'] == 'success' || response['success'] == true) {
        clearChatLocally(chatId);
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

  Future<void> _deleteChat(dynamic chatId) async {
    if (chatId == null) return;
    try {
      final response = await _apiServices.deleteChat(chatId: chatId.toString());
      if (response['status'] == 'success' || response['success'] == true) {
        removeChatLocally(chatId);
        showToast(message: 'Chat deleted');
      } else {
        showToast(
          message: response['message']?.toString() ?? 'Failed to delete chat',
        );
      }
    } catch (e) {
      showToast(message: 'Failed to delete chat: $e');
    }
  }

  void _showChatOptionsDialog(Map<String, dynamic> chat, String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isPinned = _isChatPinned(chat);
        final isMuted = _isChatMuted(chat);
        final isFavourite = _isChatFavourite(chat);
        final isArchived = _isChatArchived(chat);
        final chatId = chat['id'];

        return Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Theme.of(context).colorScheme.tertiaryContainer,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200.w,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF333333) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8.h),
                      _buildPopupItem(
                        text: isPinned
                            ? AppLocalizations.of(context)!.unpin
                            : AppLocalizations.of(context)!.pin,
                        isDarkMode: isDarkMode,
                        onTap: () async {
                          Navigator.pop(context);
                          final newPinState = !isPinned;
                          HapticFeedback.lightImpact();
                          togglePinChatLocally(chatId, newPinState);
                          try {
                            final response = await _apiServices.pinUnpinChat(
                              chatId: chatId.toString(),
                              isPinned: newPinState,
                            );
                            final apiPinnedVal =
                                response['is_pinned'] ??
                                response['data']?['is_pinned'];
                            final success =
                                response['success'] ??
                                (apiPinnedVal != null ? true : null) ??
                                true;
                            if (!success) {
                              togglePinChatLocally(chatId, isPinned);
                              showToast(message: 'Failed to update pin status');
                            } else {
                              final apiPinned = apiPinnedVal != null
                                  ? (apiPinnedVal == true ||
                                        apiPinnedVal == 1 ||
                                        apiPinnedVal.toString() == 'true')
                                  : newPinState;
                              togglePinChatLocally(chatId, apiPinned);
                            }
                          } catch (e) {
                            togglePinChatLocally(chatId, isPinned);
                            showToast(message: 'Error: $e');
                          }
                        },
                      ),
                      _buildPopupItem(
                        text: isMuted
                            ? AppLocalizations.of(context)!.unmute
                            : AppLocalizations.of(context)!.mute,
                        isDarkMode: isDarkMode,
                        onTap: () async {
                          Navigator.pop(context);
                          final newMuteState = !isMuted;
                          HapticFeedback.lightImpact();
                          _toggleMuteChatLocally(chatId, newMuteState);
                          try {
                            final response = await _apiServices.muteUnmuteChat(
                              chatId: chatId.toString(),
                              isMuted: newMuteState,
                              muteUntil: newMuteState
                                  ? DateTime.now().add(
                                      const Duration(days: 365 * 10),
                                    )
                                  : null,
                            );

                            final apiMutedVal =
                                response['is_muted'] ??
                                response['data']?['is_muted'];
                            final success =
                                response['success'] ??
                                (apiMutedVal != null ? true : null) ??
                                true;
                            if (!success) {
                              _toggleMuteChatLocally(chatId, isMuted);
                              showToast(
                                message: 'Failed to update mute status',
                              );
                            } else {
                              final apiMuted = apiMutedVal != null
                                  ? (apiMutedVal == true ||
                                        apiMutedVal == 1 ||
                                        apiMutedVal.toString() == 'true')
                                  : newMuteState;
                              _toggleMuteChatLocally(chatId, apiMuted);
                            }
                          } catch (e) {
                            debugPrint('Mute Error: $e');
                            _toggleMuteChatLocally(chatId, isMuted);
                            showToast(message: 'Error: $e');
                          }
                        },
                      ),
                      _buildPopupItem(
                        text: isFavourite
                            ? AppLocalizations.of(context)!.removefromfavorites
                            : AppLocalizations.of(context)!.addtofavorites,
                        isDarkMode: isDarkMode,
                        onTap: () async {
                          Navigator.pop(context);
                          final newFavouriteState = !isFavourite;
                          HapticFeedback.lightImpact();
                          toggleFavouriteChatLocally(chatId, newFavouriteState);
                          try {
                            final response = await _apiServices
                                .favouriteUnfavouriteChat(
                                  chatId: chatId.toString(),
                                  isFavourite: newFavouriteState,
                                );
                            final apiFavVal =
                                response['is_favourite'] ??
                                response['data']?['is_favourite'];
                            final success =
                                response['success'] ??
                                (apiFavVal != null ? true : null) ??
                                true;
                            if (!success) {
                              toggleFavouriteChatLocally(chatId, isFavourite);
                              showToast(
                                message: 'Failed to update favorite status',
                              );
                            } else {
                              final apiFav = apiFavVal != null
                                  ? (apiFavVal == true ||
                                        apiFavVal == 1 ||
                                        apiFavVal.toString() == 'true')
                                  : newFavouriteState;
                              toggleFavouriteChatLocally(chatId, apiFav);
                            }
                          } catch (e) {
                            toggleFavouriteChatLocally(chatId, isFavourite);
                            showToast(message: 'Error: $e');
                          }
                        },
                      ),
                      _buildPopupItem(
                        text: isArchived
                            ? AppLocalizations.of(context)!.unarchive
                            : AppLocalizations.of(context)!.archive,
                        isDarkMode: isDarkMode,
                        onTap: () async {
                          Navigator.pop(context);
                          final newArchiveState = !isArchived;
                          HapticFeedback.lightImpact();
                          toggleArchiveChatLocally(chatId, newArchiveState);
                          try {
                            final response = await _apiServices
                                .archiveUnarchiveChat(
                                  chatId: chatId.toString(),
                                  isArchived: newArchiveState,
                                );
                            final success = response['success'] ?? true;
                            if (!success) {
                              toggleArchiveChatLocally(chatId, isArchived);
                              showToast(
                                message: 'Failed to update archive status',
                              );
                            } else {
                              showToast(
                                message: newArchiveState
                                    ? 'Chat archived'
                                    : 'Chat unarchived',
                              );
                            }
                          } catch (e) {
                            toggleArchiveChatLocally(chatId, isArchived);
                            showToast(message: 'Error: $e');
                          }
                        },
                      ),
                      if (_isLastMessageFromOtherUser(chat)) ...[
                        _buildPopupItem(
                          text: _unreadCount(chat) > 0
                              ? AppLocalizations.of(context)!.markasread
                              : AppLocalizations.of(context)!.markasunread,
                          isDarkMode: isDarkMode,
                          onTap: () async {
                            Navigator.pop(context);
                            final isCurrentlyUnread = _unreadCount(chat) > 0;
                            final newUnreadState = !isCurrentlyUnread;
                            HapticFeedback.lightImpact();
                            toggleReadUnreadLocally(chatId, newUnreadState);
                            try {
                              await _apiServices.markChatReadUnread(
                                chatId: chatId.toString(),
                                isUnread: newUnreadState,
                              );
                            } catch (e) {
                              toggleReadUnreadLocally(
                                chatId,
                                isCurrentlyUnread,
                              );
                              showToast(
                                message: 'Failed to update read status: $e',
                              );
                            }
                          },
                        ),
                      ],
                      _buildPopupItem(
                        text: AppLocalizations.of(context)!.deletechat,
                        isDarkMode: isDarkMode,
                        textColor: Theme.of(context).colorScheme.error,
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteChatConfirmationDialog(chatId);
                        },
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> chats,
    String chatType,
  ) {
    final List<Map<String, dynamic>> tabFiltered;
    final type = chatType.toLowerCase();

    if (type == 'all') {
      tabFiltered = chats.where((c) => !_isChatArchived(c)).toList();
    } else if (type == 'unread') {
      tabFiltered = chats
          .where(
            (c) =>
                !_isChatArchived(c) && (((c['unread_count'] as int?) ?? 0) > 0),
          )
          .toList();
    } else if (type == 'favorite' ||
        type == 'favorites' ||
        type == 'favourites') {
      tabFiltered = chats
          .where((c) => !_isChatArchived(c) && _isChatFavourite(c))
          .toList();
    } else if (type == 'groups' || type == 'group') {
      tabFiltered = chats
          .where(
            (c) => c['chat_type']?.toString() == 'group' && !_isChatArchived(c),
          )
          .toList();
    } else {
      tabFiltered = chats
          .where(
            (c) => c['chat_type']?.toString() == type && !_isChatArchived(c),
          )
          .toList();
    }

    List<Map<String, dynamic>> filtered;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      filtered = tabFiltered;
    } else {
      filtered = tabFiltered.where((chat) {
        final title = _chatTitle(chat).toLowerCase();
        final last = _lastMessage(chat).toLowerCase();
        return title.contains(q) || last.contains(q);
      }).toList();
    }

    final pinned = filtered.where((c) => _isChatPinned(c)).toList();
    final unpinned = filtered.where((c) => !_isChatPinned(c)).toList();
    return [...pinned, ...unpinned];
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
    final url = _resolveProfileUrl(avatarUrl);
    if (url == null) {
      return null;
    }
    return NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();
    activeState = this;

    _tabController = TabController(length: 3, vsync: this);
    _privateScrollController = ScrollController()
      ..addListener(_onPrivateScroll);
    _groupScrollController = ScrollController()..addListener(_onGroupScroll);
    _favouriteScrollController = ScrollController();

    if (_staticChats.isNotEmpty) {
      _globalStreamController.add(_staticChats);
    }

    startGlobalPolling();
  }

  void _revealArchivedHeader(String chatType) {
    if (chatType == 'private') {
      if (!_showPrivateArchived) {
        setState(() {
          _showPrivateArchived = true;
        });
        HapticFeedback.mediumImpact();
      }
    } else {
      if (!_showGroupArchived) {
        setState(() {
          _showGroupArchived = true;
        });
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _onPrivateScroll() {
    if (_privateScrollController.offset < -40.0) {
      _revealArchivedHeader('private');
    }

    if (_searchQuery.trim().isNotEmpty) return;
    if (_privateScrollController.position.pixels >=
            _privateScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreChats();
    }
  }

  void _onGroupScroll() {
    if (_groupScrollController.offset < -40.0) {
      _revealArchivedHeader('group');
    }

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
    if (activeState == this) {
      activeState = null;
    }
    _searchController.dispose();
    _tabController.dispose();
    _privateScrollController.dispose();
    _groupScrollController.dispose();
    _favouriteScrollController.dispose();
    super.dispose();
  }

  static const String _chatsCacheKey = 'cached_chats';

  static const String _favChatsCacheKey = 'cached_favourite_chats';

  static Future<void> _loadFavsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_favChatsCacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        final decoded = json.decode(cachedData);
        if (decoded is List) {
          _favouriteChats = List<Map<String, dynamic>>.from(
            decoded.map((item) => Map<String, dynamic>.from(item as Map)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading favorite chats from cache: $e');
    }
  }

  static Future<void> _saveFavsToCache(List<Map<String, dynamic>> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favChatsCacheKey, json.encode(chats));
    } catch (e) {
      debugPrint('Error saving favorite chats to cache: $e');
    }
  }

  static Future<void> _loadChatsFromCache() async {
    try {
      await _loadFavsFromCache();
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

    final targetUrl = _nextPageUrl;
    if (targetUrl != null && _fetchedNextUrls.contains(targetUrl)) {
      return;
    }

    _isLoadingMore = true;
    _globalStreamController.add(_staticChats);

    try {
      if (targetUrl != null) {
        _fetchedNextUrls.add(targetUrl);
      }

      final nextPage = _currentPage + 1;
      final response = await ApiService().getChatListResponse(
        page: nextPage,
        nextPageUrl: targetUrl,
      );
      final List<Map<String, dynamic>> newChats =
          (response['results'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      _nextPageUrl = response['next']?.toString();
      _hasMore = _nextPageUrl != null && _nextPageUrl!.isNotEmpty;

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
    } catch (e) {
      if (targetUrl != null) {
        _fetchedNextUrls.remove(targetUrl);
      }
      debugPrint('Error loading more chats: $e');
    } finally {
      _isLoadingMore = false;
      _globalStreamController.add(_staticChats);
    }
  }

  static Future<void> refreshGlobally() async {
    await _fetchAndPushGlobally(resetPagination: true);
  }

  static void selectTab(int index) {
    activeState?._tabController.animateTo(index);
  }

  static void removeChatLocally(dynamic chatId) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    _staticChats.removeWhere((c) => c['id']?.toString() == idStr);
    _favouriteChats.removeWhere((c) => c['id']?.toString() == idStr);
    _saveChatsToCache(_staticChats);
    _saveFavsToCache(_favouriteChats);
    _updateUnreadCount();
    _globalStreamController.add(_staticChats);
  }

  static void clearChatLocally(dynamic chatId) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _staticChats.indexWhere((c) => c['id']?.toString() == idStr);
    if (index != -1) {
      _staticChats[index] = {
        ..._staticChats[index],
        'last_message': null,
        'unread_count': 0,
      };
      _saveChatsToCache(_staticChats);
      _updateUnreadCount();
      _globalStreamController.add(_staticChats);
    }
    final favIndex = _favouriteChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (favIndex != -1) {
      _favouriteChats[favIndex] = {
        ..._favouriteChats[favIndex],
        'last_message': null,
        'unread_count': 0,
      };
      _saveFavsToCache(_favouriteChats);
    }
  }

  static Future<void> _fetchAndPushGlobally({
    bool resetPagination = false,
  }) async {
    try {
      if (resetPagination) {
        _currentPage = 1;
        _hasMore = true;
        _nextPageUrl = null;
        _fetchedNextUrls.clear();
      }
      try {
        final favResponse = await ApiService().getFavouriteChats();
        final rawFavs =
            favResponse['results'] ?? favResponse['data'] ?? favResponse;
        if (rawFavs is List) {
          _favouriteChats = List<Map<String, dynamic>>.from(
            rawFavs.map((item) => Map<String, dynamic>.from(item as Map)),
          );
          _saveFavsToCache(_favouriteChats);
        }
      } catch (e) {
        debugPrint('Error fetching favorite chats: $e');
      }

      final response = await ApiService().getChatListResponse(page: 1);
      final List<Map<String, dynamic>> chats =
          (response['results'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      final rawNext = response['next']?.toString();
      if (_currentPage == 1 || resetPagination) {
        _nextPageUrl = rawNext;
        _hasMore = _nextPageUrl != null && _nextPageUrl!.isNotEmpty;
      }
      _everFetched = true;
      errorMessage = null;

      final List<Map<String, dynamic>> updatedChats;
      if (resetPagination) {
        final freshChatIds = chats.map((c) => c['id']).toSet();
        final archivedChats = _staticChats
            .where((c) => _isChatArchived(c) && !freshChatIds.contains(c['id']))
            .toList();
        updatedChats = [...chats, ...archivedChats];
      } else {
        updatedChats = _mergeChats(_staticChats, chats);
      }

      // Sync favorite flag
      final Set<dynamic> favIds = _favouriteChats
          .map((c) => c['id']?.toString())
          .whereType<String>()
          .toSet();
      for (int i = 0; i < updatedChats.length; i++) {
        final idStr = updatedChats[i]['id']?.toString();
        if (idStr != null) {
          final isFav = favIds.contains(idStr);
          updatedChats[i] = {
            ...updatedChats[i],
            'is_favourite': isFav,
            'isFavourite': isFav,
          };
        }
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
      if (_isChatArchived(chat)) continue;
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
          a[i]['updated_at'] != b[i]['updated_at'] ||
          a[i]['profile_url'] != b[i]['profile_url'] ||
          a[i]['avatar_url'] != b[i]['avatar_url'] ||
          a[i]['display_name'] != b[i]['display_name'] ||
          a[i]['title'] != b[i]['title'] ||
          _isChatPinned(a[i]) != _isChatPinned(b[i]) ||
          _isChatMuted(a[i]) != _isChatMuted(b[i]) ||
          _isChatFavourite(a[i]) != _isChatFavourite(b[i])) {
        return true;
      }
    }
    return false;
  }

  String _chatTitle(Map<String, dynamic> chat) {
    if (chat['title'] != null && (chat['title'] as String).trim().isNotEmpty) {
      return chat['title'] as String;
    }
    if (chat['display_name'] != null &&
        chat['display_name'].toString().trim().isNotEmpty) {
      return chat['display_name'].toString();
    }
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members != null && members.length > 1) {
      for (final m in members) {
        final user =
            (m as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
        final id = user?['uuid'] ?? user?['id'];
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

  String? _resolveProfileUrl(String? url) {
    if (url == null || url.trim().isEmpty || url == 'null') return null;
    if (url.startsWith('assets/')) return url;
    if (!url.startsWith('http') && !url.startsWith('data:image')) {
      final separator = url.startsWith('/') ? '' : '/';
      return '${ApiConfig.baseUrlImage}$separator$url';
    }
    return url;
  }

  String? _avatarUrl(Map<String, dynamic> chat) {
    final chatType = chat['chat_type']?.toString();
    String? avatar;
    if (chatType == 'group') {
      avatar =
          chat['avatar_url']?.toString() ?? chat['profile_url']?.toString();
    } else {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId;
      final currentUsername = userProvider.username;
      final currentUserProfilePic = userProvider.profile_picture;

      bool isCurrentUserAvatar(String? url) {
        if (url == null || url.trim().isEmpty || url == 'null') return false;
        if (currentUserProfilePic != null &&
            currentUserProfilePic.trim().isNotEmpty) {
          if (url == currentUserProfilePic) return true;
          final resolvedUrl = _resolveProfileUrl(url);
          final resolvedCurrent = _resolveProfileUrl(currentUserProfilePic);
          if (resolvedUrl != null && resolvedUrl == resolvedCurrent) {
            return true;
          }
        }
        return false;
      }

      avatar =
          chat['profile_url']?.toString() ?? chat['avatar_url']?.toString();

      if (avatar == null ||
          avatar.trim().isEmpty ||
          avatar == 'null' ||
          isCurrentUserAvatar(avatar)) {
        final members = chat['members'] as List?;
        if (members != null && members.isNotEmpty) {
          String? foundAvatar;
          for (final m in members) {
            if (m is Map<String, dynamic>) {
              final user = m['user'] as Map<String, dynamic>?;
              if (user != null) {
                final username = user['username']?.toString();
                final userId = user['uuid'] ?? user['id'];
                if (userId?.toString() != currentUserId &&
                    (currentUsername == null || username != currentUsername)) {
                  foundAvatar =
                      (user['avatar_url'] ??
                              user['profile_image'] ??
                              user['profile_picture_url'] ??
                              user['avatar'])
                          ?.toString();
                  break;
                }
              }
            }
          }
          avatar = foundAvatar;
        } else {
          avatar = null;
        }
      }
    }
    return _resolveProfileUrl(avatar);
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
      final id = user?['uuid'] ?? user?['id'];
      if (id?.toString() != currentUserId &&
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
      final id = user?['uuid'] ?? user?['id'];
      if (id?.toString() != currentUserId &&
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
      final id = user?['uuid'] ?? user?['id'];
      if (id?.toString() != currentUserId &&
          (currentUsername == null || username != currentUsername)) {
        return id;
      }
    }
    return null;
  }

  bool _isPolzetAiUsername(String? username) {
    if (username == null) return false;
    final u = username.trim().toLowerCase();
    return u == 'polzet_ai' || u == 'polet_ai';
  }

  bool _isPolzetAiChat(Map<String, dynamic> chat) {
    final otherUsername = _getOtherUsername(chat);
    if (_isPolzetAiUsername(otherUsername)) return true;

    final username = chat['username']?.toString();
    if (_isPolzetAiUsername(username)) return true;

    final displayName = chat['display_name']?.toString();
    if (_isPolzetAiUsername(displayName)) return true;

    final title = chat['title']?.toString();
    if (_isPolzetAiUsername(title)) return true;

    final members = chat['members'] as List?;
    if (members != null) {
      for (final m in members) {
        if (m is Map<String, dynamic>) {
          final user = m['user'] as Map<String, dynamic>?;
          final uName = user?['username']?.toString();
          if (_isPolzetAiUsername(uName)) return true;
        }
      }
    }
    return false;
  }

  String? _getOtherUsername(Map<String, dynamic> chat) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentUsername = userProvider.username;
    final members = chat['members'] as List?;
    if (members == null) return null;
    for (final m in members) {
      final member = m as Map<String, dynamic>;
      final user = member['user'] as Map<String, dynamic>?;
      final username = user?['username']?.toString();
      final id = user?['uuid'] ?? user?['id'];
      if (id?.toString() != currentUserId &&
          (currentUsername == null || username != currentUsername)) {
        return username;
      }
    }
    return chat['display_name']?.toString();
  }

  Future<void> _openChat(
    Map<String, dynamic> chat,
    String title,
    String? avatarUrl,
  ) async {
    final chatId = chat['id']?.toString();
    final isBlocked = _isOtherMemberBlocked(chat);

    if (chatId != null && chatId.isNotEmpty && _unreadCount(chat) > 0) {
      final index = _staticChats.indexWhere(
        (c) => c['id']?.toString() == chatId.toString(),
      );
      if (index != -1) {
        _staticChats[index] = {..._staticChats[index], 'unread_count': 0};
        _updateUnreadCount();
        _globalStreamController.add(_staticChats);
        _apiServices.markChatAsRead(chatId: chatId);
        _apiServices.markChatReadUnread(chatId: chatId, isUnread: false);
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
              username: _getOtherUsername(chat),
              profileUrl: avatarUrl,
              chatId: chatId,
              isUserBlock: isBlocked,
              chat: chat,
            ),
          ),
        ),
      );
    }
    _fetchAndPushGlobally();
  }

  Widget _buildChatList(
    List<Map<String, dynamic>> chats,
    ScrollController controller,
    String chatType,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final showLoader = _isLoadingMore && _searchQuery.trim().isEmpty;
    final type = chatType.toLowerCase();
    final archivedCount = _staticChats
        .where(
          (c) =>
              _isChatArchived(c) &&
              (type == 'all' ||
                  type == 'unread' ||
                  type == 'favorite' ||
                  type == 'favourites' ||
                  c['chat_type']?.toString() == type),
        )
        .length;
    final hasArchived = archivedCount > 0;
    final showArchivedHeader = type == 'group'
        ? _showGroupArchived
        : _showPrivateArchived;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final offset = notification.metrics.pixels;
          if (offset < -40.0) {
            _revealArchivedHeader(chatType);
          }
        } else if (notification is OverscrollNotification) {
          if (notification.overscroll < -5.0) {
            _revealArchivedHeader(chatType);
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _fetchAndPushGlobally(resetPagination: true),
        color: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        child: ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 100),
          itemCount:
              chats.length + (showLoader ? 1 : 0) + (hasArchived ? 1 : 0),
          itemBuilder: (context, i) {
            if (hasArchived && i == 0) {
              final txt = AppTextColors.of(context);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: showArchivedHeader ? 45.h : 0,
                child: showArchivedHeader
                    ? ClipRect(
                        child: OverflowBox(
                          minHeight: 0,
                          maxHeight: 60.h,
                          alignment: Alignment.topCenter,
                          child: Dismissible(
                            key: const Key('archived_header_tile'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: isDarkMode
                                  ? const Color(0xFF2E2E2E)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.09),
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Text(
                                'Hide',
                                style: AppTextStyles.bodyText.copyWith(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.7)
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            onDismissed: (direction) {
                              setState(() {
                                if (chatType == 'private') {
                                  _showPrivateArchived = false;
                                } else {
                                  _showGroupArchived = false;
                                }
                              });
                              // showToast(message: 'Archived chats hidden');
                            },
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ArchivedChatsScreen(chatType: chatType),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.w),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(11.w),
                                      width: 40.w,
                                      height: 40.h,
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? const Color(0xFF252525)
                                            : Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Image.asset(
                                        'assets/images/ic_archive.png',
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.archivedchats,
                                      style: AppTextStyles.cardTitle.copyWith(
                                        color: txt.title,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }

            final actualIndex = hasArchived ? i - 1 : i;

            if (actualIndex == chats.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Loader(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              );
            }
            final txt = AppTextColors.of(context);
            final chat = chats[actualIndex];
            final avatarUrl = _avatarUrl(chat);
            final avatarProvider = _avatarProvider(avatarUrl);
            final title = _chatTitle(chat);
            final unread = _unreadCount(chat);
            final chatId = chat['id'];

            return Dismissible(
              key: Key('chat_${chatId.toString()}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: isDarkMode
                    ? const Color(0xFF2E2E2E)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.09),
                alignment: Alignment.centerRight,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Image.asset(
                  'assets/images/ic_archive.png',
                  height: 20.h,
                  width: 20.w,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              onDismissed: (direction) async {
                HapticFeedback.lightImpact();
                toggleArchiveChatLocally(chatId, true);
                try {
                  final response = await _apiServices.archiveUnarchiveChat(
                    chatId: chatId.toString(),
                    isArchived: true,
                  );
                  final success = response['success'] ?? true;
                  if (!success) {
                    toggleArchiveChatLocally(chatId, false);
                    showToast(message: 'Failed to archive chat');
                  } else {
                    showToast(message: 'Chat archived');
                  }
                } catch (e) {
                  toggleArchiveChatLocally(chatId, false);
                  showToast(message: 'Error archiving chat: $e');
                }
              },
              child: ListTile(
                onTap: () => _openChat(chat, title, avatarUrl),
                onLongPress: () => _showChatOptionsDialog(chat, title),
                contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
                leading: _isPolzetAiChat(chat)
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
                    : (chat['chat_type'] == 'group'
                        ? (avatarUrl == null || avatarUrl.trim().isEmpty
                              ? _buildGroupAvatarStack(
                                  members: chat['members'] as List?,
                                  size: 55,
                                  isDarkMode: isDarkMode,
                                  context: context,
                                )
                              : CircleAvatar(
                                  radius: 19.r,
                                  backgroundColor: isDarkMode
                                      ? const Color(0xFF252525)
                                      : Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.08),
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? Text(
                                          title.isNotEmpty
                                              ? title[0].toUpperCase()
                                              : 'P',
                                          style: AppTextStyles.subText.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 24,
                                          ),
                                        )
                                      : null,
                                ))
                        : Stack(
                            children: [
                              CircleAvatar(
                                radius: 19.r,
                                backgroundColor: isDarkMode
                                    ? const Color(0xFF252525)
                                    : Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.08),
                                backgroundImage: avatarProvider,
                                child: avatarProvider == null
                                    ? Text(
                                        title.isNotEmpty
                                            ? title[0].toUpperCase()
                                            : 'P',
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.background,
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: txt.title,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_isPolzetAiChat(chat)) ...[
                      SizedBox(width: 4.w),
                      Image.asset(
                        Assets.images.icVerify.path,
                        height: 13,
                        width: 13,
                      ),
                    ],
                    if (_isChatFavourite(chat)) ...[
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFFFB800),
                        size: 16.w,
                      ),
                    ],
                  ],
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
                              ? txt.title
                              : txt.body.withOpacity(0.6),
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
                trailing: (_isChatMuted(chat) || _isChatPinned(chat))
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isChatMuted(chat)) ...[
                            const AssetGenImage(
                              'assets/images/ic_muted.png',
                            ).image(
                              color: isDarkMode
                                  ? const Color(0xFFDFDEDE)
                                  : const Color(0xFF595959),
                              width: 15.w,
                              height: 15.h,
                            ),
                          ],
                          if (_isChatMuted(chat) && _isChatPinned(chat))
                            SizedBox(width: 4.w),
                          if (_isChatPinned(chat)) ...[
                            const AssetGenImage(
                              'assets/images/ic_pin.png',
                            ).image(
                              color: isDarkMode
                                  ? const Color(0xFFDFDEDE)
                                  : const Color(0xFF595959),
                              width: 15.w,
                              height: 15.h,
                            ),
                          ],
                        ],
                      )
                    : null,
              ),
            );
          },
        ),
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
                  chatType == 'favorite'
                      ? AppLocalizations.of(context)!.nofavoritechatyet
                      : AppLocalizations.of(context)!.nomessagesyet,
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
                  chatType == 'favorite'
                      ? AppLocalizations.of(
                          context,
                        )!.chatsyoufavoritewillappearhere
                      : AppLocalizations.of(
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
                  chatType == 'favorite'
                      ? AppLocalizations.of(context)!.nofavoritechatyet
                      : AppLocalizations.of(context)!.nomessagesyet,
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
                  chatType == 'favorite'
                      ? AppLocalizations.of(
                          context,
                        )!.chatsyoufavoritewillappearhere
                      : AppLocalizations.of(
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

    final ScrollController controller;
    final type = chatType.toLowerCase();
    if (type == 'group') {
      controller = _groupScrollController;
    } else if (type == 'favorite' || type == 'favourites') {
      controller = _favouriteScrollController;
    } else {
      controller = _privateScrollController;
    }
    return _buildChatList(chats, controller, chatType);
  }

  int get _unreadChatsCount {
    return _staticChats
        .where(
          (c) =>
              c['chat_type']?.toString() == 'private' &&
              !_isChatArchived(c) &&
              ((c['unread_count'] as int?) ?? 0) > 0,
        )
        .length;
  }

  int get _unreadGroupsCount {
    return _staticChats
        .where(
          (c) =>
              c['chat_type']?.toString() == 'group' &&
              !_isChatArchived(c) &&
              ((c['unread_count'] as int?) ?? 0) > 0,
        )
        .length;
  }

  int get _unreadFavouritesCount {
    return _favouriteChats
        .where(
          (c) => !_isChatArchived(c) && ((c['unread_count'] as int?) ?? 0) > 0,
        )
        .length;
  }

  String _selectedFilter = 'All';

  Widget _buildFilterChips() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final filters = [
      {'key': 'All', 'label': l10n.all},
      {'key': 'Unread', 'label': l10n.unread},
      {'key': 'Groups', 'label': l10n.groups},
      {'key': 'Favorites', 'label': l10n.favorites},
    ];
    final unreadTotal = _unreadChatsCount + _unreadGroupsCount;

    return SizedBox(
      height: 30.h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        child: Row(
          children: filters.map((filter) {
            final key = filter['key']!;
            final label = filter['label']!;
            final isSelected = _selectedFilter == key;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = key;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.only(right: 5.w),
                padding: EdgeInsets.symmetric(
                  horizontal: 15.w,
                  vertical: 4.2.h,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryColor
                      : (isDarkMode
                            ? const Color(0xFF1E2029)
                            : const Color(0xFFF3F3F5)),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: key == 'Unread'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.8)
                                        : const Color(0xFF6E6E73)),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (unreadTotal > 0) ...[
                            SizedBox(width: 5.w),
                            Text(
                              '$unreadTotal',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode
                                    ? Colors.white.withOpacity(0.8)
                                    : const Color(0xFF6E6E73)),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchAndActionRow() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38.h,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 5.h,
                  ),
                  hintText: AppLocalizations.of(context)!.searchusers,
                  hintStyle: AppTextStyles.bodyText.copyWith(
                    color: txt.muted.withOpacity(0.7),
                    fontSize: 12.sp,
                  ),
                  border: InputBorder.none,
                  prefixIcon: _searchQuery.trim().isNotEmpty
                      ? GestureDetector(
                          onTap: _clearSearch,
                          child: Icon(
                            Icons.close,
                            size: 18.spMax,
                            color: const Color(0XFF898989),
                          ),
                        )
                      : Icon(
                          Icons.search_rounded,
                          size: 20.spMax,
                          color: const Color(0XFF898989),
                        ),
                ),
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.title,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          SizedBox(width: 7.w),
          GestureDetector(
            onTap: () async {
              final createdChatId = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroup()),
              );
              if (createdChatId != null) {
                MessageListState.refreshGlobally();
              }
            },
            child: Container(
              width: 38.w,
              height: 38.w,
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
              ),
              child: Center(
                child: Image.asset(
                  Assets.images.icGroup.path,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: 5.w),
          GestureDetector(
            onTap: () {
              BottomSheetUtils.showNewChatBottomSheet(context);
            },
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor,
              ),
              child: Center(
                child: Icon(Icons.add, size: 24.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchAndActionRow(),
                SizedBox(height: 8.h),
                _buildFilterChips(),
                SizedBox(height: 10.h),
                Expanded(
                  child: _buildTabBody(allChats, _selectedFilter.toLowerCase()),
                ),
              ],
            );
          },
        ),
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
    final List<String?> usernames = [];

    if (members != null) {
      for (final member in members) {
        if (profileUrls.length >= 2) break;
        final user = member is Map ? member['user'] as Map? : null;
        if (user != null) {
          final profileUrl =
              (user['avatar_url'] ??
                      user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['avatar'])
                  ?.toString();
          final username = user['username']?.toString();
          final name = (user['name'] ?? username ?? 'Unknown')
              .toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
          usernames.add(username);
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
              username: usernames.isNotEmpty ? usernames[0] : null,
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
                username: usernames.length > 1 ? usernames[1] : null,
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
    String? username,
  }) {
    if (_isPolzetAiUsername(username) ||
        _isPolzetAiUsername(profileUrl)) {
      return Container(
        width: size,
        height: size,
        decoration: hasBorder
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.background,
                  width: 1.5,
                ),
              )
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 6,
                    bottom: 0,
                    left: 8,
                    right: 7,
                  ),
                  child: Image.asset(
                    Assets.images.icSplash.path,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                Assets.images.aiFrame.path,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    }
    final ImageProvider? avatarProvider =
        (profileUrl == null || profileUrl.trim().isEmpty)
        ? AssetImage(Assets.images.icAvatar.path)
        : _avatarProvider(profileUrl);
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
