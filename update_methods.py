import re

file_path = "lib/screens/home/profile/public/new_public_profile_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# Add imports
imports_to_add = """import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../core/utils/like_util.dart';
import '../../../../api/services/share/share_service.dart';
"""
if "import '../../../../core/utils/bottomsheet_util.dart';" not in content:
    content = content.replace("import '../../../../api/api_config.dart';", "import '../../../../api/api_config.dart';\n" + imports_to_add)

# Add state variables
state_vars = """
  final LikeService likeService = LikeService();
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};
  Map<int, int> postCommentsCounts = {};
"""
if "final LikeService likeService" not in content:
    content = content.replace("Map<int, int> postLikeCounts = {};", "Map<int, int> postLikeCounts = {};\n" + state_vars)

# Add methods
methods = """
  void _showCommentsBottomSheet(int postId, String username) async {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: username,
      onCommentsCountChanged: (newCount) {
        setState(() => postCommentsCounts[postId] = newCount);
      },
    );
  }

  void _showLikedUsersBottomSheet(int postId, String username) {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: postId,
    );
  }

  Future<void> _fetchLikedUsersSilently(int postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (mounted) {
        setState(() {
          postLikedUsers[postId] = users.take(3).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(int postId) async {
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;
    });

    try {
      final result = await likeService.togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );

      if (mounted) {
        setState(() {
          postLikeStates[postId] = result.isLiked;
          postLikeCounts[postId] = result.likesCount;
        });

        if (result.likesCount > 0) {
          _fetchLikedUsersSilently(postId);
        } else {
          setState(() {
            postLikedUsers.remove(postId);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          postLikeStates[postId] = currentLikeState;
          postLikeCounts[postId] = currentLikeCount;
        });
      }
    }
  }
"""

if "_showCommentsBottomSheet" not in content:
    content = content.replace("  @override\n  Widget build(BuildContext context)", methods + "\n  @override\n  Widget build(BuildContext context)")

# Update _buildSimplePostCard
# Replace: final commentsCount = post.comments.length;
# With:    final commentsCount = postCommentsCounts[post.id] ?? post.comments.length;\n    final viewLikes = postLikedUsers[post.id] ?? [];\n    final currentUsername = userProvider.userProfile?.username ?? '';

content = content.replace("final commentsCount = post.comments.length;", "final commentsCount = postCommentsCounts[post.id] ?? post.comments.length;\n    final viewLikes = postLikedUsers[post.id] ?? [];\n    final currentUsername = userProvider.userProfile?.username ?? '';")

# Replace like icon onTap
like_btn = """                    GestureDetector(
                      onTap: () {},
                      child: isLiked
                          ? AppIcons.filledHeart(key: const ValueKey('filled'))
                          : AppIcons.outlineHeart(
                              key: const ValueKey('outline'),
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.6),
                            ),
                    ),"""
like_btn_new = """                    GestureDetector(
                      onTap: () => _toggleLike(post.id),
                      child: isLiked
                          ? AppIcons.filledHeart(key: const ValueKey('filled'))
                          : AppIcons.outlineHeart(
                              key: const ValueKey('outline'),
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.6),
                            ),
                    ),"""
content = content.replace(like_btn, like_btn_new)

# Replace likes count Text
likes_count_text = "SizedBox(width: 4.w),\n                    Text('$likesCount'),"
likes_count_text_new = "SizedBox(width: 4.w),\n                    GestureDetector(\n                      onTap: () => _showLikedUsersBottomSheet(post.id, currentUsername),\n                      child: Text('$likesCount'),\n                    ),"
content = content.replace(likes_count_text, likes_count_text_new)

# Replace comments icon and count Text
comments_icon_count = """                    AppIcons.commnetBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.6),
                    ),
                    SizedBox(width: 4.w),
                    Text('$commentsCount'),"""
comments_icon_count_new = """                    GestureDetector(
                      onTap: () => _showCommentsBottomSheet(post.id, currentUsername),
                      child: AppIcons.commnetBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () => _showCommentsBottomSheet(post.id, currentUsername),
                      child: Text('$commentsCount'),
                    ),"""
content = content.replace(comments_icon_count, comments_icon_count_new)

# Replace Share icon
share_icon = """                    AppIcons.sharePost(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.7),
                    ),"""
share_icon_new = """                    GestureDetector(
                      onTap: () {
                        ShareService.sharePost(
                          post,
                          context: context,
                          usernameOverride: currentUsername,
                        );
                      },
                      child: AppIcons.sharePost(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),"""
content = content.replace(share_icon, share_icon_new)

# Add Liked avatars display
liked_avatars_code = """                  ],
                ),
                if (likesCount > 0) ...[
                  const SizedBox(height: 5),
                  if (viewLikes.isNotEmpty)
                    GestureDetector(
                      onTap: () =>
                          _showLikedUsersBottomSheet(post.id, currentUsername),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          LikeUtils.buildLikeAvatarsStack(
                            context,
                            viewLikes,
                            avatarSize: 14,
                          ),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: SizedBox(
                              height: 20.h,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: RichText(
                                  overflow: TextOverflow.ellipsis,
                                  text: LikeUtils.buildLikedByRichText(
                                    context,
                                    viewLikes,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),"""

# Let's find the end of the post card (where children: [ Row(... bookmark ...) ] ends).
# The bottom part of the card looks like this:
old_bottom = """                    Icon(
                      FeatherIcons.bookmark,
                      size: 20.sp,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          ),"""

content = content.replace(old_bottom, old_bottom.replace("                  ],\n                ),\n              ],\n            ),\n          ),", liked_avatars_code))

with open(file_path, "w") as f:
    f.write(content)

