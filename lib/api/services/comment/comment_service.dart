import 'package:flutter/material.dart';
import '../../../models/comment/comment.dart';
import '../../../widgets/show_toast.dart';
import '../../api_service.dart';

class CommentsService {
  // Singleton instance
  static final CommentsService _instance = CommentsService._internal();
  factory CommentsService() => _instance;
  CommentsService._internal();

  // Fetch comments for any post
  Future<List<Comments>> fetchComments({
    required dynamic postId,
    VoidCallback? onUpdate,
  }) async {
    try {
      final response = await ApiService.getPostComments(postId);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final commentsModel = CommentsModel.fromJson(data);
        return commentsModel.results;
      } else {
        if (response['message'] != null) {
          showToast(message: response['message']);
        }
      }
    } catch (e) {
      showToast(message: 'Unable to load comments');
      debugPrint('Comments fetch error: $e');
    }

    return [];
  }

  // Post a new comment
  Future<Comments?> postComment({
    required dynamic postId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final response = await ApiService.createComment(
        postId: postId,
        text: text,
      );

      if (response['success'] == true && response['data'] != null) {
        return Comments.fromJson(response['data']);
      } else {
        showToast(message: response['message'] ?? 'Failed to post comment');
      }
    } catch (e) {
      showToast(message: 'Unable to post comment');
      debugPrint('Comment post error: $e');
    }

    return null;
  }

  // Edit a comment
  Future<Comments?> editComment({
    required int commentId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final response = await ApiService.editComment(
        commentId: commentId,
        text: text.trim(),
      );

      if (response['success'] == true && response['data'] != null) {
        return Comments.fromJson(response['data']);
      } else {
        showToast(message: response['message'] ?? 'Failed to edit comment');
      }
    } catch (e) {
      showToast(message: 'Unable to edit comment');
      debugPrint('Comment edit error: $e');
    }

    return null;
  }

  // Delete a comment
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await ApiService.deleteComment(commentId);
      if (response['success'] == true) {
        return true;
      } else {
        showToast(message: response['message'] ?? 'Failed to delete comment');
      }
    } catch (e) {
      showToast(message: 'Unable to delete comment');
      debugPrint('Comment delete error: $e');
    }

    return false;
  }
}
