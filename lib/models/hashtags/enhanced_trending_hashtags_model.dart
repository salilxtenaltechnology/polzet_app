class EnhancedTrendingHashtagsModel {
  final String status;
  final List<HashtagModel> trendingLast24h;
  final List<HashtagModel> allTimePopular;

  EnhancedTrendingHashtagsModel({
    required this.status,
    required this.trendingLast24h,
    required this.allTimePopular,
  });

  factory EnhancedTrendingHashtagsModel.fromJson(Map<String, dynamic> json) {
    return EnhancedTrendingHashtagsModel(
      status: json['status'] as String,
      trendingLast24h: (json['trending_last_24h'] as List<dynamic>)
          .map((e) => HashtagModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      allTimePopular: (json['all_time_popular'] as List<dynamic>)
          .map((e) => HashtagModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HashtagModel {
  final String name;
  final int count;

  HashtagModel({
    required this.name,
    required this.count,
  });

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    return HashtagModel(
      name: json['name'] as String,
      count: json['count'] as int,
    );
  }
}