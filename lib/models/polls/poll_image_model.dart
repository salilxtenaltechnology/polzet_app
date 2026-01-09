class PostImage {
  final int id;
  final String url;
  final String thumbnailUrl;
  final int order;

  PostImage({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.order,
  });

  factory PostImage.fromJson(Map<String, dynamic> json) => PostImage(
        id: json['id'],
        url: json['url'],
        thumbnailUrl: json['thumbnail_url'],
        order: json['order'],
      );
}