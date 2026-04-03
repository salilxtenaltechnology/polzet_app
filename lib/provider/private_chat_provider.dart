// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../models/message/message_model.dart';
import '../../data/token/shared_preferences.dart';
import '../api/services/api_service.dart';

class PrivateChatProvider extends ChangeNotifier {
  String? _memberName;
  String? _profileUrl;
  int? _chatId;

  String? get memberName => _memberName;
  String? get profileUrl => _profileUrl;
  int? get chatId => _chatId;

  bool isMemberTyping = false;
  int? _memberUserId;
  Timer? _typingTimer;
  Timer? _pollingTimer;

  // ── Stream for SILENT real-time message updates ────────────────────────────
  final StreamController<List<ChatMessage>> _messagesStreamController =
      StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get messagesStream =>
      _messagesStreamController.stream;

  // ── Message state ──────────────────────────────────────────────────────────
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

  // ── Loading / error state ──────────────────────────────────────────────────
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  String? _historyError;
  String? get historyError => _historyError;

  String? _nextPageUrl;
  String? _previousPageUrl;
  bool get hasMoreHistory => _nextPageUrl != null;

  // ── WebSocket state ────────────────────────────────────────────────────────
  static const String _wsBaseUrl = 'wss://testbackend.polzet.in';

  // Presence WebSocket (online/offline/typing)
  WebSocketChannel? _presenceChannel;
  StreamSubscription? _presenceSubscription;
  bool _isPresenceConnected = false;
  bool _isPresenceConnecting = false;
  int _presenceReconnectAttempts = 0;
  Timer? _presenceReconnectTimer;

  // Message WebSocket (chat_message / read_receipt)
  WebSocketChannel? _messageChannel;
  StreamSubscription? _messageSubscription;
  bool _isMessageConnected = false;
  bool _isMessageConnecting = false;
  int _messageReconnectAttempts = 0;
  Timer? _messageReconnectTimer;

  bool _shouldReconnect = false;

  static const int _maxReconnectAttempts = 5;
  static const Duration _pendingConfirmTimeout = Duration(seconds: 4);

  // ── Member online state — set ONLY by WS presence events ──────────────────
  bool _isMemberOnline = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isPresenceConnected => _isPresenceConnected;
  bool get isMessageConnected => _isMessageConnected;
  bool get isConnected => _isPresenceConnected && _isMessageConnected;
  bool get isConnecting => _isPresenceConnecting || _isMessageConnecting;
  bool get showConnectionBanner =>
      !_isPresenceConnected || !_isMessageConnected;
  bool get isMemberOnline => _isMemberOnline;

  // ── Current user ──────────────────────────────────────────────────────────
  String? _currentUsername;

  // ── Chat settings ─────────────────────────────────────────────────────────
  bool isMuteNotification = false;
  bool isProtectedChat = false;
  bool isHideChat = false;
  bool isHideChatHistory = false;

  bool _isBlocking = false;
  bool get isBlocking => _isBlocking;

  // ── Emit helpers ───────────────────────────────────────────────────────────
  void _emitMessages() {
    if (!_messagesStreamController.isClosed) {
      _messagesStreamController.add(List.unmodifiable(_messages));
    }
  }

