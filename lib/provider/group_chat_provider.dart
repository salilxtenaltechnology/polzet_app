// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:polzet_app/api/services/api_service.dart';
import 'package:polzet_app/models/message/message_model.dart';
import 'package:polzet_app/data/token/shared_preferences.dart';

class GroupChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // ── State ─────────────────────────────────────────────────────────────────
  int? chatId;
  String? chatName;
  Map<String, dynamic>? chat;
  List<Map<String, dynamic>> members;

  bool isRenaming = false;

  // ── Online presence tracking ──────────────────────────────────────────────
  // key = user_id (int), value = username (String)
  final Map<int, String> _onlineMembers = {};

  int get onlineMemberCount => _onlineMembers.length;

  /// "1 online", "2 online", or "" if none
  String get onlineStatusText {
    final count = _onlineMembers.length;
    if (count == 0) return '';
    return '$count online';
  }

  

  /// e.g. "pratik, salil and 2 others are offline"
 String get offlineMembersText {
  final onlineIds = _onlineMembers.keys.toSet();
  final offlineNames = members
      .map((m) => m['user'] as Map?)
      .where((u) => u != null)
      .where((u) => !onlineIds.contains(u!['id'] as int?))
      .where((u) => (u!['id'] as int?) != _currentUserId)
      .map((u) => (u!['username'] ?? u['full_name'] ?? '').toString())
      .where((name) => name.isNotEmpty)
      .toList();

  if (offlineNames.isEmpty) return 'You';
  return '${offlineNames.join(', ')}, You';
}

  // ── Typing indicator ──────────────────────────────────────────────────────
  // key = user_id, value = username
  final Map<int, String> _typingMembers = {};
  Timer? _memberTypingTimer;

  /// e.g. "pratik is typing...", "pratik, salil are typing..."
  String get typingText {
    if (_typingMembers.isEmpty) return '';
    final names = _typingMembers.values.toList();
    if (names.length == 1) return '${names[0]} is typing...';
    if (names.length == 2) return '${names[0]}, ${names[1]} are typing...';
    return '${names[0]} and ${names.length - 1} others are typing...';
  }

  bool get isSomeoneTyping => _typingMembers.isNotEmpty;

  // ── Stream for real-time silent UI updates ────────────────────────────────
  final StreamController<List<ChatMessage>> _messagesStreamController =
      StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get messagesStream =>
      _messagesStreamController.stream;

  // ── Message state ─────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatMessage? get lastMessage => _messages.isEmpty ? null : _messages.last;

  String get lastMessageTime {
    if (_messages.isEmpty) return '';
    final dt = _messages.last.created_at;
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (dt.year == now.year) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  String? _historyError;
  String? get historyError => _historyError;

  String? _nextPageUrl;
  bool get hasMoreHistory => _nextPageUrl != null;

  // ── WebSocket state ───────────────────────────────────────────────────────
  static const String _wsBaseUrl = 'wss://testbackend.polzet.in';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 5;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get showConnectionBanner => !_isConnected;

  // ── Current user ──────────────────────────────────────────────────────────
  String? _currentUsername;
  int? _currentUserId;

  // ── Chat settings ─────────────────────────────────────────────────────────
  bool isMuteNotification = false;
  bool isProtectedChat = false;
  bool isHideChat = false;
  bool isHideChatHistory = false;

  GroupChatProvider({
    required this.chatId,
    required this.chatName,
    required this.chat,
    required this.members,
  });

  // ── Emit helper ───────────────────────────────────────────────────────────
  void _emitMessages() {
    if (!_messagesStreamController.isClosed) {
      _messagesStreamController.add(List.unmodifiable(_messages));
    }
  }

  // ── Helper: get username from members list by user_id ─────────────────────
  String _getUsernameById(int userId) {
    for (final m in members) {
      final user = m['user'] as Map?;
      if (user != null && user['id'] == userId) {
        return (user['username'] ?? user['full_name'] ?? 'Unknown').toString();
      }
    }
    return 'Unknown';
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init({String? currentUsername}) async {
    if (currentUsername != null && currentUsername.isNotEmpty) {
      _currentUsername = currentUsername;
    } else {
      _currentUsername = await SharedPrefService.getUsername();
    }

    // Get current user id to exclude self from typing/online display
    final userId = await SharedPrefService.getUserId();
    _currentUserId = int.tryParse(userId ?? '') ?? 0;

    debugPrint('👤 Group current username: $_currentUsername');

    notifyListeners();

    if (chatId != null) {
      await fetchMessageHistory();
    } else {
      debugPrint(
        '⚠️ GroupChatProvider: chatId is null — skipping history & WS',
      );
      return;
    }

    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectWebSocket(token);
    } else {
      debugPrint('❌ GroupChatProvider: No access token for WS');
    }
  }

  // ── REST: fetch initial message history ───────────────────────────────────
  Future<void> fetchMessageHistory() async {
    if (chatId == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      final response = await _api.getMessageList(chatId: chatId!);
      _nextPageUrl = response.next;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: _currentUsername != null
                  ? item.isSentBy(_currentUsername)
                  : false,
              senderUsername: item.sender.username,
              senderProfileImage: item.sender.profileImage,
            ),
          )
          .toList();

      _messages.clear();
      _messages.addAll(fetched.reversed.toList());

      debugPrint('✅ Group: loaded ${fetched.length} messages');
      _emitMessages();
    } catch (e) {
      _historyError = e.toString();
      debugPrint('❌ Group: failed to load message history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── REST: fetch older paginated messages ──────────────────────────────────
  Future<void> fetchMoreHistory() async {
    if (chatId == null || _nextPageUrl == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await _api.getMessageList(
        chatId: chatId!,
        nextPageUrl: _nextPageUrl,
      );
      _nextPageUrl = response.next;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: _currentUsername != null
                  ? item.isSentBy(_currentUsername)
                  : false,
              senderUsername: item.sender.username,
              senderProfileImage: item.sender.profileImage,
            ),
          )
          .toList();

      _messages.insertAll(0, fetched.reversed.toList());
      debugPrint('✅ Group: loaded ${fetched.length} more messages');
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Group: failed to load more history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────
  Future<void> _connectWebSocket(String token) async {
    if (_isConnecting || _isConnected) return;
    if (chatId == null) {
      debugPrint('❌ Cannot connect WS — chatId is null');
      return;
    }

    _isConnecting = true;
    notifyListeners();

    try {
      final wsUrl = '$_wsBaseUrl/ws/chats/$chatId/presence/?token=$token';
      debugPrint('🔌 Connecting to Group Chat WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _wsSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (error) {
          debugPrint('❌ Group WS error: $error');
          if (_isUpgradeRejected(error.toString())) {
            _shouldReconnect = false;
          }
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('🔌 Group WebSocket closed');
          _handleDisconnection();
        },
        cancelOnError: false,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      debugPrint('✅ Group WebSocket connected');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Group WS connection failed: $e');
      if (_isUpgradeRejected(e.toString())) _shouldReconnect = false;
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      _handleDisconnection();
    }
  }

  bool _isUpgradeRejected(String error) =>
      error.contains('not upgraded') ||
      error.contains('403') ||
      error.contains('404');

  Future<void> reconnect() async {
    if (_isConnected || _isConnecting) return;
    debugPrint('🔄 Group: manual reconnect triggered');
    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectWebSocket(token);
    }
  }

  // ── Incoming WS message ───────────────────────────────────────────────────
  void _onMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      debugPrint('📨 Group WS message received: $data');

      // ── Presence: USER_JOINED_CHAT ────────────────────────────────────────
      if (data['type'] == 'USER_JOINED_CHAT') {
        final userId = data['user_id'];
        if (userId != null && userId != _currentUserId) {
          final username = _getUsernameById(userId as int);
          _onlineMembers[userId] = username;
          debugPrint('🟢 $username joined — online: $_onlineMembers');
          notifyListeners();
        }
        return;
      }

      // ── Presence: USER_LEFT_CHAT ──────────────────────────────────────────
      if (data['type'] == 'USER_LEFT_CHAT') {
        final userId = data['user_id'];
        if (userId != null) {
          _onlineMembers.remove(userId);
          _typingMembers.remove(userId); // stop typing if they left
          debugPrint('🔴 User $userId left — online: $_onlineMembers');
          notifyListeners();
        }
        return;
      }

      // ── Typing indicator ──────────────────────────────────────────────────
      if (data['action'] == 'typing') {
        final userId = data['user_id'];
        if (userId != null && userId != _currentUserId) {
          final isTyping = data['is_typing'] == true;
          final username = _getUsernameById(userId as int);

          if (isTyping) {
            _typingMembers[userId] = username;
            // Auto-reset if server never sends is_typing: false
            _memberTypingTimer?.cancel();
            _memberTypingTimer = Timer(const Duration(seconds: 3), () {
              _typingMembers.remove(userId);
              notifyListeners();
            });
          } else {
            _typingMembers.remove(userId);
            _memberTypingTimer?.cancel();
          }

          debugPrint('⌨️ Typing: $_typingMembers');
          notifyListeners();
        }
        return;
      }

      // ── Chat message ──────────────────────────────────────────────────────
      final String text =
          data['message']?.toString() ?? data['text']?.toString() ?? '';
      if (text.isEmpty) return;

      String? senderUsername;
      if (data['sender'] is Map) {
        senderUsername = (data['sender'] as Map)['username']?.toString();
      } else {
        senderUsername =
            data['sender']?.toString() ?? data['username']?.toString();
      }

      final bool isSentByMe =
          _currentUsername != null && senderUsername == _currentUsername;

      final DateTime serverTimestamp =
          DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
          DateTime.now();

      if (isSentByMe) {
        final pendingIndex = _messages.lastIndexWhere(
          (m) => m.isSentByMe && m.isPending && m.text == text,
        );
        if (pendingIndex != -1) {
          _messages[pendingIndex] = ChatMessage(
            text: text,
            created_at: serverTimestamp,
            isSentByMe: true,
            isPending: false,
          );
          _emitMessages();
          return;
        }
      }

      final String? profileImage = data['sender'] is Map
          ? (data['sender'] as Map)['profile_image']?.toString()
          : null;

      _messages.add(
        ChatMessage(
          text: text,
          created_at: serverTimestamp,
          isSentByMe: isSentByMe,
          isPending: false,
          senderUsername: senderUsername,
          senderProfileImage: profileImage,
        ),
      );
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Error parsing Group WS message: $e');
    }
  }

  void _handleDisconnection() {
    _cleanupConnection();
    if (!_shouldReconnect) return;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: 2 * _reconnectAttempts);
      debugPrint(
        '⏳ Group: reconnecting in ${delay.inSeconds}s '
        '(Attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
      );
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        final token = await SharedPrefService.getToken();
        if (token != null) _connectWebSocket(token);
      });
    } else {
      debugPrint('❌ Group: max reconnect attempts reached.');
    }
  }

  void _cleanupConnection() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }

  // ── Send message ──────────────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (chatId == null) return;

    final optimistic = ChatMessage(
      text: trimmed,
      created_at: DateTime.now(),
      isSentByMe: true,
      isPending: true,
    );
    _messages.add(optimistic);
    _emitMessages();

    try {
      await _api.sendMessage(chatId: chatId!, text: trimmed);
      debugPrint('✅ Group: message delivered to server: $trimmed');
    } catch (e) {
      debugPrint('❌ Group: sendMessage API failed: $e');
    }
  }

  Map<String, dynamic> _userFromMember(Map<String, dynamic> member) =>
      Map<String, dynamic>.from(member['user'] as Map? ?? {});

  // ── Add members ───────────────────────────────────────────────────────────
  Future<bool> addGroupMembers(
    List<int> memberIds,
    List<Map<String, dynamic>> selectedUsers,
  ) async {
    if (chatId == null) return false;

    final result = await _api.addGroupChatMembers(
      groupChatId: chatId!,
      members: memberIds,
    );

    if (result['success'] == true) {
      final addedIds = List<int>.from(result['added'] ?? []);
      for (final user in selectedUsers) {
        final id = user['id'] as int?;
        if (id != null && addedIds.contains(id)) {
          final alreadyExists = members.any(
            (m) => _userFromMember(m)['id'] == id,
          );
          if (!alreadyExists) {
            members.add({
              'user': {
                'id': user['id'],
                'username':
                    user['username'] ?? user['name'] ?? user['full_name'],
                'profile_image':
                    user['profile_image'] ??
                    user['avatar'] ??
                    user['profile_picture_url'] ??
                    user['image'],
              },
              'is_admin': false,
            });
          }
        }
      }
      _syncMembersIntoChat();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> renameGroup(String newTitle) async {
    if (newTitle.trim().isEmpty || newTitle == chatName || chatId == null) {
      return false;
    }
    isRenaming = true;
    notifyListeners();

    final result = await _api.renameGroup(
      chatId: chatId!,
      newTitle: newTitle.trim(),
    );

    isRenaming = false;
    if (result['success'] == true) {
      chatName = result['new_title'] as String?;
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  void updateGroupPicture(String url) {
    if (chat != null) {
      chat = {...chat!, 'profile_url': url};
    }
    notifyListeners();
  }

  Future<bool> removeMember(int userId) async {
    members = members.where((m) => _userFromMember(m)['id'] != userId).toList();
    _onlineMembers.remove(userId);
    _typingMembers.remove(userId);
    _syncMembersIntoChat();
    notifyListeners();

    final result = await _api.removeMember(chatId: chatId!, userId: userId);
    if (result['success'] != true) return false;
    return true;
  }

  Future<bool> makeAdmin(int userId) async {
    members = members.map((m) {
      final user = _userFromMember(m);
      if (user['id'] == userId) return {...m, 'is_admin': true};
      return m;
    }).toList();
    notifyListeners();

    final result = await _api.makeAdmin(chatId: chatId!, userId: userId);
    if (result['message'] != 'User promoted to admin') {
      members = members.map((m) {
        final user = _userFromMember(m);
        if (user['id'] == userId) return {...m, 'is_admin': false};
        return m;
      }).toList();
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> deleteGroup() async {
    if (chatId == null) return {'message': 'No chat ID'};
    return await _api.deleteGroup(chatId: chatId!);
  }

  Future<Map<String, dynamic>> leaveGroup() async {
    if (chatId == null) return {'message': 'No chat ID'};
    return await _api.leaveGroup(chatId: chatId!);
  }

  void toggleMuteNotification(bool value) {
    isMuteNotification = value;
    notifyListeners();
  }

  void toggleProtectedChat(bool value) {
    isProtectedChat = value;
    notifyListeners();
  }

  void toggleHideChat(bool value) {
    isHideChat = value;
    notifyListeners();
  }

  void toggleHideChatHistory(bool value) {
    isHideChatHistory = value;
    notifyListeners();
  }

  void _syncMembersIntoChat() {
    if (chat != null) {
      chat = {...chat!, 'members': members};
    }
  }

  // ── Reset / Dispose ───────────────────────────────────────────────────────
  void reset() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanupConnection();

    _onlineMembers.clear();
    _typingMembers.clear();
    _memberTypingTimer?.cancel();
    _messages.clear();
    _reconnectAttempts = 0;
    _nextPageUrl = null;
    _historyError = null;
    _currentUsername = null;
    _currentUserId = null;

    isMuteNotification = false;
    isProtectedChat = false;
    isHideChat = false;
    isHideChatHistory = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanupConnection();
    _messagesStreamController.close();
    _memberTypingTimer?.cancel();
    super.dispose();
  }
}
