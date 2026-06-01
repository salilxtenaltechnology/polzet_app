// ignore_for_file: non_constant_identifier_names
class IncomingData {
  final int senderId;
  final String senderUsername;
  final String? profile_picture;
  final String createdAt;

  IncomingData({
    required this.senderId,
    required this.senderUsername,
    this.profile_picture,
    required this.createdAt,
  });

  factory IncomingData.fromJson(Map<String, dynamic> json) {
    final dynamic sender = json['sender'] ?? {};
    final dynamic rawId = sender['id'];
    final int parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return IncomingData(
      senderId: parsedId,
      senderUsername: sender['username']?.toString() ?? '',
      profile_picture: sender['profile_picture']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
