// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();

  StreamSubscription<Uri>? _sub;
  Uri? _initialLink;
  Function(String username, String postId)? _onPostLinkReceived;
  Function(String username)? _onProfileLinkReceived;

  /*---- Parameters: username, postId, profile ----*/
  Future<void> initialize({
    required Function(String username, String postId) onPostLinkReceived,
    required Function(String username) onProfileLinkReceived,
  }) async {
    _onPostLinkReceived = onPostLinkReceived;
    _onProfileLinkReceived = onProfileLinkReceived;

    try {
      _initialLink = await _appLinks.getInitialLink();
      if (_initialLink != null) {
        _handleDeepLink(_initialLink!);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('Deep link received while app running: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  String? _lastProcessedLink;
  DateTime? _lastProcessedTime;

  /*---- Parse and handle deep link ----*/
  void _handleDeepLink(Uri uri) {
    try {
      final linkString = uri.toString();
      final now = DateTime.now();
      
      if (_lastProcessedLink == linkString &&
          _lastProcessedTime != null &&
          now.difference(_lastProcessedTime!) < const Duration(seconds: 2)) {
        debugPrint('Ignoring duplicate deep link within 2 seconds: $uri');
        return;
      }
      
      _lastProcessedLink = linkString;
      _lastProcessedTime = now;

      if (uri.host == 'www.polzet.com') {
        _handleHttpsLink(uri);
      }
      else if (uri.scheme == 'polzet') {
        if (uri.host == 'post') {
          _handleCustomSchemePost(uri);
        } else if (uri.host == 'profile') {
          _handleCustomSchemeProfile(uri);
        }
      } else {
        debugPrint('Unrecognized deep link format: $uri');
      }
    } catch (e) {
      debugPrint('Error parsing deep link: $e');
    }
  }

  /// Handle HTTPS deep links
  void _handleHttpsLink(Uri uri) {
    final pathSegments = uri.pathSegments;

    if (pathSegments.isEmpty) return;

    // Expected format: /post/{username}/{postId}
    if (pathSegments[0] == 'post') {
      if (pathSegments.length >= 3) {
        final username = pathSegments[1];
        final postId = pathSegments[2];

        debugPrint('Parsed HTTPS link - Username: $username, PostId: $postId');

        if (_onPostLinkReceived != null) {
          _onPostLinkReceived!(username, postId);
        }
      } else {
        debugPrint('Invalid post link format - insufficient path segments');
      }
    }
    // Expected format: /profile/{username}
    else if (pathSegments[0] == 'profile') {
      if (pathSegments.length >= 2) {
        final username = pathSegments[1];

        debugPrint('Parsed HTTPS profile link - Username: $username');

        if (_onProfileLinkReceived != null) {
          _onProfileLinkReceived!(username);
        }
      } else {
        debugPrint('Invalid profile link format - insufficient path segments');
      }
    } else {
      debugPrint('Invalid link format - expected /post/ or /profile/ prefix');
    }
  }

  /// Handle custom scheme post deep links
  void _handleCustomSchemePost(Uri uri) {
    final pathSegments = uri.pathSegments;

    // Expected format: polzet://post/{username}/{postId}
    if (pathSegments.length >= 2) {
      final username = pathSegments[0];
      final postId = pathSegments[1];

      debugPrint('Parsed custom scheme post - Username: $username, PostId: $postId');

      if (_onPostLinkReceived != null) {
        _onPostLinkReceived!(username, postId);
      }
    } else {
      debugPrint('Invalid custom scheme post format - insufficient path segments');
    }
  }

  /// Handle custom scheme profile deep links
  void _handleCustomSchemeProfile(Uri uri) {
    final pathSegments = uri.pathSegments;

    // Expected format: polzet://profile/{username}
    if (pathSegments.isNotEmpty) {
      final username = pathSegments[0];

      debugPrint('Parsed custom scheme profile - Username: $username');

      if (_onProfileLinkReceived != null) {
        _onProfileLinkReceived!(username);
      }
    } else {
      debugPrint('Invalid custom scheme profile format - insufficient path segments');
    }
  }

  Uri? get initialLink => _initialLink;

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _onPostLinkReceived = null;
    _onProfileLinkReceived = null;
  }

  /// Generate a shareable HTTPS link for a post
  /// [username] - Username of the post author
  /// [postId] - ID of the post
  ///
  /// Returns: https://www.polzet.com/post/{username}/{postId}
  static String generatePostLink(String username, String postId) {
    return 'https://www.polzet.com/post/$username/$postId';
  }

  /// Generate a shareable HTTPS link for a profile
  /// [username] - Username of the profile
  ///
  /// Returns: https://www.polzet.com/profile/{username}
  static String generateProfileLink(String username) {
    return 'https://www.polzet.com/profile/$username';
  }

  /// Generate a custom scheme link for a post (fallback)
  /// [username] - Username of the post author
  /// [postId] - ID of the post
  ///
  /// Returns: polzet://post/{username}/{postId}
  static String generateCustomSchemeLink(String username, String postId) {
    return 'polzet://post/$username/$postId';
  }

  /// ✅ MAIN SHARE METHOD - USE THIS ONE
  /// Share post with custom title "Sharing post"
  /// Works on both Android and iOS
  ///
  /// [username] - Username of the post author
  /// [postId] - ID of the post
  static Future<void> sharePost({
    required String username,
    required String postId,
  }) async {
    final String postLink = generatePostLink(username, postId);

    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.polzet_app/share');
        await platform.invokeMethod('sharePost', {
          'url': postLink,
          'title': 'Share post',
        });
      } else {
        // iOS fallback
        await Share.share(postLink, subject: 'Share post');
      }
    } catch (e) {
      await Share.share(postLink);
    }
  }

  /// Share post with custom message
  /// [username] - Username of the post author
  /// [postId] - ID of the post
  /// [message] - Custom message to include with the link
  static Future<void> sharePostWithMessage({
    required String username,
    required String postId,
    String? message,
  }) async {
    final String postLink = generatePostLink(username, postId);
    final String shareText = message != null ? '$message\n$postLink' : postLink;

    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.polzet_app/share');
        await platform.invokeMethod('sharePost', {
          'url': shareText,
          'title': 'Share post',
        });
      } else {
        await Share.share(shareText, subject: 'Share post');
      }
    } catch (e) {
      await Share.share(shareText);
    }
  }
}
