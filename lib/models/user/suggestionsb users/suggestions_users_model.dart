import 'dart:convert';
import 'package:flutter/material.dart';

class UserSuggestionsModel {
  final String status;
  final SuggestionsData data;

  UserSuggestionsModel({required this.status, required this.data});

  factory UserSuggestionsModel.fromJson(Map<String, dynamic> json) {
    return UserSuggestionsModel(
      status: json['status'] ?? '',
      data: SuggestionsData.fromJson(json['data']),
    );
  }
}

class SuggestionsData {
  final List<SuggestedUser> peopleYouMayKnow;
  final List<dynamic> suggestedCreators;

  SuggestionsData({
    required this.peopleYouMayKnow,
    required this.suggestedCreators,
  });

  factory SuggestionsData.fromJson(Map<String, dynamic> json) {
    return SuggestionsData(
      peopleYouMayKnow:
          (json['suggestions'] as List<dynamic>?)
              ?.map((e) => SuggestedUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      suggestedCreators: json['suggested_creators'] ?? [],
    );
  }
}

class SuggestedUser {
  final dynamic id;
  final String username;
  final String name;
  final String role;
  final String avatar;
  final int mutualFriends;
  final List<String> mutualFriendsAvatars;
  final List<String> tags;
  final bool isNew;

  // Cached image providers to prevent reloading/flickering on widget rebuilds
  ImageProvider? _avatarImageProvider;
  ImageProvider get avatarImageProvider {
    if (_avatarImageProvider == null) {
      if (avatar.startsWith('data:image')) {
        try {
          _avatarImageProvider = MemoryImage(base64Decode(avatar.split(',').last));
        } catch (_) {
          _avatarImageProvider = NetworkImage(avatar);
        }
      } else {
        _avatarImageProvider = NetworkImage(avatar);
      }
    }
    return _avatarImageProvider!;
  }

  List<ImageProvider>? _mutualImageProviders;
  List<ImageProvider> get mutualImageProviders {
    if (_mutualImageProviders == null) {
      _mutualImageProviders = [];
      for (final url in mutualFriendsAvatars) {
        if (url.startsWith('data:image')) {
          try {
            _mutualImageProviders!.add(MemoryImage(base64Decode(url.split(',').last)));
          } catch (_) {
            _mutualImageProviders!.add(NetworkImage(url));
          }
        } else {
          _mutualImageProviders!.add(NetworkImage(url));
        }
      }
    }
    return _mutualImageProviders!;
  }

  SuggestedUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.avatar,
    required this.mutualFriends,
    required this.mutualFriendsAvatars,
    required this.tags,
    required this.isNew,
  });

  factory SuggestedUser.fromJson(Map<String, dynamic> json) {
    return SuggestedUser(
      id: json['id'],
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      avatar: json['avatar'] ?? '',
      mutualFriends: json['mutualFriends'] ?? 0,
      mutualFriendsAvatars: List<String>.from(json['mutualFriendsAvatars'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      isNew: json['isNew'] ?? false,
    );
  }
}
