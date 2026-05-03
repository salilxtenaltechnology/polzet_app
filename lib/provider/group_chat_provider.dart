// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../models/message/message_model.dart';
import '../../data/token/shared_preferences.dart';
import '../api/services/api_service.dart';

class GroupMemberPresence {
  final int userId;
  String username;
  bool isOnline;
  bool isTyping;

  GroupMemberPresence({
    required this.userId,
    required this.username,
    this.isOnline = false,
    this.isTyping = false,
  });
}

class GroupChatProvider extends ChangeNotifier {
  String? _groupName;
  String? _groupImageUrl;
  int? _chatId;
  Map<String, dynamic>? _chat;

  final Set<int> _adminIds = {};

  String? get groupName => _groupName;
  String? get chatName => _groupName;
  String? get groupImageUrl => _groupImageUrl;
  int? get chatId => _chatId;
  Map<String, dynamic>? get chat => _chat;

  List<Map<String, dynamic>> get members {
    if (_chat != null && _chat!['members'] != null) {
      return List<Map<String, dynamic>>.from(_chat!['members']);
    }
    return [];
  }

  Set<int> get adminIds => Set.unmodifiable(_adminIds);

  bool isAdmin(int userId) => _adminIds.contains(userId);

  void _syncAdminIds() {
    _adminIds.clear();

    if (_chat == null) return;

    if (_chat!['admins'] != null) {
      final adminsList = _chat!['admins'] as List<dynamic>;
      for (final a in adminsList) {
        if (a is Map<String, dynamic>) {
          final id = a['id'] as int?;
          if (id != null) _adminIds.add(id);
        }
      }
      debugPrint('🔑 [Group] Synced ${_adminIds.length} admins from admins[]');
      return;
    }

    if (_chat!['members'] != null) {
      final membersList = _chat!['members'] as List<dynamic>;
      for (final m in membersList) {
        if (m is Map<String, dynamic> && m['is_admin'] == true) {
          final user = m['user'] as Map<String, dynamic>?;
          final id = user?['id'] as int?;
          if (id != null) _adminIds.add(id);
        }
      }
      debugPrint(
        '🔑 [Group] Synced ${_adminIds.length} admins from members[].is_admin',
      );
    }
  }

  bool _isRenaming = false;
  bool get isRenaming => _isRenaming;

  final Map<int, GroupMemberPresence> _memberPresence = {};
  Map<int, GroupMemberPresence> get memberPresence =>
      Map.unmodifiable(_memberPresence);

  List<String> get typingUsernames => _memberPresence.values
      .where((m) => m.isTyping)
      .map((m) => m.username)
      .toList();

  bool get isSomeoneTyping => typingUsernames.isNotEmpty;

  String get typingIndicatorText {
    final names = typingUsernames;
    if (names.isEmpty) return '';
    if (names.length == 1) return '${names.first} is typing…';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
    return '${names.take(2).join(', ')} and ${names.length - 2} more are typing…';
  }

  Timer? _typingTimer;
  Timer? _pollingTimer;
  final Map<int, Timer> _memberTypingTimers = {};

  final StreamController<List<ChatMessage>> _messagesStreamController =
      StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get messagesStream =>
      _messagesStreamController.stream;

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

  static const String _wsBaseUrl = 'ws://testbackend.polzet.in';

  WebSocketChannel? _presenceChannel;
  StreamSubscription? _presenceSubscription;
  bool _isPresenceConnected = false;
  bool _isPresenceConnecting = false;
  int _presenceReconnectAttempts = 0;
  Timer? _presenceReconnectTimer;

  WebSocketChannel? _messageChannel;
  StreamSubscription? _messageSubscription;
  bool _isMessageConnected = false;
  bool _isMessageConnecting = false;
  int _messageReconnectAttempts = 0;
  Timer? _messageReconnectTimer;

  bool _shouldReconnect = false;

  static const int _maxReconnectAttempts = 5;
  static const Duration _pendingConfirmTimeout = Duration(seconds: 4);

  bool get isPresenceConnected => _isPresenceConnected;
  bool get isMessageConnected => _isMessageConnected;
  bool get isConnected => _isPresenceConnected && _isMessageConnected;
  bool get isConnecting => _isPresenceConnecting || _isMessageConnecting;
  bool get showConnectionBanner =>
      !_isPresenceConnected || !_isMessageConnected;

