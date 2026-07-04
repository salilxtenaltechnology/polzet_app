// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../api/api_config.dart';
import '../../../../api/api_service.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../api/services/share/share_service.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../models/search/hashtag/hashtag_posts_list_model.dart';
import '../../../../models/posts/single_post_model.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/image/app_cached_network_image.dart';
import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../core/utils/like_util.dart';
import '../../home feed/rank/result/image/image_result_screen.dart';
import '../../home feed/rank/result/things/things_result_screen.dart';
import 'rank/hashtags_image_poll_ranking.dart';
import 'rank/single_post_things_ranking.dart';
import '../../profile/public/public_profile_screen.dart';
import 'package:polzet_app/gen/assets.gen.dart';

const _textSecondary = Color(0xFF888888);

class HashtagPostsList extends StatefulWidget {
  final String hashtag;

  const HashtagPostsList({super.key, required this.hashtag});

  @override
  State<HashtagPostsList> createState() => _HashtagPostsListState();
}

class _HashtagPostsListState extends State<HashtagPostsList> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<HashtagPostModel> _posts = [];
  bool _loading = true;
  String? _error;
  String? _nextPage;
  final bool _loadingMore = false;

  final ScrollController _scrollController = ScrollController();

  // Per-post like state
  final Map<String, bool> _likedMap = {};
  final Map<String, int> _likesCountMap = {};
  final Map<String, int> _commentsCountMap = {};
  final Map<String, int> _sharesCountMap = {};
  final Map<String, List<LikeUser>> _likedUsersMap = {};
  final Map<String, bool> _likedUsersLoadingMap = {};

  // Per-poll vote state
  final Map<String, int> _selectedVotes = {}; // pollId -> optionId

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _scrollController.addListener(_onScroll);
  }

  void _showAllImagesGrid(
    String postId,
    HashtagPollModel poll,
    bool isPolledByCurrentUser,
  ) {
    if (isPolledByCurrentUser) {
      // Already voted → show results
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => ImageResultScreen(
                postId: postId.toString(),
                username: _posts
                    .firstWhere((p) => p.id == postId)
                    .user
                    .username,
              ),
            ),
          )
          .then((result) {
            if (result == true) _fetchPosts();
          });
    } else {
      // Not yet polled → open ranking screen
      final post = _posts.firstWhere((p) => p.id == postId);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => HashtagsImagePollRanking(post: post, poll: poll),
            ),
          )
          .then((result) {
            if (result == true) _fetchPosts();
          });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Pagination scroll ──────────────────────────────────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _nextPage != null) {
      // _fetchMorePosts();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService().searchHashtagPosts(widget.hashtag);
      if (!mounted) return;

      _initPostState(result.results);

      setState(() {
        // _posts = result.results.where((p) => p.polls.isNotEmpty).toList();
        _posts = result.results;
        _nextPage = result.next;
      });

      for (final post in result.results) {
        _fetchLikedUsers(post.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initPostState(List<HashtagPostModel> posts) {
    for (final post in posts) {
      _likedMap[post.id] = post.isLikedByCurrentUser;
      _likesCountMap[post.id] = post.likesCount;
      _commentsCountMap[post.id] = post.commentsCount;
      _sharesCountMap[post.id] = post.sharesCount;

      for (final poll in post.polls) {
        if (poll.isPolledByCurrentUser) {
          if (poll.options.isNotEmpty) {
            _selectedVotes[poll.id] = poll.options.first.id;
          }
        }
      }
    }
  }

  Future<void> _fetchLikedUsers(String postId) async {
    if (_likedUsersLoadingMap[postId] == true ||
        _likedUsersMap.containsKey(postId)) {
      return;
    }

    setState(() => _likedUsersLoadingMap[postId] = true);
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (!mounted) return;
      setState(() {
        _likedUsersMap[postId] = users.take(3).toList();
        _likedUsersLoadingMap[postId] = false;
      });
    } catch (_) {
      if (mounted) setState(() => _likedUsersLoadingMap[postId] = false);
    }
  }

  Future<void> _refreshLikedUsersQuietly(String postId) async {
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (!mounted) return;
      setState(() => _likedUsersMap[postId] = users.take(3).toList());
    } catch (_) {}
  }

  // ── Like ───────────────────────────────────────────────────────────────────
  Future<void> _toggleLike(String postId) async {
    final prev = _likedMap[postId] ?? false;
    final prevCount = _likesCountMap[postId] ?? 0;

    setState(() {
      _likedMap[postId] = !prev;
      _likesCountMap[postId] = prev ? prevCount - 1 : prevCount + 1;
    });

    try {
      final result = await LikeService().togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: prev,
        currentLikesCount: prevCount,
      );

      if (mounted) {
        setState(() {
          _likedMap[postId] = result.isLiked;
          _likesCountMap[postId] = result.likesCount;
        });
        await _refreshLikedUsersQuietly(postId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _likedMap[postId] = prev;
          _likesCountMap[postId] = prevCount;
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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

  Uint8List? _decodeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(
        raw.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''),
      );
    } catch (_) {
      return null;
    }
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrlImage}$path';
  }

  String _formatCount(int count) {
    if (count <= 0) return '';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  bool _isImagePoll(HashtagPostModel post) =>
      post.polls.isNotEmpty &&
      post.polls.first.options.any((o) => o.image != null);

  bool _hasImageOptions(HashtagPollModel poll) =>
      poll.options.any((o) => o.image != null);

  bool _hasTextOptions(HashtagPollModel poll) =>
      poll.options.any((o) => o.text != null && o.text!.isNotEmpty);

  Widget _buildQuestionRow(
    BuildContext context,
    HashtagPollModel poll,
    AppTextColors txt, {
    VoidCallback? onVotesTap,
  }) {
    final int totalVotes = poll.options.fold<int>(
      0,
      (sum, opt) => sum + (int.tryParse(opt.voteCount) ?? 0),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            poll.question,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.heading,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (totalVotes > 0) ...[
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onVotesTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              '$totalVotes ${AppLocalizations.of(context)!.votes}',
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: widget.hashtag),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    if (_error != null) return _buildError();

    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'No posts found for #${widget.hashtag}',
          style: TextStyle(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onPrimary,
      onRefresh: _fetchPosts,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5),
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(12.h),
                child: Loader(color: Theme.of(context).colorScheme.onPrimary),
              ),
            );
          }
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  // ── Post card ──────────────────────────────────────────────────────────────
  Widget _buildPostCard(HashtagPostModel post) {
    final txt = AppTextColors.of(context);
    final isImage = _isImagePoll(post);
    final isLiked = _likedMap[post.id] ?? false;
    final likesCount = _likesCountMap[post.id] ?? 0;
    final commentsCount = _commentsCountMap[post.id] ?? 0;
    final sharesCount = _sharesCountMap[post.id] ?? 0;
    final likedUsers = _likedUsersMap[post.id] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(post),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),

          // Question row for first poll
          if (post.polls.isNotEmpty &&
              post.polls.first.question.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 2.h, 10.w, 5.h),
              child: _buildQuestionRow(
                context,
                post.polls.first,
                txt,
                onVotesTap: post.polls.first.pollType == 'hot_take'
                    ? () {
                        BottomSheetUtils.showPollVotersBottomSheet(
                          context: context,
                          postId: post.id.toString(),
                          question: post.polls.first.question,
                          pollType: post.polls.first.pollType,
                        );
                      }
                    : null,
              ),
            ),
          ],

          // Description
          if ((post.description ?? '').isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 7.h),
              child: _buildDescriptionWithHashtags(
                context,
                post.description!,
                txt,
              ),
            ),
          ],

          // Polls
          ...post.polls.asMap().entries.map((entry) {
            final poll = entry.value;
            final isFirst = entry.key == 0;
            final showQuestion = !isFirst;

            if (poll.pollType == 'hot_take') {
              return _buildHotTakePollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else if (poll.pollType == 'battle') {
              return _buildBattlePollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else if (poll.pollType == 'this_or_that') {
              return _buildThisOrThatPollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else if (poll.pollType == 'anonymous' &&
                _hasImageOptions(poll) &&
                _hasTextOptions(poll)) {
              return _buildAnonymousImageTextPollSection(
                context,
                poll,
                post,
                showQuestion: showQuestion,
              );
            } else {
              return isImage
                  ? _buildImagePollBlock(
                      poll,
                      post.id,
                      post.isPolledByCurrentUser,
                    )
                  : _buildTextPollBlock(poll, post, showQuestion: showQuestion);
            }
          }),

          const SizedBox(height: 10),

          // Interaction bar
          _buildInteractionBar(
            post: post,
            isLiked: isLiked,
            likesCount: likesCount,
            commentsCount: commentsCount,
            sharesCount: sharesCount,
          ),

          // Liked users avatars + text
          if (likesCount > 0 && likedUsers.isNotEmpty) ...[
            SizedBox(height: 4.h),
            GestureDetector(
              onTap: () => BottomSheetUtils.showLikedUsersBottomSheet(
                context: context,
                postId: post.id,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LikeUtils.buildLikeAvatarsStack(
                      context,
                      likedUsers,
                      avatarSize: 15,
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
                              likedUsers,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(HashtagPostModel post) {
    final txt = AppTextColors.of(context);
    final String? profileUrl = post.user.profileImage;
    final avatarBytes = _decodeBase64(profileUrl);

    ImageProvider? avatarImage;
    if (avatarBytes != null) {
      avatarImage = MemoryImage(avatarBytes);
    } else if (profileUrl != null && profileUrl.isNotEmpty) {
      if (profileUrl.startsWith('http') ||
          profileUrl.startsWith('/') ||
          profileUrl.contains('/')) {
        final imageUrl = profileUrl.startsWith('http')
            ? profileUrl
            : (profileUrl.startsWith('/')
                  ? '${ApiConfig.baseUrlImage}$profileUrl'
                  : '${ApiConfig.baseUrlImage}/$profileUrl');
        avatarImage = CachedNetworkImageProvider(imageUrl);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PublicProfileScreen(
                username: post.user.username,
              ),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(0.1),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Text(
                      post.user.username.isNotEmpty
                          ? post.user.username[0].toUpperCase()
                          : 'P',
                      style: AppTextStyles.subText.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${post.user.firstName} ${post.user.lastName}'.trim().isNotEmpty
                      ? '${post.user.firstName} ${post.user.lastName}'.trim()
                      : post.user.username,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: txt.title,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      post.user.username.isNotEmpty
                          ? '@${post.user.username}'
                          : '${post.user.firstName} ${post.user.lastName}'.trim(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: txt.body,
                      ),
                    ),
                    Text(
                      '  • ${_timeAgo(DateTime.parse(post.createdAt))}',
                      style: TextStyle(
                        fontSize: 8.8.sp,
                        color: txt.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSinglePollVote(
    HashtagPollModel poll,
    dynamic optionId,
    String postId,
  ) async {
    try {
      final int optId = optionId is int
          ? optionId
          : int.tryParse(optionId.toString()) ?? 0;

      final List<Map<String, int>> votes = [
        {'option_id': optId, 'rank': 1},
      ];

      final result = await ApiService.voteOnPollSingle(
        postId: postId,
        votes: votes,
      );

      if (result['success'] == true) {
        showToast(message: 'Vote submitted successfully!');
        _fetchPosts();
      } else {
        showToast(
          message:
              result['message'] ?? 'Failed to submit vote. Please try again.',
        );
      }
    } catch (e) {
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  SinglePostModel _mapToSinglePost(HashtagPostModel post) {
    return SinglePostModel(
      id: post.id,
      firstName: post.user.firstName,
      lastName: post.user.lastName,
      user: SinglePostUser(
        uuid: post.user.userid,
        username: post.user.username,
        profileImage: post.user.profileImage ?? '',
      ),
      profileImage: post.user.profileImage ?? '',
      description: post.description ?? '',
      createdAt: post.createdAt,
      polls: post.polls
          .map(
            (p) => SinglePostPoll(
              id: p.id,
              type: p.type,
              pollType: p.pollType,
              votingType: p.voteType,
              isAnonymous: p.isAnonymous,
              settings: p.settings,
              question: p.question,
              maxOptions: p.settings['max_options'] as int? ?? 1,
              options: p.options
                  .map(
                    (o) => SinglePostPollOption(
                      id: o.id,
                      text: o.text,
                      image: o.image != null
                          ? SinglePostPollImage(
                              id: o.image!.id,
                              order: o.image!.order,
                              url: o.image!.url,
                              thumbnailUrl: o.image!.thumbnailUrl,
                            )
                          : null,
                      voteCount: o.voteCount,
                      percentage: o.percentage,
                      score: o.score.toDouble(),
                      rankDistribution: o.rankDistribution.map(
                        (k, v) => MapEntry(k, v),
                      ),
                      voters: o.voters
                          .map(
                            (v) => SinglePostVoter(
                              id: v.id,
                              username: v.username,
                              firstName: v.firstName,
                              lastName: v.lastName,
                              profilePictureUrl: v.profilePictureUrl,
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
              totalVotes: p.options
                  .fold<int>(
                    0,
                    (sum, opt) => sum + (int.tryParse(opt.voteCount) ?? 0),
                  )
                  .toString(),
              userVote: _selectedVotes[p.id],
            ),
          )
          .toList(),
      images: [],
      viewLikes: (_likedUsersMap[post.id] ?? []).isNotEmpty
          ? (_likedUsersMap[post.id] ?? [])
                .map(
                  (l) => SinglePostLike(
                    id: l.id,
                    username: l.username,
                    firstName: l.fullName ?? '',
                    lastName: '',
                    profilePictureUrl: l.profileImage,
                  ),
                )
                .toList()
          : post.viewLikes
                .map(
                  (l) => SinglePostLike(
                    id: l.id,
                    username: l.username,
                    firstName: l.firstName ?? '',
                    lastName: l.lastName ?? '',
                    profilePictureUrl: l.profileImage,
                  ),
                )
                .toList(),
      isLiked: _likedMap[post.id] ?? post.isLikedByCurrentUser,
      isPolledByCurrentUser: post.isPolledByCurrentUser,
      locationName: post.locationName,
      commentsCount: post.commentsCount,
      likesCount: _likesCountMap[post.id] ?? post.likesCount,
      followingStatus: post.followingStatus,
      sharesCount: post.sharesCount,
    );
  }

  void _navigateTextPoll(HashtagPostModel post, HashtagPollModel poll) {
    final isPolledByCurrentUser = post.isPolledByCurrentUser;

    if (isPolledByCurrentUser) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => ThingsResultScreen(
                username: post.user.username,
                postId: post.id.toString(),
              ),
            ),
          )
          .then((result) {
            if (result == true) _fetchPosts();
          });
    } else {
      final mappedPost = _mapToSinglePost(post);
      final mappedPoll = mappedPost.polls.firstWhere((p) => p.id == poll.id);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) =>
                  SinglePostThingsRanking(post: mappedPost, poll: mappedPoll),
            ),
          )
          .then((result) {
            if (result == true) _fetchPosts();
          });
    }
  }

  Widget _buildAnonymousOptionCard(
    BuildContext context,
    HashtagPollOption option,
    int index,
    bool hasUserPolled,
  ) {
    Widget imageWidget = const SizedBox.shrink();
    if (option.image != null) {
      imageWidget = AppCachedNetworkImage(
        imageUrl: _resolveUrl(option.image!.url),
        fit: BoxFit.cover,
      );
    }

    return SizedBox(
      height: 150.h,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.60),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              if (hasUserPolled)
                Positioned(
                  bottom: 2,
                  left: 8.w,
                  right: 8.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.text ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${option.percentage.round()}%',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Positioned(
                  bottom: 5.h,
                  left: 8.w,
                  right: 8.w,
                  child: Text(
                    option.text ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotTakePollSection(
    BuildContext context,
    HashtagPollModel poll,
    HashtagPostModel post, {
    bool showQuestion = true,
  }) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final double pct1 = poll.options.isNotEmpty
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = poll.options.length > 1
        ? poll.options[1].percentage
        : 0.0;

    final firstImage = poll.options.isEmpty
        ? null
        : (poll.options
              .firstWhere((o) => o.image != null, orElse: () => poll.options[0])
              .image);

    return GestureDetector(
      onTap: () {
        // Do not open ThingsResultScreen
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(
                context,
                poll,
                txt,
                onVotesTap: () {
                  BottomSheetUtils.showPollVotersBottomSheet(
                    context: context,
                    postId: post.id.toString(),
                    question: poll.question,
                    pollType: poll.pollType,
                  );
                },
              ),
            ],
            if (showQuestion && poll.question.isNotEmpty)
              const SizedBox(height: 12),
            if (firstImage != null) ...[
              GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 150.h,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: AppCachedNetworkImage(
                      imageUrl: _resolveUrl(firstImage.url),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(
              height: 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!post.isPolledByCurrentUser) {
                          final optionId = poll.options.isNotEmpty
                              ? poll.options[0].id
                              : null;
                          if (optionId != null) {
                            _submitSinglePollVote(poll, optionId, post.id);
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF101F1B)
                              : const Color(0xFFECFDF5),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF19322A)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: Stack(
                            children: [
                              if (post.isPolledByCurrentUser)
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct1 / 100.0,
                                      child: Container(
                                        color: isDarkMode
                                            ? const Color(0xFF0F3A2E)
                                            : const Color(
                                                0xFF16A34A,
                                              ).withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        post.isPolledByCurrentUser
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        Assets.images.icAgree.path,
                                        height: 22,
                                        width: 22,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Agree',
                                        style: AppTextStyles.sectionHeading
                                            .copyWith(
                                              color: isDarkMode
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF059669),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      if (post.isPolledByCurrentUser) ...[
                                        const Spacer(),
                                        Text(
                                          '${pct1.round()}%',
                                          style: AppTextStyles.sectionHeading
                                              .copyWith(
                                                color: isDarkMode
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFF059669),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!post.isPolledByCurrentUser) {
                          final optionId = poll.options.length > 1
                              ? poll.options[1].id
                              : null;
                          if (optionId != null) {
                            _submitSinglePollVote(poll, optionId, post.id);
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF201315)
                              : const Color(0xFFFDE5E5),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFFCB5B5B).withOpacity(0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Stack(
                            children: [
                              if (post.isPolledByCurrentUser)
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct2 / 100.0,
                                      child: Container(
                                        color: isDarkMode
                                            ? const Color(0xFF4C1D24)
                                            : const Color(0xFFFECACA),
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        post.isPolledByCurrentUser
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        Assets.images.icDisagree.path,
                                        height: 22,
                                        width: 22,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Disagree',
                                        style: AppTextStyles.sectionHeading
                                            .copyWith(
                                              color: isDarkMode
                                                  ? const Color(0xFFE53E3E)
                                                  : const Color(0xFFC81E1E),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      if (post.isPolledByCurrentUser) ...[
                                        const Spacer(),
                                        Text(
                                          '${pct2.round()}%',
                                          style: AppTextStyles.sectionHeading
                                              .copyWith(
                                                color: isDarkMode
                                                    ? const Color(0xFFE53E3E)
                                                    : const Color(0xFFC81E1E),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildBattlePollSection(
    BuildContext context,
    HashtagPollModel poll,
    HashtagPostModel post, {
    bool showQuestion = true,
  }) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = poll.options.isNotEmpty ? poll.options[0].text ?? '' : '';
    final option2 = poll.options.length > 1 ? poll.options[1].text ?? '' : '';

    final double pct1 = poll.options.isNotEmpty
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = poll.options.length > 1
        ? poll.options[1].percentage
        : 0.0;

    final hasImages = _hasImageOptions(poll);

    return GestureDetector(
      onTap: () {
        if (post.isPolledByCurrentUser) {
          if (hasImages) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ThingsResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (showQuestion && poll.question.isNotEmpty)
              const SizedBox(height: 12),
            if (hasImages) ...[
              GestureDetector(
                onTap: post.isPolledByCurrentUser ? null : () {},
                child: SizedBox(
                  height: 150.h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.isNotEmpty
                                          ? poll.options[0].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(
                                          poll,
                                          optionId,
                                          post.id,
                                        );
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card - 1.2,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.isNotEmpty &&
                                          poll.options[0].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: _resolveUrl(
                                            poll.options[0].image!.url,
                                          ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option1,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                '${pct1.round()}%',
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option1,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.length > 1
                                          ? poll.options[1].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(
                                          poll,
                                          optionId,
                                          post.id,
                                        );
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card - 1.2,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.length > 1 &&
                                          poll.options[1].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: _resolveUrl(
                                            poll.options[1].image!.url,
                                          ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option2,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                '${pct2.round()}%',
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option2,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          width: 36.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
                                  : const [
                                      Color(0xFF111111),
                                      Color(0xFF2C2C2C),
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2E323D)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Vs',
                            style: TextStyle(
                              color: isDarkMode ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: post.isPolledByCurrentUser ? 70 : 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!post.isPolledByCurrentUser) {
                                final optionId = poll.options.isNotEmpty
                                    ? poll.options[0].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(
                                    poll,
                                    optionId,
                                    post.id,
                                  );
                                }
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.2),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (post.isPolledByCurrentUser) ...[
                                    Text(
                                      '${pct1.round()}%',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    option1,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: txt.title,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 18.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!post.isPolledByCurrentUser) {
                                final optionId = poll.options.length > 1
                                    ? poll.options[1].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(
                                    poll,
                                    optionId,
                                    post.id,
                                  );
                                }
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.2),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (post.isPolledByCurrentUser) ...[
                                    SizedBox(height: 4.h),
                                    Text(
                                      '${pct2.round()}%',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    option2,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: txt.title,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? const [
                                    Color(0xFFFFFFFF), // 0%
                                    Color(0xFFFCFCFC), // 100%
                                  ]
                                : const [Color(0xFF111111), Color(0xFF2C2C2C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF2E323D)
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Vs',
                          style: TextStyle(
                            color: isDarkMode ? Colors.black : Colors.white,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildThisOrThatPollSection(
    BuildContext context,
    HashtagPollModel poll,
    HashtagPostModel post, {
    bool showQuestion = true,
  }) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = poll.options.isNotEmpty ? poll.options[0].text ?? '' : '';
    final option2 = poll.options.length > 1 ? poll.options[1].text ?? '' : '';

    final double pct1 = poll.options.isNotEmpty
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = poll.options.length > 1
        ? poll.options[1].percentage
        : 0.0;

    final hasImages = _hasImageOptions(poll);

    return GestureDetector(
      onTap: () {
        if (post.isPolledByCurrentUser) {
          if (hasImages) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ThingsResultScreen(
                  username: post.user.username,
                  postId: post.id.toString(),
                ),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (showQuestion && poll.question.isNotEmpty)
              const SizedBox(height: 12),
            if (hasImages) ...[
              GestureDetector(
                onTap: post.isPolledByCurrentUser ? null : () {},
                child: SizedBox(
                  height: 150.h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.isNotEmpty
                                          ? poll.options[0].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(
                                          poll,
                                          optionId,
                                          post.id,
                                        );
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card - 1.2,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.isNotEmpty &&
                                          poll.options[0].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: _resolveUrl(
                                            poll.options[0].image!.url,
                                          ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option1,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                '${pct1.round()}%',
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option1,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: post.isPolledByCurrentUser
                                  ? null
                                  : () {
                                      final optionId = poll.options.length > 1
                                          ? poll.options[1].id
                                          : null;
                                      if (optionId != null) {
                                        _submitSinglePollVote(
                                          poll,
                                          optionId,
                                          post.id,
                                        );
                                      }
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary.withOpacity(0.10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card - 1.2,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (poll.options.length > 1 &&
                                          poll.options[1].image != null)
                                        AppCachedNetworkImage(
                                          imageUrl: _resolveUrl(
                                            poll.options[1].image!.url,
                                          ),
                                          fit: BoxFit.cover,
                                          showSpinnerPlaceholder: true,
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.60),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      if (post.isPolledByCurrentUser)
                                        Positioned(
                                          bottom: 2,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                option2,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                '${pct2.round()}%',
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 5.h,
                                          left: 8.w,
                                          right: 8.w,
                                          child: Text(
                                            option2,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          width: 36.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
                                  : const [
                                      Color(0xFF111111),
                                      Color(0xFF2C2C2C),
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2E323D)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Or',
                            style: TextStyle(
                              color: isDarkMode ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              SizedBox(
                height: post.isPolledByCurrentUser ? 70 : 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!post.isPolledByCurrentUser) {
                                final optionId = poll.options.isNotEmpty
                                    ? poll.options[0].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(
                                    poll,
                                    optionId,
                                    post.id,
                                  );
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF242831)
                                    : Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    option1,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1F2937),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  if (post.isPolledByCurrentUser) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${pct1.round()}%',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: isDarkMode
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!post.isPolledByCurrentUser) {
                                final optionId = poll.options.length > 1
                                    ? poll.options[1].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(
                                    poll,
                                    optionId,
                                    post.id,
                                  );
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF242831)
                                    : Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    option2,
                                    style: AppTextStyles.sectionHeading
                                        .copyWith(
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1F2937),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  if (post.isPolledByCurrentUser) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${pct2.round()}%',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: isDarkMode
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? const [Color(0xFFFFFFFF), Color(0xFFFCFCFC)]
                                : const [Color(0xFF111111), Color(0xFF2C2C2C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF2E323D)
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Or',
                          style: TextStyle(
                            color: isDarkMode ? Colors.black : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildAnonymousImageTextPollSection(
    BuildContext context,
    HashtagPollModel poll,
    HashtagPostModel post, {
    bool showQuestion = true,
  }) {
    final txt = AppTextColors.of(context);
    final validOptions = poll.options
        .where((o) => o.image != null && o.text != null && o.text!.isNotEmpty)
        .toList();

    if (validOptions.isEmpty) return const SizedBox.shrink();

    final hasUserPolled = post.isPolledByCurrentUser;

    Widget optionsWidget;
    if (validOptions.length == 4) {
      optionsWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[0],
                  0,
                  hasUserPolled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[1],
                  1,
                  hasUserPolled,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[2],
                  2,
                  hasUserPolled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnonymousOptionCard(
                  context,
                  validOptions[3],
                  3,
                  hasUserPolled,
                ),
              ),
            ],
          ),
        ],
      );
    } else if (validOptions.length == 3) {
      optionsWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[0],
              0,
              hasUserPolled,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[1],
              1,
              hasUserPolled,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAnonymousOptionCard(
              context,
              validOptions[2],
              2,
              hasUserPolled,
            ),
          ),
        ],
      );
    } else {
      optionsWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(validOptions.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < validOptions.length - 1 ? 10 : 0,
              ),
              child: _buildAnonymousOptionCard(
                context,
                validOptions[index],
                index,
                hasUserPolled,
              ),
            ),
          );
        }),
      );
    }

    return GestureDetector(
      onTap: () =>
          _showAllImagesGrid(post.id, poll, post.isPolledByCurrentUser),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showQuestion && poll.question.isNotEmpty) ...[
              SizedBox(height: 5.h),
              _buildQuestionRow(context, poll, txt),
            ],
            if (showQuestion && poll.question.isNotEmpty)
              SizedBox(height: 12.h),
            optionsWidget,
            SizedBox(height: 5.h),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMAGE POLL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildImagePollBlock(
    HashtagPollModel poll,
    String postId,
    bool isPolledByCurrentUser,
  ) {
    final validImages = poll.options.where((o) => o.image != null).toList();
    if (validImages.isEmpty) return const SizedBox.shrink();

    List<Alignment> getAlignments(int total) {
      switch (total) {
        case 1:
          return [Alignment.center];
        case 2:
          return [Alignment.centerLeft, Alignment.centerRight];
        case 3:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
          ];
        default:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.centerRight,
          ];
      }
    }

    final alignments = getAlignments(validImages.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final imageHeight = 150.h;

          return GestureDetector(
            onTap: () =>
                _showAllImagesGrid(postId, poll, isPolledByCurrentUser),
            child: SizedBox(
              height: imageHeight,
              width: availableWidth,
              child: Stack(
                children: validImages
                    .asMap()
                    .entries
                    .map<Widget>((entry) {
                      final index = entry.key;
                      final opt = entry.value;
                      final alignment = alignments[index];
                      double imageWidth =
                          (availableWidth * 0.7) - (index * 8.0);
                      imageWidth = imageWidth < 60.w ? 60.w : imageWidth;
                      final imageUrl = opt.image != null
                          ? _resolveUrl(opt.image!.url)
                          : '';

                      return Align(
                        alignment: alignment,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: imageWidth,
                          height: imageHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            value:
                                                progress.expectedTotalBytes !=
                                                    null
                                                ? progress.cumulativeBytesLoaded /
                                                      progress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  )
                                : _imagePlaceholder(),
                          ),
                        ),
                      );
                    })
                    .toList()
                    .reversed
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.r),
      color: Colors.grey[200],
    ),
    child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 30),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT POLL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTextPollBlock(
    HashtagPollModel poll,
    HashtagPostModel post, {
    bool showQuestion = true,
  }) {
    final hasUserPolled = _selectedVotes.containsKey(poll.id);
    final totalVotes = poll.options.fold<int>(
      0,
      (sum, opt) => sum + (int.tryParse(opt.voteCount) ?? 0),
    );

    final showPolledUi = post.isPolledByCurrentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showQuestion) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateTextPoll(post, poll),
                    child: Text(
                      poll.question,
                      style: AppTextStyles.bodyText.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '$totalVotes ${AppLocalizations.of(context)!.votes}',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (showPolledUi)
            _buildTextPolledOptions(poll, () => _navigateTextPoll(post, poll))
          else
            ...poll.options.asMap().entries.map(
              (e) => GestureDetector(
                onTap: () => _navigateTextPoll(post, poll),
                child: _buildTextOptionRow(
                  option: e.value,
                  optionIndex: e.key,
                  poll: poll,
                  totalVotes: totalVotes,
                  showPercentage: hasUserPolled,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextOptionRow({
    required HashtagPollOption option,
    required int optionIndex,
    required HashtagPollModel poll,
    required int totalVotes,
    required bool showPercentage,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double percentage = option.percentage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 10.h),
      height: 27.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242831) : const Color(0xFFF5F6F7),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: isDark ? const Color(0xFF30353D) : const Color(0xFFE8E8E8),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          if (showPercentage && percentage > 0)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('bar_${poll.id}_${option.id}_$percentage'),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: percentage / 100),
                builder: (_, value, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF30353D)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 3.h, 8.w, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    option.text ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (showPercentage)
                  TweenAnimationBuilder<int>(
                    key: ValueKey('pct_${poll.id}_${option.id}_$percentage'),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    tween: IntTween(begin: 0, end: percentage.round()),
                    builder: (_, val, __) => Text(
                      '$val%',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPolledOptions(HashtagPollModel poll, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: poll.options.map((option) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option.text ?? '',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${option.percentage.toInt()}%',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9D9D9).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: (option.percentage / 100).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9E2A46),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Interaction bar ────────────────────────────────────────────────────────
  Widget _buildInteractionBar({
    required HashtagPostModel post,
    required bool isLiked,
    required int likesCount,
    required int commentsCount,
    required int sharesCount,
  }) {
    final txt = AppTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Like
          GestureDetector(
            onTap: () => _toggleLike(post.id),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: isLiked
                      ? AppIcons.filledHeart(key: const ValueKey('filled'))
                      : AppIcons.outlineHeart(key: const ValueKey('outline')),
                ),
                const SizedBox(width: 8),
                Text(
                  LikeService.getLikesCountText(likesCount),
                  style: AppTextStyles.subText.copyWith(
                    color: txt.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Comment
          GestureDetector(
            onTap: () => BottomSheetUtils.showCommentsBottomSheet(
              context: context,
              postId: post.id,
              currentUsername: post.user.username,
              onCommentsCountChanged: (count) {
                if (mounted) setState(() => _commentsCountMap[post.id] = count);
              },
            ),
            child: Row(
              children: [
                AppIcons.commnetBox(),
                SizedBox(width: 3.w),
                Text(
                  _formatCount(commentsCount),
                  style: AppTextStyles.subText.copyWith(
                    color: txt.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Share
          GestureDetector(
            onTap: () => ShareService.sharePost(
              post,
              context: context,
              usernameOverride: post.user.username,
              onShareSuccess: (newCount) {
                if (mounted) {
                  setState(() => _sharesCountMap[post.id] = newCount);
                }
              },
            ),
            child: Row(
              children: [
                AppIcons.sharePost(),
                const SizedBox(width: 8),
                Text(
                  _formatCount(sharesCount),
                  style: AppTextStyles.subText.copyWith(
                    color: txt.body,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: _textSecondary, size: 40.sp),
          SizedBox(height: 12.h),
          Text(
            'Failed to load posts',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _error ?? '',
            style: TextStyle(fontSize: 10.sp, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: _fetchPosts,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionWithHashtags(
    BuildContext context,
    String description,
    AppTextColors txt,
  ) {
    if (!description.contains('#')) {
      return Text(
        description,
        style: AppTextStyles.bodyText.copyWith(
          color: txt.body,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final RegExp exp = RegExp(r'(#[a-zA-Z0-9_]+)');
    final List<TextSpan> spans = [];

    description.splitMapJoin(
      exp,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: AppTextStyles.bodyText.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String text) {
        if (text.isNotEmpty) {
          spans.add(
            TextSpan(
              text: text,
              style: AppTextStyles.bodyText.copyWith(
                color: txt.body,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }
        return '';
      },
    );

    return RichText(text: TextSpan(children: spans));
  }
}
