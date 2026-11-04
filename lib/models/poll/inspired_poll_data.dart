import '../../api/api_config.dart';
import '../posts/homefeed_posts_model.dart';
import '../posts/single_post_model.dart';
import '../posts/user_post_model.dart';

class InspiredPollData {
  final String username;
  final String question;
  final String? description;
  final String? imageUrl;
  final String? pollId;
  final String? postId;
  final String? pollType;

  const InspiredPollData({
    required this.username,
    required this.question,
    this.description,
    this.imageUrl,
    this.pollId,
    this.postId,
    this.pollType,
  });

  factory InspiredPollData.fromPost(HomeFeedPost post, {HomeFeedPoll? poll}) {
    final activePoll =
        poll ?? (post.polls.isNotEmpty ? post.polls.first : null);

    // 1. Extract image if available (from poll options or post images)
    String? imgUrl;
    if (activePoll != null) {
      for (final option in activePoll.options) {
        if (option.image != null) {
          final thumb =
              option.image!.resolvedThumbnailUrl(ApiConfig.baseUrlImage);
          if (thumb.isNotEmpty) {
            imgUrl = thumb;
            break;
          }
          final full = option.image!.resolvedUrl(ApiConfig.baseUrlImage);
          if (full.isNotEmpty) {
            imgUrl = full;
            break;
          }
        }
      }
    }

    if (imgUrl == null || imgUrl.isEmpty) {
      if (post.images.isNotEmpty) {
        final firstImage = post.images.first;
        final thumb = firstImage.resolvedThumbnailUrl(ApiConfig.baseUrlImage);
        if (thumb.isNotEmpty) {
          imgUrl = thumb;
        } else {
          final full = firstImage.resolvedUrl(ApiConfig.baseUrlImage);
          if (full.isNotEmpty) {
            imgUrl = full;
          }
        }
      }
    }

    // 2. Extract question and description
    String questionText = '';
    String? descriptionText;

    if (activePoll != null && activePoll.question.trim().isNotEmpty) {
      questionText = activePoll.question.trim();
      if (post.description.trim().isNotEmpty) {
        descriptionText = post.description.trim();
      }
    } else if (post.description.trim().isNotEmpty) {
      questionText = post.description.trim();
      descriptionText = null;
    }

    // 3. Extract clean username
    var user = post.user.username.trim();
    if (user.startsWith('@')) {
      user = user.substring(1).trim();
    }
    if (user.isEmpty) {
      user = 'user';
    }

    return InspiredPollData(
      username: user,
      question: questionText,
      description: descriptionText,
      imageUrl: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : null,
      pollId: activePoll?.id,
      postId: post.id,
      pollType: activePoll?.pollType,
    );
  }

  factory InspiredPollData.fromSinglePost(
    SinglePostModel post, {
    SinglePostPoll? poll,
  }) {
    final activePoll =
        poll ?? (post.polls.isNotEmpty ? post.polls.first : null);

    // 1. Extract image if available (from poll options or post images)
    String? imgUrl;
    if (activePoll != null) {
      for (final option in activePoll.options) {
        if (option.image != null) {
          final thumb =
              option.image!.resolvedThumbnailUrl(ApiConfig.baseUrlImage);
          if (thumb.isNotEmpty) {
            imgUrl = thumb;
            break;
          }
          final full = option.image!.resolvedUrl(ApiConfig.baseUrlImage);
          if (full.isNotEmpty) {
            imgUrl = full;
            break;
          }
        }
      }
    }

    if (imgUrl == null || imgUrl.isEmpty) {
      if (post.images.isNotEmpty) {
        final firstImage = post.images.first;
        final thumb = firstImage.resolvedThumbnailUrl(ApiConfig.baseUrlImage);
        if (thumb.isNotEmpty) {
          imgUrl = thumb;
        } else {
          final full = firstImage.resolvedUrl(ApiConfig.baseUrlImage);
          if (full.isNotEmpty) {
            imgUrl = full;
          }
        }
      }
    }

    // 2. Extract question and description
    String questionText = '';
    String? descriptionText;

    if (activePoll != null && activePoll.question.trim().isNotEmpty) {
      questionText = activePoll.question.trim();
      final cleanedDesc = post.description
          .replaceAll(RegExp(r'\s*\[inspired_by:[^\]]+\]'), '')
          .trim();
      if (cleanedDesc.isNotEmpty) {
        descriptionText = cleanedDesc;
      }
    } else {
      final cleanedDesc = post.description
          .replaceAll(RegExp(r'\s*\[inspired_by:[^\]]+\]'), '')
          .trim();
      if (cleanedDesc.isNotEmpty) {
        questionText = cleanedDesc;
        descriptionText = null;
      }
    }

    // 3. Extract clean username
    var user = post.user.username.trim();
    if (user.startsWith('@')) {
      user = user.substring(1).trim();
    }
    if (user.isEmpty) {
      user = 'user';
    }

    return InspiredPollData(
      username: user,
      question: questionText,
      description: descriptionText,
      imageUrl: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : null,
      pollId: activePoll?.id,
      postId: post.id,
      pollType: activePoll?.pollType,
    );
  }

  factory InspiredPollData.fromUserPost(
    UserPostModel post, {
    UserPollQuestion? poll,
  }) {
    final activePoll =
        poll ?? (post.polls.isNotEmpty ? post.polls.first : null);

    // 1. Extract image if available (from poll options or post images)
    String? imgUrl;
    if (activePoll != null) {
      for (final option in activePoll.options) {
        if (option.image != null) {
          final thumb =
              option.image!.resolvedThumbnailUrl(ApiConfig.baseUrlImage);
          if (thumb.isNotEmpty) {
            imgUrl = thumb;
            break;
          }
          final full = option.image!.resolvedUrl(ApiConfig.baseUrlImage);
          if (full.isNotEmpty) {
            imgUrl = full;
            break;
          }
        }
      }
    }

    if (imgUrl == null || imgUrl.isEmpty) {
      if (post.images.isNotEmpty) {
        final firstImage = post.images.first;
        final thumb = firstImage.resolvedThumbnailUrl(ApiConfig.baseUrlImage);
        if (thumb.isNotEmpty) {
          imgUrl = thumb;
        } else {
          final full = firstImage.resolvedUrl(ApiConfig.baseUrlImage);
          if (full.isNotEmpty) {
            imgUrl = full;
          }
        }
      }
    }

    // 2. Extract question and description
    String questionText = '';
    String? descriptionText;

    if (activePoll != null && activePoll.question.trim().isNotEmpty) {
      questionText = activePoll.question.trim();
      final cleanedDesc = post.description
          .replaceAll(RegExp(r'\s*\[inspired_by:[^\]]+\]'), '')
          .trim();
      if (cleanedDesc.isNotEmpty) {
        descriptionText = cleanedDesc;
      }
    } else {
      final cleanedDesc = post.description
          .replaceAll(RegExp(r'\s*\[inspired_by:[^\]]+\]'), '')
          .trim();
      if (cleanedDesc.isNotEmpty) {
        questionText = cleanedDesc;
        descriptionText = null;
      }
    }

    // 3. Extract clean username
    var user = post.user.trim();
    if (user.startsWith('@')) {
      user = user.substring(1).trim();
    }
    if (user.isEmpty) {
      user = 'user';
    }

    return InspiredPollData(
      username: user,
      question: questionText,
      description: descriptionText,
      imageUrl: (imgUrl != null && imgUrl.isNotEmpty) ? imgUrl : null,
      pollId: activePoll?.id,
      postId: post.id,
      pollType: activePoll?.pollType,
    );
  }
}

