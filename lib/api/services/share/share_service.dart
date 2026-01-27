// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../link/deeplink_generator_service.dart';

class ShareService {
  /// Share a post with deep link
  ///
  /// [post] - Post object to share
  /// [context] - BuildContext for showing snackbar on error
  static Future<void> sharePost(
    dynamic post, {
    required BuildContext context,
  }) async {
    try {
      // Extract username and post ID from your post object
      // Adjust these based on your actual post model structure
      final username = post.user?.username ?? 'user';
      final postId = post.id?.toString() ?? '0';

      // Generate the deep link
      final link = DeepLinkService.generatePostLink(username, postId);

      // Create share text
      final shareText =
          '''
$link
''';
      // Get the render box for share position (iOS)
      final box = context.findRenderObject() as RenderBox?;

      // Share using share_plus package
      final result = await Share.share(
        shareText,
        subject: 'Post from @$username',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );

      // Log the result
      if (result.status == ShareResultStatus.success) {
        debugPrint('Post shared successfully: $link');
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('Share dismissed by user');
      }
    } catch (e) {
      debugPrint('Error sharing post: $e');

      // Show error message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to share post')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Share text content
  ///
  /// [text] - Text to share
  /// [subject] - Optional subject line
  /// [context] - BuildContext for positioning (iOS)
  static Future<void> shareText(
    String text, {
    String? subject,
    BuildContext? context,
  }) async {
    try {
      final box = context?.findRenderObject() as RenderBox?;

      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }

  /// Share with custom message
  ///
  /// [post] - Post object
  /// [customMessage] - Custom message to prepend
  /// [context] - BuildContext
  static Future<void> sharePostWithMessage(
    dynamic post, {
    required String customMessage,
    required BuildContext context,
  }) async {
    try {
      final username = post.user?.username ?? 'user';
      final postId = post.id?.toString() ?? '0';
      final link = DeepLinkService.generatePostLink(username, postId);

      final shareText =
          '''
$customMessage

$link
''';

      final box = context.findRenderObject() as RenderBox?;

      await Share.share(
        shareText,
        subject: 'Polzet Post',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Error sharing post with message: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
