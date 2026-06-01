class ChartPoint {
  final String label;
  final double value;
  ChartPoint({required this.label, required this.value});
  factory ChartPoint.fromJson(Map<String, dynamic>? json) => ChartPoint(
    label: json?['label'] ?? '',
    value: (json?['value'] as num?)?.toDouble() ?? 0.0,
  );
}

class InsightsModel {
  final int totalViews;
  final int chasers;
  final int pollsCreated;
  final List<ChartPoint> recent;

  InsightsModel({
    required this.totalViews,
    required this.chasers,
    required this.pollsCreated,
    required this.recent,
  });

  factory InsightsModel.fromJson(Map<String, dynamic>? json) {
    final data = json?['data'];
    return InsightsModel(
      totalViews: data?['total_views'] ?? 0,
      chasers: data?['chasers'] ?? 0,
      pollsCreated: data?['polls_created'] ?? 0,
      recent: data?['recent'] != null
          ? (data['recent'] as List)
              .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>?))
              .toList()
          : const [],
    );
  }
}
