// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../widgets/show_toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../../provider/user_provider.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../provider/private_chat_provider.dart';
import '../../../../provider/public_profile_provider.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/shimmer/profile_simmer.dart';
import '../../../../widgets/tabbar/indicatore_animation.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../home feed/rank/result/image/image_result_screen.dart';
import '../../home feed/rank/result/things/things_result_screen.dart';
import '../../message/chat/private/private_chat_screen.dart';
import '../rank/image/public_user_image_ranking.dart';
import '../rank/things/public_user_things_ranking.dart';
import 'chase/public_chase_list.dart';

import '../../../../api/services/api_service.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../api/api_config.dart';
import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../core/utils/like_util.dart';
import '../../../../api/services/share/share_service.dart';

enum FollowStatus { none, rechase, chase, both, pending }

class PublicProfileScreen extends StatelessWidget {
  final String? userId;
  final String? username;
  const PublicProfileScreen({super.key, this.userId, this.username});

  @override
  Widget build(BuildContext context) {
    debugPrint('Public Id : $userId, Username: $username');
    return ChangeNotifierProvider(
      create: (_) => PublicProfileProvider(),
      child: _PublicProfileScreenBody(userId: userId, username: username),
    );
  }
}

class _PublicProfileScreenBody extends StatefulWidget {
  final String? userId;
  final String? username;
  const _PublicProfileScreenBody({this.userId, this.username});

  @override
  State<_PublicProfileScreenBody> createState() =>
      _PublicProfileScreenBodyState();
}

