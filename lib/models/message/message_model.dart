// ignore_for_file: non_constant_identifier_names
class ChatMessage {
    final int? id;
  final String text;
  final DateTime created_at;
  final bool isSentByMe;
  final bool isPending;
  final bool isFailed;
  final bool isRead;
  final String? senderUsername;
  final String? senderProfileImage;
  final Map<String, dynamic>? sharedPost;
  final String? senderId;

  const ChatMessage({
     this.id,
    required this.text,
    required this.created_at,
    required this.isSentByMe,
    this.isPending = false,
    this.isFailed = false,
    this.isRead = false,
    this.senderUsername,
    this.senderProfileImage,
    this.sharedPost,
    this.senderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'created_at': created_at.toIso8601String(),
      'isSentByMe': isSentByMe,
      'isPending': isPending,
      'isFailed': isFailed,
      'isRead': isRead,
      'senderUsername': senderUsername,
      'senderProfileImage': senderProfileImage,
      'sharedPost': sharedPost,
      'senderId': senderId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      created_at: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isSentByMe: json['isSentByMe'] as bool? ?? false,
      isPending: json['isPending'] as bool? ?? false,
      isFailed: json['isFailed'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      senderUsername: json['senderUsername'] as String?,
      senderProfileImage: json['senderProfileImage'] as String?,
      sharedPost: json['sharedPost'] as Map<String, dynamic>?,
      senderId: json['senderId'] as String?,
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
    return MessageListModel(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MessageItem {
  final int id;
  final int chat;
  final MessageSender sender;
  final String message;
  final DateTime created_at;
  final bool isRead;
  final Map<String, dynamic>? sharedPost;

  MessageItem({
    required this.id,
    required this.chat,
    required this.sender,
    required this.message,
    required this.created_at,
    this.isRead = false,
    this.sharedPost,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      chat: json['chat'] is int ? json['chat'] as int : int.tryParse(json['chat']?.toString() ?? '') ?? 0,
      sender: MessageSender.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      message: json['message']?.toString() ?? json['text']?.toString() ?? '',
      created_at: DateTime.parse(json['created_at']).toLocal(),
      isRead: json['is_read'] as bool? ?? false,
      sharedPost: json['shared_post'] as Map<String, dynamic>?,
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
