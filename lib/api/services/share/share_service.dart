// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:polzet_app/widgets/show_toast.dart';
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
    String? usernameOverride,
  }) async {
    try {
      final username = usernameOverride ?? post.user?.username ?? 'user';
      final postId = post.id?.toString() ?? '0';
      final link = DeepLinkService.generatePostLink(username, postId);
      final shareText = '$link\n';

      // Safely get RenderBox — can be null on non-iPad or inside slivers
      RenderBox? box;
      try {
        box = context.findRenderObject() as RenderBox?;
      } catch (_) {
        box = null; // RenderSliverList or other non-box render object
      }

      final result = await Share.share(
        shareText,
        subject: 'Post from @$username',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );

      if (result.status == ShareResultStatus.success) {
        debugPrint('Post shared successfully: $link');
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('Share dismissed by user');
      }
    } catch (e) {
      debugPrint('Error sharing post: $e');
      if (context.mounted) {
        showToast(message: 'Failed to share post');
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
