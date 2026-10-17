import 'package:flutter/material.dart';

class PollTopicModel {
  final String? id;
  final String? promptId;
  final String question;
  final String pollType;
  final String? badgeLabel;
  final String? votingType;
  final List<String> defaultOptions;
  final String bannerImageUrl;
  final int? postsCreatedCount;
  final int? categoryId;
  final String? categorySlug;
  final String? categoryTitle;
  final String? topicType;
  final String? pollTypeIcon;
  final Color? pollTypeColor;

  const PollTopicModel({
    this.id,
    this.promptId,
    String? question,
    String? pollQuestion,
    required this.pollType,
    this.badgeLabel,
    this.votingType,
    this.defaultOptions = const [],
    String? bannerImageUrl,
    String? pollImage,
    this.postsCreatedCount,
    this.categoryId,
    this.categorySlug,
    this.categoryTitle,
    this.topicType,
    this.pollTypeIcon,
    this.pollTypeColor,
  })  : question = question ?? pollQuestion ?? '',
        bannerImageUrl = bannerImageUrl ?? pollImage ?? '';

  /// Getters for snake_case and backward compatibility
  // ignore: non_constant_identifier_names
  String get pollQuestion => question;
  // ignore: non_constant_identifier_names
  String get pollImage => bannerImageUrl;
  // ignore: non_constant_identifier_names
  String get poll_question => question;
  // ignore: non_constant_identifier_names
  String get poll_type => pollType;
  // ignore: non_constant_identifier_names
  String get poll_image => bannerImageUrl;
  // ignore: non_constant_identifier_names
  String? get badge_label => badgeLabel;
  // ignore: non_constant_identifier_names
  String? get voting_type => votingType;
  // ignore: non_constant_identifier_names
  List<String> get default_options => defaultOptions;
  // ignore: non_constant_identifier_names
  String get banner_image_url => bannerImageUrl;
  // ignore: non_constant_identifier_names
  int? get posts_created_count => postsCreatedCount;
  // ignore: non_constant_identifier_names
  String? get prompt_id => promptId ?? id;
  // ignore: non_constant_identifier_names
  int? get category_id => categoryId;
  // ignore: non_constant_identifier_names
  String? get category_slug => categorySlug;
  // ignore: non_constant_identifier_names
  String? get category_title => categoryTitle;
  // ignore: non_constant_identifier_names
  String? get topic_type => topicType;

