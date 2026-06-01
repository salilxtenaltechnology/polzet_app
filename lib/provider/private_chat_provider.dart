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
  String? previousPageUrl;
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

  bool _isMemberOnline = false;

  bool get isPresenceConnected => _isPresenceConnected;
  bool get isMessageConnected => _isMessageConnected;
  bool get isConnected => _isPresenceConnected && _isMessageConnected;
  bool get isConnecting => _isPresenceConnecting || _isMessageConnecting;
  bool get showConnectionBanner =>
      !_isPresenceConnected || !_isMessageConnected;
  bool get isMemberOnline => _isMemberOnline;

  String? _currentUsername;

  bool isMuteNotification = false;
  bool isProtectedChat = false;
  bool isHideChat = false;
  bool isHideChatHistory = false;

  bool _isBlocking = false;
  bool get isBlocking => _isBlocking;

  int? currentUserId;

  void _emitMessages() {
    if (!_messagesStreamController.isClosed) {
      _messagesStreamController.add(List.unmodifiable(_messages));
    }
  }

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
          ? _messages
                .sublist(_messages.length - 60)
                .map((m) => m.toJson())
                .toList()
          : _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(toCache));
    } catch (e) {
      debugPrint('❌ Failed to save cached messages: $e');
    }
  }

  Future<void> init({
    required String? memberName,
    required String? profileUrl,
    int? chatId,
    String? currentUsername,
  }) async {
    final bool isNewChat = _chatId != chatId; // ← detect chat switch

    _memberName = memberName;
    _profileUrl = profileUrl;
    _chatId = chatId;

    if (currentUsername != null && currentUsername.isNotEmpty) {
      _currentUsername = currentUsername;
    } else {
      _currentUsername = await SharedPrefService.getUsername();
    }

    final userIdStr = await SharedPrefService.getUserId();
    currentUserId = userIdStr != null ? int.tryParse(userIdStr) : null;

    if (isNewChat) {
      _isMemberOnline = false;
      _messages.clear();
    }

    notifyListeners();

    if (_chatId == null) return;

    await _loadCachedMessages();
    fetchMessageHistory();

    final token = await SharedPrefService.getToken();
    if (token != null && token.isNotEmpty) {
      _shouldReconnect = true;

      // ✅ Reuse existing connections if same chat, reconnect if new chat
      if (isNewChat || !_isPresenceConnected) {
        await _connectPresenceSocket(token);
      } else {
        _requestMemberPresence(); // already connected, just re-ask
      }

      if (isNewChat || !_isMessageConnected) {
        await _connectMessageSocket(token);
      }
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
              id: item.id,
              text: item.message,
              created_at: item.created_at,
              isRead: item.isRead,
              isSentByMe: _currentUsername != null
                  ? item.isSentBy(_currentUsername)
                  : false,
              sharedPost: item.sharedPost,
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

        debugPrint('🔄 Polling: synced ${fetched.length} messages');
        _saveCachedMessages();
        _emitMessages();
      }
    } catch (e) {
      debugPrint('❌ Polling fetch failed: $e');
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
      previousPageUrl = response.previous;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              id: item.id,
              text: item.message,
              created_at: item.created_at,
              isRead: item.isRead,
              isSentByMe: _currentUsername != null
                  ? item.isSentBy(_currentUsername)
                  : false,
              sharedPost: item.sharedPost,
            ),
          )
          .toList();

      _messages.clear();
      _messages.addAll(fetched.reversed.toList());

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
      previousPageUrl = response.previous;

      final fetched = response.results
          .map(
            (item) => ChatMessage(
              id: item.id,
              text: item.message,
              created_at: item.created_at,
              isRead: item.isRead,
              isSentByMe: item.isSentBy(_currentUsername),
              sharedPost: item.sharedPost,
            ),
          )
          .toList();

      if (fetched.isEmpty) {
        _nextPageUrl = null;
        return;
      }

      _messages.insertAll(0, fetched.reversed.toList());

      _saveCachedMessages();
      _emitMessages();
    } catch (e) {
      debugPrint('❌ Failed to load more history: $e');
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
      final url = '$_wsBaseUrl/ws/chat/private/$_chatId/?token=$token';

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
          _handlePresenceDisconnection();
        },
        cancelOnError: false,
      );

      _isPresenceConnected = true;
      _requestMemberPresence();
      _isPresenceConnecting = false;
      _presenceReconnectAttempts = 0;

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

  void _requestMemberPresence() {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({'action': 'get_presence'}));
    debugPrint('📡 Requested member presence status');
  }

  Future<void> _connectMessageSocket(String token) async {
    if (_isMessageConnecting || _isMessageConnected) return;
    if (_chatId == null) return;

    _isMessageConnecting = true;
    notifyListeners();

    try {
      final url = '$_wsBaseUrl/ws/chat/private/$_chatId/?token=$token';

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

  void setMemberUserId(int userId) {
    _memberUserId = userId;
  }

 void _onPresenceMessageReceived(dynamic raw) {
  try {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    final String type = data['type']?.toString() ?? '';
    final int? userId = data['user_id'] is int
        ? data['user_id'] as int
        : int.tryParse(data['user_id']?.toString() ?? '');

    if (type == 'presence_update') {
      if (userId == null) return;

      // ✅ Skip own presence entirely
      if (userId == currentUserId) {
        debugPrint('👤 Skipping own presence_update (userId=$userId)');
        return;
      }

      // ✅ Only update if it's the member we're chatting with
      if (userId == _memberUserId) {
        _isMemberOnline = data['is_online'] == true;
        debugPrint('👤 Member ($userId) online: $_isMemberOnline');
        notifyListeners();
      }
      return;
    }

    if (type == 'read_receipt') {
      if (userId == null || userId == currentUserId) return;
      if (userId == _memberUserId) {
        final readAtStr = data['read_at']?.toString();
        if (readAtStr != null) {
          final readAtDttm = DateTime.tryParse(readAtStr)?.toLocal();
          if (readAtDttm != null) {
            bool changed = false;
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i].isSentByMe && !_messages[i].isRead && !_messages[i].created_at.isAfter(readAtDttm)) {
                _messages[i] = ChatMessage(
                  id: _messages[i].id,
                  text: _messages[i].text,
                  created_at: _messages[i].created_at,
                  isSentByMe: true,
                  isPending: false,
                  isFailed: false,
                  isRead: true,
                );
                changed = true;
              }
            }
            if (changed) {
              _saveCachedMessages();
              _emitMessages();
            }
          }
        }
      }
      return;
    }

    if (type == 'typing_status') {
      if (userId == null || userId == currentUserId) return;
      if (userId == _memberUserId) {
        isMemberTyping = data['is_typing'] == true;
        notifyListeners();
      }
      return;
    }

    if (type == 'typing_start' || type == 'typing_stop') {
      if (userId == null || userId == currentUserId) return;
      if (userId == _memberUserId) {
        isMemberTyping = type == 'typing_start';
        notifyListeners();
      }
      return;
    }

    if (type == 'new_message') {
      _onMessageReceived(raw);
      return;
    }

    debugPrint('⚠️ Unhandled presence type: $type');
  } catch (e) {
    debugPrint('❌ Error parsing presence message: $e');
  }
}

  void _onMessageReceived(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final String type = data['type']?.toString() ?? '';

      if (type == 'new_message') {
        final msgMap = data['message'] as Map<String, dynamic>?;
        if (msgMap == null) return;

        final int? serverId = msgMap['id'] is int
            ? msgMap['id'] as int
            : int.tryParse(msgMap['id']?.toString() ?? '');
        final String text = msgMap['text']?.toString() ?? '';
        if (text.isEmpty) return;

        // ✅ Deduplicate: ignore if message with same id already exists
        if (serverId != null && _messages.any((m) => m.id == serverId)) {
          debugPrint('⚠️ Duplicate message ignored: id=$serverId');
          return;
        }

        int? senderId;
        if (msgMap['sender'] is Map) {
          final dynamic rawSenderId = (msgMap['sender'] as Map)['id'];
          senderId = rawSenderId is int
              ? rawSenderId
              : int.tryParse(rawSenderId?.toString() ?? '');
        }

        final bool isSentByMe =
            currentUserId != null && senderId == currentUserId;

        final DateTime serverTimestamp =
            DateTime.tryParse(msgMap['created_at']?.toString() ?? '') ??
            DateTime.now();

        // ✅ Confirm pending optimistic message instead of adding a new one
        if (isSentByMe) {
          final pendingIndex = _messages.lastIndexWhere(
            (m) => m.isSentByMe && m.isPending && m.text == text,
          );
          if (pendingIndex != -1) {
            _messages[pendingIndex] = ChatMessage(
              id: serverId, // ← stamp the real id
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

        _messages.add(
          ChatMessage(
            id: serverId,
            text: text,
            created_at: serverTimestamp,
            isSentByMe: isSentByMe,
            isPending: false,
            sharedPost: msgMap['shared_post'] as Map<String, dynamic>?,
          ),
        );
        _saveCachedMessages();
        _emitMessages();
      }
    } catch (e) {
      debugPrint('❌ Error parsing chat WS message: $e');
    }
  }

  void sendTypingStart() {
    final presence = _presenceChannel;
    if (presence == null || !_isPresenceConnected) return;
    presence.sink.add(jsonEncode({'action': 'typing_start'}));
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

  void stopTyping() {
    _typingTimer?.cancel();
    sendTypingStop();
  }

  void markAsRead() {
    if (_presenceChannel != null && _isPresenceConnected) {
      _presenceChannel!.sink.add(jsonEncode({'action': 'mark_read'}));
    } else if (_messageChannel != null && _isMessageConnected) {
      _messageChannel!.sink.add(jsonEncode({'action': 'mark_read'}));
    }
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
        if (_presenceChannel != null && _isPresenceConnected) {
          _presenceChannel!.sink.add(
            jsonEncode({'action': 'send_message', 'text': trimmed}),
          );
        } else if (_messageChannel != null && _isMessageConnected) {
          _messageChannel!.sink.add(
            jsonEncode({'action': 'send_message', 'text': trimmed}),
          );
        } else {
          await ApiService().sendMessage(chatId: cid, text: trimmed);
        }
      }

      Future.delayed(_pendingConfirmTimeout, () {
        final pendingIndex = _messages.lastIndexWhere(
          (m) => m.isSentByMe && m.isPending && m.text == trimmed,
        );
        if (pendingIndex != -1) {
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
