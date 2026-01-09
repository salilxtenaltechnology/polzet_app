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
    return IncomingData(
      senderId: json['sender']['id'],
      senderUsername: json['sender']['username'],
      profile_picture: json['sender']['profile_picture'],
      createdAt: json['created_at'],
    );
  }
}