  factory PollTopicModel.fromJson(Map<String, dynamic> json) {
    List<String> parseOptions(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return PollTopicModel(
      id: json['prompt_id']?.toString() ?? json['id']?.toString(),
      promptId: json['prompt_id']?.toString() ?? json['id']?.toString(),
      question: json['question']?.toString() ??
          json['poll_question']?.toString() ??
          json['pollQuestion']?.toString() ??
          '',
      pollType: json['poll_type']?.toString() ??
          json['pollType']?.toString() ??
          '',
      badgeLabel: json['badge_label']?.toString() ??
          json['badgeLabel']?.toString(),
      votingType: json['voting_type']?.toString() ??
          json['votingType']?.toString(),
      defaultOptions: parseOptions(
        json['default_options'] ?? json['defaultOptions'],
      ),
      bannerImageUrl: json['banner_image_url']?.toString() ??
          json['banner_image']?.toString() ??
          json['bannerImageUrl']?.toString() ??
          json['banner']?.toString() ??
          json['poll_image']?.toString() ??
          json['pollImage']?.toString() ??
          '',
      postsCreatedCount: json['posts_created_count'] is int
          ? json['posts_created_count'] as int
          : int.tryParse(json['posts_created_count']?.toString() ?? ''),
      categoryId: json['category_id'] is int
          ? json['category_id'] as int
          : int.tryParse(json['category_id']?.toString() ?? ''),
      categorySlug: json['category_slug']?.toString(),
      categoryTitle: json['category_title']?.toString(),
      topicType: json['topic_type']?.toString() ??
          json['topicType']?.toString(),
      pollTypeIcon: json['poll_type_icon']?.toString() ??
          json['pollTypeIcon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (promptId != null) 'prompt_id': promptId,
      'question': question,
      'poll_question': question,
      'poll_type': pollType,
      if (badgeLabel != null) 'badge_label': badgeLabel,
      if (votingType != null) 'voting_type': votingType,
      'default_options': defaultOptions,
      'banner_image_url': bannerImageUrl,
      'poll_image': bannerImageUrl,
      if (postsCreatedCount != null) 'posts_created_count': postsCreatedCount,
      if (categoryId != null) 'category_id': categoryId,
      if (categorySlug != null) 'category_slug': categorySlug,
      if (categoryTitle != null) 'category_title': categoryTitle,
      if (topicType != null) 'topic_type': topicType,
      if (pollTypeIcon != null) 'poll_type_icon': pollTypeIcon,
    };
  }

  PollTopicModel copyWith({
    String? id,
    String? promptId,
    String? question,
    String? pollQuestion,
    String? pollType,
    String? badgeLabel,
    String? votingType,
    List<String>? defaultOptions,
    String? bannerImageUrl,
    String? pollImage,
    int? postsCreatedCount,
    int? categoryId,
    String? categorySlug,
    String? categoryTitle,
    String? topicType,
    String? pollTypeIcon,
    Color? pollTypeColor,
  }) {
    return PollTopicModel(
      id: id ?? this.id,
      promptId: promptId ?? this.promptId,
      question: question ?? pollQuestion ?? this.question,
      pollType: pollType ?? this.pollType,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      votingType: votingType ?? this.votingType,
      defaultOptions: defaultOptions ?? this.defaultOptions,
      bannerImageUrl: bannerImageUrl ?? pollImage ?? this.bannerImageUrl,
      postsCreatedCount: postsCreatedCount ?? this.postsCreatedCount,
      categoryId: categoryId ?? this.categoryId,
      categorySlug: categorySlug ?? this.categorySlug,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      topicType: topicType ?? this.topicType,
      pollTypeIcon: pollTypeIcon ?? this.pollTypeIcon,
      pollTypeColor: pollTypeColor ?? this.pollTypeColor,
    );
  }

  /// Parses feed response and extracts prompts across categories
  static List<PollTopicModel> fromFeedResponse(Map<String, dynamic> json) {
    final list = <PollTopicModel>[];
    final data = json['data'];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final category = PollTopicCategoryModel.fromJson(item);
          list.addAll(category.prompts);
        }
      }
    }
    return list;
  }
}

class PollTopicCategoryModel {
  final int? categoryId;
  final String? categorySlug;
  final String? categoryTitle;
  final int? totalPostsCreated;
  final int? totalPrompts;
  final List<PollTopicModel> prompts;

  const PollTopicCategoryModel({
    this.categoryId,
    this.categorySlug,
    this.categoryTitle,
    this.totalPostsCreated,
    this.totalPrompts,
    this.prompts = const [],
  });

  factory PollTopicCategoryModel.fromJson(Map<String, dynamic> json) {
    final catId = json['category_id'] is int
        ? json['category_id'] as int
        : int.tryParse(json['category_id']?.toString() ?? '');
    final catSlug = json['category_slug']?.toString();
    final catTitle = json['category_title']?.toString();

    final promptList = <PollTopicModel>[];
    if (json['prompts'] is List) {
      for (final p in json['prompts']) {
        if (p is Map<String, dynamic>) {
          promptList.add(
            PollTopicModel.fromJson({
              ...p,
              if (catId != null) 'category_id': catId,
              if (catSlug != null) 'category_slug': catSlug,
              if (catTitle != null) 'category_title': catTitle,
            }),
          );
        }
      }
    }

    return PollTopicCategoryModel(
      categoryId: catId,
      categorySlug: catSlug,
      categoryTitle: catTitle,
      totalPostsCreated: json['total_posts_created'] is int
          ? json['total_posts_created'] as int
          : int.tryParse(json['total_posts_created']?.toString() ?? ''),
      totalPrompts: json['total_prompts'] is int
          ? json['total_prompts'] as int
          : int.tryParse(json['total_prompts']?.toString() ?? ''),
      prompts: promptList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      if (categorySlug != null) 'category_slug': categorySlug,
      if (categoryTitle != null) 'category_title': categoryTitle,
      if (totalPostsCreated != null) 'total_posts_created': totalPostsCreated,
      if (totalPrompts != null) 'total_prompts': totalPrompts,
      'prompts': prompts.map((e) => e.toJson()).toList(),
    };
  }
}
