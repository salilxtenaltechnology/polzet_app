class RecentSearchModel {
  final String type;
  final String value;
  final String id;

  const RecentSearchModel({
    required this.type,
    required this.value,
    required this.id,
  });

  factory RecentSearchModel.fromJson(Map<String, dynamic> json) {
    return RecentSearchModel(
      type: json['type'] as String? ?? '',
      value: json['value'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'id': id,
  };
}

class RecentSearchResponse {
  final bool success;
  final List<RecentSearchModel> data;

  const RecentSearchResponse({
    required this.success,
    required this.data,
  });

  factory RecentSearchResponse.fromJson(Map<String, dynamic> json) {
    return RecentSearchResponse(
      success: json['success'] as bool? ?? false,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => RecentSearchModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}