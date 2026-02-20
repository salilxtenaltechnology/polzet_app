// ignore_for_file: non_constant_identifier_names
class ChatMessage {
  final String text;
  final DateTime created_at;
  final bool isSentByMe;
  final bool isPending;
  final bool isFailed;
  final String? senderUsername;
  final String? senderProfileImage;

  const ChatMessage({
    required this.text,
    required this.created_at,
    required this.isSentByMe,
    this.isPending = false,
    this.isFailed = false,
    this.senderUsername,
    this.senderProfileImage,
  });
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

  MessageItem({
    required this.id,
    required this.chat,
    required this.sender,
    required this.message,
    required this.created_at,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] ?? 0,
      chat: json['chat'] ?? 0,
      sender: MessageSender.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      message: json['message']?.toString() ?? json['text']?.toString() ?? '',
      created_at:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Returns true if this message was sent by [currentUsername].
  /// Called in the provider after the logged-in user is loaded from SharedPrefs.
  bool isSentBy(String? currentUsername) {
    if (currentUsername == null || currentUsername.isEmpty) return false;
    return sender.username == currentUsername;
  }
}

class MessageSender {
  final int id;
  final String username;
  final String? profileImage;

  MessageSender({required this.id, required this.username, this.profileImage});

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      id: json['id'] ?? 0,
      username: json['username']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
    );
  }
}
