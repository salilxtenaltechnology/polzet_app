// ignore_for_file: deprecated_member_use
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/dialog/custom_diolog.dart';
import '../../../api/services/like/like_service.dart';
import '../../../models/like/like_uers_model.dart';
import '../../../widgets/show_toast.dart';
import '../../../core/utils/like_util.dart';
import '../../../api/services/share/share_service.dart';
import '../../../models/posts/user_post_model.dart';
import '../../../widgets/loader.dart';
import '../../../api/api_config.dart';
import '../home feed/rank/result/image/image_result_screen.dart';
import '../home feed/rank/result/things/things_result_screen.dart';
import '../settings/new_settings_screen.dart';
import 'chase/user_chase.dart';
import 'edit_profile/new_edit_profile.dart';
import 'rank/image/user_image_ranking.dart';
import 'rank/things/user_things_ranking.dart';

class ProfileScreen extends StatefulWidget {
  final String handle;
  final String? avatarUrl;

  const ProfileScreen({super.key, this.handle = '', this.avatarUrl});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, UtilityMixin {
  late TabController _tabController;

  final ApiService apiService = ApiService();

  final Map<String, Uint8List?> _decodedImageCache = {};

  Uint8List? _getCachedProfileImage(String? base64Str, UserProvider provider) {
    if (base64Str == null || base64Str.isEmpty) return null;
    if (_decodedImageCache.containsKey(base64Str)) {
      return _decodedImageCache[base64Str];
    }
    final bytes = provider.getProfileImage(base64Str);
    _decodedImageCache[base64Str] = bytes;
    return bytes;
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

  List<UserPostModel>? _thingsPosts;
  List<UserPostModel>? _imagesPosts;
  bool _isLoadingThings = true;
  bool _isLoadingImages = true;
  int? _totalPollsCount;

  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};
  Map<int, int> postCommentsCounts = {};
  Map<int, List<LikeUser>> postLikedUsers = {};
  Map<int, bool> likedUsersLoading = {};
  late final LikeService likeService = LikeService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final username = userProvider.username;

    if (username != null) {
      if (userProvider.cachedThingsPostsMap.containsKey(username)) {
        _thingsPosts = userProvider.cachedThingsPostsMap[username];
        _isLoadingThings = false;
      }
      if (userProvider.cachedImagesPostsMap.containsKey(username)) {
        _imagesPosts = userProvider.cachedImagesPostsMap[username];
        _isLoadingImages = false;
      }
      if (userProvider.cachedTotalPollsCountMap.containsKey(username)) {
        _totalPollsCount = userProvider.cachedTotalPollsCountMap[username];
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPosts();
    });
  }

  Future<void> _handleRefresh() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUserDataSilently();
    await _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final username = userProvider.username;
    if (username == null || username.isEmpty) return;

