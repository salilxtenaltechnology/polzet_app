// ignore_for_file: deprecated_member_use, unused_element, unused_local_variable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../widgets/show_toast.dart';
import '../../../api/api_config.dart';
import '../../../api/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/group_chat_provider.dart';
import '../../../provider/private_chat_provider.dart';
import '../../../provider/user_provider.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/loader.dart';
import 'chat/group/group_chat_screen.dart';
import 'chat/private/private_chat_screen.dart';
import 'message_list.dart';

class ArchivedChatsScreen extends StatefulWidget {
  final String chatType; // 'private' or 'group'

  const ArchivedChatsScreen({super.key, required this.chatType});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen>
    with UtilityMixin {
  final _apiServices = ApiService();
  List<Map<String, dynamic>> _archivedChats = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchArchivedChats();
  }

  Future<void> _fetchArchivedChats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiServices.getArchivedList();
      final list = response['results'] as List?;
      if (list != null) {
        final allArchived = List<Map<String, dynamic>>.from(
          list.map((item) => Map<String, dynamic>.from(item as Map)),
        );
        // Filter by the screen's chatType
        final type = widget.chatType.toLowerCase();
        setState(() {
          _archivedChats = type == 'all'
              ? allArchived
              : allArchived
                    .where((c) => c['chat_type']?.toString() == type)
                    .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _archivedChats = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      showToast(message: 'Error fetching archived chats: $e');
    }
  }

  static bool _isChatPinned(Map<String, dynamic> chat) {
    final val = chat['is_pinned'] ?? chat['isPinned'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static bool _isChatMuted(Map<String, dynamic> chat) {
    final val = chat['is_muted'] ?? chat['isMuted'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static bool _isChatFavourite(Map<String, dynamic> chat) {
    final val = chat['is_favourite'] ?? chat['isFavourite'];
    return val == true || val == 1 || val?.toString() == 'true';
  }

  static bool _isChatArchived(Map<String, dynamic> chat) {
    final val = chat['is_archived'] ?? chat['isArchived'];
    return val == true || val == 1 || val?.toString() == 'true';
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

  ImageProvider? _avatarProvider(String? avatarUrl) {
    final url = _resolveProfileUrl(avatarUrl);
    if (url == null) {
      return null;
    }
    return NetworkImage(url);
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
            ),
          ),
        ),
      );
    }
    // Refresh the list after returning
    _fetchArchivedChats();
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

  void _togglePinChatLocally(dynamic chatId, bool isPinned) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _archivedChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (index != -1) {
      setState(() {
        _archivedChats[index] = {
          ..._archivedChats[index],
          'is_pinned': isPinned,
          'isPinned': isPinned,
        };
      });
    }
    MessageListState.togglePinChatLocally(chatId, isPinned);
  }

  void _toggleMuteChatLocally(dynamic chatId, bool isMuted) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _archivedChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (index != -1) {
      setState(() {
        _archivedChats[index] = {
          ..._archivedChats[index],
          'is_muted': isMuted,
          'isMuted': isMuted,
        };
      });
    }
    MessageListState.toggleMuteChatLocally(chatId, isMuted);
  }

