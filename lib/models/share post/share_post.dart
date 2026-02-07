class SharePost {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String? imageUrl;
  final int likes;
  final int comments;

  SharePost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    this.imageUrl,
    required this.likes,
    required this.comments,
  });
}
