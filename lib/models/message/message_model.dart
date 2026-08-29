// ignore_for_file: non_constant_identifier_names
class ChatMessage {
  final dynamic id;
  final dynamic chatId;
  final String text;
  final DateTime created_at;
  final bool isSentByMe;
  final bool isPending;
  final bool isFailed;
  final bool isRead;
  final String? senderUsername;
  final String? senderProfileImage;
  final Map<String, dynamic>? sharedPost;
  final Map<String, dynamic>? sharedProfile;
  final Map<String, dynamic>? sharedGroup;
  final String? senderId;

  const ChatMessage({
    this.id,
    this.chatId,
    required this.text,
    required this.created_at,
    required this.isSentByMe,
    this.isPending = false,
    this.isFailed = false,
    this.isRead = false,
    this.senderUsername,
    this.senderProfileImage,
    this.sharedPost,
    this.sharedProfile,
    this.sharedGroup,
    this.senderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'text': text,
      'created_at': created_at.toIso8601String(),
      'isSentByMe': isSentByMe,
      'isPending': isPending,
      'isFailed': isFailed,
      'isRead': isRead,
      'senderUsername': senderUsername,
      'senderProfileImage': senderProfileImage,
      'sharedPost': sharedPost,
      'sharedProfile': sharedProfile,
      'sharedGroup': sharedGroup,
      'senderId': senderId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? json['message_id'] ?? json['_id'],
      chatId: json['chatId'] ?? json['chat'] ?? json['chat_id'],
      text: json['text'] as String? ?? json['message'] as String? ?? '',
      created_at: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      isSentByMe: json['isSentByMe'] as bool? ?? false,
      isPending: json['isPending'] as bool? ?? false,
      isFailed: json['isFailed'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      senderUsername: json['senderUsername'] as String? ??
          (json['sender'] is Map ? json['sender']['username']?.toString() : null),
      senderProfileImage: json['senderProfileImage'] as String? ??
          (json['sender'] is Map ? json['sender']['profile_image']?.toString() : null),
      sharedPost: json['sharedPost'] as Map<String, dynamic>? ?? json['shared_post'] as Map<String, dynamic>?,
      sharedProfile: json['sharedProfile'] as Map<String, dynamic>? ?? json['shared_profile'] as Map<String, dynamic>?,
      sharedGroup: json['sharedGroup'] as Map<String, dynamic>? ?? json['shared_group'] as Map<String, dynamic>?,
      senderId: json['senderId'] as String? ??
          (json['sender'] is Map ? json['sender']['id']?.toString() : null),
    );
  }
}

class MessageListModel {
  final int count;
  final String? next;
  final String? previous;
  final List<MessageItem> results;

  MessageListModel({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory MessageListModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> list = [];
    if (json['results'] is List) {
      list = json['results'] as List<dynamic>;
    } else if (json['data'] is List) {
      list = json['data'] as List<dynamic>;
    } else if (json['messages'] is List) {
      list = json['messages'] as List<dynamic>;
    }
    return MessageListModel(
      count: json['count'] ?? list.length,
      next: json['next']?.toString(),
      previous: json['previous']?.toString(),
      results: list
          .whereType<Map<String, dynamic>>()
          .map((e) => MessageItem.fromJson(e))
          .toList(),
    );
  }
}

class MessageItem {
  final dynamic id;
  final dynamic chat;
  final MessageSender sender;
  final String message;
  final DateTime created_at;
  final bool isRead;
  final Map<String, dynamic>? sharedPost;
  final Map<String, dynamic>? sharedProfile;
  final Map<String, dynamic>? sharedGroup;

  MessageItem({
    required this.id,
    required this.chat,
    required this.sender,
    required this.message,
    required this.created_at,
    this.isRead = false,
    this.sharedPost,
    this.sharedProfile,
    this.sharedGroup,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] ?? json['message_id'] ?? json['_id'],
      chat: json['chat']?.toString() ?? json['chat_id']?.toString() ?? '',
      sender: MessageSender.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      message: json['message']?.toString() ?? json['text']?.toString() ?? '',
      created_at: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      sharedPost: json['shared_post'] as Map<String, dynamic>?,
      sharedProfile: json['shared_profile'] as Map<String, dynamic>?,
      sharedGroup: json['shared_group'] as Map<String, dynamic>? ?? json['sharedGroup'] as Map<String, dynamic>?,
    );
  }

  /// Returns true if this message was sent by [currentUsername].
  bool isSentBy(String? currentUsername) {
    if (currentUsername == null || currentUsername.isEmpty) return false;
    return sender.username == currentUsername;
  }
}

class MessageSender {
  final String id;
  final String username;
  final String? profileImage;

  MessageSender({required this.id, required this.username, this.profileImage});

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
    );
  }
}
