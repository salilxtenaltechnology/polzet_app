// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/comment/comment.dart';
import '../utils/time_formatter.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final String? currentUsername;
  final int? editingCommentId;
  final TextEditingController editCommentController;
  final Function(int) onEdit;
  final VoidCallback onCancelEdit;
  final Function(int, String) onSaveEdit;
  final Function(int) onDelete;

  const CommentItem({
    super.key,
    required this.comment,
    required this.currentUsername,
    required this.editingCommentId,
    required this.editCommentController,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isEditing = editingCommentId == comment.id;
    final isCurrentUserComment =
        currentUsername != null && comment.user == currentUsername;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13.r,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
                            TimeFormatter.formatCommentTime(comment.createdAt),
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
                                  onTap: () => onEdit(comment.id),
                                  child: Icon(
                                    Icons.edit,
                                    size: 16.sp,
                                    color: Colors.grey.withOpacity(0.7),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                GestureDetector(
                                  onTap: () => onDelete(comment.id),
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
                          ? Column(
                              children: [
                                TextField(
                                  controller: editCommentController,
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
                                      onPressed: onCancelEdit,
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        onSaveEdit(
                                          comment.id,
                                          editCommentController.text,
                                        );
                                      },
                                      child: Text(
                                        'Save',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
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
}