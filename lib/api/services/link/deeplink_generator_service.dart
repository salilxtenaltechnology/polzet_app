import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

/// Service to handle deep linking in the app
/// Supports both https:// links and custom polzet:// scheme
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();

  StreamSubscription<Uri>? _sub;
  Uri? _initialLink;
  Function(String username, String postId)? _onPostLinkReceived;

  /// Initialize deep link listening
  ///
  /// [onPostLinkReceived] - Callback when a post link is received
  /// Parameters: username, postId
  Future<void> initialize({
    required Function(String username, String postId) onPostLinkReceived,
  }) async {
    _onPostLinkReceived = onPostLinkReceived;

    // Handle the initial link if the app was opened via a link
    try {
      _initialLink = await _appLinks.getInitialLink();
      if (_initialLink != null) {
        debugPrint('Initial deep link: $_initialLink');
        _handleDeepLink(_initialLink!);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for links while the app is running
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

  /// Parse and handle deep link
  void _handleDeepLink(Uri uri) {
    try {
      // Handle https://www.testfrontend.polzet.in/post/{username}/{postId}
      // or https://testfrontend.polzet.in/post/{username}/{postId}
      if (uri.host == 'www.testfrontend.polzet.in' ||
          uri.host == 'testfrontend.polzet.in') {
        _handleHttpsLink(uri);
      }
      // Handle custom scheme polzet://post/{username}/{postId}
      else if (uri.scheme == 'polzet' && uri.host == 'post') {
        _handleCustomScheme(uri);
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

    // Expected format: /post/{username}/{postId}
    if (pathSegments.isNotEmpty && pathSegments[0] == 'post') {
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
    } else {
      debugPrint('Invalid post link format - expected /post/ prefix');
    }
  }

  /// Handle custom scheme deep links
  void _handleCustomScheme(Uri uri) {
    final pathSegments = uri.pathSegments;

    // Expected format: polzet://post/{username}/{postId}
    if (pathSegments.length >= 2) {
      final username = pathSegments[0];
      final postId = pathSegments[1];

      debugPrint('Parsed custom scheme - Username: $username, PostId: $postId');

      if (_onPostLinkReceived != null) {
        _onPostLinkReceived!(username, postId);
      }
    } else {
      debugPrint('Invalid custom scheme format - insufficient path segments');
    }
  }

  /// Check if there's an initial link when app starts
  Uri? get initialLink => _initialLink;

  /// Dispose the service
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _onPostLinkReceived = null;
  }

  /// Generate a shareable HTTPS link for a post
  ///
  /// [username] - Username of the post author
  /// [postId] - ID of the post
  ///
  /// Returns: https://www.testfrontend.polzet.in/post/{username}/{postId}
  static String generatePostLink(String username, String postId) {
    return 'https://www.testfrontend.polzet.in/post/$username/$postId';
  }

  /// Generate a custom scheme link for a post (fallback)
  ///
  /// [username] - Username of the post author
  /// [postId] - ID of the post
  ///
  /// Returns: polzet://post/{username}/{postId}
  static String generateCustomSchemeLink(String username, String postId) {
    return 'polzet://post/$username/$postId';
  }
}
