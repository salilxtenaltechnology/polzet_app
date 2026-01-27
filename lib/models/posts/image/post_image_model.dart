import '../../polls/poll_image_model.dart';
import '../../polls/poll_question_model.dart';

class PostImagesModel {
  final int id;
  final String user;
  final String description;
  final DateTime createdAt;
  final List<PollQuestion> pollQuestion;
  final List<PostImage> images;
  final int likesCount;
  final bool isLiked;
  final int commentsCount; // Added comments count

  PostImagesModel({
    required this.id,
    required this.user,
    required this.description,
    required this.createdAt,
    required this.pollQuestion,
    required this.images,
    required this.likesCount,
    required this.isLiked,
    required this.commentsCount, // Added to constructor
  });

  factory PostImagesModel.fromJson(Map<String, dynamic> json) =>
      PostImagesModel(
        id: json['id'] as int,
        user: json['user'] as String,
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        pollQuestion:
            (json['polls'] as List<dynamic>?)
                ?.map((e) => PollQuestion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <PollQuestion>[],
        images: (json['images'] as List<dynamic>)
            .map((e) => PostImage.fromJson(e))
            .toList(),
        likesCount: json['likes_count'] as int? ?? 0,
        isLiked: json['is_liked'] == false,
        commentsCount: (json['comments'] as List<dynamic>?)?.length ?? 0, // Calculate from comments array
      );

  // Optional: Add a copyWith method for easier updates
  PostImagesModel copyWith({
    int? id,
    String? user,
    String? description,
    DateTime? createdAt,
    List<PollQuestion>? pollQuestion,
    List<PostImage>? images,
    int? likesCount,
    bool? isLiked,
    int? commentsCount,
  }) {
    return PostImagesModel(
      id: id ?? this.id,
      user: user ?? this.user,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      images: images ?? this.images,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}