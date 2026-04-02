// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
  bool get hasMoreHistory => _nextPageUrl != null;

  // ── WebSocket state ────────────────────────────────────────────────────────
  static const String _wsBaseUrl = 'wss://testbackend.polzet.in';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  // ✅ TWO separate booleans — never mix them
  bool _isConnected = false;    // YOUR socket is alive
  bool _isMemberOnline = false; // member's presence from WS events only

  bool _isConnecting = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  static const Duration _pendingConfirmTimeout = Duration(seconds: 4);
  static const int _maxReconnectAttempts = 5;

  // ✅ Getters — clearly separated
  bool get isConnected => _isConnected;         // use for WS logic only
  bool get isMemberOnline => _isMemberOnline;   // use in UI for Online/Offline
  bool get isConnecting => _isConnecting;
  bool get showConnectionBanner => !_isConnected;

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

    await fetchMessageHistory();

    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectWebSocket(token);
    } else {
      debugPrint('❌ PrivateChatProvider: No access token for WS');
    }

    _startPolling();
  }

  // ── Polling ────────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      debugPrint('🔄 Polling: fetching latest messages...');
      await _fetchLatestMessages();
    });
  }

  Future<void> _fetchLatestMessages() async {
    if (_chatId == null) return;

    try {
      final response = await ApiService().getMessageList(chatId: _chatId!);

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

      if (fetched.length > _messages.where((m) => !m.isPending).length) {
        final pendingMessages = _messages.where((m) => m.isPending).toList();
        _messages.clear();
        _messages.addAll(fetched);
        _messages.addAll(pendingMessages);
        debugPrint('🔄 Polling: ${fetched.length} messages synced');
        _emitMessages();
      }
    } catch (e) {
      debugPrint('❌ Polling fetch failed: $e');
    }
  }

  // ── REST: fetch initial message history ────────────────────────────────────
  Future<void> fetchMessageHistory() async {
    if (_chatId == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      final response = await ApiService().getMessageList(chatId: _chatId!);
      _nextPageUrl = response.next;

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
      debugPrint('✅ Loaded ${fetched.length} messages');
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
    if (_chatId == null || _nextPageUrl == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await ApiService().getMessageList(
        chatId: _chatId!,
        nextPageUrl: _nextPageUrl,
      );
      _nextPageUrl = response.next;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              text: item.message,
              created_at: item.created_at,
              isSentByMe: item.isSentBy(_currentUsername),
            ),
          )
          .toList();

      _messages.insertAll(0, fetched.reversed.toList());
      debugPrint('✅ Loaded ${fetched.length} more messages');
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Failed to load more history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────
  Future<void> _connectWebSocket(String token) async {
    if (_isConnecting || _isConnected) return; // ✅ guard uses _isConnected only
    if (_chatId == null) {
      debugPrint('❌ Cannot connect WS — chatId is null');
      return;
    }

    _isConnecting = true;
    notifyListeners();

    try {
      final wsUrl = '$_wsBaseUrl/ws/chats/$_chatId/presence/?token=$token';
      debugPrint('🔌 Connecting to Chat WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _wsSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (error) {
          debugPrint('❌ Chat WS error: $error');
          if (_isUpgradeRejected(error.toString())) {
            _shouldReconnect = false;
          }
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('🔌 Chat WebSocket closed');
          _handleDisconnection();
        },
        cancelOnError: false,
      );

      _isConnected = true;   // ✅ YOUR socket is alive
      _isConnecting = false;
      _reconnectAttempts = 0;
      // ✅ _isMemberOnline is NOT touched here — only WS events set it
      debugPrint('✅ Chat WebSocket connected');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Chat WS connection failed: $e');
      if (_isUpgradeRejected(e.toString())) _shouldReconnect = false;
      _isConnected = false;  // ✅ YOUR socket failed
      _isConnecting = false;
      // ✅ _isMemberOnline is NOT touched here
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
    debugPrint('🔄 Manual reconnect triggered');
    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectWebSocket(token);
    }
  }

  // ── Member user id ─────────────────────────────────────────────────────────
  void setMemberUserId(int userId) {
    _memberUserId = userId;
  }

  // ── Incoming WS message ────────────────────────────────────────────────────
  void _onMessageReceived(dynamic raw) {
   // debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
   // debugPrint('📨 RAW WS RESPONSE: $raw');
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;

      // ── Presence: USER_JOINED_CHAT / USER_LEFT_CHAT ───────────────────────
      // ✅ ONLY place where _isMemberOnline is ever set
      if (data['type'] == 'USER_JOINED_CHAT' ||
          data['type'] == 'USER_LEFT_CHAT') {
        final userId = data['user_id'];
        if (userId == _memberUserId) {
          _isMemberOnline = data['type'] == 'USER_JOINED_CHAT';
          debugPrint(
            '👤 Member online status: $_isMemberOnline '
            '(event: ${data['type']})',
          );
          notifyListeners();
        }
        return;
      }

      // ── Typing indicator ──────────────────────────────────────────────────
      if (data['action'] == 'typing') {
        final userId = data['user_id'];
        if (userId == _memberUserId) {
          isMemberTyping = data['is_typing'] == true;
          notifyListeners();
        }
        return;
      }

      // ── Chat message ──────────────────────────────────────────────────────
      const encoder = JsonEncoder.withIndent('  ');
      debugPrint('📦 PARSED WS DATA:\n${encoder.convert(data)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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

      _messages.add(
        ChatMessage(
          text: text,
          created_at: serverTimestamp,
          isSentByMe: isSentByMe,
          isPending: false,
        ),
      );
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Error parsing WS message: $e');
    }
  }

  // ── Typing ─────────────────────────────────────────────────────────────────
  void sendTyping(bool isTyping) {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({'typing': isTyping}));
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
  void _handleDisconnection() {
    _cleanupConnection();
    if (!_shouldReconnect) return;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: 2 * _reconnectAttempts);
      debugPrint(
        '⏳ Reconnecting in ${delay.inSeconds}s '
        '(Attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
      );
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        final token = await SharedPrefService.getToken();
        if (token != null) _connectWebSocket(token);
      });
    } else {
      debugPrint('❌ Max reconnect attempts reached.');
    }
  }

  void _cleanupConnection() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _isConnected = false;   // ✅ YOUR socket dropped
    _isConnecting = false;
    // ✅ _isMemberOnline NOT reset here — they may still be online
    //    it will be updated when USER_LEFT_CHAT event arrives
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
      await ApiService().sendMessage(chatId: _chatId!, text: trimmed);
      debugPrint('✅ Message delivered to server: $trimmed');

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
    _reconnectTimer?.cancel();
    _cleanupConnection(); // sets _isConnected = false

    _isMemberOnline = false; // ✅ reset member presence on full reset
    isMemberTyping = false;
    _memberName = null;
    _profileUrl = null;
    _chatId = null;
    _currentUsername = null;
    _messages.clear();
    _reconnectAttempts = 0;
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
    _reconnectTimer?.cancel();
    _cleanupConnection();
    _messagesStreamController.close();
    _typingTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}