import re

file_path = "lib/screens/home/profile/public/new_public_profile_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# I will find all the extra methods and remove them.
# The methods block starts with: "  void _showCommentsBottomSheet"
# And ends before: "  @override\n  Widget build(BuildContext context)"

# Split the file by the injected methods block
methods_block = """
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

# Replace all occurrences of the block + "  @override\n  Widget build"
# Then put the block back ONLY for the first occurrence.
occurrences = content.split(methods_block + "\n  @override\n  Widget build(BuildContext context)")

if len(occurrences) > 1:
    # First split happens inside _NewPublicProfileScreenState
    new_content = occurrences[0] + methods_block + "\n  @override\n  Widget build(BuildContext context)"
    for i in range(1, len(occurrences)-1):
        new_content += occurrences[i] + "\n  @override\n  Widget build(BuildContext context)"
    new_content += occurrences[-1]
    
    with open(file_path, "w") as f:
        f.write(new_content)

