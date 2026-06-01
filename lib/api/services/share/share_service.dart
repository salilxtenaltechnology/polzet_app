// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../../../widgets/show_toast.dart';
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
    Function(int)? onShareSuccess,
  }) async {
    try {
      final username = usernameOverride ?? post.user?.username ?? 'user';
      final postId = post.id?.toString() ?? '0';
      final link = DeepLinkService.generatePostLink(username, postId);
      BottomSheetUtils.showShareBottomSheet(
        context: context,
        shareLink: link,
        username: username,
        postId: postId,
        onShareSuccess: onShareSuccess,
      );
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
