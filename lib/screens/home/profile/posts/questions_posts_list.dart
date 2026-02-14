// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/services/api_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../models/posts/user_post_model.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/card/things/poll_question_card.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/utils/bottomsheet_util.dart';

class QuestionsPostsList extends StatefulWidget {
  String? username;
  String? profileImage;
  QuestionsPostsList({super.key, required this.username, this.profileImage});

  @override
  State<QuestionsPostsList> createState() => QuestionsPostsListState();
}

class QuestionsPostsListState extends State<QuestionsPostsList> {
  late final ApiService apiService = ApiService();
  List<UserPostModel> postsPolls = [];
  bool isLoading = true;
  String? errorMessage;

  // Track like state for each post
  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};

  // Track comments count for each post
  Map<int, int> postCommentsCounts = {};

  // Track liked users for each post (fetched on-demand)
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    // Add null check before loading
    if (widget.username == null || widget.username!.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Username not available';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch posts using PostImagesResponse
      final List<UserPostModel> fetchedPosts = await apiService
          .fetchOnlyPollPosts(widget.username!);

      // Filter posts to only include those with text-based poll options
      final filteredPosts = fetchedPosts.where((post) {
        // Check if post has polls
        if (post.polls.isEmpty) return false;

        // Check if all poll options have text (not images)
        return post.polls.every(
          (poll) =>
              poll.options != null &&
              poll.options!.every(
                (option) => option.text != null && option.text!.isNotEmpty,
              ),
        );
      }).toList();

      if (mounted) {
        setState(() {
          postsPolls = filteredPosts;
          isLoading = false;

          // Initialize like states and comments counts from fetched data
          postLikeStates.clear();
          postLikeCounts.clear();
          postCommentsCounts.clear();
          postLikedUsers.clear();
          likedUsersLoading.clear();

          for (var post in filteredPosts) {
            postLikeStates[post.id] = post.isLiked;
            postLikeCounts[post.id] = post.likesCount;
            postCommentsCounts[post.id] = post.commentsCount;

            // Fetch liked users for posts with likes
            if (post.likesCount > 0) {
              _fetchLikedUsers(post.id);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  // Fetch liked users for a specific post
  Future<void> _fetchLikedUsers(int postId) async {
    // Don't fetch if already loading or already loaded
    if (likedUsersLoading[postId] == true || postLikedUsers.containsKey(postId)) {
      return;
    }

    setState(() {
      likedUsersLoading[postId] = true;
    });

    try {
      final users = await ApiService().fetchLikedUsers(postId);
      
      if (mounted) {
        setState(() {
          postLikedUsers[postId] = users.take(3).toList(); // Only keep first 3 for display
          likedUsersLoading[postId] = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching liked users for post $postId: $e');
      if (mounted) {
        setState(() {
          likedUsersLoading[postId] = false;
        });
      }
    }
  }

  // Handle like changes from child
  void _handleLikeChanged(int postId, bool isLiked, int likesCount) {
    if (mounted) {
      setState(() {
        postLikeStates[postId] = isLiked;
        postLikeCounts[postId] = likesCount;
      });
    }
  }

  // Handle comments count changes from child
  void _handleCommentsChanged(int postId, int commentsCount) {
    if (mounted) {
      setState(() {
        postCommentsCounts[postId] = commentsCount;
      });
    }
  }

  // Handle liked users updates from child
  void _handleLikedUsersUpdated(int postId, List<LikeUser> users) {
    if (mounted) {
      setState(() {
        postLikedUsers[postId] = users;
      });
    }
  }

  // Handle post deletion
  void _deletePost(int postId) {
    if (mounted) {
      setState(() {
        postsPolls.removeWhere((post) => post.id == postId);
        // Clean up tracking maps
        postLikeStates.remove(postId);
        postLikeCounts.remove(postId);
        postCommentsCounts.remove(postId);
        postLikedUsers.remove(postId);
        likedUsersLoading.remove(postId);
      });
    }
  }

  // Show comments bottom sheet
  void _showCommentsBottomSheet(int postId) {
    // Add null check before showing bottom sheet
    if (widget.username == null || widget.username!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load comments. Username not available.'),
        ),
      );
      return;
    }

    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: widget.username!,
      onCommentsCountChanged: (newCount) {
        if (mounted) {
          setState(() => postCommentsCounts[postId] = newCount);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.pollthings,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: isLoading
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[600], size: 50),
                  SizedBox(height: 16.h),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: loadPosts,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : postsPolls.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.poll_outlined, color: Colors.grey[400], size: 60),
                  SizedBox(height: 16.h),
                  Text(
                    'No active polls found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadPosts,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                itemCount: postsPolls.length,
                itemBuilder: (context, index) {
                  final post = postsPolls[index];

                  return ThingsQustionsCard(
                    post: post,
                    onDelete: _deletePost,
                    onLikeChanged: _handleLikeChanged,
                    onCommentsChanged: _handleCommentsChanged,
                    onCommentsIconTap: () => _showCommentsBottomSheet(post.id),
                    username: widget.username,
                    profileImage: widget.profileImage,
                    // Pass current tracked states
                    currentLikeState: postLikeStates[post.id],
                    currentLikesCount: postLikeCounts[post.id],
                    currentCommentsCount: postCommentsCounts[post.id],
                    currentLikedUsers: postLikedUsers[post.id],
                    onLikedUsersUpdated: _handleLikedUsersUpdated,
                  );
                },
              ),
            ),
    );
  }
}