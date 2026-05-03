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
    return NotificationsResponse(
      count: json['count'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      hasMore: json['has_more'] as bool? ?? false,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      timeAgo: json['time_ago'] as String? ?? '',
      message: json['message'] as String?,
      redirectTo: json['redirect_to'] as String?,
      clickAction: json['click_action'] as String?,
      actor: NotificationActor.fromJson(
        json['actor'] as Map<String, dynamic>? ?? {},
      ),
      post: json['post'] != null
          ? NotificationPost.fromJson(json['post'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? NotificationMeta.fromJson(json['meta'] as Map<String, dynamic>)
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
  final int userId;
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
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
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
  final int postId;
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
      postId: json['post_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      postType: json['post_type'] as String? ?? '',
      pollDetails: rawPollDetails != null
          ? rawPollDetails
                .map(
                  (e) => NotificationPollDetail.fromJson(
                    e as Map<String, dynamic>,
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
  final int id;
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
      id: json['id'] as int? ?? 0,
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? [])
          .map(
            (e) => NotificationPollOption.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      isPolledByCurrentUser:
          json['is_polled_by_current_user'] as bool? ?? false,
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
  final int id;
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
      id: json['id'] as int? ?? 0,
      text: json['text'] as String?,
      image: json['image'] != null
          ? NotificationPollImage.fromJson(
              json['image'] as Map<String, dynamic>,
            )
          : null,
      voteCount: voteCountStr,
      percentage: (json['percentage'] as num? ?? 0).toDouble(),
      voters: (json['voters'] as List<dynamic>? ?? [])
          .map((e) => NotificationPollVoter.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: (json['score'] as num? ?? 0).toInt(),
      rankDistribution:
          (json['rank_distribution'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
          ),
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
  final int id;
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
      id: json['id'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
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
  final int id;
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
      id: json['id'] as int? ?? 0,
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
  final int? postId;
  final int? senderId;
  final int? chatId;
  final String? commentText;
  final String? messagePreview;
  final String? groupName;
  final int count;
  final List<dynamic> secondaryUsers;
  final int? requestId;

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
      postId: json['post_id'] as int?,
      senderId: json['sender_id'] as int?,
      chatId: json['chat_id'] as int?,
      commentText: json['comment_text'] as String?,
      messagePreview: json['message_preview'] as String?,
      groupName: json['group_name'] as String?,
      count: parsedCount,
      secondaryUsers: json['secondary_users'] as List<dynamic>? ?? [],
      requestId: json['request_id'] as int?,
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
