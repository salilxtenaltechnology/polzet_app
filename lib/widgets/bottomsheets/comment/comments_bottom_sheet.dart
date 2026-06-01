// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import '../../../../models/comment/comment.dart';
import '../../../api/services/comment/comment_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../dialog/custom_diolog.dart';
import '../../loader.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
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
  List<Comments> comments = [];
  bool isLoading = false;
  bool isSending = false;
  int? editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint("POST_ID : ${widget.postId}");
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
    widget.onCommentsCountChanged?.call(comments.length);
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
    showDeleteCommentDiolog(context, () async {
      Navigator.pop(context);
      final success = await _commentsService.deleteComment(commentId);
      if (success) {
        setState(() {
          comments.removeWhere((c) => c.id == commentId);
        });
        widget.onCommentsCountChanged?.call(comments.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildCommentsList()),
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
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.comments,
          style: AppTextStyles.sectionHeading.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    if (isLoading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (comments.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 0.55.sh,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isDarkMode
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Image.asset(
                        Assets.images.noComments.path,
                        height: 0.22.sh,
                        width: 0.22.sh,
                        fit: BoxFit.contain,
                      ),
                    ),
              Text(
                AppLocalizations.of(context)!.nocommentsyet,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionHeading.copyWith(
                  fontSize: 18.5,
                  color: txt.title,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.bethefirsttostarttheconversation,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13,
                  color: txt.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
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

  Widget _buildCommentItem(Comments comment) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditing = editingCommentId == comment.id;
    final isCurrentUserComment =
        widget.currentUsername != null &&
        comment.user == widget.currentUsername;

    final profileBytes = getProfileImage(comment.profileImage);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              // if (userProvider.userId == comment.id) {
              //   Navigator.of(context).pushAndRemoveUntil(
              //     MaterialPageRoute(
              //       builder: (_) => const HomeScreen(initialIndex: 4),
              //     ),
              //     (route) => false,
              //   );
              // } else {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (_) => PublicProfileScreen(userId: comment.id.toString()),
              //     ),
              //   );
              // }
            },
            child: CircleAvatar(
              radius: 15.5,
              backgroundColor: isDarkMode
                  ? const Color(0xFF303030)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              backgroundImage:
                  comment.profileImage != null &&
                          comment.profileImage!.isNotEmpty &&
                          profileBytes != null
                      ? MemoryImage(profileBytes)
                      : null,
              onBackgroundImageError: comment.profileImage != null &&
                      comment.profileImage!.isNotEmpty
                  ? (_, __) {}
                  : null,
              child: comment.profileImage == null ||
                      comment.profileImage!.isEmpty
                  ? Text(
                      comment.user.isNotEmpty
                          ? comment.user[0].toUpperCase()
                          : 'P',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    )
                  : null,
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
                            style: AppTextStyles.subText.copyWith(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 4.w),
                            child: Text(
                              ' • ',
                              style: AppTextStyles.subText.copyWith(
                                fontWeight: FontWeight.w600,
                                color: txt.muted,
                              ),
                            ),
                          ),
                          Text(
                            _timeAgo(comment.createdAt),
                            style: AppTextStyles.subText.copyWith(
                              color: txt.muted,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.7),
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
                      isEditing
                          ? _buildEditCommentField(comment)
                          : Text(
                              comment.text,
                              style: AppTextStyles.subText.copyWith(
                                color: txt.body,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
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

  Widget _buildEditCommentField(Comments comment) {
    return Column(
      children: [
        TextField(
          controller: _editCommentController,
          autofocus: true,
          maxLines: null,
          style: AppTextStyles.bodyText,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: AppLocalizations.of(context)!.editcomments,
            hintStyle: AppTextStyles.subText.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                AppLocalizations.of(context)!.cancel,
                style: AppTextStyles.subText.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _editComment(comment.id),
              child: Text(
                AppLocalizations.of(context)!.save,
                style: AppTextStyles.subText.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
              height: 45,

              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                borderRadius: BorderRadius.circular(50),
                // border: Border.all(color: Theme.of(context).colorScheme.outline,width: 1)
              ),
              child: TextField(
                controller: _commentController,
                cursorColor: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.8),
                cursorWidth: 1.5,

                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  hintText: AppLocalizations.of(context)!.whatdoyouthinkforthis,
                  hintStyle: AppTextStyles.bodyText.copyWith(
                    color: const Color(0XFF898989),
                    fontWeight: FontWeight.w400,
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.15)
                          : Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.title,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 10),
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

  String _timeAgo(DateTime dt) {
    try {
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      if (diff.inDays < 7) return '${diff.inDays} d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
      return '${(diff.inDays / 365).floor()} y ago';
    } catch (_) {
      return '';
    }
  }
}
