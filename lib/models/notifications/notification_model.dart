// notification_model.dart


class NotificationsResponse {
  final int count;
  final int unreadCount;
  final int page;
  final bool hasMore;
  final List<NotificationItem> results;

  NotificationsResponse({
    required this.count,
    required this.unreadCount,
    required this.page,
    required this.hasMore,
    required this.results,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = (json['results'] is List)
        ? (json['results'] as List)
            .map((e) => NotificationItem.fromJson(_asMap(e)))
            .toList()
        : <NotificationItem>[];

    final filteredResults = rawResults
        .where((item) => item.category.toUpperCase() != 'CHAT')
        .toList();

    return NotificationsResponse(
      count: filteredResults.length,
      unreadCount: _toInt(json['unread_count']),
      page: _toInt(json['page'], defaultValue: 1),
      hasMore: _parseBool(json['has_more']),
      results: filteredResults,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'unread_count': unreadCount,
      'page': page,
      'has_more': hasMore,
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

class NotificationItem {
  final String id;
  final String category;
  final String priority;
  final bool isRead;
  final DateTime createdAt;
  final String timeAgo;
  final String? message;
  final String? redirectTo;
  final String? clickAction;
  final NotificationActor actor;
  final NotificationPost? post;
  final NotificationMeta? meta;
  final String type;
  final String title;

  NotificationItem({
    required this.id,
    required this.category,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    required this.timeAgo,
    this.message,
    this.redirectTo,
    this.clickAction,
    required this.actor,
    this.post,
    this.meta,
    required this.type,
    required this.title,
  });

  NotificationItem copyWith({
    String? id,
    String? category,
    String? priority,
    bool? isRead,
    DateTime? createdAt,
    String? timeAgo,
    String? message,
    String? redirectTo,
    String? clickAction,
    NotificationActor? actor,
    NotificationPost? post,
    NotificationMeta? meta,
    String? type,
    String? title,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      timeAgo: timeAgo ?? this.timeAgo,
      message: message ?? this.message,
      redirectTo: redirectTo ?? this.redirectTo,
      clickAction: clickAction ?? this.clickAction,
      actor: actor ?? this.actor,
      post: post ?? this.post, // preserves poll_details on copyWith
      meta: meta ?? this.meta,
      type: type ?? this.type,
      title: title ?? this.title,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final String type = json['type'] as String? ?? '';

    return NotificationItem(
      id: (json['uuid'] ?? json['id'] ?? '').toString(),
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      isRead: _parseBool(json['is_read']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      timeAgo: json['time_ago'] as String? ?? '',
      message: json['message'] as String?,
      redirectTo: json['redirect_to'] as String?,
      clickAction: json['click_action'] as String?,
      actor: NotificationActor.fromJson(
        _asMap(json['actor']),
      ),
      post: json['post'] != null
          ? NotificationPost.fromJson(_asMap(json['post']))
          : null,
      meta: json['meta'] != null
          ? NotificationMeta.fromJson(_asMap(json['meta']))
          : null,
      type: type,
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'priority': priority,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
      'time_ago': timeAgo,
      if (message != null) 'message': message,
      if (redirectTo != null) 'redirect_to': redirectTo,
      if (clickAction != null) 'click_action': clickAction,
      'actor': actor.toJson(),
      if (post != null) 'post': post!.toJson(),
      if (meta != null) 'meta': meta!.toJson(),
      'type': type,
      'title': title,
    };
  }
}

class NotificationActor {
  final String userId;
  final String name;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  NotificationActor({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.isOnline,
  });

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      userId: (json['user_uuid'] ?? json['user_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isOnline: _parseBool(json['is_online']),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'username': username,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    'is_online': isOnline,
  };
}

class NotificationPost {
  final String postId;
  final String title;
  final String description;
  final String? imageUrl;
  final String postType;
  final List<NotificationPollDetail> pollDetails;

  NotificationPost({
    required this.postId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.postType,
    this.pollDetails = const [],
  });

  factory NotificationPost.fromJson(Map<String, dynamic> json) {
    List<dynamic>? rawPollDetails;

    final dynamic raw = json['poll_details'];
    if (raw is List) {
      rawPollDetails = raw;
    }

    return NotificationPost(
      postId: (json['post_uuid'] ?? json['post_id'] ?? json['id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      postType: json['post_type'] as String? ?? '',
      pollDetails: rawPollDetails != null
          ? rawPollDetails
                .map(
                  (e) => NotificationPollDetail.fromJson(
                    _asMap(e),
                  ),
                )
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'post_id': postId,
    'title': title,
    'description': description,
    if (imageUrl != null) 'image_url': imageUrl,
    'post_type': postType,
    'poll_details': pollDetails.map((e) => e.toJson()).toList(),
  };
}

class NotificationPollDetail {
  final String id;
  final String question;
  final List<NotificationPollOption> options;
  final bool isPolledByCurrentUser;

  NotificationPollDetail({
    required this.id,
    required this.question,
    required this.options,
    required this.isPolledByCurrentUser,
  });

  factory NotificationPollDetail.fromJson(Map<String, dynamic> json) {
    return NotificationPollDetail(
      id: (json['id'] ?? '').toString(),
      question: json['question'] as String? ?? '',
      options: (json['options'] is List)
          ? (json['options'] as List)
              .map(
                (e) => NotificationPollOption.fromJson(_asMap(e)),
              )
              .toList()
          : [],
      isPolledByCurrentUser:
          _parseBool(json['is_polled_by_current_user']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'is_polled_by_current_user': isPolledByCurrentUser,
  };
}

class NotificationPollOption {
  final dynamic id;
  final String? text;
  final NotificationPollImage? image;
  final String voteCount;
  final double percentage;
  final List<NotificationPollVoter> voters;
  final int score;
  final Map<String, int> rankDistribution;

  NotificationPollOption({
    required this.id,
    this.text,
    this.image,
    required this.voteCount,
    required this.percentage,
    required this.voters,
    required this.score,
    required this.rankDistribution,
  });

  factory NotificationPollOption.fromJson(Map<String, dynamic> json) {
    final dynamic rawVoteCount = json['vote_count'];
    final String voteCountStr = rawVoteCount is int
        ? rawVoteCount.toString()
        : (rawVoteCount as String? ?? '0');

    return NotificationPollOption(
      id: json['id'],
      text: json['text'] as String?,
      image: json['image'] != null
          ? NotificationPollImage.fromJson(
              _asMap(json['image']),
            )
          : null,
      voteCount: voteCountStr,
      percentage: _toDouble(json['percentage']),
      voters: (json['voters'] is List)
          ? (json['voters'] as List)
              .map((e) => NotificationPollVoter.fromJson(_asMap(e)))
              .toList()
          : [],
      score: _toInt(json['score']),
      rankDistribution: (json['rank_distribution'] is Map)
          ? (json['rank_distribution'] as Map<dynamic, dynamic>).map(
              (k, v) => MapEntry(k.toString(), _toInt(v)),
            )
          : {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (text != null) 'text': text,
    if (image != null) 'image': image!.toJson(),
    'vote_count': voteCount,
    'percentage': percentage,
    'voters': voters.map((e) => e.toJson()).toList(),
    'score': score,
    'rank_distribution': rankDistribution,
  };
}

class NotificationPollImage {
  final dynamic id;
  final int order;
  final String url;
  final String thumbnailUrl;

  NotificationPollImage({
    required this.id,
    required this.order,
    required this.url,
    required this.thumbnailUrl,
  });

  factory NotificationPollImage.fromJson(Map<String, dynamic> json) {
    return NotificationPollImage(
      id: json['id'],
      order: _toInt(json['order']),
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'url': url,
    'thumbnail_url': thumbnailUrl,
  };
}

class NotificationPollVoter {
  final dynamic id;
  final String username;
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;

  NotificationPollVoter({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
  });

  factory NotificationPollVoter.fromJson(Map<String, dynamic> json) {
    return NotificationPollVoter(
      id: json['id'],
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': firstName,
    'last_name': lastName,
    if (profilePictureUrl != null) 'profile_picture_url': profilePictureUrl,
  };
}

class NotificationMeta {
  final String? body;
  final String type;
  final String? title;
  final String? sender;
  final dynamic postId;
  final dynamic senderId;
  final dynamic chatId;
  final String? commentText;
  final String? messagePreview;
  final String? groupName;
  final int count;
  final List<dynamic> secondaryUsers;
  final dynamic requestId;

  NotificationMeta({
    this.body,
    required this.type,
    this.title,
    this.sender,
    this.postId,
    this.senderId,
    this.chatId,
    this.commentText,
    this.messagePreview,
    this.groupName,
    this.count = 0,
    this.secondaryUsers = const [],
    this.requestId,
  });

  factory NotificationMeta.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['count'];
    final int parsedCount = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? 0;

    return NotificationMeta(
      body: json['body'] as String?,
      type: json['type'] as String? ?? '',
      title: json['title'] as String?,
      sender: json['sender'] as String?,
      postId: json['post_id'],
      senderId: json['sender_id'],
      chatId: json['chat_id'],
      commentText: json['comment_text'] as String?,
      messagePreview: json['message_preview'] as String?,
      groupName: json['group_name'] as String?,
      count: parsedCount,
      secondaryUsers: json['secondary_users'] is List ? (json['secondary_users'] as List) : [],
      requestId: json['request_id'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (body != null) 'body': body,
    'type': type,
    if (title != null) 'title': title,
    if (sender != null) 'sender': sender,
    if (postId != null) 'post_id': postId,
    if (senderId != null) 'sender_id': senderId,
    if (chatId != null) 'chat_id': chatId,
    if (commentText != null) 'comment_text': commentText,
    if (messagePreview != null) 'message_preview': messagePreview,
    if (groupName != null) 'group_name': groupName,
    'count': count,
    'secondary_users': secondaryUsers,
    if (requestId != null) 'request_id': requestId,
  };
}

int _toInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return int.tryParse(value.toString()) ?? defaultValue;
}

double _toDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return double.tryParse(value.toString()) ?? defaultValue;
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return false;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}