  // ── Caching ────────────────────────────────────────────────────────────────
  String get _cacheKey => 'chat_history_$_chatId';

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
          debugPrint('✅ Loaded ${cached.length} messages from CACHE');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to load cached messages: $e');
    }
  }

  Future<void> _saveCachedMessages() async {
    if (_chatId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final toCache = _messages.length > 60
          ? _messages.sublist(_messages.length - 60).map((m) => m.toJson()).toList()
          : _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(toCache));
    } catch (e) {
      debugPrint('❌ Failed to save cached messages: $e');
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init({
    required String? memberName,
    required String? profileUrl,
    int? chatId,
    String? currentUsername,
  }) async {
    _memberName = memberName;
    _profileUrl = profileUrl;
    _chatId = chatId;

    if (currentUsername != null && currentUsername.isNotEmpty) {
      _currentUsername = currentUsername;
    } else {
      _currentUsername = await SharedPrefService.getUsername();
    }
    debugPrint('👤 Current username: $_currentUsername');

    notifyListeners();

    if (_chatId == null) {
      debugPrint('⚠️ chatId is null — skipping history fetch and WS connect');
      return;
    }

    await _loadCachedMessages();

    // Call fetch history without awaiting so UI does not block
    fetchMessageHistory();

    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectPresenceSocket(token);
      await _connectMessageSocket(token);
    } else {
      debugPrint('❌ PrivateChatProvider: No access token for WS');
    }

    _startPolling();
  }

  // ── Polling ────────────────────────────────────────────────────────────────
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
      // Always fetch from the base URL to get latest page
      final response = await ApiService().getMessageList(chatId: cid);

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: _currentUsername != null
                  ? item.isSentBy(_currentUsername)
                  : false,
            ),
          )
          .toList()
          .reversed
          .toList();

      final confirmedCount = _messages.where((m) => !m.isPending).length;

      if (fetched.length > confirmedCount) {
        final pendingMessages = _messages.where((m) => m.isPending).toList();

        // Keep prepended older messages + replace confirmed page with fresh fetch
        final oldPrependedCount =
            _messages.length - confirmedCount - pendingMessages.length;

        final preserved = oldPrependedCount > 0
            ? _messages.sublist(0, oldPrependedCount)
            : <ChatMessage>[];

        _messages.clear();
        _messages.addAll(preserved);
        _messages.addAll(fetched);
        _messages.addAll(pendingMessages);

        debugPrint('🔄 Polling: synced ${fetched.length} messages');
        _saveCachedMessages();
        _emitMessages();
      }
    } catch (e) {
      debugPrint('❌ Polling fetch failed: $e');
    }
  }
  // ── REST: fetch initial message history ────────────────────────────────────
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
      _previousPageUrl = response.previous;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: _currentUsername != null
                  ? item.isSentBy(_currentUsername)
                  : false,
            ),
          )
          .toList();

      _messages.clear();
      _messages.addAll(fetched.reversed.toList());
      debugPrint(
        '✅ Loaded ${fetched.length} messages | '
        'next: $_nextPageUrl | previous: $_previousPageUrl',
      );
      _saveCachedMessages();
      _emitMessages();
    } catch (e) {
      _historyError = e.toString();
      debugPrint('❌ Failed to load message history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── REST: paginated older messages ─────────────────────────────────────────
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
      _previousPageUrl = response.previous;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: item.isSentBy(_currentUsername),
            ),
          )
          .toList();

      if (fetched.isEmpty) {
        debugPrint('✅ No more older messages');
        _nextPageUrl = null;
        return;
      }

      _messages.insertAll(0, fetched.reversed.toList());
      debugPrint(
        '✅ Loaded ${fetched.length} older messages | '
        'next: $_nextPageUrl | previous: $_previousPageUrl',
      );
      _saveCachedMessages();
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Failed to load more history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── Presence WebSocket ─────────────────────────────────────────────────────
  Future<void> _connectPresenceSocket(String token) async {
    if (_isPresenceConnecting || _isPresenceConnected) return;
    if (_chatId == null) return;

    _isPresenceConnecting = true;
    notifyListeners();

    try {
      final url = '$_wsBaseUrl/ws/chats/$_chatId/presence/?token=$token';
     // debugPrint('🔌 Connecting Presence WS: $url');

      _presenceChannel = WebSocketChannel.connect(Uri.parse(url));
      final presenceChannel = _presenceChannel;
      if (presenceChannel == null) return;
      await presenceChannel.ready;

      _presenceSubscription = presenceChannel.stream.listen(
        _onPresenceMessageReceived,
        onError: (error) {
          debugPrint('❌ Presence WS error: $error');
          if (_isUpgradeRejected(error.toString())) {
            _shouldReconnect = false;
          }
          _handlePresenceDisconnection();
        },
        onDone: () {
          debugPrint('🔌 Presence WS closed');
          _handlePresenceDisconnection();
        },
        cancelOnError: false,
      );

      _isPresenceConnected = true;
      _isPresenceConnecting = false;
      _presenceReconnectAttempts = 0;
      debugPrint('✅ Presence WebSocket connected');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Presence WS connection failed: $e');
      if (_isUpgradeRejected(e.toString())) _shouldReconnect = false;
      _isPresenceConnected = false;
      _isPresenceConnecting = false;
      notifyListeners();
      _handlePresenceDisconnection();
    }
  }

  // ── Message WebSocket ──────────────────────────────────────────────────────
  Future<void> _connectMessageSocket(String token) async {
    if (_isMessageConnecting || _isMessageConnected) return;
    if (_chatId == null) return;

    _isMessageConnecting = true;
    notifyListeners();

    try {
      final url = '$_wsBaseUrl/ws/chat/$_chatId/?token=$token';
     // debugPrint('🔌 Connecting Message WS: $url');

      _messageChannel = WebSocketChannel.connect(Uri.parse(url));
      final messageChannel = _messageChannel;
      if (messageChannel == null) return;
      await messageChannel.ready;

      _messageSubscription = messageChannel.stream.listen(
        _onMessageReceived,
        onError: (error) {
          debugPrint('❌ Message WS error: $error');
          if (_isUpgradeRejected(error.toString())) {
            _shouldReconnect = false;
          }
          _handleMessageDisconnection();
        },
        onDone: () {
          debugPrint('🔌 Message WS closed');
          _handleMessageDisconnection();
        },
        cancelOnError: false,
      );

      _isMessageConnected = true;
      _isMessageConnecting = false;
      _messageReconnectAttempts = 0;
      debugPrint('✅ Message WebSocket connected');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Message WS connection failed: $e');
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

  // ── Manual reconnect ───────────────────────────────────────────────────────
  Future<void> reconnect() async {
    debugPrint('🔄 Manual reconnect triggered');
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

  // ── Member user id ─────────────────────────────────────────────────────────
  void setMemberUserId(int userId) {
    _memberUserId = userId;
  }

  // ── Presence WS handler (online / offline / typing only) ──────────────────
  void _onPresenceMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;

      // ── Online / Offline ────────────────────────────────────────────────
      if (data['type'] == 'USER_JOINED_CHAT' ||
          data['type'] == 'USER_LEFT_CHAT') {
        final userId = data['user_id'];
        if (userId == _memberUserId) {
          _isMemberOnline = data['type'] == 'USER_JOINED_CHAT';
          debugPrint('👤 Member online: $_isMemberOnline (${data['type']})');
          notifyListeners();
        }
        return;
      }

      // ── Typing ──────────────────────────────────────────────────────────
      if (data['action'] == 'typing') {
        final userId = data['user_id'];
        if (userId == _memberUserId) {
          isMemberTyping = data['is_typing'] == true;
          notifyListeners();
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Error parsing presence message: $e');
    }
  }

  // ── Message WS handler (chat_message / read_receipt) ──────────────────────
  void _onMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final String type = data['type']?.toString() ?? '';

      // ── Read receipt ─────────────────────────────────────────────────────
      if (type == 'read_receipt') {
        debugPrint(
          '📖 Read receipt — chat: ${data['chat_id']}, '
          'user: ${data['user_id']}, at: ${data['read_at']}',
        );
        // TODO: mark messages as read in UI if needed
        return;
      }

      // ── Chat message ──────────────────────────────────────────────────────
      if (type == 'chat_message') {
        final msgMap = data['message'] as Map<String, dynamic>?;
        if (msgMap == null) {
          debugPrint('⚠️ chat_message received but "message" field is null');
          return;
        }

        const encoder = JsonEncoder.withIndent('  ');
        debugPrint('📦 PARSED CHAT MESSAGE:\n${encoder.convert(msgMap)}');

        final String text = msgMap['text']?.toString() ?? '';
        if (text.isEmpty) return;

        String? senderUsername;
        if (msgMap['sender'] is Map) {
          senderUsername = (msgMap['sender'] as Map)['username']?.toString();
        }

        final bool isSentByMe =
            _currentUsername != null && senderUsername == _currentUsername;

        final DateTime serverTimestamp =
            DateTime.tryParse(msgMap['created_at']?.toString() ?? '') ??
            DateTime.now();

        // ── Confirm pending message if sent by me ─────────────────────────
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
            _saveCachedMessages();
            _emitMessages();
            return;
          }
        }

        // ── New incoming message ──────────────────────────────────────────
        _messages.add(
          ChatMessage(
            text: text,
            created_at: serverTimestamp,
            isSentByMe: isSentByMe,
            isPending: false,
          ),
        );
        _saveCachedMessages();
        _emitMessages();
        return;
      }

      debugPrint('⚠️ Unknown WS message type: $type');
    } catch (e) {
      debugPrint('❌ Error parsing chat WS message: $e');
    }
  }

  void sendTyping(bool isTyping) {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({
      'action': 'typing',
      'is_typing': isTyping,
    }));
  }

  void onUserTyping() {
    sendTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      sendTyping(false);
    });
  }

  void stopTyping() {
    _typingTimer?.cancel();
    sendTyping(false);
  }

  // ── Disconnection handling ─────────────────────────────────────────────────
  void _handlePresenceDisconnection() {
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _presenceChannel?.sink.close(status.normalClosure);
    _presenceChannel = null;
    _isPresenceConnected = false;
    _isPresenceConnecting = false;
    // NOTE: _isMemberOnline is NOT reset here — updated only by WS events
    notifyListeners();

    if (!_shouldReconnect) return;

    if (_presenceReconnectAttempts < _maxReconnectAttempts) {
      _presenceReconnectAttempts++;
      final delay = Duration(seconds: 2 * _presenceReconnectAttempts);
      debugPrint(
        '⏳ Presence reconnecting in ${delay.inSeconds}s '
        '(Attempt $_presenceReconnectAttempts/$_maxReconnectAttempts)...',
      );
      _presenceReconnectTimer?.cancel();
      _presenceReconnectTimer = Timer(delay, () async {
        final token = await SharedPrefService.getToken();
        if (token != null) await _connectPresenceSocket(token);
      });
    } else {
      debugPrint('❌ Max presence reconnect attempts reached.');
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
        '⏳ Message WS reconnecting in ${delay.inSeconds}s '
        '(Attempt $_messageReconnectAttempts/$_maxReconnectAttempts)...',
      );
      _messageReconnectTimer?.cancel();
      _messageReconnectTimer = Timer(delay, () async {
        final token = await SharedPrefService.getToken();
        if (token != null) await _connectMessageSocket(token);
      });
    } else {
      debugPrint('❌ Max message reconnect attempts reached.');
    }
  }

  void _cleanupConnection() {
    // Presence
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _presenceChannel?.sink.close(status.normalClosure);
    _presenceChannel = null;
    _isPresenceConnected = false;
    _isPresenceConnecting = false;

    // Messages
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _messageChannel?.sink.close(status.normalClosure);
    _messageChannel = null;
    _isMessageConnected = false;
    _isMessageConnecting = false;

    notifyListeners();
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_chatId == null) return;

    final optimistic = ChatMessage(
      text: trimmed,
      created_at: DateTime.now(),
      isSentByMe: true,
      isPending: true,
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
          debugPrint('⏱ Fallback: auto-confirming pending message: $trimmed');
          _messages[pendingIndex] = ChatMessage(
            text: trimmed,
            created_at: _messages[pendingIndex].created_at,
            isSentByMe: true,
            isPending: false,
          );
          _saveCachedMessages();
          _emitMessages();
        }
      });
    } catch (e) {
      debugPrint('❌ sendMessage API failed: $e');
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
        );
        _saveCachedMessages();
        _emitMessages();
      }
    }
  }

  // ── Block / Unblock ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> blockUser(int userId) async {
    _isBlocking = true;
    notifyListeners();
    try {
      final result = await ApiService().blockUser(userId);
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      _isBlocking = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> unblockUser(int userId) async {
    _isBlocking = true;
    notifyListeners();
    try {
      final result = await ApiService().unblockUser(userId);
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      _isBlocking = false;
      notifyListeners();
    }
  }

  // ── Toggles ────────────────────────────────────────────────────────────────
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

  // ── Reset / Dispose ────────────────────────────────────────────────────────
  void reset() {
    _shouldReconnect = false;
    _presenceReconnectTimer?.cancel();
    _messageReconnectTimer?.cancel();
    _cleanupConnection();

    _isMemberOnline = false;
    isMemberTyping = false;
    _memberName = null;
    _profileUrl = null;
    _chatId = null;
    _currentUsername = null;
    _messages.clear();
    _presenceReconnectAttempts = 0;
    _messageReconnectAttempts = 0;
    _nextPageUrl = null;
    _historyError = null;
    isMuteNotification = false;
    isProtectedChat = false;
    isHideChat = false;
    isHideChatHistory = false;
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
    super.dispose();
  }
}
