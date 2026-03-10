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

  // ── Stream for SILENT real-time message updates ────────────────────────────
  // Only this stream triggers StreamBuilder rebuilds — notifyListeners() is
  // reserved ONLY for non-message state: connection status, loading flags, errors.
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

  // ── Loading / error state — these DO call notifyListeners() ───────────────
  // But they are separated from message updates so the StreamBuilder is unaffected.
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  String? _historyError;
  String? get historyError => _historyError;

  String? _nextPageUrl;
  bool get hasMoreHistory => _nextPageUrl != null;

  late bool _isUserBlock;


  // ── WebSocket state ────────────────────────────────────────────────────────
  static const String _wsBaseUrl = 'wss://testbackend.polzet.in';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // After sendMessage REST succeeds, we wait this long for WS echo before
  // auto-confirming the pending optimistic message ourselves.
  static const Duration _pendingConfirmTimeout = Duration(seconds: 4);
  static const int _maxReconnectAttempts = 5;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get showConnectionBanner => !_isConnected;

  // ── Current user ──────────────────────────────────────────────────────────
  String? _currentUsername;

  // ── Chat settings ──────────────────────────────────────────────────────────
  bool isMuteNotification = false;
  bool isProtectedChat = false;
  bool isHideChat = false;
  bool isHideChatHistory = false;

  // Block user settings can be added here when that feature is implemented
  bool _isBlocking = false;
  bool get isBlocking => _isBlocking;


  // ── Emit helpers ───────────────────────────────────────────────────────────

  /// Pushes the current message list into the stream.
  /// This is the ONLY way the message list UI updates — zero notifyListeners().
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

    // Only notify for initial metadata — not for messages
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
  }

  // ── REST: fetch initial message history ────────────────────────────────────
  Future<void> fetchMessageHistory() async {
    if (_chatId == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners(); // ✅ only notifies for loading spinner / error banner

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
      // API returns newest→oldest; reverse for top→bottom display
      _messages.addAll(fetched.reversed.toList());

      debugPrint('✅ Loaded ${fetched.length} messages');

      // ✅ SILENT update — StreamBuilder rebuilds, nothing else does
      _emitMessages();
    } catch (e) {
      _historyError = e.toString();
      debugPrint('❌ Failed to load message history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners(); // clears spinner, shows error banner if needed
    }
  }

  // ── REST: paginated older messages ─────────────────────────────────────────
  Future<void> fetchMoreHistory() async {
    if (_chatId == null || _nextPageUrl == null) return;
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    notifyListeners(); // shows top spinner

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

      // Prepend older messages at the top
      _messages.insertAll(0, fetched.reversed.toList());
      debugPrint('✅ Loaded ${fetched.length} more messages');

      // ✅ SILENT update
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
    if (_isConnecting || _isConnected) return;
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

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      debugPrint('✅ Chat WebSocket connected');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Chat WS connection failed: $e');
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
    debugPrint('🔄 Manual reconnect triggered');
    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;
      await _connectWebSocket(token);
    }
  }

  // ── Incoming WS message ────────────────────────────────────────────────────
  void _onMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      debugPrint('📨 WS message received: $data');

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
        // ✅ Confirm the matching pending optimistic message with server timestamp
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
          // ✅ SILENT — only StreamBuilder sees this
          _emitMessages();
          return;
        }
        // Edge case: no matching pending found — fall through to add normally
      }

      _messages.add(
        ChatMessage(
          text: text,
          created_at: serverTimestamp,
          isSentByMe: isSentByMe,
          isPending: false,
        ),
      );
      // ✅ SILENT — only StreamBuilder sees this
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Error parsing WS message: $e');
    }
  }

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
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }

  // ── Send message ──────
  // Strategy:
  // 1. Optimistic insert → user sees it immediately (via stream, silently)
  // 2. REST API call → guaranteed server delivery
  // 3. WS echo → confirms pending and sets real server timestamp
  // 4. Fallback timer → if WS echo never arrives, auto-confirm after timeout
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
    // ✅ SILENT — shows instantly in StreamBuilder with no screen flicker
    _emitMessages();

    try {
      await ApiService().sendMessage(chatId: _chatId!, text: trimmed);
      debugPrint('✅ Message delivered to server: $trimmed');

      // ── Fallback: if WS echo doesn't arrive, confirm pending after timeout ─
      // This prevents the message staying "pending" style forever.
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

  // ── Toggles ─────────
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
    _cleanupConnection();

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

    notifyListeners();
  }

  @override
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanupConnection();
    _messagesStreamController.close();
    super.dispose();
  }
}
