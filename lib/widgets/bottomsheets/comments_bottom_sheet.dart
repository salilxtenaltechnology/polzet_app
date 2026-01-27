// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:feather_icons/feather_icons.dart';
import '../../../models/comment/comment.dart';
import '../../api/services/comment/comment_service.dart';

class CommentsBottomSheet extends StatefulWidget {
  final int postId;
  final String? currentUsername;
  final ValueChanged<int>? onCommentsCountChanged;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    this.currentUsername,
    this.onCommentsCountChanged,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final CommentsService _commentsService = CommentsService();
  final TextEditingController _commentController = TextEditingController();
  List<Comment> comments = [];
  bool isLoading = false;
  bool isSending = false;
  int? editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => isLoading = true);
    final fetchedComments = await _commentsService.fetchComments(
      postId: widget.postId,
    );
    setState(() {
      comments = fetchedComments;
      isLoading = false;
    });
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || isSending) return;

    setState(() => isSending = true);
    final newComment = await _commentsService.postComment(
      postId: widget.postId,
      text: text,
    );

    if (newComment != null) {
      _commentController.clear();
      setState(() {
        comments.insert(0, newComment);
      });
      widget.onCommentsCountChanged?.call(comments.length);
    }

    setState(() => isSending = false);
  }

  Future<void> _editComment(int commentId) async {
    final text = _editCommentController.text.trim();
    if (text.isEmpty || isSending) return;

    setState(() => isSending = true);
    final updatedComment = await _commentsService.editComment(
      commentId: commentId,
      text: text,
    );

    if (updatedComment != null) {
      setState(() {
        final index = comments.indexWhere((c) => c.id == commentId);
        if (index != -1) {
          comments[index] = updatedComment;
        }
        editingCommentId = null;
        _editCommentController.clear();
      });
    }

    setState(() => isSending = false);
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await _showDeleteDialog();
    if (!confirmed) return;

    final success = await _commentsService.deleteComment(commentId);
    if (success) {
      setState(() {
        comments.removeWhere((c) => c.id == commentId);
      });
      widget.onCommentsCountChanged?.call(comments.length);
    }
  }

  Future<bool> _showDeleteDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Delete Comment',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Are you sure you want to delete this comment?',
              style: TextStyle(fontSize: 13.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Comments list
          Expanded(child: _buildCommentsList()),
          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      margin: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
      ),
      child: Center(
        child: Text(
          'Comments',
          style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 50.sp,
              color: Colors.grey.withOpacity(0.4),
            ),
            SizedBox(height: 10.h),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              'Be the first to comment',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildCommentItem(comment);
      },
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final isEditing = editingCommentId == comment.id;
    final isCurrentUserComment =
        widget.currentUsername != null &&
        comment.user == widget.currentUsername;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13.r,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.15),
            child: Text(
              comment.user.isNotEmpty ? comment.user[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: 5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(10.w, 0.h, 10.w, 5.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.user,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 4.w),
                            child: Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.withOpacity(0.7),
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(comment.createdAt),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey.withOpacity(0.7),
                            ),
                          ),
                          const Spacer(),
                          if (isCurrentUserComment && !isEditing)
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      editingCommentId = comment.id;
                                      _editCommentController.text =
                                          comment.text;
                                    });
                                  },
                                  child: Icon(
                                    Icons.edit,
                                    size: 16.sp,
                                    color: Colors.grey.withOpacity(0.7),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                GestureDetector(
                                  onTap: () => _deleteComment(comment.id),
                                  child: Icon(
                                    Icons.delete,
                                    size: 16.sp,
                                    color: Colors.red.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      isEditing
                          ? _buildEditCommentField(comment)
                          : Text(
                              comment.text,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black.withOpacity(0.8),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditCommentField(Comment comment) {
    return Column(
      children: [
        TextField(
          controller: _editCommentController,
          autofocus: true,
          maxLines: null,
          style: TextStyle(fontSize: 13.sp),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Edit comment...',
            hintStyle: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.withOpacity(0.6),
            ),
          ),
        ),
        SizedBox(height: 5.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  editingCommentId = null;
                  _editCommentController.clear();
                });
              },
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => _editComment(comment.id),
              child: Text(
                'Save',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 15.w,
        right: 15.w,
        top: 10.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.h,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25.r),
              ),
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                ),
                style: TextStyle(fontSize: 13.sp),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: isSending ? null : _postComment,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FeatherIcons.send,
                size: 18.spMax,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 28) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
