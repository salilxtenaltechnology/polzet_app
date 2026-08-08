// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/show_toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../../widgets/connection/no_internet_screen.dart';
import '../../../../provider/connection_provider.dart';
import '../../../../widgets/tabbar/indicatore_animation.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../home feed/rank/result/image/image_result_screen.dart';
import '../../home feed/rank/result/things/things_result_screen.dart';
import '../../message/chat/private/private_chat_screen.dart';
import '../rank/image/public_user_image_ranking.dart';
import '../rank/things/public_user_things_ranking.dart';
import 'chase/public_chase_list.dart';
import '../widgets/profile_image_preview.dart';
import '../../../../widgets/image/app_cached_network_image.dart';
import '../../../../widgets/expandable_bio.dart';

import '../../../../api/api_service.dart';
import '../../../../models/posts/user_post_model.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../api/api_config.dart';
import '../../../../core/utils/bottomsheet_util.dart';
import '../../../../api/services/like/like_service.dart';
import '../../../../models/like/like_uers_model.dart';
import '../../../../core/utils/like_util.dart';
import '../../../../api/services/share/share_service.dart';
import '../../../../api/services/link/deeplink_generator_service.dart';

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
  List<UserPostModel> cachedThingsPosts = [];
  List<UserPostModel> cachedImagesPosts = [];

  Map<String, bool> postLikeStates = {};
  Map<String, bool> postSaveStates = {};
  Map<String, int> postLikeCounts = {};

  final LikeService likeService = LikeService();
  Map<String, List<LikeUser>> postLikedUsers = {};
  Map<String, bool> likedUsersLoading = {};
  Map<String, int> postCommentsCounts = {};
  Map<String, int> postSharesCounts = {};

  final Set<String> locallyVotedPostIds = {};
  final Map<String, Map<dynamic, double>> locallyUpdatedPercentages = {};
  final Map<String, String> locallyUpdatedTotalVotes = {};

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

        final success = await apiService.cancelFriendRequest(
          resolvedUserId ?? widget.userId,
        );

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

        final response = await apiService.unfriend(
          resolvedUserId ?? widget.userId,
        );

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
      if (widget.username != null && widget.username!.isNotEmpty) {
        await provider.fetchPublicUserProfile(widget.username!);
        if (provider.userProfile != null) {
          resolvedUserId = provider.userProfile!.id;
          _fetchCounts();
          _loadData();
        }
      } else if (widget.userId != null && widget.userId!.isNotEmpty) {
        String? resolvedUsername;
        try {
          final searchResult = await apiService.globalSearch(widget.userId!);
          if (searchResult != null &&
              searchResult.success &&
              searchResult.data.accounts.isNotEmpty) {
            for (final acc in searchResult.data.accounts) {
              if (acc.uuid == widget.userId) {
                resolvedUsername = acc.username;
                break;
              }
            }
            resolvedUsername ??= searchResult.data.accounts.first.username;
          }
        } catch (e) {
          debugPrint(
            'Error searching username for userId ${widget.userId}: $e',
          );
        }

        final lookupKey =
            (resolvedUsername != null && resolvedUsername.isNotEmpty)
            ? resolvedUsername
            : widget.userId!;

        await provider.fetchPublicUserProfile(lookupKey);
        if (provider.userProfile != null) {
          resolvedUserId = provider.userProfile!.id;
          _fetchCounts();
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
                profileImage: (userProvider.userProfile?.username.toLowerCase() == 'polzet_ai')
                    ? Assets.images.icSplash.path
                    : userProvider.userProfile?.profilePictureUrl,
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

  Future<void> _toggleSavePost(UserPostModel post) async {
    final currentSaved = postSaveStates[post.id] ?? post.isSaved;
    final nextSaved = !currentSaved;

    setState(() {
      postSaveStates[post.id] = nextSaved;
      post.isSaved = nextSaved;
    });

    try {
      final res = await apiService.toggleSavePost(postId: post.id);
      final dynamic savedVal =
          res['is_saved'] ?? res['is_saved_by_current_user'] ?? res['saved'];
      if (savedVal != null && mounted) {
        final bool serverSaved = savedVal == true ||
            savedVal == 1 ||
            savedVal.toString().toLowerCase() == 'true';
        setState(() {
          postSaveStates[post.id] = serverSaved;
          post.isSaved = serverSaved;
        });
      }
    } catch (e) {
      debugPrint('Error toggling save post: $e');
      if (mounted) {
        setState(() {
          postSaveStates[post.id] = currentSaved;
          post.isSaved = currentSaved;
        });
        showToast(message: 'Failed to update save status');
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
          leadingWidth: 48.w,
          elevation: 0,
          automaticallyImplyLeading: true,
          leading: Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: const PrimaryBackButton(),
          ),
          toolbarHeight: AppConstants.toolbarHeight.h,
        ),
        body: const ProfileShimmer(),
      );
    }

    if (publicProfileProvider.error != null) {
      final isOffline = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      ).isOffline;
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.background,
          leadingWidth: 48.w,
          elevation: 0,
          automaticallyImplyLeading: true,
          leading: Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: const PrimaryBackButton(),
          ),
          toolbarHeight: AppConstants.toolbarHeight.h,
        ),
        body: ConnectionErrorScreen(
          type:
              publicProfileProvider.errorType == ProfileErrorType.noInternet ||
                  isOffline
              ? ConnectionErrorType.noInternet
              : publicProfileProvider.errorType == ProfileErrorType.serverError
              ? ConnectionErrorType.serverError
              : ConnectionErrorType.unknown,
          errorMessage: publicProfileProvider.error,
          onRetry: () {
            _handleRefresh();
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        leadingWidth: 48.w,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const PrimaryBackButton(),
        ),
        toolbarHeight: AppConstants.toolbarHeight.h,
        // title: Text(
        //   'Profile',
        //   style: AppTextStyles.pageTitleTextStyle(context),
        // ),
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                FeatherIcons.moreVertical,
                size: 22,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              color: Theme.of(context).colorScheme.tertiaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              offset: const Offset(0, 45),
              elevation: 2,
              padding: EdgeInsets.zero,
              onSelected: (String result) {
                if (profile == null) return;
                if (result == 'Share Profile') {
                  ShareService.shareProfile(
                    username: profile.username,
                    profileId: profile.id.toString(),
                    context: context,
                  );
                } else if (result == 'Copy Profile Link') {
                  final link = DeepLinkService.generateProfileLink(
                    profile.username,
                  );
                  Clipboard.setData(ClipboardData(text: link)).then((_) {
                    showToast(message: 'Link copied');
                  });
                }
              },
              itemBuilder: (BuildContext context) {
                PopupMenuItem<String> buildItem(String text) {
                  final txt = AppTextColors.of(context);
                  return PopupMenuItem<String>(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    value: text,
                    height: 38,
                    child: Text(
                      text,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.title,
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                      ),
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
                            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 100),
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
                            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 100),
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

  Future<void> _fetchCounts() async {
    final targetId = resolvedUserId ?? widget.userId;
    if (targetId == null || targetId.isEmpty) return;
    if (!mounted) return;
    try {
      final results = await Future.wait([
        apiService.fetchChaseList(targetUserId: targetId, page: 1),
        apiService.fetchRechaseList(targetUserId: targetId, page: 1),
      ]);

      if (results[0] != null && results[1] != null && mounted) {
        final chase = int.tryParse(results[0]!['count']?.toString() ?? '') ?? 0;
        final rechase =
            int.tryParse(results[1]!['count']?.toString() ?? '') ?? 0;

        final provider = context.read<PublicProfileProvider>();
        provider.updateCounts(followersCount: chase, followingCount: rechase);
      }
    } catch (e) {
      debugPrint('Error fetching public chase/rechase counts: $e');
    }
  }

  Future<void> _handleRefresh() async {
    _serverFollowStatus = null;
    _localFollowStatus = null;
    final publicProfileProvider = Provider.of<PublicProfileProvider>(
      context,
      listen: false,
    );

    if (widget.username != null && widget.username!.isNotEmpty) {
      await publicProfileProvider.fetchPublicUserProfile(
        widget.username!,
        isRefresh: true,
      );
      if (publicProfileProvider.userProfile != null) {
        resolvedUserId = publicProfileProvider.userProfile!.id;
      }
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      await publicProfileProvider.fetchPublicUserProfile(
        widget.userId!,
        isRefresh: true,
      );
      if (publicProfileProvider.userProfile != null) {
        resolvedUserId = publicProfileProvider.userProfile!.id;
      }
    }

    await _fetchCounts();
    await _loadData(isRefresh: true);
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    final publicProfileProvider = Provider.of<PublicProfileProvider>(
      context,
      listen: false,
    );
    final username =
        publicProfileProvider.userProfile?.username ?? widget.username;
    if (username == null || username.isEmpty) return;

    if (!isRefresh) {
      setState(() {
        isLoadingPosts = true;
      });
    }

    await Future.wait([
      apiService
          .fetchPostsImages(username)
          .then((posts) {
            if (mounted) {
              final mappedPosts = posts.where((post) {
                return post.polls.any(
                  (poll) => poll.options.any((o) => o.image != null),
                );
              }).toList();
              for (var post in mappedPosts) {
                postLikeStates[post.id] = post.isLiked;
                postSaveStates[post.id] = post.isSaved;
                postLikeCounts[post.id] = post.likesCount;
                postCommentsCounts[post.id] = post.comments.length;
                postSharesCounts[post.id] = post.sharesCount;
                if (post.likesCount > 0) _fetchLikedUsersSilently(post.id);

                if (locallyVotedPostIds.contains(post.id)) {
                  post.is_polled_by_current_user = true;
                  final updatedTotalVotes = locallyUpdatedTotalVotes[post.id];
                  final optPctMap = locallyUpdatedPercentages[post.id];
                  for (var poll in post.polls) {
                    if (updatedTotalVotes != null) {
                      poll.totalVotes = updatedTotalVotes;
                    }
                    if (optPctMap != null) {
                      for (var option in poll.options) {
                        if (optPctMap.containsKey(option.id)) {
                          option.percentage = optPctMap[option.id]!;
                        }
                      }
                    }
                  }
                }
              }
              setState(() {
                cachedImagesPosts = mappedPosts;
              });
            }
          })
          .catchError((_) {}),
      apiService
          .fetchOnlyPollPosts(username)
          .then((posts) {
            if (mounted) {
              final mappedPosts = posts.where((post) {
                if (post.polls.isEmpty) return false;
                return post.polls.every(
                  (poll) => poll.options.every(
                    (o) =>
                        o.text != null && o.text!.isNotEmpty && o.image == null,
                  ),
                );
              }).toList();
              for (var post in mappedPosts) {
                postLikeStates[post.id] = post.isLiked;
                postSaveStates[post.id] = post.isSaved;
                postLikeCounts[post.id] = post.likesCount;
                postCommentsCounts[post.id] = post.comments.length;
                postSharesCounts[post.id] = post.sharesCount;
                if (post.likesCount > 0) _fetchLikedUsersSilently(post.id);

                if (locallyVotedPostIds.contains(post.id)) {
                  post.is_polled_by_current_user = true;
                  final updatedTotalVotes = locallyUpdatedTotalVotes[post.id];
                  final optPctMap = locallyUpdatedPercentages[post.id];
                  for (var poll in post.polls) {
                    if (updatedTotalVotes != null) {
                      poll.totalVotes = updatedTotalVotes;
                    }
                    if (optPctMap != null) {
                      for (var option in poll.options) {
                        if (optPctMap.containsKey(option.id)) {
                          option.percentage = optPctMap[option.id]!;
                        }
                      }
                    }
                  }
                }
              }
              setState(() {
                cachedThingsPosts = mappedPosts;
              });
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

  Widget _buildSimplePostCard(
    UserPostModel post, {
    required bool isImage,
    required PublicProfileProvider userProvider,
  }) {
    final txt = AppTextColors.of(context);

    if (post.polls.isEmpty) return const SizedBox.shrink();
    final poll = post.polls.first;

    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final isSaved = postSaveStates[post.id] ?? post.isSaved;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = postCommentsCounts[post.id] ?? post.comments.length;
    final sharesCount = postSharesCounts[post.id] ?? post.sharesCount;
    final viewLikes = postLikedUsers[post.id] ?? [];
    final currentUsername = userProvider.userProfile?.username ?? '';
    final profile = userProvider.userProfile;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double pct1 = (poll.options.isNotEmpty)
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = (poll.options.length > 1)
        ? poll.options[1].percentage
        : 0.0;
    final firstImage = poll.options.isEmpty
        ? null
        : (poll.options
              .firstWhere((o) => o.image != null, orElse: () => poll.options[0])
              .image);

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
                  width: 42,
                  height: 42,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipOval(
                          child: (() {
                            final String currentUsername =
                                (profile?.username ?? widget.username ?? '')
                                    .trim()
                                    .toLowerCase();
                            if (currentUsername == 'polzet_ai') {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 0,
                                    left: 10,
                                    right: 9,
                                  ),
                                  child: Image.asset(
                                    Assets.images.icSplash.path,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            }
                            if (profile == null) {
                              return const _AvatarPlaceholder(
                                username: null,
                                fontSize: 18,
                              );
                            }
                            final String profilePic = (profile.profilePictureUrl != null && profile.profilePictureUrl!.isNotEmpty)
                                ? profile.profilePictureUrl!
                                : ((profile.profilePicture != null && profile.profilePicture!.isNotEmpty)
                                    ? profile.profilePicture!
                                    : (profile.profileThumbnailUrl ?? ''));
                            if (profilePic.isNotEmpty) {
                              final cachedImage = getConvertImage(profilePic);
                              if (cachedImage != null) {
                                return Image.memory(
                                  cachedImage,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                                    username: profile.username,
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
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorWidget: (_, __, ___) => _AvatarPlaceholder(
                                    username: profile.username,
                                    fontSize: 18,
                                  ),
                                );
                              }
                            }
                            return _AvatarPlaceholder(
                              username: profile.username,
                              fontSize: 18,
                            );
                          })(),
                        ),
                      ),
                      if ((profile?.username ?? widget.username ?? '')
                              .trim()
                              .toLowerCase() ==
                          'polzet_ai')
                        Positioned.fill(
                          child: Image.asset(
                            Assets.images.aiFrame.path,
                            height: 60, 
                            width: 60,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      () {
                        if (userProvider.isLoading || profile == null) return '-';
                        final fn = profile.firstName.trim();
                        final ln = profile.lastName.trim();
                        final fullName = '$fn $ln'.trim();
                        if (fullName.isNotEmpty) return fullName;
                        return profile.username.isNotEmpty
                            ? profile.username
                            : 'Polzet User';
                      }(),
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: txt.title,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        if (['polzet_ai', 'polzet'].contains(
                            (profile?.username ?? widget.username ?? '')
                                .trim()
                                .toLowerCase())) ...[
                          const SizedBox(width: 4),
                          Image.asset(
                            Assets.images.icVerify.path,
                            height: 13,
                            width: 13,
                          ),
                        ],
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
                if (poll.pollType == 'hot_take') ...[
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
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () {
                          final votes = int.tryParse(poll.totalVotes) ?? 0;
                          if (votes > 0) {
                            BottomSheetUtils.showPollVotersBottomSheet(
                              context: context,
                              postId: post.id,
                              question: poll.question,
                              pollType: poll.pollType,
                            );
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
                          style: AppTextStyles.subText.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
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
                        height: 165.h,
                        placeholder: (context, url) => Container(
                          color: Theme.of(context).colorScheme.background,
                          height: 165.h,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.background,
                          height: 165.h,
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
                              postId: post.id.toString(),
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
                                if (post.is_polled_by_current_user) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ThingsResultScreen(
                                        username: post.user,
                                        postId: post.id.toString(),
                                      ),
                                    ),
                                  );
                                } else {
                                  final optionId = (poll.options.isNotEmpty)
                                      ? poll.options[0].id
                                      : null;
                                  if (optionId != null) {
                                    _submitSinglePollVote(poll, optionId, post);
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
                          SizedBox(width: 10.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (post.is_polled_by_current_user) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ThingsResultScreen(
                                        username: post.user,
                                        postId: post.id.toString(),
                                      ),
                                    ),
                                  );
                                } else {
                                  final optionId = (poll.options.length > 1)
                                      ? poll.options[1].id
                                      : null;
                                  if (optionId != null) {
                                    _submitSinglePollVote(poll, optionId, post);
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
                  (() {
                    final option1 = poll.options.isNotEmpty
                        ? poll.options[0].text ?? ''
                        : '';
                    final option2 = poll.options.length > 1
                        ? poll.options[1].text ?? ''
                        : '';
                    final hasImages = _hasImageOptions(poll);

                    return GestureDetector(
                      onTap: () {
                        if (post.is_polled_by_current_user) {
                          _onBattleOptionTap(post, poll, hasImages);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (poll.question.isNotEmpty) ...[
                            SizedBox(height: 5.h),
                            _buildQuestionRow(
                              context,
                              poll,
                              txt,
                              onVotesTap: () {
                                final votes =
                                    int.tryParse(poll.totalVotes) ?? 0;
                                if (votes > 0) {
                                  BottomSheetUtils.showPollVotersBottomSheet(
                                    context: context,
                                    postId: post.id,
                                    question: poll.question,
                                    pollType: poll.pollType,
                                  );
                                }
                              },
                            ),
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
                          if (poll.question.isNotEmpty ||
                              post.description.isNotEmpty)
                            const SizedBox(height: 12),
                          if (hasImages) ...[
                            GestureDetector(
                              onTap: post.is_polled_by_current_user
                                  ? null
                                  : () {},
                              child: SizedBox(
                                height: 165.h,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap:
                                                post.is_polled_by_current_user
                                                ? null
                                                : () {
                                                    final optionId =
                                                        poll.options.isNotEmpty
                                                        ? poll.options[0].id
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
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withOpacity(0.10),
                                                border: Border.all(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                  width: 1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.button,
                                                    ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.button,
                                                    ),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    if (poll
                                                            .options
                                                            .isNotEmpty &&
                                                        poll.options[0].image !=
                                                            null)
                                                      AppCachedNetworkImage(
                                                        imageUrl: poll
                                                            .options[0]
                                                            .image!
                                                            .resolvedUrl(
                                                              ApiConfig
                                                                  .baseUrlImage,
                                                            ),
                                                        fit: BoxFit.cover,
                                                        showSpinnerPlaceholder:
                                                            true,
                                                      ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.transparent,
                                                            Colors.black
                                                                .withOpacity(
                                                                  0.60,
                                                                ),
                                                          ],
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                        ),
                                                      ),
                                                    ),
                                                    if (post
                                                        .is_polled_by_current_user)
                                                      Positioned(
                                                        bottom: 2.h,
                                                        left: 8.w,
                                                        right: 8.w,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              option1,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: AppTextStyles
                                                                  .bodyText
                                                                  .copyWith(
                                                                    fontSize:
                                                                        13.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                            Text(
                                                              '${pct1.round()}%',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: AppTextStyles
                                                                  .bodyText
                                                                  .copyWith(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: Colors
                                                                        .white,
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
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: AppTextStyles
                                                              .bodyText
                                                              .copyWith(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white,
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
                                            onTap:
                                                post.is_polled_by_current_user
                                                ? null
                                                : () {
                                                    final optionId =
                                                        poll.options.length > 1
                                                        ? poll.options[1].id
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
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withOpacity(0.10),
                                                border: Border.all(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                  width: 1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.button,
                                                    ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.button,
                                                    ),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    if (poll.options.length >
                                                            1 &&
                                                        poll.options[1].image !=
                                                            null)
                                                      AppCachedNetworkImage(
                                                        imageUrl: poll
                                                            .options[1]
                                                            .image!
                                                            .resolvedUrl(
                                                              ApiConfig
                                                                  .baseUrlImage,
                                                            ),
                                                        fit: BoxFit.cover,
                                                        showSpinnerPlaceholder:
                                                            true,
                                                      ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.transparent,
                                                            Colors.black
                                                                .withOpacity(
                                                                  0.60,
                                                                ),
                                                          ],
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                        ),
                                                      ),
                                                    ),
                                                    if (post
                                                        .is_polled_by_current_user)
                                                      Positioned(
                                                        bottom: 2.h,
                                                        left: 8.w,
                                                        right: 8.w,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              option2,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: AppTextStyles
                                                                  .bodyText
                                                                  .copyWith(
                                                                    fontSize:
                                                                        13.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                            Text(
                                                              '${pct2.round()}%',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: AppTextStyles
                                                                  .bodyText
                                                                  .copyWith(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: Colors
                                                                        .white,
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
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: AppTextStyles
                                                              .bodyText
                                                              .copyWith(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white,
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
                                                ? const [
                                                    Color(0xFFFFFFFF),
                                                    Color(0xFFFCFCFC),
                                                  ]
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
                                            color: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            if (!post
                                                .is_polled_by_current_user) {
                                              final optionId =
                                                  poll.options.isNotEmpty
                                                  ? poll.options[0].id
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
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                                  .withOpacity(0.10),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withOpacity(0.2),
                                                width: 1.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.card,
                                                  ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (post
                                                    .is_polled_by_current_user) ...[
                                                  Text(
                                                    '${pct1.round()}%',
                                                    style: AppTextStyles
                                                        .bodyText
                                                        .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onBackground,
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ],
                                                Text(
                                                  option1,
                                                  style: AppTextStyles
                                                      .sectionHeading
                                                      .copyWith(
                                                        color: txt.title,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
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
                                            if (!post
                                                .is_polled_by_current_user) {
                                              final optionId =
                                                  poll.options.length > 1
                                                  ? poll.options[1].id
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
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                                  .withOpacity(0.10),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withOpacity(0.2),
                                                width: 1.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.card,
                                                  ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (post
                                                    .is_polled_by_current_user) ...[
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    '${pct2.round()}%',
                                                    style: AppTextStyles
                                                        .bodyText
                                                        .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onBackground,
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ],
                                                Text(
                                                  option2,
                                                  style: AppTextStyles
                                                      .sectionHeading
                                                      .copyWith(
                                                        color: txt.title,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
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
                                          color: isDarkMode
                                              ? Colors.black
                                              : Colors.white,
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
                  })(),
                  SizedBox(height: 5.h),
                ] else if (poll.pollType == 'this_or_that') ...[
                  _buildThisOrThatPollSection(context, poll, post),
                  SizedBox(height: 5.h),
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
                      if (post.is_polled_by_current_user)
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
                  SizedBox(height: 16.h),
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
                                profileImage: (userProvider.userProfile?.username.toLowerCase() == 'polzet_ai')
                                    ? Assets.images.icSplash.path
                                    : userProvider.userProfile!.profilePictureUrl,
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
                ],

                const SizedBox(height: 10),

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
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _toggleSavePost(post),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: isSaved
                            ? AppIcons.filledSave(
                                key: const ValueKey('saved_filled'),
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : AppIcons.outlineSave(
                                key: const ValueKey('saved_outline'),
                              ),
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

  Widget _buildTextOptions(UserPollQuestion poll, VoidCallback onTap) {
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

  Widget _buildPolledTextOptions(UserPollQuestion poll, VoidCallback onTap) {
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
                    final imageUrl = imageData.resolvedUrl(
                      ApiConfig.baseUrlImage,
                    );

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
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: FutureBuilder<String?>(
                              future: _authTokenFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.button,
                                      ),
                                      color: Colors.grey[200],
                                    ),
                                  );
                                }
                                final token = snapshot.data;
                                final headers =
                                    token != null && imageUrl.contains('/api/')
                                    ? {'Authorization': 'Bearer $token'}
                                    : null;
                                return CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  httpHeaders: headers,
                                  placeholder: (context, url) => Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.button,
                                      ),
                                      color: Colors.grey[200],
                                    ),
                                    child: Center(
                                      child: Loader(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.button,
                                          ),
                                          color: Colors.grey[200],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.grey[600],
                                            size: 30,
                                          ),
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
            onTap: () {
              final String currentUsername =
                  (profile?.username ?? widget.username ?? '')
                      .trim()
                      .toLowerCase();
              if (currentUsername == 'polzet_ai') return;
              final String? originalImageSource =
                  profile?.profilePicture ?? profile?.profilePictureUrl;
              if (originalImageSource == null ||
                  originalImageSource.isEmpty) {
                return;
              }
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.transparent,
                  transitionDuration: const Duration(milliseconds: 150),
                  reverseTransitionDuration: const Duration(
                    milliseconds: 150,
                  ),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return ProfileImagePreview(
                      imageSource: originalImageSource,
                      username: profile?.username ?? widget.username,
                    );
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (profile?.username ?? widget.username ?? '')
                                  .trim()
                                  .toLowerCase() ==
                              'polzet_ai'
                          ? Colors.transparent
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: (() {
                      final String currentUsername =
                          (profile?.username ?? widget.username ?? '')
                              .trim()
                              .toLowerCase();
                      if (currentUsername == 'polzet_ai') {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 26,
                              bottom: 6,
                              left: 18,
                              right: 12,
                            ),
                            child: Image.asset(
                              Assets.images.icSplash.path,
                              height: 70,width: 70,
                            ),
                          ),
                        );
                      }
                      if (profile == null) {
                        return const _AvatarPlaceholder(
                          username: null,
                          fontSize: 35,
                        );
                      }
                      final String profilePic = profile.profilePictureUrl ?? '';
                      if (profilePic.isNotEmpty) {
                        final cachedImage = getConvertImage(profilePic);
                        if (cachedImage != null) {
                          return Image.memory(
                            cachedImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                              username: profile.username,
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
                          return Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _AvatarPlaceholder(
                              username: profile.username,
                              fontSize: 35,
                            ),
                          );
                        }
                      }
                      return _AvatarPlaceholder(
                        username: profile.username,
                        fontSize: 35,
                      );
                    })(),
                  ),
                ),
                if ((profile?.username ?? widget.username ?? '')
                        .trim()
                        .toLowerCase() ==
                    'polzet_ai')
                  Positioned.fill(
                    child: Image.asset(
                      Assets.images.aiFrame.path,
                      height: 120,width: 120,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            () {
              if (userProvider.isLoading || userProvider.userProfile == null) {
                return '-';
              }
              final fn = userProvider.userProfile!.firstName.trim();
              final ln = userProvider.userProfile!.lastName.trim();
              final fullName = '$fn $ln'.trim();
              if (fullName.isNotEmpty) return fullName;
              return userProvider.userProfile!.username.isNotEmpty
                  ? userProvider.userProfile!.username
                  : 'Polzet User';
            }(),
            style: AppTextStyles.sectionHeading.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                userProvider.isLoading || userProvider.userProfile == null
                    ? '-'
                    : '@${userProvider.userProfile!.username}',
                style: AppTextStyles.subText.copyWith(
                  color: const Color(0XFF898989),
                  fontSize: 13.7,
                ),
              ),
              if (['polzet_ai', 'polzet'].contains(
                  (userProvider.userProfile?.username ?? widget.username ?? '')
                      .trim()
                      .toLowerCase())) ...[
                const SizedBox(width: 4),
                Image.asset(
                  Assets.images.icVerify.path,
                  height: 14,
                  width: 14,
                ),
              ],
            ],
          ),
          if (profile != null &&
              profile.bio != null &&
              profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpandableBio(bio: profile.bio!),
          ],
          const SizedBox(height: 20),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatCard(
                  value: (profile?.followingCount ?? 0).toString(),
                  label: AppLocalizations.of(context)!.revibe,
                  onTap: canViewPosts
                      ? () {
                          final p = profile!;
                          navigationPush(
                            context,
                            PublicChaseList(
                              userId: p.userId,
                              username: p.username,
                              initialIndex: 1,
                            ),
                          ).then((_) {
                            _fetchCounts();
                          });
                        }
                      : null,
                ),
                const SizedBox(width: 15),
                _StatCard(
                  value: (profile?.followersCount ?? 0).toString(),
                  label: AppLocalizations.of(context)!.vibe,
                  onTap: canViewPosts
                      ? () {
                          final p = profile!;
                          navigationPush(
                            context,
                            PublicChaseList(
                              userId: p.userId,
                              username: p.username,
                              initialIndex: 0,
                            ),
                          ).then((_) {
                            _fetchCounts();
                          });
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
                                color: Theme.of(context).colorScheme.onPrimary,
                                width: 0.8,
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
                              ? Theme.of(context).colorScheme.onPrimary
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
                        final p = profile!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                              create: (_) => PrivateChatProvider()
                                ..init(
                                  memberName:
                                      '${p.firstName} ${p.lastName}'
                                          .trim()
                                          .isNotEmpty
                                      ? '${p.firstName} ${p.lastName}'.trim()
                                      : p.username,
                                  profileUrl: (p.username.toLowerCase() == 'polzet_ai')
                                      ? Assets.images.icSplash.path
                                      : p.profilePictureUrl,
                                  chatId: p.chatId == 0 ? null : p.chatId,
                                  currentUsername: p.username,
                                ),
                              child: PrivateChatScreen(
                                userId: widget.userId,
                                memberName:
                                    '${p.firstName} ${p.lastName}'
                                        .trim()
                                        .isNotEmpty
                                    ? '${p.firstName} ${p.lastName}'.trim()
                                    : p.username,
                                username: p.username,
                                profileUrl: p.profilePictureUrl,
                                chatId: p.chatId == 0 ? null : p.chatId,
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

  Future<void> _submitSinglePollVote(
    UserPollQuestion poll,
    dynamic optionId,
    UserPostModel post,
  ) async {
    try {
      final List<Map<String, int>> votes = [
        {
          'option_id': optionId is int
              ? optionId
              : int.tryParse(optionId.toString()) ?? 0,
          'rank': 1,
        },
      ];

      final result = await ApiService.voteOnPollSingle(
        postId: post.id,
        votes: votes,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            post.is_polled_by_current_user = true;

            final currentVotes = int.tryParse(poll.totalVotes) ?? 0;
            poll.totalVotes = (currentVotes + 1).toString();

            final responseOptions = result['data']?['options'];
            final Map<dynamic, double> optPctMap = {};
            if (responseOptions is List && responseOptions.isNotEmpty) {
              for (final optionData in responseOptions) {
                if (optionData is! Map) continue;
                final rawId = optionData['option_id'];
                if (rawId == null) continue;
                final pct =
                    (optionData['percentage'] as num?)?.toDouble() ?? 0.0;

                for (var option in poll.options) {
                  if (option.id.toString() == rawId.toString()) {
                    option.percentage = pct;
                    optPctMap[option.id] = pct;
                  }
                }
              }
            }
            locallyUpdatedPercentages[post.id] = optPctMap;
            locallyUpdatedTotalVotes[post.id] = poll.totalVotes;
            locallyVotedPostIds.add(post.id);
          });
        }

        showToast(message: 'Vote submitted successfully!');
        _loadData(isRefresh: true);
      } else {
        showToast(message: 'Failed to submit vote. Please try again.');
      }
    } catch (e) {
      debugPrint('Error voting: $e');
      showToast(message: 'An error occurred. Please try again.');
    }
  }

  bool _hasImageOptions(UserPollQuestion poll) =>
      poll.options.any((o) => o.image != null);

  bool _hasTextOptions(UserPollQuestion poll) =>
      poll.options.any((o) => o.text != null && o.text!.isNotEmpty);

  Widget _buildAnonymousImageTextPollSection(
    BuildContext context,
    UserPollQuestion poll,
    UserPostModel post,
  ) {
    final txt = AppTextColors.of(context);
    final validOptions = poll.options
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (int.tryParse(poll.totalVotes) != null &&
                    int.parse(poll.totalVotes) > 0) ...[
                  SizedBox(width: 8.w),
                  Text(
                    '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
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
            color: Theme.of(context).colorScheme.outline,
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

  Widget _buildThisOrThatPollSection(
    BuildContext context,
    UserPollQuestion poll,
    UserPostModel post,
  ) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final option1 = (poll.options.isNotEmpty) ? poll.options[0].text ?? '' : '';
    final option2 = (poll.options.length > 1) ? poll.options[1].text ?? '' : '';

    final double pct1 = (poll.options.isNotEmpty)
        ? poll.options[0].percentage
        : 0.0;
    final double pct2 = (poll.options.length > 1)
        ? poll.options[1].percentage
        : 0.0;

    final hasImages = poll.options.any((o) => o.image != null);

    return GestureDetector(
      onTap: () {
        if (post.is_polled_by_current_user) {
          if (hasImages) {
            navigationPush(
              context,
              ImageResultScreen(
                username: post.user,
                postId: post.id.toString(),
              ),
            );
          } else {
            navigationPush(
              context,
              ThingsResultScreen(
                username: post.user,
                postId: post.id.toString(),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (int.tryParse(poll.totalVotes) != null &&
                    int.parse(poll.totalVotes) > 0) ...[
                  SizedBox(width: 8.w),
                  Text(
                    '${poll.totalVotes} ${AppLocalizations.of(context)!.votes}',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
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
            const SizedBox(height: 8),
          if (hasImages) ...[
            GestureDetector(
              onTap: () {
                if (post.is_polled_by_current_user) {
                  navigationPush(
                    context,
                    ImageResultScreen(
                      username: post.user,
                      postId: post.id.toString(),
                    ),
                  );
                }
              },
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
                            onTap: () {
                              if (post.is_polled_by_current_user) {
                                navigationPush(
                                  context,
                                  ImageResultScreen(
                                    username: post.user,
                                    postId: post.id.toString(),
                                  ),
                                );
                              } else {
                                final optionId = poll.options.isNotEmpty
                                    ? poll.options[0].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(poll, optionId, post);
                                }
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
                                    if (poll.options.isNotEmpty &&
                                        poll.options[0].image != null)
                                      AppCachedNetworkImage(
                                        imageUrl: poll.options[0].image!
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
                        SizedBox(width: 10.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (post.is_polled_by_current_user) {
                                navigationPush(
                                  context,
                                  ImageResultScreen(
                                    username: post.user,
                                    postId: post.id.toString(),
                                  ),
                                );
                              } else {
                                final optionId = poll.options.length > 1
                                    ? poll.options[1].id
                                    : null;
                                if (optionId != null) {
                                  _submitSinglePollVote(poll, optionId, post);
                                }
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
                                    if (poll.options.length > 1 &&
                                        poll.options[1].image != null)
                                      AppCachedNetworkImage(
                                        imageUrl: poll.options[1].image!
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
                        width: 32.w,
                        height: 32.h,
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
                          onTap: () {
                            if (post.is_polled_by_current_user) {
                              navigationPush(
                                context,
                                ThingsResultScreen(
                                  username: post.user,
                                  postId: post.id.toString(),
                                ),
                              );
                            } else {
                              final optionId = poll.options.isNotEmpty
                                  ? poll.options[0].id
                                  : null;
                              if (optionId != null) {
                                _submitSinglePollVote(poll, optionId, post);
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
                          onTap: () {
                            if (post.is_polled_by_current_user) {
                              navigationPush(
                                context,
                                ThingsResultScreen(
                                  username: post.user,
                                  postId: post.id.toString(),
                                ),
                              );
                            } else {
                              final optionId = poll.options.length > 1
                                  ? poll.options[1].id
                                  : null;
                              if (optionId != null) {
                                _submitSinglePollVote(poll, optionId, post);
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
          ],
        ],
      ),
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
    }
  }

  Widget _buildQuestionRow(
    BuildContext context,
    UserPollQuestion poll,
    AppTextColors txt, {
    VoidCallback? onVotesTap,
  }) {
    final votesCount = int.tryParse(poll.totalVotes) ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        if (votesCount > 0) ...[
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
