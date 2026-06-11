// global_search_model.dart
import '../../api/api_config.dart';

class GlobalSearchModel {
  final bool success;
  final String query;
  final String tab;
  final GlobalSearchData data;
  final SearchPagination pagination;

  GlobalSearchModel({
    required this.success,
    required this.query,
    required this.tab,
    required this.data,
    required this.pagination,
  });

  factory GlobalSearchModel.fromJson(Map<String, dynamic> json) {
    return GlobalSearchModel(
      success: json['success'] ?? false,
      query: json['query'] ?? '',
      tab: json['tab'] ?? '',
      data: GlobalSearchData.fromJson(json['data'] ?? {}),
      pagination: SearchPagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

/* ─── Data ─────*/
class GlobalSearchData {
  final List<SearchAccount> accounts;
  final List<SearchPost> posts;
  final List<SearchPhoto> photos;
  final List<SearchHashtag> hashtags;
  final List<SearchPlace> places;

  GlobalSearchData({
    required this.accounts,
    required this.posts,
    required this.photos,
    required this.hashtags,
    required this.places,
  });

  factory GlobalSearchData.fromJson(Map<String, dynamic> json) {
    final List<SearchAccount> accounts = (json['accounts'] as List<dynamic>? ?? [])
        .map((e) => SearchAccount.fromJson(e))
        .toList();

    final List<SearchPost> posts = (json['posts'] as List<dynamic>? ?? [])
        .map((e) => SearchPost.fromJson(e))
        .toList();

    final List<SearchPhoto> photos = (json['photos'] as List<dynamic>? ?? [])
        .map((e) => SearchPhoto.fromJson(e))
        .toList();

    final List<SearchHashtag> hashtags = (json['hashtags'] as List<dynamic>? ?? [])
        .map((e) => SearchHashtag.fromJson(e))
        .toList();

    final List<SearchPlace> places = (json['places'] as List<dynamic>? ?? [])
        .map((e) => SearchPlace.fromJson(e as Map<String, dynamic>))
        .toList();

    return GlobalSearchData(
      accounts: accounts,
      posts: posts,
      photos: photos,
      hashtags: hashtags,
      places: places,
    );
  }
}

/* ─── Account ─────*/
class SearchAccount {
  final String uuid;
  final String username;
  final String fullName;
  final String? profileImage;
  final bool isVerified;
  final int followersCount;
  final bool isFollowing;
  final String followStatus;
  final bool isPrivate;

  String get id => uuid;

  SearchAccount({
    required this.uuid,
    required this.username,
    required this.fullName,
    this.profileImage,
    required this.isVerified,
    required this.followersCount,
    required this.isFollowing,
    this.followStatus = 'none',
    this.isPrivate = false,
  });

  factory SearchAccount.fromJson(Map<String, dynamic> json) {
    final String parsedUuid = (json['uuid'] ?? json['id'] ?? '').toString();
    final String firstName = json['first_name'] ?? '';
    final String lastName = json['last_name'] ?? '';
    final String calculatedFullName = json['fullName'] ?? 
        (firstName.isNotEmpty ? '$firstName $lastName'.trim() : '');
    final String? profileImg = json['profileImage'] ?? json['avatar_url'];
    final String status = json['follow_status'] ?? 'none';
    final bool following = json['isFollowing'] ?? 
        (status == 'following' || status == 'both');

    return SearchAccount(
      uuid: parsedUuid,
      username: json['username'] ?? '',
      fullName: calculatedFullName,
      profileImage: profileImg,
      isVerified: json['isVerified'] ?? false,
      followersCount: json['followersCount'] ?? 0,
      isFollowing: following,
      followStatus: status,
      isPrivate: json['is_private'] ?? false,
    );
  }
}

/* ─── Post ─────*/
class SearchPost {
  final String id;
  final String description;
  final String createdAt;
  final SearchPostAuthor author;
  final List<SearchPostPoll> polls;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByCurrentUser;
  final String followingStatus;

  SearchPost({
    required this.id,
    required this.description,
    required this.createdAt,
    required this.author,
    required this.polls,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLikedByCurrentUser,
    required this.followingStatus,
  });

  String get caption => description;
  String get title => description;

  String? get thumbnail {
    for (final poll in polls) {
      for (final option in poll.options) {
        if (option.image != null) {
          final String rawUrl = option.image!.thumbnailUrl.isNotEmpty
              ? option.image!.thumbnailUrl
              : option.image!.url;
          if (rawUrl.isEmpty) continue;
          return rawUrl.startsWith('http')
              ? rawUrl
              : '${ApiConfig.baseUrlImage}$rawUrl';
        }
      }
    }
    return null;
  }

  factory SearchPost.fromJson(Map<String, dynamic> json) {
    return SearchPost(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
      author: SearchPostAuthor.fromJson(json['author'] ?? json['user'] ?? {}),
      polls: (json['polls'] as List<dynamic>? ?? [])
          .map((e) => SearchPostPoll.fromJson(e as Map<String, dynamic>))
          .toList(),
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      sharesCount: json['shares_count'] as int? ?? 0,
      isLikedByCurrentUser: json['is_liked_by_current_user'] ?? false,
      followingStatus: json['following_status'] ?? 'none',
    );
  }
}

class SearchPostAuthor {
  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profileImage;

  SearchPostAuthor({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profileImage,
  });

  factory SearchPostAuthor.fromJson(Map<String, dynamic> json) {
    return SearchPostAuthor(
      id: (json['id'] ?? json['userid'] ?? '').toString(),
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      profileImage: json['profileImage'] ?? json['profile_image'],
    );
  }
}

class SearchPostPoll {
  final String id;
  final String question;
  final List<SearchPostPollOption> options;
  final bool isPolledByCurrentUser;

  SearchPostPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.isPolledByCurrentUser,
  });

  factory SearchPostPoll.fromJson(Map<String, dynamic> json) {
    return SearchPostPoll(
      id: (json['id'] ?? '').toString(),
      question: json['question'] ?? '',
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => SearchPostPollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      isPolledByCurrentUser: json['is_polled_by_current_user'] ?? false,
    );
  }
}

class SearchPostPollOption {
  final dynamic id;
  final String? text;
  final SearchPostPollImage? image;
  final String voteCount;
  final double percentage;

  SearchPostPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
  });

  factory SearchPostPollOption.fromJson(Map<String, dynamic> json) {
    return SearchPostPollOption(
      id: json['id'],
      text: json['text'] as String?,
      image: json['image'] != null
          ? SearchPostPollImage.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      voteCount: json['vote_count']?.toString() ?? '0',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SearchPostPollImage {
  final dynamic id;
  final String url;
  final String thumbnailUrl;
  final int order;

  SearchPostPollImage({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.order,
  });

  factory SearchPostPollImage.fromJson(Map<String, dynamic> json) {
    return SearchPostPollImage(
      id: json['id'],
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      order: json['order'] as int? ?? 0,
    );
  }
}

/* ─── Photo ─────*/
class SearchPhoto {
  final String id;
  final String imageUrl;
  final String postId;
  final String username;
  final SearchPhotoAuthor author;

  SearchPhoto({
    required this.id,
    required this.imageUrl,
    required this.postId,
    required this.username,
    required this.author,
  });

  factory SearchPhoto.fromJson(Map<String, dynamic> json) {
    final String parsedUsername = json['username'] ?? '';
    return SearchPhoto(
      id: (json['id'] ?? json['image_id'] ?? '').toString(),
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? json['url'] ?? '',
      postId: (json['postId'] ?? json['post_id'] ?? '').toString(),
      username: parsedUsername,
      author: SearchPhotoAuthor.fromJson(
        json['author'] ?? 
        json['user'] ?? 
        {'username': parsedUsername.isNotEmpty ? parsedUsername : 'user'}
      ),
    );
  }
}

class SearchPhotoAuthor {
  final String id;
  final String username;

  SearchPhotoAuthor({required this.id, required this.username});

  factory SearchPhotoAuthor.fromJson(Map<String, dynamic> json) {
    return SearchPhotoAuthor(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      username: json['username'] ?? '',
    );
  }
}

/* ─── Hastags ─────*/
class SearchHashtag {
  final dynamic id;
  final String tag;
  final int postsCount;

  SearchHashtag({
    required this.id,
    required this.tag,
    required this.postsCount,
  });

  factory SearchHashtag.fromJson(Map<String, dynamic> json) {
    return SearchHashtag(
      id: json['id'],
      tag: json['tag'] ?? json['name'] ?? '',
      postsCount: json['postsCount'] ?? json['posts_count'] ?? 0,
    );
  }
}

/* ─── Pagination ─────*/
class SearchPagination {
  final int page;
  final int limit;
  final bool hasNext;

  SearchPagination({
    required this.page,
    required this.limit,
    required this.hasNext,
  });

  factory SearchPagination.fromJson(Map<String, dynamic> json) {
    return SearchPagination(
      page: json['page'] ?? json['current_page'] ?? 1,
      limit: json['limit'] ?? json['per_page'] ?? 10,
      hasNext: json['hasNext'] ??
               json['has_next'] ??
               json['hasMore'] ??
               json['has_more'] ??
               (json['next'] != null) ??
               false,
    );
  }
}

/* ─── Place ─────*/
class SearchPlace {
  final String name;

  SearchPlace({required this.name});

  factory SearchPlace.fromJson(Map<String, dynamic> json) {
    return SearchPlace(
      name: json['name'] ?? '',
    );
  }
}
