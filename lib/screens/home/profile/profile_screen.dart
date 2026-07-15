// ignore_for_file: invalid_null_aware_operator, unnecessary_non_null_assertion, unnecessary_null_comparison, deprecated_member_use
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../api/api_service.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/bottomsheet_util.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
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
import '../../../widgets/image/app_cached_network_image.dart';
import '../../../api/api_config.dart';
import '../home feed/rank/result/image/image_result_screen.dart';
import '../home feed/rank/result/things/things_result_screen.dart';
import '../settings/settings_screen.dart';
import 'chase/user_chase.dart';
import 'edit_profile/edit_profile.dart';
import 'rank/image/user_image_ranking.dart';
import 'rank/things/user_things_ranking.dart';
import 'widgets/profile_image_preview.dart';
import '../../../widgets/expandable_bio.dart';

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

  Map<String, bool> postLikeStates = {};
  Map<String, int> postLikeCounts = {};
  Map<String, int> postCommentsCounts = {};
  Map<String, int> postSharesCounts = {};
  Map<String, List<LikeUser>> postLikedUsers = {};
  Map<String, bool> likedUsersLoading = {};
  late final LikeService likeService = LikeService();

  void _initializePostStates(List<UserPostModel> posts) {
    for (var post in posts) {
      postLikeStates[post.id] = post.isLiked;
      postLikeCounts[post.id] = post.likesCount;
      postCommentsCounts[post.id] = post.commentsCount;
      postSharesCounts[post.id] = post.sharesCount;
      if (post.likesCount > 0) {
        _fetchLikedUsersSilently(post.id);
      }
    }
  }

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
        if (_thingsPosts != null) {
          _initializePostStates(_thingsPosts!);
        }
      }
      if (userProvider.cachedImagesPostsMap.containsKey(username)) {
        _imagesPosts = userProvider.cachedImagesPostsMap[username];
        _isLoadingImages = false;
        if (_imagesPosts != null) {
          _initializePostStates(_imagesPosts!);
        }
      }
      if (userProvider.cachedTotalPollsCountMap.containsKey(username)) {
        _totalPollsCount = userProvider.cachedTotalPollsCountMap[username];
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCounts();
      _fetchPosts();
    });
  }

  Future<void> _fetchCounts() async {
    if (!mounted) return;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';
      if (myUserId.isEmpty) return;

      final results = await Future.wait([
        apiService.fetchChaseList(targetUserId: myUserId, page: 1),
        apiService.fetchRechaseList(targetUserId: myUserId, page: 1),
      ]);

      if (results[0] != null && results[1] != null && mounted) {
        final chase = int.tryParse(results[0]!['count']?.toString() ?? '') ?? 0;
        final rechase =
            int.tryParse(results[1]!['count']?.toString() ?? '') ?? 0;

        userProvider.cachedChaseCount = chase;
        userProvider.cachedRechaseCount = rechase;
        userProvider.updateUserFields({
          'followers_count': chase.toString(),
          'following_count': rechase.toString(),
        });
      }
    } catch (e) {
      debugPrint('Error fetching chase/rechase counts: $e');
    }
  }

  Future<void> _handleRefresh() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUserDataSilently();
    await _fetchCounts();
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
                    (o) =>
                        o.text != null && o.text!.isNotEmpty && o.image == null,
                  ),
            );
          }).toList();
          userProvider.cachedThingsPostsMap[username] = _thingsPosts!;
          _initializePostStates(_thingsPosts!);
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
          _initializePostStates(_imagesPosts!);
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

  void _showCommentsBottomSheet(String postId, String username) async {
    BottomSheetUtils.showCommentsBottomSheet(
      context: context,
      postId: postId,
      currentUsername: username,
      onCommentsCountChanged: (newCount) {
        setState(() => postCommentsCounts[postId] = newCount);
      },
    );
  }

  void _showLikedUsersBottomSheet(String postId, String username) {
    BottomSheetUtils.showLikedUsersBottomSheet(
      context: context,
      postId: postId,
    );
  }

  void _onBattleOptionTap(
    UserPostModel post,
    UserPollQuestion poll,
    bool hasImages,
  ) {
    if (post.is_polled_by_current_user) {
      if (hasImages) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ImageResultScreen(username: post.user, postId: post.id),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ThingsResultScreen(username: post.user, postId: post.id),
          ),
        );
      }
    } else {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (hasImages) {
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
      } else {
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
    }
  }

  void _showAllImagesGrid(
    String postId,
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

  Future<void> _deletePost(String postId) async {
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
            postSharesCounts.remove(postId);
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

  Future<void> _fetchLikedUsersSilently(
    String postId, {
    bool force = false,
  }) async {
    if (!force && postLikedUsers.containsKey(postId)) return;
    try {
      final users = await ApiService().fetchLikedUsers(postId);
      if (mounted) {
        setState(() {
          postLikedUsers[postId] = users.take(3).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(String postId) async {
    final currentLikeState = postLikeStates[postId] ?? false;
    final currentLikeCount = postLikeCounts[postId] ?? 0;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId ?? '';
    final currentUsername = userProvider.username ?? '';
    final currentUserFullName =
        '${userProvider.firstName ?? ''} ${userProvider.lastName ?? ''}'.trim();
    final currentUserImage = userProvider.profile_picture;

    final previousViewLikes = List<LikeUser>.from(postLikedUsers[postId] ?? []);

    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;

      final newLikeState = !currentLikeState;
      if (newLikeState) {
        final list = List<LikeUser>.from(postLikedUsers[postId] ?? []);
        list.insert(
          0,
          LikeUser(
            id: currentUserId,
            fullName: currentUserFullName.isNotEmpty
                ? currentUserFullName
                : currentUsername,
            username: currentUsername,
            profileImage: currentUserImage,
          ),
        );
        postLikedUsers[postId] = list.take(3).toList();
      } else {
        final list = List<LikeUser>.from(postLikedUsers[postId] ?? []);
        list.removeWhere((user) => user.username == currentUsername);
        postLikedUsers[postId] = list;
      }
    });

    try {
      final result = await likeService.togglePostLike(
        context: context,
        postId: postId,
        currentLikeState: currentLikeState,
        currentLikesCount: currentLikeCount,
      );

      if (mounted) {
        if (!result.success) {
          setState(() {
            postLikeStates[postId] = currentLikeState;
            postLikeCounts[postId] = currentLikeCount;
            postLikedUsers[postId] = previousViewLikes;
          });
          showToast(message: result.message);
        } else {
          setState(() {
            postLikeStates[postId] = result.isLiked;
            postLikeCounts[postId] = result.likesCount;
          });

          if (result.likesCount > 0) {
            _fetchLikedUsersSilently(postId, force: true);
          } else {
            setState(() {
              postLikedUsers.remove(postId);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          postLikeStates[postId] = currentLikeState;
          postLikeCounts[postId] = currentLikeCount;
          postLikedUsers[postId] = previousViewLikes;
        });
        showToast(message: 'Failed to update like');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
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
          AppLocalizations.of(context)!.profile,
          style: AppTextStyles.pageTitleTextStyle(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              navigationPush(context, const SettingsScreen());
            },
            icon: Icon(FeatherIcons.settings, size: 22, color: txt.heading),
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
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.5),

                    tabs: [
                      Tab(text: AppLocalizations.of(context)!.things),
                      Tab(text: AppLocalizations.of(context)!.images),
                      Tab(text: AppLocalizations.of(context)!.saved),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: ColoredBox(
            color: Theme.of(context).colorScheme.background,
            child: TabBarView(
              controller: _tabController,
              children: [
                _isLoadingThings
                    ? Center(
                        child: Loader(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : (_thingsPosts == null || _thingsPosts!.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isDarkMode
                                ? const SizedBox()
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Image.asset(
                                      Assets.images.noThingsPost.path,
                                      height: 0.20.sh,
                                      width: 0.20.sh,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                            Text(
                              AppLocalizations.of(context)!.nothingspollyet,

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
                              AppLocalizations.of(
                                context,
                              )!.createyourfirstpollandstartgatheringopinions,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13,
                                color: txt.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 100),
                        itemCount: _thingsPosts!.length,
                        itemBuilder: (context, index) {
                          return _buildSimplePostCard(
                            _thingsPosts![index],
                            isImage: false,
                            userProvider: userProvider,
                            index: index,
                          );
                        },
                      ),
                _isLoadingImages
                    ? Center(
                        child: Loader(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : (_imagesPosts == null || _imagesPosts!.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isDarkMode
                                ? const SizedBox()
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Image.asset(
                                      Assets.images.noImagePoll.path,
                                      height: 0.20.sh,
                                      width: 0.20.sh,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                            Text(
                              AppLocalizations.of(context)!.noimagepollyet,

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
                              AppLocalizations.of(
                                context,
                              )!.createyourfirstpollandstartgatheringopinions,

                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13,
                                color: txt.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 100),
                        itemCount: _imagesPosts!.length,
                        itemBuilder: (context, index) {
                          return _buildSimplePostCard(
                            _imagesPosts![index],
                            isImage: true,
                            userProvider: userProvider,
                            index: index,
                          );
                        },
                      ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isDarkMode
                          ? const SizedBox()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Image.asset(
                                Assets.images.noSavedPost.path,
                                height: 0.20.sh,
                                width: 0.20.sh,
                                fit: BoxFit.contain,
                              ),
                            ),

                      Text(
                        AppLocalizations.of(context)!.nothingsavedyet,

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
                        AppLocalizations.of(
                          context,
                        )!.savedpollsyouwanttorevisitlater,

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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double topPadding, UserProvider userProvider) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              final originalImageSource =
                  userProvider.profile_picture_path ??
                  userProvider.profile_picture;
              if (originalImageSource == null || originalImageSource.isEmpty) {
                return;
              }
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.transparent,
                  transitionDuration: const Duration(milliseconds: 150),
                  reverseTransitionDuration: const Duration(milliseconds: 150),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return ProfileImagePreview(
                      imageSource: originalImageSource,
                      username: userProvider.username,
                    );
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: (() {
                      final profilePic = userProvider.profile_picture;
                      if (profilePic != null && profilePic.isNotEmpty) {
                        final cachedImage = _getCachedProfileImage(
                          profilePic,
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
                        } else if (profilePic.startsWith('http') ||
                            profilePic.startsWith('/') ||
                            profilePic.contains('/')) {
                          final imageUrl = profilePic.startsWith('http')
                              ? profilePic
                              : (profilePic.startsWith('/')
                                    ? '${ApiConfig.baseUrlImage}$profilePic'
                                    : '${ApiConfig.baseUrlImage}/$profilePic');
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _AvatarPlaceholder(
                              username: userProvider.username,
                              fontSize: 35,
                            ),
                          );
                        }
                      }
                      return _AvatarPlaceholder(
                        username: userProvider.username,
                        fontSize: 35,
                      );
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
              fontSize: 13.7,
            ),
          ),
          if (userProvider.bio != null && userProvider.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpandableBio(bio: userProvider.bio!),
          ],
          const SizedBox(height: 20),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatCard(
                  value: userProvider.following_count ?? '0',
                  label: AppLocalizations.of(context)!.revibe,
                  onTap: () =>
                      navigationPush(
                        context,
                        UserChase(
                          username: userProvider.username ?? '-',
                          followingCount: userProvider.following_count ?? '0',
                          followerCount: userProvider.followers_count ?? '0',
                          initialIndex: 1,
                        ),
                      ).then((_) {
                        _fetchCounts();
                      }),
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: userProvider.followers_count ?? '0',
                  label: AppLocalizations.of(context)!.vibe,
                  onTap: () =>
                      navigationPush(
                        context,
                        UserChase(
                          username: userProvider.username ?? '-',
                          followingCount: userProvider.following_count ?? '0',
                          followerCount: userProvider.followers_count ?? '0',
                          initialIndex: 0,
                        ),
                      ).then((_) {
                        _fetchCounts();
                      }),
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: userProvider.isLoading || _totalPollsCount == null
                      ? '0'
                      : _totalPollsCount.toString(),
                  label: AppLocalizations.of(context)!.polls,
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
                        navigationPush(context, const EditProfile());
                      },
                      icon: const Icon(
                        FeatherIcons.edit2,
                        // Icons.edit_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        AppLocalizations.of(context)!.editprofile,
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
                    onPressed: () {
                      final username = userProvider.username;
                      if (username != null && username.isNotEmpty) {
                        ShareService.shareProfile(
                          username: username,
                          context: context,
                        );
                      }
                    },
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
                      AppLocalizations.of(context)!.shareprofile,
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 14.5,
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // const SizedBox(width: 8),
                // const Icon(
                //   FeatherIcons.moreVertical,
                //   size: 25,
                //   color: Color(0XFF727272),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
          fontSize: 13.5,
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

  Widget _buildSimplePostCard(
    UserPostModel post, {
    required bool isImage,
    required UserProvider userProvider,
    int index = 0,
  }) {
    final txt = AppTextColors.of(context);
    if (post.polls.isEmpty) return const SizedBox.shrink();
    final poll = post.polls.first;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final double pct1 = (poll.options != null && poll.options!.isNotEmpty)
        ? poll.options![0].percentage
        : 0.0;
    final double pct2 = (poll.options != null && poll.options!.length > 1)
        ? poll.options![1].percentage
        : 0.0;

    final firstImage = (poll.options == null || poll.options!.isEmpty)
        ? null
        : (poll.options!
              .firstWhere(
                (o) => o.image != null,
                orElse: () => poll.options![0],
              )
              .image);

    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = postCommentsCounts[post.id] ?? post.commentsCount;
    final sharesCount = postSharesCounts[post.id] ?? post.sharesCount;
    final viewLikes = postLikedUsers[post.id] ?? [];
    final currentUsername = userProvider.username ?? '';

    return ProfilePostCardAnimation(
      index: index,
      child: Container(
        margin: EdgeInsets.only(bottom: 20.h),
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
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: (() {
                        final profilePic = userProvider.profile_picture;
                        if (profilePic != null && profilePic.isNotEmpty) {
                          final cachedImage = _getCachedProfileImage(
                            profilePic,
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
                          } else if (profilePic.startsWith('http') ||
                              profilePic.startsWith('/') ||
                              profilePic.contains('/')) {
                            final imageUrl = profilePic.startsWith('http')
                                ? profilePic
                                : (profilePic.startsWith('/')
                                      ? '${ApiConfig.baseUrlImage}$profilePic'
                                      : '${ApiConfig.baseUrlImage}/$profilePic');
                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _AvatarPlaceholder(
                                username: userProvider.username,
                                fontSize: 18,
                              ),
                            );
                          }
                        }
                        return _AvatarPlaceholder(
                          username: userProvider.username,
                          fontSize: 18,
                        );
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
                          color: txt.title,
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
                              color: txt.body,
                            ),
                          ),
                          Text(
                            '  • ${_timeAgo(post.createdAt)}',
                            style: AppTextStyles.subText.copyWith(
                              color: txt.muted,
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
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (poll.pollType == 'hot_take') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            poll.question,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: txt.title,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
                          style: AppTextStyles.subText.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (post.description.isNotEmpty) ...[
                      SizedBox(height: 5.h),
                      _buildDescriptionWithHashtags(
                        context,
                        post.description,
                        txt,
                      ),
                    ],
                    if (firstImage != null) ...[
                      SizedBox(height: 12.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        child: CachedNetworkImage(
                          imageUrl: firstImage.resolvedUrl(
                            ApiConfig.baseUrlImage,
                          ),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 150.h,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context).colorScheme.background,
                            height: 150.h,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).colorScheme.background,
                            height: 150.h,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () {
                        if (post.is_polled_by_current_user) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ThingsResultScreen(
                                username: post.user,
                                postId: post.id,
                              ),
                            ),
                          );
                        }
                      },
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!post.is_polled_by_current_user) {
                                    final optionId =
                                        (poll.options != null &&
                                            poll.options!.isNotEmpty)
                                        ? poll.options![0].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(
                                        poll,
                                        optionId,
                                        post,
                                      );
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
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    child: Stack(
                                      children: [
                                        if (post.is_polled_by_current_user)
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
                                                  post.is_polled_by_current_user
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
                                                  style: AppTextStyles
                                                      .sectionHeading
                                                      .copyWith(
                                                        color: isDarkMode
                                                            ? const Color(
                                                                0xFF10B981,
                                                              )
                                                            : const Color(
                                                                0xFF059669,
                                                              ),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                ),
                                                if (post
                                                    .is_polled_by_current_user) ...[
                                                  const Spacer(),
                                                  Text(
                                                    '${pct1.round()}%',
                                                    style: AppTextStyles
                                                        .sectionHeading
                                                        .copyWith(
                                                          color: isDarkMode
                                                              ? const Color(
                                                                  0xFF10B981,
                                                                )
                                                              : const Color(
                                                                  0xFF059669,
                                                                ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!post.is_polled_by_current_user) {
                                    final optionId =
                                        (poll.options != null &&
                                            poll.options!.length > 1)
                                        ? poll.options![1].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(
                                        poll,
                                        optionId,
                                        post,
                                      );
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
                                          ? const Color(
                                              0xFFCB5B5B,
                                            ).withOpacity(0.5)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    child: Stack(
                                      children: [
                                        if (post.is_polled_by_current_user)
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
                                                  post.is_polled_by_current_user
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
                                                  style: AppTextStyles
                                                      .sectionHeading
                                                      .copyWith(
                                                        color: isDarkMode
                                                            ? const Color(
                                                                0xFFE53E3E,
                                                              )
                                                            : const Color(
                                                                0xFFC81E1E,
                                                              ),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                ),
                                                if (post
                                                    .is_polled_by_current_user) ...[
                                                  const Spacer(),
                                                  Text(
                                                    '${pct2.round()}%',
                                                    style: AppTextStyles
                                                        .sectionHeading
                                                        .copyWith(
                                                          color: isDarkMode
                                                              ? const Color(
                                                                  0xFFE53E3E,
                                                                )
                                                              : const Color(
                                                                  0xFFC81E1E,
                                                                ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
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
                    ),
                  ] else if (poll.pollType == 'battle') ...[
                    _buildBattlePollSection(context, poll, post),
                  ] else if (poll.pollType == 'this_or_that') ...[
                    _buildThisOrThatPollSection(context, poll, post),
                  ] else if (poll.pollType == 'anonymous' &&
                      _hasImageOptions(poll) &&
                      _hasTextOptions(poll)) ...[
                    _buildAnonymousImageTextPollSection(context, poll, post),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            poll.question,
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.heading,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        Text(
                          '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
                          style: AppTextStyles.subText.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
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
                  ],
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleLike(post.id),
                        child: isLiked
                            ? AppIcons.filledHeart(
                                key: const ValueKey('filled'),
                              )
                            : AppIcons.outlineHeart(
                                key: const ValueKey('outline'),
                              ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showLikedUsersBottomSheet(
                          post.id,
                          currentUsername,
                        ),
                        child: Text(
                          likesCount > 0 ? '$likesCount' : '',
                          style: AppTextStyles.subText.copyWith(
                            color: txt.body,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () =>
                            _showCommentsBottomSheet(post.id, currentUsername),
                        child: AppIcons.commnetBox(),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            _showCommentsBottomSheet(post.id, currentUsername),
                        child: Text(
                          commentsCount > 0 ? '$commentsCount' : '',
                          style: AppTextStyles.subText.copyWith(
                            color: txt.body,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () {
                          ShareService.sharePost(
                            post,
                            context: context,
                            usernameOverride: currentUsername,
                            onShareSuccess: (newCount) {
                              if (mounted) {
                                setState(() {
                                  postSharesCounts[post.id] = newCount;
                                });
                              }
                            },
                          );
                        },
                        child: Row(
                          children: [
                            AppIcons.sharePost(),
                            const SizedBox(width: 8),
                            Text(
                              sharesCount > 0 ? '$sharesCount' : '',
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
                  if (likesCount > 0 && viewLikes.isNotEmpty) ...[
                    SizedBox(height: 5.h),
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
      ),
    );
  }

  Widget _buildTextOptions(UserPollQuestion poll, VoidCallback onTap) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Row(
                            children: [
                              if (option.percentage.toInt() != 0)
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
                            height: 7.h,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2D2D2D)
                                  : const Color(0xFFF6F3F2),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double imageHeight = 165.h;

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
                            color: Theme.of(context).colorScheme.background,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: imageData.resolvedUrl(
                                ApiConfig.baseUrlImage,
                              ),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.background,
                                ),
                                child: Center(
                                  child: Loader(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  color: isDarkMode
                                      ? const Color.fromARGB(104, 46, 46, 46)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.background,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.4),
                                    size: 30,
                                  ),
                                ),
                              ),
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

  Widget _buildThisOrThatPollSection(
    BuildContext context,
    UserPollQuestion poll,
    UserPostModel post,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = (poll.options != null && poll.options!.isNotEmpty)
        ? poll.options![0].text ?? ''
        : '';
    final option2 = (poll.options != null && poll.options!.length > 1)
        ? poll.options![1].text ?? ''
        : '';

    final double pct1 = (poll.options != null && poll.options!.isNotEmpty)
        ? poll.options![0].percentage
        : 0.0;
    final double pct2 = (poll.options != null && poll.options!.length > 1)
        ? poll.options![1].percentage
        : 0.0;

    final hasImages = _hasImageOptions(poll);

    return GestureDetector(
      onTap: () {
        if (post.is_polled_by_current_user) {
          if (hasImages) {
            navigationPush(
              context,
              ImageResultScreen(username: post.user, postId: post.id),
            );
          } else {
            navigationPush(
              context,
              ThingsResultScreen(username: post.user, postId: post.id),
            );
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (poll.question.isNotEmpty) ...[
            SizedBox(height: 5.h),
            _buildQuestionRow(context, poll, txt),
          ],
          if (post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _buildDescriptionWithHashtags(
                context,
                post.description,
                txt,
              ),
            ),
          if (poll.question.isNotEmpty || post.description.isNotEmpty)
            const SizedBox(height: 12),
          if (hasImages) ...[
            GestureDetector(
              onTap: post.is_polled_by_current_user ? null : () {},
              child: SizedBox(
                height: 165.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: post.is_polled_by_current_user
                                ? null
                                : () {
                                    final optionId =
                                        (poll.options != null &&
                                            poll.options!.isNotEmpty)
                                        ? poll.options![0].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(
                                        poll,
                                        optionId,
                                        post,
                                      );
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (poll.options != null &&
                                        poll.options!.isNotEmpty &&
                                        poll.options![0].image != null)
                                      AppCachedNetworkImage(
                                        imageUrl: poll.options![0].image!
                                            .resolvedUrl(
                                              ApiConfig.baseUrlImage,
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
                                    if (post.is_polled_by_current_user)
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
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            Text(
                                              '${pct1.round()}%',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bodyText
                                                  .copyWith(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
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
                            onTap: post.is_polled_by_current_user
                                ? null
                                : () {
                                    final optionId =
                                        (poll.options != null &&
                                            poll.options!.length > 1)
                                        ? poll.options![1].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(
                                        poll,
                                        optionId,
                                        post,
                                      );
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (poll.options != null &&
                                        poll.options!.length > 1 &&
                                        poll.options![1].image != null)
                                      AppCachedNetworkImage(
                                        imageUrl: poll.options![1].image!
                                            .resolvedUrl(
                                              ApiConfig.baseUrlImage,
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
                                    if (post.is_polled_by_current_user)
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
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            Text(
                                              '${pct2.round()}%',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bodyText
                                                  .copyWith(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
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
            ),
            const SizedBox(height: 10),
          ] else ...[
            SizedBox(
              height: post.is_polled_by_current_user ? 70 : 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: post.is_polled_by_current_user
                              ? null
                              : () {
                                  final optionId =
                                      (poll.options != null &&
                                          poll.options!.isNotEmpty)
                                      ? poll.options![0].id
                                      : null;
                                  if (optionId != null) {
                                    _submitSinglePollVote(poll, optionId, post);
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
                                  style: AppTextStyles.sectionHeading.copyWith(
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (post.is_polled_by_current_user) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pct1.round()}%',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF4B5563),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(
                                        begin: 0,
                                        end: (pct1 / 100.0).clamp(0.0, 1.0),
                                      ),
                                      builder: (_, value, __) => ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: value,
                                          minHeight: 6,
                                          backgroundColor: isDarkMode
                                              ? const Color(0xFF2D2D2D)
                                              : const Color(0xFFF6F3F2),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      ),
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
                          onTap: post.is_polled_by_current_user
                              ? null
                              : () {
                                  final optionId =
                                      (poll.options != null &&
                                          poll.options!.length > 1)
                                      ? poll.options![1].id
                                      : null;
                                  if (optionId != null) {
                                    _submitSinglePollVote(poll, optionId, post);
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
                                  style: AppTextStyles.sectionHeading.copyWith(
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (post.is_polled_by_current_user) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pct2.round()}%',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF4B5563),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(
                                        begin: 0,
                                        end: (pct2 / 100.0).clamp(0.0, 1.0),
                                      ),
                                      builder: (_, value, __) => ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: value,
                                          minHeight: 6,
                                          backgroundColor: isDarkMode
                                              ? const Color(0xFF2D2D2D)
                                              : const Color(0xFFF6F3F2),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      ),
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
                  Positioned(
                    top: (post.is_polled_by_current_user ? 35 : 25) - 16.h,
                    left: 0,
                    right: 0,
                    child: Center(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _submitSinglePollVote(
    UserPollQuestion poll,
    int optionId,
    UserPostModel post,
  ) async {
    try {
      final List<Map<String, int>> votes = [
        {'option_id': optionId, 'rank': 1},
      ];

      final result = await ApiService.voteOnPollSingle(
        postId: post.id,
        votes: votes,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            post.is_polled_by_current_user = true;

            final responseOptions = result['data']?['options'];
            if (responseOptions is List && responseOptions.isNotEmpty) {
              for (final optionData in responseOptions) {
                if (optionData is! Map) continue;
                final rawId = optionData['option_id'];
                if (rawId == null) continue;
                final optId = rawId is int ? rawId : (rawId as num).toInt();
                final pct =
                    (optionData['percentage'] as num?)?.toDouble() ?? 0.0;

                if (poll.options != null) {
                  for (var option in poll.options!) {
                    if (option.id == optId) {
                      option.percentage = pct;
                    }
                  }
                }
              }
            }
          });
        }

        showToast(message: 'Vote submitted successfully!');
        _fetchPosts();
      } else {
        showToast(message: 'Failed to submit vote. Please try again.');
      }
    } catch (e) {
      debugPrint('Error voting: $e');
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  bool _hasImageOptions(UserPollQuestion poll) =>
      poll.options != null && poll.options!.any((o) => o.image != null);

  bool _hasTextOptions(UserPollQuestion poll) =>
      poll.options != null &&
      poll.options!.any((o) => o.text != null && o.text!.isNotEmpty);

  Widget _buildAnonymousImageTextPollSection(
    BuildContext context,
    UserPollQuestion poll,
    UserPostModel post,
  ) {
    final txt = AppTextColors.of(context);
    final validOptions = poll.options!
        .where((o) => o.image != null && o.text != null && o.text!.isNotEmpty)
        .toList();

    if (validOptions.isEmpty) return const SizedBox.shrink();

    final hasUserPolled = post.is_polled_by_current_user;

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
          const SizedBox(height: 12),
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
      onTap: () => _showAllImagesGrid(
        post.id,
        poll,
        post.is_polled_by_current_user,
        post,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (poll.question.isNotEmpty) ...[
            SizedBox(height: 5.h),
            _buildQuestionRow(context, poll, txt),
          ],
          if (post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _buildDescriptionWithHashtags(
                context,
                post.description,
                txt,
              ),
            ),
          if (poll.question.isNotEmpty || post.description.isNotEmpty)
            SizedBox(height: 12.h),
          optionsWidget,
          SizedBox(height: 5.h),
        ],
      ),
    );
  }

  Widget _buildAnonymousOptionCard(
    BuildContext context,
    UserPollOption option,
    int index,
    bool hasUserPolled,
  ) {
    Widget imageWidget = const SizedBox.shrink();
    if (option.image != null) {
      imageWidget = AppCachedNetworkImage(
        imageUrl: option.image!.resolvedUrl(ApiConfig.baseUrlImage),
        fit: BoxFit.cover,
      );
    }

    return SizedBox(
      height: 165.h,
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

  Widget _buildBattlePollSection(
    BuildContext context,
    UserPollQuestion poll,
    UserPostModel post,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = (poll.options != null && poll.options!.isNotEmpty)
        ? poll.options![0].text ?? ''
        : '';
    final option2 = (poll.options != null && poll.options!.length > 1)
        ? poll.options![1].text ?? ''
        : '';

    final double pct1 = (poll.options != null && poll.options!.isNotEmpty)
        ? poll.options![0].percentage
        : 0.0;
    final double pct2 = (poll.options != null && poll.options!.length > 1)
        ? poll.options![1].percentage
        : 0.0;

    final hasImages = _hasImageOptions(poll);

    return GestureDetector(
      onTap: () {
        if (post.is_polled_by_current_user) {
          if (hasImages) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ImageResultScreen(username: post.user, postId: post.id),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ThingsResultScreen(username: post.user, postId: post.id),
              ),
            );
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (poll.question.isNotEmpty) ...[
            SizedBox(height: 5.h),
            _buildQuestionRow(context, poll, txt),
          ],
          if (post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _buildDescriptionWithHashtags(
                context,
                post.description,
                txt,
              ),
            ),
          if (poll.question.isNotEmpty || post.description.isNotEmpty)
            const SizedBox(height: 12),
          if (hasImages) ...[
            GestureDetector(
              onTap: post.is_polled_by_current_user ? null : () {},
              child: SizedBox(
                height: 165.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: post.is_polled_by_current_user
                                ? null
                                : () {
                                    final optionId =
                                        (poll.options != null &&
                                            poll.options!.isNotEmpty)
                                        ? poll.options![0].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(
                                        poll,
                                        optionId,
                                        post,
                                      );
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (poll.options != null &&
                                        poll.options!.isNotEmpty &&
                                        poll.options![0].image != null)
                                      AppCachedNetworkImage(
                                        imageUrl: poll.options![0].image!
                                            .resolvedUrl(
                                              ApiConfig.baseUrlImage,
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
                                    if (post.is_polled_by_current_user)
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
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            Text(
                                              '${pct1.round()}%',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bodyText
                                                  .copyWith(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
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
                            onTap: post.is_polled_by_current_user
                                ? null
                                : () {
                                    final optionId =
                                        (poll.options != null &&
                                            poll.options!.length > 1)
                                        ? poll.options![1].id
                                        : null;
                                    if (optionId != null) {
                                      _submitSinglePollVote(
                                        poll,
                                        optionId,
                                        post,
                                      );
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.10),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (poll.options != null &&
                                        poll.options!.length > 1 &&
                                        poll.options![1].image != null)
                                      AppCachedNetworkImage(
                                        imageUrl: poll.options![1].image!
                                            .resolvedUrl(
                                              ApiConfig.baseUrlImage,
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
                                    if (post.is_polled_by_current_user)
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
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            Text(
                                              '${pct2.round()}%',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bodyText
                                                  .copyWith(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
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
              height: post.is_polled_by_current_user ? 70 : 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (post.is_polled_by_current_user) {
                              _onBattleOptionTap(post, poll, false);
                            } else {
                              final optionId =
                                  (poll.options != null &&
                                      poll.options!.isNotEmpty)
                                  ? poll.options![0].id
                                  : null;
                              if (optionId != null) {
                                _submitSinglePollVote(poll, optionId, post);
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
                                if (post.is_polled_by_current_user) ...[
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
                                  style: AppTextStyles.sectionHeading.copyWith(
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (post.is_polled_by_current_user) {
                              _onBattleOptionTap(post, poll, false);
                            } else {
                              final optionId =
                                  (poll.options != null &&
                                      poll.options!.length > 1)
                                  ? poll.options![1].id
                                  : null;
                              if (optionId != null) {
                                _submitSinglePollVote(poll, optionId, post);
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
                                if (post.is_polled_by_current_user) ...[
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
                                  style: AppTextStyles.sectionHeading.copyWith(
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
        ],
      ),
    );
  }

  Widget _buildQuestionRow(
    BuildContext context,
    UserPollQuestion poll,
    AppTextColors txt, {
    VoidCallback? onVotesTap,
  }) {
    final votes = int.tryParse(poll.totalVotes) ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            poll.question,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.heading,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (votes > 0) ...[
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onVotesTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
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
      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.09),
      child: Center(
        child: Text(
          firstLetter,
          style: AppTextStyles.bodyText.copyWith(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
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
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark
          ? Theme.of(context).colorScheme.background
          : Theme.of(context).colorScheme.background,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}

class ProfilePostCardAnimation extends StatefulWidget {
  final Widget child;
  final int index;

  const ProfilePostCardAnimation({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<ProfilePostCardAnimation> createState() =>
      _ProfilePostCardAnimationState();
}

class _ProfilePostCardAnimationState extends State<ProfilePostCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    final int delayMs = widget.index < 4 ? (widget.index * 80) : 0;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
