import 'package:flutter/material.dart';

class NotificationsResponse {
  final String status;
  final List<NotificationItem> notifications;
  final int count;
  final String? next;
  final String? previous;

  NotificationsResponse({
    required this.status,
    required this.notifications,
    required this.count,
    this.next,
    this.previous,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      status: json['status'] as String? ?? 'success',
      notifications:
          (json['notifications'] as List<dynamic>?)
              ?.map((e) {
                try {
                  return NotificationItem.fromJson(e as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ Error parsing notification: $e');
                  return null;
                }
              })
              .whereType<NotificationItem>()
              .toList() ??
          [],
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'notifications': notifications.map((e) => e.toJson()).toList(),
      'count': count,
      'next': next,
      'previous': previous,
    };
  }
}

class NotificationItem {
  final String id;
  final String type;
  final String? title;
  final String? message;
  final Post? post;
  final UserInfo actor;
  final UserInfo? postOwner;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    this.title,
    this.message,
    this.post,
    required this.actor,
    this.postOwner,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      post: json['post'] != null
          ? Post.fromJson(json['post'] as Map<String, dynamic>)
          : null,
      actor: UserInfo.fromJson(json['actor'] as Map<String, dynamic>),
      postOwner: json['post_owner'] != null
          ? UserInfo.fromJson(json['post_owner'] as Map<String, dynamic>)
          : null, // Allow null for FOLLOW notifications
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'post': post?.toJson(),
      'actor': actor.toJson(),
      'post_owner': postOwner?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  NotificationItem copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    Post? post,
    UserInfo? actor,
    UserInfo? postOwner,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      post: post ?? this.post,
      actor: actor ?? this.actor,
      postOwner: postOwner ?? this.postOwner,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class Post {
  final int postId;
  final String? title;
  final String? description;
  final String imageUrl;
  final PostOwner? postOwner;
  final String? username;

  Post({
    required this.postId,
    this.title,
    this.description,
    required this.imageUrl,
    this.postOwner,
    this.username,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      postId: json['post_id'] as int? ?? json['id'] as int? ?? 0,
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      postOwner: json['post_owner'] != null
          ? PostOwner.fromJson(json['post_owner'] as Map<String, dynamic>)
          : null,
      username: json['username']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'post_owner': postOwner?.toJson(),
      'username': username,
    };
  }
}

class PostOwner {
  final int userId;
  final String name;
  final String? avatarUrl;
  final bool isOnline;

  PostOwner({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.isOnline,
  });

  factory PostOwner.fromJson(Map<String, dynamic> json) {
    return PostOwner(
      userId: json['user_id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      avatarUrl: json['avatar_url']?.toString(),
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
    };
  }
}

class UserInfo {
  final int userId;
  final String name;
  final String? avatarUrl;
  final bool isOnline;

  UserInfo({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.isOnline,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['user_id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      avatarUrl: json['avatar_url']?.toString(),
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
    };
  }
}