  String? _currentUsername;
  String? get currentUsername => _currentUsername;

  int? _currentUserId;
  int? get currentUserId => _currentUserId;

  bool isMuteNotification = false;

  void _emitMessages() {
    if (!_messagesStreamController.isClosed) {
      _messagesStreamController.add(List.unmodifiable(_messages));
    }
  }

  String get _cacheKey => 'group_chat_history_$_chatId';

  Future<void> _loadCachedMessages() async {
    if (_chatId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        final cached = decoded.map((e) => ChatMessage.fromJson(e)).toList();
        if (cached.isNotEmpty) {
          _messages.clear();
          _messages.addAll(cached);
          _emitMessages();
        }
      }
    } catch (e) {
      debugPrint('❌ [Group] Failed to load cached messages: $e');
    }
  }

  Future<void> _saveCachedMessages() async {
    if (_chatId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final toCache = _messages.length > 60
          ? _messages
                .sublist(_messages.length - 60)
                .map((m) => m.toJson())
                .toList()
          : _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(toCache));
    } catch (e) {
      debugPrint('❌ [Group] Failed to save cached messages: $e');
    }
  }

  Future<void> init({
    required String? groupName,
    required String? groupImageUrl,
    int? chatId,
    String? currentUsername,
    int? currentUserId,
    Map<String, dynamic>? chat,
  }) async {
    _groupName = groupName;
    _groupImageUrl = groupImageUrl;
    _chatId = chatId;
    _currentUserId = currentUserId;
    _chat = chat;
    _syncAdminIds();

    if (currentUsername != null && currentUsername.isNotEmpty) {
      _currentUsername = currentUsername;
    } else {
      _currentUsername = await SharedPrefService.getUsername();
    }
    debugPrint('👤 [Group] Current username: $_currentUsername');

    if (chat != null && chat['members'] != null) {
      final membersList = chat['members'] as List<dynamic>?;
      if (membersList != null) {
        for (final m in membersList) {
          if (m is Map<String, dynamic>) {
            final user = m['user'] as Map<String, dynamic>?;
            final userId = user?['id'] as int?;
            final username = user?['username']?.toString();
            final isOnline = (m['is_online'] as bool?) ?? false;

            if (userId != null) {
              _memberPresence[userId] = GroupMemberPresence(
                userId: userId,
                username: username ?? 'User $userId',
                isOnline: isOnline,
              );
            }
          }
        }
      }
    }

    notifyListeners();

    if (_chatId == null) {
      return;
    }

    await _loadCachedMessages();
    fetchMessageHistory();

    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectPresenceSocket(token);
      await _connectMessageSocket(token);
    } else {
      debugPrint('❌ [Group] No access token for WS');
    }

    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _fetchLatestMessages();
    });
  }

  Future<void> _fetchLatestMessages() async {
    final cid = _chatId;
    if (cid == null) return;

    try {
      final response = await ApiService().getMessageList(chatId: cid);

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
          .toList()
          .reversed
          .toList();

      final confirmedCount = _messages.where((m) => !m.isPending).length;

      if (fetched.length > confirmedCount) {
        final pendingMessages = _messages.where((m) => m.isPending).toList();
        final oldPrependedCount =
            _messages.length - confirmedCount - pendingMessages.length;
        final preserved = oldPrependedCount > 0
            ? _messages.sublist(0, oldPrependedCount)
            : <ChatMessage>[];

        _messages.clear();
        _messages.addAll(preserved);
        _messages.addAll(fetched);
        _messages.addAll(pendingMessages);

        debugPrint('🔄 [Group] Polling: synced ${fetched.length} messages');
        _saveCachedMessages();
        _emitMessages();
      }
    } catch (e) {
      debugPrint('❌ [Group] Polling fetch failed: $e');
    }
  }

  Future<void> fetchMessageHistory() async {
    final cid = _chatId;
    if (cid == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      final response = await ApiService().getMessageList(chatId: cid);
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
      debugPrint(
        '[Group] Loaded ${fetched.length} messages | next: $_nextPageUrl',
      );
      _saveCachedMessages();
      _emitMessages();
    } catch (e) {
      _historyError = e.toString();
      debugPrint('❌ [Group] Failed to load message history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreHistory() async {
    final cid = _chatId;
    final nextUrl = _nextPageUrl;
    if (cid == null || nextUrl == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await ApiService().getMessageList(
        chatId: cid,
        nextPageUrl: nextUrl,
      );

      _nextPageUrl = response.next;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: item.isSentBy(_currentUsername),
              senderUsername: item.sender.username,
              senderProfileImage: item.sender.profileImage,
            ),
          )
          .toList();

      if (fetched.isEmpty) {
        debugPrint('✅ [Group] No more older messages');
        _nextPageUrl = null;
        return;
      }

      _messages.insertAll(0, fetched.reversed.toList());
      debugPrint(
        '[Group] Loaded ${fetched.length} older messages | next: $_nextPageUrl',
      );
      _saveCachedMessages();
      _emitMessages();
    } catch (e) {
      debugPrint('❌ [Group] Failed to load more history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> _connectPresenceSocket(String token) async {
    if (_isPresenceConnecting || _isPresenceConnected) return;
    if (_chatId == null) return;

    _isPresenceConnecting = true;
    notifyListeners();

    try {
      final url = '$_wsBaseUrl/ws/chat/group/$_chatId/?token=$token';

      _presenceChannel = WebSocketChannel.connect(Uri.parse(url));
      final presenceChannel = _presenceChannel;
      if (presenceChannel == null) return;
      await presenceChannel.ready;

      _presenceSubscription = presenceChannel.stream.listen(
        _onPresenceMessageReceived,
        onError: (error) {
          debugPrint('❌ [Group] Presence WS error: $error');
          if (_isUpgradeRejected(error.toString())) _shouldReconnect = false;
          _handlePresenceDisconnection();
        },
        onDone: () {
          debugPrint('🔌 [Group] Presence WS closed');
          _handlePresenceDisconnection();
        },
        cancelOnError: false,
      );

      _isPresenceConnected = true;
      _isPresenceConnecting = false;
      _presenceReconnectAttempts = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [Group] Presence WS connection failed: $e');
      if (_isUpgradeRejected(e.toString())) _shouldReconnect = false;
      _isPresenceConnected = false;
      _isPresenceConnecting = false;
      notifyListeners();
      _handlePresenceDisconnection();
    }
  }

  Future<void> _connectMessageSocket(String token) async {
    if (_isMessageConnecting || _isMessageConnected) return;
    if (_chatId == null) return;

    _isMessageConnecting = true;
    notifyListeners();

    try {
      final url = '$_wsBaseUrl/ws/chat/group/$_chatId/?token=$token';
      debugPrint('🔌 [Group] Connecting Message WS: $url');

      _messageChannel = WebSocketChannel.connect(Uri.parse(url));
      final messageChannel = _messageChannel;
      if (messageChannel == null) return;
      await messageChannel.ready;

      _messageSubscription = messageChannel.stream.listen(
        _onMessageReceived,
        onError: (error) {
          debugPrint('❌ [Group] Message WS error: $error');
          if (_isUpgradeRejected(error.toString())) _shouldReconnect = false;
          _handleMessageDisconnection();
        },
        onDone: () {
          _handleMessageDisconnection();
        },
        cancelOnError: false,
      );

      _isMessageConnected = true;
      _isMessageConnecting = false;
      _messageReconnectAttempts = 0;

      notifyListeners();
    } catch (e) {
      if (_isUpgradeRejected(e.toString())) _shouldReconnect = false;
      _isMessageConnected = false;
      _isMessageConnecting = false;
      notifyListeners();
      _handleMessageDisconnection();
    }
  }

  bool _isUpgradeRejected(String error) =>
      error.contains('not upgraded') ||
      error.contains('403') ||
      error.contains('404');

  Future<void> reconnect() async {
    debugPrint('🔄 [Group] Manual reconnect triggered');
    final token = await SharedPrefService.getToken();
    if (token == null || token.isEmpty) return;
    _shouldReconnect = true;
    if (!_isPresenceConnected && !_isPresenceConnecting) {
      await _connectPresenceSocket(token);
    }
    if (!_isMessageConnected && !_isMessageConnecting) {
      await _connectMessageSocket(token);
    }
  }

  void _onPresenceMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final String type = data['type']?.toString() ?? '';
      final int? userId = data['user_id'] as int?;

      // ── presence_update (server broadcast for all members) ──────────────
      if (type == 'presence_update') {
        if (userId == null) return;

        // ✅ Skip own presence
        if (userId == _currentUserId) {
          debugPrint('👤 [Group] Skipping own presence_update');
          return;
        }

        _upsertMemberOnline(
          userId: userId,
          username: data['username']?.toString(),
          isOnline: data['is_online'] == true,
        );
        return;
      }

      // ── USER_JOINED / USER_LEFT (legacy fallback) ───────────────────────
      if (type == 'USER_JOINED_CHAT' || type == 'USER_LEFT_CHAT') {
        if (userId == null || userId == _currentUserId) return;
        _upsertMemberOnline(
          userId: userId,
          username: data['username']?.toString(),
          isOnline: type == 'USER_JOINED_CHAT',
        );
        return;
      }

      // ── user_status (legacy fallback) ───────────────────────────────────
      if (type == 'user_status') {
        if (userId == null || userId == _currentUserId) return;
        _upsertMemberOnline(
          userId: userId,
          username: data['username']?.toString(),
          isOnline: data['status']?.toString() == 'online',
        );
        return;
      }

      // ── typing_status (server broadcast) ───────────────────────────────
      if (type == 'typing_status') {
        if (userId == null || userId == _currentUserId) return;
        _upsertMemberTyping(
          userId: userId,
          username: data['username']?.toString(),
          isTyping: data['is_typing'] == true,
        );
        return;
      }

      // ── typing_start / typing_stop (action echo) ────────────────────────
      if (type == 'typing_start' || type == 'typing_stop') {
        if (userId == null || userId == _currentUserId) return;
        _upsertMemberTyping(
          userId: userId,
          username: data['username']?.toString(),
          isTyping: type == 'typing_start',
        );
        return;
      }

      // ── old action-based typing (legacy) ────────────────────────────────
      if (data['action'] == 'typing') {
        if (userId == null || userId == _currentUserId) return;
        _upsertMemberTyping(
          userId: userId,
          username: data['username']?.toString(),
          isTyping: data['is_typing'] == true,
        );
        return;
      }

      // ── incoming message routed through presence socket ──────────────────
      if (type == 'new_message' || type == 'chat_message') {
        _onMessageReceived(raw);
        return;
      }

      debugPrint('⚠️ [Group] Unhandled presence type: $type');
    } catch (e) {
      debugPrint('❌ [Group] Error parsing presence message: $e');
    }
  }

  void _upsertMemberOnline({
    required int userId,
    String? username,
    required bool isOnline,
  }) {
    final existing = _memberPresence[userId];
    final finalUsername = username ?? existing?.username ?? 'User $userId';

    if (existing != null) {
      existing.isOnline = isOnline;
      existing.username = finalUsername;
    } else {
      _memberPresence[userId] = GroupMemberPresence(
        userId: userId,
        username: finalUsername,
        isOnline: isOnline,
      );
    }
    debugPrint(
      '👥 [Group] Member $finalUsername ($userId) → online: $isOnline',
    );
    notifyListeners();
  }

  void _upsertMemberTyping({
    required int userId,
    String? username,
    required bool isTyping,
  }) {
    final existing = _memberPresence[userId];
    final finalUsername = username ?? existing?.username ?? 'User $userId';

    if (existing != null) {
      existing.isTyping = isTyping;
      existing.username = finalUsername;
    } else {
      _memberPresence[userId] = GroupMemberPresence(
        userId: userId,
        username: finalUsername,
        isTyping: isTyping,
      );
    }

    if (isTyping) {
      _memberTypingTimers[userId]?.cancel();
      _memberTypingTimers[userId] = Timer(const Duration(seconds: 3), () {
        _memberPresence[userId]?.isTyping = false;
        _memberTypingTimers.remove(userId);
        notifyListeners();
      });
    } else {
      _memberTypingTimers[userId]?.cancel();
      _memberTypingTimers.remove(userId);
    }

    notifyListeners();
  }

  void _onMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final String type = data['type']?.toString() ?? '';

      if (type == 'read_receipt') return;

      // ✅ Accept both "new_message" and legacy "chat_message"
      if (type == 'new_message' || type == 'chat_message') {
        final msgMap = data['message'] as Map<String, dynamic>?;
        if (msgMap == null) return;

        final int? serverId = msgMap['id'] as int?;
        final String text = msgMap['text']?.toString() ?? '';
        if (text.isEmpty) return;

        // ✅ Deduplicate by server message id
        if (serverId != null && _messages.any((m) => m.id == serverId)) {
          debugPrint('⚠️ [Group] Duplicate message ignored: id=$serverId');
          return;
        }

        String? senderUsername;
        String? senderProfileImage;
        int? senderUserId;

        if (msgMap['sender'] is Map) {
          final sender = msgMap['sender'] as Map<String, dynamic>;
          senderUsername = sender['username']?.toString();
          senderProfileImage = sender['profile_image']?.toString();
          senderUserId = sender['id'] as int?;
        }

        // ✅ Use sender id (not username) to detect own messages — more reliable
        final bool isSentByMe =
            _currentUserId != null && senderUserId == _currentUserId;

        final DateTime serverTimestamp =
            DateTime.tryParse(msgMap['created_at']?.toString() ?? '') ??
            DateTime.now();

        // ✅ Confirm pending optimistic message
        if (isSentByMe) {
          final pendingIndex = _messages.lastIndexWhere(
            (m) => m.isSentByMe && m.isPending && m.text == text,
          );
          if (pendingIndex != -1) {
            _messages[pendingIndex] = ChatMessage(
              id: serverId,
              text: text,
              created_at: serverTimestamp,
              isSentByMe: true,
              isPending: false,
              senderUsername: senderUsername,
              senderProfileImage: senderProfileImage,
            );
            _saveCachedMessages();
            _emitMessages();
            return;
          }
        }

        _messages.add(
          ChatMessage(
            id: serverId,
            text: text,
            created_at: serverTimestamp,
            isSentByMe: isSentByMe,
            isPending: false,
            senderUsername: senderUsername,
            senderProfileImage: senderProfileImage,
          ),
        );

        // Clear typing for sender when message arrives
        if (senderUserId != null && senderUserId != _currentUserId) {
          _upsertMemberTyping(
            userId: senderUserId,
            username: senderUsername ?? 'User $senderUserId',
            isTyping: false,
          );
        }

        _saveCachedMessages();
        _emitMessages();
        return;
      }

      debugPrint('⚠️ [Group] Unknown WS message type: $type');
    } catch (e) {
      debugPrint('❌ [Group] Error parsing chat WS message: $e');
    }
  }

  void sendTypingStart() {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({'action': 'typing_start'}));
  }

  void stopTyping() {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({'action': 'typing_stop'}));
     _typingTimer?.cancel();
    sendTypingStop();
  }

  void markAsRead() {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({'action': 'mark_read'}));
  }

  void sendTypingStop() {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({'action': 'typing_stop'}));
  }

  void onUserTyping() {
    sendTypingStart();
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      sendTypingStop();
    });
  }

  void _handlePresenceDisconnection() {
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _presenceChannel?.sink.close(status.normalClosure);
    _presenceChannel = null;
    _isPresenceConnected = false;
    _isPresenceConnecting = false;
    notifyListeners();

    if (!_shouldReconnect) return;

    if (_presenceReconnectAttempts < _maxReconnectAttempts) {
      _presenceReconnectAttempts++;
      final delay = Duration(seconds: 2 * _presenceReconnectAttempts);
      debugPrint(
        '⏳ [Group] Presence reconnecting in ${delay.inSeconds}s '
        '(Attempt $_presenceReconnectAttempts/$_maxReconnectAttempts)…',
      );
      _presenceReconnectTimer?.cancel();
      _presenceReconnectTimer = Timer(delay, () async {
        final token = await SharedPrefService.getToken();
        if (token != null) await _connectPresenceSocket(token);
      });
    } else {
      debugPrint('❌ [Group] Max presence reconnect attempts reached.');
    }
  }

  void _handleMessageDisconnection() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _messageChannel?.sink.close(status.normalClosure);
    _messageChannel = null;
    _isMessageConnected = false;
    _isMessageConnecting = false;
    notifyListeners();

    if (!_shouldReconnect) return;

    if (_messageReconnectAttempts < _maxReconnectAttempts) {
      _messageReconnectAttempts++;
      final delay = Duration(seconds: 2 * _messageReconnectAttempts);
      debugPrint(
        '⏳ [Group] Message WS reconnecting in ${delay.inSeconds}s '
        '(Attempt $_messageReconnectAttempts/$_maxReconnectAttempts)…',
      );
      _messageReconnectTimer?.cancel();
      _messageReconnectTimer = Timer(delay, () async {
        final token = await SharedPrefService.getToken();
        if (token != null) await _connectMessageSocket(token);
      });
    } else {
      debugPrint('❌ [Group] Max message reconnect attempts reached.');
    }
  }

  void _cleanupConnection() {
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _presenceChannel?.sink.close(status.normalClosure);
    _presenceChannel = null;
    _isPresenceConnected = false;
    _isPresenceConnecting = false;

    _messageSubscription?.cancel();
    _messageSubscription = null;
    _messageChannel?.sink.close(status.normalClosure);
    _messageChannel = null;
    _isMessageConnected = false;
    _isMessageConnecting = false;

    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_chatId == null) return;

    final optimistic = ChatMessage(
      text: trimmed,
      created_at: DateTime.now(),
      isSentByMe: true,
      isPending: true,
      senderUsername: _currentUsername,
    );
    _messages.add(optimistic);
    _emitMessages();

    try {
      final cid = _chatId;
      if (cid != null) {
        await ApiService().sendMessage(chatId: cid, text: trimmed);
      }

      Future.delayed(_pendingConfirmTimeout, () {
        final pendingIndex = _messages.lastIndexWhere(
          (m) => m.isSentByMe && m.isPending && m.text == trimmed,
        );
        if (pendingIndex != -1) {
          debugPrint(
            '⏱ [Group] Fallback: auto-confirming pending message: $trimmed',
          );
          _messages[pendingIndex] = ChatMessage(
            text: trimmed,
            created_at: _messages[pendingIndex].created_at,
            isSentByMe: true,
            isPending: false,
            senderUsername: _currentUsername,
          );
          _saveCachedMessages();
          _emitMessages();
        }
      });
    } catch (e) {
      debugPrint('❌ [Group] sendMessage API failed: $e');
      final pendingIndex = _messages.lastIndexWhere(
        (m) => m.isSentByMe && m.isPending && m.text == trimmed,
      );
      if (pendingIndex != -1) {
        _messages[pendingIndex] = ChatMessage(
          text: trimmed,
          created_at: _messages[pendingIndex].created_at,
          isSentByMe: true,
          isPending: false,
          isFailed: true,
          senderUsername: _currentUsername,
        );
        _saveCachedMessages();
        _emitMessages();
      }
    }
  }

  void toggleMuteNotification(bool value) {
    isMuteNotification = value;
    notifyListeners();
  }

  Future<bool> renameGroup(String title) async {
    if (_chatId == null) return false;
    _isRenaming = true;
    notifyListeners();
    try {
      final res = await ApiService().renameGroup(
        chatId: _chatId!,
        newTitle: title,
      );
      _isRenaming = false;
      if (res['success'] == true && res['new_title'] != null) {
        _groupName = res['new_title'] as String;
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isRenaming = false;
      notifyListeners();
      return false;
    }
  }

  void updateGroupPicture(String url) {
    _groupImageUrl = url;
    if (_chat != null) {
      _chat!['profile_url'] = url;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> deleteGroup() async {
    if (_chatId == null) return {'success': false, 'message': 'No chat ID'};
    try {
      return await ApiService().deleteGroup(chatId: _chatId!);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> leaveGroup() async {
    if (_chatId == null) return {'success': false, 'message': 'No chat ID'};
    try {
      return await ApiService().leaveGroup(chatId: _chatId!);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  void removeMemberOptimistically(int userId) {
    if (_chat == null || _chat!['members'] == null) return;
    final membersList = List<Map<String, dynamic>>.from(
      (_chat!['members'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    membersList.removeWhere((m) => (m['user'] as Map?)?['id'] == userId);
    _chat = {..._chat!, 'members': membersList};
    // Also remove from adminIds if they were admin
    _adminIds.remove(userId);
    notifyListeners();
  }

  Future<bool> removeMember(int userId) async {
    if (_chatId == null) return false;
    try {
      final res = await ApiService().removeMember(
        chatId: _chatId!,
        userId: userId,
      );
      if (res['success'] == true) {
        await _refreshChatData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('removeMember error: $e');
      return false;
    }
  }

  Future<bool> makeAdmin(int userId) async {
    if (_chatId == null) return false;
    try {
      final res = await ApiService().makeAdmin(
        chatId: _chatId!,
        userId: userId,
      );

      if (res['message'] != null) {
        await _refreshChatData();
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('makeAdmin DioError: ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('makeAdmin error: $e');
      return false;
    }
  }

  void updateMemberAdminStatus(int userId, bool isAdminStatus) {
    if (isAdminStatus) {
      _adminIds.add(userId);
    } else {
      _adminIds.remove(userId);
    }
    notifyListeners();
  }

  Future<void> _refreshChatData() async {
    if (_chatId == null) return;
    try {
      final freshChat = await ApiService().getGroupChatInfo(chatId: _chatId!);
      _chat = freshChat;

      _syncAdminIds();

      if (_chat != null && _chat!['members'] != null) {
        final membersList = _chat!['members'] as List<dynamic>;
        for (final m in membersList) {
          if (m is Map<String, dynamic>) {
            final user = m['user'] as Map<String, dynamic>?;
            final uid = user?['id'] as int?;
            final username = user?['username']?.toString();
            if (uid != null) {
              final existing = _memberPresence[uid];
              if (existing != null) {
                existing.username = username ?? existing.username;
              } else {
                _memberPresence[uid] = GroupMemberPresence(
                  userId: uid,
                  username: username ?? 'User $uid',
                );
              }
            }
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [Group] Failed to refresh chat data: $e');
    }
  }

  /// Public wrapper so UI can trigger a refresh directly
  Future<void> refreshChatData() => _refreshChatData();

  Future<bool> addGroupMembers(
    List<int> userIds, [
    List<Map<String, dynamic>>? newUsers,
  ]) async {
    if (_chatId == null) return false;
    try {
      final res = await ApiService().addGroupChatMembers(
        groupChatId: _chatId!,
        members: userIds,
      );

      if (res['success'] == true) {
        await _refreshChatData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void addMembersOptimistically(List<Map<String, dynamic>> newUsers) {
    if (_chat == null || _chat!['members'] == null) return;

    final membersList = List<Map<String, dynamic>>.from(
      (_chat!['members'] as List).map((e) => Map<String, dynamic>.from(e)),
    );

    final existingIds = membersList
        .map((m) => (m['user'] as Map?)?['id'])
        .whereType<int>()
        .toSet();

    for (final userObj in newUsers) {
      final id = userObj['id'];
      if (id != null && !existingIds.contains(id as int)) {
        final normalized = Map<String, dynamic>.from(userObj);
        normalized['profile_image'] ??=
            userObj['avatar'] ??
            userObj['profile_picture_url'] ??
            userObj['image'];

        membersList.add({'is_admin': false, 'user': normalized});
        existingIds.add(id);
      }
    }

    _chat = {..._chat!, 'members': membersList};
    notifyListeners();
  }

  void rollbackOptimisticMembers(Set<int> failedIds) {
    if (_chat == null || _chat!['members'] == null) return;

    final membersList = List<Map<String, dynamic>>.from(
      (_chat!['members'] as List).map((e) => Map<String, dynamic>.from(e)),
    );

    _chat = {
      ..._chat!,
      'members': membersList
          .where((m) => !failedIds.contains((m['user'] as Map?)?['id'] as int?))
          .toList(),
    };

    notifyListeners();
  }

  void reset() {
    _shouldReconnect = false;
    _presenceReconnectTimer?.cancel();
    _messageReconnectTimer?.cancel();
    _cleanupConnection();

    _memberPresence.clear();
    _adminIds.clear();
    for (final t in _memberTypingTimers.values) {
      t.cancel();
    }
    _memberTypingTimers.clear();

    _groupName = null;
    _groupImageUrl = null;
    _chatId = null;
    _currentUsername = null;
    _currentUserId = null;
    _messages.clear();
    _presenceReconnectAttempts = 0;
    _messageReconnectAttempts = 0;
    _nextPageUrl = null;
    _historyError = null;
    isMuteNotification = false;
    _typingTimer?.cancel();
    _pollingTimer?.cancel();

    notifyListeners();
  }

  @override
  void dispose() {
    _shouldReconnect = false;
    _presenceReconnectTimer?.cancel();
    _messageReconnectTimer?.cancel();
    _cleanupConnection();
    _messagesStreamController.close();
    _typingTimer?.cancel();
    _pollingTimer?.cancel();
    for (final t in _memberTypingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
