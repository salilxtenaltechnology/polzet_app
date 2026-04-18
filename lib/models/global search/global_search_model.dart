// global_search_model.dart
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
  final List<dynamic> places;

  GlobalSearchData({
    required this.accounts,
    required this.posts,
    required this.photos,
    required this.hashtags,
    required this.places,
  });

  factory GlobalSearchData.fromJson(Map<String, dynamic> json) {
    return GlobalSearchData(
      accounts: (json['accounts'] as List<dynamic>? ?? [])
          .map((e) => SearchAccount.fromJson(e))
          .toList(),
      posts: (json['posts'] as List<dynamic>? ?? [])
          .map((e) => SearchPost.fromJson(e))
          .toList(),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => SearchPhoto.fromJson(e))
          .toList(),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((e) => SearchHashtag.fromJson(e))
          .toList(),
      places: json['places'] ?? [],
    );
  }
}

/* ─── Account ─────*/
class SearchAccount {
  final int id;
  final String username;
  final String fullName;
  final String? profileImage;
  final bool isVerified;
  final int followersCount;
  final bool isFollowing;

  SearchAccount({
    required this.id,
    required this.username,
    required this.fullName,
    this.profileImage,
    required this.isVerified,
    required this.followersCount,
    required this.isFollowing,
  });

  factory SearchAccount.fromJson(Map<String, dynamic> json) {
    return SearchAccount(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      profileImage: json['profileImage'],
      isVerified: json['isVerified'] ?? false,
      followersCount: json['followersCount'] ?? 0,
      isFollowing: json['isFollowing'] ?? false,
    );
  }
}

/* ─── Post ─────*/
class SearchPost {
  final int id;
  final String title;
  final String caption;
  final String createdAt;
  final String? locationName;
  final SearchPostAuthor author;
  final String postType;
  final String? thumbnail;

  SearchPost({
    required this.id,
    required this.title,
    required this.caption,
    required this.createdAt,
    this.locationName,
    required this.author,
    required this.postType,
    this.thumbnail,
  });

  factory SearchPost.fromJson(Map<String, dynamic> json) {
    return SearchPost(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      caption: json['caption'] ?? '',
      createdAt: json['createdAt'] ?? '',
      locationName: json['location_name'],
      author: SearchPostAuthor.fromJson(json['author'] ?? {}),
      postType: json['postType'] ?? '',
      thumbnail: json['thumbnail'],
    );
  }
}

class SearchPostAuthor {
  final int id;
  final String username;
  final String? profileImage;

  SearchPostAuthor({
    required this.id,
    required this.username,
    this.profileImage,
  });

  factory SearchPostAuthor.fromJson(Map<String, dynamic> json) {
    return SearchPostAuthor(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      profileImage: json['profileImage'],
    );
  }
}

/* ─── Photo ─────*/
class SearchPhoto {
  final int id;
  final String imageUrl;
  final int postId;
  final SearchPhotoAuthor author;

  SearchPhoto({
    required this.id,
    required this.imageUrl,
    required this.postId,
    required this.author,
  });

  factory SearchPhoto.fromJson(Map<String, dynamic> json) {
    return SearchPhoto(
      id: json['id'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
      postId: json['postId'] ?? 0,
      author: SearchPhotoAuthor.fromJson(json['author'] ?? {}),
    );
  }
}

class SearchPhotoAuthor {
  final int id;
  final String username;

  SearchPhotoAuthor({required this.id, required this.username});

  factory SearchPhotoAuthor.fromJson(Map<String, dynamic> json) {
    return SearchPhotoAuthor(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
    );
  }
}

/* ─── Hastags ─────*/
class SearchHashtag {
  final int id;
  final String tag;
  final int postsCount;

  SearchHashtag({
    required this.id,
    required this.tag,
    required this.postsCount,
  });

  factory SearchHashtag.fromJson(Map<String, dynamic> json) {
    return SearchHashtag(
      id: json['id'] ?? 0,
      tag: json['tag'] ?? '',
      postsCount: json['postsCount'] ?? 0,
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
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      hasNext: json['hasNext'] ?? false,
    );
  }
}
