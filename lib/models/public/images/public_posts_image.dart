class PublicPostImage {
  final int id;
  final String url;
  final String thumbnailUrl;
  final int order;

  PublicPostImage({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.order,
  });

  factory PublicPostImage.fromJson(Map<String, dynamic> json) {
    return PublicPostImage(
      id: json['id'],
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
      order: json['order'],
    );
  }
}
