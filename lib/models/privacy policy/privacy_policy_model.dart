class PrivacyPolicyModel {
  final int userId;
  final String privacyStatus; // "accept" | "decline"
  final String? acceptedAt;
  final String? declinedAt;
  final bool isAccepted;
 
  const PrivacyPolicyModel({
    required this.userId,
    required this.privacyStatus,
    this.acceptedAt,
    this.declinedAt,
    required this.isAccepted,
  });
 
  factory PrivacyPolicyModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PrivacyPolicyModel(
      userId: data['user_id'] as int,
      privacyStatus: data['privacy_status'] as String,
      acceptedAt: data['accepted_at'] as String?,
      declinedAt: data['declined_at'] as String?,
      isAccepted: data['is_accepted'] as bool,
    );
  }
}