class _PublicProfileScreenBodyState extends State<_PublicProfileScreenBody>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final ApiService apiService = ApiService();
  String? resolvedUserId;
  Future<String?>? _authTokenFuture;
  bool isLoadingPosts = true;
  List<PublicPost> cachedThingsPosts = [];
  List<PublicPost> cachedImagesPosts = [];

  Map<String, bool> postLikeStates = {};
  Map<String, int> postLikeCounts = {};

  final LikeService likeService = LikeService();
  Map<String, List<LikeUser>> postLikedUsers = {};
  Map<String, bool> likedUsersLoading = {};
  Map<String, int> postCommentsCounts = {};
  Map<String, int> postSharesCounts = {};

  FollowStatus? _localFollowStatus;
  FollowStatus? _serverFollowStatus;
  bool _isProcessingRequest = false;

  late TabController _tabController;

  FollowStatus _getEffectiveFollowStatus(
    String? profileFollowStatus,
    bool hasProfile,
  ) {
    final parsed = _parseFollowStatus(profileFollowStatus);
    if (_serverFollowStatus == null && hasProfile) {
      _serverFollowStatus = parsed;
    }
    if (_localFollowStatus != null) {
      return _localFollowStatus!;
    }
    return parsed;
  }

  FollowStatus _parseFollowStatus(String? status) {
    if (status == null || status.isEmpty) return FollowStatus.none;
    switch (status.toLowerCase()) {
      case 'following':
      case 'rechase':
        return FollowStatus.rechase;
      case 'follower':
      case 'followers':
      case 'chase':
        return FollowStatus.chase;
      case 'both':
      case 'friends':
        return FollowStatus.both;
      case 'pending':
      case 'requested':
        return FollowStatus.pending;
      default:
        return FollowStatus.none;
    }
  }

  Map<String, dynamic> _getButtonState(FollowStatus status) {
    switch (status) {
      case FollowStatus.none:
        return {
          'text': 'Chase',
          'icon': null,
          'canTap': !_isProcessingRequest,
          'isFollowing': false,
        };
      case FollowStatus.chase:
        return {
          'text': 'Chase Back',
          'icon': null,
          'canTap': !_isProcessingRequest,
          'isFollowing': false,
        };
      case FollowStatus.rechase:
      case FollowStatus.both:
        return {
          'text': 'Chasing',
          'icon': null,
          'canTap': !_isProcessingRequest,
          'isFollowing': true,
        };
      case FollowStatus.pending:
        return {
          'text': 'Requested',
          'canTap': !_isProcessingRequest,
          'isFollowing': true,
        };
    }
  }

  Future<void> _handleFollowAction(
    String username,
    bool isFollowing,
    bool isPrivate,
  ) async {
    if (_isProcessingRequest) return;

    final provider = Provider.of<PublicProfileProvider>(context, listen: false);
    final profileFollowStatus = provider.userProfile?.followStatus;

    // The true server status is either our cached one, or the freshly parsed one if we haven't cached it.
    final originalServerStatus =
        _serverFollowStatus ?? _parseFollowStatus(profileFollowStatus);

    final currentStatus = _localFollowStatus ?? originalServerStatus;

    setState(() => _isProcessingRequest = true);

    try {
      // ── Cancel pending request ──────────────────────────────────────
      if (currentStatus == FollowStatus.pending) {
        final revertTo = originalServerStatus;

        setState(() {
          _localFollowStatus = revertTo;
          _isProcessingRequest = false;
        });

        final success = await apiService.cancelFriendRequest(resolvedUserId ?? widget.userId);

        if (!success) {
          setState(() => _localFollowStatus = FollowStatus.pending);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to cancel request. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        // _serverFollowStatus stays as-is
      }
      // ── Unfollow (rechase / both) ───────────────────────────────────
      else if (isFollowing) {
        // If we were 'both' or they were following us ('chase'), unfollowing means they still follow us -> 'chase'
        final nextStatus =
            (currentStatus == FollowStatus.both ||
                originalServerStatus == FollowStatus.both ||
                originalServerStatus == FollowStatus.chase)
            ? FollowStatus.chase
            : FollowStatus.none;

        setState(() {
          _localFollowStatus = nextStatus;
          _isProcessingRequest = false;
        });

        final response = await apiService.unfriend(resolvedUserId ?? widget.userId);

        if (response['status'] == 'success') {
          // Confirmed by server → now safe to update server status
          _serverFollowStatus = nextStatus;
        } else {
          setState(() => _localFollowStatus = originalServerStatus);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to unfollow. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
      // ── Send request ────────────────────────────────────────────────
      else {
        final nextStatus = isPrivate
            ? FollowStatus.pending
            : (currentStatus == FollowStatus.chase
                  ? FollowStatus.both
                  : FollowStatus.rechase);

        setState(() {
          _localFollowStatus = nextStatus;
          _isProcessingRequest = false;
        });

        final bool requestResult = await apiService.sendFriendRequest(username);

        if (requestResult) {
          if (!isPrivate) {
            _serverFollowStatus = nextStatus;
          }
        } else {
          setState(() => _localFollowStatus = originalServerStatus);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send request. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _localFollowStatus = originalServerStatus;
        _isProcessingRequest = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authTokenFuture = SharedPrefService.getToken();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PublicProfileProvider>();
      if (widget.userId != null) {
        resolvedUserId = widget.userId;
        provider.fetchPublicUserProfile(widget.userId!);
        _loadData();
      } else if (widget.username != null) {
        await provider.fetchPublicUserProfileByUsername(widget.username!);
        if (provider.userProfile != null) {
          resolvedUserId = provider.userProfile!.id;
          _loadData();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAllImagesGrid(
    String postId,
    PublicPoll poll,
    bool isPolledByCurrentUser,
    PublicPost post,
  ) {
    if (isPolledByCurrentUser) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageResultScreen(
            username: post.user,
            postId: post.id,
          ),
        ),
      );
    } else {
      final userProvider = Provider.of<PublicProfileProvider>(
        context,
        listen: false,
      );
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => PublicUserImageRanking(
                post: post,
                poll: poll,
                firstName: userProvider.userProfile?.firstName ?? '',
                lastName: userProvider.userProfile?.lastName ?? '',
                profileImage: userProvider.userProfile?.profilePictureUrl,
              ),
            ),
          )
          .then((result) {
            if (result == true) {
              setState(() {});
              _loadData();
            }
          });
    }
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

  Future<void> _fetchLikedUsersSilently(String postId, {bool force = false}) async {
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
    final currentUserFullName = '${userProvider.firstName ?? ''} ${userProvider.lastName ?? ''}'.trim();
    final currentUserImage = userProvider.profile_picture;

    setState(() {
      postLikeStates[postId] = !currentLikeState;
      postLikeCounts[postId] = currentLikeState
          ? currentLikeCount - 1
          : currentLikeCount + 1;

      if (!currentLikeState) {
        final list = List<LikeUser>.from(postLikedUsers[postId] ?? []);
        list.insert(
          0,
          LikeUser(
            id: currentUserId,
            fullName: currentUserFullName.isNotEmpty ? currentUserFullName : currentUsername,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          postLikeStates[postId] = currentLikeState;
          postLikeCounts[postId] = currentLikeCount;
        });
      }
    }
  }

  bool _isLoading(PublicProfileProvider provider) => provider.isLoading;

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;
    final publicProfileProvider = Provider.of<PublicProfileProvider>(context);

    final profile = publicProfileProvider.userProfile;
    final effectiveStatus = _getEffectiveFollowStatus(
      profile?.followStatus,
      profile != null,
    );
    final isFriend =
        effectiveStatus == FollowStatus.rechase ||
        effectiveStatus == FollowStatus.both;
    final canViewPosts = profile != null
        ? (!profile.isPrivate || isFriend)
        : true;

    if (_isLoading(publicProfileProvider)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.background,
          toolbarHeight: 35.h,
          elevation: 0,
          automaticallyImplyLeading: true,
          leading: const PrimaryBackButton(),
        ),
        body: const ProfileShimmer(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 35.h,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: const PrimaryBackButton(),
        // title: Text(
        //   'Profile',
        //   style: AppTextStyles.pageTitleTextStyle(context),
        // ),
        actions:  [
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                FeatherIcons.moreVertical,
                size: 22,
                color: Colors.black,
              ),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              offset: const Offset(0, 45),
              elevation: 2,
              padding: EdgeInsets.zero,
              onSelected: (String result) {
                if (profile == null) return;
                if (result == 'Share Profile') {
                  ShareService.shareProfile(
                    username: profile.username,
                    context: context,
                  );
                } else if (result == 'Copy Profile Link') {
                  final link = 'https://www.polzet.com/profile/${profile.username}';
                  Clipboard.setData(ClipboardData(text: link)).then((_) {
                    showToast(message: 'Link copied');
                  });
                }
              },
              itemBuilder: (BuildContext context) {
                PopupMenuItem<String> buildItem(String text) {
                  return PopupMenuItem<String>(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                    value: text,
                    height: 45,
                    child: Text(
                      text,
                      style: AppTextStyles.bodyText.copyWith(
                        color: const  Color(0XFF595959),
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5

                      )
                    ),
                  );
                }

                return <PopupMenuEntry<String>>[
                  buildItem('Share Profile'),
                  buildItem('Copy Profile Link'),
                ];
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Theme.of(context).colorScheme.onPrimary,
        child: NestedScrollView(
          physics: canViewPosts
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildHeader(top, publicProfileProvider),
              ),
              if (canViewPosts)
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
                      ],
                    ),
                  ),
                ),
            ];
          },
          body: canViewPosts
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    isLoadingPosts
                        ? Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : cachedThingsPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                isDarkMode
                                    ? const SizedBox()
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
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
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                            itemCount: cachedThingsPosts.length,
                            itemBuilder: (context, index) {
                              return _buildSimplePostCard(
                                cachedThingsPosts[index],
                                isImage: false,
                                userProvider: publicProfileProvider,
                              );
                            },
                          ),
                    isLoadingPosts
                        ? Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : cachedImagesPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                isDarkMode
                                    ? const SizedBox()
                                    : Image.asset(
                                        Assets.images.noImagePoll.path,
                                        height: 0.20.sh,
                                        width: 0.20.sh,
                                        fit: BoxFit.contain,
                                      ),
                                const SizedBox(height: 5),
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
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                            itemCount: cachedImagesPosts.length,
                            itemBuilder: (context, index) {
                              return _buildSimplePostCard(
                                cachedImagesPosts[index],
                                isImage: true,
                                userProvider: publicProfileProvider,
                              );
                            },
                          ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FeatherIcons.lock, size: 40.sp, color: txt.muted),
                      SizedBox(height: 10.h),
                      Text(
                        AppLocalizations.of(context)!.thisaccountisprivate,
                        style: AppTextStyles.sectionHeading.copyWith(
                          fontSize: 18.5,
                          color: txt.title,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.chasethisaccounttoseetheirposts,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13,
                          color: txt.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    _serverFollowStatus = null;
    _localFollowStatus = null;
    final publicProfileProvider = Provider.of<PublicProfileProvider>(
      context,
      listen: false,
    );
    
    if (widget.userId != null) {
      resolvedUserId = widget.userId;
      await publicProfileProvider.fetchPublicUserProfile(
        widget.userId!,
        isRefresh: true,
      );
    } else if (widget.username != null) {
      await publicProfileProvider.fetchPublicUserProfileByUsername(
        widget.username!,
        isRefresh: true,
      );
      if (publicProfileProvider.userProfile != null) {
        resolvedUserId = publicProfileProvider.userProfile!.id;
      }
    }
    
    await _loadData(isRefresh: true);
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    final targetUserId = resolvedUserId ?? widget.userId;
    if (targetUserId == null) return;

    if (!isRefresh) {
      setState(() {
        isLoadingPosts = true;
      });
    }

    await Future.wait([
      apiService
          .fetchPostsWithImages(targetUserId)
          .then((posts) {
            if (mounted) {
              setState(() {
                cachedImagesPosts = posts;
              });
              for (var post in posts) {
                postLikeStates[post.id] = post.isLiked;
                postLikeCounts[post.id] = post.likesCount;
                postCommentsCounts[post.id] = post.comments.length;
                postSharesCounts[post.id] = post.sharesCount;
                if (post.likesCount > 0) _fetchLikedUsersSilently(post.id);
              }
            }
          })
          .catchError((_) {}),
      apiService
          .fetchPublicPostsPolls(targetUserId)
          .then((posts) {
            if (mounted) {
              setState(() {
                cachedThingsPosts = posts;
              });
              for (var post in cachedThingsPosts) {
                postLikeStates[post.id] = post.isLiked;
                postLikeCounts[post.id] = post.likesCount;
                postCommentsCounts[post.id] = post.comments.length;
                postSharesCounts[post.id] = post.sharesCount;
                if (post.likesCount > 0) _fetchLikedUsersSilently(post.id);
              }
            }
          })
          .catchError((_) {}),
    ]).whenComplete(() {
      if (mounted) {
        setState(() {
          isLoadingPosts = false;
        });
      }
    });
  }

  String _timeAgo(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      Duration diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return '';
    }
  }

  Widget _buildSimplePostCard(
    PublicPost post, {
    required bool isImage,
    required PublicProfileProvider userProvider,
  }) {
    final txt = AppTextColors.of(context);

    if (post.polls.isEmpty) return const SizedBox.shrink();
    final poll = post.polls.first;

    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = postCommentsCounts[post.id] ?? post.comments.length;
    final sharesCount = postSharesCounts[post.id] ?? post.sharesCount;
    final viewLikes = postLikedUsers[post.id] ?? [];
    final currentUsername = userProvider.userProfile?.username ?? '';
    final profile = userProvider.userProfile;

    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipOval(
                    child: (() {
                      if (profile == null) {
                        return const _AvatarPlaceholder(
                          username: null,
                          fontSize: 18,
                        );
                      }
                      final cachedImage = getConvertImage(
                        profile.profilePictureUrl,
                      );
                      if (cachedImage != null) {
                        return Image.memory(
                          cachedImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                            username: profile.username,
                            fontSize: 18,
                          ),
                        );
                      } else {
                        return _AvatarPlaceholder(
                          username: profile.username,
                          fontSize: 18,
                        );
                      }
                    })(),
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userProvider.isLoading || profile == null
                          ? '-'
                          : (profile.firstName.isNotEmpty
                                ? '${profile.firstName} ${profile.lastName}'
                                      .trim()
                                : profile.username),
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: txt.title,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          userProvider.isLoading || profile == null
                              ? '-'
                              : '@${profile.username}',
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
              ],
            ),
          ),

          Divider(color: Theme.of(context).colorScheme.outlineVariant),

          // ── Body ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question + total votes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        poll.question,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                    if (post.is_polled_by_current_user)
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

                // ── Poll options ──────────────────────────────────
                if (isImage)
                  _buildImagesStack(post)
                else if (post.is_polled_by_current_user)
                  // Already voted → show results
                  _buildPolledTextOptions(poll, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ThingsResultScreen(
                          username: post.user,
                          postId: post.id.toString(),
                        ),
                      ),
                    );
                  })
                else
                  // Not yet voted → show option chips
                  _buildTextOptions(poll, () {
                    final userProvider = Provider.of<PublicProfileProvider>(
                      context,
                      listen: false,
                    );
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => PublicUserThingsRanking(
                              firstName:
                                  userProvider.userProfile?.firstName ?? '',
                              lastName:
                                  userProvider.userProfile?.lastName ?? '',
                              profileImage:
                                  userProvider.userProfile!.profilePictureUrl,
                              post: post,
                              poll: poll,
                            ),
                          ),
                        )
                        .then((result) {
                          if (result == true) {
                            setState(() {});
                            _loadData();
                          }
                        });
                  }),

                const SizedBox(height: 12),

                // ── Actions row ───────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(post.id),
                      child: isLiked
                          ? AppIcons.filledHeart(key: const ValueKey('filled'))
                          : AppIcons.outlineHeart(
                              key: const ValueKey('outline'),
                            ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _showLikedUsersBottomSheet(post.id, currentUsername),
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

                // ── Liked by ──────────────────────────────────────
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

  Widget _buildTextOptions(PublicPoll poll, VoidCallback onTap) {
    if (poll.options.isEmpty) return const SizedBox.shrink();

    final int totalOptions = poll.options.length;

    // Always show only 1 visible chip if 2 options, else show 2
    final int visibleCount = totalOptions == 2 ? 1 : 2;
    final int moreCount = totalOptions - visibleCount;
    final visibleOptions = poll.options.take(visibleCount).toList();

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          ...visibleOptions
              .asMap()
              .entries
              .map(
                (entry) => [
                  _buildOptionChip(
                    label: entry.value.text ?? '',
                    isBold: false,
                  ),
                  SizedBox(width: 8.w),
                ],
              )
              .expand((e) => e),

          // "+N more" always shown
          _buildOptionChip(label: '+$moreCount more', isBold: true),
        ],
      ),
    );
  }

  Widget _buildOptionChip({required String label, required bool isBold}) {
    final txt = AppTextColors.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.5,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: txt.title,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPolledTextOptions(PublicPoll poll, VoidCallback onTap) {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (poll.options.isEmpty) return const SizedBox.shrink();

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
                      // ── Option text + percentage ──────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option.text ?? '',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          SizedBox(
                            width: 44.w,
                            child: Text(
                              '${option.percentage.toInt()}%',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 6.h),

                      // ── Progress bar ──────────────────────────────
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 8.h,
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
                const SizedBox(width: 12),
                // ── Vote count ────────────────────────────────────
                SizedBox(
                  width: 48.w,
                  child: Text(
                    '${option.voteCount} votes',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: txt.muted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImagesStack(PublicPost post) {
    if (post.polls.isEmpty) return const SizedBox.shrink();

    List<PollOptionImage> validImages = [];
    PublicPoll? firstPollWithImages;

    for (var p in post.polls) {
      for (var option in p.options) {
        if (option.image != null) {
          validImages.add(option.image!);
          firstPollWithImages ??= p;
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
              children: validImages.asMap().entries.map<Widget>((entry) {
                int index = entry.key;
                PollOptionImage imageData = entry.value;
                Alignment alignment = alignments[index];
                double imageWidth = (availableWidth * 0.7) - (index * 8.0);
                imageWidth = imageWidth < 60.w ? 60.w : imageWidth;
                final imageUrl = '${ApiConfig.baseUrlImage}${imageData.url}';

                return Align(
                  alignment: alignment,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: imageWidth,
                    height: imageHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        child: FutureBuilder<String?>(
                          future: _authTokenFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  color: Colors.grey[200],
                                ),
                              );
                            }
                            final token = snapshot.data;
                            final headers = token != null && imageUrl.contains('/api/')
                                ? {'Authorization': 'Bearer $token'}
                                : null;
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              headers: headers,
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
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double topPadding, PublicProfileProvider userProvider) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final profile = userProvider.userProfile;
    final effectiveStatus = _getEffectiveFollowStatus(
      profile?.followStatus,
      profile != null,
    );
    final isFriend =
        effectiveStatus == FollowStatus.rechase ||
        effectiveStatus == FollowStatus.both;
    final canViewPosts = profile != null
        ? (!profile.isPrivate || isFriend)
        : true;
    final buttonState = _getButtonState(effectiveStatus);
    return Container(
      color: Theme.of(context).colorScheme.background,
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
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: (() {
                      if (profile == null) {
                        return const _AvatarPlaceholder(
                          username: null,
                          fontSize: 35,
                        );
                      }
                      final cachedImage = getConvertImage(
                        profile.profilePictureUrl,
                      );
                      if (cachedImage != null) {
                        return Image.memory(
                          cachedImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                            username: profile.username,
                            fontSize: 35,
                          ),
                        );
                      } else {
                        return _AvatarPlaceholder(
                          username: profile.username,
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
            userProvider.isLoading || userProvider.userProfile == null
                ? '-'
                : (userProvider.userProfile!.firstName.isNotEmpty
                      ? '${userProvider.userProfile!.firstName} ${userProvider.userProfile!.lastName}'
                            .trim()
                      : userProvider.userProfile!.username),
            style: AppTextStyles.sectionHeading.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            userProvider.isLoading || userProvider.userProfile == null
                ? '-'
                : '@${userProvider.userProfile!.username}',
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
                  value: profile?.rechaseList?.length.toString() ?? '0',
                  label: AppLocalizations.of(context)!.revibe,
                  onTap: canViewPosts
                      ? () {
                          navigationPush(
                            context,
                            PublicChaseList(
                              userId: profile!.id,
                              username: profile.username,
                              initialIndex: 1,
                              chaseList: profile.chaseList,
                              rechaseList: profile.rechaseList,
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: profile?.chaseList?.length.toString() ?? '0',
                  label: AppLocalizations.of(context)!.vibe,
                  onTap: canViewPosts
                      ? () {
                          navigationPush(
                            context,
                            PublicChaseList(
                              userId: profile!.id,
                              username: profile.username,
                              initialIndex: 0,
                              chaseList: profile.chaseList,
                              rechaseList: profile.rechaseList,
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: canViewPosts
                      ? (cachedThingsPosts.length + cachedImagesPosts.length)
                            .toString()
                      : (profile.imagePostCount + profile.textPostCount)
                            .toString(),
                  label: AppLocalizations.of(context)!.polls,
                  onTap: null,
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
                    child: ElevatedButton(
                      onPressed: buttonState['canTap']
                          ? () {
                              _handleFollowAction(
                                profile!.username,
                                buttonState['isFollowing'],
                                profile.isPrivate,
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonState['isFollowing']
                            ? (isDarkMode ? Colors.transparent : Colors.white)
                            : Theme.of(context).colorScheme.primary.withOpacity(
                                buttonState['canTap'] ? 1.0 : 0.5,
                              ),
                        elevation: 0,
                        side: buttonState['isFollowing']
                            ? BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      child: Text(
                        buttonState['text'],
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.5,
                          color: buttonState['isFollowing']
                              ? Theme.of(context).colorScheme.onBackground
                              : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                              create: (_) => PrivateChatProvider()
                                ..init(
                                  memberName: profile.username,
                                  profileUrl: profile.profilePictureUrl,
                                  chatId: profile.chatId,
                                  currentUsername: profile.username,
                                ),
                              child: PrivateChatScreen(
                                userId: int.tryParse(profile!.id.toString()),
                                memberName: profile.username,
                                profileUrl: profile.profilePictureUrl,
                                chatId: profile.chatId,
                              ),
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.message,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.5,
                          color: Theme.of(context).colorScheme.onBackground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
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

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _StatCard({required this.value, required this.label, this.onTap});

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