    try {
      final things = await apiService.fetchOnlyPollPosts(username);
      if (mounted) {
        setState(() {
          _thingsPosts = things.where((post) {
            if (post.polls.isEmpty) return false;
            return post.polls.every(
              (poll) =>
                  poll.options != null &&
                  poll.options!.every(
                    (o) => o.text != null && o.text!.isNotEmpty,
                  ),
            );
          }).toList();
          userProvider.cachedThingsPostsMap[username] = _thingsPosts!;
          for (var post in _thingsPosts!) {
            postLikeStates[post.id] = post.isLiked;
            postLikeCounts[post.id] = post.likesCount;
            postCommentsCounts[post.id] = post.commentsCount;
            if (post.likesCount > 0) _fetchLikedUsersSilently(post.id);
          }
          _isLoadingThings = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingThings = false);
    }

    try {
      final images = await apiService.fetchPostsImages(username);
      if (mounted) {
        setState(() {
          _imagesPosts = images.where((post) {
            return post.polls.any(
              (poll) => poll.options?.any((o) => o.image != null) ?? false,
            );
          }).toList();
          userProvider.cachedImagesPostsMap[username] = _imagesPosts!;
          for (var post in _imagesPosts!) {
            postLikeStates[post.id] = post.isLiked;
            postLikeCounts[post.id] = post.likesCount;
            postCommentsCounts[post.id] = post.commentsCount;
            if (post.likesCount > 0) _fetchLikedUsersSilently(post.id);
          }
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingImages = false);
    }

    if (mounted) {
      setState(() {
        _totalPollsCount =
            (_thingsPosts?.length ?? 0) + (_imagesPosts?.length ?? 0);
        if (_totalPollsCount != null) {
          userProvider.cachedTotalPollsCountMap[username] = _totalPollsCount!;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  void _showAllImagesGrid(
    int postId,
    UserPollQuestion poll,
    bool isPolledByCurrentUser,
    UserPostModel post,
  ) {
    if (isPolledByCurrentUser) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ImageResultScreen(username: post.user, postId: post.id),
        ),
      );
    } else {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => UserImageRanking(
                post: post,
                poll: poll,
                firstName: userProvider.firstName,
                lastName: userProvider.lastName,
                profileImage: userProvider.profile_picture,
              ),
            ),
          )
          .then((result) {
            if (result == true) {
              setState(() {});
              _fetchPosts();
            }
          });
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      bool success = await apiService.userDeletePost(postId);
      if (success) {
        if (mounted) {
          setState(() {
            _thingsPosts?.removeWhere((post) => post.id == postId);
            _imagesPosts?.removeWhere((post) => post.id == postId);
            postLikeStates.remove(postId);
            postLikeCounts.remove(postId);
            postCommentsCounts.remove(postId);
            postLikedUsers.remove(postId);
            likedUsersLoading.remove(postId);
            _totalPollsCount =
                (_thingsPosts?.length ?? 0) + (_imagesPosts?.length ?? 0);

            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            final username = userProvider.username;
            if (username != null) {
              if (_thingsPosts != null) {
                userProvider.cachedThingsPostsMap[username] = _thingsPosts!;
              }
              if (_imagesPosts != null) {
                userProvider.cachedImagesPostsMap[username] = _imagesPosts!;
              }
              if (_totalPollsCount != null) {
                userProvider.cachedTotalPollsCountMap[username] =
                    _totalPollsCount!;
              }
            }
          });
        }
        showToast(message: 'Post deleted successfully');
      } else {
        showToast(message: 'Failed to delete post');
      }
    } catch (error) {
      showToast(message: 'Error: ${error.toString()}');
    }
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

        if (!result.success) {
          showToast(message: result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          postLikeStates[postId] = currentLikeState;
          postLikeCounts[postId] = currentLikeCount;
        });
        showToast(message: 'Failed to update like');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 35.h,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Profile',
          style: AppTextStyles.pageTitleTextStyle(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // navigationPush(context, const Settings());
              navigationPush(context, const NewSettingsScreen());
            },
            icon: const Icon(
              FeatherIcons.settings,
              size: 22,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Theme.of(context).colorScheme.primary,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(child: _buildHeader(top, userProvider)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.onBackground,
                    labelStyle: AppTextStyles.bodyText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    indicator: FadeUnderlineTabIndicator(),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    unselectedLabelColor: const Color(0XFF8E8E8E),
                    tabs: const [
                      Tab(text: 'Things'),
                      Tab(text: 'Images'),
                      Tab(text: 'Saved'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _isLoadingThings
                  ? Center(
                      child: Loader(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : (_thingsPosts == null || _thingsPosts!.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            Assets.images.noThingsPost.path,
                            height: 0.20.sh,
                            width: 0.20.sh,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No things poll yet',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.sectionHeading.copyWith(
                              fontSize: 18.5,
                              color: Theme.of(context).colorScheme.onBackground,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Create your first poll and start\ngathering opinions.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13,
                              color: const Color(0xFF595959),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      itemCount: _thingsPosts!.length,
                      itemBuilder: (context, index) {
                        return _buildSimplePostCard(
                          _thingsPosts![index],
                          isImage: false,
                          userProvider: userProvider,
                        );
                      },
                    ),
              _isLoadingImages
                  ? Center(
                      child: Loader(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : (_imagesPosts == null || _imagesPosts!.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            Assets.images.noImagePoll.path,
                            height: 0.20.sh,
                            width: 0.20.sh,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No image poll yet',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.sectionHeading.copyWith(
                              fontSize: 18.5,
                              color: Theme.of(context).colorScheme.onBackground,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Create your first poll and start\ngathering opinions.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13,
                              color: const Color(0xFF595959),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      itemCount: _imagesPosts!.length,
                      itemBuilder: (context, index) {
                        return _buildSimplePostCard(
                          _imagesPosts![index],
                          isImage: true,
                          userProvider: userProvider,
                        );
                      },
                    ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      Assets.images.noSavedPost.path,
                      height: 0.20.sh,
                      width: 0.20.sh,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nothing saved yet',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sectionHeading.copyWith(
                        fontSize: 18.5,
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Save polls you want to revisit later.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13,
                        color: const Color(0xFF595959),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double topPadding, UserProvider userProvider) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {},
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: (() {
                      final cachedImage = _getCachedProfileImage(
                        userProvider.profile_picture,
                        userProvider,
                      );
                      if (cachedImage != null) {
                        return Image.memory(
                          cachedImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                            username: userProvider.username,
                            fontSize: 35,
                          ),
                        );
                      } else {
                        return _AvatarPlaceholder(
                          username: userProvider.username,
                          fontSize: 35,
                        );
                      }
                    })(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Name
          Text(
            userProvider.isLoading
                ? '-'
                : (userProvider.firstName != null &&
                          userProvider.firstName!.isNotEmpty
                      ? '${userProvider.firstName} ${userProvider.lastName ?? ''}'
                            .trim()
                      : (userProvider.username ?? 'Polzet User')),
            style: AppTextStyles.sectionHeading.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            userProvider.isLoading
                ? '-'
                : (userProvider.username != null
                      ? '@${userProvider.username}'
                      : '@polzet_user'),
            style: AppTextStyles.subText.copyWith(
              color: const Color(0XFF898989),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatCard(
                  value: userProvider.isLoading
                      ? '-'
                      : (userProvider.counts?['rechasing']?.toString() ?? '0'),
                  label: 'Re-chase',
                  onTap: () => navigationPush(
                    context,
                    UserChase(
                      username: userProvider.username ?? '-',
                      followingCount:
                          (userProvider.counts?['rechasing']?.toString() ??
                          '0'),
                      followerCount:
                          (userProvider.counts?['chasing']?.toString() ?? '0'),
                      initialIndex: 1,
                      chaseList: userProvider.chase_list,
                      rechaseList: userProvider.rechase_list,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: userProvider.isLoading
                      ? '-'
                      : (userProvider.counts?['chasing']?.toString() ?? '0'),
                  label: 'Chase',
                  onTap: () => navigationPush(
                    context,
                    UserChase(
                      username: userProvider.username ?? '-',
                      followingCount:
                          (userProvider.counts?['rechasing']?.toString() ??
                          '0'),
                      followerCount:
                          (userProvider.counts?['chasing']?.toString() ?? '0'),
                      initialIndex: 0,
                      chaseList: userProvider.chase_list,
                      rechaseList: userProvider.rechase_list,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: userProvider.isLoading || _totalPollsCount == null
                      ? '0'
                      : _totalPollsCount.toString(),
                  label: 'Polls',
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        navigationPush(context, const NewEditProfile());
                      },
                      icon: const Icon(
                        FeatherIcons.edit2,
                        // Icons.edit_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Edit Profile',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFDDDDDD),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      'Share profile',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 14.5,
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  FeatherIcons.moreVertical,
                  size: 25,
                  color: Color(0XFF727272),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSimplePostCard(
    UserPostModel post, {
    required bool isImage,
    required UserProvider userProvider,
  }) {
    if (post.polls.isEmpty) return const SizedBox.shrink();
    final poll = post.polls.first;

    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = postCommentsCounts[post.id] ?? post.commentsCount;
    final viewLikes = postLikedUsers[post.id] ?? [];
    final currentUsername = userProvider.username ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: (() {
                      final cachedImage = _getCachedProfileImage(
                        userProvider.profile_picture,
                        userProvider,
                      );
                      if (cachedImage != null) {
                        return Image.memory(
                          cachedImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                            username: userProvider.username,
                            fontSize: 18,
                          ),
                        );
                      } else {
                        return _AvatarPlaceholder(
                          username: userProvider.username,
                          fontSize: 18,
                        );
                      }
                    })(),
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProvider.isLoading
                          ? '-'
                          : (userProvider.firstName != null &&
                                    userProvider.firstName!.isNotEmpty
                                ? '${userProvider.firstName} ${userProvider.lastName ?? ''}'
                                      .trim()
                                : (userProvider.username ?? 'Polzet User')),
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: const Color(0XFF2C2C2C),
                        fontSize: 14,
                      ),
                    ),

                    //const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          userProvider.isLoading
                              ? '-'
                              : (userProvider.username != null
                                    ? '@${userProvider.username}'
                                    : '@polzet_user'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0XFF595959),
                          ),
                        ),
                        Text(
                          '  • ${_timeAgo(post.createdAt)}',
                          style: AppTextStyles.subText.copyWith(
                            color: const Color(0xFF727272),
                            fontWeight: FontWeight.w400,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    showUserDeletePostDiolog(context, () {
                      Navigator.pop(context);
                      _deletePost(post.id);
                    });
                  },
                  child: const Icon(
                    FeatherIcons.moreVertical,
                    size: 22,
                    color: Color(0xFF727272),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFDCDCDC)),
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        poll.question,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ),
                    if (isImage)
                      Text(
                        '${poll.totalVotes} votes',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0XFF8E8E8E),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16.h),
                if (isImage)
                  _buildImagesStack(post)
                else
                  _buildTextOptions(poll, () {
                    if (post.is_polled_by_current_user) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ThingsResultScreen(
                            username: post.user,
                            postId: post.id,
                          ),
                        ),
                      );
                    } else {
                      final userProvider = Provider.of<UserProvider>(
                        context,
                        listen: false,
                      );
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => UserThingsRanking(
                                firstName: userProvider.firstName,
                                lastName: userProvider.lastName,
                                profileImage: userProvider.profile_picture,
                                post: post,
                                poll: poll,
                              ),
                            ),
                          )
                          .then((result) {
                            if (result == true) {
                              setState(() {});
                              _fetchPosts();
                            }
                          });
                    }
                  }),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(post.id),
                      child: isLiked
                          ? AppIcons.filledHeart(key: const ValueKey('filled'))
                          : AppIcons.outlineHeart(
                              key: const ValueKey('outline'),
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.6),
                            ),
                    ),
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () =>
                          _showLikedUsersBottomSheet(post.id, currentUsername),
                      child: Text('$likesCount'),
                    ),
                    SizedBox(width: 16.w),
                    GestureDetector(
                      onTap: () =>
                          _showCommentsBottomSheet(post.id, currentUsername),
                      child: AppIcons.commnetBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () =>
                          _showCommentsBottomSheet(post.id, currentUsername),
                      child: Text('$commentsCount'),
                    ),
                    SizedBox(width: 16.w),
                    GestureDetector(
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
                    ),
                    const Spacer(),
                    Icon(
                      FeatherIcons.bookmark,
                      size: 20.sp,
                      color: Colors.black54,
                    ),
                  ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildTextOptions(UserPollQuestion poll, VoidCallback onTap) {
    if (poll.options == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: poll.options!.map((option) {
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
                          Text(
                            option.text ?? '',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${option.percentage.toInt()}%',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground,
                                ),
                              ),
                            ],
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
                              color: const Color(0XFFD9D9D9).withOpacity(0.5),
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
                SizedBox(width: 15.w),
                Text(
                  '${option.voteCount} votes',
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0XFF8E8E8E),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImagesStack(UserPostModel post) {
    if (post.polls.isEmpty) return const SizedBox.shrink();

    List<PollOptionImage> validImages = [];
    UserPollQuestion? firstPollWithImages;

    for (var p in post.polls) {
      if (p.options != null) {
        for (var option in p.options!) {
          if (option.image != null) {
            validImages.add(option.image!);
            firstPollWithImages ??= p;
          }
        }
      }
    }

    if (validImages.isEmpty || firstPollWithImages == null) {
      return const SizedBox.shrink();
    }

    List<Alignment> getAlignments(int totalImages) {
      switch (totalImages) {
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
        case 4:
        default:
          return [
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.centerRight,
          ];
      }
    }

    List<Alignment> alignments = getAlignments(validImages.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double imageHeight = 150.h;

        return GestureDetector(
          onTap: () => _showAllImagesGrid(
            post.id,
            firstPollWithImages!,
            post.is_polled_by_current_user,
            post,
          ),
          child: SizedBox(
            height: imageHeight,
            width: availableWidth,
            child: Stack(
              children: validImages
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    int index = entry.key;
                    PollOptionImage imageData = entry.value;
                    Alignment alignment = alignments[index];
                    double imageWidth = (availableWidth * 0.7) - (index * 8.0);
                    imageWidth = imageWidth < 60.w ? 60.w : imageWidth;

                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        width: imageWidth,
                        height: imageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: Image.network(
                              '${ApiConfig.baseUrlImage}${imageData.url}',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.button,
                                    ),
                                    color: Colors.grey[200],
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[600],
                                    size: 30,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                        color: Colors.grey[200],
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
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
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final String? username;
  final double fontSize;

  const _AvatarPlaceholder({this.username, this.fontSize = 35});

  @override
  Widget build(BuildContext context) {
    String firstLetter = 'P';
    if (username != null && username!.isNotEmpty) {
      firstLetter = username![0].toUpperCase();
    }

    return Container(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.09),
      child: Center(
        child: Text(
          firstLetter,
          style: AppTextStyles.bodyText.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;
  const _StatCard({
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: const Color(0XFFEFEFEF), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0x00000000).withOpacity(0.06),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.sectionHeading.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                color: const Color(0xFF898989),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