  void _toggleFavouriteChatLocally(dynamic chatId, bool isFavourite) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _archivedChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (index != -1) {
      setState(() {
        _archivedChats[index] = {
          ..._archivedChats[index],
          'is_favourite': isFavourite,
          'isFavourite': isFavourite,
        };
      });
    }
    MessageListState.toggleFavouriteChatLocally(chatId, isFavourite);
  }

  void _toggleReadUnreadLocally(dynamic chatId, bool isUnread) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    final index = _archivedChats.indexWhere(
      (c) => c['id']?.toString() == idStr,
    );
    if (index != -1) {
      setState(() {
        _archivedChats[index] = {
          ..._archivedChats[index],
          'unread_count': isUnread ? 1 : 0,
        };
      });
    }
    MessageListState.toggleReadUnreadLocally(chatId, isUnread);
  }

  void _removeChatLocally(dynamic chatId) {
    if (chatId == null) return;
    final idStr = chatId.toString();
    setState(() {
      _archivedChats.removeWhere((c) => c['id']?.toString() == idStr);
    });
    MessageListState.removeChatLocally(chatId);
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

  Future<void> _showDeleteChatConfirmationDialog(dynamic chatId) async {
    final txt = AppTextColors.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete Chat?',
                  style: AppTextStyles.sectionHeading.copyWith(
                    color: txt.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete this chat? All message history will be removed for you. This action cannot be undone.',
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.body,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.bodyText.copyWith(
                          color: txt.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteChat(chatId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: AppTextStyles.bodyText.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteChat(dynamic chatId) async {
    if (chatId == null) return;
    try {
      final response = await _apiServices.deleteChat(chatId: chatId.toString());
      if (response['status'] == 'success' || response['success'] == true) {
        _removeChatLocally(chatId);
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
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200.w,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF333333) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                          _togglePinChatLocally(chatId, newPinState);
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
                              _togglePinChatLocally(chatId, isPinned);
                              showToast(message: 'Failed to update pin status');
                            } else {
                              final apiPinned = apiPinnedVal != null
                                  ? (apiPinnedVal == true ||
                                        apiPinnedVal == 1 ||
                                        apiPinnedVal.toString() == 'true')
                                  : newPinState;
                              _togglePinChatLocally(chatId, apiPinned);
                            }
                          } catch (e) {
                            _togglePinChatLocally(chatId, isPinned);
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
                      // _buildPopupItem(
                      //   text: isFavourite ? 'Remove from favorites' : 'Add to favorites',
                      //   isDarkMode: isDarkMode,
                      //   onTap: () async {
                      //     Navigator.pop(context);
                      //     final newFavouriteState = !isFavourite;
                      //     HapticFeedback.lightImpact();
                      //     _toggleFavouriteChatLocally(chatId, newFavouriteState);
                      //     try {
                      //       final response = await _apiServices
                      //           .favouriteUnfavouriteChat(
                      //             chatId: chatId.toString(),
                      //             isFavourite: newFavouriteState,
                      //           );
                      //       final apiFavVal =
                      //           response['is_favourite'] ??
                      //           response['data']?['is_favourite'];
                      //       final success =
                      //           response['success'] ??
                      //           (apiFavVal != null ? true : null) ??
                      //           true;
                      //       if (!success) {
                      //         _toggleFavouriteChatLocally(chatId, isFavourite);
                      //         showToast(message: 'Failed to update favorite status');
                      //       } else {
                      //         final apiFav = apiFavVal != null
                      //             ? (apiFavVal == true ||
                      //                   apiFavVal == 1 ||
                      //                   apiFavVal.toString() == 'true')
                      //             : newFavouriteState;
                      //         _toggleFavouriteChatLocally(chatId, apiFav);
                      //       }
                      //     } catch (e) {
                      //       _toggleFavouriteChatLocally(chatId, isFavourite);
                      //       showToast(message: 'Error: $e');
                      //     }
                      //   },
                      // ),
                      _buildPopupItem(
                        text: isArchived
                            ? AppLocalizations.of(context)!.unarchive
                            : AppLocalizations.of(context)!.archive,
                        isDarkMode: isDarkMode,
                        onTap: () async {
                          Navigator.pop(context);
                          final newArchiveState = !isArchived;
                          HapticFeedback.lightImpact();

                          if (!newArchiveState) {
                            // Optimistically remove from archived list
                            final chatIndex = _archivedChats.indexWhere(
                              (c) => c['id']?.toString() == chatId?.toString(),
                            );
                            Map<String, dynamic>? removedChat;
                            if (chatIndex != -1) {
                              removedChat = _archivedChats[chatIndex];
                              setState(() {
                                _archivedChats.removeAt(chatIndex);
                              });
                            }
                            MessageListState.toggleArchiveChatLocally(
                              chatId,
                              false,
                            );
                            try {
                              final response = await _apiServices
                                  .archiveUnarchiveChat(
                                    chatId: chatId.toString(),
                                    isArchived: false,
                                  );
                              final success = response['success'] ?? true;
                              if (!success) {
                                // Revert
                                if (removedChat != null) {
                                  setState(() {
                                    _archivedChats.insert(
                                      chatIndex,
                                      removedChat!,
                                    );
                                  });
                                }
                                MessageListState.toggleArchiveChatLocally(
                                  chatId,
                                  true,
                                );
                                showToast(message: 'Failed to unarchive chat');
                              } else {
                                showToast(message: 'Chat unarchived');
                              }
                            } catch (e) {
                              // Revert
                              if (removedChat != null) {
                                setState(() {
                                  _archivedChats.insert(
                                    chatIndex,
                                    removedChat!,
                                  );
                                });
                              }
                              MessageListState.toggleArchiveChatLocally(
                                chatId,
                                true,
                              );
                              showToast(message: 'Error: $e');
                            }
                          } else {
                            MessageListState.toggleArchiveChatLocally(
                              chatId,
                              true,
                            );
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
                            _toggleReadUnreadLocally(chatId, newUnreadState);
                            try {
                              await _apiServices.markChatReadUnread(
                                chatId: chatId.toString(),
                                isUnread: newUnreadState,
                              );
                            } catch (e) {
                              _toggleReadUnreadLocally(
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
              (user['avatar_url'] ??
                      user['profile_image'] ??
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    final title = widget.chatType == 'group'
        ? 'Archived Groups'
        : 'Archived Chats';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          title,
          style: AppTextStyles.sectionHeading.copyWith(
            color: txt.title,
            fontSize: 18.spMax,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: txt.title,
            size: 18.spMax,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load archived chats',
                    style: AppTextStyles.bodyText.copyWith(color: txt.muted),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchArchivedChats,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _archivedChats.isEmpty
          ? Center(
              child: Text(
                'No archived chats yet',
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.muted,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _archivedChats.length,
              padding: const EdgeInsets.only(bottom: 50),
              itemBuilder: (context, i) {
                final chat = _archivedChats[i];
                final avatarUrl = _avatarUrl(chat);
                final avatarProvider = _avatarProvider(avatarUrl);
                final title = _chatTitle(chat);
                final unread = _unreadCount(chat);
                final chatId = chat['id'];

                return Dismissible(
                  key: Key('archived_${chatId.toString()}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: isDarkMode
                        ? const Color(0xFF2E2E2E)
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.09),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Image.asset(
                      'assets/images/ic_unarchive.png',
                      height: 20.h,
                      width: 20.w,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  onDismissed: (direction) async {
                    HapticFeedback.lightImpact();

                    // Optimistically remove from screen list and update main cache
                    setState(() {
                      _archivedChats.removeAt(i);
                    });
                    MessageListState.toggleArchiveChatLocally(chatId, false);

                    try {
                      final response = await _apiServices.archiveUnarchiveChat(
                        chatId: chatId.toString(),
                        isArchived: false,
                      );
                      final success = response['success'] ?? true;
                      if (!success) {
                        // Revert
                        MessageListState.toggleArchiveChatLocally(chatId, true);
                        _fetchArchivedChats();
                        showToast(message: 'Failed to unarchive chat');
                      } else {
                        showToast(message: 'Chat unarchived');
                      }
                    } catch (e) {
                      // Revert
                      MessageListState.toggleArchiveChatLocally(chatId, true);
                      _fetchArchivedChats();
                      showToast(message: 'Error unarchiving chat: $e');
                    }
                  },
                  child: ListTile(
                    onTap: () => _openChat(chat, title, avatarUrl),
                    onLongPress: () => _showChatOptionsDialog(chat, title),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
                    leading: chat['chat_type'] == 'group'
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.8),
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
                          ),
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
                                  width: 16.w,
                                  height: 16.h,
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
                                  width: 16.w,
                                  height: 16.h,
                                ),
                              ],
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
